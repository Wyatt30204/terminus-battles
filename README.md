# Terminus-Battles

A keyboard-first tower-defense game where you write GDScript plans to build towers, send bloons, and survive waves. Play locally, host a direct online duel, or team up in co-op.

## Run the game

Install Godot 4.7.1, import `project/project.godot`, and press **F6/F5** or run the project from the editor. The ready-to-play ZIP is kept outside the public source repository because it includes the Godot runtime and third-party music.

## Open and edit the game

1. Install Godot 4.7.1.
2. In Godot, import `project/project.godot`.
3. Press **F6/F5** or run the project from the editor.

The full player guide is in [`project/README.md`](project/README.md). It covers multiplayer setup, GDScript actions, and the in-game Handbook. Optional commander voice clip paths are documented in [`project/voice/README.md`](project/voice/README.md).

## Build a friend-ready ZIP

On Windows, place the Godot 4.7.1 runtime executable beside `Build_Playtest_Zip.ps1`, then run the script. It creates `Terminus-Battles-Playtest.zip` with the game project, available music and voice folders, launcher, and Godot runtime. Add audio you have permission to redistribute under `project/music/` before building if you want music in your package. The generated ZIP and runtime executable are excluded from Git history.

## Repository contents

- `project/` — Godot project, GDScript, handbook, music, and optional voice assets
- `Build_Playtest_Zip.ps1` — Windows playtest package builder
- `Start_Terminus_Battles.bat` — playtest launcher
- `DESIGN.md` — visual direction for the game UI

The public source repository does not include the third-party Warzone music. The Windows playtest ZIP includes the audio files already selected for this game; they retain their original ownership and licensing. Source clones start without background music until you add audio you have permission to use. See [`project/music/README.md`](project/music/README.md) for filenames.
