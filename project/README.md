# Terminus-Battles — GDScript Playtest

## Start

Unzip the playtest folder and double-click `Start_Terminus_Battles.bat`. It runs the included Godot 4.7.1 executable and needs no separate Godot installation.

## Play with a friend

1. The host clicks **HOST GAME** and leaves that screen open.
2. The host looks up their public IPv4 address (search “what is my IP”) and sends it to the friend.
3. The friend types their name and the host’s IP in the **JOIN A FRIEND’S GAME** boxes, then clicks **JOIN HOST**.
4. If they are at another house, the host may need to allow Godot through the Windows firewall and forward **UDP port 24680** on the router.
5. When both screens switch to the match, each player writes GDScript and clicks **RUN PLAN**, then clicks **READY**. The host runs both plans together and sends the same battle state to both screens.

The connection is direct ENet, without a relay service. Players outside the host's local network usually need UDP port forwarding or a VPN such as a private gaming LAN. Both players must use the same playtest build.

For a same-computer match, enter both names in the **LOCAL DUEL** section and select **START LOCAL DUEL**. Each player writes and locks in a plan in turn; both plans resolve together after both select **READY**.

Both boards are square and resize with the game window to keep their tiles proportional. The **SESSION** clock appears above the boards. In online play, the host sends the same board state and elapsed time to the joining player.

## Use GDScript

The editor compiles your code as a GDScript function. It supports normal GDScript syntax such as variables, loops, and conditionals. Game actions are methods supplied by the game:

```gdscript
var row = 1
for x in range(3):
    build("dart", x, row)

if money >= 180:
    build("tack", 4, 4)

send("red", 5)
```

Available actions: `build(kind, x, y)`, `send(kind, count)`, `upgrade(x, y)`, `upgrade_all(kind)`, `repair(x, y)`, `spikes(x, y)`, `streak(kind)`, and `nuke()`. Click **HELP** or press **F1** for a separate, scrollable handbook with complete tower stats, upgrade prices, range, balloon, repair, and scorestreak rules. GDScript indentation matters; use four spaces inside loops and conditionals.

Choose **GDScript Academy** from Singleplayer to follow a guided course from basic actions through variables, loops, collections, functions, and a final challenge. Lessons explain each concept, show an example, and unlock after a valid plan demonstrates it.

The **Notebook** keeps multiple autosaved pages of notes and reusable code. Write an alias such as `dart = "dart"` on a note page, then use `build(dart, 4, 3)` in your plan. Save reusable code as a function and call it by name in a plan. Use the notebook’s insert action to copy any selection into the planner.

## Rebuild the playtest ZIP

After changing the project, run `Build_Playtest_Zip.ps1` from the repository folder. It recreates `Terminus-Battles-Playtest.zip` with the current source, launcher, and Godot runtime. It skips generated `.godot` editor cache files.

This is an early playable prototype; tower balance and online synchronization still need testing by two players.
