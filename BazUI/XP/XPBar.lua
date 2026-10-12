-- XP/XPBar.lua
-- A thin experience bar, its own object, normally along the bottom edge of
-- the screen beneath the action buttons. Hover it and the numbers appear on
-- it; move it in the game's layout mode (Ctrl+\).
--
-- Plugins can't ask the game for XP, but every character-XP message in the
-- Advancement chat ("You've earned 145 XP for a total of 400,880 XP.") carries
-- the running total. That total, the player's level and the per-level table
-- in Levels.lua are all the bar needs. The last total is kept per character,
-- so the bar is right as soon as you log in.

BazUI.XP = BazUI.XP or {};
local XP = BazUI.XP;
local LEVELS = XP.LEVELS;

local HEIGHT = 14;         -- room for the numbers on the bar
local DATA_KEY = "BazUI_XP";
XP.HEIGHT = HEIGHT;       -- the action bars stack above it

-- Colors are alpha, r, g, b.
local BORDER_COLOR = Turbine.UI.Color(0.9, 0, 0, 0);
local TRACK_COLOR = Turbine.UI.Color(0.75, 0.09, 0.08, 0.07);
local FILL_COLOR = Turbine.UI.Color(1, 0.86, 0.66, 0.20);
local TEXT_COLOR = Turbine.UI.Color(1, 0.96, 0.93, 0.82);

-- Other experience (virtues, legendary items, steeds, crafting) reports in
-- the same chat; its totals mustn't be read as character XP. English
-- wording - on other clients the level-range check in ReadTotal is what
-- keeps them out.
local OTHER_KINDS = { "virtue", "item", "legendary", "steed", "mount", "craft" };

-- Thousands separators the game may put inside a number, as Lua patterns:
-- , . ' space, and the two no-break spaces (UTF-8) some languages use.
local SEPARATORS = { ",", "%.", "'", " ", "\194\160", "\226\128\175" };

local settings, player, window, track, fill, label, fitOverlay;
local enabled = false;
local level;          -- the player's level
local total;          -- running XP total, nil until known
local hovering = false;
local loggedMessages = 0;

local function Scale(control)
	local ok, scale = pcall(function() return control:GetScale(); end);
	return (ok and type(scale) == "number" and scale > 0) and scale or 1;
end

-- How far through the current level, 0-1, and what's known about it:
-- "ok", "unknown" (no XP message yet) or "max" (level cap).
local function Progress()
	local low, high = LEVELS[level], LEVELS[level + 1];
	if high == nil then
		return 1, "max";
	end
	if total == nil or low == nil then
		return 0, "unknown";
	end
	return math.max(0, math.min(1, (total - low) / (high - low))), "ok";
end

local function Summary()
	local fraction, state = Progress();
	if state == "max" then
		return "Level " .. level .. "  -  maximum level";
	elseif state == "unknown" then
		return "Level " .. level .. "  -  XP shows after your next XP gain";
	end
	local low, high = LEVELS[level], LEVELS[level + 1];
	return string.format("Level %d   %s / %s XP   %d%%", level,
		BazUI.Util.Thousands(total - low), BazUI.Util.Thousands(high - low), math.floor(fraction * 100));
end

local function Refresh()
	local fraction = Progress();
	fill:SetWidth(math.floor((settings.Width - 2) * fraction));
	label:SetText(Summary());
end

local function ShowText(show)
	if show then
		Refresh();
	end
	label:SetVisible(show);
end

local function SetTotal(value)
	if value == total then
		return;
	end
	total = value;
	pcall(Turbine.PluginData.Save, Turbine.DataScope.Character, DATA_KEY, { Total = total });
	Refresh();
end

-- The running total in an Advancement message, or nil if it isn't a
-- character-XP message.
local function ReadTotal(message)
	local text = string.gsub(message, "<[^>]*>", ""); -- color and link markup
	local lower = string.lower(text);
	for _, kind in ipairs(OTHER_KINDS) do
		if string.find(lower, kind, 1, true) then
			return nil;
		end
	end

	-- "400,880" -> "400880", however the client groups its digits.
	for _, separator in ipairs(SEPARATORS) do
		local count;
		repeat
			text, count = string.gsub(text, "(%d)" .. separator .. "(%d%d%d)", "%1%2");
		until count == 0;
	end

	-- The total is the largest number that fits between the start of this
	-- level and the end of the next (the message can land just before the
	-- level-up does). The XP just earned is smaller, and anything else is
	-- out of range.
	local low = LEVELS[level];
	local ceiling = LEVELS[level + 2] or math.huge;
	local best;
	for digits in string.gmatch(text, "%d+") do
		local n = tonumber(digits);
		if n >= low and n < ceiling and (best == nil or n > best) then
			best = n;
		end
	end
	return best;
end

local function OnChat(args)
	-- Read even while the bar is switched off, so it's right when it's back.
	if args.ChatType ~= Turbine.ChatType.Advancement or type(args.Message) ~= "string" then
		return;
	end
	local found = ReadTotal(args.Message);

	-- The first few each session go in the log, so the parsing can be
	-- checked against what the game actually says.
	if loggedMessages < 5 then
		loggedMessages = loggedMessages + 1;
		BazUI.Log.Write("xp: advancement \"" .. args.Message .. "\" -> " .. tostring(found));
	end

	if found ~= nil then
		SetTotal(found);
	end
end

local function OnLevelChanged(sender, args)
	level = player:GetLevel();
	-- A level up means at least the new level's start, until the next XP
	-- message says exactly where.
	local start = LEVELS[level];
	if start ~= nil and (total == nil or total < start) then
		total = nil; -- force the save in SetTotal
		SetTotal(start);
	else
		Refresh();
	end
end

local function CreateWindow()
	local w = Turbine.UI.Window();
	w:SetSize(settings.Width, HEIGHT);
	w:SetBackColor(BORDER_COLOR);

	track = Turbine.UI.Control();
	track:SetParent(w);
	track:SetPosition(1, 1);
	track:SetSize(settings.Width - 2, HEIGHT - 2);
	track:SetBackColor(TRACK_COLOR);
	track:SetMouseVisible(false);

	fill = Turbine.UI.Control();
	fill:SetParent(w);
	fill:SetPosition(1, 1);
	fill:SetSize(0, HEIGHT - 2);
	fill:SetBackColor(FILL_COLOR);
	fill:SetMouseVisible(false);

	-- The numbers, on the bar itself, outlined so they read over the fill
	-- and the track alike.
	label = Turbine.UI.Label();
	label:SetParent(w);
	label:SetSize(settings.Width, HEIGHT);
	label:SetFont(Turbine.UI.Lotro.Font.Verdana12);
	label:SetFontStyle(Turbine.UI.FontStyle.Outline);
	label:SetOutlineColor(Turbine.UI.Color(1, 0, 0, 0));
	label:SetForeColor(TEXT_COLOR);
	label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	label:SetZOrder(5);
	label:SetMouseVisible(false);
	label:SetVisible(false);

	-- The numbers on hover; not in layout mode, where it's being moved.
	w.MouseEnter = function(sender, args)
		hovering = true;
		ShowText(not BazUI.Events.IsLayoutUnlocked());
	end
	w.MouseLeave = function(sender, args)
		hovering = false;
		ShowText(false);
	end
	return w;
end

-- Bottom centre of the screen, unless it has been moved.
local function Place()
	local Display = Turbine.UI.Display;
	local scale = Scale(window);
	local width, height = settings.Width * scale, HEIGHT * scale;
	local left, top = settings.Left, settings.Top;
	if left < 0 or top < 0 or left > Display.GetWidth() - 50 or top > Display.GetHeight() - height then
		left = math.floor((Display.GetWidth() - width) / 2);
		top = math.floor(Display.GetHeight() - height - 2);
	end
	window:SetPosition(left, top);
end

local function Create()
	settings = BazUI.Settings.Get("XP");
	player = Turbine.Gameplay.LocalPlayer.GetInstance();
	level = player:GetLevel();

	local ok, saved = pcall(Turbine.PluginData.Load, Turbine.DataScope.Character, DATA_KEY);
	if ok and type(saved) == "table" and type(saved.Total) == "number" then
		total = saved.Total;
		-- A total from a different level (e.g. levelled with BazUI off) is stale.
		local low, high = LEVELS[level], LEVELS[level + 1];
		if low == nil or total < low or (high ~= nil and total >= high) then
			total = nil;
		end
	end

	window = CreateWindow();
	BazUI.Scaling.Attach(window, Place); -- a new scale changes where centred is
	Place();

	fitOverlay = BazUI.Layout.MakeMovable("xp", window, function(left, top)
		settings.Left, settings.Top = left, top;
	end);
	BazUI.Events.OnLayoutMode("xp", function(unlocked)
		ShowText(enabled and hovering and not unlocked);
	end);

	BazUI.Events.OnChat("xp", OnChat);
	BazUI.Events.OnPlayer("LevelChanged", "xp", OnLevelChanged);

	Refresh();
	BazUI.Log.Write("xp: level " .. tostring(level) .. ", total " .. tostring(total));
end

-- Module switch (General tab).
function XP.Enable()
	if window == nil then
		Create();
	end
	enabled = true;
	window:SetVisible(true);
end

function XP.Disable()
	enabled = false;
	if window ~= nil then
		window:SetVisible(false);
	end
end

function XP.SetWidth(width)
	settings.Width = width;
	if window == nil then
		return;
	end
	window:SetWidth(width);
	track:SetWidth(width - 2);
	label:SetWidth(width);
	Place(); -- stays centred unless it has been moved
	fitOverlay();
	Refresh();
end

function XP.ResetPosition()
	settings.Left, settings.Top = -1, -1;
	if window ~= nil then
		Place();
	end
end

-- The XP bar settings tab. `form` is a BazUI.Options form.
function XP.BuildOptions(form)
	settings = settings or BazUI.Settings.Get("XP"); -- the tab can open while the module is off
	form:Heading("Size and place");
	form:Slider("Width", 300, 2400, settings.Width, function(value)
		XP.SetWidth(value);
	end, 50);
	form:Button("Back to the bottom centre", XP.ResetPosition);
	form:Note("To move it anywhere else, use the game's layout mode (Ctrl+\\): the bar lights up and can be dragged. Ctrl+\\ again locks it.");

	if window ~= nil then
		form:Heading("Now");
		form:Note(Summary());
	end
end

-- For /bazui xp.
function XP.Report()
	if window == nil then
		Turbine.Shell.WriteLine("BazUI: the XP bar isn't running.");
		return;
	end
	Turbine.Shell.WriteLine("BazUI XP: " .. Summary() .. (total ~= nil and (" (total " .. BazUI.Util.Thousands(total) .. ")") or ""));
end
