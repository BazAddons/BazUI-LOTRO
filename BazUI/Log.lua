-- Log.lua
-- BazUI's log, saved through PluginData so problems can be read from disk
-- rather than copied out of chat:
--   Documents/The Lord of the Rings Online/PluginData/<account>/AllServers/BazUI_Log.plugindata
-- Load, unload and errors are always logged. Module chatter (BazUI.Trace)
-- is only kept while /bazui debug is on, and is echoed to chat as well.

BazUI.Log = {};
BazUI.Debug = false;

local KEY = "BazUI_Log";
local MAX_LINES = 300;

-- Keep the previous sessions' lines, so a load that failed partway still
-- shows up next to the one that worked.
local lines = {};
local ok, saved = pcall(Turbine.PluginData.Load, Turbine.DataScope.Account, KEY);
if ok and type(saved) == "table" then
	lines = saved;
end

function BazUI.Log.Write(text)
	table.insert(lines, string.format("%10.2f  %s", Turbine.Engine.GetGameTime(), text));
	while #lines > MAX_LINES do
		table.remove(lines, 1);
	end
	pcall(Turbine.PluginData.Save, Turbine.DataScope.Account, KEY, lines);
end

function BazUI.Log.Error(text)
	BazUI.Log.Write("ERROR " .. text);
	Turbine.Shell.WriteLine("BazUI error: " .. text);
end

function BazUI.Trace(text)
	if BazUI.Debug then
		BazUI.Log.Write(text);
		Turbine.Shell.WriteLine("BazUI " .. text);
	end
end

-- /bazui dump: writes what the live client really has in the parts of the API
-- BazUI builds on, one line per table, so modules are written against that
-- rather than against patch notes (which have been wrong before).
local DUMPS = {
	"Turbine.UI.Lotro.LotroUIElement",
	"Turbine.UI.Lotro.Action",
	"Turbine.UI.Lotro.ShortcutType",
	"Turbine.Gameplay.EquipmentSlot",
	"Turbine.UI.Lotro",
	"Turbine.UI.Lotro.Quickslot",
	"Turbine.UI.Lotro.Shortcut",
	"Turbine.UI.Lotro.EntityControl",
	"Turbine.UI",
	-- for scaling: the group names, and what Display offers
	"Turbine.UI.Lotro.UIScalingGroupType",
	"Turbine.UI.Display",
	-- for tinting art (the accent colour)
	"Turbine.UI.BlendMode",
	"Turbine.Gameplay",
	"Turbine.Gameplay.LocalPlayer",
	-- for the XP bar: where level and experience live, and the chat it can read
	"Turbine.Gameplay.Attributes",
	"Turbine.Gameplay.ClassAttributes",
	"Turbine.Gameplay.Player",
	"Turbine.Gameplay.Actor",
	"Turbine.Gameplay.Entity",
	"Turbine.Chat",
	"Turbine.ChatType",
};

local function Lookup(path)
	local value = _G;
	for part in string.gmatch(path, "[^%.]+") do
		if type(value) ~= "table" then
			return nil;
		end
		value = value[part];
	end
	return value;
end

function BazUI.Log.DumpApi()
	for _, path in ipairs(DUMPS) do
		local value = Lookup(path);
		if type(value) ~= "table" then
			BazUI.Log.Write("api " .. path .. ": " .. type(value));
		else
			local parts = {};
			for key, member in pairs(value) do
				local kind = type(member);
				if kind == "number" or kind == "string" or kind == "boolean" then
					table.insert(parts, tostring(key) .. "=" .. tostring(member));
				else
					table.insert(parts, tostring(key) .. "(" .. kind .. ")");
				end
			end
			table.sort(parts);
			BazUI.Log.Write("api " .. path .. ": " .. table.concat(parts, ", "));
		end
	end
	Turbine.Shell.WriteLine("BazUI: API names written to the log.");
end

-- Wraps an event handler so an error in it is logged (once, so a per-frame
-- handler can't flood the log) instead of vanishing into chat.
function BazUI.Guard(label, handler)
	local reported = false;
	return function(...)
		local ok, err = pcall(handler, ...);
		if not ok and not reported then
			reported = true;
			BazUI.Log.Error(label .. ": " .. tostring(err));
		end
	end
end
