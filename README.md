# ao-doom

An Active Oberon rewrite of the classic Doom engine, using
[id Software's `linuxdoom-1.10`](https://github.com/id-Software/DOOM/tree/master/linuxdoom-1.10)
as the reference implementation.

## Status

Repository setup only. The engine, build scripts, and runnable game are not
implemented yet.

## Initial target

- Linux64 with the MiniA2 Active Oberon SDK.
- Original software rendering at 320 x 200.
- Single-player gameplay.

The first milestone is to load a Doom WAD, render one map, and allow player
movement with collision detection.

## Development rules

Follow [AGENTS.md](AGENTS.md), including the requirement to write each Active
Oberon operation on its own line.

## Upstream and game data

The reference engine is released under
[GPL-2.0](https://github.com/id-Software/DOOM/blob/master/LICENSE.TXT).
Preserve the required license and copyright notices when porting its code.

Doom WAD files contain separately licensed game data and are not included.
Keep local WAD files out of Git.
