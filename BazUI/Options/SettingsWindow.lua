-- Options/SettingsWindow.lua
-- BazUI's settings: a General tab for switching modules on and off, a Skin
-- tab for the parts of the game's interface the BazUI skin restyles, then one
-- tab per module. Opens with /bazui, or from BazUI's Options button in the
-- Plugin Manager. Changes apply as they're made.

BazUI.Options = BazUI.Options or {};
local Options = BazUI.Options;

local WIDTH = 720;           -- wide enough for General, Skin and a tab per module
local MIN_CONTENT_H = 200;   -- the window grows to fit each tab, never shorter than this
local PAD = 26;            -- inside the Lotro.Window frame
local TABS_TOP = 42;
local TAB_H = 24;
local TAB_GAP = 14;
local TAB_CHAR_W = 9;      -- rough TrajanPro14 character width, to size tabs
local CONTENT_TOP = TABS_TOP + TAB_H + 14;
local CONTENT_W = WIDTH - 2 * PAD;

-- Colors are alpha, r, g, b; golds are tables, shown through BazUI.Accent.
local TAB_ON_GOLD = { 1, 0.90, 0.78, 0.42 };
local TAB_OFF_COLOR = Turbine.UI.Color(1, 0.55, 0.55, 0.53);
local RULE_GOLD = { 0.5, 0.90, 0.78, 0.42 };

local settings, window, content, underline, managerPanel;
local tabs = {};   -- { key, title, build, label }

local function BuildGeneral(form)
	form:Heading("Modules");
	form:Note("Switch off anything you don't use. A module that's off hands its part of the interface back to the game, and comes back as you left it.");
	for _, entry in ipairs(BazUI.Modules) do
		form:Check(entry.title .. "  -  " .. entry.about, BazUI.IsModuleEnabled(entry.key), function(on)
			BazUI.SetModuleEnabled(entry.key, on);
		end);
	end

	form:Heading("Look");
	form:Cycle("Accent colour", BazUI.Accent.CHOICES, BazUI.Accent.Get(), function(name)
		BazUI.Accent.Set(name);
	end);
	form:Note("BazUI's own windows change at once. The game's windows, restyled by the skin, change when it's rebuilt (see the Skin tab).");

	BazUI.Grid.BuildOptions(form);

	form:Heading("Troubleshooting");
	form:Check("Debug logging (records what the game reports, in BazUI's log)", BazUI.Debug, function(on)
		BazUI.SetDebug(on);
	end);
	form:Note("BazUI v" .. BazUI.Version .. " by Baz4k. Type /bazui help for the chat commands.");
end

-- General and Skin first, then a tab for each module that has settings.
local function MakeTabs()
	tabs = {
		{ key = "General", title = "General", build = BuildGeneral },
		{ key = "Skin", title = "Skin", build = BazUI.Skin.BuildOptions },
	};
	for _, entry in ipairs(BazUI.Modules) do
		if entry.module.BuildOptions ~= nil then
			table.insert(tabs, {
				key = entry.key,
				title = entry.title,
				build = function(form)
					if not BazUI.IsModuleEnabled(entry.key) then
						form:Note("This module is off - switch it on in the General tab. Settings made here still apply when it's back.");
					end
					entry.module.BuildOptions(form);
				end,
			});
		end
	end
end

-- Rebuilt every time a tab is shown, so it always reflects the current
-- settings (some can also be changed from elsewhere, e.g. the bag's menu).
local function ShowTab(key)
	local chosen = tabs[1];
	for _, tab in ipairs(tabs) do
		if tab.key == key then
			chosen = tab;
		end
	end
	settings.Tab = chosen.key;

	for _, tab in ipairs(tabs) do
		if tab == chosen then
			BazUI.Accent.Bind(tab.label, "SetForeColor", TAB_ON_GOLD);
		else
			BazUI.Accent.Unbind(tab.label, "SetForeColor");
			tab.label:SetForeColor(TAB_OFF_COLOR);
		end
	end
	underline:SetPosition(chosen.label:GetLeft(), TABS_TOP + TAB_H - 2);
	underline:SetWidth(chosen.label:GetWidth());

	if content ~= nil then
		content:SetParent(nil);
	end
	content = Turbine.UI.Control();
	content:SetParent(window);
	content:SetPosition(PAD, CONTENT_TOP);
	content:SetWidth(CONTENT_W);

	local form = Options.Form(content, CONTENT_W);
	local ok, err = pcall(chosen.build, form);
	if not ok then
		BazUI.Log.Error("settings tab " .. chosen.key .. ": " .. tostring(err));
	end

	-- Fit the window to the tab.
	local height = math.max(form:Height(), MIN_CONTENT_H);
	content:SetHeight(height);
	window:SetHeight(CONTENT_TOP + height + PAD);
end

local function CreateTabStrip()
	local x = PAD;
	for _, tab in ipairs(tabs) do
		local width = #tab.title * TAB_CHAR_W + 8;
		local label = Turbine.UI.Label();
		label:SetParent(window);
		label:SetPosition(x, TABS_TOP);
		label:SetSize(width, TAB_H);
		label:SetFont(Turbine.UI.Lotro.Font.TrajanPro14);
		label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
		label:SetText(tab.title);
		label.MouseClick = function(sender, args)
			ShowTab(tab.key);
		end
		tab.label = label;
		x = x + width + TAB_GAP;
	end

	local rule = Turbine.UI.Control();
	rule:SetParent(window);
	rule:SetPosition(PAD, TABS_TOP + TAB_H);
	rule:SetSize(CONTENT_W, 1);
	BazUI.Accent.Bind(rule, "SetBackColor", RULE_GOLD);

	underline = Turbine.UI.Control();
	underline:SetParent(window);
	underline:SetHeight(2);
	BazUI.Accent.Bind(underline, "SetBackColor", TAB_ON_GOLD);
end

local function Create()
	settings = BazUI.Settings.Get("Options");
	MakeTabs();

	window = Turbine.UI.Lotro.Window();
	window:SetText("BazUI Settings");
	window:SetSize(WIDTH, CONTENT_TOP + MIN_CONTENT_H + PAD);

	local Display = Turbine.UI.Display;
	local left, top = settings.Left, settings.Top;
	if left < 0 or top < 0 or left > Display.GetWidth() - 100 or top > Display.GetHeight() - 100 then
		left = math.floor((Display.GetWidth() - WIDTH) / 2);
		top = math.floor(Display.GetHeight() / 6);
	end
	window:SetPosition(left, top);
	window.PositionChanged = function(sender, args)
		settings.Left, settings.Top = window:GetLeft(), window:GetTop();
	end

	window:SetWantsKeyEvents(true);
	window.KeyDown = function(sender, args)
		if args.Action == Turbine.UI.Lotro.Action.Escape then
			window:SetVisible(false);
		end
	end

	-- Closing the window is a natural moment to write the changes to disk.
	window.VisibleChanged = function(sender, args)
		if not window:IsVisible() then
			BazUI.Settings.Save();
		end
	end

	CreateTabStrip();
	BazUI.Scaling.Attach(window);
end

function Options.Show()
	if window == nil then
		Create();
	end
	ShowTab(settings.Tab);
	window:SetVisible(true);
end

-- Builds the open tab again, for a tab whose rows depend on a choice made in
-- it (which bar the Action bars tab is editing, say).
function Options.Refresh()
	if window ~= nil and window:IsVisible() then
		ShowTab(settings.Tab);
	end
end

function Options.Toggle()
	if window ~= nil and window:IsVisible() then
		window:SetVisible(false);
	else
		Options.Show();
	end
end

-- What BazUI's Options button in the Plugin Manager shows: a way in.
function Options.ManagerPanel()
	if managerPanel == nil then
		managerPanel = Turbine.UI.Control();
		managerPanel:SetSize(320, 64);

		local button = Turbine.UI.Lotro.Button();
		button:SetParent(managerPanel);
		button:SetPosition(10, 10);
		button:SetSize(220, 20);
		button:SetText("Open BazUI Settings");
		button.Click = function(sender, args)
			Options.Show();
		end

		local hint = Turbine.UI.Label();
		hint:SetParent(managerPanel);
		hint:SetPosition(10, 36);
		hint:SetSize(300, 20);
		hint:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		hint:SetText("Or type /bazui in chat.");
	end
	return managerPanel;
end
