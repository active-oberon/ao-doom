MODULE DoomMouse;

IMPORT DoomInput, Inputs, Displays, Plugins, XDisplay, X11, Machine, Unix;

VAR library: ADDRESS;
	getFocus: PROCEDURE {C} (display: X11.DisplayPtr; VAR window: X11.Window; VAR revert: SIGNED32);
	ungrab: PROCEDURE {C} (display: X11.DisplayPtr; time: X11.Time);

TYPE Pointer* = OBJECT (Inputs.Sink)
	VAR display: XDisplay.Display;
		controls: DoomInput.Controller;
		captured: BOOLEAN;

		PROCEDURE &Init(device: XDisplay.Display; input: DoomInput.Controller);
		BEGIN
			display := device;
			controls := input;
			captured := FALSE
		END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		BEGIN
			IF message IS Inputs.AbsMouseMsg THEN
				WITH message: Inputs.AbsMouseMsg DO
					controls.Mouse(message.keys, message.dz)
				END
			ELSIF message IS Inputs.MouseMsg THEN
				WITH message: Inputs.MouseMsg DO
					controls.Mouse(message.keys, message.dz);
					controls.Motion(message.dx, message.dy)
				END
			END
		END Handle;

		(* Poll recenters only the focused game window and ignores its generated warp notifications. *)
		PROCEDURE Poll*;
		VAR focus, root, child: X11.Window;
			revert, result, rx, ry, x, y, cx, cy: SIGNED32;
			dx, dy: SIGNED32;
			changed: BOOLEAN;
			buttons: SET32;
		BEGIN
			changed := FALSE;
			dx := 0;
			dy := 0;
			Machine.Acquire(Machine.X11);
			getFocus(display.xdisp, focus, revert);
			IF focus # display.primary THEN
				IF captured THEN
					ungrab(display.xdisp, X11.CurrentTime);
					captured := FALSE;
					changed := TRUE
				END
			ELSE
				cx := display.width DIV 2;
				cy := display.height DIV 2;
				IF ~captured THEN
					result := X11.GrabPointer(display.xdisp, display.primary, X11.True,
						X11.ButtonPressMask + X11.ButtonReleaseMask + X11.PointerMotionMask,
						X11.GrabModeAsync, X11.GrabModeAsync, display.primary, X11.None, X11.CurrentTime);
					IF result = X11.GrabSuccess THEN
						captured := TRUE;
						changed := TRUE;
						X11.WarpPointer(display.xdisp, X11.None, display.primary, 0, 0, 0, 0, cx, cy)
					END
				ELSE
					X11.QueryPointer(display.xdisp, display.primary, root, child, rx, ry, x, y, buttons);
					IF (x # cx) OR (y # cy) THEN
						dx := x - cx;
						dy := y - cy;
						X11.WarpPointer(display.xdisp, X11.None, display.primary, 0, 0, 0, 0, cx, cy)
					END
				END
			END;
			X11.Flush(display.xdisp);
			Machine.Release(Machine.X11);
			IF changed THEN
				controls.Focus(focus = display.primary)
			END;
			IF (dx # 0) OR (dy # 0) THEN
				controls.Motion(dx, dy)
			END
		END Poll;

		PROCEDURE Close*;
		BEGIN
			Machine.Acquire(Machine.X11);
			IF captured THEN
				ungrab(display.xdisp, X11.CurrentTime);
				X11.Flush(display.xdisp);
				captured := FALSE
			END;
			Machine.Release(Machine.X11);
			controls.Focus(FALSE)
		END Close;
	END Pointer;

PROCEDURE Open*(controls: DoomInput.Controller): Pointer;
VAR plugin: Plugins.Plugin;
	pointer: Pointer;
BEGIN
	plugin := Displays.registry.Get("");
	IF (plugin = NIL) OR ~(plugin IS XDisplay.Display) OR (getFocus = NIL) OR (ungrab = NIL) THEN
		RETURN NIL
	END;
	NEW(pointer, plugin(XDisplay.Display), controls);
	RETURN pointer
END Open;

BEGIN
	library := Unix.DlopenOptional("libX11.so.6", 2);
	IF library # 0 THEN
		Unix.Dlsym(library, "XGetInputFocus", ADDRESSOF(getFocus));
		Unix.Dlsym(library, "XUngrabPointer", ADDRESSOF(ungrab))
	END
END DoomMouse.
