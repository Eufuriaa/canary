local event = CreatureEvent("paleWormDeath")

function event.onDeath(creature)
	local state = PaleWormEncounter.state
	if not state or state.bossId ~= creature:getId() then
		return true
	end
	for _, entry in pairs(state.players) do
		local player = PaleWormEncounter.player(entry)
		if player and PaleWormEncounter.floor(player:getPosition()) then
			if player:getStorageValue(Storage.Quest.U12_30.PoltergeistOutfits.Received) == -1 then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Congratulations you received the Poltergeist Outfit.")
				player:addOutfit(1271, 0)
				player:addOutfit(1270, 0)
				player:setStorageValue(Storage.Quest.U12_30.PoltergeistOutfits.Received, 1)
			end
			player:setStorageValue(Storage.Quest.U12_30.FeasterOfSouls.PaleWormKilled, 1)
			player:addAchievement("Beyonder")
		end
	end
	-- BossDeath still needs the native reward statistics.
	PaleWormEncounter.cleanup(false, true)
	return true
end

event:register()
