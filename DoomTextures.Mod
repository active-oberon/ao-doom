MODULE DoomTextures;

IMPORT DoomWad, GameBytes, GameMaterials;

CONST MaximumPixels = 16 * 1024 * 1024;
	MaximumWork = 64 * 1024 * 1024;

TYPE
	Cached = POINTER TO RECORD
		name: ARRAY 9 OF CHAR;
		texture: GameMaterials.Texture;
		flat: BOOLEAN;
		next: Cached
	END;

	Library* = OBJECT
	VAR archive: DoomWad.Archive;
		palette, names, first, second: DoomWad.Lump;
		cache: Cached;
		pixels, work: SIGNED32;

		PROCEDURE &Init(source: DoomWad.Archive);
		BEGIN
			archive := source;
			cache := NIL;
			pixels := 0;
			work := 0
		END Init;

		PROCEDURE Validate(VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR index, count: SIGNED32;
		BEGIN
			index := archive.Find("PLAYPAL");
			IF index < 0 THEN
				COPY("Texture resources require PLAYPAL", error);
				RETURN FALSE
			END;
			palette := archive.Entry(index);
			IF palette.size < 768 THEN
				COPY("PLAYPAL is shorter than one RGB palette", error);
				RETURN FALSE
			END;
			index := archive.Find("PNAMES");
			IF index < 0 THEN
				COPY("Texture resources require PNAMES", error);
				RETURN FALSE
			END;
			names := archive.Entry(index);
			IF names.size < 4 THEN
				COPY("PNAMES header is truncated", error);
				RETURN FALSE
			END;
			count := GameBytes.I32(archive.data^, names.offset);
			IF (count < 0) OR (count > 65536) THEN
				COPY("PNAMES count is invalid", error);
				RETURN FALSE
			END;
			IF ~Within(names, names.offset + 4, count * 8) THEN
				COPY("PNAMES table is truncated", error);
				RETURN FALSE
			END;
			index := archive.Find("TEXTURE1");
			IF index < 0 THEN
				COPY("Texture resources require TEXTURE1", error);
				RETURN FALSE
			END;
			first := archive.Entry(index);
			IF ~Directory(first, error) THEN
				RETURN FALSE
			END;
			second.size := 0;
			index := archive.Find("TEXTURE2");
			IF index >= 0 THEN
				second := archive.Entry(index);
				IF ~Directory(second, error) THEN
					RETURN FALSE
				END
			END;
			RETURN TRUE
		END Validate;

		PROCEDURE Directory(CONST table: DoomWad.Lump; VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR count: SIGNED32;
		BEGIN
			IF table.size < 4 THEN
				COPY("Texture directory header is truncated", error);
				RETURN FALSE
			END;
			count := GameBytes.I32(archive.data^, table.offset);
			IF (count < 0) OR (count > 65536) THEN
				COPY("Texture directory count is invalid", error);
				RETURN FALSE
			END;
			IF ~Within(table, table.offset + 4, count * 4) THEN
				COPY("Texture directory offsets are truncated", error);
				RETURN FALSE
			END;
			RETURN TRUE
		END Directory;

		PROCEDURE Find(CONST table: DoomWad.Lump; CONST name: ARRAY OF CHAR;
			VAR offset: SIGNED32; VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR i, count, relative: SIGNED32;
			entry: ARRAY 9 OF CHAR;
		BEGIN
			IF table.size = 0 THEN
				RETURN FALSE
			END;
			count := GameBytes.I32(archive.data^, table.offset);
			FOR i := 0 TO count - 1 DO
				relative := GameBytes.I32(archive.data^, table.offset + 4 + i * 4);
				IF (relative < 0) OR (relative > table.size) THEN
					COPY("Texture record offset is outside its lump", error);
					RETURN FALSE
				END;
				offset := table.offset + relative;
				IF ~Within(table, offset, 22) THEN
					COPY("Texture record header is truncated", error);
					RETURN FALSE
				END;
				Name(archive.data^, offset, entry);
				IF entry = name THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END Find;

		PROCEDURE Patch(texture: GameMaterials.Texture; CONST patch: DoomWad.Lump;
			originX, originY: SIGNED32; VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR width, height, x, row, column, relative, top, length,
			i, paletteIndex, color, red, green, blue, destinationX, destinationY: SIGNED32;
		BEGIN
			IF patch.size < 8 THEN
				COPY("Patch header is truncated", error);
				RETURN FALSE
			END;
			width := GameBytes.U16(archive.data^, patch.offset);
			height := GameBytes.U16(archive.data^, patch.offset + 2);
			IF (width < 1) OR (width > 1024) OR (height < 1) OR (height > 1024) THEN
				COPY("Patch dimensions are invalid or exceed 1024", error);
				RETURN FALSE
			END;
			IF ~Within(patch, patch.offset + 8, width * 4) THEN
				COPY("Patch column table is truncated", error);
				RETURN FALSE
			END;
			FOR x := 0 TO width - 1 DO
				IF work = MaximumWork THEN
					COPY("Texture decode work exceeds the resource budget", error);
					RETURN FALSE
				END;
				INC(work);
				relative := GameBytes.I32(archive.data^, patch.offset + 8 + x * 4);
				IF (relative < 8 + width * 4) OR (relative >= patch.size) THEN
					COPY("Patch column offset is outside its pixel data", error);
					RETURN FALSE
				END;
				column := patch.offset + relative;
				LOOP
					IF ~Within(patch, column, 1) THEN
						COPY("Patch column has no terminator", error);
						RETURN FALSE
					END;
					top := ORD(archive.data[column]);
					IF top = 255 THEN
						EXIT
					END;
					IF ~Within(patch, column, 4) THEN
						COPY("Patch post header is truncated", error);
						RETURN FALSE
					END;
					length := ORD(archive.data[column + 1]);
					IF ~Within(patch, column, length + 4) OR (top + length > height) THEN
						COPY("Patch post pixels are outside the column", error);
						RETURN FALSE
					END;
					IF length + 1 > MaximumWork - work THEN
						COPY("Texture decode work exceeds the resource budget", error);
						RETURN FALSE
					END;
					INC(work, length + 1);
					destinationX := originX + x;
					FOR row := 0 TO length - 1 DO
						destinationY := originY + top + row;
						IF (destinationX >= 0) & (destinationX < texture.width) &
							(destinationY >= 0) & (destinationY < texture.height) THEN
							paletteIndex := ORD(archive.data[column + 3 + row]);
							i := palette.offset + paletteIndex * 3;
							red := ORD(archive.data[i]);
							green := ORD(archive.data[i + 1]);
							blue := ORD(archive.data[i + 2]);
							color := red * 65536 + green * 256 + blue;
							texture.Set(destinationX, destinationY, color)
						END
					END;
					INC(column, length + 4)
				END
			END;
			RETURN TRUE
		END Patch;

		PROCEDURE Get*(CONST name: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): GameMaterials.Texture;
		VAR found: Cached;
			table, patch: DoomWad.Lump;
			offset, width, height, count, patchCount, i, position, index,
			originX, originY, lump: SIGNED32;
			patchName, wanted: ARRAY 9 OF CHAR;
			texture: GameMaterials.Texture;
		BEGIN
			error[0] := 0X;
			i := 0;
			WHILE (i < LEN(name)) & (name[i] # 0X) DO
				IF i = 8 THEN
					COPY("Texture name exceeds eight characters", error);
					RETURN NIL
				END;
				wanted[i] := CAP(name[i]);
				INC(i)
			END;
			wanted[i] := 0X;
			found := cache;
			WHILE found # NIL DO
				IF (found.name = wanted) & ~found.flat THEN
					RETURN found.texture
				END;
				found := found.next
			END;
			table := first;
			IF ~Find(table, wanted, offset, error) THEN
				IF error[0] # 0X THEN
					RETURN NIL
				END;
				table := second;
				IF ~Find(table, wanted, offset, error) THEN
					IF error[0] = 0X THEN
						COPY("Wall texture is not defined in TEXTURE1 or TEXTURE2", error)
					END;
					RETURN NIL
				END
			END;
			width := GameBytes.U16(archive.data^, offset + 12);
			height := GameBytes.U16(archive.data^, offset + 14);
			count := GameBytes.U16(archive.data^, offset + 20);
			IF (width < 1) OR (width > 1024) OR (height < 1) OR (height > 1024) OR
				(count < 1) OR (count > 4096) THEN
				COPY("Texture dimensions or patch count are invalid", error);
				RETURN NIL
			END;
			IF ~Within(table, offset + 22, count * 10) THEN
				COPY("Texture patch list is truncated", error);
				RETURN NIL
			END;
			IF width * height > MaximumPixels - pixels THEN
				COPY("Texture cache exceeds 16 million pixels", error);
				RETURN NIL
			END;
			NEW(texture, width, height);
			patchCount := GameBytes.I32(archive.data^, names.offset);
			FOR i := 0 TO count - 1 DO
				position := offset + 22 + i * 10;
				originX := GameBytes.I16(archive.data^, position);
				originY := GameBytes.I16(archive.data^, position + 2);
				index := GameBytes.U16(archive.data^, position + 4);
				IF index >= patchCount THEN
					COPY("Texture references an invalid PNAMES index", error);
					RETURN NIL
				END;
				Name(archive.data^, names.offset + 4 + index * 8, patchName);
				lump := archive.Find(patchName);
				IF lump < 0 THEN
					COPY("Texture patch lump is missing", error);
					RETURN NIL
				END;
				patch := archive.Entry(lump);
				IF ~Patch(texture, patch, originX, originY, error) THEN
					RETURN NIL
				END
			END;
			texture.Seal;
			INC(pixels, width * height);
			NEW(found);
			COPY(wanted, found.name);
			found.texture := texture;
			found.flat := FALSE;
			found.next := cache;
			cache := found;
			RETURN texture
		END Get;

		PROCEDURE Flat*(CONST name: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): GameMaterials.Texture;
		VAR found: Cached;
			wanted: ARRAY 9 OF CHAR;
			index, i, position, color, red, green, blue: SIGNED32;
			lump: DoomWad.Lump;
			texture: GameMaterials.Texture;
		BEGIN
			error[0] := 0X;
			i := 0;
			WHILE (i < LEN(name)) & (name[i] # 0X) DO
				IF i = 8 THEN
					COPY("Flat name exceeds eight characters", error);
					RETURN NIL
				END;
				wanted[i] := CAP(name[i]);
				INC(i)
			END;
			wanted[i] := 0X;
			found := cache;
			WHILE found # NIL DO
				IF (found.name = wanted) & found.flat THEN
					RETURN found.texture
				END;
				found := found.next
			END;
			index := archive.Find(wanted);
			IF index < 0 THEN
				COPY("Sector flat lump is missing", error);
				RETURN NIL
			END;
			lump := archive.Entry(index);
			IF lump.size # 4096 THEN
				COPY("Sector flat must contain 4096 palette indices", error);
				RETURN NIL
			END;
			IF (4096 > MaximumPixels - pixels) OR (4096 > MaximumWork - work) THEN
				COPY("Flat decoding exceeds the texture resource budget", error);
				RETURN NIL
			END;
			NEW(texture, 64, 64);
			FOR i := 0 TO 4095 DO
				position := palette.offset + ORD(archive.data[lump.offset + i]) * 3;
				red := ORD(archive.data[position]);
				green := ORD(archive.data[position + 1]);
				blue := ORD(archive.data[position + 2]);
				color := red * 65536 + green * 256 + blue;
				texture.Set(i MOD 64, i DIV 64, color)
			END;
			texture.Seal;
			INC(pixels, 4096);
			INC(work, 4096);
			NEW(found);
			COPY(wanted, found.name);
			found.texture := texture;
			found.flat := TRUE;
			found.next := cache;
			cache := found;
			RETURN texture
		END Flat;
	END Library;

PROCEDURE Within(CONST lump: DoomWad.Lump; offset, size: SIGNED32): BOOLEAN;
BEGIN
	RETURN (offset >= lump.offset) & (offset <= lump.offset + lump.size) &
		(size >= 0) & (size <= lump.offset + lump.size - offset)
END Within;

PROCEDURE Name(CONST data: ARRAY OF CHAR; offset: SIGNED32; VAR name: ARRAY OF CHAR);
VAR i: SIGNED32;
	value: CHAR;
BEGIN
	ASSERT(GameBytes.Range(data, offset, 8));
	ASSERT(LEN(name) >= 9);
	FOR i := 0 TO 7 DO
		value := data[offset + i];
		IF (value >= "a") & (value <= "z") THEN
			value := CHR(ORD(value) - ORD("a") + ORD("A"))
		END;
		name[i] := value
	END;
	name[8] := 0X
END Name;

PROCEDURE Open*(archive: DoomWad.Archive; VAR error: ARRAY OF CHAR): Library;
VAR library: Library;
BEGIN
	error[0] := 0X;
	NEW(library, archive);
	IF ~library.Validate(error) THEN
		RETURN NIL
	END;
	RETURN library
END Open;

END DoomTextures.
