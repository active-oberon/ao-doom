MODULE DoomWindow;

IMPORT DoomConfig, Doom, GameLoop, GameSurface, GameDisplay, GameClock,
	Inputs, Objects, Kernel, KernelLog, Unix, Commands;

CONST Forward = 0;
	Backward = 1;
	Left = 2;
	Right = 3;
	StrafeLeft = 4;
	StrafeRight = 5;
	Use = 6;

TYPE
	Keyboard = OBJECT (Inputs.Sink)
	VAR held: SET;
		quit: BOOLEAN;
		use: BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			held := {};
			quit := FALSE;
			use := FALSE
		END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		VAR action: SIGNED32;
		BEGIN {EXCLUSIVE}
			IF message IS Inputs.FocusMsg THEN
				WITH message: Inputs.FocusMsg DO
					IF ~message.focused THEN
						held := {};
						use := FALSE
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
						| 020H:
							action := Use
					ELSE
					END;
					IF action >= 0 THEN
						IF Inputs.Release IN message.flags THEN
							EXCL(held, action)
						ELSE
							IF (action = Use) & ~(Use IN held) THEN
								use := TRUE
							END;
							INCL(held, action)
						END
					END
				END
			END
		END Handle;

		PROCEDURE Read(VAR move, strafe, turn: SIGNED32; VAR activate: BOOLEAN): BOOLEAN;
		BEGIN {EXCLUSIVE}
			move := 0;
			strafe := 0;
			turn := 0;
			activate := use;
			use := FALSE;
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
	move, strafe, turn, elapsed, ticks, argument: SIGNED32;
	path: ARRAY 512 OF CHAR;
	map: ARRAY 9 OF CHAR;
	error: ARRAY 256 OF CHAR;
	firstFrame, activate: BOOLEAN;
BEGIN
	argument := 1;
	COPY(DoomConfig.DefaultFile, path);
	IF Unix.argc > argument THEN
		Unix.GetArg(argument, error);
		IF error = "--config" THEN
			INC(argument);
			IF Unix.argc <= argument THEN
				KernelLog.String("Doom: --config requires a YAML file path.");
				KernelLog.Ln;
				context.result := Commands.CommandError;
				RETURN
			END;
			Unix.GetArg(argument, path);
			INC(argument)
		END
	END;
	IF ~DoomConfig.Load(path, error) THEN
		KernelLog.String("Doom config: ");
		KernelLog.String(error);
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	presenter := GameDisplay.Open();
	IF presenter = NIL THEN
		KernelLog.String("Doom: no supported display; build with --gui.");
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	NEW(game);
	IF Unix.argc > argument THEN
		Unix.GetArg(argument, path);
		INC(argument);
		COPY("E1M1", map);
		IF Unix.argc > argument THEN
			Unix.GetArg(argument, map)
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
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	NEW(keyboard);
	NEW(clock, DoomConfig.values.ticksPerSecond);
	Inputs.keyboard.Register(keyboard);
	KernelLog.String("Doom scene: W/S move, A/D strafe, arrows turn, Space uses, Escape exits.");
	KernelLog.Ln;
	Kernel.SetTimer(timer, 0);
	firstFrame := TRUE;
	LOOP
		IF ~keyboard.Read(move, strafe, turn, activate) THEN
			EXIT
		END;
		elapsed := Kernel.Elapsed(timer);
		Kernel.SetTimer(timer, 0);
		IF elapsed < 0 THEN
			elapsed := 0
		ELSIF elapsed > DoomConfig.values.maximumElapsed THEN
			elapsed := DoomConfig.values.maximumElapsed
		END;
		ticks := clock.Consume(elapsed);
		game.Controls(move, strafe, turn);
		IF activate THEN
			game.Use
		END;
		IF ticks > 0 THEN
			ASSERT(simulation.Advance(ticks))
		END;
		IF (ticks > 0) OR firstFrame THEN
			game.Render(frame);
			IF ~presenter.Present(frame) THEN
				KernelLog.String("Doom: display is smaller than the configured frame.");
				KernelLog.Ln;
				context.result := Commands.CommandError;
				EXIT
			END;
			firstFrame := FALSE
		END;
		Objects.Sleep(DoomConfig.values.sleepMillis)
	END;
	Inputs.keyboard.Unregister(keyboard);
	simulation.Close
END Do;

END DoomWindow.
