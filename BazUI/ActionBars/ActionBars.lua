-- ActionBars/ActionBars.lua
-- Action buttons with no chrome: just the skills, a small key label, and a
-- flash when the key fires. Each slot sits on a dark backdrop, with an
-- optional gold frame. Every bar is laid out in columns and rows, has its own
-- size on top of the UI scale, and moves in layout mode (Ctrl+\).
--
-- Two kinds of bar:
--   The game's six. Plugins can't be bound to keys, so each of these stands
--   in for one of the game's own bars, slot for slot: Main = keys 1..= (game
--   quickslots 1-12), Ctrl = 13-24, Alt = 25-36, Shift = 37-48, Extra 1 and
--   2 = 49-72. A key fires the game's slot, so a BazUI slot should hold the
--   same skill as the game slot with its key; the flash on key press is how a
--   mismatch shows. The BazUI skin hides the game's bars, which keep working
--   on their keys. Twelve slots each, as the game's.
--   Bars made in the settings tab: as many as you like, any number of
--   columns and rows, clicked only.

BazUI.ActionBars = {};
local ActionBars = BazUI.ActionBars;

local SLOT = 38;           -- the game's own quickslot size
local GAP = 4;
local STACK_GAP = 6;       -- between stacked bars, and above the XP bar
local MAX_COLUMNS, MAX_ROWS = 12, 12;
local GAME_SLOTS = 12;     -- per game bar
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 50, 200, 5;   -- percent of the UI scale
local FLASH_TIME = 0.15;   -- seconds
local FRAME_ART = "Baz4k/BazUI/ActionBars/Art/frame.tga";
local FRAME_PX = 2 * SLOT; -- the frame art is twice the slot size, shrunk to it so it stays sharp
local DATA_KEY = "BazUI_ActionBars";

-- Slots on bars made in BazUI are saved under numbers well clear of the
-- game's 1-72: bar Id n uses CUSTOM_BASE + n * CUSTOM_STRIDE + 1 onward.
local CUSTOM_BASE, CUSTOM_STRIDE = 1000, 200;

local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" };

-- The game's bars, bottom to top as they stack by default. `first` is the
-- game quickslot number of the bar's slot 1; `prefix` goes before its key
-- labels (nil: no keys bound by default).
local BARS = {
	{ key = "Main", title = "Main bar", keys = "keys 1 to =", first = 1, prefix = "" },
	{ key = "Ctrl", title = "Ctrl bar", keys = "Ctrl+1 to =", first = 13, prefix = "C" },
	{ key = "Alt", title = "Alt bar", keys = "Alt+1 to =", first = 25, prefix = "A" },
	{ key = "Shift", title = "Shift bar", keys = "Shift+1 to =", first = 37, prefix = "S" },
	{ key = "Extra1", title = "Extra bar 1", keys = "no keys by default", first = 49 },
	{ key = "Extra2", title = "Extra bar 2", keys = "no keys by default", first = 61 },
};
for stackIndex, def in ipairs(BARS) do
	def.stackIndex = stackIndex;
end

-- Colors are alpha, r, g, b.
local BACKDROP_COLOR = Turbine.UI.Color(0.45, 0.12, 0.11, 0.10);
local FLASH_COLOR = Turbine.UI.Color(0.40, 1, 1, 1);
local KEY_COLOR = Turbine.UI.Color(1, 0.88, 0.86, 0.80);

local settings;
local enabled = false;
local ready = false;     -- saved slots have been put back once
local bars = {};         -- def key -> { def, place, window, cells, fit, reapply }
local cellsByNumber = {};  -- slot number -> cell
local saved = {};        -- slot number -> { Type, Data }, per character
local restoring = false; -- set while shortcuts are put in by code
local pending = {};      -- slot numbers whose shortcut didn't take yet
local retryAt = {};      -- game times to try `pending` again
local flashing = {};     -- cell -> game time its flash ends
local ticker;            -- drives flashes, retries and the lock; also "the module has been created"

-- Locked bars take no drops unless Shift is down, so nothing lands on, moves
-- between or overwrites slots by accident. (A plugin can't stop a drag from
-- starting, only refuse the drop.) Shift is watched every frame while
-- locked, and the slots told whether to accept drops when it changes.
local shiftDown = false;

-- A skill dragged from one BazUI slot to another moves there, swapping with
-- whatever was there, as on the game's bars. A plugin quickslot only copies
-- what's dropped on it, so the slot a drag starts from is noted - on
-- DragStart, or if the game doesn't send that, the press that began it - and
-- emptied (or given the other slot's skill) when the drop lands.
local dragFrom;            -- { cell, type, data, time }
local dragStartSeen = false;
local DRAG_WINDOW = 10;    -- seconds a press can still turn out to be a drag

-- Turbine.UI.Lotro.Action value -> game quickslot number
local ACTION_SLOT = {};
for number = 1, 72 do
	local action = Turbine.UI.Lotro.Action["Quickslot_" .. number];
	if action ~= nil then
		ACTION_SLOT[action] = number;
	end
end

local function AcceptsDrops()
	return not settings.Locked or shiftDown;
end

local function Scale(control)
	local ok, scale = pcall(function() return control:GetScale(); end);
	return (ok and type(scale) == "number" and scale > 0) and scale or 1;
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, math.floor(tonumber(value) or low)));
end

local function IsEmpty(shortcut)
	return shortcut == nil or shortcut:GetType() == Turbine.UI.Lotro.ShortcutType.Undefined;
end

local function SaveSlots()
	pcall(Turbine.PluginData.Save, Turbine.DataScope.Character, DATA_KEY, saved);
end

-- MARK: Bars and their settings

local function CustomDef(entry)
	return { key = "Custom" .. entry.Id, id = entry.Id, title = "Bar " .. entry.Id, keys = "click only",
		first = CUSTOM_BASE + entry.Id * CUSTOM_STRIDE + 1, custom = true };
end

-- Settings, with the list of bars made in BazUI tidied: a saved list can come
-- back keyed by strings, and bars saved by an older BazUI lack fields.
local function LoadSettings()
	if settings ~= nil then
		return settings;
	end
	settings = BazUI.Settings.Get("ActionBars");
	local list = {};
	for _, entry in pairs(settings.Custom) do
		if type(entry) == "table" and tonumber(entry.Id) ~= nil then
			entry.Id = tonumber(entry.Id);
			for field, default in pairs({ Shown = true, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 }) do
				if entry[field] == nil then
					entry[field] = default;
				end
			end
			table.insert(list, entry);
		end
	end
	-- In Id order. A plain insertion sort: a handful of bars, and nothing for
	-- odd saved data to trip (table.sort can hand its comparison a nil).
	for i = 2, #list do
		local entry, j = list[i], i - 1;
		while j >= 1 and list[j].Id > entry.Id do
			list[j + 1] = list[j];
			j = j - 1;
		end
		list[j + 1] = entry;
	end
	settings.Custom = list;
	return settings;
end

-- The game's bars, then the ones made in BazUI.
local function AllDefs()
	local defs = {};
	for _, def in ipairs(BARS) do
		table.insert(defs, def);
	end
	for _, entry in ipairs(settings.Custom) do
		table.insert(defs, CustomDef(entry));
	end
	return defs;
end

local function BarSettings(def)
	if not def.custom then
		return settings.Bars[def.key];
	end
	for _, entry in ipairs(settings.Custom) do
		if entry.Id == def.id then
			return entry;
		end
	end
end

local function SlotCount(def, place)
	local count = Clamp(place.Columns, 1, MAX_COLUMNS) * Clamp(place.Rows, 1, MAX_ROWS);
	return def.custom and count or math.min(count, GAME_SLOTS);
end

-- MARK: Slots

local function NoteDragFrom(cell)
	local ok, shortcut = pcall(function() return cell.slot:GetShortcut(); end);
	if ok and not IsEmpty(shortcut) then
		dragFrom = { cell = cell, type = shortcut:GetType(), data = shortcut:GetData(),
			time = Turbine.Engine.GetGameTime() };
	else
		dragFrom = nil;
	end
end

-- `cell` has just taken `shortcut` in a drop, replacing `previous` (a saved
-- entry, or nil). If the drop came from another BazUI slot, that slot gives
-- the skill up and takes `previous`: the two swap.
local function CompleteMove(cell, shortcut, previous)
	local from = dragFrom;
	dragFrom = nil;
	if from == nil or from.cell == cell or IsEmpty(shortcut)
		or Turbine.Engine.GetGameTime() - from.time > DRAG_WINDOW
		or shortcut:GetType() ~= from.type or shortcut:GetData() ~= from.data then
		return;
	end
	local source = from.cell;
	restoring = true; -- saved below, not by its ShortcutChanged
	pcall(function()
		if previous ~= nil then
			source.slot:SetShortcut(Turbine.UI.Lotro.Shortcut(previous.Type, previous.Data));
		else
			source.slot:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Undefined, ""));
		end
	end);
	restoring = false;
	saved[source.number] = previous;
	BazUI.Trace("bars: moved slot " .. source.number .. " to " .. cell.number ..
		(previous ~= nil and " (swapped)" or ""));
end

local function OnShortcutChanged(cell)
	if not restoring then
		local previous = saved[cell.number];
		local shortcut = cell.slot:GetShortcut();
		if IsEmpty(shortcut) then
			saved[cell.number] = nil;
		else
			saved[cell.number] = { Type = shortcut:GetType(), Data = shortcut:GetData() };
		end
		CompleteMove(cell, shortcut, previous);
		SaveSlots();
	end
end

local function Clear(cell)
	cell.slot:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Undefined, ""));
	-- Saved here too rather than relying on ShortcutChanged for a change made in code.
	saved[cell.number] = nil;
	SaveSlots();
end

-- Puts a saved shortcut back; items can fail until the inventory has loaded,
-- so those are kept and retried.
local function Restore(number)
	local cell, entry = cellsByNumber[number], saved[number];
	if cell == nil or entry == nil then
		return true;
	end
	restoring = true;
	local ok = pcall(function()
		cell.slot:SetShortcut(Turbine.UI.Lotro.Shortcut(entry.Type, entry.Data));
	end);
	restoring = false;
	return ok and not IsEmpty(cell.slot:GetShortcut());
end

local function CreateCell(bar, index)
	local cell = Turbine.UI.Control();
	cell:SetParent(bar.window);
	cell:SetSize(SLOT, SLOT);
	cell:SetBackColor(BACKDROP_COLOR);
	cell.bar = bar;
	cell.number = bar.def.first + index - 1;

	local slot = Turbine.UI.Lotro.Quickslot();
	slot:SetParent(cell);
	slot:SetSize(SLOT, SLOT);
	slot:SetAllowDrop(AcceptsDrops());
	slot:SetUseOnRightClick(false); -- right-click is for Shift+right-click to clear
	slot.ShortcutChanged = BazUI.Guard("bars ShortcutChanged", function(sender, args)
		OnShortcutChanged(cell);
	end);
	slot.MouseClick = function(sender, args)
		dragFrom = nil; -- that press was a click, not the start of a drag
		if args.Button == Turbine.UI.MouseButton.Right and Turbine.UI.Control.IsShiftKeyDown() then
			Clear(cell);
		end
	end
	slot.DragStart = function(sender, args)
		dragStartSeen = true;
		NoteDragFrom(cell);
	end
	slot.MouseDown = function(sender, args)
		if not dragStartSeen and args.Button == Turbine.UI.MouseButton.Left then
			NoteDragFrom(cell);
		end
	end
	cell.slot = slot;

	if bar.def.prefix ~= nil then
		local label = Turbine.UI.Label();
		label:SetParent(cell);
		-- Inside the frame's ring (about 3 in from each edge, rounder at the corners).
		label:SetPosition(4, 3);
		label:SetSize(SLOT - 9, 14);
		label:SetFont(Turbine.UI.Lotro.Font.Verdana12);
		label:SetFontStyle(Turbine.UI.FontStyle.Outline);
		label:SetOutlineColor(Turbine.UI.Color(1, 0, 0, 0));
		label:SetForeColor(KEY_COLOR);
		label:SetTextAlignment(Turbine.UI.ContentAlignment.TopRight);
		label:SetText(bar.def.prefix .. KEYS[index]);
		label:SetZOrder(5);
		label:SetMouseVisible(false);
	end

	local flash = Turbine.UI.Control();
	flash:SetParent(cell);
	flash:SetSize(SLOT, SLOT);
	flash:SetBackColor(FLASH_COLOR);
	flash:SetZOrder(10);
	flash:SetMouseVisible(false);
	flash:SetVisible(false);
	cell.flash = flash;

	-- The frame: part of the slot, so it layers with the bar (under the
	-- game's windows, over the skill). Its art is twice the slot's size:
	-- set at that size, then stretched down to the slot.
	local frame = Turbine.UI.Control();
	frame:SetParent(cell);
	frame:SetBackground(FRAME_ART);
	frame:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
	frame:SetSize(FRAME_PX, FRAME_PX);
	frame:SetStretchMode(1);
	frame:SetSize(SLOT, SLOT);
	-- Stretched controls need their edges pinned to scale with the UI.
	pcall(function()
		local Same = Turbine.UI.EdgeAttachmentType.Same;
		frame:AttachEdges(Same, Same, Same, Same);
	end);
	frame:SetZOrder(4);
	frame:SetMouseVisible(false);
	cell.frame = frame;

	cellsByNumber[cell.number] = cell;
	-- A slot made after the saved ones were put back (the bar grew) gets its own.
	if ready then
		Restore(cell.number);
	end
	return cell;
end

-- MARK: Laying bars out

-- Slots in rows of `Columns`, as many as Columns x Rows allows.
local function Layout(bar)
	local columns = Clamp(bar.place.Columns, 1, MAX_COLUMNS);
	local count = SlotCount(bar.def, bar.place);
	local rows = math.ceil(count / columns);
	for index = #bar.cells + 1, count do
		bar.cells[index] = CreateCell(bar, index);
	end
	for index, cell in ipairs(bar.cells) do
		local x = ((index - 1) % columns) * (SLOT + GAP);
		local y = math.floor((index - 1) / columns) * (SLOT + GAP);
		local shown = index <= count;
		cell:SetPosition(x, y);
		cell:SetVisible(shown);
		cell.frame:SetVisible(settings.Frames);
	end
	local width = columns * SLOT + (columns - 1) * GAP;
	local height = rows * SLOT + (rows - 1) * GAP;
	bar.window:SetSize(width, height);
	bar.fit();
end

-- The game's bars stack upward from just above the XP bar, bottom centre;
-- bars made in BazUI start in the middle of the screen.
local function DefaultPosition(bar)
	local Display = Turbine.UI.Display;
	local scale = Scale(bar.window);
	local width, height = bar.window:GetWidth() * scale, bar.window:GetHeight() * scale;
	local left = math.floor((Display.GetWidth() - width) / 2);
	if bar.def.custom then
		return left, math.floor(Display.GetHeight() * 0.4 - height / 2);
	end
	local bottom = Display.GetHeight() - ((BazUI.XP.HEIGHT or 14) + STACK_GAP) * scale;
	for i = 1, bar.def.stackIndex - 1 do
		local below = bars[BARS[i].key];
		if below ~= nil then
			bottom = bottom - below.window:GetHeight() * Scale(below.window) - STACK_GAP * scale;
		end
	end
	return left, math.floor(bottom - height - STACK_GAP * scale);
end

local function Place(bar)
	local Display = Turbine.UI.Display;
	local left, top = bar.place.Left, bar.place.Top;
	if left < 0 or top < 0 or left > Display.GetWidth() - 50 or top > Display.GetHeight() - 20 then
		left, top = DefaultPosition(bar);
	end
	bar.window:SetPosition(left, top);
end

-- Default spots depend on the bars below, so they all go round again.
local function PlaceAll()
	for _, def in ipairs(AllDefs()) do
		if bars[def.key] ~= nil then
			Place(bars[def.key]);
		end
	end
end

-- One window per bar, so each can be moved on its own.
local function CreateBar(def)
	local bar = { def = def, place = BarSettings(def), cells = {} };
	local w = Turbine.UI.Window();
	w:SetBackColor(Turbine.UI.Color(0, 0, 0, 0));
	bar.window = w;

	bar.fit = BazUI.Layout.MakeMovable("bar " .. def.key, w, function(left, top)
		bar.place.Left, bar.place.Top = left, top;
	end);
	Layout(bar);

	-- After a scale change: back to the default spot if it hasn't been moved.
	bar.reapply = BazUI.Scaling.Attach(w, PlaceAll, function() return bar.place.Scale; end);
	Place(bar);
	bars[def.key] = bar;
	return bar;
end

local function ShowBars()
	for _, bar in pairs(bars) do
		local shown = enabled and bar.place.Shown;
		bar.window:SetVisible(shown);
		Layout(bar);
	end
end

-- MARK: Flashes and retries

local function ApplyLock()
	local accept = AcceptsDrops();
	for _, bar in pairs(bars) do
		for _, cell in ipairs(bar.cells) do
			cell.slot:SetAllowDrop(accept);
		end
	end
end

-- Asked of the Control class, or failing that of a control.
local function ShiftIsDown()
	local ok, down = pcall(Turbine.UI.Control.IsShiftKeyDown);
	if not ok then
		ok, down = pcall(function() return ticker:IsShiftKeyDown(); end);
	end
	return ok and down == true;
end

local function WatchingShift()
	return enabled and settings.Locked;
end

local function OnUpdate()
	local now = Turbine.Engine.GetGameTime();
	if WatchingShift() then
		local down = ShiftIsDown();
		if down ~= shiftDown then
			shiftDown = down;
			ApplyLock();
		end
	end
	for cell, ends in pairs(flashing) do
		if now >= ends then
			cell.flash:SetVisible(false);
			flashing[cell] = nil;
		end
	end
	if #retryAt > 0 and now >= retryAt[1] then
		table.remove(retryAt, 1);
		local still = {};
		for _, number in ipairs(pending) do
			if not Restore(number) then
				table.insert(still, number);
			end
		end
		pending = still;
		if #pending == 0 then
			retryAt = {};
		elseif #retryAt == 0 then
			BazUI.Log.Write("bars: " .. #pending .. " slot(s) still empty after retrying");
		end
	end
	if next(flashing) == nil and #retryAt == 0 and not WatchingShift() then
		ticker:SetWantsUpdates(false);
	end
end

local function OnAction(action)
	local cell = enabled and cellsByNumber[ACTION_SLOT[action]];
	if cell and cell:IsVisible() and cell.bar.window:IsVisible() then
		cell.flash:SetVisible(true);
		flashing[cell] = Turbine.Engine.GetGameTime() + FLASH_TIME;
		ticker:SetWantsUpdates(true);
	end
end

local function RestoreAll()
	pending = {};
	for number in pairs(saved) do
		if not Restore(number) then
			table.insert(pending, number);
		end
	end
	ready = true;
	if #pending > 0 then
		-- Soon, then less often for a couple of minutes, for a slow load.
		local now = Turbine.Engine.GetGameTime();
		retryAt = {};
		for _, delay in ipairs({ 3, 10, 20, 35, 60, 90, 120 }) do
			table.insert(retryAt, now + delay);
		end
		BazUI.Log.Write("bars: " .. #pending .. " slot(s) didn't load yet, retrying");
		ticker:SetWantsUpdates(true);
	end
end

local function Create()
	LoadSettings();

	local ok, data = pcall(Turbine.PluginData.Load, Turbine.DataScope.Character, DATA_KEY);
	saved = {};
	if ok and type(data) == "table" then
		-- Saved keys can come back as strings; slot numbers are numbers.
		for number, entry in pairs(data) do
			if tonumber(number) ~= nil and type(entry) == "table" then
				saved[tonumber(number)] = entry;
			end
		end
	end

	-- A 1x1 transparent window that stays shown, so it ticks whichever bars
	-- are visible.
	ticker = Turbine.UI.Window();
	ticker:SetSize(1, 1);
	ticker:SetBackColor(Turbine.UI.Color(0, 0, 0, 0));
	ticker:SetMouseVisible(false);
	ticker:SetVisible(true);
	ticker.Update = BazUI.Guard("bars Update", OnUpdate);

	for _, def in ipairs(AllDefs()) do
		CreateBar(def);
	end
	RestoreAll();
	BazUI.Events.OnAction("bars", OnAction);
end

-- MARK: Making and removing bars

local function NewBar()
	local id = math.max(1, tonumber(settings.NextId) or 1);
	for _, entry in ipairs(settings.Custom) do
		id = math.max(id, entry.Id + 1);
	end
	settings.NextId = id + 1;
	local entry = { Id = id, Shown = true, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 };
	table.insert(settings.Custom, entry);
	local def = CustomDef(entry);
	if ticker ~= nil then
		CreateBar(def);
		ShowBars();
	end
	return def;
end

-- Its window can't be destroyed, so it's hidden for good and forgotten; its
-- slots are forgotten too (for this character - others' are just unused).
local function DeleteBar(def)
	for i, entry in ipairs(settings.Custom) do
		if entry.Id == def.id then
			table.remove(settings.Custom, i);
			break;
		end
	end
	local bar = bars[def.key];
	if bar ~= nil then
		bar.window:SetVisible(false);
		for _, cell in ipairs(bar.cells) do
			cellsByNumber[cell.number] = nil;
			flashing[cell] = nil;
		end
		bars[def.key] = nil;
	end
	for number = def.first, def.first + MAX_COLUMNS * MAX_ROWS - 1 do
		saved[number] = nil;
	end
	SaveSlots();
end

-- MARK: Module

-- Module switch (General tab).
function ActionBars.Enable()
	if ticker == nil then
		Create();
	end
	enabled = true;
	ShowBars();
	ticker:SetWantsUpdates(true); -- watches Shift while locked; idles otherwise
end

function ActionBars.Disable()
	enabled = false;
	if ticker ~= nil then
		ShowBars();
	end
end

function ActionBars.ResetPositions()
	for _, def in ipairs(AllDefs()) do
		local place = BarSettings(def);
		place.Left, place.Top = -1, -1;
	end
	PlaceAll();
end

-- The Action bars settings tab. `form` is a BazUI.Options form.
function ActionBars.BuildOptions(form)
	LoadSettings(); -- the tab can open while the module is off
	local defs = AllDefs();

	form:Heading("Bars");
	for _, def in ipairs(defs) do
		local place = BarSettings(def);
		form:Check(def.title .. " (" .. def.keys .. ")", place.Shown, function(on)
			place.Shown = on;
			if ticker ~= nil then
				ShowBars();
			end
		end);
	end
	form:Button("New bar", function()
		settings.Editing = NewBar().key;
		BazUI.Options.Refresh();
	end);

	-- One bar at a time: pick it, then its layout and size.
	local editing = defs[1];
	for _, def in ipairs(defs) do
		if def.key == settings.Editing then
			editing = def;
		end
	end
	local place = BarSettings(editing);
	local function Changed()
		local bar = bars[editing.key];
		if bar ~= nil then
			Layout(bar);
			bar.reapply();
			PlaceAll();
		end
	end

	form:Heading("Edit a bar");
	local choices = {};
	for _, def in ipairs(defs) do
		table.insert(choices, { def.key, def.title });
	end
	form:Cycle("Editing", choices, editing.key, function(key)
		settings.Editing = key;
		BazUI.Options.Refresh();
	end);
	form:Slider("Columns", 1, MAX_COLUMNS, Clamp(place.Columns, 1, MAX_COLUMNS), function(value)
		place.Columns = value;
		Changed();
	end);
	form:Slider("Rows", 1, MAX_ROWS, Clamp(place.Rows, 1, MAX_ROWS), function(value)
		place.Rows = value;
		Changed();
	end);
	local percent = SCALE_STEP * math.floor((tonumber(place.Scale) or 1) * 100 / SCALE_STEP + 0.5);
	form:Slider("Size, % of the UI scale", SCALE_MIN, SCALE_MAX, percent, function(value)
		place.Scale = value / 100;
		Changed();
	end, SCALE_STEP);
	if not editing.custom then
		form:Note("The game's bars have twelve slots, so columns x rows above twelve still shows twelve.");
	end
	form:Button("Back to its default spot", function()
		place.Left, place.Top = -1, -1;
		PlaceAll();
	end);
	if editing.custom then
		local armed = false;
		local delete;
		delete = form:Button("Delete this bar", function()
			if not armed then
				armed = true;
				delete:SetText("Click again to delete " .. editing.title);
				return;
			end
			DeleteBar(editing);
			settings.Editing = nil;
			BazUI.Options.Refresh();
		end);
	end

	form:Heading("Look");
	form:Check("Button frames (gold, like the menu)", settings.Frames, function(on)
		settings.Frames = on;
		if ticker ~= nil then
			ShowBars();
		end
	end);

	form:Heading("Place");
	form:Button("All bars back to their default spots", ActionBars.ResetPositions);
	form:Note("Move a bar anywhere with the game's layout mode (Ctrl+\\): the bars light up and can be dragged.");

	form:Heading("Using them");
	form:Check("Locked: hold Shift to put skills on, move them or empty slots", settings.Locked, function(on)
		settings.Locked = on;
		shiftDown = false;
		ApplyLock();
		if ticker ~= nil and enabled then
			ticker:SetWantsUpdates(true);
		end
	end);
	form:Note("Drag a skill or item onto a slot, or from one slot to another to move it (with Shift held while locked); Shift+right-click a slot to empty it. Bars made here are clicked only. Each of the game's six stands in for the game's bar with the same keys - give a slot the same skill as the game's slot with its key. Pressing a key flashes the BazUI slot it fires.");
end
