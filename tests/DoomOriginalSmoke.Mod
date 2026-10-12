MODULE DoomOriginalSmoke;

IMPORT DoomConfig, DoomCombat, DoomInventory, Doom, GameSurface, KernelLog, Unix, Commands;

PROCEDURE Visible(frame: GameSurface.Frame): BOOLEAN;
VAR x, y, color: SIGNED32;
BEGIN
	FOR y := 0 TO frame.height - DoomConfig.values.hud.height - DoomConfig.values.hud.margin - 6 DO
		FOR x := 0 TO frame.width - 1 DO
			color := frame.Pixel(x, y);
			IF ((ABS(x - frame.width DIV 2) > DoomConfig.values.combat.aimRadius) OR
				(ABS(y - frame.height DIV 2) > DoomConfig.values.combat.aimRadius)) &
				(color # 0202938H) & (color # 035302CH) THEN
				RETURN TRUE
			END
		END
	END;
	RETURN FALSE
END Visible;

PROCEDURE {TEST} SceneVisibility*;
VAR frame: GameSurface.Frame;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
BEGIN
	NEW(frame, 320, 200);
	frame.Background(0202938H, 035302CH);
	DoomCombat.DrawAim(frame, FALSE);
	ASSERT(~Visible(frame));
	DoomInventory.Reset(player);
	DoomCombat.Reset(weapon, player);
	DoomCombat.DrawStatus(weapon, player, frame);
	ASSERT(~Visible(frame));
	frame.Span(0, 0, 0, 0FFFFFFH);
	ASSERT(Visible(frame))
END SceneVisibility;

PROCEDURE Do*(context: Commands.Context);
VAR game: Doom.Game;
	frame: GameSurface.Frame;
	pose: Doom.Pose;
	path: ARRAY 512 OF CHAR;
	marker: ARRAY 9 OF CHAR;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
	floor: FLOAT64;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	SceneVisibility;
	IF Unix.argc < 3 THEN
		KernelLog.String("Usage: original-check WAD MAP");
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	Unix.GetArg(1, path);
	Unix.GetArg(2, marker);
	NEW(game);
	IF ~game.Load(path, marker, error) THEN
		KernelLog.String(marker);
		KernelLog.String(": ");
		KernelLog.String(error);
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(Visible(frame));
	ASSERT(frame.Save("original-start.ppm"));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 35 DO
		game.Step(i)
	END;
	game.Render(frame);
	ASSERT(Visible(frame));
	ASSERT(frame.Save("original-walk.ppm"));
	game.Controls(0, 0, 1);
	game.Fire(TRUE);
	FOR i := 36 TO 132 DO
		game.Step(i);
		IF i MOD 12 = 0 THEN
			game.Render(frame)
		END
	END;
	game.Fire(FALSE);
	pose := game.State();
	ASSERT(game.world.Locate(pose.x, pose.y) >= 0);
	ASSERT(game.world.Stand(pose.x, pose.y, DoomConfig.values.playerRadius, pose.eye - DoomConfig.values.playerEye,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor));
	ASSERT(ABS(floor - pose.eye + DoomConfig.values.playerEye) < 0.000001);
	KernelLog.String(marker);
	KernelLog.String(": loaded, rendered, walked, turned and fired");
	KernelLog.Ln
END Do;

END DoomOriginalSmoke.
