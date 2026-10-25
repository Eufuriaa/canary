local config = PaleWormEncounter.config
for _, definition in ipairs({
	{ name = "Hunger Worm", health = config.hungerHealth, event = "PaleWormHungerDeath" },
	{ name = "Greed Worm", health = config.greedHealth, event = "PaleWormGreedDeath" },
	{ name = "A Weak Spot", health = config.weakSpotHealth, event = "PaleWormWeakSpotDamage", stationary = true },
}) do
	local mType = Game.createMonsterType(definition.name)
	local monster = {
		description = definition.name:lower(),
		experience = 0,
		outfit = { lookType = definition.stationary and config.weakSpotLookType or config.wormLookType },
		health = definition.health,
		maxHealth = definition.health,
		race = "undead",
		speed = definition.stationary and 0 or 220,
		corpse = definition.stationary and 32726 or 32733,
		events = { definition.event },
		changeTarget = { interval = 4000, chance = 0 },
		flags = {
			summonable = false,
			attackable = true,
			hostile = not definition.stationary,
			convinceable = false,
			pushable = false,
			rewardBoss = false,
			illusionable = false,
			canPushItems = false,
			canPushCreatures = false,
			staticAttackChance = 100,
			targetDistance = 1,
			runHealth = 0,
		},
		attacks = definition.stationary and {} or {
			{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -config.wormMeleeDamage },
		},
		defenses = { defense = 0, armor = 0 },
		loot = {},
		immunities = {
			{ type = "paralyze", condition = true },
			{ type = "invisible", condition = true },
		},
	}
	mType:register(monster)
end
