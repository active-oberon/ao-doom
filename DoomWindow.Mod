MODULE DoomWindow;

IMPORT DoomConfig, DoomInput, DoomMouse, Doom, GameLoop, GameSurface, GameDisplay, GameClock,
	Inputs, Objects, Kernel, Logging, Unix, Commands;

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
	mouse: DoomMouse.Pointer;
	clock: GameClock.Clock;
	timer: Kernel.MilliTimer;
	move, strafe, turn, elapsed, ticks, argument: SIGNED32;
	dx, dy, slot, cycle, logResult: SIGNED32;
	configFields: ARRAY 1 OF Logging.Attr;
	errorFields: ARRAY 2 OF Logging.Attr;
	mapFields, startupFields: ARRAY 3 OF Logging.Attr;
	stopFields: ARRAY 2 OF Logging.Attr;
	path: ARRAY 512 OF CHAR;
	map: ARRAY 9 OF CHAR;
	error: ARRAY 256 OF CHAR;
	firstFrame, activate, firing, reloading, aiming: BOOLEAN;
BEGIN
	argument := 1;
	COPY(DoomConfig.DefaultFile, path);
	IF Unix.argc > argument THEN
		Unix.GetArg(argument, error);
		IF error = "--config" THEN
			INC(argument);
			IF Unix.argc <= argument THEN
				logResult := Doom.log.Error("--config requires a YAML file path");
				context.result := Commands.CommandError;
				RETURN
			END;
			Unix.GetArg(argument, path);
			INC(argument)
		END
	END;
	IF ~DoomConfig.Load(path, error) THEN
		errorFields[0] := Logging.String("path", path);
		errorFields[1] := Logging.String("error", error);
		logResult := Doom.log.Log(Logging.LevelError, "configuration load failed", errorFields);
		context.result := Commands.CommandError;
		RETURN
	END;
	configFields[0] := Logging.String("path", path);
	logResult := Doom.log.Log(Logging.LevelInfo, "configuration loaded", configFields);
	presenter := GameDisplay.Open();
	IF presenter = NIL THEN
		logResult := Doom.log.Error("no supported display; build with --gui");
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
			mapFields[0] := Logging.String("path", path);
			mapFields[1] := Logging.String("map", map);
			mapFields[2] := Logging.String("error", error);
			logResult := Doom.log.Log(Logging.LevelError, "map load failed", mapFields);
			context.result := Commands.CommandError;
			RETURN
		END;
		mapFields[0] := Logging.String("path", path);
		mapFields[1] := Logging.String("map", map);
		mapFields[2] := Logging.Int("sectors", game.world.SectorCount());
		logResult := Doom.log.Log(Logging.LevelInfo, "map loaded", mapFields)
	ELSE
		logResult := Doom.log.Info("demo loaded")
	END;
	NEW(simulation, game.Step);
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	NEW(controls);
	mouse := DoomMouse.Open(controls);
	IF mouse = NIL THEN
		logResult := Doom.log.Error("X11 mouse capture is unavailable");
		simulation.Close;
		context.result := Commands.CommandError;
		RETURN
	END;
	NEW(keyboard, controls);
	NEW(clock, DoomConfig.values.ticksPerSecond);
	Inputs.keyboard.Register(keyboard);
	Inputs.mouse.Register(mouse);
	startupFields[0] := Logging.Int("width", frame.width);
	startupFields[1] := Logging.Int("height", frame.height);
	startupFields[2] := Logging.Int("ticks_per_second", DoomConfig.values.ticksPerSecond);
	logResult := Doom.log.Log(Logging.LevelInfo, "window started", startupFields);
	Kernel.SetTimer(timer, 0);
	firstFrame := TRUE;
	LOOP
		mouse.Poll;
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
		controls.Extra(dx, dy, slot, cycle, reloading, aiming);
		game.Aim(aiming);
		game.Look(dx, dy);
		game.SelectWeapon(slot, cycle);
		IF reloading THEN
			game.Reload
		END;
		IF activate THEN
			game.Use
		END;
		IF ticks > 0 THEN
			ASSERT(simulation.Advance(ticks))
		END;
		IF (ticks > 0) OR firstFrame THEN
			game.Render(frame);
			IF ~presenter.Present(frame) THEN
				logResult := Doom.log.Error("display is smaller than the configured frame");
				context.result := Commands.CommandError;
				EXIT
			END;
			firstFrame := FALSE
		END;
		Objects.Sleep(DoomConfig.values.sleepMillis)
	END;
	Inputs.keyboard.Unregister(keyboard);
	Inputs.mouse.Unregister(mouse);
	mouse.Close;
	simulation.Close;
	stopFields[0] := Logging.Int("ticks", game.Ticks());
	stopFields[1] := Logging.Int("result", context.result);
	logResult := Doom.log.Log(Logging.LevelInfo, "window stopped", stopFields)
END Do;

END DoomWindow.
