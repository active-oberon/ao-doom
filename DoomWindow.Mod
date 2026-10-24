MODULE DoomWindow;

IMPORT DoomConfig, DoomFormat, DoomInput, DoomMouse, Doom, DoomInventory, DoomCombat, GameLoop, GameSurface, GameDisplay, GameClock,
	Inputs, Objects, Kernel, Logging, Unix, Commands;

TYPE
	Keyboard = OBJECT (Inputs.Sink)
	VAR controls: DoomInput.Controller;
		focusKnown, focused: BOOLEAN;

		PROCEDURE &Init(input: DoomInput.Controller);
		BEGIN
			controls := input
		END Init;

		PROCEDURE Handle*(VAR message: Inputs.Message);
		VAR fields: ARRAY 1 OF Logging.Attr;
			result: SIGNED32;
		BEGIN
			IF message IS Inputs.FocusMsg THEN
				WITH message: Inputs.FocusMsg DO
					controls.Focus(message.focused);
					IF ~focusKnown OR (focused # message.focused) THEN
						focusKnown := TRUE;
						focused := message.focused;
						fields[0] := Logging.Bool("focused", focused);
						result := Doom.log.Log(Logging.LevelInfo, "input focus changed", fields)
					END
				END
			ELSIF message IS Inputs.KeyboardMsg THEN
				WITH message: Inputs.KeyboardMsg DO
					controls.Key(message.keysym, Inputs.Release IN message.flags)
				END
			END
		END Handle;
	END Keyboard;

(* LogState reports changes between window observations without writing from simulation or rendering. *)
PROCEDURE LogState(game: Doom.Game; CONST before: DoomInventory.State; CONST previous: DoomCombat.Weapon);
VAR after: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	fields: ARRAY 11 OF Logging.Attr;
	map: ARRAY 9 OF CHAR;
	i, result: SIGNED32;
	ammunition: BOOLEAN;
BEGIN
	after := game.Inventory();
	weapon := game.Weapon();
	ammunition := (previous.selected = weapon.selected) &
		(previous.loaded[previous.selected] # weapon.loaded[weapon.selected]);
	FOR i := 0 TO DoomInventory.AmmoKinds - 1 DO
		ammunition := ammunition OR (before.ammo[i] # after.ammo[i])
	END;
	IF (before.pickups = after.pickups) & (before.health = after.health) &
		(before.armor = after.armor) & (previous.selected = weapon.selected) &
		(previous.reloadUntil = weapon.reloadUntil) & ~ammunition THEN
		RETURN
	END;
	game.MapName(map);
	fields[0] := Logging.String("map", map);
	fields[1] := Logging.Int("tick", game.Ticks());
	fields[2] := Logging.Int("health", after.health);
	fields[3] := Logging.Int("armor", after.armor);
	fields[4] := Logging.Int("weapon", weapon.selected);
	fields[5] := Logging.Int("loaded", weapon.loaded[weapon.selected]);
	fields[6] := Logging.Int("bullets", after.ammo[DoomInventory.Bullets]);
	fields[7] := Logging.Int("shells", after.ammo[DoomInventory.Shells]);
	fields[8] := Logging.Int("cells", after.ammo[DoomInventory.Cells]);
	fields[9] := Logging.Int("rockets", after.ammo[DoomInventory.Rockets]);
	fields[10] := Logging.Int("pickups", after.pickups);
	IF after.pickups > before.pickups THEN
		result := Doom.log.Log(Logging.LevelInfo, "items collected", fields)
	END;
	IF (after.health < before.health) OR (after.armor < before.armor) THEN
		result := Doom.log.Log(Logging.LevelInfo, "player hurt", fields);
		IF (before.health > 0) & (after.health = 0) THEN
			result := Doom.log.Log(Logging.LevelInfo, "player died", fields)
		END
	END;
	IF previous.selected # weapon.selected THEN
		result := Doom.log.Log(Logging.LevelInfo, "weapon selected", fields)
	ELSIF (previous.reloadUntil = 0) & (weapon.reloadUntil > 0) THEN
		result := Doom.log.Log(Logging.LevelInfo, "weapon reload started", fields)
	ELSIF (previous.reloadUntil > 0) & (weapon.reloadUntil = 0) THEN
		result := Doom.log.Log(Logging.LevelInfo, "weapon reload finished", fields)
	END;
	IF ammunition THEN
		result := Doom.log.Log(Logging.LevelInfo, "weapon ammunition changed", fields)
	END
END LogState;

(* LogInteraction includes rejected and targetless use attempts so silent controls can be diagnosed. *)
PROCEDURE LogInteraction(event: Doom.Interaction);
VAR fields: ARRAY 6 OF Logging.Attr;
	result: SIGNED32;
BEGIN
	IF event = NIL THEN
		RETURN
	END;
	fields[0] := Logging.String("map", event.map);
	fields[1] := Logging.Int("tick", event.tick);
	fields[2] := Logging.Int("line", event.line);
	fields[3] := Logging.Int("special", event.special);
	fields[4] := Logging.Int("needed_key", event.neededKey);
	fields[5] := Logging.Bool("accepted", event.accepted);
	result := Doom.log.Log(Logging.LevelInfo, "map use attempted", fields)
END LogInteraction;

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
	configFields: ARRAY 4 OF Logging.Attr;
	errorFields: ARRAY 2 OF Logging.Attr;
	mapFields, startupFields: ARRAY 3 OF Logging.Attr;
	loadedFields: ARRAY 6 OF Logging.Attr;
	stopFields: ARRAY 2 OF Logging.Attr;
	transitionFields: ARRAY 5 OF Logging.Attr;
	transition: Doom.Transition;
	transitionMessage: ARRAY 32 OF CHAR;
	transitionLevel: SIGNED32;
	before: DoomInventory.State;
	previous: DoomCombat.Weapon;
	pose: Doom.Pose;
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
	configFields[1] := Logging.Int("width", DoomConfig.values.width);
	configFields[2] := Logging.Int("height", DoomConfig.values.height);
	configFields[3] := Logging.Int("ticks_per_second", DoomConfig.values.ticksPerSecond);
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
		pose := game.State();
		loadedFields[0] := Logging.String("path", path);
		loadedFields[1] := Logging.String("map", map);
		loadedFields[2] := Logging.Int("sectors", game.world.SectorCount());
		loadedFields[3] := Logging.Int("walls", game.world.Count());
		loadedFields[4] := Logging.Int("spawn_x", ENTIER(pose.x * DoomFormat.UnitsPerWorld));
		loadedFields[5] := Logging.Int("spawn_y", ENTIER(pose.y * DoomFormat.UnitsPerWorld));
		logResult := Doom.log.Log(Logging.LevelInfo, "map loaded", loadedFields)
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
		before := game.Inventory();
		previous := game.Weapon();
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
		transition := game.TakeTransition();
		IF transition # NIL THEN
			transitionFields[0] := Logging.String("previous", transition.previous);
			transitionFields[1] := Logging.String("target", transition.target);
			transitionFields[2] := Logging.Int("kind", transition.kind);
			transitionFields[3] := Logging.Int("line", transition.line);
			transitionFields[4] := Logging.String("error", transition.error);
			transitionLevel := Logging.LevelInfo;
			IF transition.result = Doom.LevelChanged THEN
				COPY("level transitioned", transitionMessage)
			ELSIF transition.result = Doom.CampaignComplete THEN
				COPY("campaign completed", transitionMessage)
			ELSE
				COPY("level transition failed", transitionMessage);
				transitionLevel := Logging.LevelError
			END;
			logResult := Doom.log.Log(transitionLevel, transitionMessage, transitionFields)
		END;
		LogInteraction(game.TakeInteraction());
		IF (transition = NIL) & ((ticks > 0) OR (slot # 0) OR (cycle # 0)) THEN
			LogState(game, before, previous)
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
