# Pale Worm mechanics

The encounter is started by the existing BossLever. Its occupancy and evacuation
zone includes both floors. Only the admitted team receives the outfit, quest
completion, existing Beyonder achievement, and boss reward participation.
Weak Spot damage is credited to the attacking player (or a summon's owner) in
the native reward chest statistics before subtracting the boss's health. It does
not pass through resistance or Greater Hex a second time. Direct boss hits use
the configured additional resistance; its existing elemental resistances remain.

## Configuration and evidence

Edit `data-otservbr-global/lib/quests/pale_worm.lua`,
`PaleWormEncounter.config`, before server startup. The implementation fixes the
requested hole duration at a default of 10 seconds and gives each player a new
5-second death-damage clock on every descent. Leaving the lower floor cancels
that player's clock and resets escalation. Leaving the encounter removes Hex;
lantern protection persists until the current encounter ends.

[TibiaWiki's quest description](https://tibia.fandom.com/wiki/Feaster_of_Souls_Quest)
describes Hunger Worm opening a hole, the Weak Spot forwarding damage, escalating
death damage below, and Greed Worms exploding on death. It reports 750 earth
damage, 40% remaining maximum health under Greater Hex, and a 20% lantern break
chance. These are community reports, not official balance specifications; all
remain configurable. A broken lantern still removes Hex.

The following defaults are unverified and deliberately exposed for tuning:

| Setting | Default |
| --- | --- |
| Hunger spawn interval | 30 seconds, at most one; no spawn during an open hole |
| Greed replenishment | Every 15 seconds, up to 4 per floor |
| Death damage | 250 initially, doubles per tick, capped at 16000 |
| Hex damage / healing received | 40% |
| Additional direct boss damage | 5% |
| Weak Spot transfer multiplier | 1 |
| Greed explosion radius | 1 tile, same floor |
| Hunger / Greed / Weak Spot health | 10000 / 5000 / 420000 |
| Worm melee maximum damage | 600 |
| Worm / Weak Spot appearance | Look types 1275 / 1273 |
| Baseline reward credit for each admitted player | 1 |

The upper bounds come from the existing lever. The lower bounds use the same
rectangle at z=15; Weak Spot defaults to (33805,31504,15), and the return ramp
defaults to (33810,31498,15), leading to (33810,31498,14). These lower-floor map
positions are provisional: the main downloaded world OTBM is absent from this
checkout. Confirm them against the deployed map and adjust the configuration.
Startup of a fight fails without charging cooldown if any required mechanic
tile is missing. Hole item 385 uses native floor-change routing at Hunger
Worm's death position; a lower tile must exist. The hole is session-tagged, and
cleanup restores the original ground type without removing an unrelated
replacement item.

## Lifetime and cleanup

Timers resolve the current encounter using its generation and their own ticket;
death timers also check the player's descent generation, ID, and GUID. Monster
removal invalidates ownership. On death, auxiliaries and holes are removed, Hex
and hazard timers are cleared, and native reward statistics survive until the
reward system consumes them. BossLever retains its normal 60-second post-kill
exit window for both floors. Timeout, abandonment, owner removal, shutdown, and
library reload drain encounter work and native reward state; aborts evacuate
remaining participants when needed.

## Validation

Run `luajit tests/lua/test_pale_worm_mechanics.lua` from the repository root.
The fixture exercises independent descent clocks, reset and stale ticks, mixed
damage and healing on Weak Spot, outsiders, lantern break and fight-scoped
protection, hole lifetime, same-floor explosions, rewards on both floors,
reused IDs, abandonment, owner removal, shutdown, and library reload. The test
is included automatically by the existing Lua CI workflow.

On a running server with the deployed map, verify the lower bounds and ramp,
native hole routing, Hex's displayed health and buffs, summon attribution,
reward chest loot, and evacuation after 25 minutes and after the post-kill
window. These engine/map integration checks are not simulated by the fixture.
