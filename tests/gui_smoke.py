#!/usr/bin/env python3
"""gui_smoke checks only the window owned by the executable it launches."""

import ctypes as C
import pathlib
import subprocess
import sys
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


def pixels(display, window):
    image = X.XGetImage(display, window, 0, 0, 640, 400, C.c_ulong(-1), 2)
    assert image, "Cannot read the game window"
    try:
        return tuple(X.XGetPixel(image, x, y)
                     for y in range(0, 400, 8) for x in range(0, 640, 8))
    finally:
        X.XDestroyImage(image)


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


def main():
    executable = pathlib.Path(sys.argv[1]).resolve()
    display = X.XOpenDisplay(None)
    if not display:
        raise RuntimeError("No X11 display is accessible for the window check")
    root = X.XDefaultRootWindow(display)
    process = subprocess.Popen([str(executable), *sys.argv[2:]], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    try:
        deadline = time.monotonic() + 5
        window = None
        while window is None and time.monotonic() < deadline:
            assert process.poll() is None, "Game exited before opening its window"
            window = find_window(display, root, executable)
            time.sleep(0.05)
        assert window is not None, "Game window did not appear"
        time.sleep(0.2)
        initial = pixels(display, window)
        assert len(set(initial)) >= 4, "Frame contains no visible scene"
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
        print("GUI check passed: visible scene, movement, release, focus loss, turn, Escape shutdown")
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()
        X.XCloseDisplay(display)


if __name__ == "__main__":
    main()
