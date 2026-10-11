MODULE DoomDoorsSmoke;

IMPORT DoomConfig, Doom, DoomInventory, DoomMap, DoomWad, GameGeometry, GameRenderer, GameSurface, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32; x: FLOAT64);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO ticks DO
		map.doors.Step(map.world, x, 0, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END
END Advance;

PROCEDURE Ceiling(world: GameGeometry.World): FLOAT64;
VAR region: GameGeometry.Sector;
BEGIN
	region := world.Region(1);
	RETURN region.ceiling
END Ceiling;

PROCEDURE Cycle;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	x, y, feet, floor: FLOAT64;
	pixel: SIGNED32;
BEGIN
	DoomInventory.Reset(player);
	Load("door.wad", map);
	old := map.world;
	ASSERT(~map.world.Stand(0, 0, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor));
	ASSERT(~map.doors.Use(map.world, -2, 0, 0, player));
	ASSERT(~map.doors.Use(map.world, -1.000001, 0, 0, player));
	ASSERT(~map.doors.Use(map.world, map.x, 0, MathL.pi, player));
	ASSERT(~map.doors.Use(map.world, 0.5, 0, MathL.pi, player));
	NEW(frame, 320, 200);
	GameRenderer.Render(map.world, frame, map.x, 0, 0, map.eye);
	pixel := frame.Pixel(160, 100);
	ASSERT(frame.Save("door-closed.ppm"));
	ASSERT(map.doors.Use(map.world, -1, 0, 0, player));
	Advance(map, 27, map.x);
	ASSERT(Ceiling(map.world) = 54.0 / 64);
	ASSERT(~map.world.Stand(0, 0, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor));
	GameRenderer.Render(map.world, frame, map.x, 0, 0, map.eye);
	ASSERT(frame.Save("door-opening.ppm"));
	Advance(map, 1, map.x);
	ASSERT(map.world.Stand(0, 0, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor));
	Advance(map, 34, map.x);
	ASSERT(Ceiling(map.world) = 124.0 / 64);
	ASSERT(Ceiling(old) = 0);
	GameRenderer.Render(map.world, frame, map.x, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 100) # pixel);
	ASSERT(frame.Save("door-open.ppm"));
	x := map.x;
	y := 0;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 3, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep));
	ASSERT(x > 2);
	Advance(map, 150, map.x);
	ASSERT(Ceiling(map.world) = 124.0 / 64);
	Advance(map, 1, map.x);
	ASSERT(Ceiling(map.world) = 122.0 / 64);
	Advance(map, 61, map.x);
	ASSERT(Ceiling(map.world) = 0);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, 1, map.x);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, 1, map.x);
	ASSERT(Ceiling(map.world) = 0);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, 62, map.x);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, 1, map.x);
	ASSERT(Ceiling(map.world) = 124.0 / 64);
	Advance(map, 150, 0.5);
	Advance(map, 35, 0.5);
	ASSERT(Ceiling(map.world) = 56.0 / 64);
	ASSERT(map.world.Stand(0.5, 0, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor));
	Advance(map, 1, 0.5);
	ASSERT(Ceiling(map.world) = 58.0 / 64)
END Cycle;

PROCEDURE Variant(CONST path: ARRAY OF CHAR; ticks: SIGNED32; stayOpen: BOOLEAN);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
BEGIN
	DoomInventory.Reset(player);
	Load(path, map);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, ticks - 1, map.x);
	ASSERT(Ceiling(map.world) < 124.0 / 64);
	Advance(map, 1, map.x);
	ASSERT(Ceiling(map.world) = 124.0 / 64);
	IF stayOpen THEN
		ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
		Advance(map, 250, map.x);
		ASSERT(Ceiling(map.world) = 124.0 / 64)
	ELSE
		Advance(map, 150 + ticks, map.x);
		ASSERT(Ceiling(map.world) = 0)
	END
END Variant;

PROCEDURE Peg(CONST path: ARRAY OF CHAR; upper, offset, lower: FLOAT64);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	wall: GameGeometry.Wall;
	distance: FLOAT64;
BEGIN
	DoomInventory.Reset(player);
	Load(path, map);
	ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
	Advance(map, 1, map.x);
	ASSERT(map.world.CastSector(0, map.x, 0, 1, 0, 0, distance, wall));
	ASSERT(wall.upperAnchor = upper);
	ASSERT(map.world.CastSector(1, 0.5, 0, -1, 0, 0, distance, wall));
	ASSERT(wall.upper # NIL);
	ASSERT(wall.lowerAnchor = lower);
	ASSERT(map.world.CastSector(1, 0.5, 0, 0, 1, 0, distance, wall));
	ASSERT(wall.top = 2.0 / 64);
	ASSERT(wall.vOffset = offset)
END Peg;

PROCEDURE Do*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	game: Doom.Game;
	old: GameGeometry.World;
	archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	DoomInventory.Reset(player);
	Cycle;
	Variant("door-open.wad", 62, TRUE);
	Variant("door-fast.wad", 16, FALSE);
	Variant("door-fast-open.wad", 16, TRUE);
	Peg("door.wad", 1 + 2.0 / 64, 0, 0);
	Peg("door-peg-top.wad", 2, 0, 0);
	Peg("door-peg-bottom.wad", 1 + 2.0 / 64, -2.0 / 64, 2.0 / 64);
	Load("door-locked.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	Load("door-unsupported.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	Load("door-no-back.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	Load("door-occluded.wad", map);
	ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
	archive := DoomWad.Open("door-hidden-unknown.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT((map.world = NIL) & (map.doors = NIL) & (error[0] # 0X));
	NEW(game);
	ASSERT(game.Load("door.wad", "E1M1", error));
	old := game.world;
	game.Use;
	game.Use;
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 1 TO 62 DO
		game.Step(i)
	END;
	ASSERT(Ceiling(game.world) = 124.0 / 64);
	ASSERT(Ceiling(old) = 0)
END Do;

END DoomDoorsSmoke.
