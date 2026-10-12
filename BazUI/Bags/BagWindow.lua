-- Bags/BagWindow.lua
-- One window holding every backpack slot. While BazUI is loaded the game's
-- six bag windows are switched off and the bag keys open this one.
--
-- Two ways of arranging it, switched from the right-click menu:
--   categories - items grouped and sorted by what they are (Categories.lua),
--                empty slots hidden and counted in the title instead; click a
--                category's heading to fold it away, drop an item on a
--                heading to pin it there (categorize mode shows every
--                category, empty ones too, to drop on)
--   bags       - every slot in the game's own order, empty ones included
-- Either way each cell stays bound to one real backpack slot and only where
-- it's drawn changes, so the bags themselves are never rearranged.

BazUI.Bags = BazUI.Bags or {};
local Categories = BazUI.Bags.Categories;
local MoneyBar = BazUI.Bags.MoneyBar;

local ICON = 32;        -- item icons are 32x32
local SLOT = 36;        -- icon plus a 2px frame, which carries the rarity color
local GAP = 2;
local HEADER_H = 22;    -- category name plus its underline
local SECTION_GAP = 6;  -- extra space above every category after the first
local FOOTER_GAP = 6;   -- space between the items and the money
local SEARCH_W, SEARCH_H = 180, 22;
local PAD_LEFT, PAD_RIGHT = 20, 20;   -- room for the Lotro.Window frame
local PAD_TOP, PAD_BOTTOM = 40, 22;
local CONTENT_TOP = PAD_TOP + SEARCH_H + 8;   -- below the search box

-- Colors are alpha, r, g, b.
local SLOT_COLOR = Turbine.UI.Color(0.85, 0.10, 0.09, 0.08);
local HEADER_COLOR = Turbine.UI.Color(1, 0.90, 0.78, 0.42);
local RULE_COLOR = Turbine.UI.Color(0.5, 0.90, 0.78, 0.42);
local HINT_COLOR = Turbine.UI.Color(1, 0.55, 0.55, 0.55);
local DIM_COLOR = Turbine.UI.Color(0.75, 0, 0, 0);   -- over items search didn't match

-- The slot frame takes the item's quality color, uncommon and better: white
-- on every slot would be noise rather than information.
local QUALITY_COLORS = {
	uncommon = Turbine.UI.Color(0.95, 0.95, 0.84, 0.30),     -- yellow
	rare = Turbine.UI.Color(0.95, 0.72, 0.40, 0.95),         -- purple
	incomparable = Turbine.UI.Color(0.95, 0.30, 0.85, 0.82), -- teal
	legendary = Turbine.UI.Color(0.95, 1.00, 0.56, 0.16),    -- orange
};

-- Any bag key toggles the window: "Toggle All Bags" and "Toggle Bag 1-6".
local TOGGLE_ACTIONS = {};
for _, name in ipairs({ "ToggleBags", "ToggleBag1", "ToggleBag2", "ToggleBag3",
		"ToggleBag4", "ToggleBag5", "ToggleBag6" }) do
	local action = Turbine.UI.Lotro.Action[name];
	if action ~= nil then
		TOGGLE_ACTIONS[action] = true;
	end
end

local settings, backpack, equipment, window, dropZone, menu, searchBox;
local enabled = false;
local categorize = false;   -- categorize mode: every category shown, for pinning
local slots = {};    -- backpack slot index -> cell
local headers = {};  -- category key -> header
local entries = {};  -- backpack slot index -> Categories.Describe(), from the last rebuild
local query = "";    -- lower-cased search text, "" when not searching

local Rebuild; -- defined below; the menu and headers call it

-- The grid is settings.Columns slots wide.
local function ContentWidth()
	return settings.Columns * SLOT + (settings.Columns - 1) * GAP;
end

local function SetGameBagsEnabled(enabled)
	for i = 1, 6 do
		Turbine.UI.Lotro.LotroUI.SetEnabled(Turbine.UI.Lotro.LotroUIElement["Backpack" .. i], enabled);
	end
end

local function FirstEmptySlot()
	for index = 1, backpack:GetSize() do
		if backpack:GetItem(index) == nil then
			return index;
		end
	end
end

-- index nil means "wherever there's room", for drops on the background.
local function Drop(index, args)
	local shortcut = args.DragDropInfo:GetShortcut();
	index = index or FirstEmptySlot();
	if shortcut ~= nil and index ~= nil then
		backpack:PerformShortcutDrop(shortcut, index, Turbine.UI.Control.IsShiftKeyDown());
	end
end

-- Dropping an item on a heading pins it to that category; dropping it on the
-- heading the rules would pick anyway takes the pin off.
local function PinDropped(key, args)
	local shortcut = args.DragDropInfo:GetShortcut();
	if shortcut == nil or shortcut:GetType() ~= Turbine.UI.Lotro.ShortcutType.Item then
		return;
	end
	local item = shortcut:GetItem();
	if item == nil then
		return;
	end
	local entry = Categories.Describe(item, 0);
	if entry.name == "" then
		return;
	end
	if entry.autoCategory.key == key then
		settings.Pins[entry.name] = nil;
		Turbine.Shell.WriteLine("BazUI: " .. entry.name .. " is no longer pinned - it files under " .. entry.autoCategory.label .. " by itself.");
	else
		settings.Pins[entry.name] = key;
		Turbine.Shell.WriteLine("BazUI: " .. entry.name .. " now always files under " .. Categories.Get(key).label .. ".");
	end
	BazUI.Log.Write("bags: pin " .. entry.name .. " -> " .. tostring(settings.Pins[entry.name]));
	Rebuild();
end

-- Right-click menu on the background and headings.
local byCategoryItem, byBagItem, categorizeItem;

local function CreateMenu()
	local m = Turbine.UI.ContextMenu();
	local items = m:GetItems();

	byCategoryItem = Turbine.UI.MenuItem("Group by category");
	byCategoryItem.Click = function(sender, args)
		BazUI.Bags.SetView("categories");
	end
	items:Add(byCategoryItem);

	byBagItem = Turbine.UI.MenuItem("Bag order");
	byBagItem.Click = function(sender, args)
		BazUI.Bags.SetView("bags");
	end
	items:Add(byBagItem);

	local expandAll = Turbine.UI.MenuItem("Expand all categories");
	expandAll.Click = function(sender, args)
		settings.Collapsed = {};
		Rebuild();
	end
	items:Add(expandAll);

	local collapseAll = Turbine.UI.MenuItem("Collapse all categories");
	collapseAll.Click = function(sender, args)
		for key in pairs(headers) do
			settings.Collapsed[key] = true;
		end
		Rebuild();
	end
	items:Add(collapseAll);

	categorizeItem = Turbine.UI.MenuItem("Categorize mode (drop items on a heading to pin them)");
	categorizeItem.Click = function(sender, args)
		categorize = not categorize;
		if categorize and settings.View == "bags" then
			settings.View = "categories";
		end
		Rebuild();
	end
	items:Add(categorizeItem);

	return m;
end

local function OpenMenu()
	byCategoryItem:SetChecked(settings.View ~= "bags");
	byBagItem:SetChecked(settings.View == "bags");
	categorizeItem:SetChecked(categorize);
	menu:ShowMenu();
end

local function OnBackgroundClick(sender, args)
	if args.Button == Turbine.UI.MouseButton.Right then
		OpenMenu();
	end
end

local function CreateSlot(index)
	local cell = Turbine.UI.Control();
	cell:SetParent(window);
	cell:SetSize(SLOT, SLOT);
	cell:SetBackColor(SLOT_COLOR);
	cell:SetAllowDrop(true);
	cell.DragDrop = function(sender, args)
		Drop(index, args);
	end

	local icon = Turbine.UI.Lotro.ItemControl(nil);
	icon:SetParent(cell);
	icon:SetPosition((SLOT - ICON) / 2, (SLOT - ICON) / 2);
	icon:SetSize(ICON, ICON);
	icon:SetAllowDrop(true);
	icon.DragDrop = cell.DragDrop;

	-- Laid over the item when a search doesn't match it. Mouse-invisible, so
	-- the item underneath still gets its clicks and tooltip.
	local dim = Turbine.UI.Control();
	dim:SetParent(cell);
	dim:SetSize(SLOT, SLOT);
	dim:SetBackColor(DIM_COLOR);
	dim:SetZOrder(1);
	dim:SetMouseVisible(false);
	dim:SetVisible(false);

	cell.icon = icon;
	cell.dim = dim;
	return cell;
end

local function ToggleCollapsed(key)
	if settings.Collapsed[key] then
		settings.Collapsed[key] = nil;
	else
		settings.Collapsed[key] = true;
	end
	Rebuild();
end

local function GetHeader(category)
	local header = headers[category.key];
	if header == nil then
		header = Turbine.UI.Control();
		header:SetParent(window);
		header:SetHeight(HEADER_H);
		header:SetAllowDrop(true);
		header.DragDrop = BazUI.Guard("bags pin", function(sender, args)
			PinDropped(category.key, args);
		end);
		header.MouseClick = function(sender, args)
			if args.Button == Turbine.UI.MouseButton.Right then
				OpenMenu();
			else
				ToggleCollapsed(category.key);
			end
		end

		local label = Turbine.UI.Label();
		label:SetParent(header);
		label:SetHeight(HEADER_H - 4);
		label:SetFont(Turbine.UI.Lotro.Font.TrajanPro14);
		label:SetForeColor(HEADER_COLOR);
		label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		label:SetMouseVisible(false);
		header.label = label;

		local rule = Turbine.UI.Control();
		rule:SetParent(header);
		rule:SetPosition(0, HEADER_H - 3);
		rule:SetHeight(1);
		rule:SetBackColor(RULE_COLOR);
		rule:SetMouseVisible(false);
		header.rule = rule;

		headers[category.key] = header;
	end
	return header;
end

-- Puts the n-th cell (1-based) of a grid whose top row is at y.
local function PlaceInGrid(cell, n, y)
	cell:SetPosition(PAD_LEFT + ((n - 1) % settings.Columns) * (SLOT + GAP),
		y + math.floor((n - 1) / settings.Columns) * (SLOT + GAP));
	cell:SetVisible(true);
end

local function GridHeight(count)
	local rows = math.ceil(count / settings.Columns);
	return rows * SLOT + math.max(rows - 1, 0) * GAP;
end

-- Each layout places what it shows and returns the y its content ends at.
local function LayoutBags(count)
	for index = 1, count do
		PlaceInGrid(slots[index], index, CONTENT_TOP);
	end
	return CONTENT_TOP + GridHeight(count);
end

local function LayoutCategories(count)
	local y = CONTENT_TOP;
	for n, group in ipairs(Categories.Group(entries, count, categorize)) do
		if n > 1 then
			y = y + SECTION_GAP;
		end

		local category = group.category;
		local collapsed = settings.Collapsed[category.key] == true;
		local header = GetHeader(category);
		if categorize and #group.entries == 0 then
			header.label:SetText("  " .. category.label .. "  - drop items here");
		elseif collapsed then
			header.label:SetText("+ " .. category.label .. " (" .. #group.entries .. ")");
		else
			header.label:SetText("- " .. category.label);
		end
		header:SetPosition(PAD_LEFT, y);
		header:SetWidth(ContentWidth());
		header.label:SetWidth(ContentWidth());
		header.rule:SetWidth(ContentWidth());
		header:SetVisible(true);
		y = y + HEADER_H;

		if not collapsed then
			for i, entry in ipairs(group.entries) do
				PlaceInGrid(slots[entry.index], i, y);
			end
			y = y + GridHeight(#group.entries);
		end
	end
	return y;
end

-- Dims every item the search doesn't match. Cheap: reuses the descriptions
-- from the last rebuild, so it can run on every keystroke.
local function ApplySearch()
	for index, cell in ipairs(slots) do
		local entry = entries[index];
		local match = query == "" or (entry ~= nil and Categories.Matches(entry, query));
		cell.dim:SetVisible(not match);
	end
end

-- Re-reads every slot and redraws the window around what's there.
Rebuild = function()
	local count = backpack:GetSize();
	local free = 0;
	entries = {};

	for index = 1, count do
		if slots[index] == nil then
			slots[index] = CreateSlot(index);
		end
		local cell = slots[index];
		local item = backpack:GetItem(index);
		cell.icon:SetItem(item);
		cell:SetVisible(false); -- the layout shows the ones it places

		if item == nil then
			free = free + 1;
			cell:SetBackColor(SLOT_COLOR);
		else
			local entry = Categories.Describe(item, index);
			entries[index] = entry;
			cell:SetBackColor((settings.RarityBorder and QUALITY_COLORS[entry.qualityName]) or SLOT_COLOR);
		end
	end

	-- The bag shrank (rare): park the leftover cells.
	for index = count + 1, #slots do
		slots[index].icon:SetItem(nil);
		slots[index]:SetVisible(false);
	end

	for _, header in pairs(headers) do
		header:SetVisible(false);
	end

	local bottom;
	if settings.View == "bags" then
		bottom = LayoutBags(count);
	else
		bottom = LayoutCategories(count);
	end
	bottom = math.max(bottom, CONTENT_TOP + SLOT);

	dropZone:SetSize(ContentWidth(), bottom - CONTENT_TOP);
	MoneyBar.SetVisible(settings.ShowMoney);
	if settings.ShowMoney then
		MoneyBar.Place(PAD_LEFT, bottom + FOOTER_GAP, ContentWidth());
		bottom = bottom + FOOTER_GAP + MoneyBar.HEIGHT;
	end

	window:SetSize(PAD_LEFT + ContentWidth() + PAD_RIGHT, bottom + PAD_BOTTOM);
	window:SetText("Bags (" .. free .. " free)");

	ApplySearch();
end

-- Bag changes arrive as bursts of events (equipping takes one item out and
-- puts the old piece in), so events only mark the window stale: it's rebuilt
-- on the next frame, then once more a moment later to catch anything the
-- server finishes after that.
local SETTLE_TIME = 0.3; -- seconds
local rebuildSoon = false;
local rebuildAt = nil;   -- game time of the follow-up rebuild

local function QueueRebuild()
	rebuildSoon = true;
	rebuildAt = Turbine.Engine.GetGameTime() + SETTLE_TIME;
	window:SetWantsUpdates(true);
end

local function OnUpdate()
	if rebuildSoon then
		rebuildSoon = false;
		Rebuild();
	end
	if rebuildAt ~= nil and Turbine.Engine.GetGameTime() >= rebuildAt then
		rebuildAt = nil;
		Rebuild();
	end
	if not rebuildSoon and rebuildAt == nil then
		window:SetWantsUpdates(false);
	end
end

local function CreateWindow()
	local w = Turbine.UI.Lotro.Window();
	w:SetText("Bags");

	-- Put it back where it was, unless that's now off screen.
	local left, top = settings.Left, settings.Top;
	if left < 0 or left > Turbine.UI.Display.GetWidth() - 100 then left = 200 end
	if top < 0 or top > Turbine.UI.Display.GetHeight() - 100 then top = 200 end
	w:SetPosition(left, top);

	w.PositionChanged = function(sender, args)
		settings.Left = w:GetLeft();
		settings.Top = w:GetTop();
	end

	w.VisibleChanged = BazUI.Guard("bags VisibleChanged", function(sender, args)
		settings.Visible = w:IsVisible();
		if settings.Visible then
			-- Another plugin unloading (HugeBag did this) can switch the
			-- game's bags back on, so switch them off again whenever ours opens.
			if enabled then
				SetGameBagsEnabled(false);
			end
			Rebuild(); -- cheap, and self-corrects anything an event missed
			MoneyBar.Refresh();
		else
			searchBox:SetText(""); -- a bag that reopens half-dimmed is confusing
		end
	end);

	w.Update = BazUI.Guard("bags Update", OnUpdate);

	w:SetWantsKeyEvents(true);
	w.KeyDown = function(sender, args)
		if not enabled then
			return;
		end
		if TOGGLE_ACTIONS[args.Action] then
			w:SetVisible(not w:IsVisible());
		elseif args.Action == Turbine.UI.Lotro.Action.Escape and w:IsVisible() then
			w:SetVisible(false);
		end
	end

	return w;
end

local function CreateSearch()
	local box = Turbine.UI.Lotro.TextBox();
	box:SetParent(window);
	box:SetPosition(PAD_LEFT, PAD_TOP);
	box:SetSize(SEARCH_W, SEARCH_H);
	box:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	if box.SetMultiline ~= nil then
		box:SetMultiline(false);
	end

	-- "Search" in grey while the box is empty and not being typed in.
	local hint = Turbine.UI.Label();
	hint:SetParent(window);
	hint:SetPosition(PAD_LEFT + 6, PAD_TOP);
	hint:SetSize(SEARCH_W - 6, SEARCH_H);
	hint:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	hint:SetForeColor(HINT_COLOR);
	hint:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
	hint:SetText("Search");
	hint:SetZOrder(1);
	hint:SetMouseVisible(false);

	local focused = false;

	box.TextChanged = BazUI.Guard("bags search", function(sender, args)
		local text = box:GetText() or "";
		query = string.lower(string.match(text, "^%s*(.-)%s*$"));
		hint:SetVisible(text == "" and not focused);
		ApplySearch();
	end);

	box.FocusGained = function(sender, args)
		focused = true;
		hint:SetVisible(false);
	end

	box.FocusLost = function(sender, args)
		focused = false;
		hint:SetVisible((box:GetText() or "") == "");
	end

	return box;
end

-- Behind the slots: catches drops that miss a slot, and right-clicks.
local function CreateDropZone()
	local zone = Turbine.UI.Control();
	zone:SetParent(window);
	zone:SetPosition(PAD_LEFT, CONTENT_TOP);
	zone:SetZOrder(-1);
	zone:SetAllowDrop(true);
	zone.DragDrop = function(sender, args)
		Drop(nil, args);
	end
	zone.MouseClick = OnBackgroundClick;
	return zone;
end

local function HookEvents()
	backpack.ItemAdded = BazUI.Guard("bags ItemAdded", function(sender, args)
		BazUI.Trace("bags: ItemAdded slot " .. tostring(args.Index));
		QueueRebuild();
	end);

	backpack.ItemRemoved = BazUI.Guard("bags ItemRemoved", function(sender, args)
		BazUI.Trace("bags: ItemRemoved slot " .. tostring(args.Index));
		QueueRebuild();
	end);

	backpack.ItemMoved = BazUI.Guard("bags ItemMoved", function(sender, args)
		BazUI.Trace("bags: ItemMoved " .. tostring(args.OldIndex) .. " -> " .. tostring(args.NewIndex));
		QueueRebuild();
	end);

	backpack.SizeChanged = BazUI.Guard("bags SizeChanged", function(sender, args)
		BazUI.Trace("bags: SizeChanged to " .. tostring(backpack:GetSize()));
		QueueRebuild();
	end);

	-- Equipping should also show up as backpack events, but listen here too
	-- in case the game only reports the swap on the equipment side.
	equipment.ItemEquipped = BazUI.Guard("bags ItemEquipped", function(sender, args)
		BazUI.Trace("bags: ItemEquipped slot " .. tostring(args.Index));
		QueueRebuild();
	end);

	equipment.ItemUnequipped = BazUI.Guard("bags ItemUnequipped", function(sender, args)
		BazUI.Trace("bags: ItemUnequipped slot " .. tostring(args.Index));
		QueueRebuild();
	end);
end

local function Create()
	settings = BazUI.Settings.Get("Bags");
	Categories.SetPins(settings.Pins);
	local player = Turbine.Gameplay.LocalPlayer.GetInstance();
	backpack = player:GetBackpack();
	equipment = player:GetEquipment();

	window = CreateWindow();
	dropZone = CreateDropZone();
	searchBox = CreateSearch();
	MoneyBar.Create(window);
	menu = CreateMenu();
	Rebuild();
	HookEvents();

	SetGameBagsEnabled(false);
	window:SetVisible(settings.Visible);

	-- Last, so a scaling problem can never leave the bag half set up.
	BazUI.Scaling.Attach(window);

	Categories.LogSnapshot(backpack);
end

-- Module switch (General tab). Off hands the bags back to the game.
function BazUI.Bags.Enable()
	if window == nil then
		Create();
	else
		SetGameBagsEnabled(false);
	end
	enabled = true;
end

function BazUI.Bags.Disable()
	enabled = false;
	if window ~= nil then
		window:SetVisible(false);
	end
	SetGameBagsEnabled(true);
end

-- Redraws after a setting changes.
function BazUI.Bags.Refresh()
	if window ~= nil then
		Rebuild();
	end
end

-- The Bags settings tab. `form` is a BazUI.Options form.
function BazUI.Bags.BuildOptions(form)
	settings = settings or BazUI.Settings.Get("Bags"); -- the tab can open while the module is off
	form:Heading("Arrangement");
	form:Check("Group by category (off: the game's own bag order)", settings.View ~= "bags", function(on)
		BazUI.Bags.SetView(on and "categories" or "bags");
	end);
	form:Slider("Columns", 6, 20, settings.Columns, function(value)
		settings.Columns = value;
		BazUI.Bags.Refresh();
	end);

	form:Heading("Slots");
	form:Check("Rarity border (uncommon and better)", settings.RarityBorder, function(on)
		settings.RarityBorder = on;
		BazUI.Bags.Refresh();
	end);
	form:Check("Show money under the bag", settings.ShowMoney, function(on)
		settings.ShowMoney = on;
		BazUI.Bags.Refresh();
	end);
	form:Note("Right-click the bag's background or a heading for the same arrangement choices, plus expand and collapse all.");

	form:Heading("Pinned items");
	local pinned = {};
	for name, key in pairs(settings.Pins) do
		table.insert(pinned, { name = name, key = key });
	end
	table.sort(pinned, function(a, b) return a.name < b.name; end);
	if #pinned == 0 then
		form:Note("None yet. Drag an item onto a category heading in the bag to pin it there; turn on Categorize mode (right-click the bag) to see empty categories too.");
	end
	for _, pin in ipairs(pinned) do
		local category = Categories.Get(pin.key);
		local button;
		button = form:Button("Unpin " .. pin.name .. " (" .. (category and category.label or pin.key) .. ")", function()
			settings.Pins[pin.name] = nil;
			button:SetText("Unpinned " .. pin.name);
			button:SetEnabled(false);
			BazUI.Bags.Refresh();
		end);
	end
end

function BazUI.Bags.SetView(view)
	settings = settings or BazUI.Settings.Get("Bags");
	settings.View = view;
	BazUI.Log.Write("bags: view " .. view);
	BazUI.Bags.Refresh();
end

function BazUI.Bags.ToggleView()
	settings = settings or BazUI.Settings.Get("Bags");
	BazUI.Bags.SetView(settings.View == "bags" and "categories" or "bags");
end

function BazUI.Bags.Toggle()
	if window ~= nil and enabled then
		window:SetVisible(not window:IsVisible());
	elseif not enabled then
		Turbine.Shell.WriteLine("BazUI: the Bags module is off - switch it on in /bazui > General.");
	end
end

function BazUI.Bags.GetWindow()
	return window;
end

-- Plugin unloading: give the game its bags back.
function BazUI.Bags.Destroy()
	if enabled then
		SetGameBagsEnabled(true);
	end
end
