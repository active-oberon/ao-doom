MODULE DoomCeilingsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomInventory, GameGeometry, GameSurface, GameRenderer;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Use(VAR map: DoomMap.Map): BOOLEAN;
VAR player: DoomInventory.State;
BEGIN
	DoomInventory.Reset(player);
	RETURN map.doors.Use(map.world, map.x, map.y, map.angle, player)
END Use;

PROCEDURE Cross(VAR map: DoomMap.Map);
BEGIN
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.floors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	map.floors.ApplyCrossings(map.world)
END Cross;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
	feet: FLOAT64;
BEGIN
	feet := map.world.Region(map.world.Locate(map.x, map.y)).floor;
	FOR i := 1 TO ticks DO
		map.doors.StepOccupied(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, map.sprites.FitsCeilings)
	END
END Advance;

PROCEDURE {TEST} LoweringActions*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("ceiling-41.wad", map);
	old := map.world;
	ASSERT(Use(map));
	ASSERT(map.actions.Special(7) = 0);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 95.0 / 64);
	Advance(map, 79);
	ASSERT(map.world.Region(1).ceiling = 16.0 / 64);
	ASSERT(map.world.Region(1).floor = old.Region(1).floor);
	ASSERT(old.Region(1).ceiling = 96.0 / 64);
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1);
	ASSERT(~Use(map));
	Load("ceiling-43.wad", map);
	ASSERT(Use(map));
	ASSERT(map.actions.Special(7) = 43);
	Advance(map, 80);
	ASSERT(Use(map));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 16.0 / 64)
END LoweringActions;

PROCEDURE {TEST} RaisingAction*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	pixel: SIGNED32;
BEGIN
	Load("ceiling-40.wad", map);
	old := map.world;
	ASSERT(~Use(map));
	map.doors.Shot(map.world, 8);
	map.doors.Crossed(-0.5, 5, 0.5, 5);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 1);
	ASSERT(map.world = old);
	Cross(map);
	ASSERT(map.actions.Special(8) = 0);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 97.0 / 64);
	Advance(map, 95);
	ASSERT(map.world.Region(1).ceiling = 3);
	ASSERT(map.world.Region(1).floor = 16.0 / 64);
	ASSERT(map.world.Region(1).ceilingTexture = old.Region(1).ceilingTexture);
	ASSERT(old.Region(1).ceiling = 96.0 / 64);
	ASSERT(map.actions.Claim(1));
	map.actions.Release(1);
	NEW(frame, 32, 20);
	GameRenderer.Render(old, frame, map.x, map.y, 0, 41.0 / 64);
	pixel := frame.Pixel(16, 1);
	GameRenderer.Render(map.world, frame, map.x, map.y, 0, 41.0 / 64);
	ASSERT(frame.Pixel(16, 1) # pixel);
	GameRenderer.Render(old, frame, map.x, map.y, 0, 41.0 / 64);
	ASSERT(frame.Pixel(16, 1) = pixel)
END RaisingAction;

PROCEDURE {TEST} BoundsAndOwnership*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
BEGIN
	Load("ceiling-high.wad", map);
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 224.0 / 64);
	ASSERT(map.actions.Claim(1));
	Load("ceiling-negative.wad", map);
	Cross(map);
	Advance(map, 32);
	ASSERT(map.world.Region(1).ceiling = -1);
	Load("ceiling-isolated.wad", map);
	map.doors.Crossed(-4.5, 0, -3.5, 0);
	map.doors.ApplyCrossings(map.world);
	Advance(map, 1);
	ASSERT(map.world.Region(0).ceiling = 2);
	ASSERT(map.actions.Claim(0));
	Load("ceiling-41.wad", map);
	ASSERT(map.actions.Claim(1));
	ASSERT(~Use(map));
	ASSERT(map.actions.Special(7) = 41);
	map.actions.Release(1);
	ASSERT(Use(map));
	Load("ceiling-40.wad", map);
	ASSERT(map.actions.Claim(1));
	Cross(map);
	ASSERT(map.actions.Special(8) = 0);
	map.actions.Release(1);
	Cross(map);
	Advance(map, 10);
	ASSERT(map.world.Region(1).ceiling = 96.0 / 64);
	Load("ceiling-manual.wad", map);
	ASSERT(Use(map));
	DoomInventory.Reset(player);
	ASSERT(~map.doors.Use(map.world, -0.5, 0, 0, player));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 95.0 / 64)
END BoundsAndOwnership;

PROCEDURE {TEST} OccupantsAndGroups*;
VAR map: DoomMap.Map;
	i: SIGNED32;
BEGIN
	Load("ceiling-43.wad", map);
	ASSERT(Use(map));
	FOR i := 1 TO 60 DO
		map.doors.Step(map.world, 2, 0, DoomConfig.values.playerRadius, 16.0 / 64,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	ASSERT(map.world.Region(1).ceiling = 72.0 / 64);
	ASSERT(~map.actions.Claim(1));
	Advance(map, 56);
	ASSERT(map.world.Region(1).ceiling = 16.0 / 64);
	Load("ceiling-actors.wad", map);
	ASSERT(Use(map));
	Advance(map, 100);
	ASSERT(map.world.Region(1).ceiling = 58.0 / 64);
	ASSERT(map.sprites.Health(0) = 20);
	map.sprites := map.sprites.Shoot(map.world, 1, -1, 0, 48.0 / 64, 8, 100);
	ASSERT(map.sprites.Health(0) = 0);
	Advance(map, 42);
	ASSERT(map.world.Region(1).ceiling = 16.0 / 64);
	Load("ceiling-grouped.wad", map);
	ASSERT(map.actions.Claim(1));
	ASSERT(Use(map));
	Advance(map, 192);
	ASSERT(map.world.Region(1).ceiling = 96.0 / 64);
	ASSERT(map.world.Region(2).ceiling = 0);
	map.actions.Release(1)
END OccupantsAndGroups;

PROCEDURE {TEST} SwitchesAndReplacement*;
VAR game: Doom.Game;
	map: DoomMap.Map;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("ceiling-43.wad", map);
	old := map.world;
	ASSERT(Use(map));
	map.actions.Step(map.world);
	ASSERT(map.world.WallAt(7).texture # old.WallAt(7).texture);
	FOR i := 2 TO DoomConfig.values.buttonTicks DO
		map.actions.Step(map.world)
	END;
	ASSERT(map.world.WallAt(7).texture = old.WallAt(7).texture);
	NEW(game);
	ASSERT(game.Load("ceiling-40.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	game.Controls(0, 0, 0);
	ASSERT(~game.Load("ceiling-hidden.wad", "E1M1", error));
	ASSERT(error[0] # 0X);
	FOR i := 11 TO 110 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).ceiling = 3);
	ASSERT(game.world.Region(1).floor = 16.0 / 64);
	ASSERT(old.Region(1).ceiling = 96.0 / 64);
	ASSERT(game.Load("ceiling-blocked.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 111 TO 150 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(1).ceiling = 96.0 / 64)
END SwitchesAndReplacement;

PROCEDURE {TEST} CustomSpeed*;
VAR map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	ASSERT(DoomConfig.values.ceilingSpeed = 3.0 / 64);
	Load("ceiling-41.wad", map);
	ASSERT(Use(map));
	Advance(map, 1);
	ASSERT(map.world.Region(1).ceiling = 93.0 / 64);
	Advance(map, 26);
	ASSERT(map.world.Region(1).ceiling = 16.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSpeed;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	LoweringActions;
	RaisingAction;
	BoundsAndOwnership;
	OccupantsAndGroups;
	SwitchesAndReplacement;
	CustomSpeed
END Do;

END DoomCeilingsSmoke.
