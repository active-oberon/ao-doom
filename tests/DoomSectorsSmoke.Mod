MODULE DoomSectorsSmoke;

IMPORT Doom, DoomWad, DoomMap, GameGeometry, GameSurface, GameRenderer, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Blocked(CONST path: ARRAY OF CHAR);
VAR map: DoomMap.Map;
	x, y, feet: FLOAT64;
BEGIN
	Load(path, map);
	x := map.x;
	y := map.y;
	feet := map.eye - Doom.PlayerEye;
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 1, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT((x < -Doom.PlayerRadius) & (x > -0.4));
	ASSERT(ABS(y - 1) < 0.000001);
	ASSERT(feet = 0)
END Blocked;

PROCEDURE Covered(frame: GameSurface.Frame);
VAR x, y, color: SIGNED32;
BEGIN
	FOR y := 0 TO frame.height - 1 DO
		FOR x := 0 TO frame.width - 1 DO
			color := frame.Pixel(x, y);
			ASSERT((color # 0202938H) & (color # 035302CH))
		END
	END
END Covered;

PROCEDURE Do*;
VAR map: DoomMap.Map;
	game: Doom.Game;
	pose: Doom.Pose;
	wall: GameGeometry.Wall;
	frame: GameSurface.Frame;
	x, y, feet, distance: FLOAT64;
	error: ARRAY 128 OF CHAR;
	i, farColor, lowerColor, upperColor: SIGNED32;
BEGIN
	Load("sectors.wad", map);
	ASSERT(map.world.SectorCount() = 3);
	ASSERT(map.world.Count() = 12);
	ASSERT(map.world.Locate(-2, 0) = 0);
	ASSERT(map.world.Locate(2, 0) = 1);
	ASSERT(map.world.Locate(6, 0) = 2);
	ASSERT(map.world.Locate(9, 0) = -1);
	ASSERT(map.world.CastSector(0, -2, 0, 1, 0, 0, distance, wall));
	ASSERT((distance = 2) & (wall.neighbor = 1));
	ASSERT(map.world.CastSector(1, -2, 0, 1, 0, distance, distance, wall));
	ASSERT((distance = 6) & (wall.neighbor = 2));
	ASSERT(map.world.CastSector(2, -2, 0, 1, 0, distance, distance, wall));
	ASSERT((distance = 10) & (wall.neighbor = -1));
	NEW(frame, 320, 200);
	GameRenderer.Render(map.world, frame, map.x, map.y, map.angle, map.eye);
	ASSERT(frame.Save("sectors-scene.ppm"));
	Covered(frame);
	farColor := frame.Pixel(160, 100);
	lowerColor := frame.Pixel(160, 150);
	upperColor := frame.Pixel(160, 10);
	ASSERT((farColor # 0202938H) & (farColor # 035302CH));
	ASSERT((lowerColor # farColor) & (upperColor # farColor));
	ASSERT(frame.Pixel(160, 199) # 035302CH);
	x := map.x;
	y := map.y;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT(ABS(x - 2) < 0.000001);
	ASSERT(feet = Doom.PlayerStep);
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT(ABS(x - 6) < 0.000001);
	ASSERT(feet = 0);
	ASSERT(map.world.MovePlayer(x, y, feet, -8, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT(ABS(x + 2) < 0.000001);
	ASSERT(feet = 0);
	ASSERT(map.world.MovePlayer(x, y, feet, 30, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT((x < 8 - Doom.PlayerRadius) & (x > 7.6));
	Blocked("blocked-portal.wad");
	Blocked("high-step.wad");
	Blocked("low-portal.wad");
	Blocked("closed-portal.wad");
	Load("blocked-portal.wad", map);
	GameRenderer.Render(map.world, frame, map.x, map.y, map.angle, map.eye);
	ASSERT(frame.Pixel(160, 100) = farColor);
	Load("closed-portal.wad", map);
	GameRenderer.Render(map.world, frame, map.x, map.y, map.angle, map.eye);
	Covered(frame);
	Load("level-portal.wad", map);
	FOR i := 0 TO 7 DO
		GameRenderer.Render(map.world, frame, map.x, map.y, i * MathL.pi / 4, map.eye);
		Covered(frame)
	END;
	x := map.x;
	y := map.y;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 8, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT(ABS(x - 6) < 0.000001);
	Load("high-step.wad", map);
	x := 2;
	y := 0;
	feet := 25.0 / 64;
	ASSERT(map.world.MovePlayer(x, y, feet, -4, 0, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
	ASSERT(ABS(x + 2) < 0.000001);
	ASSERT(feet = 0);
	NEW(game);
	ASSERT(game.Load("sectors.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 45 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x > 2) & (pose.x < 2.1));
	ASSERT(ABS(pose.eye - Doom.PlayerEye - Doom.PlayerStep) < 0.000001);
	game.Render(frame);
	ASSERT(frame.Save("sectors-walk.ppm"));
	FOR i := 46 TO 95 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x > 6.5) & (pose.x < 6.6));
	ASSERT(ABS(pose.eye - Doom.PlayerEye) < 0.000001);
	game.Render(frame);
	ASSERT(frame.Save("sectors-far.ppm"));
	game.Controls(0, 0, 1);
	FOR i := 96 TO 143 DO
		game.Step(i)
	END;
	game.Render(frame);
	Covered(frame);
	ASSERT(frame.Save("sectors-reverse.ppm"))
END Do;

END DoomSectorsSmoke.
