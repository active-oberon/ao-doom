MODULE DoomHost;

IMPORT DoomConfig, DoomInput, DoomKeys, Doom, GameSurface, Commands, Inputs, Plugins, Strings,
	WMWindowManager, WMRectangles, Raster, Logging
	(*#IF WIN THEN*) , User32 (*#END*) ;

TYPE
	Motion = OBJECT (Inputs.Sink)
	VAR controls: DoomInput.Controller;
		focused, absolute: BOOLEAN; x, y: SIGNED32;
		PROCEDURE &Init(input: DoomInput.Controller);
		BEGIN controls := input; focused := FALSE; absolute := FALSE END Init;
		PROCEDURE Focus(value: BOOLEAN);
		BEGIN {EXCLUSIVE} focused := value; absolute := FALSE END Focus;
		PROCEDURE Handle*(VAR message: Inputs.Message);
		BEGIN {EXCLUSIVE}
			IF ~focused THEN RETURN END;
			IF message IS Inputs.MouseMsg THEN
				WITH message: Inputs.MouseMsg DO controls.Motion(message.dx, message.dy) END
			ELSIF message IS Inputs.AbsMouseMsg THEN
				(* Hosted drivers provide absolute positions plus overflow at screen edges. *)
				WITH message: Inputs.AbsMouseMsg DO
					IF absolute THEN controls.Motion(message.x - x + message.dx, message.y - y + message.dy) END;
					x := message.x; y := message.y; absolute := TRUE
				END
			END
		END Handle;
	END Motion;

	Window = OBJECT (WMWindowManager.DoubleBufferWindow)
	VAR controls: DoomInput.Controller; motion: Motion;
		buttons: SET; focused, closed: BOOLEAN;
		PROCEDURE &New(input: DoomInput.Controller; pointer: Motion);
		BEGIN
			controls := input; motion := pointer; buttons := {}; focused := FALSE; closed := FALSE;
			Init(DoomConfig.values.width, DoomConfig.values.height, FALSE);
			SetTitle(Strings.NewString("ao-doom"))
		END New;

		PROCEDURE KeyEvent*(ucs: SIZE; flags: SET; keysym: SIZE);
		BEGIN
			(* Hosted Windows drivers may suppress releases; Poll reads physical key state there. *)
			(*#IF ~WIN THEN*) controls.Key(SIGNED32(keysym), Inputs.Release IN flags) (*#END*)
		END KeyEvent;

		PROCEDURE FocusGot*;
		VAR fields: ARRAY 1 OF Logging.Attr; result: SIGNED32;
		BEGIN
			focused := TRUE; controls.Focus(TRUE); motion.Focus(TRUE);
			fields[0] := Logging.Bool("focused", TRUE);
			result := Doom.log.Log(Logging.LevelInfo, "input focus changed", fields)
		END FocusGot;

		PROCEDURE FocusLost*;
		VAR fields: ARRAY 1 OF Logging.Attr; result: SIGNED32;
		BEGIN
			focused := FALSE; buttons := {}; motion.Focus(FALSE); controls.Focus(FALSE);
			fields[0] := Logging.Bool("focused", FALSE);
			result := Doom.log.Log(Logging.LevelInfo, "input focus changed", fields)
		END FocusLost;

		PROCEDURE PointerDown*(x, y: SIZE; keys: SET);
		BEGIN buttons := keys; controls.Mouse(keys, 0) END PointerDown;
		PROCEDURE PointerUp*(x, y: SIZE; keys: SET);
		BEGIN buttons := keys; controls.Mouse(keys, 0) END PointerUp;
		PROCEDURE PointerMove*(x, y: SIZE; keys: SET);
		BEGIN buttons := keys; controls.Mouse(keys, 0) END PointerMove;
		PROCEDURE WheelMove*(dz: SIZE);
		BEGIN controls.Mouse(buttons, SIGNED32(dz)) END WheelMove;

		PROCEDURE Close*;
		BEGIN
			closed := TRUE; motion.Focus(FALSE); controls.Stop; Close^
		END Close;

		PROCEDURE Present(frame: GameSurface.Frame): BOOLEAN;
		VAR row, column, source, target: SIGNED32;
		BEGIN
			IF closed THEN RETURN TRUE END;
			(* Raster.BGR888 stores the same blue/green/red byte order as GameSurface. *)
			FOR row := 0 TO frame.height - 1 DO
				FOR column := 0 TO frame.width - 1 DO
					source := (row * frame.width + column) * 4;
					target := row * SIGNED32(backImg.bpr) + column * 3;
					backImg.mem[target] := frame.pixels[source];
					backImg.mem[target + 1] := frame.pixels[source + 1];
					backImg.mem[target + 2] := frame.pixels[source + 2]
				END
			END;
			Swap;
			Invalidate(WMRectangles.MakeRect(0, 0, frame.width, frame.height));
			RETURN TRUE
		END Present;
	END Window;

	Host* = OBJECT
	VAR context: Commands.Context; window: Window; motion: Motion;
		PROCEDURE &Init*(command: Commands.Context);
		BEGIN context := command END Init;
		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		BEGIN RETURN context.arg.GetString(value) END Next;

		PROCEDURE Open*(controls: DoomInput.Controller): BOOLEAN;
		VAR plugin: Plugins.Plugin;
			(*#IF WIN THEN*) action, binding, result: SIGNED32; (*#END*)
		BEGIN
			(*#IF WIN THEN*)
			FOR action := 0 TO DoomConfig.InputActions - 1 DO
				FOR binding := 0 TO DoomConfig.values.controls[action].count - 1 DO
					IF DoomKeys.VirtualKey(DoomConfig.values.controls[action].keys[binding]) = 0 THEN
						result := Doom.log.Error("unsupported Windows key binding in A2"); RETURN FALSE
					END
				END
			END;
			(*#END*)
			plugin := WMWindowManager.registry.Get("");
			IF plugin = NIL THEN RETURN FALSE END;
			controls.Focus(FALSE);
			NEW(motion, controls); NEW(window, controls, motion);
			(* Explicit format avoids assumptions about the desktop's native pixel depth. *)
			Raster.Create(window.backImg, DoomConfig.values.width, DoomConfig.values.height, Raster.BGR888);
			Raster.Create(window.img, DoomConfig.values.width, DoomConfig.values.height, Raster.BGR888);
			Inputs.mouse.Register(motion);
			WMWindowManager.DefaultAddWindow(window);
			RETURN TRUE
		END Open;

		PROCEDURE Poll*;
		(*#IF WIN THEN*) VAR action, binding, key: SIGNED32; (*#END*)
		BEGIN
			(*#IF WIN THEN*)
			IF window.focused & ~window.closed THEN
				FOR action := 0 TO DoomConfig.InputActions - 1 DO
					FOR binding := 0 TO DoomConfig.values.controls[action].count - 1 DO
						key := DoomConfig.values.controls[action].keys[binding];
						controlsKey(key)
					END
				END
			END
			(*#END*)
		END Poll;

		(*#IF WIN THEN*)
		PROCEDURE controlsKey(key: SIGNED32);
		VAR native: SIGNED32;
		BEGIN
			native := DoomKeys.VirtualKey(key);
			IF native # 0 THEN window.controls.Key(key, User32.GetAsyncKeyState(native) >= 0) END
		END controlsKey;
		(*#END*)
		PROCEDURE Present*(frame: GameSurface.Frame): BOOLEAN;
		BEGIN RETURN window.Present(frame) END Present;
		PROCEDURE Close*;
		BEGIN
			motion.Focus(FALSE); Inputs.mouse.Unregister(motion); window.Close
		END Close;
	END Host;

END DoomHost.
