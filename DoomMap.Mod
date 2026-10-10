MODULE DoomMap;

IMPORT DoomWad, DoomTextures, GameBytes, GameGeometry, MathL;

TYPE
	Map* = RECORD
		world*: GameGeometry.World;
		x*, y*, angle*, eye*: FLOAT64
	END;

PROCEDURE MapLump(archive: DoomWad.Archive; index: SIGNED32;
	CONST name: ARRAY OF CHAR; stride: SIGNED32; VAR lump: DoomWad.Lump): BOOLEAN;
BEGIN
	IF (index < 0) OR (index >= archive.Count()) THEN
		RETURN FALSE
	END;
	lump := archive.Entry(index);
	RETURN (lump.name = name) & (lump.size > 0) & (lump.size MOD stride = 0)
END MapLump;

PROCEDURE Inside(archive: DoomWad.Archive; CONST lines, vertices: DoomWad.Lump; x, y: FLOAT64): BOOLEAN;
VAR i, offset, v1, v2: SIGNED32;
	ax, ay, bx, by, crossing: FLOAT64;
	inside: BOOLEAN;
BEGIN
	inside := FALSE;
	FOR i := 0 TO lines.size DIV 14 - 1 DO
		offset := lines.offset + i * 14;
		IF GameBytes.U16(archive.data^, offset + 12) = 65535 THEN
			v1 := GameBytes.U16(archive.data^, offset);
			v2 := GameBytes.U16(archive.data^, offset + 2);
			ax := GameBytes.I16(archive.data^, vertices.offset + v1 * 4) / 64.0;
			ay := -GameBytes.I16(archive.data^, vertices.offset + v1 * 4 + 2) / 64.0;
			bx := GameBytes.I16(archive.data^, vertices.offset + v2 * 4) / 64.0;
			by := -GameBytes.I16(archive.data^, vertices.offset + v2 * 4 + 2) / 64.0;
			IF (ay > y) # (by > y) THEN
				crossing := ax + (y - ay) * (bx - ax) / (by - ay);
				IF crossing > x THEN
					inside := ~inside
				END
			END
		END
	END;
	RETURN inside
END Inside;

PROCEDURE LoadMap*(archive: DoomWad.Archive; CONST name: ARRAY OF CHAR;
	VAR map: Map; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR marker, i, offset, v1, v2, front, back, flags, start,
	vertexCount, sideCount, sector, color, light, result: SIGNED32;
	things, lines, sides, vertices, sectors: DoomWad.Lump;
	wall: GameGeometry.Wall;
	world: GameGeometry.World;
	textures: DoomTextures.Library;
	textureName: ARRAY 9 OF CHAR;
	j: SIGNED32;
	degree: POINTER TO ARRAY OF SIGNED32;
	x, y, angle, floor, ceiling: FLOAT64;
BEGIN
	map.world := NIL;
	error[0] := 0X;
	marker := archive.Find(name);
	IF (marker < 0) OR
		~MapLump(archive, marker + 1, "THINGS", 10, things) OR
		~MapLump(archive, marker + 2, "LINEDEFS", 14, lines) OR
		~MapLump(archive, marker + 3, "SIDEDEFS", 30, sides) OR
		~MapLump(archive, marker + 4, "VERTEXES", 4, vertices) OR
		~MapLump(archive, marker + 8, "SECTORS", 26, sectors) THEN
		COPY("Missing or malformed classic Doom map lumps", error);
		RETURN FALSE
	END;
	IF sectors.size # 26 THEN
		COPY("This renderer currently supports single-sector maps only", error);
		RETURN FALSE
	END;
	vertexCount := vertices.size DIV 4;
	sideCount := sides.size DIV 30;
	IF (lines.size DIV 14 > 65536) OR (sideCount > 65536) OR (vertexCount > 65536) THEN
		COPY("Map record count exceeds 65536", error);
		RETURN FALSE
	END;
	floor := GameBytes.I16(archive.data^, sectors.offset) / 64.0;
	ceiling := GameBytes.I16(archive.data^, sectors.offset + 2) / 64.0;
	IF ceiling - floor < 56.0 / 64 THEN
		COPY("Sector has insufficient player clearance", error);
		RETURN FALSE
	END;
	light := GameBytes.I16(archive.data^, sectors.offset + 20);
	IF (light < 0) OR (light > 255) THEN
		COPY("Sector light level must be between 0 and 255", error);
		RETURN FALSE
	END;
	color := 0A07850H;
	FOR i := 0 TO sideCount - 1 DO
		sector := GameBytes.U16(archive.data^, sides.offset + i * 30 + 28);
		IF sector # 0 THEN
			COPY("SIDEDEFS references an invalid sector", error);
			RETURN FALSE
		END
	END;
	textures := NIL;
	IF archive.Find("TEXTURE1") >= 0 THEN
		textures := DoomTextures.Open(archive, error);
		IF textures = NIL THEN
			RETURN FALSE
		END
	END;
	NEW(world, lines.size DIV 14);
	NEW(degree, vertexCount);
	FOR i := 0 TO lines.size DIV 14 - 1 DO
		offset := lines.offset + i * 14;
		v1 := GameBytes.U16(archive.data^, offset);
		v2 := GameBytes.U16(archive.data^, offset + 2);
		flags := GameBytes.U16(archive.data^, offset + 4);
		front := GameBytes.U16(archive.data^, offset + 10);
		back := GameBytes.U16(archive.data^, offset + 12);
		IF (v1 >= vertexCount) OR (v2 >= vertexCount) OR (front >= sideCount) OR
			((back # 65535) & (back >= sideCount)) THEN
			COPY("LINEDEFS references an invalid vertex or sidedef", error);
			RETURN FALSE
		END;
		IF v1 = v2 THEN
			COPY("Map contains a degenerate linedef", error);
			RETURN FALSE
		END;
		IF back = 65535 THEN
			INC(degree[v1]);
			INC(degree[v2])
		END;
		IF (back = 65535) OR (flags MOD 2 = 1) THEN
			wall.ax := GameBytes.I16(archive.data^, vertices.offset + v1 * 4) / 64.0;
			wall.ay := -GameBytes.I16(archive.data^, vertices.offset + v1 * 4 + 2) / 64.0;
			wall.bx := GameBytes.I16(archive.data^, vertices.offset + v2 * 4) / 64.0;
			wall.by := -GameBytes.I16(archive.data^, vertices.offset + v2 * 4 + 2) / 64.0;
			wall.bottom := floor;
			wall.top := ceiling;
			wall.color := color;
			wall.light := light;
			wall.texture := NIL;
			IF textures # NIL THEN
				FOR j := 0 TO 7 DO
					textureName[j] := CAP(archive.data[sides.offset + front * 30 + 20 + j])
				END;
				textureName[8] := 0X;
				wall.texture := textures.Get(textureName, error);
				IF wall.texture = NIL THEN
					RETURN FALSE
				END;
				wall.uScale := 64.0 / wall.texture.width;
				wall.vScale := 64.0 / wall.texture.height;
				wall.uOffset := GameBytes.I16(archive.data^, sides.offset + front * 30) /
					FLOAT64(wall.texture.width);
				wall.vOffset := GameBytes.I16(archive.data^, sides.offset + front * 30 + 2) /
					FLOAT64(wall.texture.height);
				IF flags DIV 16 MOD 2 = 1 THEN
					wall.vOffset := wall.vOffset + (floor - ceiling) * wall.vScale
				END
			END;
			IF ~world.Add(wall) THEN
				COPY("Map contains a degenerate wall", error);
				RETURN FALSE
			END
		END
	END;
	FOR i := 0 TO vertexCount - 1 DO
		IF (degree[i] # 0) & (degree[i] # 2) THEN
			COPY("Single-sector boundary must form closed contours", error);
			RETURN FALSE
		END
	END;
	world.Seal;
	start := -1;
	FOR i := 0 TO things.size DIV 10 - 1 DO
		offset := things.offset + i * 10;
		IF (start < 0) & (GameBytes.I16(archive.data^, offset + 6) = 1) THEN
			start := offset
		END
	END;
	IF start < 0 THEN
		COPY("Map has no player-one start", error);
		RETURN FALSE
	END;
	x := GameBytes.I16(archive.data^, start) / 64.0;
	y := -GameBytes.I16(archive.data^, start + 2) / 64.0;
	result := GameBytes.I16(archive.data^, start + 4) MOD 360;
	angle := -result * MathL.pi / 180;
	IF angle < -MathL.pi THEN
		angle := angle + MathL.pi * 2
	END;
	IF (world.Count() = 0) OR ~world.Free(x, y, 0.25) OR ~Inside(archive, lines, vertices, x, y) THEN
		COPY("Player start is outside the sector or intersects a wall", error);
		RETURN FALSE
	END;
	map.world := world;
	map.x := x;
	map.y := y;
	map.angle := angle;
	map.eye := floor + 41.0 / 64;
	RETURN TRUE
END LoadMap;

END DoomMap.
