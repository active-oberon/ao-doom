MODULE DoomChangingPlatformsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry, Strings;

TYPE Carrier = OBJECT
VAR scene: DoomSprites.Scene;
	PROCEDURE Follow(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
	VAR candidate: DoomSprites.Scene;
	BEGIN
		candidate := scene.FollowFloors(before, after, sector);
		IF candidate = NIL THEN
			RETURN FALSE
		END;
		scene := candidate;
		RETURN TRUE
	END Follow;
END Carrier;

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
	feet := 0.5;
	FOR i := 1 TO ticks DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END
END Advance;

PROCEDURE Cross(VAR map: DoomMap.Map; x0, x1: FLOAT64);
BEGIN
	map.floors.Crossed(x0, 0, x1, 0);
	map.floors.ApplyCrossings(map.world)
END Cross;

PROCEDURE Activate(VAR map: DoomMap.Map; special: SIGNED32);
BEGIN
	IF (special = 22) OR (special = 95) THEN
		Cross(map, -0.5, 0.5)
	ELSIF special = 47 THEN
		map.floors.Shot(map.world, 7)
	ELSE
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle))
	END
END Activate;

PROCEDURE Variant(special, target: SIGNED32; nearest, repeat: BOOLEAN);
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
	sector, line, i, code: SIGNED32;
BEGIN
	COPY("platform-change-", path);
	Strings.IntToStr(special, number);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map);
	sector := 1;
	line := 7;
	IF (special = 22) OR (special = 95) THEN
		sector := 2;
		line := 8
	END;
	old := map.world;
	code := map.floors.SectorSpecial(sector);
	Activate(map, special);
	ASSERT(map.world.Region(sector).floor = 0);
	ASSERT(map.world.Region(sector).floorTexture = old.Region(0).floorTexture);
	IF nearest THEN
		ASSERT(map.floors.SectorSpecial(sector) = 0)
	ELSE
		ASSERT(map.floors.SectorSpecial(sector) = code)
	END;
	IF repeat THEN
		ASSERT(map.actions.Special(line) = special)
	ELSE
		ASSERT(map.actions.Special(line) = 0)
	END;
	ASSERT(~map.actions.Claim(sector));
	Advance(map, 1);
	ASSERT(map.world.Region(sector).floor = 0.5 / 64);
	FOR i := 2 TO target * 2 DO
		Advance(map, 1)
	END;
	ASSERT(map.world.Region(sector).floor = target / 64.0);
	ASSERT(map.actions.Claim(sector));
	map.actions.Release(sector);
	ASSERT(old.Region(sector).floor = 0);
	ASSERT(old.Region(sector).floorTexture # map.world.Region(sector).floorTexture);
	IF repeat & ~nearest THEN
		Activate(map, special);
		Advance(map, target * 2);
		ASSERT(map.world.Region(sector).floor = target / 32.0)
	ELSIF repeat THEN
		Activate(map, special);
		Advance(map, 128);
		IF special = 68 THEN
			ASSERT(map.world.Region(sector).floor = 1.5)
		ELSE
			ASSERT(map.world.Region(sector).floor = 0.5)
		END
	END
END Variant;

PROCEDURE {TEST} AllActions*;
BEGIN
	Variant(14, 32, FALSE, FALSE);
	Variant(15, 24, FALSE, FALSE);
	Variant(20, 32, TRUE, FALSE);
	Variant(22, 32, TRUE, FALSE);
	Variant(47, 32, TRUE, FALSE);
	Variant(66, 24, FALSE, TRUE);
	Variant(67, 32, FALSE, TRUE);
	Variant(68, 32, TRUE, TRUE);
	Variant(95, 32, TRUE, TRUE)
END AllActions;

PROCEDURE {TEST} BusyAndGrouped*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("platform-change-66.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(1));
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.world = old);
	ASSERT(map.actions.Special(7) = 66);
	map.actions.Release(1);
	Activate(map, 66);
	Advance(map, 4);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	Load("platform-change-47.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(1));
	Activate(map, 47);
	ASSERT(map.actions.Special(7) = 0);
	ASSERT(map.world = old);
	Load("platform-change-grouped.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(1));
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.world.Region(1).floorTexture = old.Region(1).floorTexture);
	ASSERT(map.world.Region(3).floorTexture = old.Region(0).floorTexture);
	Advance(map, 128);
	ASSERT(map.world.Region(3).floor = 1);
	ASSERT(map.world.Region(1).floor = 0);
	Load("platform-change-no-next.wad", map);
	Activate(map, 95);
	Advance(map, 1);
	ASSERT(map.world.Region(2).floor = 0);
	ASSERT(map.floors.SectorSpecial(2) = 0);
	ASSERT(map.actions.Claim(2))
END BusyAndGrouped;

PROCEDURE LimitFloor(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor <= 4.0 / 64
END LimitFloor;

PROCEDURE {TEST} ReverseAndStasis*;
VAR map: DoomMap.Map;
	feet, saved: FLOAT64;
	i: SIGNED32;
BEGIN
	Load("platform-change-66.wad", map);
	Activate(map, 66);
	Advance(map, 8);
	feet := 0.5;
	map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 3.5 / 64);
	Advance(map, 7);
	ASSERT(map.world.Region(1).floor = 0);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 2);
	ASSERT(map.world.Region(1).floor = 0.5 / 64);
	Advance(map, 47);
	ASSERT(map.world.Region(1).floor = 24.0 / 64);
	ASSERT(map.actions.Claim(1));
	Load("platform-change-stasis.wad", map);
	Activate(map, 66);
	Advance(map, 8);
	saved := map.world.Region(1).floor;
	Cross(map, -0.5, 0.5);
	Advance(map, 100);
	ASSERT(map.world.Region(1).floor = saved);
	Cross(map, 3.5, 4.5);
	Advance(map, 40);
	ASSERT(map.world.Region(1).floor = 24.0 / 64);
	ASSERT(map.actions.Claim(1))
END ReverseAndStasis;

PROCEDURE {TEST} GunPublicationAndReplacement*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("platform-change-47.wad", "E1M1", error));
	old := game.world;
	game.Fire(TRUE);
	game.Step(1);
	game.Fire(FALSE);
	ASSERT(game.world.Region(1).floorTexture = old.Region(0).floorTexture);
	ASSERT(game.world.Region(1).floor = 0);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 2 TO 65 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0.5);
	ASSERT(old.Region(1).floor = 0);
	ASSERT(game.Load("platform-change-47.wad", "E1M1", error));
	ASSERT(game.world.Region(1).floorTexture.Sample(0, 0) = old.Region(1).floorTexture.Sample(0, 0))
END GunPublicationAndReplacement;

PROCEDURE {TEST} RidingAndHiddenMaterials*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	carrier: Carrier;
	old: DoomSprites.Scene;
	feet: FLOAT64;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("platform-change-actors.wad", map);
	NEW(carrier);
	carrier.scene := map.sprites;
	old := carrier.scene;
	Activate(map, 95);
	feet := 0;
	FOR i := 1 TO 64 DO
		map.floors.Step(map.world, 5, -1, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, carrier.Follow)
	END;
	ASSERT(feet = 0.5);
	ASSERT(carrier.scene.State(0).feet = feet);
	ASSERT(old.State(0).feet = 0);
	archive := DoomWad.Open("platform-change-hidden.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(error[0] # 0X)
END RidingAndHiddenMaterials;

PROCEDURE {TEST} CustomSettings*;
VAR map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("platform-change-14.wad", map);
	Activate(map, 14);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 1.5 / 64);
	Advance(map, 26);
	ASSERT(map.world.Region(1).floor = 40.0 / 64);
	Load("platform-change-15.wad", map);
	Activate(map, 15);
	Advance(map, 11);
	ASSERT(map.world.Region(1).floor = 16.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSettings;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	AllActions;
	BusyAndGrouped;
	ReverseAndStasis;
	GunPublicationAndReplacement;
	RidingAndHiddenMaterials;
	CustomSettings
END Do;

END DoomChangingPlatformsSmoke.
