-- Grid.lua
-- An alignment grid over the whole screen while the game's layout mode
-- (Ctrl+\) is on, with the centre lines picked out in gold, for lining things
-- up by eye. It ignores the mouse, so dragging works straight through it.
-- /bazui grid shows it at other times too.

BazUI.Grid = {};
local Grid = BazUI.Grid;

-- Colors are alpha, r, g, b.
local LINE_COLOR = Turbine.UI.Color(0.14, 1, 1, 1);
local MAJOR_COLOR = Turbine.UI.Color(0.28, 1, 1, 1);    -- every 4th line out from the centre
local CENTER_COLOR = Turbine.UI.Color(0.85, 1, 0.84, 0.30);
local MAJOR_EVERY = 4;

local settings, window;
local lines = {};
local forced = false;   -- shown by /bazui grid

local function AddLine(x, y, w, h, color)
	local line = Turbine.UI.Control();
	line:SetParent(window);
	line:SetPosition(x, y);
	line:SetSize(w, h);
	line:SetBackColor(color);
	line:SetMouseVisible(false);
	table.insert(lines, line);
end

-- Lines run out from the centre, so the centre is always on the grid.
local function Draw()
	for _, line in ipairs(lines) do
		line:SetParent(nil);
	end
	lines = {};

	local width, height = Turbine.UI.Display.GetWidth(), Turbine.UI.Display.GetHeight();
	window:SetSize(width, height);
	local step = math.max(8, settings.Spacing);
	local cx, cy = math.floor(width / 2), math.floor(height / 2);

	for k = 1, math.ceil(width / 2 / step) do
		local color = (k % MAJOR_EVERY == 0) and MAJOR_COLOR or LINE_COLOR;
		for _, x in ipairs({ cx - k * step, cx + k * step }) do
			if x >= 0 and x < width then
				AddLine(x, 0, 1, height, color);
			end
		end
	end
	for k = 1, math.ceil(height / 2 / step) do
		local color = (k % MAJOR_EVERY == 0) and MAJOR_COLOR or LINE_COLOR;
		for _, y in ipairs({ cy - k * step, cy + k * step }) do
			if y >= 0 and y < height then
				AddLine(0, y, width, 1, color);
			end
		end
	end

	AddLine(cx - 1, 0, 2, height, CENTER_COLOR);
	AddLine(0, cy - 1, width, 2, CENTER_COLOR);
end

local function Update()
	local show = settings.Enabled and (forced or BazUI.Events.IsLayoutUnlocked());
	if show then
		if window == nil then
			-- Drawn 1:1 with the screen whatever the UI scale, so its centre
			-- lines are the screen's centre.
			window = Turbine.UI.Window();
			window:SetPosition(0, 0);
			window:SetMouseVisible(false);
			window:SetZOrder(-1000);
			BazUI.Scaling.Unscale(window);
		end
		Draw();
		window:SetVisible(true);
	elseif window ~= nil then
		window:SetVisible(false);
	end
end

function Grid.Start()
	settings = BazUI.Settings.Get("Core").Grid;
	BazUI.Events.OnLayoutMode("grid", Update);
end

-- /bazui grid
function Grid.Toggle()
	forced = not forced;
	if forced and not settings.Enabled then
		Turbine.Shell.WriteLine("BazUI: the grid is switched off in /bazui > General.");
	end
	Update();
end

-- After a grid setting changes.
function Grid.Refresh()
	Update();
end

-- Its part of the General settings tab.
function Grid.BuildOptions(form)
	form:Heading("Layout mode (Ctrl+\\)");
	form:Check("Show an alignment grid while layout mode is on", settings.Enabled, function(on)
		settings.Enabled = on;
		Update();
	end);
	form:Slider("Grid spacing", 16, 128, settings.Spacing, function(value)
		settings.Spacing = value;
		Update();
	end, 8);
	form:Note("The gold lines mark the centre of the screen. /bazui grid shows the grid at any time.");
end
