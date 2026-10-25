local config = PaleWormEncounter.config
PaleWormEncounter.cleanup(true) -- Script reload also ends the previous session.

for _, floor in ipairs({ "upper", "lower" }) do
	local zone = Zone("pale-worm." .. floor)
	zone:addArea(config[floor].from, config[floor].to)
	zone:trapMonsters()
	local event = ZoneEvent(zone)
	function event.afterEnter(_, creature)
		local player = creature:getPlayer()
		if player then
			PaleWormEncounter.enter(player)
			if floor == "lower" then
				PaleWormEncounter.enterLower(player)
			end
		end
	end
	function event.afterLeave(_, creature)
		local player = creature:getPlayer()
		if not player then
			PaleWormEncounter.removed(creature)
			return
		end
		if floor == "lower" then
			PaleWormEncounter.leaveLower(player)
		end
		if not PaleWormEncounter.floor(player:getPosition()) then
			player:removeCondition(CONDITION_GREATERHEX, CONDITIONID_COMBAT, config.hexSubId)
		end
	end
	event:register()
end

local ramp = MoveEvent()
function ramp.onStepIn(creature)
	local state = PaleWormEncounter.state
	local player = creature:getPlayer()
	if player and state and state.players[player:getGuid()] then
		player:teleportTo(config.returnDestination)
		PaleWormEncounter.leaveLower(player)
	end
	return true
end
ramp:type("stepin")
ramp:position(config.returnPosition)
ramp:register()

local lantern = Action()
function lantern.onUse(player, item)
	local state = PaleWormEncounter.state
	local entry = state and state.players[player:getGuid()]
	if not entry or entry.id ~= player:getId() or entry.protected or not PaleWormEncounter.floor(player:getPosition()) then
		return false
	end
	entry.protected = true -- Protection succeeds even if the lantern burns out.
	player:removeCondition(CONDITION_GREATERHEX, CONDITIONID_COMBAT, config.hexSubId)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	if math.random(100) <= config.lanternBreakChance then
		item:remove(1)
	end
	return true
end
lantern:id(config.lanternId)
lantern:register()

local hungerDeath = CreatureEvent("PaleWormHungerDeath")
function hungerDeath.onDeath(creature, corpse)
	local state = PaleWormEncounter.state
	if not state or state.hungerId ~= creature:getId() or not PaleWormEncounter.boss() then
		return true
	end
	state.monsters[creature:getId()] = nil
	state.hungerId = nil
	if corpse then
		corpse:remove()
	end
	local position = creature:getPosition()
	local destination = Position(position.x, position.y, position.z + 1)
	if PaleWormEncounter.floor(position) ~= "upper" or PaleWormEncounter.floor(destination) ~= "lower" or not Tile(destination) then
		return true
	end
	PaleWormEncounter.closeHole()
	local tile = Tile(position)
	local ground = tile:getGround()
	if not ground or tile:getItemById(config.holeItemId) then
		return true
	end
	local originalId = ground:getId()
	-- A hole is ground: inserting/removing it would destroy the original floor.
	ground:transform(config.holeItemId)
	if ground:getId() == config.holeItemId then
		ground:setCustomAttribute("pale-worm-session", state.generation)
		state.hole = { x = position.x, y = position.y, z = position.z, originalId = originalId }
		PaleWormEncounter.schedule("hole", config.holeDuration, "closeHole")
	end
	return true
end
hungerDeath:register()

local greedDeath = CreatureEvent("PaleWormGreedDeath")
function greedDeath.onDeath(creature, corpse)
	local state = PaleWormEncounter.state
	if state then
		state.monsters[creature:getId()] = nil
	end
	if corpse then
		corpse:remove()
	end
	local radius = config.greedExplosionRadius
	for _, player in ipairs(Game.getSpectators(creature:getPosition(), false, true, radius, radius, radius, radius)) do
		doTargetCombatHealth(0, player, COMBAT_EARTHDAMAGE, -config.greedExplosionDamage, -config.greedExplosionDamage, CONST_ME_HITBYPOISON)
	end
	return true
end
greedDeath:register()

local weakSpot = CreatureEvent("PaleWormWeakSpotDamage")
function weakSpot.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	local state = PaleWormEncounter.state
	local boss = PaleWormEncounter.boss()
	if not state or not boss or state.weakSpotId ~= creature:getId() then
		return 0, primaryType, 0, secondaryType
	end
	local player = attacker and (attacker:getPlayer() or (attacker:getMaster() and attacker:getMaster():getPlayer()))
	local entry = player and state.players[player:getGuid()]
	if not entry or entry.id ~= player:getId() or PaleWormEncounter.floor(player:getPosition()) ~= "lower" then
		return 0, primaryType, 0, secondaryType
	end
	local damage = (primaryType ~= COMBAT_HEALING and math.abs(primaryDamage) or 0) + (secondaryType ~= COMBAT_HEALING and math.abs(secondaryDamage) or 0)
	damage = math.min(boss:getHealth(), math.floor(damage * config.weakSpotDamageMultiplier))
	if damage > 0 then
		local stats = GetPlayerStats(state.bossId, entry.guid, true)
		stats.playerId = entry.id
		stats.active = true
		stats.damageOut = (stats.damageOut or 0) + damage
		-- ORIGIN_NONE avoids a second resistance/Hex pass and recursion.
		-- Record contribution before a potentially lethal hit.
		boss:addHealth(-damage, COMBAT_UNDEFINEDDAMAGE)
	end
	return 0, primaryType, 0, secondaryType
end
weakSpot:register()

local resistance = CreatureEvent("PaleWormResistance")
function resistance.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if primaryType ~= COMBAT_HEALING then
		primaryDamage = math.floor(math.abs(primaryDamage) * config.bossDirectDamagePercent / 100)
	end
	if secondaryType ~= COMBAT_HEALING then
		secondaryDamage = math.floor(math.abs(secondaryDamage) * config.bossDirectDamagePercent / 100)
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
resistance:register()

local logout = CreatureEvent("PaleWormLogout")
function logout.onLogout(player)
	PaleWormEncounter.leaveLower(player)
	player:removeCondition(CONDITION_GREATERHEX, CONDITIONID_COMBAT, config.hexSubId)
	return true
end
logout:register()

local shutdown = GlobalEvent("PaleWormShutdown")
function shutdown.onShutdown()
	PaleWormEncounter.cleanup(true)
	return true
end
shutdown:register()
