-- Options/Form.lua
-- Builds a settings tab top to bottom; each call adds one row under the last.
--
--   local form = BazUI.Options.Form(parent, width)
--   form:Heading(text)
--   form:Note(text)                                returns the label
--   form:Check(text, checked, onChange)            onChange(isChecked)
--   form:Slider(text, min, max, value, onChange [, step])   onChange(value)
--   form:Button(text, onClick)
--   form:Cycle(text, choices, current, onChange)   a button that steps through
--                                  choices = { { value, label }, ... }; onChange(value)
--   form:Height()                                  how tall it ended up

BazUI.Options = BazUI.Options or {};

local ROW_GAP = 6;
local HEADING_GAP = 12;   -- extra space above a heading that isn't first
local NOTE_LINE = 16;     -- Verdana14 line height
local NOTE_CHAR_W = 7.2;  -- rough Verdana14 character width, to size notes

-- Colors are alpha, r, g, b; golds are tables, shown through BazUI.Accent.
local HEADING_GOLD = { 1, 0.90, 0.78, 0.42 };
local TEXT_COLOR = Turbine.UI.Color(1, 0.90, 0.88, 0.82);
local NOTE_COLOR = Turbine.UI.Color(1, 0.62, 0.62, 0.60);

local Form = {};
Form.__index = Form;

function BazUI.Options.Form(parent, width)
	return setmetatable({ parent = parent, width = width, y = 0 }, Form);
end

-- Places a control on the next row and moves the cursor below it.
function Form:Place(control, height, left)
	control:SetParent(self.parent);
	control:SetPosition(left or 0, self.y);
	self.y = self.y + height + ROW_GAP;
	return control;
end

function Form:Height()
	return self.y;
end

local function Label(text, font, color, width, height)
	local label = Turbine.UI.Label();
	label:SetSize(width, height);
	label:SetFont(font);
	label:SetForeColor(color);
	label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
	label:SetText(text);
	return label;
end

function Form:Heading(text)
	if self.y > 0 then
		self.y = self.y + HEADING_GAP;
	end
	local heading = self:Place(Label(text, Turbine.UI.Lotro.Font.TrajanPro14, TEXT_COLOR, self.width, 20), 20);
	BazUI.Accent.Bind(heading, "SetForeColor", HEADING_GOLD);
end

function Form:Note(text)
	local perLine = math.max(1, math.floor(self.width / NOTE_CHAR_W));
	local height = math.ceil(#text / perLine) * NOTE_LINE;
	local label = Label(text, Turbine.UI.Lotro.Font.Verdana14, NOTE_COLOR, self.width, height);
	label:SetMultiline(true);
	label:SetTextAlignment(Turbine.UI.ContentAlignment.TopLeft);
	return self:Place(label, height);
end

function Form:Check(text, checked, onChange)
	local box = Turbine.UI.Lotro.CheckBox();
	box:SetSize(self.width, 20);
	box:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	box:SetForeColor(TEXT_COLOR);
	box:SetText(" " .. text);
	box:SetChecked(checked == true);
	box.CheckedChanged = BazUI.Guard("options check", function(sender, args)
		onChange(box:IsChecked());
	end);
	return self:Place(box, 20);
end

-- A label showing the current value, with a horizontal slider under it.
function Form:Slider(text, min, max, value, onChange, step)
	step = step or 1;
	local label = self:Place(Label(text .. ": " .. value, Turbine.UI.Lotro.Font.Verdana14, TEXT_COLOR, self.width, 18), 18);
	self.y = self.y - ROW_GAP + 2;

	-- The scroll bar works in steps, so a 300-2400 slider in 50s runs 0-42.
	local bar = Turbine.UI.Lotro.ScrollBar();
	bar:SetOrientation(Turbine.UI.Orientation.Horizontal);
	bar:SetSize(math.min(self.width, 320), 10);
	bar:SetMinimum(0);
	bar:SetMaximum(math.floor((max - min) / step));
	bar:SetSmallChange(1);
	bar:SetLargeChange(1);
	bar:SetValue(math.floor((value - min) / step + 0.5));
	bar.ValueChanged = BazUI.Guard("options slider", function(sender, args)
		local current = min + bar:GetValue() * step;
		label:SetText(text .. ": " .. current);
		onChange(current);
	end);
	return self:Place(bar, 10);
end

function Form:Cycle(text, choices, current, onChange)
	local index = 1;
	for i, choice in ipairs(choices) do
		if choice[1] == current then
			index = i;
		end
	end
	local button;
	local function Label()
		return text .. ": " .. choices[index][2];
	end
	button = self:Button(Label(), function()
		index = index % #choices + 1;
		button:SetText(Label());
		onChange(choices[index][1]);
	end);
	return button;
end

function Form:Button(text, onClick)
	local button = Turbine.UI.Lotro.Button();
	button:SetSize(220, 20);
	button:SetText(text);
	button.Click = BazUI.Guard("options button", function(sender, args)
		onClick();
	end);
	return self:Place(button, 20);
end
