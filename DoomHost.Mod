MODULE DoomHost;

IMPORT DoomInput, DoomMouse, Doom, GameSurface, GameDisplay, Inputs, Unix, Commands, Logging;

TYPE
	Keyboard = OBJECT (Inputs.Sink)
	VAR controls: DoomInput.Controller;
		known, focused: BOOLEAN;

		PROCEDURE &Init(input: DoomInput.Controller);
		BEGIN controls := input; known := FALSE END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		VAR fields: ARRAY 1 OF Logging.Attr; result: SIGNED32;
		BEGIN
			IF message IS Inputs.FocusMsg THEN
				WITH message: Inputs.FocusMsg DO
					controls.Focus(message.focused);
					IF ~known OR (focused # message.focused) THEN
						known := TRUE; focused := message.focused;
						fields[0] := Logging.Bool("focused", focused);
						result := Doom.log.Log(Logging.LevelInfo, "input focus changed", fields)
					END
				END
			ELSIF message IS Inputs.KeyboardMsg THEN
				WITH message: Inputs.KeyboardMsg DO controls.Key(message.keysym, Inputs.Release IN message.flags) END
			END
		END Handle;
	END Keyboard;

	Host* = OBJECT
	VAR argument: SIGNED32;
		presenter: GameDisplay.Presenter;
		keyboard: Keyboard;
		mouse: DoomMouse.Pointer;

		PROCEDURE &Init*(context: Commands.Context);
		BEGIN argument := 1 END Init;

		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF argument >= Unix.argc THEN RETURN FALSE END;
			Unix.GetArg(argument, value); INC(argument); RETURN TRUE
		END Next;

		PROCEDURE Open*(controls: DoomInput.Controller): BOOLEAN;
		BEGIN
			presenter := GameDisplay.Open();
			IF presenter = NIL THEN RETURN FALSE END;
			mouse := DoomMouse.Open(controls);
			IF mouse = NIL THEN RETURN FALSE END;
			NEW(keyboard, controls);
			Inputs.keyboard.Register(keyboard); Inputs.mouse.Register(mouse);
			RETURN TRUE
		END Open;

		PROCEDURE Poll*;
		BEGIN mouse.Poll END Poll;

		PROCEDURE Present*(frame: GameSurface.Frame): BOOLEAN;
		BEGIN RETURN presenter.Present(frame) END Present;

		PROCEDURE Close*;
		BEGIN
			Inputs.keyboard.Unregister(keyboard); Inputs.mouse.Unregister(mouse); mouse.Close
		END Close;
	END Host;

END DoomHost.
