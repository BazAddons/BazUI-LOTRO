-- Events.lua
-- Game events more than one BazUI module needs. The API keeps a single
-- handler per event, so BazUI hooks each one once here and passes it on.
--
--   BazUI.Events.OnChat(label, handler)        handler(args) for every chat
--                                              message (args.ChatType, args.Message)
--   BazUI.Events.OnLayoutMode(label, handler)  handler(unlocked) when the
--                                              player toggles UI layout mode (Ctrl+\)
--   BazUI.Events.IsLayoutUnlocked()
--   BazUI.Events.OnAction(label, handler)      handler(action) for every key
--                                              action the player triggers
--                                              (Turbine.UI.Lotro.Action values)
--   BazUI.Events.OnPlayer(event, label, handler)  handler(sender, args) for one
--                                              of the local player's events
--                                              (LevelChanged, MoraleChanged, ...)

BazUI.Events = {};

local chatHandlers = {};
local layoutHandlers = {};
local actionHandlers = {};
local playerHandlers = {};   -- event name -> { handler, ... }
local layoutUnlocked = false;
local keyListener;

function BazUI.Events.OnChat(label, handler)
	table.insert(chatHandlers, BazUI.Guard(label .. " chat", handler));
end

function BazUI.Events.OnLayoutMode(label, handler)
	table.insert(layoutHandlers, BazUI.Guard(label .. " layout", handler));
end

function BazUI.Events.OnAction(label, handler)
	table.insert(actionHandlers, BazUI.Guard(label .. " action", handler));
end

-- Several modules want the same player events (the XP bar and the unit
-- frames both need LevelChanged), so each is hooked once and fanned out.
function BazUI.Events.OnPlayer(event, label, handler)
	local list = playerHandlers[event];
	if list == nil then
		list = {};
		playerHandlers[event] = list;
		Turbine.Gameplay.LocalPlayer.GetInstance()[event] = function(sender, args)
			for _, each in ipairs(list) do
				each(sender, args);
			end
		end
	end
	table.insert(list, BazUI.Guard(label .. " " .. event, handler));
end

function BazUI.Events.IsLayoutUnlocked()
	return layoutUnlocked;
end

function BazUI.Events.Start()
	Turbine.Chat.Received = function(sender, args)
		for _, handler in ipairs(chatHandlers) do
			handler(args);
		end
	end

	-- The game's layout mode can't be asked about, only watched: it flips
	-- each time the player presses the key for it.
	keyListener = Turbine.UI.Control();
	keyListener:SetWantsKeyEvents(true);
	keyListener.KeyDown = function(sender, args)
		if args.Action == Turbine.UI.Lotro.Action.ToggleHiddenDragBoxes then
			layoutUnlocked = not layoutUnlocked;
			for _, handler in ipairs(layoutHandlers) do
				handler(layoutUnlocked);
			end
		end
		for _, handler in ipairs(actionHandlers) do
			handler(args.Action);
		end
	end
end

function BazUI.Events.Stop()
	Turbine.Chat.Received = nil;
	if keyListener ~= nil then
		keyListener:SetWantsKeyEvents(false);
	end
end
