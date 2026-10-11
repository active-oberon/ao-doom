MODULE DoomWindow;

IMPORT DoomConfig, DoomInput, Doom, GameLoop, GameSurface, GameDisplay, GameClock,
	Inputs, Objects, Kernel, KernelLog, Unix, Commands;

TYPE
	Keyboard = OBJECT (Inputs.Sink)
	VAR controls: DoomInput.Controller;

		PROCEDURE &Init(input: DoomInput.Controller);
		BEGIN
			controls := input
		END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		BEGIN
			IF message IS Inputs.FocusMsg THEN
				WITH message: Inputs.FocusMsg DO
					controls.Focus(message.focused)
				END
			ELSIF message IS Inputs.KeyboardMsg THEN
				WITH message: Inputs.KeyboardMsg DO
					controls.Key(message.keysym, Inputs.Release IN message.flags)
				END
			END
		END Handle;
	END Keyboard;

PROCEDURE Do*(context: Commands.Context);
VAR game: Doom.Game;
	simulation: GameLoop.Simulation;
	frame: GameSurface.Frame;
	presenter: GameDisplay.Presenter;
	keyboard: Keyboard;
	controls: DoomInput.Controller;
	clock: GameClock.Clock;
	timer: Kernel.MilliTimer;
	move, strafe, turn, elapsed, ticks, argument: SIGNED32;
	path: ARRAY 512 OF CHAR;
	map: ARRAY 9 OF CHAR;
	error: ARRAY 256 OF CHAR;
	firstFrame, activate, firing: BOOLEAN;
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
	NEW(controls);
	NEW(keyboard, controls);
	NEW(clock, DoomConfig.values.ticksPerSecond);
	Inputs.keyboard.Register(keyboard);
	KernelLog.String("Doom scene: movement, use, fire and quit keys are configured in YAML.");
	KernelLog.Ln;
	Kernel.SetTimer(timer, 0);
	firstFrame := TRUE;
	LOOP
		IF ~controls.Read(move, strafe, turn, activate, firing) THEN
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
		game.Fire(firing);
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
