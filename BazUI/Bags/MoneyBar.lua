-- Bags/MoneyBar.lua
-- Your coin along the bottom of the bag window: gold, silver, copper.
--
-- The game keeps money as one copper count: 100 copper to a silver, 1000
-- silver to a gold.

BazUI.Bags = BazUI.Bags or {};
BazUI.Bags.MoneyBar = {};
local MoneyBar = BazUI.Bags.MoneyBar;

MoneyBar.HEIGHT = 20;

local COPPER_PER_SILVER = 100;
local SILVER_PER_GOLD = 1000;

-- One right-aligned label, each amount in its coin's color using the game's
-- <rgb=#RRGGBB> markup; plain gold text where markup isn't available.
local COLORS = { gold = "FFD64C", silver = "D1D6E0", copper = "DB8F57" };
local PLAIN_COLOR = Turbine.UI.Color(1, 1.00, 0.84, 0.30); -- alpha, r, g, b

local player, attributes, label;
local markup = false;

-- The copper count, from wherever this client keeps it, plus where that was.
local function ReadMoney()
	for _, source in ipairs({ { "attributes", attributes }, { "player", player } }) do
		if source[2] ~= nil then
			local ok, money = pcall(function() return source[2]:GetMoney(); end);
			if ok and type(money) == "number" then
				return money, source[1];
			end
		end
	end
end

local function Amount(text, color)
	if markup then
		return "<rgb=#" .. color .. ">" .. text .. "</rgb>";
	end
	return text;
end

function MoneyBar.Refresh()
	local money = ReadMoney();
	if money == nil then
		label:SetText("?");
		return;
	end

	local gold = math.floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
	local silver = math.floor(money / COPPER_PER_SILVER) % SILVER_PER_GOLD;
	local copper = money % COPPER_PER_SILVER;
	label:SetText(
		Amount(BazUI.Util.Thousands(gold) .. "g", COLORS.gold) .. "  " ..
		Amount(silver .. "s", COLORS.silver) .. "  " ..
		Amount(copper .. "c", COLORS.copper));
end

function MoneyBar.SetVisible(show)
	label:SetVisible(show);
end

-- Puts the bar at (left, top), its text right-aligned within width.
function MoneyBar.Place(left, top, width)
	label:SetPosition(left, top);
	label:SetSize(width, MoneyBar.HEIGHT);
end

function MoneyBar.Create(parent)
	player = Turbine.Gameplay.LocalPlayer.GetInstance();
	local ok, value = pcall(function() return player:GetAttributes(); end);
	attributes = ok and value or nil;

	label = Turbine.UI.Label();
	label:SetParent(parent);
	label:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	label:SetForeColor(PLAIN_COLOR);
	label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleRight);
	label:SetMouseVisible(false);
	if label.SetMarkupEnabled ~= nil then
		label:SetMarkupEnabled(true);
		markup = true;
	end

	-- The change event lives with whichever object has GetMoney; hooking
	-- both is harmless where one doesn't exist.
	local onChange = BazUI.Guard("bags MoneyChanged", function(sender, args)
		BazUI.Trace("bags: MoneyChanged");
		MoneyBar.Refresh();
	end);
	if attributes ~= nil then
		attributes.MoneyChanged = onChange;
	end
	BazUI.Events.OnPlayer("MoneyChanged", "bags", onChange);

	MoneyBar.Refresh();
	return label;
end
