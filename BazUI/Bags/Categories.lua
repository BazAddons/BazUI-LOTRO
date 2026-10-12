-- Bags/Categories.lua
-- Which category each item belongs to, and the order items sit in within one.
--
-- Rules match on the names of LOTRO's own enums (Turbine.Gameplay.ItemCategory
-- and ItemQuality) rather than their numbers, so they read as words and keep
-- working if the game renumbers anything. As in the WoW BazUI, where a
-- category is drawn (its place in LIST) and when it gets asked (its rank) are
-- separate: categories are asked lowest rank first, the first match takes
-- the item, and anything nobody claims goes to Other. A pin - the player
-- dropping an item on a category's heading - beats the rules.

BazUI.Bags = BazUI.Bags or {};
BazUI.Bags.Categories = {};
local Categories = BazUI.Bags.Categories;

-- value -> name for one of the game's enums.
local function EnumNames(enum)
	local names = {};
	if type(enum) == "table" then
		for name, value in pairs(enum) do
			if type(name) == "string" and type(value) ~= "function" then
				names[value] = name;
			end
		end
	end
	return names;
end

local CATEGORY_NAMES = EnumNames(Turbine.Gameplay.ItemCategory);
local QUALITY_NAMES = EnumNames(Turbine.Gameplay.ItemQuality);

-- LOTRO's item colours, worst to best: white, yellow, purple, teal, orange.
local QUALITY_RANK = { common = 1, uncommon = 2, rare = 3, incomparable = 4, legendary = 5, epic = 5 };

-- Matches an item whose lower-cased ItemCategory name is one of `names`, or
-- starts with one of `prefixes`, or ends with one of `suffixes` (and is
-- longer than the suffix, so "Scroll" itself isn't caught by "...Scroll").
local function OneOf(names, prefixes, suffixes)
	local set = {};
	for _, name in ipairs(names) do
		set[string.lower(name)] = true;
	end
	return function(categoryName)
		if set[categoryName] then
			return true;
		end
		for _, prefix in ipairs(prefixes or {}) do
			if string.sub(categoryName, 1, #prefix) == prefix then
				return true;
			end
		end
		for _, suffix in ipairs(suffixes or {}) do
			if #categoryName > #suffix and string.sub(categoryName, -#suffix) == suffix then
				return true;
			end
		end
		return false;
	end
end

-- In display order. Names are the game's ItemCategory names, from the full
-- list v005 logged; anything not named here lands in Other.
local LIST = {
	{ key = "equipment", label = "Equipment", rank = 5, match = OneOf({
		-- armour and jewellery
		"Armor", "Head", "Shoulders", "Chest", "Back", "Hands", "Legs", "Feet", "Shield", "Jewelry",
		-- weapons
		"Weapon", "Axe", "Bow", "Club", "Crossbow", "Dagger", "Halberd", "Hammer", "Javelin", "Mace",
		"Spear", "Staff", "Sword", "Thrown", "Orb", -- rune-stones report as Staff or Orb
		-- class items
		"Beorning", "Brawler", "Burglar", "Captain", "Champion", "Guardian", "GuardianBelt", "Hunter",
		"Loremaster", "Mariner", "Minstrel", "MinstrelBook", "Runekeeper", "Shieldspike", "Warden",
		"Instrument" }) },
	{ key = "cosmetics", label = "Cosmetics", rank = 6,
		match = OneOf({ "Clothing", "Dye" }, { "cosmetic" }) },
	{ key = "consumables", label = "Consumables", rank = 7, match = OneOf({
		"Food", "LoremasterFood", "Potion", "Healing", "Scroll", "Trap", "Oil", "Travel", "Map",
		"Tome", "Special" }) },
	{ key = "legendary", label = "Legendary Items", rank = 3,
		match = OneOf({ "Relic", "Deconstructable" }, { "legendaryweapon" }) },
	{ key = "crafting", label = "Crafting", rank = 4, match = OneOf({
		"Crafting", "CraftingTrophy", "Component", "Ingredient", "OptionalIngredient", "Resource",
		"Tool", "Fish", "FishingBait", "FishingOther", "FishingPole",
		"287" }, -- hides like Rough Fur: a category number the game's enum has no name for
		nil, { "scroll" }) }, -- the tiered recipe scrolls: ApprenticeCookScroll ... WestfoldWoodworkScroll
	{ key = "barter", label = "Barter & Tokens", rank = 8,
		match = OneOf({ "Barter", "Reputation", "Skirmish", "Festival" }) },
	{ key = "housing", label = "Housing", rank = 9,
		match = OneOf({ "Decoration" }, nil, { "decoration" }) },
	{ key = "quest", label = "Quest Items", rank = 1,
		match = OneOf({ "Quest", "Key" }) },
	{ key = "trophies", label = "Trophies & Treasure", rank = 2,
		match = OneOf({ "Trophy", "Treasure", "SpecialTrophy" }) },
	{ key = "other", label = "Other", rank = 99,
		match = function() return true; end },
};

local MATCH_ORDER = {};
local BY_KEY = {};
for _, category in ipairs(LIST) do
	table.insert(MATCH_ORDER, category);
	BY_KEY[category.key] = category;
end
table.sort(MATCH_ORDER, function(a, b) return a.rank < b.rank; end);

-- Item name -> category key, the player's pins (the Bags settings table).
local pins = {};

function Categories.SetPins(table)
	pins = table or {};
end

function Categories.Get(key)
	return BY_KEY[key];
end

-- Calls object:method(), or returns nil if the object or method isn't there.
local function Call(object, method)
	if object == nil then
		return nil;
	end
	local ok, value = pcall(function() return object[method](object); end);
	if ok then
		return value;
	end
end

-- ItemCategory names already reported as landing in Other this session.
local reportedOther = {};

local function Classify(entry)
	for _, category in ipairs(MATCH_ORDER) do
		if category.match(entry.categoryName) then
			if category.key == "other" and not reportedOther[entry.categoryName] then
				reportedOther[entry.categoryName] = true;
				BazUI.Log.Write("bags: " .. entry.name .. " (" .. entry.categoryName .. ") filed under Other");
			end
			return category;
		end
	end
end

-- Everything the window needs to know about the item in one slot: where it
-- files, how it sorts, what search matches it on and how its slot is tinted.
--   index, name, quantity, categoryName (the game's, lower-cased),
--   qualityName (lower-cased), quality (rank, higher is better),
--   category (entry from LIST), autoCategory (where the rules alone put it),
--   pinned (true when a pin decided the category)
function Categories.Describe(item, index)
	local info = Call(item, "GetItemInfo");
	local category = Call(info, "GetCategory") or Call(item, "GetCategory");
	local quality = Call(info, "GetQuality") or Call(item, "GetQuality");
	local entry = {
		index = index,
		name = Call(item, "GetName") or Call(info, "GetName") or "",
		quantity = Call(item, "GetQuantity") or 1,
		categoryName = string.lower(CATEGORY_NAMES[category] or tostring(category)),
		qualityName = string.lower(QUALITY_NAMES[quality] or ""),
	};
	entry.quality = QUALITY_RANK[entry.qualityName] or 0;
	entry.autoCategory = Classify(entry);
	local pinnedTo = BY_KEY[pins[entry.name] or ""];
	entry.category = pinnedTo or entry.autoCategory;
	entry.pinned = pinnedTo ~= nil;
	return entry;
end

-- Best quality first, then by name, then biggest stack first.
local function Before(a, b)
	if a.quality ~= b.quality then return a.quality > b.quality; end
	if a.name ~= b.name then return a.name < b.name; end
	if a.quantity ~= b.quantity then return a.quantity > b.quantity; end
	return a.index < b.index;
end

-- Groups described slots (slot index -> entry, for the first `count` slots)
-- by category. Returns, in display order:
--   { { category = <entry from LIST>, entries = { entry, ... } }, ... }
-- with each group's entries already sorted. Empty categories are left out
-- unless showEmpty is set (categorize mode, so items can be dropped on them).
function Categories.Group(entries, count, showEmpty)
	local buckets = {};
	for index = 1, count do
		local entry = entries[index];
		if entry ~= nil then
			local key = entry.category.key;
			buckets[key] = buckets[key] or {};
			table.insert(buckets[key], entry);
		end
	end

	local groups = {};
	for _, category in ipairs(LIST) do
		local bucket = buckets[category.key];
		if bucket ~= nil then
			table.sort(bucket, Before);
			table.insert(groups, { category = category, entries = bucket });
		elseif showEmpty then
			table.insert(groups, { category = category, entries = {} });
		end
	end
	return groups;
end

-- Search: does the (lower-cased, non-empty) query appear in the item's name,
-- its category, the game's category name or its quality? Plain substring
-- matching, so characters like "-" or "(" in a query are just characters.
function Categories.Matches(entry, query)
	return string.find(string.lower(entry.name), query, 1, true) ~= nil
		or string.find(string.lower(entry.category.label), query, 1, true) ~= nil
		or string.find(entry.categoryName, query, 1, true) ~= nil
		or string.find(entry.qualityName, query, 1, true) ~= nil;
end

-- For /bazui debug: where each item in the bag landed, and why.
function Categories.LogSnapshot(backpack)
	if not BazUI.Debug then
		return;
	end
	local count = backpack:GetSize();
	local entries = {};
	for index = 1, count do
		local item = backpack:GetItem(index);
		if item ~= nil then
			entries[index] = Categories.Describe(item, index);
		end
	end
	for _, group in ipairs(Categories.Group(entries, count)) do
		local parts = {};
		for _, entry in ipairs(group.entries) do
			table.insert(parts, entry.name .. " (" .. entry.categoryName .. ", " .. entry.qualityName .. ")");
		end
		BazUI.Trace("bags: " .. group.category.label .. ": " .. table.concat(parts, ", "));
	end
end
