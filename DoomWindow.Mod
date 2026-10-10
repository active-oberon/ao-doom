MODULE DoomWindow;

IMPORT Doom, GameLoop, GameSurface, GameDisplay, GameClock,
	Inputs, Objects, Kernel, KernelLog, Unix, Commands;

CONST Forward = 0;
	Backward = 1;
	Left = 2;
	Right = 3;
	StrafeLeft = 4;
	StrafeRight = 5;

TYPE
	Keyboard = OBJECT (Inputs.Sink)
	VAR held: SET;
		quit: BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			held := {};
			quit := FALSE
		END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		VAR action: SIGNED32;
		BEGIN {EXCLUSIVE}
			IF message IS Inputs.FocusMsg THEN
				WITH message: Inputs.FocusMsg DO
					IF ~message.focused THEN
						held := {}
					END
				END
			ELSIF message IS Inputs.KeyboardMsg THEN
				WITH message: Inputs.KeyboardMsg DO
					IF (message.keysym = Inputs.KsEscape) &
						~(Inputs.Release IN message.flags) THEN
						quit := TRUE
					END;
					action := -1;
					CASE message.keysym OF
						Inputs.KsUp, 077H, 057H:
							action := Forward
						| Inputs.KsDown, 073H, 053H:
							action := Backward
						| Inputs.KsLeft:
							action := Left
						| Inputs.KsRight:
							action := Right
						| 061H, 041H:
							action := StrafeLeft
						| 064H, 044H:
							action := StrafeRight
					ELSE
					END;
					IF action >= 0 THEN
						IF Inputs.Release IN message.flags THEN
							EXCL(held, action)
						ELSE
							INCL(held, action)
						END
					END
				END
			END
		END Handle;

		PROCEDURE Read(VAR move, strafe, turn: SIGNED32): BOOLEAN;
		BEGIN {EXCLUSIVE}
			move := 0;
			strafe := 0;
			turn := 0;
			IF Forward IN held THEN
				INC(move)
			END;
			IF Backward IN held THEN
				DEC(move)
			END;
			IF StrafeRight IN held THEN
				INC(strafe)
			END;
			IF StrafeLeft IN held THEN
				DEC(strafe)
			END;
			IF Right IN held THEN
				INC(turn)
			END;
			IF Left IN held THEN
				DEC(turn)
			END;
			RETURN ~quit
		END Read;
	END Keyboard;

PROCEDURE Do*(context: Commands.Context);
VAR game: Doom.Game;
	simulation: GameLoop.Simulation;
	frame: GameSurface.Frame;
	presenter: GameDisplay.Presenter;
	keyboard: Keyboard;
	clock: GameClock.Clock;
	timer: Kernel.MilliTimer;
	move, strafe, turn, elapsed, ticks: SIGNED32;
	path: ARRAY 512 OF CHAR;
	map: ARRAY 9 OF CHAR;
	error: ARRAY 128 OF CHAR;
	firstFrame: BOOLEAN;
BEGIN
	presenter := GameDisplay.Open();
	IF presenter = NIL THEN
		KernelLog.String("Doom: no supported display; build with --gui.");
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	NEW(game);
	IF Unix.argc > 1 THEN
		Unix.GetArg(1, path);
		COPY("E1M1", map);
		IF Unix.argc > 2 THEN
			Unix.GetArg(2, map)
		END;
		IF ~game.Load(path, map, error) THEN
			KernelLog.String("Doom: ");
			KernelLog.String(error);
			KernelLog.Ln;
			context.result := Commands.CommandError;
			RETURN
		END
	END;
	NEW(simulation, game.Step);
	NEW(frame, 320, 200);
	NEW(keyboard);
	NEW(clock, Doom.TicksPerSecond);
	Inputs.keyboard.Register(keyboard);
	KernelLog.String("Doom scene: W/S move, A/D strafe, arrows turn, Escape exits.");
	KernelLog.Ln;
	Kernel.SetTimer(timer, 0);
	firstFrame := TRUE;
	LOOP
		IF ~keyboard.Read(move, strafe, turn) THEN
			EXIT
		END;
		elapsed := Kernel.Elapsed(timer);
		Kernel.SetTimer(timer, 0);
		IF elapsed < 0 THEN
			elapsed := 0
		ELSIF elapsed > 250 THEN
			elapsed := 250
		END;
		ticks := clock.Consume(elapsed);
		game.Controls(move, strafe, turn);
		IF ticks > 0 THEN
			ASSERT(simulation.Advance(ticks))
		END;
		IF (ticks > 0) OR firstFrame THEN
			game.Render(frame);
			IF ~presenter.Present(frame) THEN
				KernelLog.String("Doom: display is smaller than 320 x 200.");
				KernelLog.Ln;
				context.result := Commands.CommandError;
				EXIT
			END;
			firstFrame := FALSE
		END;
		Objects.Sleep(5)
	END;
	Inputs.keyboard.Unregister(keyboard);
	simulation.Close
END Do;

END DoomWindow.
