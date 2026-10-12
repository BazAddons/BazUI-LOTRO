-- Main.lua
-- BazUI entry point: loads shared services, then each module.

import "Turbine";
import "Turbine.Gameplay";
import "Turbine.UI";
import "Turbine.UI.Lotro";

BazUI = {};
BazUI.Version = "007";

import "Baz4k.BazUI.Log";
BazUI.Log.Write("---- v" .. BazUI.Version .. " loading");

import "Baz4k.BazUI.Util";
import "Baz4k.BazUI.Settings";
import "Baz4k.BazUI.Scaling";
import "Baz4k.BazUI.Accent";
import "Baz4k.BazUI.Events";
import "Baz4k.BazUI.Layout";
import "Baz4k.BazUI.Grid";
import "Baz4k.BazUI.Options.Form";
import "Baz4k.BazUI.Options.SettingsWindow";
import "Baz4k.BazUI.Skin.Built";
import "Baz4k.BazUI.Skin.SkinTab";
import "Baz4k.BazUI.Bags.Categories";
import "Baz4k.BazUI.Bags.MoneyBar";
import "Baz4k.BazUI.Bags.BagWindow";
import "Baz4k.BazUI.ActionBars.ActionBars";
import "Baz4k.BazUI.Menu.Geometry";
import "Baz4k.BazUI.Menu.Menu";
import "Baz4k.BazUI.UnitFrames.UnitFrames";
import "Baz4k.BazUI.ClassBar.ClassBar";
import "Baz4k.BazUI.XP.Levels";
import "Baz4k.BazUI.XP.XPBar";

-- Every module, in settings-tab order. Each provides Enable() and Disable()
-- - switching one off hands its part of the interface back to the game -
-- and BuildOptions(form) for its settings tab.
BazUI.Modules = {
	{ key = "Bags", title = "Bags", about = "all your bags in one window", module = BazUI.Bags },
	{ key = "ActionBars", title = "Action bars", about = "action buttons with no chrome", module = BazUI.ActionBars },
	{ key = "Menu", title = "Menu", about = "the game menu, fading in on hover", module = BazUI.Menu },
	{ key = "UnitFrames", title = "Unit frames", about = "your frame and your target's", module = BazUI.UnitFrames },
	{ key = "ClassBar", title = "Class bar", about = "your class's resource (Rune-keeper attunement)", module = BazUI.ClassBar },
	{ key = "XP", title = "XP bar", about = "a slim experience bar", module = BazUI.XP },
};

BazUI.Settings.Load();
BazUI.Settings.StartAutosave();
local core = BazUI.Settings.Get("Core");
BazUI.Debug = core.Debug;

local function Find(key)
	for _, entry in ipairs(BazUI.Modules) do
		if entry.key == key then
			return entry;
		end
	end
end

function BazUI.IsModuleEnabled(key)
	return core.Modules[key] ~= false;
end

-- Runs a module's Enable or Disable on its own, so one failing reports
-- itself instead of taking the rest of BazUI down with it.
local function Switch(entry, on)
	local ok, err = pcall(on and entry.module.Enable or entry.module.Disable);
	if ok then
		BazUI.Log.Write(entry.key .. (on and " on" or " off"));
	else
		BazUI.Log.Error(entry.key .. " failed to switch " .. (on and "on" or "off") .. ": " .. tostring(err));
	end
end

function BazUI.SetModuleEnabled(key, on)
	local entry = Find(key);
	if entry == nil or BazUI.IsModuleEnabled(key) == on then
		return;
	end
	core.Modules[key] = on;
	BazUI.Settings.Save();
	Switch(entry, on);
end

function BazUI.SetDebug(on)
	BazUI.Debug = on;
	core.Debug = on;
	BazUI.Settings.Save(); -- so it survives a relog even if unload doesn't run
	BazUI.Log.Write("debug " .. (on and "on" or "off"));
end

BazUI.Events.Start();
BazUI.Grid.Start();
for _, entry in ipairs(BazUI.Modules) do
	if BazUI.IsModuleEnabled(entry.key) then
		Switch(entry, true);
	end
end

-- /bazui chat command
local command = Turbine.ShellCommand();

function command:Execute(cmd, args)
	local words = {};
	for word in string.gmatch(string.lower(args or ""), "%S+") do
		table.insert(words, word);
	end
	local verb = words[1];

	if verb == nil or verb == "settings" or verb == "options" then
		BazUI.Options.Toggle();
	elseif verb == "bags" then
		if words[2] == "view" then
			BazUI.Bags.ToggleView();
		else
			BazUI.Bags.Toggle();
		end
	elseif verb == "grid" then
		BazUI.Grid.Toggle();
	elseif verb == "xp" then
		BazUI.XP.Report();
	elseif verb == "scale" then
		local value = tonumber(words[2] or "");
		if value ~= nil and value >= 0.5 and value <= 4 then
			BazUI.Scaling.SetOverride(value);
			Turbine.Shell.WriteLine("BazUI scale set to " .. value .. " (/bazui scale auto follows the game again)");
		elseif words[2] == "auto" then
			BazUI.Scaling.SetOverride(nil);
			Turbine.Shell.WriteLine("BazUI scale follows the game's Global UI scale");
		elseif words[2] ~= nil then
			Turbine.Shell.WriteLine("BazUI: /bazui scale takes a number from 0.5 to 4, or auto");
		else
			BazUI.Scaling.Report(BazUI.Bags.GetWindow());
		end
	elseif verb == "dump" then
		BazUI.Log.DumpApi();
	elseif verb == "debug" then
		BazUI.SetDebug(not BazUI.Debug);
		Turbine.Shell.WriteLine("BazUI debug " .. (BazUI.Debug and "on" or "off"));
	else
		Turbine.Shell.WriteLine(self:GetHelp());
	end
end

function command:GetShortHelp()
	return "BazUI: /bazui opens the settings; /bazui help lists the rest";
end

function command:GetHelp()
	return "BazUI v" .. BazUI.Version .. "\n" ..
		"/bazui - open or close the settings\n" ..
		"/bazui bags - show or hide the bag window\n" ..
		"/bazui bags view - switch between categories and bag order (or right-click the bag)\n" ..
		"/bazui xp - print your level and XP (the bar itself moves in layout mode, Ctrl+\\)\n" ..
		"/bazui grid - show or hide the alignment grid (it also shows in layout mode)\n" ..
		"/bazui scale - print the UI scale values BazUI sees\n" ..
		"/bazui scale 2 - draw BazUI at that scale whatever the game reports; /bazui scale auto to follow the game\n" ..
		"/bazui debug - log what the game reports, for troubleshooting\n" ..
		"/bazui dump - write the game's API names to the log, for development";
end

local ok, added = pcall(Turbine.Shell.AddCommand, "bazui", command);
if not ok then
	BazUI.Log.Error("couldn't register /bazui: " .. tostring(added));
elseif added == false or added == 0 then
	BazUI.Log.Error("couldn't register /bazui: the game refused it (left over from an earlier load?)");
end

-- The game registers each loaded plugin by name in the global Plugins table;
-- older plugins use the `plugin` global or the Plugin class instead. Hook
-- whichever exist, and make sure unload runs once.
local unloaded = false;
local function Unload(sender, args)
	if unloaded then return end
	unloaded = true;
	BazUI.Log.Write("unloading");

	for _, step in ipairs({
		{ "restore game bags", BazUI.Bags.Destroy },
		{ "restore game unit frames", BazUI.UnitFrames.Destroy },
		{ "stop events", BazUI.Events.Stop },
		{ "save settings", BazUI.Settings.Save },
		{ "remove /bazui", function() Turbine.Shell.RemoveCommand(command) end },
	}) do
		local stepOk, err = pcall(step[2]);
		if not stepOk then
			BazUI.Log.Error("unload, " .. step[1] .. ": " .. tostring(err));
		end
	end

	BazUI.Log.Write("unloaded");
end

local me = (Plugins ~= nil and Plugins["BazUI"]) or plugin;
-- (Not a loop over the three: a nil first one would end ipairs early.)
if me ~= nil then me.Unload = Unload; end
if plugin ~= nil then plugin.Unload = Unload; end
if Turbine.Plugin ~= nil then Turbine.Plugin.Unload = Unload; end

-- BazUI's Options button in the Plugin Manager.
if me ~= nil then
	me.GetOptionsPanel = function(sender, args)
		return BazUI.Options.ManagerPanel();
	end
end

BazUI.Log.Write("loaded; plugin screen " .. Turbine.UI.Display.GetWidth() .. "x" .. Turbine.UI.Display.GetHeight());
Turbine.Shell.WriteLine("BazUI v" .. BazUI.Version .. " loaded. Type /bazui for settings.");
