-- Run from the repository root: luajit tests/lua/test_pale_worm_mechanics.lua
local root = "data-otservbr-global/"
local nextId, now = 0, 0
local pending, players, monsters, tiles, events, zones, actions = {}, {}, {}, {}, {}, {}, {}
local damageLog = {}
for index, name in ipairs({
	"CONDITION_GREATERHEX", "CONDITIONID_COMBAT", "CONDITION_PARAM_SUBID", "CONDITION_PARAM_TICKS",
	"CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT", "CONDITION_PARAM_BUFF_DAMAGEDEALT", "CONDITION_PARAM_BUFF_HEALINGRECEIVED",
	"COMBAT_DEATHDAMAGE", "COMBAT_HEALING", "COMBAT_UNDEFINEDDAMAGE", "COMBAT_EARTHDAMAGE", "COMBAT_PHYSICALDAMAGE",
	"CONST_ME_MORTAREA", "CONST_ME_MAGIC_BLUE", "CONST_ME_HITBYPOISON", "CONST_ME_TELEPORT", "MESSAGE_EVENT_ADVANCE",
}) do
	_G[name] = index
end
Storage = { Quest = { U12_30 = { PoltergeistOutfits = { Received = 1 }, FeasterOfSouls = { PaleWormKilled = 2 } } } }
GlobalBosses = {}
logger = { error = function() end }
function Position(x, y, z)
	if type(x) == "table" then
		x, y, z = x.x, x.y, x.z
	end
	return { x = x, y = y, z = z, toString = function() return "position" end, sendMagicEffect = function() end }
end
function Player(id) return players[id] end
function Monster(id) return monsters[id] end
function Condition(kind)
	return { kind = kind, setParameter = function(self, key, value) self[key] = value end }
end
function CreatureEvent(name)
	local event = { register = function() end }
	events[name] = event
	return event
end
function GlobalEvent(name) return CreatureEvent(name) end
function Zone(name)
	if not zones[name] then
		zones[name] = {
			addArea = function(self, from, to) self.from, self.to = from, to end,
			trapMonsters = function() end,
			countMonsters = function(self, nameToCount)
				local count = 0
				for _, monster in pairs(monsters) do
					if monster.name == nameToCount and monster.position.z == self.from.z then count = count + 1 end
				end
				return count
			end,
			randomPosition = function(self) return Position(33803, 31503, self.from.z) end,
		}
	end
	return zones[name]
end
function ZoneEvent(zone)
	local event = { register = function(self) zone.event = self end }
	return event
end
function Action()
	local action = { register = function() end, id = function(self, id) actions[id] = self end }
	return action
end
function MoveEvent()
	return { type = function() end, position = function(self, pos) self.pos = pos end, register = function(self) actions.ramp = self end }
end
local function tileKey(pos) return pos.x .. ":" .. pos.y .. ":" .. pos.z end
function Tile(pos)
	local key = tileKey(pos)
	if not tiles[key] then
		tiles[key] = { items = {}, getItemById = function(self, id) return self.items[id] end }
		local tile = tiles[key]
		tile.ground = {
			id = 100,
			getId = function(self) return self.id end,
			setCustomAttribute = function(self, name, value) self[name] = value end,
			getCustomAttribute = function(self, name) return self[name] end,
			removeCustomAttribute = function(self, name) self[name] = nil end,
			transform = function(self, id)
				tile.items[self.id] = nil
				self.id = id
				tile.items[id] = self
				return true
			end,
		}
		tile.getGround = function(self) return self.ground end
	end
	return tiles[key]
end
Game = {}
function Game.createItem(id, _, pos)
	local tile = Tile(pos)
	local item = {
		setCustomAttribute = function(self, key, value) self[key] = value end,
		getCustomAttribute = function(self, key) return self[key] end,
		remove = function(self) tile.items[id] = nil; self.removed = true end,
	}
	tile.items[id] = item
	return item
end
function Game.createMonster(name, pos)
	nextId = nextId + 1
	local monster = {
		id = nextId, name = name, position = pos, health = 420000,
		getId = function(self) return self.id end,
		getName = function(self) return self.name end,
		getPosition = function(self) return self.position end,
		getHealth = function(self) return self.health end,
		getPlayer = function() return nil end,
		getMaster = function() return nil end,
		registerEvent = function() end, unregisterEvent = function() end,
		setReward = function(self) GlobalBosses[self.id] = {} end,
		remove = function(self) monsters[self.id] = nil end,
		addHealth = function(self, amount) self.health = self.health + amount end,
	}
	monsters[monster.id] = monster
	return monster
end
function Game.getSpectators(pos, _, _, rx, _, ry)
	local result = {}
	for _, player in pairs(players) do
		local p = player.position
		if p.z == pos.z and math.abs(p.x - pos.x) <= rx and math.abs(p.y - pos.y) <= ry then
			table.insert(result, player)
		end
	end
	return result
end
function GetPlayerStats(id, guid)
	local info = assert(GlobalBosses[id])
	info[guid] = info[guid] or { damageIn = 0, healing = 0 }
	return info[guid]
end
function addEvent(callback, delay, ...)
	nextId = nextId + 1
	pending[nextId] = { callback = callback, time = now + delay, args = { ... } }
	return nextId
end
function stopEvent(id) pending[id] = nil end
function doTargetCombatHealth(_, player, kind, minimum)
	table.insert(damageLog, { id = player.id, kind = kind, damage = -minimum, time = now })
end
local unpackArgs = table.unpack or unpack
local function fire(event) event.callback(unpackArgs(event.args)) end
local function advance(milliseconds)
	local finish = now + milliseconds
	while true do
		local first, time = nil, finish + 1
		for id, event in pairs(pending) do
			if event.time < time then first, time = id, event.time end
		end
		if not first then break end
		now = time
		local event = pending[first]
		pending[first] = nil
		fire(event)
	end
	now = finish
end
local function newPlayer(id, guid, z)
	local player = {
		id = id, guid = guid, position = Position(33805, 31504, z), outfits = {}, storages = {},
		getId = function(self) return self.id end,
		getGuid = function(self) return self.guid end,
		getPlayer = function(self) return self end,
		getPosition = function(self) return self.position end,
		teleportTo = function(self, pos) self.position = pos end,
		registerEvent = function() end,
		getCondition = function(self) return self.hex end,
		addCondition = function(self, hex) self.hex = hex end,
		removeCondition = function(self) self.hex = nil end,
		getStorageValue = function(self, key) return self.storages[key] or -1 end,
		setStorageValue = function(self, key, value) self.storages[key] = value end,
		addOutfit = function(self, outfit) self.outfits[outfit] = true end,
		addAchievement = function(self) self.achievement = true end,
		sendTextMessage = function() end,
	}
	players[id] = player
	return player
end
dofile(root .. "lib/quests/pale_worm.lua")
dofile(root .. "scripts/quests/feaster_of_souls/pale_worm_mechanics.lua")
dofile(root .. "scripts/quests/feaster_of_souls/creaturescripts_pale_worm_death.lua")
local encounter, config = PaleWormEncounter, PaleWormEncounter.config
local a, b = newPlayer(1001, 2001, 14), newPlayer(1002, 2002, 14)
local boss = assert(encounter.start({ a, b }))
encounter.enter(a)
assert(a.hex[CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT] == 40)
assert(a.hex[CONDITION_PARAM_BUFF_DAMAGEDEALT] == 40 and a.hex[CONDITION_PARAM_BUFF_HEALINGRECEIVED] == 40)

-- Each descent gets its own five-second clock; returning invalidates queued work.
a.position.z = 15
zones["pale-worm.lower"].event.afterEnter(nil, a)
advance(2000)
b.position.z = 15
zones["pale-worm.lower"].event.afterEnter(nil, b)
advance(3000)
assert(#damageLog == 1 and damageLog[1].id == a.id and damageLog[1].damage == config.deathInitial)
advance(2000)
assert(#damageLog == 2 and damageLog[2].id == b.id)
local staleTick = pending[encounter.state.events["death:" .. a.guid]]
a.position.z = 14
zones["pale-worm.lower"].event.afterLeave(nil, a)
assert(not encounter.state.players[a.guid].damage)
a.position.z = 15
zones["pale-worm.lower"].event.afterEnter(nil, a)
local currentTickId = encounter.state.events["death:" .. a.guid]
fire(staleTick)
assert(#damageLog == 2 and encounter.state.events["death:" .. a.guid] == currentTickId)
advance(5000)
local resetTick = false
for _, hit in ipairs(damageLog) do
	if hit.id == a.id and hit.time == now then
		assert(hit.damage == config.deathInitial)
		resetTick = true
	end
end
assert(resetTick)

-- Weak Spot forwards both components once, ignores healing, and retains itself.
local spot = Monster(encounter.state.weakSpotId)
local before = boss.health
local p, _, s = events.PaleWormWeakSpotDamage.onHealthChange(spot, a, 100, COMBAT_PHYSICALDAMAGE, 50, COMBAT_DEATHDAMAGE)
assert(p == 0 and s == 0 and boss.health == before - 150)
assert(GlobalBosses[boss.id][a.guid].damageOut == config.participantCredit + 150)
events.PaleWormWeakSpotDamage.onHealthChange(spot, a, 100, COMBAT_HEALING, 0, COMBAT_HEALING)
assert(boss.health == before - 150)
local outsider = newPlayer(1003, 2003, 15)
events.PaleWormWeakSpotDamage.onHealthChange(spot, outsider, 100, COMBAT_PHYSICALDAMAGE, 0, COMBAT_PHYSICALDAMAGE)
assert(boss.health == before - 150)
local reduced = events.PaleWormResistance.onHealthChange(boss, a, 1000, COMBAT_PHYSICALDAMAGE, 0, COMBAT_PHYSICALDAMAGE)
assert(reduced == 50)

-- Lantern immunity lasts through floor changes, including a broken lantern.
config.lanternBreakChance = 100
local lantern = { remove = function(self) self.broken = true end }
assert(actions[config.lanternId].onUse(a, lantern) and lantern.broken and not a.hex)
a.position.z = 14
encounter.enter(a)
assert(not a.hex and not actions[config.lanternId].onUse(a, lantern))

-- Hunger death leaves a hole for exactly ten seconds; old callbacks cannot
-- remove a replacement item, and Greed explosions stay on their own floor.
encounter.hunger()
local hunger = Monster(encounter.state.hungerId)
events.PaleWormHungerDeath.onDeath(hunger)
hunger:remove()
local hole = Tile(config.bossPosition):getItemById(config.holeItemId)
assert(hole)
advance(9999)
assert(hole:getId() == config.holeItemId)
advance(1)
assert(hole:getId() == 100 and not hole:getCustomAttribute("pale-worm-session"))
encounter.hunger()
hunger = Monster(encounter.state.hungerId)
events.PaleWormHungerDeath.onDeath(hunger)
hunger:remove()
local foreignHole = Game.createItem(config.holeItemId, 1, config.bossPosition)
encounter.closeHole()
assert(not foreignHole.removed) -- Do not touch a replacement without our tag.
Tile(config.bossPosition).items[config.holeItemId] = nil
Tile(config.bossPosition):getGround():transform(100)
local greed = Game.createMonster("Greed Worm", a.position)
damageLog = {}
events.PaleWormGreedDeath.onDeath(greed)
assert(#damageLog == 1 and damageLog[1].id == a.id and damageLog[1].damage == config.greedExplosionDamage)
greed:remove()

-- Rewards cover participating players on either floor, not spectators.
local staleSession = pending[encounter.state.events.watch]
local oldStats = GlobalBosses[boss.id]
events.paleWormDeath.onDeath(boss)
assert(a.outfits[1270] and b.outfits[1271] and a.storages[2] == 1 and b.storages[2] == 1)
assert(not outsider.outfits[1270] and not a.hex and not b.hex)
assert(GlobalBosses[boss.id] == oldStats and not encounter.state and not next(pending))
boss:remove() -- Engine removes the dead boss after onDeath.
assert(not next(monsters))

-- Session/guid checks reject old work and reused player IDs.
a.position.z, b.position.z = 14, 14
boss = assert(encounter.start({ a, b }))
encounter.enter(a)
assert(a.hex and not encounter.state.players[a.guid].protected)
fire(staleSession)
assert(encounter.boss() == boss)
local replacement = newPlayer(a.id, 9999, 15)
assert(not encounter.player(encounter.state.players[a.guid]))
events.PaleWormShutdown.onShutdown()
assert(not encounter.state and not next(pending) and not next(monsters) and not GlobalBosses[boss.id])
assert(replacement.position.z == 15) -- Never act on an unrelated reused ID.

-- Abandonment, missing owner, and reload all drain pending work.
players[a.id] = a
a.position.z = 14
boss = assert(encounter.start({ a }))
a.position = Position(1, 1, 7)
advance(1000)
assert(not encounter.state and not next(pending) and not next(monsters))
a.position = Position(33805, 31504, 14)
boss = assert(encounter.start({ a }))
encounter.removed(boss)
boss:remove()
assert(not encounter.state and not next(pending))

-- Timeout evacuates both floors, clears Hex, removes auxiliaries and statistics.
a.position.z, b.position.z = 14, 15
config.fightDuration = 1000
boss = assert(encounter.start({ a, b }))
encounter.enter(a)
encounter.enter(b)
advance(1000)
assert(not encounter.state and not next(pending) and not next(monsters))
assert(not a.hex and not b.hex and a.position == config.exit and b.position == config.exit)
assert(not GlobalBosses[boss.id])
config.fightDuration = 25 * 60 * 1000

-- A summon credits its owner; lethal forwarding is capped at remaining health.
a.position = Position(33805, 31504, 14)
boss = assert(encounter.start({ a }))
a.position.z = 15
spot = Monster(encounter.state.weakSpotId)
local summon = { getPlayer = function() return nil end, getMaster = function() return a end }
boss.health = 100
events.PaleWormWeakSpotDamage.onHealthChange(spot, summon, 200, COMBAT_PHYSICALDAMAGE, 0, COMBAT_DEATHDAMAGE)
assert(boss.health == 0 and GlobalBosses[boss.id][a.guid].damageOut == config.participantCredit + 100)
encounter.cleanup(true)

-- Script reload, independently of library reload, drains the old session.
a.position = Position(33805, 31504, 14)
boss = assert(encounter.start({ a }))
dofile(root .. "scripts/quests/feaster_of_souls/pale_worm_mechanics.lua")
assert(not encounter.state and not next(pending) and not next(monsters))
a.position = Position(33805, 31504, 14)
boss = assert(encounter.start({ a }))
dofile(root .. "lib/quests/pale_worm.lua")
assert(not PaleWormEncounter.state and not next(pending) and not next(monsters))

-- Missing map tiles reject admission before a fight is created.
local originalTile = Tile
Tile = function() return nil end
assert(not PaleWormEncounter.start({ a }) and not PaleWormEncounter.state)
Tile = originalTile

-- All auxiliary types and lever integration are registered from production files.
local types = {}
function Game.createMonsterType(name)
	return { register = function(_, definition) types[name] = definition end }
end
dofile(root .. "monster/quests/feaster_of_souls/pale_worm_minions.lua")
assert(types["Hunger Worm"].events[1] == "PaleWormHungerDeath")
assert(types["Greed Worm"].events[1] == "PaleWormGreedDeath")
assert(types["A Weak Spot"].events[1] == "PaleWormWeakSpotDamage")
assert(not types["A Weak Spot"].flags.hostile and types["A Weak Spot"].speed == 0)
local registeredLever
BossLever = setmetatable({}, { __call = function(_, settings)
	local areas = {}
	local zone = { addArea = function(_, from, to) table.insert(areas, { from = from, to = to }) end }
	local lever = {
		lever = { getPlayers = function() return { a } end },
		position = function() end,
		register = function(self) registeredLever = self; zone:addArea(settings.specPos.from, settings.specPos.to) end,
		getZone = function() return zone end,
		settings = settings, areas = areas,
	}
	return lever
end })
dofile(root .. "scripts/quests/feaster_of_souls/actions_the_pale_worm_lever.lua")
assert(#registeredLever.areas == 2 and registeredLever.areas[2].from.z == 15)
assert(registeredLever.settings.timeToDefeat == 25 * 60)
a.position = Position(33805, 31504, 14)
assert(registeredLever.settings.boss.createFunction())
PaleWormEncounter.cleanup(true)
assert(not next(monsters) and not next(pending))
print("Pale Worm mechanics regression tests passed")
