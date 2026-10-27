# Windows, Linux and A2

The game rules, renderer and simulation loop are shared. `DoomHost` supplies
arguments, input, frame presentation and cleanup for the selected platform.
The root `DoomHost.Mod`/`DoomArgs.Mod` and `DoomMouse.Mod` support Linux/X11;
`platform/windows` and `platform/a2` provide build overlays.

## Standalone Windows and Linux

Install the native MiniA2 SDK (`ob`), Task and Python 3. The SDK must contain
the YAML and Logging modules required by the game. The engine can be in
`../ao-game-engine`, or in `target/deps/ao-game-engine`. Alternatively, pass
`ENGINE_DIR=/path/to/ao-game-engine` to Task. A compatible engine revision is
`d90c17d0e74eeb615ff2ba1cd0f6d2c4a832a12c`.

```powershell
task build-windows
task check-windows
task run-windows
task run-windows -- "C:/Games/Doom/doom.wad" E1M1
task run-windows -- --config "C:/Games/My profiles/doom.yaml" "C:/Games/Doom/doom.wad" E1M1
```

The Windows executable is `build/windows/ao-doom.exe`. Keep `doom.yaml` with
it and run from that directory, or pass `--config`. Task runs from the project
root, where the repository configuration is available. No game assets are
required for the built-in demonstration.

```sh
task build-linux
task check-linux
task run-linux -- /path/to/doom.wad E1M1
task gui-check
```

Linux output remains `build/ao-doom`. `task build`, `task run` and `task check`
select the current host automatically. GUI builds use the native SDK; they
cannot be verified by cross-compiling from another operating system.

Windows keyboard input polls physical key state, retaining the common YAML
key symbols, and works with SDK display drivers that suppress release events.
Letters, digits, arrows, modifiers, function keys and the mapped punctuation
keys are supported; unsupported bindings produce a startup error. Mouse
movement uses a centered pointer confined to the focused game's client area.
Losing focus clears controls and releases confinement. Mouse buttons and the
wheel retain their configured meanings. Linux retains its X11 capture adapter.

## Full A2

Build against a full A2 distribution's `bin` directory, using the matching
compiler platform. This validates the imports against A2 symbols rather than
using the standalone SDK's symbols for the application modules.

```powershell
task build-a2 A2_ROOT=../target/Win64 A2_PLATFORM=Win64
```

For a built native A2 distribution, use its symbols and platform, for example:

```sh
task build-a2 A2_ROOT=/path/to/built/Bios64 A2_PLATFORM=Bios64
```

Supported compiler platform names are `Win64`, `Win32`, `Unix64`, `Unix32`,
`Bios64` and `Bios32`. Each needs matching full-A2 symbols; availability of a
compiler option alone does not establish that the corresponding runtime works.

The output directory is `build/a2`. Its `ao-doom-a2-<platform>.zip` contains
the game's and engine's sources, object/symbol files, `doom.yaml`, `Doom.Tool`,
and the YAML/Logging support libraries and license. It excludes WADs and the
A2 operating system. `build.json` records the target and module list.

In an existing A2 desktop, install the package modules and `doom.yaml` on a
mounted file system searched by the A2 module loader. On a hosted system,
`Files.AddSearchPath` can add the package directory. On native A2, install
them on the module volume used by that system. Then execute:

```text
DoomWindow.Do ~
DoomWindow.Do --config "MYFS:doom.yaml" "MYFS:doom.wad" E1M1 ~
```

In the A2 text editor, execute each line by clicking the middle mouse button
on the command name (`Files.AddSearchPath`, then `DoomWindow.Do`). Clicking a
file path or the final `~` attempts to interpret that token as a command and
can produce error 3903. The search-path command must run before the game command;
otherwise the loader reports error 3401, `DoomWindow.GofWw not found` on Win64.

To execute a command file in order, use `System.DoFile "path/to/file.cfg" ~`
and middle-click `System.DoFile` itself.

`Doom.Tool` also contains the module compilation command, in dependency order.
Use the platform matching that A2 installation. The game opens a 320 x 200
`WMWindowManager` window with double buffering and desktop scaling. Keyboard
events, focus changes, buttons, wheel and relative mouse motion feed the same
controller as the standalone game. On Windows-hosted A2, physical key polling
handles old display drivers without release notifications. Closing the game
window stops its simulation and unregisters its mouse sink; the A2 desktop
continues running.

An optional hosted harness starts the A2 window system inside the native SDK:

```powershell
task run-a2 A2_ROOT=../target/Win64 A2_PLATFORM=Win64
task run-a2 A2_ROOT=../target/Win64 A2_PLATFORM=Win64 -- "C:/Games/Doom/doom.wad" E1M1
```

This requires a full A2 distribution's desktop objects and data, with APIs
compatible with the installed SDK. It is a desktop-adapter check, not a native
A2 boot-image builder. In a running A2 desktop, invoke `DoomWindow.Do` directly.

## Verification on 2026-10-27

Windows x64: native build and 37 engine/game check groups passed. The Windows
window displayed the demonstration, movement and mouse look worked, and a
mouse shot reduced ammunition. Repeated frames confirmed movement stopped
after releasing the movement key.

Full A2 Win64: the application compiled using the full A2 distribution's
symbols. The hosted desktop harness logged window-manager initialization,
focus acquisition and `window started`. Computer Use was stopped by the user's
physical Escape key, so further interactive checks were not performed. Native
A2 boot, physical hardware, and a fresh Linux regression remain unverified in
this Windows session. Linux's existing X11 GUI scenarios remain available.
