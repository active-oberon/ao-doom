#!/usr/bin/env python3
"""Native SDK builds; all compiler output stays in a platform-specific directory."""
import argparse
from graphlib import TopologicalSorter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
A2_EXTENSIONS = {'Win64': ('.GofWw', '.SymWw'), 'Win32': ('.GofW', '.SymW'),
                 'Unix64': ('.GofUu', '.SymUu'), 'Unix32': ('.GofU', '.SymU'),
                 'Bios64': ('.Goff', '.Symm'), 'Bios32': ('.Gof', '.Sym')}


def run(args, cwd, timeout=120):
    print('+', ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, check=True, timeout=timeout, stderr=subprocess.STDOUT)


def engine_path(value):
    candidates = [Path(value)] if value else [ROOT.parent / 'ao-game-engine', ROOT / 'target/deps/ao-game-engine']
    for path in candidates:
        path = path.resolve()
        if (path / 'GameGeometry.Mod').is_file():
            return path
    raise RuntimeError('ao-game-engine is missing; set ENGINE_DIR or clone it into target/deps/ao-game-engine')


def stage(platform, engine, destination):
    if destination.resolve() in (ROOT, engine, ROOT / 'platform' / platform):
        raise RuntimeError('Build directory must be separate from source directories')
    destination.mkdir(parents=True, exist_ok=True)
    # Only remove compiler output owned by this build, never WADs or rendered frames.
    for pattern in ('*.Gof*', '*.Sym*'):
        for path in destination.glob(pattern):
            path.unlink()
    for name in [*(p.name for p in ROOT.joinpath('tests').glob('*.Mod')),
                 *(p.name for p in engine.glob('*Smoke.Mod')), 'DoomChecks.Mod', 'A2Compile.Mod']:
        (destination / name).unlink(missing_ok=True)
    for source in [*(p for p in engine.glob('Game*.Mod') if not p.stem.endswith('Smoke')), *ROOT.glob('Doom*.Mod'),
                   *ROOT.joinpath('platform', platform).glob('*.Mod')]:
        shutil.copy2(source, destination / source.name)
    if platform != 'linux':
        (destination / 'DoomMouse.Mod').unlink(missing_ok=True)
    shutil.copy2(ROOT / 'doom.yaml', destination / 'doom.yaml')
    if platform == 'a2':
        for source in ROOT.joinpath('platform/a2/support').glob('*.Mod'):
            shutil.copy2(source, destination / source.name)


def a2_order(destination):
    sources = {p.stem: p for p in destination.glob('*.Mod')
               if p.stem not in ('A2Compile', 'A2Launch', 'DoomChecks') and not p.stem.endswith('Smoke')}
    graph = {}
    for name, path in sources.items():
        match = re.search(r'\bIMPORT\s+(.*?);', path.read_text(), re.S)
        imports = re.findall(r'\b[A-Za-z]\w*\b', match[1]) if match else []
        graph[name] = sorted(set(imports) & sources.keys())
    return [sources[name].name for name in TopologicalSorter(graph).static_order()]


def checks(destination, engine, sdk, platform):
    run([sys.executable, ROOT / 'tests/wad_fixtures.py', destination], ROOT)
    for source in ROOT.joinpath('tests').glob('doom-*.yaml'):
        shutil.copy2(source, destination / source.name)
    sources = [*engine.glob('*Smoke.Mod'), *ROOT.joinpath('tests').glob('*Smoke.Mod')]
    modules = []
    calls = []
    for source in sorted(sources, key=lambda p: (p.stem != 'DoomConfigSmoke', p.stem)):
        shutil.copy2(source, destination / source.name)
        modules.append(source.stem)
        args = []
        if source.stem == 'DoomOriginalSmoke':
            args = ['sectors.wad', 'E1M1']
        elif source.stem == 'DoomOriginalDoorsSmoke':
            args = ['door.wad', 'E1M1']
        if args:
            calls.extend([f"Streams.OpenStringReader(reader, '{' '.join(args)}');",
                          'NEW(command, NIL, reader, NIL, NIL, NIL);',
                          f'{source.stem}.Do(command); ASSERT(command.result = 0);'])
        else:
            calls.append(f'{source.stem}.Do;')
        calls.append(f"KernelLog.String('PASS {source.stem}'); KernelLog.Ln;")
    calls.append('Doom.Do;')
    helper = 'MODULE DoomChecks;\nIMPORT Streams, Commands, KernelLog, Doom,\n\t' + ',\n\t'.join(modules) + ';\n'
    helper += 'PROCEDURE Do*; VAR reader: Streams.StringReader; command: Commands.Context; result: INTEGER; message: ARRAY 256 OF CHAR;\nBEGIN\n'
    # ob run uses an isolated compiler directory; fixtures live in this build directory.
    helper += f"Commands.Call('Files.SetWorkPath \"{destination.as_posix()}\"', {{Commands.Wait}}, result, message); ASSERT(result = 0);\n"
    helper += '\n'.join(calls) + '\nEND Do;\nEND DoomChecks.\n'
    (destination / 'DoomChecks.Mod').write_text(helper)
    run([sdk, 'run', 'DoomChecks.Mod'], destination, timeout=120)
    passed = modules + ['Doom']
    (destination / 'checks.json').write_text(json.dumps({'platform': platform, 'passed': passed}, indent=2))
    print(f'{len(passed)} native checks passed', flush=True)


def a2_build(destination, options, sdk):
    if not options.a2_root:
        raise RuntimeError('Set A2_ROOT to a built A2 distribution with bin/ and data/')
    distribution = Path(options.a2_root).resolve()
    object_ext, symbol_ext = A2_EXTENSIONS[options.a2_platform]
    if not (distribution / 'bin' / ('WMWindowManager' + symbol_ext)).is_file():
        raise RuntimeError('A2_ROOT must provide the full window system symbols for the selected platform')
    files = a2_order(destination)
    refs = destination / 'references'
    refs.mkdir(exist_ok=True)
    for name in files:
        for extension in (object_ext, symbol_ext):
            (refs / (Path(name).stem + extension)).unlink(missing_ok=True)
    for source in (distribution / 'bin').glob('*' + symbol_ext):
        shutil.copy2(source, refs / source.name)
    command = (f'Compiler.Compile -p={options.a2_platform} --srcPath="{destination.as_posix()}/" '
               f'--destPath="{refs.as_posix()}/" ' + ' '.join(files))
    tool = ('Compiler.Compile -p=' + options.a2_platform + ' ' + ' '.join(files) +
            ' ~\n\nDoomWindow.Do ~\nDoomWindow.Do --config doom.yaml "my-game.wad" E1M1 ~\n')
    (destination / 'Doom.Tool').write_text(tool)
    # Use the installed compiler to check against full A2 symbols. The existing A2
    # executable and its files remain untouched; no desktop is started by this step.
    paths = [destination, distribution / 'bin', distribution / 'data']
    setup = '\n'.join(f'Files.AddSearchPath "{p.as_posix()}"~' for p in paths)
    (destination / 'oberon.cfg').write_text(setup + '\nConfiguration.Init~\n')
    (destination / 'desktop.cfg').write_text(
        f'Files.AddSearchPath "{(distribution / "data").as_posix()}"~\nConfiguration.Init~\n')
    (destination / 'a2pkg.json').write_text(json.dumps({'sourcePaths': [(distribution / 'bin').as_posix()]}))
    calls = '\n'.join(
        f'Commands.Call(\'Files.AddSearchPath "{p.as_posix()}"\', {{Commands.Wait}}, result, message); ASSERT(result = 0);'
        for p in paths)
    helper = f'''MODULE A2Compile;
IMPORT Commands;
VAR result: INTEGER; message: ARRAY 256 OF CHAR;
PROCEDURE Do*(context: Commands.Context);
BEGIN
{calls}
Commands.Call('Files.SetWorkPath "{destination.as_posix()}"', {{Commands.Wait}}, result, message); ASSERT(result = 0);
Commands.Call('{command}', {{Commands.Wait}}, result, message);
context.result := result
END Do;
END A2Compile.
'''
    compiler_dir = destination / 'compiler'
    compiler_dir.mkdir(exist_ok=True)
    (compiler_dir / 'A2Compile.Mod').write_text(helper)
    run([sdk, 'run', 'A2Compile.Mod'], compiler_dir)
    artifacts = []
    for name in files:
        for extension in (object_ext, symbol_ext):
            path = refs / (Path(name).stem + extension)
            if not path.is_file():
                raise RuntimeError(f'A2 compiler produced no {path.name}')
            shutil.copy2(path, destination / path.name)
            artifacts.append(destination / path.name)
    manifest = {'platform': options.a2_platform, 'modules': [Path(p).stem for p in files],
                'symbols_from': str(distribution / 'bin'), 'bare_metal_tested': False}
    (destination / 'build.json').write_text(json.dumps(manifest, indent=2))
    package = destination / f'ao-doom-a2-{options.a2_platform}.zip'
    with ZipFile(package, 'w', ZIP_DEFLATED) as archive:
        for path in artifacts + [destination / p for p in files] + [destination / 'doom.yaml', destination / 'Doom.Tool', destination / 'build.json']:
            archive.write(path, path.name)
        archive.write(ROOT / 'platform/a2/support/LICENSE.txt', 'LICENSE.txt')
        archive.write(ROOT / 'platform/a2/support/SOURCE.md', 'SUPPORT-SOURCES.md')
        archive.write(ROOT / 'docs/PLATFORMS.md', 'README.md')
    print(f'A2 modules and Doom.Tool prepared in {destination}', flush=True)


def gui_checks(destination, sdk, executable, platform):
    if platform != 'linux':
        raise RuntimeError('The automated GUI scenarios use X11; use run-windows for an interactive Windows check')
    run([sys.executable, ROOT / 'tests/wad_fixtures.py', destination], ROOT)
    run([sys.executable, ROOT / 'tests/gui_smoke.py', executable], ROOT, timeout=60)
    plain = ['valid', 'sectors', 'sky', 'bsp-sectors', 'masked', 'sprites', 'sprites-grate']
    cases = [(None, p, 'E1M1') for p in plain]
    modes = {'pickup': 'pickups', 'combat': 'combat', 'remapped-combat': 'combat', 'ai': 'ai',
             'hitscan': 'hitscan', 'projectiles': 'projectiles', 'blast': 'blast',
             'explosions': 'barrels-chain', 'modern': 'combat', 'actor': 'actors-barrel',
             'door': 'door', 'locked-door': 'door-key', 'tagged-door': 'tagged-door-gui',
             'walk-door': 'tagged-door-90', 'gun-door': 'tagged-door-gun-portal',
             'lift': 'floor-lift-ride', 'platform': 'platform-riding', 'stairs': 'stairs-gui',
             'walk-floor': 'floor-88', 'gun-floor': 'floor-gun', 'button': 'switch-button',
             'switch': 'switch-103', 'gun-switch': 'switch-24', 'exit': 'exits-use',
             'failed-exit': 'exits-missing'}
    cases += [(f'--{mode}', fixture, 'E1M1') for mode, fixture in modes.items()]
    cases += [('--secret-exit', 'exits-secret', 'E1M3'), ('--complete', 'exits-end', 'E1M8')]
    for mode, fixture, marker in cases:
        run([sys.executable, ROOT / 'tests/gui_smoke.py', *([mode] if mode else []),
             executable, destination / f'{fixture}.wad', marker], ROOT, timeout=60)
    headless = destination / 'doom-check'
    run([sdk, 'build', 'Doom.Mod', '-o', headless], destination)
    run([sys.executable, ROOT / 'tests/logging_smoke.py', headless, executable], ROOT)


def a2_argument(value):
    if '"' not in value:
        return '"' + value + '"'
    if "'" not in value:
        return "'" + value + "'"
    raise RuntimeError('A2 command arguments cannot contain both quote types')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['stage', 'build', 'run', 'check', 'wad-check', 'door-check', 'bench', 'gui-check'])
    parser.add_argument('--platform', choices=['auto', 'linux', 'windows', 'a2'], default='auto')
    parser.add_argument('--engine', default='')
    parser.add_argument('--build-dir')
    parser.add_argument('--a2-root', default='')
    parser.add_argument('--a2-platform', choices=A2_EXTENSIONS, default='Win64' if os.name == 'nt' else 'Unix64')
    parser.add_argument('args', nargs=argparse.REMAINDER)
    options = parser.parse_args()
    if options.args[:1] == ['--']:
        options.args = options.args[1:]
    platform = options.platform
    if platform == 'auto':
        platform = 'windows' if os.name == 'nt' else 'linux'
    engine = engine_path(options.engine)
    destination = Path(options.build_dir).resolve() if options.build_dir else ROOT / 'build' / ('' if platform == 'linux' else platform)
    stage(platform, engine, destination)
    if options.action == 'stage':
        return
    sdk = shutil.which('ob')
    if not sdk:
        raise RuntimeError('MiniA2 SDK ob is missing from PATH')
    if platform == 'a2':
        a2_build(destination, options, sdk)
        if options.action == 'run':
            host = 'Win64' if os.name == 'nt' else 'Unix64'
            if options.a2_platform != host:
                raise RuntimeError(f'The hosted A2 harness needs A2_PLATFORM={host}')
            (destination / 'launch.cfg').write_text('DoomWindow.Do ' + ' '.join(map(a2_argument, options.args)) + '~\n')
            run([sdk, 'run', '--gui=800x600', 'A2Launch.Mod'], destination, timeout=None)
        return
    if (platform == 'windows') != (os.name == 'nt'):
        raise RuntimeError('GUI builds require the native MiniA2 SDK on the selected platform')
    executable = destination / ('ao-doom.exe' if platform == 'windows' else 'ao-doom')
    if options.action == 'check':
        checks(destination, engine, sdk, platform)
    elif options.action in ('wad-check', 'door-check', 'bench'):
        module = {'wad-check': 'DoomOriginalSmoke', 'door-check': 'DoomOriginalDoorsSmoke', 'bench': 'SceneBench'}[options.action]
        shutil.copy2(ROOT / 'tests' / (module + '.Mod'), destination)
        run([sdk, 'build', module + '.Mod', '-o', executable], destination)
        run([executable, *options.args], destination, timeout=30)
        return
    run([sdk, 'build', '--gui=640x400', 'DoomWindow.Mod', '-o', executable], destination)
    if options.action == 'run':
        run([executable, *options.args], ROOT, timeout=None)
    elif options.action == 'gui-check':
        gui_checks(destination, sdk, executable, platform)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
