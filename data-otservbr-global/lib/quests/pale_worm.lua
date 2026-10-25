-- Mechanics tuning is centralized here. Unverified balance/map values are defaults,
-- not claims about the official server; see docs/quests/pale-worm.md.
local generation = PaleWormEncounter and PaleWormEncounter.generation or 0
if PaleWormEncounter then
	PaleWormEncounter.cleanup(true)
end

PaleWormEncounter = {
	generation = generation,
	config = {
		upper = { from = Position(33793, 31496, 14), to = Position(33816, 31515, 14) },
		lower = { from = Position(33793, 31496, 15), to = Position(33816, 31515, 15) },
		bossPosition = Position(33805, 31504, 14),
		weakSpotPosition = Position(33805, 31504, 15),
		returnPosition = Position(33810, 31498, 15),
		returnDestination = Position(33810, 31498, 14),
		exit = Position(33572, 31451, 10),
		fightDuration = 25 * 60 * 1000,
		holeDuration = 10000,
		holeItemId = 385,
		hungerInterval = 30000,
		greedInterval = 15000,
		greedPerFloor = 4,
		deathInterval = 5000,
		deathInitial = 250,
		deathMultiplier = 2,
		deathMaximum = 16000,
		hexHealthPercent = 40,
		hexDamagePercent = 40,
		hexHealingPercent = 40,
		hexSubId = 47019,
		lanternId = 32591,
		lanternBreakChance = 20,
		greedExplosionDamage = 750,
		greedExplosionRadius = 1,
		bossDirectDamagePercent = 5,
		weakSpotDamageMultiplier = 1,
		participantCredit = 1,
		hungerHealth = 10000,
		greedHealth = 5000,
		weakSpotHealth = 420000,
		wormMeleeDamage = 600,
		wormLookType = 1275,
		weakSpotLookType = 1273,
	},
}

local function inside(position, area)
	return position.z == area.from.z and position.x >= area.from.x and position.x <= area.to.x and position.y >= area.from.y and position.y <= area.to.y
end

function PaleWormEncounter.floor(position)
	local config = PaleWormEncounter.config
	return inside(position, config.upper) and "upper" or inside(position, config.lower) and "lower" or nil
end

function PaleWormEncounter.player(entry)
	local player = Player(entry.id)
	return player and player:getGuid() == entry.guid and player or nil
end

function PaleWormEncounter.boss()
	local state = PaleWormEncounter.state
	local boss = state and Monster(state.bossId)
	return boss and boss:getName():lower() == "the pale worm" and PaleWormEncounter.floor(boss:getPosition()) == "upper" and boss or nil
end

local function clearHex(player)
	player:removeCondition(CONDITION_GREATERHEX, CONDITIONID_COMBAT, PaleWormEncounter.config.hexSubId)
end

function PaleWormEncounter.enter(player)
	local state = PaleWormEncounter.state
	local entry = state and state.players[player:getGuid()]
	if not entry or entry.id ~= player:getId() or entry.protected or player:getCondition(CONDITION_GREATERHEX, CONDITIONID_COMBAT, PaleWormEncounter.config.hexSubId) then
		return
	end
	local config = PaleWormEncounter.config
	local hex = Condition(CONDITION_GREATERHEX)
	hex:setParameter(CONDITION_PARAM_SUBID, config.hexSubId)
	hex:setParameter(CONDITION_PARAM_TICKS, -1)
	hex:setParameter(CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT, config.hexHealthPercent)
	hex:setParameter(CONDITION_PARAM_BUFF_DAMAGEDEALT, config.hexDamagePercent)
	hex:setParameter(CONDITION_PARAM_BUFF_HEALINGRECEIVED, config.hexHealingPercent)
	player:addCondition(hex)
end

function PaleWormEncounter.cancel(key)
	local state = PaleWormEncounter.state
	if state and state.events[key] then
		stopEvent(state.events[key])
		state.events[key] = nil
	end
	if state then
		state.tickets[key] = (state.tickets[key] or 0) + 1
	end
end

function PaleWormEncounter.schedule(key, delay, operation, ...)
	local state = PaleWormEncounter.state
	if not state then
		return
	end
	PaleWormEncounter.cancel(key)
	state.events[key] = addEvent(PaleWormEncounter.dispatch, math.max(1, math.min(delay, 2147483647)), state.generation, key, state.tickets[key], operation, ...)
end

function PaleWormEncounter.dispatch(token, key, ticket, operation, ...)
	local state = PaleWormEncounter.state
	if not state or state.generation ~= token or state.tickets[key] ~= ticket then
		return
	end
	state.events[key] = nil
	if not PaleWormEncounter.boss() then
		PaleWormEncounter.cleanup(true)
		return
	end
	PaleWormEncounter[operation](...)
end

function PaleWormEncounter.closeHole()
	local state = PaleWormEncounter.state
	if not state or not state.hole then
		return
	end
	local tile = Tile(state.hole)
	local item = tile and tile:getItemById(PaleWormEncounter.config.holeItemId)
	if item and item:getCustomAttribute("pale-worm-session") == state.generation then
		item:removeCustomAttribute("pale-worm-session")
		item:transform(state.hole.originalId)
	end
	state.hole = nil
	PaleWormEncounter.cancel("hole")
end

function PaleWormEncounter.cleanup(evacuate, killed)
	local state = PaleWormEncounter.state
	if not state then
		return
	end
	for _, eventId in pairs(state.events) do
		stopEvent(eventId)
	end
	state.events = {}
	PaleWormEncounter.closeHole()
	PaleWormEncounter.state = nil -- Invalidate before removing monsters or moving players.
	local lever = BossLever and BossLever["the pale worm"]
	if not killed and lever and lever.timeoutEvent then
		stopEvent(lever.timeoutEvent)
		lever.timeoutEvent = nil
	end
	for _, entry in pairs(state.players) do
		local player = PaleWormEncounter.player(entry)
		if player then
			clearHex(player)
			if evacuate and PaleWormEncounter.floor(player:getPosition()) then
				player:teleportTo(PaleWormEncounter.config.exit)
			end
		end
	end
	for id, name in pairs(state.monsters) do
		local monster = Monster(id)
		if monster and monster:getName() == name and (not killed or id ~= state.bossId) then
			monster:remove()
		end
	end
	if not killed then
		_G.GlobalBosses[state.bossId] = nil
	end
end

function PaleWormEncounter.spawn(name, position)
	local monster = Game.createMonster(name, position, true, true)
	if monster then
		PaleWormEncounter.state.monsters[monster:getId()] = monster:getName()
	end
	return monster
end

function PaleWormEncounter.hunger()
	local state = PaleWormEncounter.state
	local existing = state.hungerId and Monster(state.hungerId)
	if not existing and not state.hole then
		local monster = PaleWormEncounter.spawn("Hunger Worm", PaleWormEncounter.config.bossPosition)
		state.hungerId = monster and monster:getId() or nil
	end
	PaleWormEncounter.schedule("hunger", PaleWormEncounter.config.hungerInterval, "hunger")
end

function PaleWormEncounter.greed()
	local config = PaleWormEncounter.config
	for _, floor in ipairs({ "upper", "lower" }) do
		local zone = Zone("pale-worm." .. floor)
		for _ = zone:countMonsters("Greed Worm") + 1, config.greedPerFloor do
			local position = zone:randomPosition()
			if position then
				PaleWormEncounter.spawn("Greed Worm", position)
			end
		end
	end
	PaleWormEncounter.schedule("greed", config.greedInterval, "greed")
end

function PaleWormEncounter.leaveLower(player)
	local state = PaleWormEncounter.state
	local entry = state and state.players[player:getGuid()]
	if entry and entry.id == player:getId() then
		PaleWormEncounter.cancel("death:" .. entry.guid)
		entry.damage = nil
		entry.descent = (entry.descent or 0) + 1
	end
end

function PaleWormEncounter.enterLower(player)
	local state = PaleWormEncounter.state
	local entry = state and state.players[player:getGuid()]
	if not entry or entry.id ~= player:getId() then
		return
	end
	PaleWormEncounter.leaveLower(player)
	entry.damage = PaleWormEncounter.config.deathInitial
	PaleWormEncounter.schedule("death:" .. entry.guid, PaleWormEncounter.config.deathInterval, "deathTick", entry.guid, entry.descent)
end

function PaleWormEncounter.deathTick(guid, descent)
	local state = PaleWormEncounter.state
	local entry = state.players[guid]
	local player = entry and PaleWormEncounter.player(entry)
	if not player or entry.descent ~= descent or not entry.damage or PaleWormEncounter.floor(player:getPosition()) ~= "lower" then
		return
	end
	local config = PaleWormEncounter.config
	doTargetCombatHealth(0, player, COMBAT_DEATHDAMAGE, -entry.damage, -entry.damage, CONST_ME_MORTAREA)
	if PaleWormEncounter.state ~= state or entry.descent ~= descent or PaleWormEncounter.floor(player:getPosition()) ~= "lower" then
		return
	end
	entry.damage = math.min(config.deathMaximum, entry.damage * config.deathMultiplier)
	PaleWormEncounter.schedule("death:" .. guid, config.deathInterval, "deathTick", guid, descent)
end

function PaleWormEncounter.watch()
	local state = PaleWormEncounter.state
	local present = false
	for _, entry in pairs(state.players) do
		local player = PaleWormEncounter.player(entry)
		if player and PaleWormEncounter.floor(player:getPosition()) then
			present = true
			local stats = GetPlayerStats(state.bossId, entry.guid, true)
			stats.playerId = entry.id
			stats.active = true
		else
			local stats = _G.GlobalBosses[state.bossId] and _G.GlobalBosses[state.bossId][entry.guid]
			if stats then
				stats.active = false
			end
			if player then
				clearHex(player)
				PaleWormEncounter.leaveLower(player)
			end
		end
	end
	if not present then
		PaleWormEncounter.cleanup(false)
		return
	end
	PaleWormEncounter.schedule("watch", 1000, "watch")
end

function PaleWormEncounter.start(players)
	PaleWormEncounter.cleanup(true)
	local config = PaleWormEncounter.config
	for _, position in ipairs({ config.bossPosition, config.weakSpotPosition, config.returnPosition, config.returnDestination }) do
		if not Tile(position) then
			logger.error("Pale Worm: missing mechanic tile at {}", position:toString())
			return false
		end
	end
	PaleWormEncounter.generation = PaleWormEncounter.generation + 1
	PaleWormEncounter.state = { generation = PaleWormEncounter.generation, players = {}, events = {}, tickets = {}, monsters = {} }
	local state = PaleWormEncounter.state
	local boss = PaleWormEncounter.spawn("The Pale Worm", config.bossPosition)
	if not boss then
		PaleWormEncounter.state = nil
		return false
	end
	state.bossId = boss:getId()
	if not _G.GlobalBosses[state.bossId] then
		boss:setReward(true)
	end
	boss:registerEvent("BossLeverOnDeath")
	boss:unregisterEvent("BossThink") -- Target lists exclude the other floor.
	local weakSpot = PaleWormEncounter.spawn("A Weak Spot", config.weakSpotPosition)
	if not weakSpot then
		PaleWormEncounter.cleanup(false)
		return false
	end
	state.weakSpotId = weakSpot:getId()
	for _, player in ipairs(players) do
		local guid = player:getGuid()
		state.players[guid] = { id = player:getId(), guid = guid }
		player:registerEvent("PaleWormLogout")
		local stats = GetPlayerStats(state.bossId, guid, true)
		stats.playerId = player:getId()
		stats.damageOut = config.participantCredit
		stats.active = true
	end
	PaleWormEncounter.greed()
	PaleWormEncounter.schedule("hunger", config.hungerInterval, "hunger")
	PaleWormEncounter.schedule("watch", 1000, "watch")
	PaleWormEncounter.schedule("timeout", config.fightDuration, "cleanup", true)
	return boss
end

function PaleWormEncounter.removed(creature)
	local state = PaleWormEncounter.state
	local id = creature:getId()
	if not state or not state.monsters[id] then
		return
	end
	state.monsters[id] = nil
	if id == state.bossId or id == state.weakSpotId then
		PaleWormEncounter.cleanup(true)
	elseif id == state.hungerId then
		state.hungerId = nil
	end
end
