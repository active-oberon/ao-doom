MODULE DoomTaggedDoorsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomInventory, DoomCombat, GameGeometry, GameSurface, GameRenderer, KernelLog, MathL, Strings;

PROCEDURE {TEST} RemoteUse*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	region: GameGeometry.Sector;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	NEW(game);
	ASSERT(game.Load("tagged-door-use.wad", "E1M1", error));
	old := game.world;
	game.Use;
	FOR i := 1 TO 62 DO
		game.Step(i)
	END;
	region := game.world.Region(1);
	ASSERT(region.ceiling = 124.0 / 64);
	region := old.Region(1);
	ASSERT(region.ceiling = 0);
	ASSERT(game.Load("tagged-door-gui.wad", "E1M1", error));
	game.Use;
	FOR i := 63 TO 124 DO
		game.Step(i)
	END;
	game.Controls(1, 0, 0);
	FOR i := 125 TO 204 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 4)
END RemoteUse;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE VariantMap(special: SIGNED32; VAR map: DoomMap.Map);
VAR number: ARRAY 12 OF CHAR;
	path: ARRAY 64 OF CHAR;
BEGIN
	Strings.IntToStr(special, number);
	COPY("tagged-door-", path);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map)
END VariantMap;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32; x: FLOAT64);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO ticks DO
		map.doors.Step(map.world, x, 0, DoomConfig.values.playerRadius, 0,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END
END Advance;

PROCEDURE SwitchVariant(special, units: SIGNED32; close, raise, repeat: BOOLEAN; key: SIGNED32);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	old: GameGeometry.World;
	ticks, form: SIGNED32;
BEGIN
	FOR form := 0 TO 1 DO
		VariantMap(special, map);
		DoomInventory.Reset(player);
		old := map.world;
		IF key >= 0 THEN
			ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
			ASSERT(player.neededKey = key);
			player.keys := {0..5} - {key, key + DoomInventory.KeyColors};
			ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
			INCL(player.keys, key + form * DoomInventory.KeyColors)
		END;
		ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
		ASSERT(player.neededKey = -1);
		ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
		Advance(map, 1, map.x);
		IF close THEN
			ASSERT(map.world.Region(1).ceiling = (128.0 - units) / 64);
			ASSERT(old.Region(1).ceiling = 2);
			ticks := 128 DIV units
		ELSE
			ASSERT(map.world.Region(1).ceiling = units / 64.0);
			ASSERT(old.Region(1).ceiling = 0);
			ticks := (124 + units - 1) DIV units
		END;
		Advance(map, ticks - 1, map.x);
		IF close THEN
			ASSERT(map.world.Region(1).ceiling = 0)
		ELSE
			ASSERT(map.world.Region(1).ceiling = 124.0 / 64);
			Advance(map, DoomConfig.values.doorWait, map.x);
			ASSERT(map.world.Region(1).ceiling = 124.0 / 64);
			Advance(map, ticks, map.x);
			IF raise THEN
				ASSERT(map.world.Region(1).ceiling = 0)
			ELSE
				ASSERT(map.world.Region(1).ceiling = 124.0 / 64)
			END
		END;
		ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player) = repeat);
		IF key >= 0 THEN
			ASSERT((key + form * DoomInventory.KeyColors) IN player.keys)
		END
	END
END SwitchVariant;

PROCEDURE {TEST} SwitchVariants*;
BEGIN
	SwitchVariant(29, 2, FALSE, TRUE, FALSE, -1);
	SwitchVariant(42, 2, TRUE, FALSE, TRUE, -1);
	SwitchVariant(50, 2, TRUE, FALSE, FALSE, -1);
	SwitchVariant(61, 2, FALSE, FALSE, TRUE, -1);
	SwitchVariant(63, 2, FALSE, TRUE, TRUE, -1);
	SwitchVariant(103, 2, FALSE, FALSE, FALSE, -1);
	SwitchVariant(111, 8, FALSE, TRUE, FALSE, -1);
	SwitchVariant(112, 8, FALSE, FALSE, FALSE, -1);
	SwitchVariant(113, 8, TRUE, FALSE, FALSE, -1);
	SwitchVariant(114, 8, FALSE, TRUE, TRUE, -1);
	SwitchVariant(115, 8, FALSE, FALSE, TRUE, -1);
	SwitchVariant(116, 8, TRUE, FALSE, TRUE, -1);
	SwitchVariant(99, 8, FALSE, FALSE, TRUE, DoomInventory.BlueCard);
	SwitchVariant(133, 8, FALSE, FALSE, FALSE, DoomInventory.BlueCard);
	SwitchVariant(134, 8, FALSE, FALSE, TRUE, DoomInventory.RedCard);
	SwitchVariant(135, 8, FALSE, FALSE, FALSE, DoomInventory.RedCard);
	SwitchVariant(136, 8, FALSE, FALSE, TRUE, DoomInventory.YellowCard);
	SwitchVariant(137, 8, FALSE, FALSE, FALSE, DoomInventory.YellowCard)
END SwitchVariants;

PROCEDURE WalkVariant(special, units: SIGNED32; close, reopen, raise, repeat: BOOLEAN);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	ticks: SIGNED32;
BEGIN
	VariantMap(special, map);
	DoomInventory.Reset(player);
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	map.doors.Crossed(-0.5, 5, 0.5, 5);
	map.doors.Crossed(-0.5, 0, -0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 1, map.x);
	IF close THEN
		ASSERT(map.world.Region(2).ceiling = 2)
	ELSE
		ASSERT(map.world.Region(2).ceiling = 0)
	END;
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 1, map.x);
	IF close THEN
		ASSERT(map.world.Region(2).ceiling = (128.0 - units) / 64);
		ticks := 128 DIV units
	ELSE
		ASSERT(map.world.Region(2).ceiling = units / 64.0);
		ticks := (124 + units - 1) DIV units
	END;
	map.doors.Crossed(0.5, 0, -0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, ticks - 1, map.x);
	IF close THEN
		ASSERT(map.world.Region(2).ceiling = 0);
		IF reopen THEN
			Advance(map, DoomConfig.values.doorCloseWait, map.x);
			ASSERT(map.world.Region(2).ceiling = 0);
			Advance(map, ticks, map.x);
			ASSERT(map.world.Region(2).ceiling = 2)
		END
	ELSE
		ASSERT(map.world.Region(2).ceiling = 124.0 / 64);
		IF raise THEN
			Advance(map, DoomConfig.values.doorWait + ticks, map.x);
			ASSERT(map.world.Region(2).ceiling = 0);
			map.doors.Crossed(0.5, 0, -0.5, 0);
			map.doors.ApplyCrossings(map.world);
			Advance(map, 1, map.x);
			IF repeat THEN
				ASSERT(map.world.Region(2).ceiling = units / 64.0)
			ELSE
				ASSERT(map.world.Region(2).ceiling = 0)
			END
		END
	END
END WalkVariant;

PROCEDURE {TEST} WalkVariants*;
BEGIN
	WalkVariant(2, 2, FALSE, FALSE, FALSE, FALSE);
	WalkVariant(3, 2, TRUE, FALSE, FALSE, FALSE);
	WalkVariant(4, 2, FALSE, FALSE, TRUE, FALSE);
	WalkVariant(16, 2, TRUE, TRUE, FALSE, FALSE);
	WalkVariant(75, 2, TRUE, FALSE, FALSE, TRUE);
	WalkVariant(76, 2, TRUE, TRUE, FALSE, TRUE);
	WalkVariant(86, 2, FALSE, FALSE, FALSE, TRUE);
	WalkVariant(90, 2, FALSE, FALSE, TRUE, TRUE);
	WalkVariant(105, 8, FALSE, FALSE, TRUE, TRUE);
	WalkVariant(106, 8, FALSE, FALSE, FALSE, TRUE);
	WalkVariant(107, 8, TRUE, FALSE, FALSE, TRUE);
	WalkVariant(108, 8, FALSE, FALSE, TRUE, FALSE);
	WalkVariant(109, 8, FALSE, FALSE, FALSE, FALSE);
	WalkVariant(110, 8, TRUE, FALSE, FALSE, FALSE)
END WalkVariants;

PROCEDURE {TEST} GroupAndBounds*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	old: GameGeometry.World;
BEGIN
	DoomInventory.Reset(player);
	Load("tagged-door-use.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x + 1, 0, map.angle, player));
	ASSERT(~map.doors.Use(map.world, -4.5, 0, 0, player));
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Load("tagged-door-no-tag.wad", map);
	old := map.world;
	ASSERT(~map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 100, map.x);
	ASSERT(map.world = old);
	Load("tagged-door-occluded.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, 0, map.angle, player));
	Load("tagged-door-multi.wad", map);
	old := map.world;
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 62, map.x);
	ASSERT((map.world.Region(1).ceiling = 124.0 / 64) & (map.world.Region(3).ceiling = 124.0 / 64));
	ASSERT((old.Region(1).ceiling = 0) & (old.Region(3).ceiling = 0));
	ASSERT((map.world.Region(0).ceiling = 2) & (map.world.Region(2).ceiling = 2) & (map.world.Region(4).ceiling = 2));
	ASSERT(~map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 150 + 62, map.x);
	ASSERT((map.world.Region(1).ceiling = 0) & (map.world.Region(3).ceiling = 0));
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Load("tagged-door-multi.wad", map);
	ASSERT(map.doors.Use(map.world, -0.5, 0, 0, player));
	Advance(map, 1, map.x);
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 1, map.x);
	ASSERT((map.world.Region(1).ceiling = 4.0 / 64) & (map.world.Region(3).ceiling = 2.0 / 64));
	Load("tagged-door-busy.wad", map);
	ASSERT(map.doors.Use(map.world, -0.5, 0, 0, player));
	ASSERT(~map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 62 + 150 + 62, map.x);
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player))
END GroupAndBounds;

PROCEDURE {TEST} AcceptedCrossings*;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("tagged-door-90.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 7 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	ASSERT(game.world.Region(2).ceiling > 0);
	ASSERT(game.Load("tagged-door-blocked-crossing.wad", "E1M1", error));
	FOR i := 8 TO 30 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(2).ceiling = 0)
END AcceptedCrossings;

PROCEDURE {TEST} ClosingObstruction*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
BEGIN
	DoomInventory.Reset(player);
	VariantMap(42, map);
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 37, 2);
	ASSERT(map.world.Region(1).ceiling = DoomConfig.values.playerHeight);
	Advance(map, 10, 2);
	ASSERT(map.world.Region(1).ceiling = DoomConfig.values.playerHeight);
	Advance(map, 28, map.x);
	ASSERT(map.world.Region(1).ceiling = 0);
	VariantMap(63, map);
	ASSERT(map.doors.Use(map.world, map.x, 0, map.angle, player));
	Advance(map, 62, map.x);
	Advance(map, 150 + 35, 2);
	ASSERT(map.world.Region(1).ceiling = DoomConfig.values.playerHeight);
	Advance(map, 1, 2);
	ASSERT(map.world.Region(1).ceiling > DoomConfig.values.playerHeight);
	VariantMap(76, map);
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 37, 6);
	ASSERT(map.world.Region(2).ceiling = DoomConfig.values.playerHeight);
	Advance(map, 1, 6);
	ASSERT(map.world.Region(2).ceiling > DoomConfig.values.playerHeight)
END ClosingObstruction;

PROCEDURE {TEST} ShotClipping*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	game: Doom.Game;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	VariantMap(46, map);
	DoomInventory.Reset(player);
	DoomCombat.Reset(weapon, player);
	ASSERT(~map.doors.Use(map.world, map.x, 0, map.angle, player));
	map.sprites := DoomCombat.StepAimObserved(1, FALSE, weapon, map.world, map.sprites, map.x, 0, map.angle,
		map.eye, 0, player, map.doors.Shot);
	Advance(map, 1, map.x);
	ASSERT(map.world.Region(1).ceiling = 0);
	map.sprites := DoomCombat.StepAimObserved(2, TRUE, weapon, map.world, map.sprites, map.x, 0, map.angle,
		map.eye, 0, player, map.doors.Shot);
	Advance(map, 62, map.x);
	ASSERT(map.world.Region(1).ceiling = 124.0 / 64);
	ASSERT(player.ammo[DoomInventory.Bullets] = DoomConfig.values.inventory.initialBullets - 1);
	Load("tagged-door-gun-occluded.wad", map);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, 0, map.angle, map.eye, 0, 10, 1, map.doors.Shot);
	Advance(map, 1, map.x);
	ASSERT(map.world.Region(1).ceiling = 0);
	Load("tagged-door-gun-actor.wad", map);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, 0, map.angle, map.eye, 0, 10, 1, map.doors.Shot);
	Advance(map, 1, map.x);
	ASSERT(map.world.Region(1).ceiling = 0);
	VariantMap(46, map);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, 0, map.angle, map.eye, 0, 0.25, 1, map.doors.Shot);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, 0, map.angle, map.eye, 10, 10, 1, map.doors.Shot);
	Advance(map, 1, map.x);
	ASSERT(map.world.Region(1).ceiling = 0);
	Load("tagged-door-gun-portal.wad", map);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, 0, map.angle, map.eye, 0, 10, 1, map.doors.Shot);
	Advance(map, 62, map.x);
	ASSERT(map.world.Region(2).ceiling = 124.0 / 64);
	NEW(game);
	ASSERT(game.Load("tagged-door-gun-projectile.wad", "E1M1", error));
	game.Step(1);
	game.SelectWeapon(5, 0);
	ASSERT(game.Weapon().selected = DoomInventory.Launcher);
	game.Fire(TRUE);
	FOR i := 2 TO 20 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 0);
	ASSERT(game.Load("tagged-door-46.wad", "E1M1", error));
	game.Fire(TRUE);
	FOR i := 21 TO 84 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 124.0 / 64)
END ShotClipping;

PROCEDURE {TEST} ResourcesAndProfile*;
VAR map: DoomMap.Map;
	game: Doom.Game;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	error: ARRAY 256 OF CHAR;
	distance: FLOAT64;
	wall: GameGeometry.Wall;
	i: SIGNED32;
BEGIN
	Load("tagged-door-hidden.wad", map);
	ASSERT(map.world.CastSector(0, -0.5, 0, 1, 0, 0, distance, wall));
	ASSERT(wall.upper # NIL);
	NEW(game);
	NEW(frame, 320, 200);
	ASSERT(game.Load("tagged-door-use.wad", "E1M1", error));
	old := game.world;
	game.Use;
	ASSERT(~game.Load("tagged-door-missing-texture.wad", "E1M1", error));
	ASSERT(game.world = old);
	FOR i := 1 TO 62 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 124.0 / 64);
	game.Render(frame);
	ASSERT(frame.Save("tagged-door-open.ppm"));
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	VariantMap(76, map);
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 32, map.x);
	ASSERT(map.world.Region(2).ceiling = 0);
	Advance(map, 7, map.x);
	ASSERT(map.world.Region(2).ceiling = 0);
	Advance(map, 1, map.x);
	ASSERT(map.world.Region(2).ceiling = 4.0 / 64);
	Advance(map, 31, map.x);
	ASSERT(map.world.Region(2).ceiling = 2);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END ResourcesAndProfile;

PROCEDURE Do*;
BEGIN
	RemoteUse;
	SwitchVariants;
	WalkVariants;
	GroupAndBounds;
	AcceptedCrossings;
	ClosingObstruction;
	ShotClipping;
	ResourcesAndProfile;
	KernelLog.String("DoomTaggedDoorsSmoke: tagged door checks passed.");
	KernelLog.Ln
END Do;

END DoomTaggedDoorsSmoke.
