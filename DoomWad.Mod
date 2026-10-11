MODULE DoomWad;

IMPORT DoomFormat, GameBytes;

TYPE
	Lump* = RECORD
		offset*, size*: SIGNED32;
		name*: ARRAY DoomFormat.NameLength + 1 OF CHAR
	END;

	Archive* = OBJECT
	VAR data-: GameBytes.Buffer;
		lumps: POINTER TO ARRAY OF Lump;

		PROCEDURE &Init(bytes: GameBytes.Buffer);
		BEGIN
			data := bytes
		END Init;

		PROCEDURE Validate(VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR count, directory, i, j, offset: SIGNED32;
			magic: ARRAY 5 OF CHAR;
		BEGIN
			IF ~GameBytes.Range(data^, 0, DoomFormat.HeaderSize) THEN
				COPY("WAD header is truncated", error);
				RETURN FALSE
			END;
			FOR i := 0 TO 3 DO
				magic[i] := data[i]
			END;
			magic[4] := 0X;
			IF (magic # "IWAD") & (magic # "PWAD") THEN
				COPY("Not an IWAD or PWAD", error);
				RETURN FALSE
			END;
			count := GameBytes.I32(data^, 4);
			directory := GameBytes.I32(data^, 8);
			IF (count < 0) OR (count > DoomFormat.MaximumRecords) THEN
				COPY("WAD directory count is invalid or exceeds 65536", error);
				RETURN FALSE
			END;
			IF ~GameBytes.Range(data^, directory, count * DoomFormat.DirectorySize) THEN
				COPY("WAD directory is outside the file", error);
				RETURN FALSE
			END;
			NEW(lumps, count);
			FOR i := 0 TO count - 1 DO
				offset := directory + i * DoomFormat.DirectorySize;
				lumps[i].offset := GameBytes.I32(data^, offset);
				lumps[i].size := GameBytes.I32(data^, offset + 4);
				IF ~GameBytes.Range(data^, lumps[i].offset, lumps[i].size) THEN
					COPY("WAD lump is outside the file", error);
					RETURN FALSE
				END;
				FOR j := 0 TO DoomFormat.NameLength - 1 DO
					lumps[i].name[j] := Upper(data[offset + 8 + j])
				END;
				lumps[i].name[DoomFormat.NameLength] := 0X
			END;
			RETURN TRUE
		END Validate;

		PROCEDURE Count*(): SIGNED32;
		BEGIN
			RETURN SIGNED32(LEN(lumps^))
		END Count;

		PROCEDURE Entry*(index: SIGNED32): Lump;
		BEGIN
			ASSERT((index >= 0) & (index < LEN(lumps^)));
			RETURN lumps[index]
		END Entry;

		PROCEDURE Find*(CONST name: ARRAY OF CHAR): SIGNED32;
		VAR i, j: SIGNED32;
			wanted: ARRAY DoomFormat.NameLength + 1 OF CHAR;
		BEGIN
			j := 0;
			WHILE (j < LEN(name)) & (name[j] # 0X) DO
				IF j = DoomFormat.NameLength THEN
					RETURN -1
				END;
				wanted[j] := Upper(name[j]);
				INC(j)
			END;
			wanted[j] := 0X;
			FOR i := SIGNED32(LEN(lumps^)) - 1 TO 0 BY -1 DO
				IF lumps[i].name = wanted THEN
					RETURN i
				END
			END;
			RETURN -1
		END Find;
	END Archive;

PROCEDURE Upper(value: CHAR): CHAR;
BEGIN
	IF (value >= "a") & (value <= "z") THEN
		RETURN CHR(ORD(value) - ORD("a") + ORD("A"))
	END;
	RETURN value
END Upper;

PROCEDURE Open*(CONST path: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): Archive;
VAR bytes: GameBytes.Buffer;
	archive: Archive;
BEGIN
	error[0] := 0X;
	bytes := GameBytes.Load(path);
	IF bytes = NIL THEN
		COPY("Cannot read WAD or file exceeds 64 MiB", error);
		RETURN NIL
	END;
	NEW(archive, bytes);
	IF ~archive.Validate(error) THEN
		RETURN NIL
	END;
	RETURN archive
END Open;

END DoomWad.
