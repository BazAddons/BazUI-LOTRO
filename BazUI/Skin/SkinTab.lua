-- Skin/SkinTab.lua
-- The Skin tab: a switch for each part of the game's own interface the BazUI
-- skin restyles. A plugin can't change a skin, so the switches are saved with
-- BazUI's settings and Skin/build_skin.py reads them when it builds the skin;
-- the game then picks it up when it next starts. Skin/Built.lua, written by
-- each build, says what the skin was built from, so this tab can tell when
-- it needs building again.

BazUI.Skin = {};
local Skin = BazUI.Skin;

-- The switches, in build_skin.py's order and with its names for them.
local PARTS = {
	{ key = "Toolbar", name = "toolbar",
		text = "Toolbar: just the menu buttons, top centre (needs the Action bars module)" },
	{ key = "Radar", name = "radar", text = "Radar: a thin gold ring, and hope/dread gems to match" },
	{ key = "CastBar", name = "cast bar", text = "Cast bar: a dark track with a gold outline" },
	{ key = "Buffs", name = "buffs", text = "Buff and debuff icons: an even gold edge" },
	{ key = "QuestTracker", name = "quest tracker", text = "Quest tracker: a soft dark backing per quest, gold accent on the selected one" },
	{ key = "Windows", name = "windows", text = "Windows and chat: BazUI's dark panel and gold line, no silver or knots" },
};

-- Modules whose part of the game's interface the skin hides while they're on.
local FOLLOWS = {
	{ key = "ActionBars", name = "Action bars module" },
	{ key = "Menu", name = "Menu module" },
	{ key = "ClassBar", name = "Class bar module" },
};

local REBUILD = "python3 build_skin.py in Plugins/Baz4k/BazUI/Skin, then exit and relaunch the game";

-- What the settings ask of the skin now, by part name.
local function Wanted()
	local settings = BazUI.Settings.Get("Skin");
	local wanted = {};
	for _, part in ipairs(PARTS) do
		wanted[part.key] = settings[part.key] ~= false;
	end
	for _, part in ipairs(FOLLOWS) do
		wanted[part.key] = BazUI.IsModuleEnabled(part.key);
	end
	return wanted;
end

-- One line on whether the skin matches the settings, and what to do if not.
local function Status()
	local built = BazUI.SkinBuilt;
	if built == nil then
		return "No record of the skin being built yet. Build it: " .. REBUILD .. ".";
	end
	local wanted, changed = Wanted(), {};
	for _, list in ipairs({ PARTS, FOLLOWS }) do
		for _, part in ipairs(list) do
			if wanted[part.key] ~= (built[part.key] ~= false) then
				table.insert(changed, part.name);
			end
		end
	end
	if tonumber(built.ChatOpacity) ~= tonumber(BazUI.Settings.Get("Skin").ChatOpacity) then
		table.insert(changed, "chat tab opacity");
	end
	if (built.Accent or "gold") ~= BazUI.Accent.Get() then
		table.insert(changed, "accent colour");
	end
	if #changed == 0 then
		return "The skin matches these settings.";
	end
	return "Changed since the skin was built: " .. table.concat(changed, ", ") .. ". Rebuild it: " .. REBUILD .. ".";
end

-- The Skin settings tab. `form` is a BazUI.Options form.
function Skin.BuildOptions(form)
	local settings = BazUI.Settings.Get("Skin");

	form:Note("These parts of the game's own interface are restyled by the BazUI skin (Options > UI Settings > Current User Skin). Untick one to keep the game's own look for it.");

	-- Sized for the longest status, then set to the real one.
	local longest = "Changed since the skin was built: toolbar, radar, cast bar, buffs, quest tracker, windows, Action bars module, Menu module, Class bar module, chat tab opacity, accent colour. Rebuild it: " .. REBUILD .. ".";
	local status;

	form:Heading("Restyled");
	for _, part in ipairs(PARTS) do
		form:Check(part.text, settings[part.key] ~= false, function(on)
			settings[part.key] = on;
			BazUI.Settings.Save(); -- build_skin.py reads the saved file
			status:SetText(Status());
		end);
	end

	form:Heading("Chat");
	form:Note("The chat window's background is the game's own, with its own opacity setting, and follows it at once. Its tabs are skin art and can't: set the same opacity here and rebuild, so the open tab matches the window.");
	form:Slider("Tab opacity, %", 0, 100, math.floor((tonumber(settings.ChatOpacity) or 45) + 0.5), function(value)
		settings.ChatOpacity = value;
		BazUI.Settings.Save(); -- build_skin.py reads the saved file
		status:SetText(Status());
	end);

	form:Heading("Hidden while their module is on");
	form:Note("The game's quickslot bars (Action bars), its menu button art - BazUI draws the menu over the buttons - (Menu), and the Rune-keeper attunement display (Class bar). Switch a module off in General and rebuild the skin to have the game's own back.");

	form:Heading("Building the skin");
	status = form:Note(longest);
	status:SetText(Status());
end
