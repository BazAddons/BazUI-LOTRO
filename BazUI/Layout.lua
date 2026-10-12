-- Layout.lua
-- Lets BazUI's free-standing objects be dragged while the game's UI layout
-- mode (Ctrl+\) is on - the same moment the game's own pieces can be moved -
-- and keeps them locked in place the rest of the time.

BazUI.Layout = {};

local OVERLAY_COLOR = Turbine.UI.Color(0.45, 0.25, 0.55, 0.95); -- alpha, r, g, b

-- Makes `window` draggable in layout mode. onMoved(left, top) is called when
-- a drag ends, to save the spot. Returns a function that re-fits the drag
-- overlay, to call after the window changes size.
function BazUI.Layout.MakeMovable(label, window, onMoved)
	local Display = Turbine.UI.Display;

	local overlay = Turbine.UI.Control();
	overlay:SetParent(window);
	overlay:SetBackColor(OVERLAY_COLOR);
	overlay:SetZOrder(100);
	overlay:SetVisible(false);

	-- Drag in screen coordinates, so it tracks the cursor whatever scale the
	-- window is drawn at.
	local dragging = false;
	local mouseX, mouseY, startLeft, startTop;

	overlay.MouseDown = function(sender, args)
		dragging = true;
		mouseX, mouseY = Display.GetMouseX(), Display.GetMouseY();
		startLeft, startTop = window:GetLeft(), window:GetTop();
	end

	overlay.MouseMove = function(sender, args)
		if dragging then
			window:SetPosition(startLeft + Display.GetMouseX() - mouseX, startTop + Display.GetMouseY() - mouseY);
		end
	end

	overlay.MouseUp = function(sender, args)
		if dragging then
			dragging = false;
			onMoved(window:GetLeft(), window:GetTop());
		end
	end

	local function Fit()
		overlay:SetSize(window:GetWidth(), window:GetHeight());
		overlay:SetVisible(BazUI.Events.IsLayoutUnlocked());
	end

	BazUI.Events.OnLayoutMode(label, Fit);
	Fit();
	return Fit;
end
