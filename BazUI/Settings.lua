-- Settings.lua
-- Account-wide saved settings shared by every BazUI module. Each module owns
-- one section (e.g. Settings.Get("Bags")) and edits that table in place;
-- everything is written to disk on unload and every couple of minutes.

BazUI.Settings = {};

local KEY = "BazUI_Settings";

local defaults = {
	Core = { Debug = false, Modules = { Bags = true, ActionBars = true, Menu = true, UnitFrames = true, ClassBar = true, XP = true },
		Grid = { Enabled = true, Spacing = 40 } },
	Bags = { Left = 200, Top = 200, Visible = false, View = "categories", Collapsed = {},
		Columns = 10, RarityBorder = true, ShowMoney = true, Pins = {} },
	XP = { Width = 900, Left = -1, Top = -1 }, -- -1: not placed yet, centre it at the bottom
	ClassBar = { Shown = true, Dock = true, Panel = false, ShowLabel = false, Left = -1, Top = -1 },
	UnitFrames = { HideGameFrames = true, Numbers = "value",
		Player = { Shown = true, Left = -1, Top = -1 }, Target = { Shown = true, Left = -1, Top = -1 } },
	-- The game's six bars by name; bars made in BazUI in Custom, by Id.
	ActionBars = { Frames = true, Locked = true, NextId = 1, Custom = {}, Bars = {
		Main = { Shown = true, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
		Ctrl = { Shown = true, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
		Alt = { Shown = false, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
		Shift = { Shown = false, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
		Extra1 = { Shown = false, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
		Extra2 = { Shown = false, Left = -1, Top = -1, Columns = 12, Rows = 1, Scale = 1 },
	} },
	Options = { Left = -1, Top = -1, Tab = "General" },
	-- The BazUI skin's parts (Skin tab), read by Skin/build_skin.py.
	Skin = { Toolbar = true, Radar = true, CastBar = true, Buffs = true, QuestTracker = true, Windows = true },
	-- First guesses at what the game's menu buttons open, left to right; the
	-- Menu tab corrects them.
	Menu = { AlwaysShow = false, Left = -1, Top = -1, Slots = { "options", "crafting", "social", "character", "quests",
		"deeds", "traits", "help", "fellowship" } },
};

local data = {};

-- Fill in anything missing from a saved file (new settings, older versions).
local function ApplyDefaults(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then
				target[k] = {};
			end
			ApplyDefaults(target[k], v);
		elseif target[k] == nil then
			target[k] = v;
		end
	end
end

function BazUI.Settings.Load()
	local ok, loaded = pcall(Turbine.PluginData.Load, Turbine.DataScope.Account, KEY);
	if ok and type(loaded) == "table" then
		data = loaded;
	else
		data = {};
	end
	ApplyDefaults(data, defaults);
end

function BazUI.Settings.Save()
	Turbine.PluginData.Save(Turbine.DataScope.Account, KEY, data);
end

function BazUI.Settings.Get(section)
	return data[section];
end

-- Modules edit their settings in place, so as well as on unload (and when
-- the settings window closes) everything is written every couple of minutes:
-- a crash or a lost connection can't take more than that with it.
local AUTOSAVE_EVERY = 120; -- seconds

function BazUI.Settings.StartAutosave()
	local nextSave = Turbine.Engine.GetGameTime() + AUTOSAVE_EVERY;
	local ticker = Turbine.UI.Window();
	ticker:SetSize(1, 1);
	ticker:SetBackColor(Turbine.UI.Color(0, 0, 0, 0));
	ticker:SetMouseVisible(false);
	ticker:SetVisible(true);
	ticker.Update = function(sender, args)
		local now = Turbine.Engine.GetGameTime();
		if now >= nextSave then
			nextSave = now + AUTOSAVE_EVERY;
			local ok, err = pcall(BazUI.Settings.Save);
			if not ok then
				BazUI.Log.Error("autosave: " .. tostring(err));
			end
		end
	end
	ticker:SetWantsUpdates(true);
end
