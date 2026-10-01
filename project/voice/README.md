# Commander voice clip slots

The game has three commander slots. The current Godot lobby is still 1v1 (or two-player co-op); commander 3 is reserved for a future third player.

Add optional OGG clips at these exact paths:

- `commander_1/build/tower_built.ogg`
- `commander_1/streak/activated.ogg`
- `commander_1/match_result/victory.ogg`
- `commander_1/match_result/defeat.ogg`

Repeat the same `build`, `streak`, and `match_result` folders under `commander_2` and `commander_3` for the other voices. Missing clips are skipped silently. The three spoken event categories are construction, scorestreak activation, and match results. In an online match, the host sends voice events to the joining player.
