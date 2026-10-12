-- ClassBar/ClassBar.lua
-- Your class's resource, in BazUI's dark-and-gold look. Each class that has
-- one gets a "provider" below saying how to read it and how to draw it; a
-- class without one simply shows nothing. So far: the Rune-keeper.
--
-- It can dock above your unit frame - same width, following it when it
-- moves - or stand on its own. By default it's just the pips, no panel.
--
-- Rune-keeper attunement runs 0-20 with 10 neutral (lotro-wiki.com, Attunement):
-- battle attunement lights red pips out to the left of the gold centre mark,
-- healing attunement green pips out to the right, nine each way. The centre
-- mark glows while the Rune-keeper is charged.

BazUI.ClassBar = {};
local ClassBar = BazUI.ClassBar;

local PIP_W, PIP_H = 14, 10;
local PIP_GAP = 3;
local CENTER_W = 16;
local PAD = 6;
local SIDE = 9;                 -- pips each way from the centre
local LABEL_H = 14;
local DOCK_GAP = 3;             -- between the docked bar and the frame under it

-- Colors are alpha, r, g, b.
local BACK_COLOR = Turbine.UI.Color(0.80, 0.05, 0.04, 0.03);
local BORDER_GOLD = { 0.90, 0.69, 0.55, 0.28 };   -- the menu's gold, through BazUI.Accent
local PIP_OFF_COLOR = Turbine.UI.Color(0.90, 0.27, 0.23, 0.18);
local BATTLE_COLOR = Turbine.UI.Color(1, 0.82, 0.24, 0.16);
local HEAL_COLOR = Turbine.UI.Color(1, 0.26, 0.68, 0.30);
local CENTER_COLOR = Turbine.UI.Color(1, 0.69, 0.55, 0.28);
local CHARGED_COLOR = Turbine.UI.Color(1, 1.00, 0.86, 0.45);
local TEXT_GOLD = { 1, 0.93, 0.86, 0.62 };

local settings, player, attributes, window, label, center;
local pips = { battle = {}, heal = {} };
local provider;
local enabled = false;

local function Call(object, method)
	if object == nil then
		return nil;
	end
	local ok, value = pcall(function() return object[method](object); end);
	if ok then
		return value;
	end
end

-- Width of the pip row: nine pips, the centre mark, nine pips.
local ROW_W = 2 * SIDE * PIP_W + CENTER_W + 2 * SIDE * PIP_GAP;

local function Refresh()
	if provider ~= nil then
		provider.refresh();
	end
end

local providers = {
	RuneKeeper = {
		events = { "AttunementChanged", "IsChargedChanged" },
		refresh = function()
			local value = Call(attributes, "GetAttunement");
			if value == nil then
				return;
			end
			-- Pip k (1 = next to the centre) lights when attunement reaches it.
			local battle = math.max(0, 10 - value);
			local heal = math.max(0, value - 10);
			for k = 1, SIDE do
				pips.battle[k]:SetBackColor(k <= battle and BATTLE_COLOR or PIP_OFF_COLOR);
				pips.heal[k]:SetBackColor(k <= heal and HEAL_COLOR or PIP_OFF_COLOR);
			end
			center:SetBackColor(Call(attributes, "IsCharged") and CHARGED_COLOR or CENTER_COLOR);

			if battle > 0 then
				label:SetText("Battle " .. battle);
			elseif heal > 0 then
				label:SetText("Healing " .. heal);
			else
				label:SetText("Neutral");
			end
		end,
	},
};

local function ClassName()
	local class = Call(player, "GetClass");
	for name, value in pairs(Turbine.Gameplay.Class) do
		if value == class and type(name) == "string" then
			return name;
		end
	end
end

local function Height()
	return PAD + (settings.ShowLabel and LABEL_H or 0) + PIP_H + PAD;
end

-- The unit frame's window to dock under, or nil to stand alone.
local function DockTarget()
	if settings.Dock and BazUI.UnitFrames ~= nil and BazUI.UnitFrames.GetPlayerWindow ~= nil then
		return BazUI.UnitFrames.GetPlayerWindow();
	end
end

local function Scale(control)
	local ok, scale = pcall(function() return control:GetScale(); end);
	return (ok and type(scale) == "number" and scale > 0) and scale or 1;
end

local function Layout()
	local top = PAD + (settings.ShowLabel and LABEL_H or 0);
	label:SetVisible(settings.ShowLabel);
	window:SetHeight(Height());
	window.back:SetHeight(Height() - 2);

	-- The panel - dark, gold border - is optional; without it, just the pips.
	if settings.Panel then
		BazUI.Accent.Bind(window, "SetBackColor", BORDER_GOLD);
	else
		BazUI.Accent.Unbind(window, "SetBackColor");
		window:SetBackColor(Turbine.UI.Color(0, 0, 0, 0));
	end
	window.back:SetVisible(settings.Panel);

	-- Docked it takes the frame's width and the pips stretch to fill it.
	local dock = DockTarget();
	local width = dock and dock:GetWidth() or (ROW_W + 2 * PAD);
	local row = width - 2 * PAD;
	local pipW = dock and math.floor((row - CENTER_W - 2 * SIDE * PIP_GAP) / (2 * SIDE)) or PIP_W;
	local used = 2 * SIDE * pipW + CENTER_W + 2 * SIDE * PIP_GAP;
	window:SetWidth(width);
	window.back:SetWidth(width - 2);
	label:SetWidth(row);

	-- Battle pips run leftward from the centre, healing pips rightward.
	local centerX = PAD + math.floor((row - used) / 2) + SIDE * (pipW + PIP_GAP);
	for k = 1, SIDE do
		pips.battle[k]:SetWidth(pipW);
		pips.heal[k]:SetWidth(pipW);
		pips.battle[k]:SetPosition(centerX - k * (pipW + PIP_GAP), top);
		pips.heal[k]:SetPosition(centerX + CENTER_W + PIP_GAP + (k - 1) * (pipW + PIP_GAP), top);
	end
	center:SetPosition(centerX, top - 2);
end

local function DefaultPosition()
	local Display = Turbine.UI.Display;
	local scale = 1;
	pcall(function() scale = window:GetScale(); end);
	local width = (ROW_W + 2 * PAD) * scale;
	-- Centred, a little above the middle of the lower half: over the action bars.
	return math.floor((Display.GetWidth() - width) / 2), math.floor(Display.GetHeight() * 0.80);
end

local function Place()
	-- Docked: just above the frame.
	local dock = DockTarget();
	if dock ~= nil then
		window:SetPosition(dock:GetLeft(), dock:GetTop() - math.floor((Height() + DOCK_GAP) * Scale(window) + 0.5));
		return;
	end

	local Display = Turbine.UI.Display;
	local left, top = settings.Left, settings.Top;
	if left < 0 or top < 0 or left > Display.GetWidth() - 50 or top > Display.GetHeight() - 20 then
		left, top = DefaultPosition();
	end
	window:SetPosition(left, top);
end

-- Docking can change with the frame (moved, shown, hidden) or the setting.
local function Redock()
	if window ~= nil then
		Layout();
		Place();
	end
end

local function Pip()
	local pip = Turbine.UI.Control();
	pip:SetParent(window);
	pip:SetSize(PIP_W, PIP_H);
	pip:SetBackColor(PIP_OFF_COLOR);
	pip:SetMouseVisible(false);
	return pip;
end

local function Create()
	settings = BazUI.Settings.Get("ClassBar");
	player = Turbine.Gameplay.LocalPlayer.GetInstance();
	local class = ClassName();
	provider = class and providers[class];
	BazUI.Log.Write("classbar: class " .. tostring(class) .. (provider and "" or " - nothing to show"));
	if provider == nil then
		return;
	end
	attributes = player:GetClassAttributes();

	window = Turbine.UI.Window();
	window:SetWidth(ROW_W + 2 * PAD);
	BazUI.Accent.Bind(window, "SetBackColor", BORDER_GOLD);

	local back = Turbine.UI.Control();
	back:SetParent(window);
	back:SetPosition(1, 1);
	back:SetWidth(ROW_W + 2 * PAD - 2);
	back:SetBackColor(BACK_COLOR);
	back:SetMouseVisible(false);
	window.back = back;

	label = Turbine.UI.Label();
	label:SetParent(window);
	label:SetPosition(PAD, PAD - 2);
	label:SetSize(ROW_W, LABEL_H);
	label:SetFont(Turbine.UI.Lotro.Font.Verdana12);
	BazUI.Accent.Bind(label, "SetForeColor", TEXT_GOLD);
	label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	label:SetMouseVisible(false);

	for k = 1, SIDE do
		pips.battle[k] = Pip();
		pips.heal[k] = Pip();
	end
	center = Turbine.UI.Control();
	center:SetParent(window);
	center:SetSize(CENTER_W, PIP_H + 4);
	center:SetBackColor(CENTER_COLOR);
	center:SetMouseVisible(false);

	Layout();
	BazUI.Scaling.Attach(window, Place);
	Place();
	BazUI.Layout.MakeMovable("classbar", window, function(left, top)
		if DockTarget() ~= nil then
			Place(); -- docked: it goes where the frame goes
		else
			settings.Left, settings.Top = left, top;
		end
	end);
	if BazUI.UnitFrames.OnPlayerFrameChanged ~= nil then
		BazUI.UnitFrames.OnPlayerFrameChanged(Redock);
	end

	local handler = BazUI.Guard("classbar", function(sender, args)
		Refresh();
	end);
	for _, event in ipairs(provider.events) do
		attributes[event] = handler;
	end
	Refresh();
end

local function Show()
	if window ~= nil then
		window:SetVisible(enabled and settings.Shown);
	end
end

-- Module switch (General tab).
function ClassBar.Enable()
	if player == nil then
		Create();
	end
	enabled = true;
	Show();
end

function ClassBar.Disable()
	enabled = false;
	Show();
end

-- The Class bar settings tab. `form` is a BazUI.Options form.
function ClassBar.BuildOptions(form)
	settings = settings or BazUI.Settings.Get("ClassBar"); -- the tab can open while the module is off
	if player ~= nil and provider == nil then
		form:Note("Your class has no bar in BazUI yet - so far it draws Rune-keeper attunement.");
		return;
	end
	form:Check("Show the bar", settings.Shown, function(on)
		settings.Shown = on;
		Show();
	end);
	form:Check("Dock above your unit frame (off: a bar of its own, moved in layout mode)", settings.Dock, function(on)
		settings.Dock = on;
		Redock();
	end);
	form:Check("Dark panel with a gold border behind it", settings.Panel, function(on)
		settings.Panel = on;
		if window ~= nil then
			Layout();
		end
	end);
	form:Check("Show the attunement in words above the pips", settings.ShowLabel, function(on)
		settings.ShowLabel = on;
		Redock(); -- its height changes, and docked that moves it
	end);
	form:Button("Back to its default spot", function()
		settings.Left, settings.Top = -1, -1;
		if window ~= nil then
			Place();
		end
	end);
	form:Note("Undocked, move it with the game's layout mode (Ctrl+\\). While this module is on, the BazUI skin hides the game's own attunement display (see the Skin tab).");
end
