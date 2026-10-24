MODULE DoomStairsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, GameGeometry, GameSurface, Strings, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
	feet: FLOAT64;
BEGIN
	feet := 0;
	FOR i := 1 TO ticks DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END
END Advance;

PROCEDURE Variant(special, units, ticks: SIGNED32; walk: BOOLEAN);
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
	i: SIGNED32;
BEGIN
	COPY("stairs-", path);
	Strings.IntToStr(special, number);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map);
	old := map.world;
	ASSERT(~map.floors.Moving(0));
	FOR i := 1 TO 4 DO
		ASSERT(map.floors.Moving(i))
	END;
	IF walk THEN
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
		map.floors.Crossed(-0.5, 5, 0.5, 5);
		map.floors.ApplyCrossings(map.world);
		Advance(map, 1);
		ASSERT(map.world = old);
		map.floors.Crossed(-0.5, 0, 0.5, 0);
		map.floors.ApplyCrossings(map.world);
		ASSERT(map.actions.Special(12) = 0)
	ELSE
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
		ASSERT(map.actions.Special(11) = 0)
	END;
	FOR i := 1 TO 4 DO
		ASSERT(~map.actions.Claim(i))
	END;
	Advance(map, ticks);
	ASSERT(map.world.Region(0).floor = 0);
	FOR i := 1 TO 4 DO
		ASSERT(map.world.Region(i).floor = i * units / 64.0);
		ASSERT(old.Region(i).floor = 0);
		ASSERT(map.actions.Claim(i));
		map.actions.Release(i)
	END
END Variant;

PROCEDURE {TEST} ActionVariants*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Variant(7, 8, 128, FALSE);
	Variant(8, 8, 128, TRUE);
	Variant(100, 16, 16, TRUE);
	Variant(127, 16, 16, FALSE)
END ActionVariants;

PROCEDURE {TEST} DirectionAndTexture*;
VAR map: DoomMap.Map;
	i: SIGNED32;
BEGIN
	FOR i := 0 TO 1 DO
		IF i = 0 THEN
			Load("stairs-reversed.wad", map)
		ELSE
			Load("stairs-texture.wad", map)
		END;
		ASSERT(~map.floors.Moving(2));
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
		Advance(map, 128);
		ASSERT(map.world.Region(1).floor = 8.0 / 64);
		ASSERT(map.world.Region(2).floor = 0);
		ASSERT(map.world.Region(3).floor = 0);
		ASSERT(map.world.Region(4).floor = 0)
	END
END DirectionAndTexture;

PROCEDURE {TEST} BusyAndGrouped*;
VAR map: DoomMap.Map;
BEGIN
	Load("stairs-7.wad", map);
	ASSERT(map.actions.Claim(2));
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 128);
	ASSERT(map.world.Region(1).floor = 8.0 / 64);
	ASSERT(map.world.Region(2).floor = 0);
	ASSERT(map.world.Region(3).floor = 0);
	ASSERT(~map.actions.Claim(2));
	Load("stairs-7.wad", map);
	ASSERT(map.actions.Claim(1));
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.actions.Special(11) = 7);
	map.actions.Release(1);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Load("stairs-grouped.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 256);
	ASSERT(map.world.Region(1).floor = 8.0 / 64);
	ASSERT(map.world.Region(2).floor = 16.0 / 64);
	ASSERT(map.world.Region(3).floor = 24.0 / 64);
	ASSERT(map.world.Region(4).floor = 32.0 / 64)
END BusyAndGrouped;

PROCEDURE {TEST} HiddenMaterialsAndFailedReplacement*;
VAR game: Doom.Game;
	world: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("stairs-7.wad", "E1M1", error));
	game.Use;
	game.Step(1);
	world := game.world;
	ASSERT(~game.Load("stairs-hidden-texture.wad", "E1M1", error));
	ASSERT(game.world = world);
	FOR i := 2 TO 128 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(4).floor = 32.0 / 64)
END HiddenMaterialsAndFailedReplacement;

PROCEDURE {TEST} ObstructionAndRiding*;
VAR map: DoomMap.Map;
	feet: FLOAT64;
	i: SIGNED32;
	frame: GameSurface.Frame;
	game: Doom.Game;
	error: ARRAY 256 OF CHAR;
BEGIN
	Load("stairs-obstructed.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	feet := 0;
	FOR i := 1 TO 128 DO
		map.floors.Step(map.world, 5, 0, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END;
	ASSERT(map.world.Region(1).floor = 8.0 / 64);
	ASSERT(map.world.Region(2).floor = 0);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 64);
	ASSERT(map.world.Region(2).floor = 16.0 / 64);
	ASSERT(map.actions.Claim(2));
	Load("stairs-7.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	feet := 0;
	FOR i := 1 TO 32 DO
		map.floors.Step(map.world, 2, 0, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL);
		ASSERT(feet = i * 0.25 / 64)
	END;
	NEW(game);
	ASSERT(game.Load("stairs-7.wad", "E1M1", error));
	game.Use;
	FOR i := 1 TO 128 DO
		game.Step(i)
	END;
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(frame.Save("stairs-raised.ppm"))
END ObstructionAndRiding;

PROCEDURE {TEST} CustomSettings*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Variant(7, 4, 32, FALSE);
	Variant(127, 12, 24, FALSE);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSettings;

PROCEDURE Do*;
BEGIN
	ActionVariants;
	DirectionAndTexture;
	BusyAndGrouped;
	HiddenMaterialsAndFailedReplacement;
	ObstructionAndRiding;
	CustomSettings;
	KernelLog.String("DoomStairsSmoke: actions, chains, materials, occupancy, riding and snapshots passed.");
	KernelLog.Ln
END Do;

END DoomStairsSmoke.
