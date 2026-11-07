MODULE DoomFloorVariantsSmoke;

IMPORT Doom, DoomConfig, DoomMap, DoomWad, GameGeometry, GameMaterials, Strings, KernelLog;

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

PROCEDURE Trigger(VAR map: DoomMap.Map; walk: BOOLEAN);
BEGIN
	IF walk THEN
		map.floors.Crossed(-0.5, 0, 0.5, 0);
		map.floors.ApplyCrossings(map.world)
	ELSE
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle))
	END
END Trigger;

PROCEDURE Variant(special, initial, target, speed: SIGNED32; walk, repeat: BOOLEAN);
VAR map: DoomMap.Map;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
	old: GameGeometry.World;
	sector, line, distance, ticks: SIGNED32;
BEGIN
	COPY("floor-", path);
	Strings.IntToStr(special, number);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map);
	sector := 1;
	line := 7;
	IF walk THEN
		sector := 2;
		line := 8
	END;
	old := map.world;
	ASSERT(old.Region(sector).floor = initial / 64.0);
	Trigger(map, walk);
	ASSERT(~map.actions.Claim(sector));
	IF repeat THEN
		ASSERT(map.actions.Special(line) = special)
	ELSE
		ASSERT(map.actions.Special(line) = 0)
	END;
	IF ~walk THEN
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle))
	END;
	Advance(map, 1);
	IF target > initial THEN
		ASSERT(map.world.Region(sector).floor = (initial + speed) / 64.0)
	ELSE
		ASSERT(map.world.Region(sector).floor = MAX(target, initial - speed) / 64.0)
	END;
	distance := ABS(target - initial);
	ticks := (distance + speed - 1) DIV speed;
	Advance(map, ticks - 1);
	ASSERT(map.world.Region(sector).floor = target / 64.0);
	ASSERT(old.Region(sector).floor = initial / 64.0);
	ASSERT(map.world.Region(sector).ceiling = old.Region(sector).ceiling);
	ASSERT(map.world.Region(sector).floorTexture = old.Region(sector).floorTexture);
	ASSERT(map.actions.Claim(sector));
	map.actions.Release(sector);
	Advance(map, 5);
	ASSERT(map.world.Region(sector).floor = target / 64.0)
END Variant;

PROCEDURE {TEST} Actions*;
BEGIN
	Variant(36, 96, 8, 4, TRUE, FALSE);
	Variant(70, 96, 72, 4, FALSE, TRUE);
	Variant(71, 96, 72, 4, FALSE, FALSE);
	Variant(98, 96, 8, 4, TRUE, TRUE);
	Variant(58, 96, 120, 1, TRUE, FALSE);
	Variant(92, 96, 120, 1, TRUE, TRUE);
	Variant(140, 96, 608, 1, FALSE, FALSE);
	Variant(129, -24, 0, 4, TRUE, TRUE);
	Variant(130, -24, 0, 4, TRUE, FALSE);
	Variant(131, 0, 64, 4, FALSE, FALSE);
	Variant(132, 0, 64, 4, FALSE, TRUE)
END Actions;

PROCEDURE LimitFloor(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor <= 192.0 / 64
END LimitFloor;

PROCEDURE {TEST} LimitsAndRepeat*;
VAR map: DoomMap.Map;
	i: SIGNED32;
	feet: FLOAT64;
BEGIN
	Load("floor-turbo-equal.wad", map);
	Trigger(map, FALSE);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 96.0 / 64);
	ASSERT(map.actions.Claim(1));
	Load("floor-turbo-close.wad", map);
	Trigger(map, FALSE);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 96.0 / 64);
	Load("floor-turbo-above.wad", map);
	Trigger(map, FALSE);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 96.0 / 64);
	Load("floor-fast-no-higher.wad", map);
	Trigger(map, FALSE);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 1);
	ASSERT(map.actions.Claim(1));
	Load("floor-132.wad", map);
	Trigger(map, FALSE);
	Advance(map, 16);
	Trigger(map, FALSE);
	Advance(map, 240);
	ASSERT(map.world.Region(1).floor = 1);
	Load("floor-92.wad", map);
	FOR i := 1 TO 2 DO
		Trigger(map, TRUE);
		Advance(map, 24)
	END;
	ASSERT(map.world.Region(2).floor = 144.0 / 64);
	Load("floor-step-blocked.wad", map);
	Trigger(map, TRUE);
	feet := 0;
	FOR i := 1 TO 40 DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor)
	END;
	ASSERT(map.world.Region(2).floor = 192.0 / 64);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 8);
	ASSERT(map.world.Region(2).floor = 200.0 / 64);
	ASSERT(map.actions.Claim(2))
END LimitsAndRepeat;

PROCEDURE {TEST} CustomSettings*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Variant(70, 96, 68, 8, FALSE, TRUE);
	Variant(58, 96, 112, 2, TRUE, FALSE);
	Variant(140, 96, 352, 2, FALSE, FALSE);
	Variant(131, 0, 64, 8, FALSE, FALSE);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSettings;

PROCEDURE {TEST} SwitchMaterials*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	wall: GameGeometry.Wall;
	texture: GameMaterials.Texture;
	distance: FLOAT64;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
	special: SIGNED32;
BEGIN
	FOR special := 70 TO 140 DO
		IF (special = 70) OR (special = 71) OR (special = 131) OR (special = 132) OR (special = 140) THEN
			COPY("switch-", path);
			Strings.IntToStr(special, number);
			Strings.Append(path, number);
			Strings.Append(path, ".wad");
			Load(path, map);
			old := map.world;
			ASSERT(old.CastSector(0, -3.5, 0, -1, 0, 0, distance, wall));
			texture := wall.texture;
			Trigger(map, FALSE);
			map.actions.Step(map.world);
			ASSERT(map.world.CastSector(0, -3.5, 0, -1, 0, 0, distance, wall));
			ASSERT(wall.texture # texture);
			Advance(map, 1);
			ASSERT(map.world.CastSector(0, -3.5, 0, -1, 0, 0, distance, wall));
			ASSERT(wall.texture # texture)
		END
	END
END SwitchMaterials;

PROCEDURE {TEST} ChangedSurfaceThenRaise*;
VAR map: DoomMap.Map;
	old, lowered: GameGeometry.World;
BEGIN
	Load("floor-change-raise.wad", map);
	old := map.world;
	Trigger(map, TRUE);
	Advance(map, 96);
	lowered := map.world;
	ASSERT(lowered.Region(1).floor = 0);
	ASSERT(lowered.Region(1).floorTexture = old.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 5);
	ASSERT(map.floors.Use(map.world, -3.625, 0, 3.141592653589793));
	Advance(map, 512);
	ASSERT(map.world.Region(1).floor = 8);
	ASSERT(map.world.Region(1).floorTexture = lowered.Region(1).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 5);
	ASSERT(lowered.Region(1).floor = 0);
	ASSERT(old.Region(1).floor = 1.5)
END ChangedSurfaceThenRaise;

PROCEDURE {TEST} AcceptedMovementAndRiding*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-step-game.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	game.Controls(0, 0, 0);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 11 TO 40 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 24.0 / 64);
	ASSERT(game.State().eye = 24.0 / 64 + DoomConfig.values.playerEye);
	ASSERT(old.Region(1).floor = 0);
	ASSERT(game.Load("floor-step-game-blocked.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 41 TO 80 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(1).floor = 1.5)
END AcceptedMovementAndRiding;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Actions;
	LimitsAndRepeat;
	CustomSettings;
	SwitchMaterials;
	ChangedSurfaceThenRaise;
	AcceptedMovementAndRiding;
	KernelLog.String("DoomFloorVariantsSmoke: fixed raises and turbo floors passed.");
	KernelLog.Ln
END Do;

END DoomFloorVariantsSmoke.
