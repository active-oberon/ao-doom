MODULE DoomTextureFloorsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry;

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

PROCEDURE Cross(VAR map: DoomMap.Map; reverse: BOOLEAN);
BEGIN
	IF reverse THEN
		map.floors.Crossed(0.5, 0, -0.5, 0)
	ELSE
		map.floors.Crossed(-0.5, 0, 0.5, 0)
	END;
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

PROCEDURE {TEST} Actions*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("floor-texture-30.wad", map);
	old := map.world;
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	map.floors.Shot(map.world, 8);
	map.floors.Crossed(-0.5, 5, 0.5, 5);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 1);
	ASSERT(map.world = old);
	Cross(map, FALSE);
	ASSERT(map.actions.Special(8) = 0);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 1);
	ASSERT(map.world.Region(2).floor = 17.0 / 64);
	Advance(map, 23);
	ASSERT(map.world.Region(2).floor = 40.0 / 64);
	ASSERT(map.actions.Claim(2));
	map.actions.Release(2);
	ASSERT(old.Region(2).floor = 16.0 / 64);
	ASSERT(map.world.Region(2).floorTexture = old.Region(2).floorTexture);
	ASSERT(map.world.Region(2).ceiling = old.Region(2).ceiling);
	Cross(map, TRUE);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 40.0 / 64);
	Load("floor-texture-96.wad", map);
	Cross(map, TRUE);
	ASSERT(map.actions.Special(8) = 96);
	Advance(map, 24);
	Cross(map, FALSE);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 64.0 / 64)
END Actions;

PROCEDURE CheckTarget(CONST path: ARRAY OF CHAR; target: SIGNED32);
VAR map: DoomMap.Map;
BEGIN
	Load(path, map);
	Cross(map, FALSE);
	Advance(map, 64);
	ASSERT(map.world.Region(2).floor = target / 64.0);
	ASSERT(map.actions.Claim(2))
END CheckTarget;

PROCEDURE {TEST} BoundariesAndMaterials*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	CheckTarget("floor-texture-reverse.wad", 40);
	CheckTarget("floor-texture-front.wad", 40);
	CheckTarget("floor-texture-absent.wad", 16);
	CheckTarget("floor-texture-negative.wad", -8);
	Load("floor-texture-switch.wad", map);
	old := map.world;
	map.actions.Activated(8, FALSE);
	map.actions.Step(map.world);
	map.floors.Crossed(-4.5, 0, -3.5, 0);
	map.floors.ApplyCrossings(map.world);
	map.actions.Activated(8, FALSE);
	map.actions.Step(map.world);
	Advance(map, 48);
	ASSERT(map.world.Region(1).floor = 144.0 / 64);
	map.floors.Crossed(-4.5, 0, -3.5, 0);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 64);
	ASSERT(map.world.Region(1).floor = 208.0 / 64);
	ASSERT(old.WallAt(8).lower.height = 64)
END BoundariesAndMaterials;

PROCEDURE LimitFloor(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor <= 32.0 / 64
END LimitFloor;

PROCEDURE {TEST} OwnershipAndObstruction*;
VAR map: DoomMap.Map;
	i: SIGNED32;
	feet: FLOAT64;
BEGIN
	Load("floor-texture-30.wad", map);
	ASSERT(map.actions.Claim(2));
	Cross(map, FALSE);
	ASSERT(map.actions.Special(8) = 0);
	map.actions.Release(2);
	Cross(map, FALSE);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 16.0 / 64);
	Load("floor-texture-grouped.wad", map);
	ASSERT(map.actions.Claim(2));
	Cross(map, FALSE);
	Advance(map, 8);
	ASSERT(map.world.Region(1).floor = 8.0 / 64);
	ASSERT(map.world.Region(2).floor = 16.0 / 64);
	map.actions.Release(2);
	Cross(map, FALSE);
	feet := 0;
	FOR i := 1 TO 40 DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor)
	END;
	ASSERT(map.world.Region(2).floor = 32.0 / 64);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 8);
	ASSERT(map.world.Region(2).floor = 40.0 / 64);
	ASSERT(map.actions.Claim(2))
END OwnershipAndObstruction;

PROCEDURE {TEST} MovementAndReplacement*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-texture-game.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	game.Controls(0, 0, 0);
	ASSERT(~game.Load("floor-texture-missing.wad", "E1M1", error));
	ASSERT(error[0] # 0X);
	FOR i := 11 TO 40 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 8.0 / 64);
	ASSERT(game.State().eye = 8.0 / 64 + DoomConfig.values.playerEye);
	ASSERT(old.Region(1).floor = 0);
	ASSERT(game.Load("floor-texture-blocked.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 41 TO 80 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(1).floor = 0)
END MovementAndReplacement;

PROCEDURE {TEST} RidingAndValidation*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	carrier: Carrier;
	old: DoomSprites.Scene;
	feet: FLOAT64;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("floor-texture-actors.wad", map);
	NEW(carrier);
	carrier.scene := map.sprites;
	old := carrier.scene;
	Cross(map, FALSE);
	feet := 16.0 / 64;
	FOR i := 1 TO 24 DO
		map.floors.Step(map.world, 6, 0, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, carrier.Follow)
	END;
	ASSERT(feet = 40.0 / 64);
	ASSERT(carrier.scene.State(0).feet = feet);
	ASSERT(old.State(0).feet = 16.0 / 64);
	archive := DoomWad.Open("floor-texture-unflagged.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(error[0] # 0X)
END RidingAndValidation;

PROCEDURE {TEST} CustomSpeed*;
VAR map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("floor-texture-96.wad", map);
	Cross(map, FALSE);
	Advance(map, 1);
	ASSERT(map.world.Region(2).floor = 18.0 / 64);
	Advance(map, 11);
	ASSERT(map.world.Region(2).floor = 40.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSpeed;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Actions;
	BoundariesAndMaterials;
	OwnershipAndObstruction;
	MovementAndReplacement;
	RidingAndValidation;
	CustomSpeed
END Do;

END DoomTextureFloorsSmoke.
