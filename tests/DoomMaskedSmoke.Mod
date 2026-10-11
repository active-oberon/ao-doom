MODULE DoomMaskedSmoke;

IMPORT DoomConfig, DoomWad, DoomTextures, DoomMap, GameMaterials, GameGeometry, GameSurface, GameRenderer, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Reject(CONST path: ARRAY OF CHAR);
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(error[0] # 0X)
END Reject;

PROCEDURE Do*;
VAR archive: DoomWad.Archive;
	library: DoomTextures.Library;
	texture: GameMaterials.Texture;
	map: DoomMap.Map;
	wall: GameGeometry.Wall;
	original, lowered: GameGeometry.World;
	heights: ARRAY 3 OF FLOAT64;
	plain, masked, bottom, layered: GameSurface.Frame;
	error: ARRAY 128 OF CHAR;
	x, y, feet, distance: FLOAT64;
	column, row, changed, holes, black: SIGNED32;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	archive := DoomWad.Open("masked.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("GRATE", error);
	ASSERT(texture # NIL);
	ASSERT(texture.SampleMasked(0.1, 0.3) = -1);
	ASSERT(texture.Sample(0.1, 0.3) = 0);
	ASSERT(texture.SampleMasked(0.1, 0.9) = 0);
	ASSERT(texture.SampleMasked(0.01, 0.3) = 0C87850H);
	ASSERT(library.Get("grate", error) = texture);
	archive := DoomWad.Open("masked-composite.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("GRATE", error);
	ASSERT(texture # NIL);
	ASSERT(texture.SampleMasked(0.01, 0.3) = 0C87850H);
	ASSERT(texture.SampleMasked(4.5 / 64, 0.3) = 05060B0H);
	ASSERT(texture.SampleMasked(9.5 / 64, 0.3) = -1);
	NEW(plain, 320, 200);
	NEW(masked, 320, 200);
	NEW(bottom, 320, 200);
	NEW(layered, 320, 200);
	Load("level-portal.wad", map);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	Load("masked.wad", map);
	ASSERT(map.world.CastSector(0, -2, 0, 1, 0, 0, distance, wall));
	ASSERT(wall.texture # NIL);
	GameRenderer.Render(map.world, masked, map.x, map.y, map.angle, map.eye);
	changed := 0;
	holes := 0;
	black := 0;
	FOR column := 0 TO 319 DO
		FOR row := 0 TO 199 DO
			IF masked.Pixel(column, row) # plain.Pixel(column, row) THEN
				INC(changed)
			END;
			IF masked.Pixel(column, row) = 0 THEN
				INC(black)
			END
		END;
		IF masked.Pixel(column, 30) = plain.Pixel(column, 30) THEN
			INC(holes)
		END;
		ASSERT(masked.Pixel(column, 100) = plain.Pixel(column, 100))
	END;
	ASSERT((changed > 1000) & (holes > 100) & (black > 100));
	ASSERT(masked.Save("masked-scene.ppm"));
	original := map.world;
	heights[0] := 2;
	heights[1] := 1.5;
	heights[2] := 2;
	lowered := original.WithCeilings(heights);
	ASSERT(lowered # NIL);
	GameRenderer.Render(lowered, bottom, map.x, map.y, map.angle, map.eye);
	ASSERT(bottom.Pixel(128, 100) # plain.Pixel(128, 100));
	GameRenderer.Render(original, bottom, map.x, map.y, map.angle, map.eye);
	ASSERT(bottom.Pixel(128, 100) = plain.Pixel(128, 100));
	x := map.x;
	y := map.y;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep));
	ASSERT(ABS(x - 2) < 0.000001);
	GameRenderer.Render(map.world, masked, 2, 0, MathL.pi, map.eye);
	ASSERT(masked.Pixel(128, 50) = 0);
	ASSERT(masked.Save("masked-reverse.ppm"));
	Load("masked-bottom.wad", map);
	GameRenderer.Render(map.world, bottom, map.x, map.y, map.angle, map.eye);
	ASSERT(bottom.Pixel(128, 100) # plain.Pixel(128, 100));
	ASSERT(bottom.Pixel(160, 100) = plain.Pixel(160, 100));
	Load("masked-layered.wad", map);
	GameRenderer.Render(map.world, layered, map.x, map.y, map.angle, map.eye);
	ASSERT(layered.Pixel(128, 100) = bottom.Pixel(128, 100));
	ASSERT(layered.Pixel(160, 100) = bottom.Pixel(160, 100));
	ASSERT(layered.Pixel(148, 100) # bottom.Pixel(148, 100));
	ASSERT(layered.Save("masked-layered.ppm"));
	Load("masked-offset.wad", map);
	GameRenderer.Render(map.world, masked, map.x, map.y, map.angle, map.eye);
	ASSERT(masked.Pixel(128, 20) # bottom.Pixel(128, 20));
	ASSERT(masked.Pixel(128, 0) = plain.Pixel(128, 0));
	ASSERT(masked.Pixel(144, 0) # plain.Pixel(144, 0));
	Load("tiered-portal.wad", map);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	Load("masked-tiered.wad", map);
	GameRenderer.Render(map.world, masked, map.x, map.y, map.angle, map.eye);
	ASSERT(masked.Pixel(128, 100) # plain.Pixel(128, 100));
	FOR column := 0 TO 319 DO
		ASSERT(masked.Pixel(column, 10) = plain.Pixel(column, 10));
		ASSERT(masked.Pixel(column, 150) = plain.Pixel(column, 150))
	END;
	Load("masked-same-sector.wad", map);
	ASSERT(map.world.CastSector(0, -2, 0, 1, 0, 0, distance, wall));
	ASSERT((wall.neighbor = 0) & (wall.texture # NIL));
	GameRenderer.Render(map.world, masked, map.x, map.y, map.angle, map.eye);
	ASSERT(masked.Pixel(128, 50) = 0);
	Load("masked-blocked.wad", map);
	x := map.x;
	y := map.y;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep));
	ASSERT(x < -DoomConfig.values.playerRadius);
	Reject("masked-unknown.wad");
	Reject("masked-no-end.wad")
END Do;

END DoomMaskedSmoke.
