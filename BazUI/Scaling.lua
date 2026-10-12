-- Scaling.lua
-- Makes BazUI windows follow LOTRO's Global UI scale (Options > UI Settings).
--
-- Since Update 46.2 plugin windows can scale, but the Plugin Manager's
-- "Use Global Scaling" checkbox is off by default. Rather than depend on that
-- box, each window measures whatever scale the game is already applying and
-- picks a local scale that brings the total to the Global value. That gives
-- the same result with the box checked or unchecked.
--
-- Nothing in here may break a module: every failure is logged and the window
-- is left to whatever scaling the game applies on its own.

BazUI.Scaling = {};

-- The scaling-group enum. The 49.6 patch notes put it at
-- Turbine.UI.UIScalingGroupType, but the live client had nothing there
-- (v003 log), so check the other likely spots and log which one answered.
local GROUP_ENUMS = {
	{ "Turbine.UI.UIScalingGroupType", Turbine.UI.UIScalingGroupType },
	{ "Turbine.UI.Lotro.UIScalingGroupType", Turbine.UI.Lotro.UIScalingGroupType },
	{ "Turbine.UIScalingGroupType", Turbine.UIScalingGroupType },
};

local Groups, groupsPath;
for _, entry in ipairs(GROUP_ENUMS) do
	if entry[2] ~= nil then
		groupsPath, Groups = entry[1], entry[2];
		break;
	end
end

local warned = false;

-- Names in the API that look scaling-related, so the log shows where the
-- enum really lives if none of the spots above had it.
local function ScalingNames()
	local found = {};
	local places = {
		{ "Turbine", Turbine },
		{ "Turbine.UI", Turbine.UI },
		{ "Turbine.UI.Lotro", Turbine.UI.Lotro },
		{ "Turbine.UI.Display", Turbine.UI.Display },
	};
	for _, place in ipairs(places) do
		if type(place[2]) == "table" then
			for name in pairs(place[2]) do
				if type(name) == "string" and (string.find(name, "Scal") or string.find(name, "Group")) then
					table.insert(found, place[1] .. "." .. name);
				end
			end
		end
	end
	return #found > 0 and table.concat(found, ", ") or "none";
end

local function WindowMethods(window)
	local found = {};
	for _, name in ipairs({ "SetScale", "GetScale", "SetUIScalingGroup", "RegisterForGlobalScaling" }) do
		if window[name] ~= nil then
			table.insert(found, name);
		end
	end
	return #found > 0 and table.concat(found, " ") or "none";
end

local function GlobalScale()
	return Turbine.UI.Display.GetUIGroupScale(Groups.Global);
end

local function Apply(window, factor)
	if window.SetScale == nil then
		return; -- client predates UI scaling
	end

	local target = GlobalScale();
	if target == nil or target <= 0 then
		return;
	end
	if factor ~= nil then
		target = target * factor();
	end

	-- Total scale = (what the game applies) x (our local scale). Reset ours to
	-- 1 to measure the game's part, then solve for ours.
	window:SetScale(1);
	local base = window:GetScale();
	if base == nil or base <= 0 then
		base = 1;
	end
	window:SetScale(target / base);
	BazUI.Trace("scaling: Global " .. tostring(target) .. ", game applied " .. tostring(base) ..
		", window now " .. tostring(window:GetScale()));
end

local function SafeApply(window, factor)
	local ok, err = pcall(Apply, window, factor);
	if not ok and not warned then
		warned = true;
		BazUI.Log.Error("couldn't apply UI scale: " .. tostring(err));
	end
end

-- Call once per window, after it has its final size. onScaled, if given,
-- runs after the player changes a scale option - e.g. to re-place a window
-- whose default spot depends on its size. factor, if given, is a function
-- returning a multiple of the Global scale for this window (its own size
-- setting). Returns a function that applies the scale again, for after that
-- setting changes.
function BazUI.Scaling.Attach(window, onScaled, factor)
	local reapply = function() end;
	local ok, err = pcall(function()
		BazUI.Log.Write("scaling: group enum at " .. tostring(groupsPath) ..
			"; window has " .. WindowMethods(window) ..
			"; Display.GetUIGroupScale " .. (Turbine.UI.Display.GetUIGroupScale ~= nil and "present" or "missing"));

		if Groups == nil or Turbine.UI.Display.GetUIGroupScale == nil then
			BazUI.Log.Write("scaling: API names seen: " .. ScalingNames());
			return; -- leave it to the Plugin Manager's "Use Global Scaling" box
		end

		if window.SetUIScalingGroup ~= nil then
			-- Turns scaling on for this window even when the plugin isn't using
			-- Global scaling, and makes UIScaleChanged fire when the player
			-- moves the Global slider.
			window:SetUIScalingGroup(Groups.Global);
		end

		window.UIScaleChanged = function(sender, args)
			SafeApply(window, factor);
			if onScaled ~= nil then
				pcall(onScaled);
			end
		end

		SafeApply(window, factor);
		reapply = function() SafeApply(window, factor); end;
	end);

	if not ok then
		BazUI.Log.Error("scaling setup failed: " .. tostring(err));
	end
	return reapply;
end

-- Gives a window an exact total scale, whatever the game applies on its own
-- (including the Plugin Manager's "Use Global Scaling"): measures the game's
-- part and sets the rest. Kept right when the player changes a scale option.
--   1         matches the screen 1:1 (the alignment grid)
--   other     e.g. drawing 64-pixel art at a chosen size (the menu)
--   function  called for the number each time (e.g. half another window's)
function BazUI.Scaling.SetTotal(window, total)
	local function Apply()
		if window.SetScale == nil then
			return;
		end
		local wanted = type(total) == "function" and total() or total;
		window:SetScale(1);
		local base = window:GetScale();
		if type(base) == "number" and base > 0 and math.abs(base - wanted) > 0.0001 then
			window:SetScale(wanted / base);
		end
	end

	local ok, err = pcall(Apply);
	if not ok then
		BazUI.Log.Error("couldn't set a window's scale: " .. tostring(err));
	end
	window.UIScaleChanged = function(sender, args)
		pcall(Apply);
	end
end

function BazUI.Scaling.Unscale(window)
	BazUI.Scaling.SetTotal(window, 1);
end

-- Prints the numbers behind the current scale, for /bazui scale.
function BazUI.Scaling.Report(window)
	local function Fmt(fn)
		local ok, value = pcall(fn);
		if ok and type(value) == "number" then
			return string.format("%.2f", value);
		end
		return "n/a";
	end

	local Display = Turbine.UI.Display;
	local line = "BazUI scale: Global option " ..
		Fmt(function() return Display.GetUIGroupScale(Groups.Global) end) ..
		", Bags option " ..
		Fmt(function() return Display.GetUIGroupScale(Groups.InventoryBags) end) ..
		", bag window " ..
		Fmt(function() return window:GetScale() end);
	BazUI.Log.Write(line);
	Turbine.Shell.WriteLine(line);
end
