MODULE DoomSpritesSmoke;

IMPORT DoomConfig, Doom, DoomWad, DoomMap, DoomTextures, DoomThings, GameGeometry, GameRenderer, GameSurface, GameMaterials, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Render(CONST map: DoomMap.Map; frame: GameSurface.Frame);
BEGIN
	GameRenderer.Render(map.world, frame, map.x, map.y, map.angle, map.eye);
	map.sprites.Render(map.world, frame, map.x, map.y, map.angle, map.eye)
END Render;

PROCEDURE Difference(first, second: GameSurface.Frame): SIGNED32;
VAR column, row, count: SIGNED32;
BEGIN
	count := 0;
	FOR column := 0 TO first.width - 1 DO
		FOR row := 0 TO first.height - 1 DO
			IF first.Pixel(column, row) # second.Pixel(column, row) THEN
				INC(count)
			END
		END
	END;
	RETURN count
END Difference;

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
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	library: DoomTextures.Library;
	texture: GameMaterials.Texture;
	plain, sprites, other: GameSurface.Frame;
	game: Doom.Game;
	lowered: GameGeometry.World;
	heights: ARRAY 1 OF FLOAT64;
	info: DoomThings.Info;
	index, left, top, column: SIGNED32;
	error: ARRAY 128 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	ASSERT(DoomThings.Lookup(3004, info));
	ASSERT(info.name = "POSSA");
	ASSERT(DoomThings.Lookup(49, info));
	ASSERT(info.ceiling & (info.height = 68));
	ASSERT(DoomThings.Lookup(85, info));
	ASSERT(info.fullbright);
	ASSERT(~DoomThings.Lookup(14, info));
	ASSERT(~DoomThings.Lookup(9999, info));
	archive := DoomWad.Open("sprites.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	index := archive.Find("BON2A0");
	texture := library.Sprite(index, left, top, error);
	ASSERT(texture # NIL);
	ASSERT((left = 16) & (top = 64));
	ASSERT((texture.width = 32) & (texture.height = 64));
	ASSERT(texture.SampleMasked(0.25, 0.2) = 0);
	ASSERT(texture.SampleMasked(0.5, 0.2) = 0FF40C0H);
	ASSERT(texture.SampleMasked(0.5, 0.5) = -1);
	ASSERT(library.Sprite(index, left, top, error) = texture);
	ASSERT(library.Sprite(-1, left, top, error) = NIL);
	ASSERT(error[0] # 0X);
	NEW(plain, 320, 200);
	NEW(sprites, 320, 200);
	NEW(other, 320, 200);
	Load("sprites.wad", map);
	ASSERT(map.sprites.Count() = 1);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	Render(map, sprites);
	ASSERT(Difference(plain, sprites) > 1000);
	ASSERT(sprites.Pixel(140, 80) = 0);
	ASSERT(sprites.Pixel(160, 80) # plain.Pixel(160, 80));
	ASSERT(sprites.Pixel(160, 115) = plain.Pixel(160, 115));
	ASSERT(sprites.Save("sprites-scene.ppm"));
	Load("sprites-layered.wad", map);
	Render(map, sprites);
	Load("sprites-reordered.wad", map);
	Render(map, other);
	ASSERT(Difference(sprites, other) = 0);
	ASSERT(sprites.Save("sprites-layered.ppm"));
	Load("masked-bottom.wad", map);
	Render(map, plain);
	Load("sprites-grate.wad", map);
	Render(map, sprites);
	ASSERT(Difference(plain, sprites) > 100);
	ASSERT(sprites.Pixel(152, 100) = plain.Pixel(152, 100));
	ASSERT(plain.Pixel(152, 100) # 0);
	ASSERT(sprites.Pixel(160, 100) # plain.Pixel(160, 100));
	FOR column := 0 TO 319 DO
		IF plain.Pixel(column, 100) = 0 THEN
			ASSERT(sprites.Pixel(column, 100) = 0)
		END
	END;
	ASSERT(sprites.Save("sprites-grate.ppm"));
	Load("sprites-front-grate.wad", map);
	Render(map, other);
	ASSERT(Difference(sprites, other) > 1000);
	ASSERT((other.Pixel(128, 90) = 0) & (plain.Pixel(128, 90) # 0));
	Load("sprites-closed.wad", map);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	Render(map, sprites);
	ASSERT(Difference(plain, sprites) = 0);
	Load("sprites-hidden-wall.wad", map);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	Render(map, sprites);
	ASSERT(Difference(plain, sprites) = 0);
	Load("sprites-flags.wad", map);
	ASSERT(map.sprites.Count() = 1);
	Load("sprites-ceiling.wad", map);
	sprites.Background(0202938H, 035302CH);
	map.sprites.Render(map.world, sprites, map.x, map.y, map.angle, map.eye);
	ASSERT(sprites.Pixel(160, 80) = 0202938H);
	heights[0] := 1.5;
	lowered := map.world.WithCeilings(heights);
	ASSERT(lowered # NIL);
	other.Background(0202938H, 035302CH);
	map.sprites.Render(lowered, other, map.x, map.y, map.angle, map.eye);
	ASSERT(other.Pixel(160, 80) # 0202938H);
	plain.Background(0202938H, 035302CH);
	map.sprites.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	ASSERT(Difference(plain, sprites) = 0);
	Load("sprites-fullbright.wad", map);
	Render(map, sprites);
	ASSERT(sprites.Pixel(160, 80) = 0FF40C0H);
	Load("sprite-last-lump.wad", map);
	Render(map, sprites);
	ASSERT(sprites.Pixel(160, 80) DIV 65536 < 80);
	Load("sprite-rotations.wad", map);
	GameRenderer.Render(map.world, plain, 3, 0, MathL.pi, map.eye);
	map.sprites.Render(map.world, plain, 3, 0, MathL.pi, map.eye);
	GameRenderer.Render(map.world, sprites, 2, -2, MathL.pi / 2, map.eye);
	map.sprites.Render(map.world, sprites, 2, -2, MathL.pi / 2, map.eye);
	GameRenderer.Render(map.world, other, 2, 2, -MathL.pi / 2, map.eye);
	map.sprites.Render(map.world, other, 2, 2, -MathL.pi / 2, map.eye);
	ASSERT(plain.Pixel(160, 80) # sprites.Pixel(160, 80));
	ASSERT(sprites.Pixel(148, 80) = 0);
	ASSERT(other.Pixel(180, 80) = 0);
	ASSERT(plain.Save("sprites-facing.ppm"));
	NEW(game);
	ASSERT(game.Load("sprites.wad", "E1M1", error));
	game.Render(plain);
	ASSERT(~game.Load("sprite-missing.wad", "E1M1", error));
	game.Render(sprites);
	ASSERT(Difference(plain, sprites) = 0);
	Reject("sprite-missing.wad");
	Reject("sprite-short.wad");
	Reject("sprite-no-end.wad");
	Reject("sprite-dimensions.wad");
	Reject("sprite-outside.wad");
	Reject("sprite-missing-rotation.wad");
	Reject("sprite-mixed-rotations.wad");
	Reject("sprite-duplicate-rotation.wad");
	Reject("sprite-invalid-rotation.wad");
	Reject("sprites-no-resources.wad");
	Reject("sprites-too-many.wad")
END Do;

END DoomSpritesSmoke.
