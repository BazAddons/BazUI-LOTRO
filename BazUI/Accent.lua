-- Accent.lua
-- BazUI's accent colour: gold, or grey (General tab, Core.Accent). Borders,
-- lines and headings are bound to it, so they change the moment it does; gold
-- art is shown grey through the Grayscale blend mode, the only clean way the
-- live client has to recolour an image (DEVELOPERS.md). The game's own windows
-- follow when the skin is next built - Skin/build_skin.py reads the setting.

BazUI.Accent = {};
local Accent = BazUI.Accent;

-- For the settings tab: value, then what it's called.
Accent.CHOICES = { { "gold", "Gold" }, { "grey", "Grey" } };

local WHITE = Turbine.UI.Color(1, 1, 1, 1);
local CLEAR = Turbine.UI.Color(0, 0, 0, 0);

local bound = setmetatable({}, { __mode = "k" });   -- control -> { [method] = gold }
local images = setmetatable({}, { __mode = "k" });  -- control -> true: shows gold art

function Accent.Get()
	return BazUI.Settings.Get("Core").Accent == "grey" and "grey" or "gold";
end

-- A gold, { alpha, r, g, b }, as the accent has it: itself, or a grey as bright.
function Accent.Color(gold)
	local a, r, g, b = gold[1], gold[2], gold[3], gold[4];
	if Accent.Get() == "grey" then
		local v = 0.299 * r + 0.587 * g + 0.114 * b;
		return Turbine.UI.Color(a, v, v, v);
	end
	return Turbine.UI.Color(a, r, g, b);
end

-- Sets `control`'s colour with `method` ("SetForeColor", "SetBackColor") to
-- the accent's version of `gold`, and keeps it so when the accent changes.
function Accent.Bind(control, method, gold)
	bound[control] = bound[control] or {};
	bound[control][method] = gold;
	control[method](control, Accent.Color(gold));
end

-- Stops following the accent, for a colour that's set to something else now.
function Accent.Unbind(control, method)
	if bound[control] ~= nil then
		bound[control][method] = nil;
	end
end

local function Paint(control)
	if Accent.Get() == "grey" then
		control:SetBackColor(WHITE);
		control:SetBackColorBlendMode(Turbine.UI.BlendMode.Grayscale);
	else
		control:SetBackColorBlendMode(Turbine.UI.BlendMode.None);
		control:SetBackColor(CLEAR);
	end
end

-- The gold art on `control` is shown grey while the accent is.
function Accent.Image(control)
	images[control] = true;
	if Accent.Get() == "grey" then
		local ok, err = pcall(Paint, control);
		if not ok then
			BazUI.Log.Error("accent: couldn't grey an image: " .. tostring(err));
		end
	end
end

function Accent.Set(name)
	BazUI.Settings.Get("Core").Accent = name;
	BazUI.Settings.Save(); -- build_skin.py reads the saved file
	for control, colours in pairs(bound) do
		for method, gold in pairs(colours) do
			pcall(control[method], control, Accent.Color(gold));
		end
	end
	for control in pairs(images) do
		pcall(Paint, control);
	end
	BazUI.Log.Write("accent " .. name);
end
