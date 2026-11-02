MODULE DoomDoorOccupantsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomInventory, DoomSprites, GameGeometry;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Use(VAR map: DoomMap.Map);
VAR player: DoomInventory.State;
BEGIN
	DoomInventory.Reset(player);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player))
END Use;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO ticks DO
		map.doors.StepOccupied(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, map.sprites.FitsCeilings)
	END
END Advance;

PROCEDURE {TEST} CloseAndRelease*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	sprites: DoomSprites.Scene;
BEGIN
	Load("door-occupants-42.wad", map);
	old := map.world;
	sprites := map.sprites;
	Use(map);
	Advance(map, 43);
	ASSERT(map.world.Region(1).ceiling = 42.0 / 64);
	ASSERT(old.Region(1).ceiling = 2);
	old := map.world;
	Advance(map, 30);
	ASSERT(map.world.Region(1).ceiling = 42.0 / 64);
	ASSERT(map.world = old);
	ASSERT(map.sprites = sprites);
	ASSERT(map.sprites.Health(0) = 20);
	ASSERT(~map.actions.Claim(1));
	map.sprites := map.sprites.Shoot(map.world, -3.5, 0, 0, 0.5, 8, 100);
	ASSERT(map.sprites.Health(0) = 0);
	ASSERT(sprites.Health(0) = 20);
	Advance(map, 21);
	ASSERT(map.world.Region(1).ceiling = 0);
	ASSERT(old.Region(1).ceiling = 42.0 / 64);
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1);
	Load("door-occupants-116.wad", map);
	Use(map);
	Advance(map, 50);
	ASSERT(map.world.Region(1).ceiling = 48.0 / 64)
END CloseAndRelease;

PROCEDURE Reversal(CONST path: ARRAY OF CHAR; blocked, next: FLOAT64; ticks: SIGNED32);
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load(path, map);
	Use(map);
	Advance(map, ticks);
	ASSERT(map.world.Region(1).ceiling = blocked / 64);
	old := map.world;
	Advance(map, 1);
	ASSERT(map.world = old);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = next / 64);
	ASSERT(old.Region(1).ceiling = blocked / 64)
END Reversal;

PROCEDURE {TEST} RaiseReverses*;
BEGIN
	Reversal("door-occupants-63.wad", 42, 44, 1 + 150 + 41);
	Reversal("door-occupants-114.wad", 44, 52, 1 + 150 + 10);
	Reversal("door-occupants-manual.wad", 42, 44, 62 + 150 + 41)
END RaiseReverses;

PROCEDURE {TEST} CloseWaitReverses*;
VAR map: DoomMap.Map;
BEGIN
	Load("door-occupants-wait.wad", map);
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 43);
	ASSERT(map.world.Region(2).ceiling = 42.0 / 64);
	Advance(map, 1);
	ASSERT(map.world.Region(2).ceiling = 42.0 / 64);
	Advance(map, 1);
	ASSERT(map.world.Region(2).ceiling = 44.0 / 64);
	Advance(map, 42);
	ASSERT(map.world.Region(2).ceiling = 2);
	ASSERT(map.actions.Claim(2));
	map.actions.Release(2)
END CloseWaitReverses;

PROCEDURE Footprint(CONST path: ARRAY OF CHAR; expected: FLOAT64);
VAR map: DoomMap.Map;
BEGIN
	Load(path, map);
	Use(map);
	Advance(map, 100);
	ASSERT(map.world.Region(1).ceiling = expected / 64)
END Footprint;

PROCEDURE {TEST} FootprintsAndAttachments*;
BEGIN
	Footprint("door-occupants-overlap.wad", 42);
	Footprint("door-occupants-tangent.wad", 0);
	Footprint("door-occupants-remote.wad", 0);
	Footprint("door-occupants-invalid.wad", 0);
	Footprint("door-occupants-pickup.wad", 0);
	Footprint("door-occupants-hanging.wad", 68);
	Footprint("door-occupants-hanging-passable.wad", 0);
	Footprint("door-occupants-monster.wad", 56)
END FootprintsAndAttachments;

PROCEDURE {TEST} GroupedDoors*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("door-occupants-grouped.wad", map);
	old := map.world;
	Use(map);
	Advance(map, 100);
	ASSERT(map.world.Region(1).ceiling = 42.0 / 64);
	ASSERT(map.world.Region(3).ceiling = 0);
	ASSERT(old.Region(1).ceiling = 2);
	ASSERT(old.Region(3).ceiling = 2);
	ASSERT(~map.actions.Claim(1));
	ASSERT(map.actions.Claim(3));
	map.actions.Release(3)
END GroupedDoors;

PROCEDURE {TEST} GameIntegration*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("door-occupants-42.wad", "E1M1", error));
	old := game.world;
	game.Use;
	FOR i := 1 TO 100 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 42.0 / 64);
	ASSERT(old.Region(1).ceiling = 2);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 101 TO 120 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 42.0 / 64)
END GameIntegration;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	CloseAndRelease;
	RaiseReverses;
	CloseWaitReverses;
	FootprintsAndAttachments;
	GroupedDoors;
	GameIntegration
END Do;

END DoomDoorOccupantsSmoke.
