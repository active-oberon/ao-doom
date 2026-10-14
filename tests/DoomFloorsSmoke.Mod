MODULE DoomFloorsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomInventory, DoomSprites, GameGeometry, GameSurface, Strings, KernelLog;

PROCEDURE {TEST} LiftUse*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	NEW(game);
	ASSERT(game.Load("floor-lift.wad", "E1M1", error));
	old := game.world;
	game.Use;
	FOR i := 1 TO 24 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0);
	ASSERT(old.Region(1).floor = 96.0 / 64)
END LiftUse;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32; VAR feet: FLOAT64);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO ticks DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END
END Advance;

PROCEDURE Variant(special, initial, target, sector, units: SIGNED32; walk, gun, lift, repeat: BOOLEAN);
VAR map: DoomMap.Map;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
	old: GameGeometry.World;
	feet: FLOAT64;
	ticks: SIGNED32;
BEGIN
	COPY("floor-", path);
	Strings.IntToStr(special, number);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map);
	old := map.world;
	feet := 0;
	ASSERT(map.world.Region(sector).floor = initial / 64.0);
	IF walk THEN
		map.floors.Crossed(-0.5, 5, 0.5, 5);
		map.floors.ApplyCrossings(map.world);
		Advance(map, 1, feet);
		ASSERT(map.world = old);
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
		map.floors.Crossed(-0.5, 0, 0.5, 0);
		map.floors.ApplyCrossings(map.world)
	ELSIF gun THEN
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
		map.sprites := map.sprites.ShootAimObserved(map.world, map.x, map.y, map.angle, map.eye, 0,
			8, 1, map.floors.Shot)
	ELSE
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle))
	END;
	IF repeat THEN
		IF walk THEN
			ASSERT(map.actions.Special(8) = special)
		ELSE
			ASSERT(map.actions.Special(7) = special)
		END
	ELSE
		IF walk THEN
			ASSERT(map.actions.Special(8) = 0)
		ELSE
			ASSERT(map.actions.Special(7) = 0)
		END
	END;
	ticks := ABS(target - initial) DIV units;
	Advance(map, ticks, feet);
	ASSERT(map.world.Region(sector).floor = target / 64.0);
	ASSERT(old.Region(sector).floor = initial / 64.0);
	IF lift THEN
		Advance(map, DoomConfig.values.platformWait, feet);
		ASSERT(map.world.Region(sector).floor = target / 64.0);
		Advance(map, ticks, feet);
		ASSERT(map.world.Region(sector).floor = initial / 64.0);
		IF ~walk THEN
			ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle) = repeat)
		END
	END
END Variant;

PROCEDURE {TEST} ActionVariants*;
BEGIN
	Variant(19, 96, 0, 2, 1, TRUE, FALSE, FALSE, FALSE);
	Variant(45, 96, 64, 1, 1, FALSE, FALSE, FALSE, TRUE);
	Variant(83, 96, 0, 2, 1, TRUE, FALSE, FALSE, TRUE);
	Variant(102, 96, 64, 1, 1, FALSE, FALSE, FALSE, FALSE);
	Variant(23, 96, 0, 1, 1, FALSE, FALSE, FALSE, FALSE);
	Variant(38, 96, 0, 2, 1, TRUE, FALSE, FALSE, FALSE);
	Variant(60, 96, 0, 1, 1, FALSE, FALSE, FALSE, TRUE);
	Variant(82, 96, 0, 2, 1, TRUE, FALSE, FALSE, TRUE);
	Variant(18, 0, 64, 1, 1, FALSE, FALSE, FALSE, FALSE);
	Variant(69, 0, 64, 1, 1, FALSE, FALSE, FALSE, TRUE);
	Variant(119, -24, 0, 2, 1, TRUE, FALSE, FALSE, FALSE);
	Variant(128, -24, 0, 2, 1, TRUE, FALSE, FALSE, TRUE);
	Variant(5, 96, 192, 2, 1, TRUE, FALSE, FALSE, FALSE);
	Variant(24, 96, 128, 1, 1, FALSE, TRUE, FALSE, FALSE);
	Variant(64, 96, 128, 1, 1, FALSE, FALSE, FALSE, TRUE);
	Variant(91, 96, 192, 2, 1, TRUE, FALSE, FALSE, TRUE);
	Variant(101, 96, 128, 1, 1, FALSE, FALSE, FALSE, FALSE);
	Variant(10, 96, 0, 2, 4, TRUE, FALSE, TRUE, FALSE);
	Variant(21, 96, 0, 1, 4, FALSE, FALSE, TRUE, FALSE);
	Variant(62, 96, 0, 1, 4, FALSE, FALSE, TRUE, TRUE);
	Variant(88, 96, 0, 2, 4, TRUE, FALSE, TRUE, TRUE);
	Variant(120, 96, 0, 2, 8, TRUE, FALSE, TRUE, TRUE);
	Variant(121, 96, 0, 2, 8, TRUE, FALSE, TRUE, FALSE);
	Variant(122, 96, 0, 1, 8, FALSE, FALSE, TRUE, FALSE);
	Variant(123, 96, 0, 1, 8, FALSE, FALSE, TRUE, TRUE)
END ActionVariants;

PROCEDURE {TEST} RidingAndSnapshots*;
VAR game: Doom.Game;
	map: DoomMap.Map;
	old, carried: DoomSprites.Scene;
	world: GameGeometry.World;
	heights: ARRAY 3 OF FLOAT64;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-lift-ride.wad", "E1M1", error));
	game.Use;
	FOR i := 1 TO 24 DO
		game.Step(i);
		ASSERT(game.State().eye = (96 - i * 4) / 64.0 + DoomConfig.values.playerEye)
	END;
	FOR i := 25 TO 129 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0);
	FOR i := 130 TO 153 DO
		game.Step(i)
	END;
	ASSERT(game.State().eye = 96.0 / 64 + DoomConfig.values.playerEye);
	Load("floor-riders.wad", map);
	old := map.sprites;
	heights[0] := 0;
	heights[1] := 0;
	heights[2] := 1;
	world := map.world.WithFloors(heights);
	carried := old.FollowFloors(map.world, world, 1);
	ASSERT(carried # NIL);
	ASSERT(carried # old);
	ASSERT((old.State(0).feet = 1.5) & (old.State(1).feet = 1.5));
	ASSERT((carried.State(0).feet = 0) & (carried.State(1).feet = 0));
	ASSERT(carried.State(2).feet = old.State(2).feet);
	ASSERT(carried.Health(0) = old.Health(0));
	Load("floor-actor-block.wad", map);
	heights[1] := 39.0 / 64;
	world := map.world.WithFloors(heights);
	ASSERT(map.sprites.FollowFloors(map.world, world, 1) = NIL);
	ASSERT(map.sprites.State(0).feet = 0)
END RidingAndSnapshots;

PROCEDURE {TEST} PlayerAndActorObstruction*;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-player-block.wad", "E1M1", error));
	game.Use;
	FOR i := 1 TO 40 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 24.0 / 64);
	ASSERT(game.State().eye = 24.0 / 64 + DoomConfig.values.playerEye);
	game.Controls(-1, 0, 0);
	FOR i := 41 TO 160 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 80.0 / 64);
	game.Controls(0, 0, 0);
	ASSERT(game.Load("floor-actor-block.wad", "E1M1", error));
	game.Use;
	FOR i := 161 TO 220 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 38.0 / 64);
	game.Fire(TRUE);
	FOR i := 221 TO 290 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 80.0 / 64)
END PlayerAndActorObstruction;

PROCEDURE LimitFloor(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor <= 32.0 / 64
END LimitFloor;

PROCEDURE {TEST} LiftReversal*;
VAR map: DoomMap.Map;
	feet: FLOAT64;
	i: SIGNED32;
BEGIN
	Load("floor-lift.wad", map);
	feet := 0;
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 24 + 105, feet);
	FOR i := 1 TO 9 DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor)
	END;
	ASSERT(map.world.Region(1).floor = 32.0 / 64);
	map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor);
	ASSERT(map.world.Region(1).floor = 28.0 / 64)
END LiftReversal;

PROCEDURE {TEST} SharedActionsAndBusySectors*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	feet: FLOAT64;
	i: SIGNED32;
BEGIN
	DoomInventory.Reset(player);
	feet := 0;
	Load("floor-shared-actions.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 24, feet);
	ASSERT(map.actions.Special(8) = 0);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 1 TO 94 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	ASSERT(map.world.Region(2).ceiling = 188.0 / 64);
	Load("floor-door-busy.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(~map.doors.Use(map.world, -0.5, 0, 0, player));
	Advance(map, 64, feet);
	ASSERT(map.doors.Use(map.world, -0.5, 0, 0, player));
	Load("floor-door-busy.wad", map);
	ASSERT(map.doors.Use(map.world, -0.5, 0, 0, player));
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.actions.Special(7) = 18);
	Load("floor-24.wad", map);
	ASSERT(map.actions.Claim(1));
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, map.y, map.angle, map.eye, 0,
		8, 1, map.floors.Shot);
	ASSERT(map.actions.Special(7) = 0);
	map.actions.Release(1);
	map.sprites := map.sprites.ShootAimObserved(map.world, map.x, map.y, map.angle, map.eye, 0,
		8, 1, map.floors.Shot);
	feet := 0;
	Advance(map, 10, feet);
	ASSERT(map.world.Region(1).floor = 1.5)
END SharedActionsAndBusySectors;

PROCEDURE {TEST} MovementAndFailure*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-88.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 30 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	ASSERT(game.world.Region(2).floor = 0);
	ASSERT(game.Load("floor-blocked-crossing.wad", "E1M1", error));
	FOR i := 31 TO 60 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(2).floor = 1.5);
	game.Controls(0, 0, 0);
	ASSERT(game.Load("floor-lift.wad", "E1M1", error));
	old := game.world;
	game.Use;
	ASSERT(~game.Load("floor-hidden-texture.wad", "E1M1", error));
	ASSERT(game.world = old);
	FOR i := 61 TO 84 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0);
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(frame.Save("floor-lift-bottom.ppm"));
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	ASSERT(game.Load("floor-lift.wad", "E1M1", error));
	game.Use;
	FOR i := 85 TO 108 DO
		game.Step(i)
	END;
	FOR i := 109 TO 115 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0);
	game.Step(116);
	ASSERT(game.world.Region(1).floor = 4.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END MovementAndFailure;

PROCEDURE Do*;
BEGIN
	LiftUse;
	ActionVariants;
	RidingAndSnapshots;
	PlayerAndActorObstruction;
	LiftReversal;
	SharedActionsAndBusySectors;
	MovementAndFailure;
	KernelLog.String("DoomFloorsSmoke: floor and lift checks passed.");
	KernelLog.Ln
END Do;

END DoomFloorsSmoke.
