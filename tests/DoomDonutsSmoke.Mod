MODULE DoomDonutsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry, GameMaterials;

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

PROCEDURE Variant(CONST path: ARRAY OF CHAR);
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	texture: GameMaterials.Texture;
BEGIN
	Load(path, map);
	old := map.world;
	texture := old.Region(0).floorTexture;
	map.floors.Crossed(-0.5, 0, 0.5, 0);
	map.floors.ApplyCrossings(map.world);
	map.floors.Shot(map.world, 7);
	Advance(map, 1);
	ASSERT(map.world = old);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.actions.Special(7) = 0);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(~map.actions.Claim(1));
	ASSERT(~map.actions.Claim(2));
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0.5 / 64);
	ASSERT(map.world.Region(2).floor = 95.5 / 64);
	Advance(map, 62);
	ASSERT(map.world.Region(1).floor = 31.5 / 64);
	ASSERT(map.floors.SectorSpecial(1) = 9);
	ASSERT(map.world.Region(1).floorTexture = old.Region(1).floorTexture);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0.5);
	ASSERT(map.world.Region(1).floorTexture = texture);
	ASSERT(map.floors.SectorSpecial(1) = 0);
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 64);
	ASSERT(map.world.Region(2).floor = 0.5);
	ASSERT(map.floors.SectorSpecial(2) = 7);
	ASSERT(map.world.Region(2).floorTexture = old.Region(2).floorTexture);
	ASSERT(map.actions.Claim(2));
	map.actions.Release(2);
	ASSERT(old.Region(1).floor = 0);
	ASSERT(old.Region(2).floor = 1.5);
	ASSERT(map.world.Region(0).floor = old.Region(0).floor)
END Variant;

PROCEDURE {TEST} MotionAndSurface*;
BEGIN
	Variant("donut.wad");
	Variant("donut-nested.wad");
	Variant("donut-reversed.wad");
	Variant("donut-untextured.wad")
END MotionAndSurface;

PROCEDURE {TEST} BusyAndMissingTargets*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	i: SIGNED32;
BEGIN
	FOR i := 1 TO 2 DO
		Load("donut.wad", map);
		old := map.world;
		ASSERT(map.actions.Claim(i));
		ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
		ASSERT(map.actions.Special(7) = 9);
		Advance(map, 1);
		ASSERT(map.world = old);
		ASSERT(map.actions.Claim(3 - i));
		map.actions.Release(3 - i);
		map.actions.Release(i);
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle))
	END;
	Load("donut-no-model.wad", map);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	ASSERT(map.actions.Special(7) = 9);
	ASSERT(map.actions.Claim(1));
	ASSERT(map.actions.Claim(2));
	Load("donut-no-tag.wad", map);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	Load("donut-wrong-height.wad", map);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle))
END BusyAndMissingTargets;

PROCEDURE RejectRing(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN sector # 1
END RejectRing;

PROCEDURE {TEST} ObstructionAndCapturedModel*;
VAR map: DoomMap.Map;
	model: GameMaterials.Texture;
	feet: FLOAT64;
BEGIN
	Load("donut.wad", map);
	model := map.world.Region(0).floorTexture;
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	map.world := map.world.WithFloorTexture(0, map.world.Region(2).floorTexture);
	Advance(map, 63);
	feet := 0.5;
	map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, RejectRing);
	ASSERT(map.world.Region(1).floor = 31.5 / 64);
	ASSERT(map.floors.SectorSpecial(1) = 9);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 65);
	ASSERT(map.world.Region(1).floorTexture = model);
	ASSERT(map.floors.SectorSpecial(1) = 0);
	Load("donut-equal.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0.5);
	ASSERT(map.floors.SectorSpecial(1) = 0);
	ASSERT(map.actions.Claim(1))
END ObstructionAndCapturedModel;

PROCEDURE {TEST} RidingAndReplacement*;
VAR map: DoomMap.Map;
	carrier: Carrier;
	old: DoomSprites.Scene;
	game: Doom.Game;
	feet: FLOAT64;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	Load("donut-actors.wad", map);
	NEW(carrier);
	carrier.scene := map.sprites;
	old := carrier.scene;
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	feet := 0;
	FOR i := 1 TO 64 DO
		map.floors.Step(map.world, 2, -1, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, carrier.Follow)
	END;
	ASSERT(feet = 0.5);
	ASSERT(carrier.scene.State(0).feet = 0.5);
	ASSERT(carrier.scene.State(1).feet = 1);
	ASSERT(old.State(0).feet = 0);
	ASSERT(old.State(1).feet = 1.5);
	NEW(game);
	ASSERT(game.Load("donut.wad", "E1M1", error));
	game.Use;
	game.Step(1);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 2 TO 128 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 0.5);
	ASSERT(game.world.Region(2).floor = 0.5);
	ASSERT(game.Load("donut.wad", "E1M1", error));
	ASSERT(game.world.Region(1).floor = 0)
END RidingAndReplacement;

PROCEDURE {TEST} HiddenMaterials*;
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	Load("donut.wad", map);
	ASSERT(map.floors.Moving(1));
	ASSERT(map.floors.Moving(2));
	archive := DoomWad.Open("donut-hidden-wall.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(error[0] # 0X)
END HiddenMaterials;

PROCEDURE {TEST} CustomSpeed*;
VAR map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("donut.wad", map);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 1.5 / 64);
	ASSERT(map.world.Region(2).floor = 94.5 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSpeed;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	MotionAndSurface;
	BusyAndMissingTargets;
	ObstructionAndCapturedModel;
	RidingAndReplacement;
	HiddenMaterials;
	CustomSpeed
END Do;

END DoomDonutsSmoke.
