MODULE DoomFloorChangesSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry, GameSurface, GameRenderer, GameMaterials;

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

PROCEDURE Cross(VAR map: DoomMap.Map);
BEGIN
	map.floors.Crossed(-0.5, 0, 0.5, 0);
	map.floors.ApplyCrossings(map.world)
END Cross;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
	feet: FLOAT64;
BEGIN
	feet := map.world.Region(map.world.Locate(map.x, map.y)).floor;
	FOR i := 1 TO ticks DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END
END Advance;

PROCEDURE Variant(CONST path: ARRAY OF CHAR; special: SIGNED32);
VAR map: DoomMap.Map;
	old, almost: GameGeometry.World;
	texture, original: GameMaterials.Texture;
	frame: GameSurface.Frame;
	pixel: SIGNED32;
BEGIN
	Load(path, map);
	old := map.world;
	texture := old.Region(0).floorTexture;
	original := old.Region(1).floorTexture;
	ASSERT(texture # original);
	ASSERT(map.floors.SectorSpecial(1) = 9);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	map.floors.Shot(map.world, 8);
	map.floors.Crossed(-0.5, 5, 0.5, 5);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 1);
	ASSERT(map.world = old);
	Cross(map);
	ASSERT(map.world.Region(1).floorTexture = original);
	ASSERT(~map.actions.Claim(1));
	IF special = 37 THEN
		ASSERT(map.actions.Special(8) = 0)
	ELSE
		ASSERT(map.actions.Special(8) = special)
	END;
	Advance(map, 95);
	ASSERT(map.world.Region(1).floor = 1.0 / 64);
	ASSERT(map.world.Region(1).floorTexture = original);
	ASSERT(map.floors.SectorSpecial(1) = 9);
	almost := map.world;
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0);
	ASSERT(map.world.Region(1).floorTexture = texture);
	ASSERT(map.floors.SectorSpecial(1) = 5);
	ASSERT(almost.Region(1).floorTexture = original);
	ASSERT((old.Region(1).floor = 1.5) & (old.Region(1).floorTexture = original));
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1);
	NEW(frame, 32, 20);
	GameRenderer.Render(almost, frame, 1, 0, 0, 0.89);
	pixel := frame.Pixel(16, 19);
	GameRenderer.Render(map.world, frame, 1, 0, 0, 0.89);
	ASSERT(frame.Pixel(16, 19) # pixel);
	GameRenderer.Render(almost, frame, 1, 0, 0, 0.89);
	ASSERT(frame.Pixel(16, 19) = pixel);
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floorTexture = texture);
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1)
END Variant;

PROCEDURE {TEST} CrossingVariants*;
BEGIN
	Variant("floor-change-37.wad", 37);
	Variant("floor-change-84.wad", 84)
END CrossingVariants;

PROCEDURE Model(CONST path: ARRAY OF CHAR; sector, special, ticks: SIGNED32; height: FLOAT64);
VAR map: DoomMap.Map;
	texture: GameMaterials.Texture;
BEGIN
	Load(path, map);
	texture := map.world.Region(sector).floorTexture;
	Cross(map);
	Advance(map, ticks);
	ASSERT(map.world.Region(1).floor = height / 64);
	ASSERT(map.world.Region(1).floorTexture = texture);
	ASSERT(map.floors.SectorSpecial(1) = special)
END Model;

PROCEDURE {TEST} ModelSelection*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	Model("floor-change-tie.wad", 0, 5, 96, 0);
	Model("floor-change-order.wad", 2, 7, 96, 0);
	Model("floor-change-no-model.wad", 1, 9, 1, -16);
	Model("floor-change-zero.wad", 0, 5, 1, 0);
	Model("floor-change-untextured.wad", 0, 5, 96, 0);
	archive := DoomWad.Open("floor-change-unflagged.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(error[0] # 0X)
END ModelSelection;

PROCEDURE {TEST} CapturedModel*;
VAR map: DoomMap.Map;
	texture: GameMaterials.Texture;
BEGIN
	Load("floor-change-84.wad", map);
	texture := map.world.Region(0).floorTexture;
	Cross(map);
	map.world := map.world.WithFloorTexture(0, map.world.Region(2).floorTexture);
	Advance(map, 96);
	ASSERT(map.world.Region(1).floorTexture = texture);
	ASSERT(map.world.Region(1).floorTexture # map.world.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 5)
END CapturedModel;

PROCEDURE RejectLast(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor > 0
END RejectLast;

PROCEDURE {TEST} ObstructionAndBusy*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	i: SIGNED32;
	feet: FLOAT64;
BEGIN
	Load("floor-change-37.wad", map);
	ASSERT(map.actions.Claim(1));
	old := map.world;
	Cross(map);
	Advance(map, 1);
	ASSERT((map.world = old) & (map.actions.Special(8) = 0));
	map.actions.Release(1);
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world = old);
	Load("floor-change-84.wad", map);
	ASSERT(map.actions.Claim(1));
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 1.5);
	map.actions.Release(1);
	Cross(map);
	Advance(map, 95);
	old := map.world;
	feet := 0;
	FOR i := 1 TO 10 DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, RejectLast)
	END;
	ASSERT(map.world = old);
	ASSERT(map.floors.SectorSpecial(1) = 9);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 1);
	ASSERT(map.world.Region(1).floorTexture = map.world.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 5)
END ObstructionAndBusy;

PROCEDURE {TEST} ChangedStairChains*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("floor-change-stairs.wad", map);
	FOR i := 1 TO 4 DO
		ASSERT(map.floors.Moving(i))
	END;
	Cross(map);
	Advance(map, 32);
	ASSERT(map.world.Region(1).floorTexture = map.world.Region(2).floorTexture);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 16);
	FOR i := 1 TO 4 DO
		ASSERT(map.world.Region(i).floor = i * 16.0 / 64)
	END;
	archive := DoomWad.Open("floor-change-stairs-hidden.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT((map.world = NIL) & (error[0] # 0X))
END ChangedStairChains;

PROCEDURE {TEST} GroupedModelsAndRiding*;
VAR map: DoomMap.Map;
	carrier: Carrier;
	old: DoomSprites.Scene;
	feet: FLOAT64;
	i: SIGNED32;
BEGIN
	Load("floor-change-grouped.wad", map);
	Cross(map);
	Advance(map, 96);
	ASSERT((map.world.Region(1).floor = 0) & (map.world.Region(3).floor = 0));
	ASSERT(map.world.Region(1).floorTexture = map.world.Region(0).floorTexture);
	ASSERT(map.world.Region(3).floorTexture = map.world.Region(2).floorTexture);
	ASSERT(map.world.Region(1).floorTexture # map.world.Region(3).floorTexture);
	ASSERT((map.floors.SectorSpecial(1) = 5) & (map.floors.SectorSpecial(3) = 7));
	Load("floor-change-riding.wad", map);
	NEW(carrier);
	carrier.scene := map.sprites;
	old := carrier.scene;
	Cross(map);
	feet := 1.5;
	FOR i := 1 TO 96 DO
		map.floors.Step(map.world, 1, -1, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, carrier.Follow)
	END;
	ASSERT(feet = 0);
	ASSERT(carrier.scene.State(0).feet = 0);
	ASSERT(old.State(0).feet = 1.5);
	ASSERT(map.world.Region(1).floorTexture = map.world.Region(0).floorTexture)
END GroupedModelsAndRiding;

PROCEDURE {TEST} AcceptedMovementAndReplacement*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-change-game.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	game.Controls(0, 0, 0);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 11 TO 110 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(2).floor = 0);
	ASSERT(game.world.Region(2).floorTexture = old.Region(1).floorTexture);
	ASSERT(old.Region(2).floorTexture # game.world.Region(2).floorTexture);
	ASSERT(game.Load("floor-change-game.wad", "E1M1", error));
	ASSERT(game.world.Region(2).floor = 1.5);
	ASSERT(game.world.Region(2).floorTexture # game.world.Region(1).floorTexture);
	ASSERT(game.Load("floor-change-84.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 111 TO 160 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(1).floor = 1.5)
END AcceptedMovementAndReplacement;

PROCEDURE {TEST} CustomSpeed*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Model("floor-change-84.wad", 0, 5, 48, 0);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSpeed;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	CrossingVariants;
	ModelSelection;
	CapturedModel;
	ObstructionAndBusy;
	ChangedStairChains;
	GroupedModelsAndRiding;
	AcceptedMovementAndReplacement;
	CustomSpeed
END Do;

END DoomFloorChangesSmoke.
