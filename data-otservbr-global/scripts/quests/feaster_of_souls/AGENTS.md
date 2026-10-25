# Feaster of Souls encounter mechanics

- Multi-floor encounters must track the admitted team by player ID and GUID.
  Do not use only a boss target list or same-floor spectators for participation,
  quest rewards, occupancy, or evacuation. Keep contribution in the native boss
  reward statistics and validate both floors plus an unrelated spectator.
- Deferred encounter work must use a session generation and a per-event ticket;
  per-player floor hazards additionally require a descent generation. Cancel and
  invalidate work on exit, owner removal, timeout, shutdown, and reload. Validate
  an old callback after re-entry and after a new fight in the Lua regression test.
- Temporary ground holes must transform and restore the original ground type;
  inserting and later deleting a ground item can destroy the existing floor.
  Tag ownership and validate restoration plus an unrelated replacement tile.
