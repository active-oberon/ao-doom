#!/usr/bin/env python3
"""gui_smoke checks only the window owned by the executable it launches."""

import ctypes as C
import pathlib
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
    colors = set(frame[:45 * 80])
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


def check(executable, arguments, door=False, pickup=False, locked_door=False):
    executable = executable.resolve()
    display = X.XOpenDisplay(None)
    if not display:
        raise RuntimeError("No X11 display is accessible for the window check")
    root = X.XDefaultRootWindow(display)
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
        if locked_door:
            key(display, window, root, 0x20)
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
            key(display, window, root, 0x20, release=True)
            before_open = pixels(display, window)
            key(display, window, root, 0x20)
            key(display, window, root, 0x20, release=True)
            time.sleep(2)
            initial = pixels(display, window)
            assert initial[:45 * 80] != before_open[:45 * 80], "Collected key did not unlock the door"
            time.sleep(0.2)
            assert pixels(display, window) == initial, "Locked open-only door did not stop moving"
        if pickup:
            before = pixels(display, window, hud=True)
            key(display, window, root, ord("w"))
            deadline = time.monotonic() + 4
            while pixels(display, window, hud=True) == before and time.monotonic() < deadline:
                time.sleep(0.05)
            key(display, window, root, ord("w"), release=True)
            time.sleep(0.2)
            assert pixels(display, window, hud=True) != before, "Touching items did not update inventory HUD"
            initial = pixels(display, window)
        if door:
            key(display, window, root, 0x20)
            time.sleep(0.3)
            assert pixels(display, window) != initial, "Door did not start opening"
            key(display, window, root, 0x20)
            time.sleep(2)
            key(display, window, root, 0x20, release=True)
            opened = pixels(display, window)
            assert opened != initial, "Repeated held Space toggled the door"
            time.sleep(0.2)
            assert pixels(display, window) == opened, "Door did not reach its open position"
            key(display, window, root, 0x20)
            time.sleep(2)
            key(display, window, root, 0x20, release=True)
            assert pixels(display, window) == initial, "A new Space press did not close the door"
            key(display, window, root, 0x20)
            key(display, window, root, 0x20, release=True)
            time.sleep(2)
            initial = pixels(display, window)
            assert initial == opened, "Door did not reopen"
        key(display, window, root, ord("w"))
        time.sleep(0.3)
        key(display, window, root, ord("w"), release=True)
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
        key(display, window, root, 0xFF1B)
        output, _ = process.communicate(timeout=5)
        assert process.returncode == 0, output
        if door:
            print("Door GUI check passed: opening, held/released Space, closing and reopening")
        if pickup:
            print("Pickup GUI check passed: touching items updates the inventory HUD")
        if locked_door:
            print("Locked door GUI check passed: key denial hint, card pickup, unlocking and crossing")
        print("GUI check passed: visible scene, movement, release, focus loss, turn, Escape shutdown")
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()
        X.XCloseDisplay(display)


def main():
    arguments = sys.argv[1:]
    door = arguments[0] == "--door"
    pickup = arguments[0] == "--pickup"
    locked_door = arguments[0] == "--locked-door"
    if door or pickup or locked_door:
        arguments = arguments[1:]
    with tempfile.TemporaryDirectory(prefix="ao-doom-gui-") as directory:
        executable = pathlib.Path(directory) / "ao-doom"
        shutil.copy2(arguments[0], executable)
        check(executable, arguments[1:], door, pickup, locked_door)


if __name__ == "__main__":
    main()
