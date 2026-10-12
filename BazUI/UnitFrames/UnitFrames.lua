-- UnitFrames/UnitFrames.lua
-- Your frame and your target's, in BazUI's dark-and-gold look: name and
-- level, a morale bar and a power bar with the numbers on them. While this
-- module is on, the game's own vitals and target displays are switched off
-- (plugins are allowed to hide exactly those two); switch it off and they
-- come back.
--
-- Clicking a frame targets that unit and right-clicking opens the game's own
-- menu for it, through the game's EntityControl. Both frames move in layout
-- mode (Ctrl+\).

BazUI.UnitFrames = {};
local UnitFrames = BazUI.UnitFrames;

local WIDTH = 240;
local PAD = 6;
local NAME_H = 18;
local MORALE_H = 16;
local POWER_H = 10;
local BAR_GAP = 3;
local HEIGHT = PAD + NAME_H + MORALE_H + BAR_GAP + POWER_H + PAD;

-- Colors are alpha, r, g, b; golds are tables, shown through BazUI.Accent.
local BACK_COLOR = Turbine.UI.Color(0.80, 0.05, 0.04, 0.03);
local BORDER_GOLD = { 0.90, 0.69, 0.55, 0.28 };   -- the menu's gold
local TRACK_COLOR = Turbine.UI.Color(0.90, 0.13, 0.11, 0.09);
local MORALE_COLOR = Turbine.UI.Color(1, 0.22, 0.62, 0.22);
local MORALE_LOW_COLOR = Turbine.UI.Color(1, 0.78, 0.20, 0.16);  -- under a third
local POWER_COLOR = Turbine.UI.Color(1, 0.22, 0.42, 0.80);
local TEMP_COLOR = Turbine.UI.Color(0.85, 0.95, 0.80, 0.30);     -- temporary morale, on top
local NAME_GOLD = { 1, 0.93, 0.86, 0.62 };
local TEXT_COLOR = Turbine.UI.Color(1, 0.95, 0.95, 0.92);

local settings, player;
local frames = {};       -- "Player" / "Target" -> frame
local target;            -- the actor the Target frame is showing
local enabled = false;
local playerListeners = {};  -- told when your frame moves, shows or hides (the docked class bar)

local function NotifyPlayerFrame()
	for _, listener in ipairs(playerListeners) do
		listener();
	end
end

local function SetGameFrames(on)
	local LotroUI, Element = Turbine.UI.Lotro.LotroUI, Turbine.UI.Lotro.LotroUIElement;
	if settings.HideGameFrames or on then
		LotroUI.SetEnabled(Element.Vitals, on);
		LotroUI.SetEnabled(Element.Target, on);
	end
end

-- Calls object:method(), or nil if the object or method isn't there (a
-- target can be an object with no morale, for instance).
local function Call(object, method)
	if object == nil then
		return nil;
	end
	local ok, value = pcall(function() return object[method](object); end);
	if ok then
		return value;
	end
end

local function Number(n)
	return BazUI.Util.Thousands(math.floor(n + 0.5));
end

-- A bar: dark track, a fill, and its numbers centred on it.
local function CreateBar(parent, top, height, color, font)
	local bar = {};
	bar.track = Turbine.UI.Control();
	bar.track:SetParent(parent);
	bar.track:SetPosition(PAD, top);
	bar.track:SetSize(WIDTH - 2 * PAD, height);
	bar.track:SetBackColor(TRACK_COLOR);
	bar.track:SetMouseVisible(false);

	bar.fill = Turbine.UI.Control();
	bar.fill:SetParent(bar.track);
	bar.fill:SetHeight(height);
	bar.fill:SetBackColor(color);
	bar.fill:SetMouseVisible(false);

	bar.temp = Turbine.UI.Control();
	bar.temp:SetParent(bar.track);
	bar.temp:SetHeight(math.max(2, math.floor(height / 4)));
	bar.temp:SetBackColor(TEMP_COLOR);
	bar.temp:SetMouseVisible(false);

	bar.text = Turbine.UI.Label();
	bar.text:SetParent(bar.track);
	bar.text:SetSize(WIDTH - 2 * PAD, height);
	bar.text:SetFont(font);
	bar.text:SetFontStyle(Turbine.UI.FontStyle.Outline);
	bar.text:SetOutlineColor(Turbine.UI.Color(1, 0, 0, 0));
	bar.text:SetForeColor(TEXT_COLOR);
	bar.text:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	bar.text:SetMouseVisible(false);
	return bar;
end

-- value/max on a bar; temp is temporary morale or power, drawn as a strip
-- along the top of the bar.
local function SetBar(bar, value, max, temp, lowColor, color)
	local width = WIDTH - 2 * PAD;
	if value == nil or max == nil or max <= 0 then
		bar.fill:SetWidth(0);
		bar.temp:SetWidth(0);
		bar.text:SetText("");
		return;
	end
	local fraction = math.max(0, math.min(1, value / max));
	bar.fill:SetWidth(math.floor(width * fraction + 0.5));
	if lowColor ~= nil then
		bar.fill:SetBackColor(fraction < 1 / 3 and lowColor or color);
	end
	bar.temp:SetWidth(temp and temp > 0 and math.floor(width * math.min(1, temp / max) + 0.5) or 0);

	local text;
	if settings.Numbers == "percent" then
		text = math.floor(fraction * 100 + 0.5) .. "%";
	elseif settings.Numbers == "both" then
		text = Number(value) .. " / " .. Number(max) .. "  (" .. math.floor(fraction * 100 + 0.5) .. "%)";
	else
		text = Number(value) .. " / " .. Number(max);
	end
	if temp and temp > 0 then
		text = text .. "  +" .. Number(temp);
	end
	bar.text:SetText(text);
end

local function Refresh(frame)
	local actor = frame.actor;
	if actor == nil then
		return;
	end
	local level = Call(actor, "GetLevel");
	frame.name:SetText(Call(actor, "GetName") or "");
	frame.level:SetText(level ~= nil and tostring(level) or "");

	local morale = Call(actor, "GetMorale");
	local hasVitals = morale ~= nil;
	frame.morale.track:SetVisible(hasVitals);
	frame.power.track:SetVisible(hasVitals);
	if hasVitals then
		SetBar(frame.morale, morale, Call(actor, "GetMaxMorale"), Call(actor, "GetTemporaryMorale"),
			MORALE_LOW_COLOR, MORALE_COLOR);
		SetBar(frame.power, Call(actor, "GetPower"), Call(actor, "GetMaxPower"), Call(actor, "GetTemporaryPower"));
	end
end

local VITAL_EVENTS = { "MoraleChanged", "MaxMoraleChanged", "TemporaryMoraleChanged", "MaxTemporaryMoraleChanged",
	"PowerChanged", "MaxPowerChanged", "TemporaryPowerChanged", "MaxTemporaryPowerChanged",
	"LevelChanged", "NameChanged" };

local function IsSelf(actor)
	return actor == player or Call(actor, "IsLocalPlayer") == true;
end

-- Points the Target frame at an actor (nil: none), moving its event
-- handlers across. An actor's events hold one handler each, so the player's
-- own events go through BazUI.Events (other modules use them too) and when
-- you target yourself the Target frame rides on those.
local function Bind(frame, actor)
	if frame.actor ~= nil and not IsSelf(frame.actor) then
		for _, event in ipairs(VITAL_EVENTS) do
			frame.actor[event] = nil;
		end
	end
	frame.actor = actor;
	local ok = pcall(function() frame.entity:SetEntity(actor); end);
	if not ok and not frame.warnedEntity then
		frame.warnedEntity = true;
		BazUI.Log.Write("unitframes: EntityControl has no SetEntity");
	end

	if actor == nil then
		frame.window:SetVisible(false);
		return;
	end
	if not IsSelf(actor) then
		local handler = BazUI.Guard("unitframes " .. frame.key, function(sender, args)
			Refresh(frame);
		end);
		for _, event in ipairs(VITAL_EVENTS) do
			actor[event] = handler;
		end
	end
	Refresh(frame);
	frame.window:SetVisible(enabled and settings[frame.key].Shown);
end

local function DefaultPosition(key)
	local Display = Turbine.UI.Display;
	local cx, y = Display.GetWidth() / 2, math.floor(Display.GetHeight() * 0.62);
	if key == "Player" then
		return math.floor(cx - 40 - WIDTH * 1.0), y;
	end
	return math.floor(cx + 40), y;
end

local function Place(frame)
	local place = settings[frame.key];
	local Display = Turbine.UI.Display;
	local left, top = place.Left, place.Top;
	if left < 0 or top < 0 or left > Display.GetWidth() - 50 or top > Display.GetHeight() - 20 then
		left, top = DefaultPosition(frame.key);
	end
	frame.window:SetPosition(left, top);
end

local function CreateFrame(key)
	local frame = { key = key };
	local w = Turbine.UI.Window();
	w:SetSize(WIDTH, HEIGHT);
	BazUI.Accent.Bind(w, "SetBackColor", BORDER_GOLD);
	frame.window = w;

	-- A 1-unit gold border round a dark panel.
	local back = Turbine.UI.Control();
	back:SetParent(w);
	back:SetPosition(1, 1);
	back:SetSize(WIDTH - 2, HEIGHT - 2);
	back:SetBackColor(BACK_COLOR);
	back:SetMouseVisible(false);

	frame.name = Turbine.UI.Label();
	frame.name:SetParent(w);
	frame.name:SetPosition(PAD, PAD - 2);
	frame.name:SetSize(WIDTH - 2 * PAD - 30, NAME_H);
	frame.name:SetFont(Turbine.UI.Lotro.Font.TrajanPro14);
	BazUI.Accent.Bind(frame.name, "SetForeColor", NAME_GOLD);
	frame.name:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
	frame.name:SetMouseVisible(false);

	frame.level = Turbine.UI.Label();
	frame.level:SetParent(w);
	frame.level:SetPosition(WIDTH - PAD - 30, PAD - 2);
	frame.level:SetSize(30, NAME_H);
	frame.level:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	BazUI.Accent.Bind(frame.level, "SetForeColor", NAME_GOLD);
	frame.level:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleRight);
	frame.level:SetMouseVisible(false);

	local y = PAD + NAME_H;
	frame.morale = CreateBar(w, y, MORALE_H, MORALE_COLOR, Turbine.UI.Lotro.Font.Verdana12);
	frame.power = CreateBar(w, y + MORALE_H + BAR_GAP, POWER_H, POWER_COLOR, Turbine.UI.Lotro.Font.Verdana10);

	-- The game's own click-to-target and right-click menu, over the whole frame.
	local entity = Turbine.UI.Lotro.EntityControl();
	entity:SetParent(w);
	entity:SetSize(WIDTH, HEIGHT);
	entity:SetZOrder(20);
	for _, setup in ipairs({ "SetSelectionEnabled", "SetContextMenuEnabled" }) do
		local ok = pcall(function() entity[setup](entity, true); end);
		if not ok then
			BazUI.Log.Write("unitframes: EntityControl has no " .. setup);
		end
	end
	frame.entity = entity;

	BazUI.Scaling.Attach(w, function() Place(frame); end);
	if key == "Player" then
		w.PositionChanged = function(sender, args)
			NotifyPlayerFrame();
		end
	end
	Place(frame);
	BazUI.Layout.MakeMovable("unitframe " .. key, w, function(left, top)
		settings[key].Left, settings[key].Top = left, top;
	end);
	return frame;
end

local function OnTargetChanged()
	local new = Call(player, "GetTarget");
	if new ~= target then
		target = new;
		Bind(frames.Target, target);
	end
end

local function Create()
	settings = BazUI.Settings.Get("UnitFrames");
	player = Turbine.Gameplay.LocalPlayer.GetInstance();

	frames.Player = CreateFrame("Player");
	frames.Target = CreateFrame("Target");

	frames.Player.actor = player;
	pcall(function() frames.Player.entity:SetEntity(player); end);
	for _, event in ipairs(VITAL_EVENTS) do
		BazUI.Events.OnPlayer(event, "unitframes", function(sender, args)
			Refresh(frames.Player);
			if IsSelf(frames.Target.actor) then
				Refresh(frames.Target);
			end
		end);
	end
	Refresh(frames.Player);

	BazUI.Events.OnPlayer("TargetChanged", "unitframes", OnTargetChanged);
	OnTargetChanged();
end

local function ShowFrames()
	frames.Player.window:SetVisible(enabled and settings.Player.Shown);
	frames.Target.window:SetVisible(enabled and settings.Target.Shown and target ~= nil);
	NotifyPlayerFrame();
end

-- Your frame's window while it's showing, else nil - for the class bar to
-- dock under.
function UnitFrames.GetPlayerWindow()
	if enabled and frames.Player ~= nil and frames.Player.window:IsVisible() then
		return frames.Player.window;
	end
end

-- listener() is called whenever your frame moves, shows or hides.
function UnitFrames.OnPlayerFrameChanged(listener)
	table.insert(playerListeners, BazUI.Guard("unitframes listener", listener));
end

-- Module switch (General tab). Off gives the game its own frames back.
function UnitFrames.Enable()
	if player == nil then
		Create();
	end
	enabled = true;
	SetGameFrames(false);
	ShowFrames();
end

function UnitFrames.Disable()
	enabled = false;
	if player ~= nil then
		ShowFrames();
	end
	SetGameFrames(true);
end

-- Plugin unloading: give the game its frames back.
function UnitFrames.Destroy()
	if enabled then
		SetGameFrames(true);
	end
end

function UnitFrames.ResetPositions()
	for key, frame in pairs(frames) do
		settings[key].Left, settings[key].Top = -1, -1;
		Place(frame);
	end
end

-- The Unit frames settings tab. `form` is a BazUI.Options form.
function UnitFrames.BuildOptions(form)
	settings = settings or BazUI.Settings.Get("UnitFrames"); -- the tab can open while the module is off

	form:Heading("Frames");
	form:Check("Your frame", settings.Player.Shown, function(on)
		settings.Player.Shown = on;
		if player ~= nil then ShowFrames(); end
	end);
	form:Check("Target frame", settings.Target.Shown, function(on)
		settings.Target.Shown = on;
		if player ~= nil then ShowFrames(); end
	end);
	form:Check("Hide the game's own vitals and target displays", settings.HideGameFrames, function(on)
		settings.HideGameFrames = on;
		if enabled then
			Turbine.UI.Lotro.LotroUI.SetEnabled(Turbine.UI.Lotro.LotroUIElement.Vitals, not on);
			Turbine.UI.Lotro.LotroUI.SetEnabled(Turbine.UI.Lotro.LotroUIElement.Target, not on);
		end
	end);

	form:Heading("Numbers");
	form:Cycle("On the bars", { { "value", "current / max" }, { "percent", "percent" }, { "both", "both" } },
		settings.Numbers, function(value)
			settings.Numbers = value;
			for _, frame in pairs(frames) do
				Refresh(frame);
			end
		end);

	form:Heading("Place");
	form:Button("Back to their default spots", UnitFrames.ResetPositions);
	form:Note("Move them anywhere with the game's layout mode (Ctrl+\\).");
end
