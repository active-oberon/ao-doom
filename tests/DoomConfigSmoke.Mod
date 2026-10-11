MODULE DoomConfigSmoke;

IMPORT DoomConfig, Doom, DoomHud, DoomInventory, DoomWad, DoomMap, GameSurface, GameGeometry, KernelLog;

PROCEDURE {TEST} RequiredFile*;
VAR settings: DoomConfig.Settings;
	archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(~DoomConfig.loaded);
	archive := DoomWad.Open("valid.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(map.world = NIL);
	ASSERT(DoomConfig.Read("doom.yaml", settings, error));
	settings.width := 640;
	ASSERT(~DoomConfig.Read("doom-incomplete.yaml", settings, error));
	ASSERT(error[0] # 0X);
	ASSERT(settings.width = 640);
	ASSERT(~DoomConfig.Load("doom-incomplete.yaml", error));
	ASSERT(~DoomConfig.loaded);
	ASSERT(DoomConfig.Load("doom.yaml", error));
	ASSERT(DoomConfig.loaded);
	ASSERT(~DoomConfig.Load("doom-incomplete.yaml", error));
	ASSERT(DoomConfig.loaded)
END RequiredFile;

PROCEDURE WallColor(game: Doom.Game; x, y, dx, dy: FLOAT64; expected: SIGNED32);
VAR wall: GameGeometry.Wall;
	distance: FLOAT64;
BEGIN
	ASSERT(game.world.Cast(x, y, dx, dy, distance, wall));
	ASSERT(wall.color = expected);
	ASSERT(wall.texture # NIL);
	ASSERT(wall.texture.Sample(0.125, 0.125) = expected)
END WallColor;

PROCEDURE {TEST} DemoColors*;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	NEW(game);
	WallColor(game, 2, 4, 0, -1, 0112233H);
	WallColor(game, 2, 4, 0, 1, 0112233H);
	WallColor(game, 2, 4, -1, 0, 0445566H);
	WallColor(game, 10, 4, 1, 0, 0445566H);
	WallColor(game, 2, 2, 1, 0, 0778899H);
	WallColor(game, 2, 6, 1, 0, 0778899H);
	WallColor(game, 7, 2, 1, 0, 0AABBCCH);
	WallColor(game, 7, 9, 1, 0, 0AABBCCH);
	WallColor(game, 5.5, 6, 0, 1, 0DDEEFFH);
	WallColor(game, 7, 7.5, -1, 0, 0DDEEFFH);
	WallColor(game, 5.5, 9, 0, -1, 0DDEEFFH);
	WallColor(game, 4.5, 7.5, 1, 0, 0DDEEFFH);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END DemoColors;

PROCEDURE {TEST} DemoAppearance*;
VAR game: Doom.Game;
	wall: GameGeometry.Wall;
	distance: FLOAT64;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	NEW(game);
	ASSERT(ABS(game.State().eye - 80.0 / 64) < 0.00000001);
	ASSERT(game.world.Cast(2, 4, 0, -1, distance, wall));
	ASSERT(wall.top = 192.0 / 64);
	ASSERT(wall.light = 160);
	ASSERT((wall.texture.width = 32) & (wall.texture.height = 32));
	ASSERT(wall.texture.Sample(0, 0) = 0081119H);
	ASSERT(wall.texture.Sample(1.0 / 32, 1.0 / 32) = 0112233H);
	ASSERT(wall.texture.Sample(10.0 / 32, 9.0 / 32) = 0081119H);
	ASSERT(wall.texture.Sample(11.0 / 32, 9.0 / 32) = 0112233H);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END DemoAppearance;

PROCEDURE {TEST} MovementAndPanel*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	frame: GameSurface.Frame;
	player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	NEW(game);
	game.Controls(1, 0, 0);
	game.Step(1);
	pose := game.State();
	ASSERT(ABS(pose.x - 2.18) < 0.00000001);
	game.Controls(0, 0, 1);
	game.Step(2);
	ASSERT(ABS(game.State().angle - 0.13) < 0.00000001);
	ASSERT(game.Load("valid.wad", "E1M1", error));
	ASSERT(ABS(game.State().eye - 42.0 / 64) < 0.00000001);
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	DoomInventory.Reset(player);
	DoomHud.Draw(player, frame);
	ASSERT((frame.width = 400) & (frame.height = 240));
	ASSERT(frame.Pixel(0, frame.height - 24) = 010203H);
	ASSERT(frame.Pixel(0, frame.height - 25) = 0);
	ASSERT(frame.Pixel(8, frame.height - 24 + 3) = 0ABCDEFH);
	ASSERT(~DoomConfig.Load("doom-invalid.yaml", error));
	ASSERT((DoomConfig.values.width = 400) & (DoomConfig.values.hud.background = 010203H));
	ASSERT(DoomConfig.Load("doom.yaml", error))
END MovementAndPanel;

PROCEDURE {TEST} DoorParameters*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	player: DoomInventory.State;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	archive := DoomWad.Open("door.wad", error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error));
	DoomInventory.Reset(player);
	ASSERT(~map.doors.Use(map.world, -0.500001, 0, 0, player));
	ASSERT(map.doors.Use(map.world, -0.5, 0, 0, player));
	FOR i := 1 TO 30 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	ASSERT(map.world.Region(1).ceiling = 120.0 / 64);
	FOR i := 1 TO 10 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	ASSERT(map.world.Region(1).ceiling = 120.0 / 64);
	map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep);
	ASSERT(map.world.Region(1).ceiling = 116.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END DoorParameters;

PROCEDURE Do*;
BEGIN
	RequiredFile;
	DoomConfig.CompleteAndRequired;
	DoomConfig.PaletteBounds;
	DoomConfig.DemoAppearanceBounds;
	DoomConfig.RejectInvalidAndPreserve;
	DemoColors;
	DemoAppearance;
	MovementAndPanel;
	DoorParameters;
	DoomHud.Panel;
	KernelLog.String("DoomConfigSmoke: configuration and HUD {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomConfigSmoke.
