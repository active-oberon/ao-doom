#!/usr/bin/env python3
"""gui_smoke checks only the window owned by the executable it launches."""

import ctypes as C
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

X = C.CDLL("libX11.so.6")
Display = C.c_void_p
Window = C.c_ulong
X.XOpenDisplay.argtypes = [C.c_char_p]
X.XOpenDisplay.restype = Display
X.XDefaultRootWindow.argtypes = [Display]
X.XDefaultRootWindow.restype = Window
X.XQueryTree.argtypes = [Display, Window, C.POINTER(Window), C.POINTER(Window),
                         C.POINTER(C.POINTER(Window)), C.POINTER(C.c_uint)]
X.XGetCommand.argtypes = [Display, Window, C.POINTER(C.POINTER(C.c_char_p)),
                          C.POINTER(C.c_int)]
X.XFreeStringList.argtypes = [C.POINTER(C.c_char_p)]
X.XFree.argtypes = [C.c_void_p]
X.XKeysymToKeycode.argtypes = [Display, C.c_ulong]
X.XKeysymToKeycode.restype = C.c_uint
X.XGetImage.argtypes = [Display, Window, C.c_int, C.c_int, C.c_uint,
                        C.c_uint, C.c_ulong, C.c_int]
X.XGetImage.restype = C.c_void_p
X.XGetPixel.argtypes = [C.c_void_p, C.c_int, C.c_int]
X.XGetPixel.restype = C.c_ulong
X.XDestroyImage.argtypes = [C.c_void_p]
X.XFlush.argtypes = [Display]
X.XCloseDisplay.argtypes = [Display]
X.XGetInputFocus.argtypes = [Display, C.POINTER(Window), C.POINTER(C.c_int)]
X.XSetInputFocus.argtypes = [Display, Window, C.c_int, C.c_ulong]
X.XQueryPointer.argtypes = [Display, Window, C.POINTER(Window), C.POINTER(Window),
                           *([C.POINTER(C.c_int)] * 4), C.POINTER(C.c_uint)]
X.XWarpPointer.argtypes = [Display, Window, Window, *([C.c_int] * 6)]
X.XCreateSimpleWindow.argtypes = [Display, Window, C.c_int, C.c_int, C.c_uint,
                                 C.c_uint, C.c_uint, C.c_ulong, C.c_ulong]
X.XCreateSimpleWindow.restype = Window
X.XMapWindow.argtypes = [Display, Window]
X.XDestroyWindow.argtypes = [Display, Window]


class KeyEvent(C.Structure):
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong),
                ("send_event", C.c_int), ("display", Display),
                ("window", Window), ("root", Window), ("subwindow", Window),
                ("time", C.c_ulong), ("x", C.c_int), ("y", C.c_int),
                ("x_root", C.c_int), ("y_root", C.c_int),
                ("state", C.c_uint), ("keycode", C.c_uint),
                ("same_screen", C.c_int)]


class FocusEvent(C.Structure):
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong),
                ("send_event", C.c_int), ("display", Display),
                ("window", Window), ("mode", C.c_int), ("detail", C.c_int)]


class Event(C.Union):
    _fields_ = [("key", KeyEvent), ("focus", FocusEvent), ("padding", C.c_long * 24)]


X.XSendEvent.argtypes = [Display, Window, C.c_int, C.c_long, C.POINTER(Event)]


def find_window(display, parent, executable):
    root, ancestor = Window(), Window()
    children, count = C.POINTER(Window)(), C.c_uint()
    if not X.XQueryTree(display, parent, C.byref(root), C.byref(ancestor),
                        C.byref(children), C.byref(count)):
        return None
    try:
        for index in range(count.value):
            window = children[index]
            argv, argc = C.POINTER(C.c_char_p)(), C.c_int()
            if X.XGetCommand(display, window, C.byref(argv), C.byref(argc)):
                try:
                    if argc.value and pathlib.Path(argv[0].decode()).resolve() == executable:
                        return window
                finally:
                    X.XFreeStringList(argv)
            found = find_window(display, window, executable)
            if found is not None:
                return found
    finally:
        if children:
            X.XFree(children)
    return None


def pixels(display, window, hud=False):
    image = X.XGetImage(display, window, 0, 0, 640, 400, C.c_ulong(-1), 2)
    assert image, "Cannot read the game window"
    try:
        return tuple(X.XGetPixel(image, x, y)
                     for y in range(360 if hud else 0, 400, 2 if hud else 8)
                     for x in range(0, 640, 2 if hud else 8))
    finally:
        X.XDestroyImage(image)


def visible(frame):
    # Exclude the maximum crosshair area, status panel and weapon status line.
    colors = {color for index, color in enumerate(frame[:43 * 80])
              if abs(index % 80 - 40) > 4 or abs(index // 80 - 25) > 4}
    return len(colors) > 1 and bool(colors.difference((0x202938, 0x35302C)))


def key(display, window, root, keysym, release=False):
    event = Event()
    event.key.type = 3 if release else 2
    event.key.display = display
    event.key.window = window
    event.key.root = root
    event.key.keycode = X.XKeysymToKeycode(display, keysym)
    event.key.same_screen = 1
    assert X.XSendEvent(display, window, 0, 2 if release else 1, C.byref(event))
    X.XFlush(display)


def focus(display, window, gained):
    event = Event()
    event.focus.type = 9 if gained else 10
    event.focus.display = display
    event.focus.window = window
    assert X.XSendEvent(display, window, 0, 1 << 21, C.byref(event))
    X.XFlush(display)


def shutdown(display, window, root):
    # A synthetic key still needs the game focused after restoring other windows.
    X.XSetInputFocus(display, window, 1, 0)
    X.XFlush(display)
    time.sleep(0.2)
    key(display, window, root, 0xFF1B)


def button(display, window, root, number, release=False):
    event = Event()
    event.key.type = 5 if release else 4
    event.key.display = display
    event.key.window = window
    event.key.root = root
    event.key.x, event.key.y = 320, 200
    event.key.keycode = number
    event.key.same_screen = 1
    assert X.XSendEvent(display, window, 0, 1 << (3 if release else 2), C.byref(event))
    X.XFlush(display)


def pointer(display, window):
    root, child = Window(), Window()
    rx, ry, x, y = C.c_int(), C.c_int(), C.c_int(), C.c_int()
    mask = C.c_uint()
    assert X.XQueryPointer(display, window, C.byref(root), C.byref(child), C.byref(rx),
                           C.byref(ry), C.byref(x), C.byref(y), C.byref(mask))
    return rx.value, ry.value, x.value, y.value


def mouse_controls(display, window, root):
    previous, revert = Window(), C.c_int()
    X.XGetInputFocus(display, C.byref(previous), C.byref(revert))
    saved = pointer(display, root)
    peer = X.XCreateSimpleWindow(display, root, 0, 0, 64, 64, 0, 0, 0)
    assert peer
    try:
        X.XSetInputFocus(display, window, 1, 0)
        X.XFlush(display)
        time.sleep(0.3)
        initial = pixels(display, window)
        for _ in range(3):
            X.XWarpPointer(display, 0, window, 0, 0, 0, 0, 420, 200)
            X.XFlush(display)
            time.sleep(0.15)
            assert pointer(display, window)[2:] == (320, 200), "Mouse was not recentered"
        turned = pixels(display, window)
        assert turned != initial, "Horizontal mouse motion did not turn the view"
        X.XWarpPointer(display, 0, window, 0, 0, 0, 0, 320, 150)
        X.XFlush(display)
        time.sleep(0.2)
        pitched = pixels(display, window)
        assert pitched != turned, "Vertical mouse motion did not pitch the view"
        button(display, window, root, 3)
        time.sleep(0.2)
        zoomed = pixels(display, window)
        assert zoomed != pitched, "RMB did not aim"
        button(display, window, root, 3, True)
        time.sleep(0.2)
        assert pixels(display, window) == pitched, "RMB release did not restore the view"
        panel = pixels(display, window, hud=True)
        button(display, window, root, 1)
        time.sleep(1.4)
        button(display, window, root, 1, True)
        time.sleep(0.2)
        depleted = pixels(display, window, hud=True)
        assert depleted != panel, "LMB did not consume ammunition"
        button(display, window, root, 1)
        time.sleep(0.8)
        assert pixels(display, window, hud=True) == depleted, "Empty magazine kept firing"
        key(display, window, root, ord("r"))
        key(display, window, root, ord("r"), True)
        time.sleep(0.7)
        assert pixels(display, window, hud=True) != depleted, "R did not reload and allow firing"
        button(display, window, root, 1, True)
        time.sleep(0.2)
        pistol = pixels(display, window)
        key(display, window, root, ord("1"))
        key(display, window, root, ord("1"), True)
        time.sleep(0.2)
        assert pixels(display, window) != pistol, "Digit did not change the selected weapon"
        button(display, window, root, 5)
        button(display, window, root, 5, True)
        time.sleep(0.2)
        assert pixels(display, window) == pistol, "Wheel did not return to the pistol"
        key(display, window, root, ord("r"))
        key(display, window, root, ord("r"), True)
        time.sleep(0.6)
        button(display, window, root, 1)
        button(display, window, root, 3)
        X.XMapWindow(display, peer)
        X.XFlush(display)
        time.sleep(0.2)
        X.XSetInputFocus(display, peer, 1, 0)
        X.XFlush(display)
        time.sleep(0.2)
        stopped = pixels(display, window, hud=True)
        time.sleep(0.6)
        assert pixels(display, window, hud=True) == stopped, "Mouse firing survived focus loss"
        X.XWarpPointer(display, 0, peer, 0, 0, 0, 0, 32, 32)
        X.XFlush(display)
        time.sleep(0.1)
        current_focus, current_revert = Window(), C.c_int()
        X.XGetInputFocus(display, C.byref(current_focus), C.byref(current_revert))
        position = pointer(display, peer)[2:]
        assert current_focus.value == peer, "Auxiliary test window did not retain focus"
        assert position == (32, 32), f"Focus loss did not release pointer confinement: position={position}"
        X.XSetInputFocus(display, window, 1, 0)
        X.XFlush(display)
        time.sleep(0.3)
        panel = pixels(display, window, hud=True)
        time.sleep(0.5)
        assert pixels(display, window, hud=True) == panel, "Focus regain resumed firing"
        print("Modern GUI check passed: yaw/pitch, recenter, LMB, RMB, magazine/R, digit/wheel and focus release")
    finally:
        X.XDestroyWindow(display, peer)
        X.XSetInputFocus(display, previous, revert.value, 0)
        X.XFlush(display)
        time.sleep(0.05)
        X.XWarpPointer(display, 0, root, 0, 0, 0, 0, saved[0], saved[1])
        X.XFlush(display)


def check_logs(output, arguments):
    records = [json.loads(line) for line in output.splitlines() if line.startswith('{"time":')]
    assert records, "Game emitted no structured logs"
    for record in records:
        assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", record["time"])
        assert record["attrs"]["component"] == "doom"
        assert record["level"] == "INFO", record
    assert [record["msg"] for record in records] == ["configuration loaded",
            "map loaded" if any(arg.lower().endswith(".wad") for arg in arguments) else "demo loaded",
            "window started", "window stopped"], records
    started, stopped = records[-2:]
    assert started["attrs"]["width"] == 320 and started["attrs"]["height"] == 200
    assert started["attrs"]["ticks_per_second"] == 35
    assert isinstance(stopped["attrs"]["ticks"], int) and stopped["attrs"]["ticks"] > 0
    assert stopped["attrs"]["result"] == 0


def check(executable, arguments, door=False, pickup=False, locked_door=False, actor=False, combat=False, remapped=False, ai=False, hitscan=False, projectiles=False, modern=False, blast=False, explosions=False):
    executable = executable.resolve()
    display = X.XOpenDisplay(None)
    if not display:
        raise RuntimeError("No X11 display is accessible for the window check")
    root = X.XDefaultRootWindow(display)
    previous_focus, previous_revert = Window(), C.c_int()
    X.XGetInputFocus(display, C.byref(previous_focus), C.byref(previous_revert))
    previous_pointer = pointer(display, root)
    process = subprocess.Popen([str(executable), *arguments], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    try:
        deadline = time.monotonic() + 5
        window = None
        while window is None and time.monotonic() < deadline:
            assert process.poll() is None, "Game exited before opening its window"
            window = find_window(display, root, executable)
            time.sleep(0.05)
        assert window is not None, "Game window did not appear"
        deadline = time.monotonic() + 5
        initial = ()
        while time.monotonic() < deadline:
            assert process.poll() is None, "Game exited before rendering its scene"
            initial = pixels(display, window)
            if visible(initial):
                break
            time.sleep(0.05)
        assert visible(initial), "Frame contains no visible scene"
        # Synchronize the driver's physical modifier snapshot before synthetic Ctrl.
        key(display, window, root, ord("0"))
        key(display, window, root, ord("0"), release=True)
        time.sleep(0.05)
        if modern:
            mouse_controls(display, window, root)
            shutdown(display, window, root)
            output, _ = process.communicate(timeout=5)
            assert process.returncode == 0, output
            check_logs(output, arguments)
            return
        if explosions:
            key(display, window, root, 0xFFE3)
            time.sleep(0.7)
            key(display, window, root, 0xFFE3, release=True)
            first = pixels(display, window)
            assert first[:43 * 80] != initial[:43 * 80], "Destroyed barrel did not start its explosion"
            time.sleep(0.45)
            second = pixels(display, window)
            assert second[:43 * 80] != first[:43 * 80], "Barrel explosion did not animate or reach its neighbor"
            time.sleep(2)
            final = pixels(display, window)
            assert final[:43 * 80] != second[:43 * 80], "Barrel chain did not finish and clear its effects"
            time.sleep(0.3)
            assert pixels(display, window) == final, "Completed barrel explosions continued changing the scene"
            initial = final
        if blast:
            key(display, window, root, ord("5"))
            key(display, window, root, ord("5"), release=True)
            time.sleep(0.2)
            before = pixels(display, window, hud=True)
            health = tuple(before[row * 320 + 32:row * 320 + 44] for row in range(3, 8))
            button(display, window, root, 1)
            time.sleep(0.6)
            button(display, window, root, 1, True)
            time.sleep(0.2)
            dead = pixels(display, window)
            panel = pixels(display, window, hud=True)
            assert tuple(panel[row * 320 + 32:row * 320 + 44] for row in range(3, 8)) != health, "Own rocket blast did not reduce health"
            assert dead[:43 * 80] != initial[:43 * 80], "Rocket blast did not change the visible targets"
            time.sleep(0.5)
            assert pixels(display, window, hud=True) == panel, "Rocket blast caused repeated damage"
            initial = dead
        if hitscan or projectiles:
            before = pixels(display, window, hud=True)
            deadline = time.monotonic() + 3
            while pixels(display, window, hud=True) == before and time.monotonic() < deadline:
                time.sleep(0.05)
            assert pixels(display, window, hud=True) != before, "Ranged actor did not damage the stationary player"
            key(display, window, root, 0xFFE3)
            time.sleep(0.2)
            key(display, window, root, 0xFFE3, release=True)
            # A fired fireball and its impact finish independently of the owner's death.
            time.sleep(0.75 if projectiles else 0.2)
            dead = pixels(display, window)
            panel = pixels(display, window, hud=True)
            time.sleep(1.5)
            assert pixels(display, window, hud=True) == panel, "Killed ranged actor caused further damage"
            assert pixels(display, window) == dead, "Killed ranged actor continued animating"
            initial = dead
        if ai:
            before = pixels(display, window, hud=True)
            time.sleep(0.3)
            assert pixels(display, window)[:45 * 80] != initial[:45 * 80], "Demon did not approach the stationary player"
            deadline = time.monotonic() + 3
            while pixels(display, window, hud=True) == before and time.monotonic() < deadline:
                time.sleep(0.05)
            assert pixels(display, window, hud=True) != before, "Demon bite did not update health"
            key(display, window, root, 0xFFE3)
            time.sleep(0.2)
            key(display, window, root, 0xFFE3, release=True)
            time.sleep(0.2)
            dead = pixels(display, window)
            panel = pixels(display, window, hud=True)
            time.sleep(1)
            assert pixels(display, window, hud=True) == panel, "Killed demon continued to bite"
            assert pixels(display, window) == dead, "Killed demon continued moving or animating"
            assert visible(dead), "Killing the demon removed the visible scene"
            initial = dead
        if combat:
            before = pixels(display, window, hud=True)
            if remapped:
                key(display, window, root, 0xFFE3)
                key(display, window, root, ord("w"))
                time.sleep(0.7)
                key(display, window, root, 0xFFE3, release=True)
                key(display, window, root, ord("w"), release=True)
                assert pixels(display, window) == initial, "Old bindings stayed active after YAML remapping"
            fire_key = ord("f") if remapped else 0xFFE3
            key(display, window, root, fire_key)
            time.sleep(0.9)
            key(display, window, root, fire_key, release=True)
            time.sleep(0.25)
            after = pixels(display, window, hud=True)
            assert after != before, "Pistol did not consume ammunition"
            dead = pixels(display, window)
            assert dead[:45 * 80] != initial[:45 * 80], "Target did not change to its corpse frame"
            time.sleep(0.7)
            assert pixels(display, window, hud=True) == after, "Firing continued after key release"
            key(display, window, root, fire_key)
            time.sleep(0.2)
            focus(display, window, False)
            time.sleep(0.25)
            unfocused_panel = pixels(display, window, hud=True)
            time.sleep(0.7)
            assert pixels(display, window, hud=True) == unfocused_panel, "Firing continued after focus loss"
            key(display, window, root, fire_key, release=True)
            focus(display, window, True)
            initial = pixels(display, window)
        if actor:
            key(display, window, root, ord("i" if remapped else "w"))
            time.sleep(1.2)
            key(display, window, root, ord("i" if remapped else "w"), release=True)
            time.sleep(0.2)
            blocked = pixels(display, window)
            assert blocked != initial, "Player did not approach the solid actor"
            key(display, window, root, ord("i" if remapped else "w"))
            time.sleep(0.4)
            key(display, window, root, ord("i" if remapped else "w"), release=True)
            time.sleep(0.2)
            assert pixels(display, window) == blocked, "Player walked through the solid actor"
            key(display, window, root, ord("i" if remapped else "w"))
            key(display, window, root, ord("d"))
            time.sleep(0.5)
            key(display, window, root, ord("i" if remapped else "w"), release=True)
            key(display, window, root, ord("d"), release=True)
            time.sleep(0.2)
            assert pixels(display, window) != blocked, "Player could not slide around the solid actor"
            key(display, window, root, ord("s"))
            time.sleep(0.5)
            key(display, window, root, ord("s"), release=True)
            time.sleep(0.2)
            initial = pixels(display, window)
        if locked_door:
            key(display, window, root, ord("e"))
            time.sleep(0.2)
            locked = pixels(display, window)
            panel = pixels(display, window, hud=True)
            assert locked[:45 * 80] == initial[:45 * 80], "Door opened without its key"
            assert panel[13 * 320 + 216] == 0x60A0FF, "Missing blue key hint was not drawn"
            key(display, window, root, ord("d"))
            deadline = time.monotonic() + 3
            while pixels(display, window, hud=True)[13 * 320 + 144] != 0x60A0FF:
                assert time.monotonic() < deadline, "Strafing did not collect the blue card"
                time.sleep(0.05)
            key(display, window, root, ord("d"), release=True)
            time.sleep(0.2)
            assert pixels(display, window, hud=True)[13 * 320 + 216] == 0x12161C, "Collected key did not clear its hint"
            key(display, window, root, ord("e"), release=True)
            before_open = pixels(display, window)
            key(display, window, root, ord("e"))
            key(display, window, root, ord("e"), release=True)
            time.sleep(2)
            initial = pixels(display, window)
            assert initial[:45 * 80] != before_open[:45 * 80], "Collected key did not unlock the door"
            time.sleep(0.2)
            assert pixels(display, window) == initial, "Locked open-only door did not stop moving"
        if pickup:
            before = pixels(display, window, hud=True)
            key(display, window, root, ord("i" if remapped else "w"))
            deadline = time.monotonic() + 4
            while pixels(display, window, hud=True) == before and time.monotonic() < deadline:
                time.sleep(0.05)
            key(display, window, root, ord("i" if remapped else "w"), release=True)
            time.sleep(0.2)
            assert pixels(display, window, hud=True) != before, "Touching items did not update inventory HUD"
            initial = pixels(display, window)
        if door:
            key(display, window, root, ord("e"))
            time.sleep(0.3)
            assert pixels(display, window) != initial, "Door did not start opening"
            key(display, window, root, ord("e"))
            time.sleep(2)
            key(display, window, root, ord("e"), release=True)
            opened = pixels(display, window)
            assert opened != initial, "Repeated held Space toggled the door"
            time.sleep(0.2)
            assert pixels(display, window) == opened, "Door did not reach its open position"
            key(display, window, root, ord("e"))
            time.sleep(2)
            key(display, window, root, ord("e"), release=True)
            assert pixels(display, window) == initial, "A new Space press did not close the door"
            key(display, window, root, ord("e"))
            key(display, window, root, ord("e"), release=True)
            time.sleep(2)
            initial = pixels(display, window)
            assert initial == opened, "Door did not reopen"
        key(display, window, root, ord("i" if remapped else "w"))
        time.sleep(0.3)
        key(display, window, root, ord("i" if remapped else "w"), release=True)
        time.sleep(0.2)
        moved = pixels(display, window)
        assert moved != initial, "Forward input did not change the frame"
        time.sleep(0.15)
        assert pixels(display, window) == moved, "Player kept moving after key release"
        key(display, window, root, ord("d"))
        time.sleep(0.15)
        focus(display, window, False)
        time.sleep(0.2)
        unfocused = pixels(display, window)
        time.sleep(0.15)
        assert pixels(display, window) == unfocused, "Player kept moving after focus loss"
        key(display, window, root, ord("d"), release=True)
        focus(display, window, True)
        key(display, window, root, 0xFF53)
        time.sleep(0.2)
        key(display, window, root, 0xFF53, release=True)
        time.sleep(0.15)
        assert pixels(display, window) != moved, "Turn input did not change the frame"
        shutdown(display, window, root)
        output, _ = process.communicate(timeout=5)
        assert process.returncode == 0, output
        check_logs(output, arguments)
        if door:
            print("Door GUI check passed: opening, held/released E, closing and reopening")
        if pickup:
            print("Pickup GUI check passed: touching items updates the inventory HUD")
        if locked_door:
            print("Locked door GUI check passed: key denial hint, card pickup, unlocking and crossing")
        if combat:
            print("Combat GUI check passed: ammo, corpse, release, focus loss and YAML bindings")
        if actor:
            print("Actor GUI check passed: approach, blocked forward movement and diagonal sliding")
        if ai:
            print("AI GUI check passed: stationary-player chase, bite HUD, YAML damage, kill and stopped attacks")
        if hitscan:
            print("Hitscan GUI check passed: ranged damage HUD, YAML damage, kill and stopped enemy fire")
        if projectiles:
            print("Projectile GUI check passed: flight damage HUD, YAML damage, kill and stopped enemy attacks")
        if blast:
            print("Blast GUI check passed: rocket selection, health/corpses, one impact and clean shutdown")
        if explosions:
            print("Explosion GUI check passed: barrel death, changing frames, delayed chain and effect expiry")
        print("GUI check passed: visible scene, movement, release, focus loss, turn, Escape shutdown")
    except Exception:
        if process.poll() is None:
            process.kill()
        output, _ = process.communicate()
        print(output, file=sys.stderr)
        raise
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()
        X.XSetInputFocus(display, previous_focus, previous_revert.value, 0)
        X.XWarpPointer(display, 0, root, 0, 0, 0, 0, previous_pointer[0], previous_pointer[1])
        X.XFlush(display)
        X.XCloseDisplay(display)


def main():
    blank = [0x202938 if i < 25 * 80 else 0x35302C for i in range(50 * 80)]
    blank[25 * 80 + 40] = 0xFFFFFF
    assert not visible(blank), "Crosshair alone must not qualify as a visible scene"
    blank[43 * 80 + 1] = 0xFFFFFF
    assert not visible(blank), "Weapon status alone must not qualify as a visible scene"
    blank[0] = 0xFFFFFF
    assert visible(blank)
    arguments = sys.argv[1:]
    door = arguments[0] == "--door"
    pickup = arguments[0] == "--pickup"
    locked_door = arguments[0] == "--locked-door"
    actor = arguments[0] == "--actor"
    combat = arguments[0] in ("--combat", "--remapped-combat")
    remapped = arguments[0] == "--remapped-combat"
    ai = arguments[0] == "--ai"
    hitscan = arguments[0] == "--hitscan"
    projectiles = arguments[0] == "--projectiles"
    modern = arguments[0] == "--modern"
    blast = arguments[0] == "--blast"
    explosions = arguments[0] == "--explosions"
    if door or pickup or locked_door or actor or combat or ai or hitscan or projectiles or modern or blast or explosions:
        arguments = arguments[1:]
    with tempfile.TemporaryDirectory(prefix="ao-doom-gui-") as directory:
        executable = pathlib.Path(directory) / "ao-doom"
        shutil.copy2(arguments[0], executable)
        if combat or ai or hitscan or projectiles or modern or blast:
            config = pathlib.Path(directory) / "doom-test.yaml"
            profile = pathlib.Path("doom.yaml").read_text()
            if blast:
                profile = re.sub(r"      explosion:\n(?:        .*\n)+", "      explosion: null\n", profile)
            if combat or modern:
                # Isolate weapon/input checks from autonomous target attacks and animation.
                profile = re.sub(r"      behavior: hitscan\n      hitscan:\n(?:        .*\n)+",
                                 "      behavior: static\n", profile)
            if modern:
                profile = (profile.replace("    magazine: 12\n", "    magazine: 2\n")
                           .replace("    cooldown_ticks: 19\n", "    cooldown_ticks: 2\n")
                           .replace("    flash_ticks: 3\n", "    flash_ticks: 1\n")
                           .replace("    reload_ticks: 35\n", "    reload_ticks: 14\n"))
            if remapped:
                profile = (profile.replace("forward: [0x77, 0x57, 0xff52]", "forward: [0x69, 0x49, 0xff52]")
                           .replace("fire: [0xffe3, 0xffe4]", "fire: [0x66, 0x46]"))
            if ai or hitscan or projectiles:
                profile = profile.replace("    damage: 10\n", "    damage: 200\n")
            config.write_text(profile)
            arguments[1:1] = ["--config", str(config)]
        check(executable, arguments[1:], door, pickup, locked_door, actor, combat, remapped, ai, hitscan, projectiles, modern, blast, explosions)


if __name__ == "__main__":
    main()
