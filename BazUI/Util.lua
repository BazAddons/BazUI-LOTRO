-- Util.lua
-- Small helpers shared by modules.

BazUI.Util = {};

-- 1234567 -> "1,234,567"
function BazUI.Util.Thousands(n)
	local text = tostring(math.floor(n));
	local result = "";
	while #text > 3 do
		result = "," .. string.sub(text, -3) .. result;
		text = string.sub(text, 1, -4);
	end
	return text .. result;
end
