-- Menu/Menu.lua
-- BazUI's micro menu: a row of icons along the top of the screen that fades
-- in when the cursor comes near it and out when it leaves.
--
-- The game's own menu buttons are still there underneath - the BazUI skin
-- makes them invisible - and they do the work: opening panels, tooltips.
-- This window ignores the mouse, so every click goes straight through to
-- them. Menu/Geometry.lua, written by the skin builder, says where they are.
-- Which panel each button opens is set in the game's own UI Settings, so the
-- icon for each slot is picked in the Menu settings tab to match.
--
-- Moving it: the game's buttons only move when the skin is rebuilt, so in
-- layout mode (Ctrl+\) a "Menu" placeholder is dragged instead. Its spot is
-- saved (Menu.Left/Top, in points) for Skin/build_skin.py to pick up.

BazUI.Menu = {};
local Menu = BazUI.Menu;

local ICON_PX = 64              -- the icon images' size, in pixels
local FADE_TIME = 0.18          -- seconds from hidden to shown
local REACH = 14                -- points around the row that count as near it
local ICON_PATH = "Baz4k/BazUI/Menu/Icons/";

-- Every icon there is, in the order the settings tab cycles through them.
local ICONS = { "character", "skills", "traits", "quests", "deeds", "crafting", "social",
	"fellowship", "map", "mail", "housing", "reputation", "mounts", "collections",
	"instances", "options", "help", "none" };

local settings, window, buttons, bounds, placeholder;

-- The first guess at the slots had help twice; slot 7 is the traits button.
-- Settings still holding that guess untouched get it put right.
local function LoadSettings()
	if settings == nil then
		settings = BazUI.Settings.Get("Menu");
		local slots = settings.Slots;
		if slots[7] == "help" and slots[8] == "help" then
			slots[7] = "traits";
		end
	end
	return settings;
end
local pointsToScreen = 1;   -- screen units per game point
local icons = {};        -- slot -> { control, name, hover }
local opacity = 0;
local hovered;           -- slot under the cursor, or nil
local lastTime;
local enabled = false;

-- Shows the right image for a slot, only touching the control when it changes.
local function ShowIcon(slot, hover)
	local icon = icons[slot];
	local name = settings.Slots[slot] or "none";
	if icon.name == name and icon.hover == hover then
		return;
	end
	icon.name, icon.hover = name, hover;
	if name == "none" then
		icon.control:SetVisible(false);
	else
		icon.control:SetBackground(ICON_PATH .. name .. (hover and "_hover" or "") .. ".tga");
		icon.control:SetVisible(true);
	end
end

local function Inside(x, y, left, top, right, bottom)
	return x >= left and x < right and y >= top and y < bottom;
end

local function OnUpdate()
	local now = Turbine.Engine.GetGameTime();
	local dt = lastTime and math.min(now - lastTime, 0.1) or 0;
	lastTime = now;

	local mx, my = Turbine.UI.Display.GetMouseX(), Turbine.UI.Display.GetMouseY();
	local near = Inside(mx, my, bounds.left, bounds.top, bounds.right, bounds.bottom);

	local target = (near or settings.AlwaysShow or BazUI.Events.IsLayoutUnlocked()) and 1 or 0;
	if opacity ~= target then
		local step = dt / FADE_TIME;
		opacity = (target > opacity) and math.min(1, opacity + step) or math.max(0, opacity - step);
		window:SetOpacity(opacity);
	end

	local over;
	if near then
		for slot, b in ipairs(buttons) do
			if Inside(mx, my, b.left, b.top, b.right, b.bottom) then
				over = slot;
			end
		end
	end
	if over ~= hovered then
		if hovered ~= nil then ShowIcon(hovered, false); end
		if over ~= nil then ShowIcon(over, true); end
		hovered = over;
	end
end

local function Create()
	LoadSettings();
	local geometry = BazUI.MenuGeometry;
	local spots = geometry.Buttons;

	-- Geometry is in game points; plugin windows are placed in the screen
	-- coordinates the Display reports.
	local k = Turbine.UI.Display.GetWidth() / geometry.ScreenWidth;  -- screen units per point
	pointsToScreen = k;
	local first, last = spots[1], spots[#spots];
	local px = ICON_PX / first.Width;                                 -- icon pixels per point

	window = Turbine.UI.Window();
	window:SetMouseVisible(false);
	window:SetPosition(math.floor(first.Left * k + 0.5), math.floor(first.Top * k + 0.5));
	window:SetSize(math.ceil((last.Left + last.Width - first.Left) * px), ICON_PX);
	-- Laid out in icon pixels, drawn at the size the skin made the buttons.
	BazUI.Scaling.SetTotal(window, k / px);

	buttons = {};
	for slot, spot in ipairs(spots) do
		local control = Turbine.UI.Control();
		control:SetParent(window);
		control:SetPosition(math.floor((spot.Left - first.Left) * px + 0.5), 0);
		control:SetSize(ICON_PX, ICON_PX);
		control:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
		control:SetMouseVisible(false);
		icons[slot] = { control = control };
		ShowIcon(slot, false);

		buttons[slot] = { left = spot.Left * k, top = spot.Top * k,
			right = (spot.Left + spot.Width) * k, bottom = (spot.Top + spot.Height) * k };
	end
	bounds = { left = (first.Left - REACH) * k, top = 0,
		right = (last.Left + last.Width + REACH) * k, bottom = (first.Top + first.Height + REACH) * k };

	window:SetOpacity(0);
	window.Update = BazUI.Guard("menu Update", OnUpdate);
	BazUI.Log.Write("menu: " .. #spots .. " buttons, " .. string.format("%.3f", k) .. " screen units per point");
end

-- Whether the saved spot differs from where the skin put the menu - i.e.
-- the skin needs rebuilding.
local function MovePending()
	local first = BazUI.MenuGeometry.Buttons[1];
	if settings.Left < 0 then
		return false;
	end
	return math.abs(settings.Left - first.Left) > 1 or math.abs(settings.Top - first.Top) > 1;
end

local REBUILD = "python3 build_skin.py in Plugins/Baz4k/BazUI/Skin, then exit and relaunch the game";

-- The stand-in that's dragged in layout mode.
local function CreatePlaceholder()
	local spots = BazUI.MenuGeometry.Buttons;
	local first, last = spots[1], spots[#spots];
	local k = pointsToScreen;

	placeholder = Turbine.UI.Window();
	placeholder:SetSize(math.ceil((last.Left + last.Width - first.Left) * k), math.ceil(first.Height * k));
	placeholder:SetBackColor(Turbine.UI.Color(0.35, 0.10, 0.10, 0.10));
	BazUI.Scaling.Unscale(placeholder);
	if settings.Left >= 0 then
		placeholder:SetPosition(math.floor(settings.Left * k + 0.5), math.floor(settings.Top * k + 0.5));
	else
		placeholder:SetPosition(math.floor(first.Left * k + 0.5), math.floor(first.Top * k + 0.5));
	end

	local label = Turbine.UI.Label();
	label:SetParent(placeholder);
	label:SetSize(placeholder:GetWidth(), placeholder:GetHeight());
	label:SetFont(Turbine.UI.Lotro.Font.TrajanPro14);
	label:SetForeColor(Turbine.UI.Color(1, 0.95, 0.85, 0.55));
	label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	label:SetText("Menu");
	label:SetMouseVisible(false);

	BazUI.Layout.MakeMovable("menu", placeholder, function(left, top)
		settings.Left = math.floor(left / k + 0.5);
		settings.Top = math.floor(top / k + 0.5);
		BazUI.Settings.Save();
		if MovePending() then
			Turbine.Shell.WriteLine("BazUI: menu spot saved. To move the menu there, rebuild the skin: " .. REBUILD .. ".");
		end
	end);
	BazUI.Events.OnLayoutMode("menu placeholder", function(unlocked)
		placeholder:SetVisible(unlocked and enabled);
	end);
	placeholder:SetVisible(BazUI.Events.IsLayoutUnlocked() and enabled);
end

local function HasMenu()
	return BazUI.MenuGeometry ~= nil and #BazUI.MenuGeometry.Buttons > 0;
end

-- Module switch (General tab).
function Menu.Enable()
	if not HasMenu() then
		BazUI.Log.Write("menu: the skin isn't set to a BazUI menu, nothing to draw");
		return;
	end
	if window == nil then
		Create();
		CreatePlaceholder();
	end
	enabled = true;
	window:SetVisible(true);
	window:SetWantsUpdates(true);
end

function Menu.Disable()
	enabled = false;
	if window ~= nil then
		window:SetWantsUpdates(false);
		window:SetVisible(false);
		placeholder:SetVisible(false);
	end
end

-- The Menu settings tab. `form` is a BazUI.Options form.
function Menu.BuildOptions(form)
	LoadSettings(); -- the tab can open while the module is off
	if not HasMenu() then
		form:Note("The BazUI skin isn't set to draw a BazUI menu - it does while this module and the Skin tab's Toolbar switch are on. Rebuild it: " .. REBUILD .. ".");
		return;
	end

	form:Check("Always show the menu (no fade)", settings.AlwaysShow, function(on)
		settings.AlwaysShow = on;
	end);

	form:Heading("Place");
	form:Note("In layout mode (Ctrl+\\) a Menu box appears - drag it where you want the menu. The game's buttons move when the skin is rebuilt: " .. REBUILD .. ".");
	if MovePending() then
		form:Note("A new spot is saved and waiting for that rebuild.");
	end
	form:Button("Centre it again", function()
		settings.Left, settings.Top = -1, -1;
		BazUI.Settings.Save();
		if placeholder ~= nil then
			local first = BazUI.MenuGeometry.Buttons[1];
			placeholder:SetPosition(math.floor(first.Left * pointsToScreen + 0.5), math.floor(first.Top * pointsToScreen + 0.5));
		end
		Turbine.Shell.WriteLine("BazUI: the menu will be centred at the top after the skin is rebuilt.");
	end);

	form:Heading("Icons");
	form:Note("Each slot sits over one of the game's menu buttons. Hover a button for its tooltip, then click its slot here until the icon matches. Which panel a button opens is set in the game's UI Settings > Toolbar.");
	for slot = 1, #BazUI.MenuGeometry.Buttons do
		local button;
		local function Label()
			return "Slot " .. slot .. ":  " .. (settings.Slots[slot] or "none");
		end
		button = form:Button(Label(), function()
			local current, nextName = settings.Slots[slot] or "none", ICONS[1];
			for i, name in ipairs(ICONS) do
				if name == current then
					nextName = ICONS[i % #ICONS + 1];
				end
			end
			settings.Slots[slot] = nextName;
			button:SetText(Label());
			if window ~= nil then
				ShowIcon(slot, slot == hovered);
			end
		end);
	end
end
