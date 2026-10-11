MODULE DoomConfigSmoke;

IMPORT DoomConfig, Doom, DoomHud, DoomInventory, DoomWad, DoomMap, GameSurface;

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
	MovementAndPanel;
	DoorParameters
END Do;

END DoomConfigSmoke.
