local lever
local mechanics = PaleWormEncounter.config
local config = {
	boss = {
		name = "The Pale Worm",
		position = Position(33805, 31504, 14),
		createFunction = function()
			return PaleWormEncounter.start(lever.lever:getPlayers())
		end,
	},
	requiredLevel = 250,
	timeToDefeat = mechanics.fightDuration / 1000,
	playerPositions = {
		{ pos = Position(33772, 31504, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33773, 31504, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33774, 31504, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33775, 31504, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33773, 31503, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33774, 31503, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33775, 31503, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33773, 31505, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33774, 31505, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(33775, 31505, 14), teleport = Position(33808, 31513, 14), effect = CONST_ME_TELEPORT },
	},
	specPos = mechanics.upper,
	exit = mechanics.exit,
}

lever = BossLever(config)
lever:position({ x = 33771, y = 31504, z = 14 })
lever:register()
-- Occupancy and evacuation must cover both floors.
lever:getZone():addArea(mechanics.lower.from, mechanics.lower.to)
