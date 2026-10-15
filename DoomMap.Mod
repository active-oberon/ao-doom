MODULE DoomMap;

IMPORT DoomConfig, DoomFormat, DoomWad, DoomTextures, DoomBsp, DoomDoors, DoomFloors, DoomActions, DoomSwitches, DoomExits, DoomSprites, GameBytes, GameGeometry, MathL;

CONST MaximumValidationWork = 64 * 1024 * 1024;

TYPE
	Map* = RECORD
		world*: GameGeometry.World;
		doors*: DoomDoors.Controller;
		floors*: DoomFloors.Controller;
		actions*: DoomActions.Table;
		exits*: DoomExits.Controller;
		sprites*: DoomSprites.Scene;
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

PROCEDURE Name(CONST data: ARRAY OF CHAR; offset: SIGNED32; VAR name: ARRAY OF CHAR);
VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO DoomFormat.NameLength - 1 DO
		name[i] := CAP(data[offset + i])
	END;
	name[DoomFormat.NameLength] := 0X
END Name;

PROCEDURE SkyName(CONST map: ARRAY OF CHAR; VAR sky: ARRAY OF CHAR);
VAR level: SIGNED32;
BEGIN
	COPY("SKY1", sky);
	IF (map[0] = "E") & (map[1] >= "1") & (map[1] <= "4") & (map[2] = "M") THEN
		sky[3] := map[1]
	ELSIF (map[0] = "M") & (map[1] = "A") & (map[2] = "P") &
		(map[3] >= "0") & (map[3] <= "9") & (map[4] >= "0") & (map[4] <= "9") THEN
		level := (ORD(map[3]) - ORD("0")) * 10 + ORD(map[4]) - ORD("0");
		IF level >= 21 THEN
			COPY("SKY3", sky)
		ELSIF level >= 12 THEN
			COPY("SKY2", sky)
		END
	END
END SkyName;

PROCEDURE Side(archive: DoomWad.Archive; textures: DoomTextures.Library; doors: DoomDoors.Controller; floors: DoomFloors.Controller;
	world: GameGeometry.World; CONST regions: ARRAY OF GameGeometry.Sector;
	CONST vertices, sides: DoomWad.Lump; id, v1, v2, side, neighbor, flags: SIGNED32;
	VAR error: ARRAY OF CHAR): BOOLEAN;
VAR wall: GameGeometry.Wall;
	front, back: GameGeometry.Sector;
	offset: SIGNED32;
	name: ARRAY DoomFormat.NameLength + 1 OF CHAR;
BEGIN
	offset := sides.offset + side * DoomFormat.SideSize;
	wall.id := id;
	wall.sector := GameBytes.U16(archive.data^, offset + DoomFormat.SideSector);
	wall.neighbor := neighbor;
	wall.blocking := flags MOD 2 = 1;
	wall.omitMiddle := FALSE;
	wall.omitUpper := FALSE;
	wall.omitLower := FALSE;
	wall.middleFromFloor := flags DIV 16 MOD 2 = 1;
	wall.upperFromNeighbor := flags DIV 8 MOD 2 = 0;
	wall.lowerFromCeiling := flags DIV 16 MOD 2 = 1;
	wall.ax := GameBytes.I16(archive.data^, vertices.offset + v1 * DoomFormat.VertexSize) / DoomFormat.UnitsPerWorld;
	wall.ay := -GameBytes.I16(archive.data^, vertices.offset + v1 * DoomFormat.VertexSize + 2) / DoomFormat.UnitsPerWorld;
	wall.bx := GameBytes.I16(archive.data^, vertices.offset + v2 * DoomFormat.VertexSize) / DoomFormat.UnitsPerWorld;
	wall.by := -GameBytes.I16(archive.data^, vertices.offset + v2 * DoomFormat.VertexSize + 2) / DoomFormat.UnitsPerWorld;
	front := regions[wall.sector];
	wall.bottom := front.floor;
	wall.top := front.ceiling;
	wall.color := 0A07850H;
	wall.light := front.light;
	wall.texture := NIL;
	wall.upper := NIL;
	wall.lower := NIL;
	wall.upperAnchor := front.ceiling;
	wall.lowerAnchor := front.floor;
	wall.xOffset := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
	wall.yOffset := GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
	wall.texelsPerUnit := DoomFormat.UnitsPerWorld;
	IF textures # NIL THEN
		Name(archive.data^, offset + 20, name);
		wall.omitMiddle := name = "-";
		IF ~wall.omitMiddle THEN
			wall.texture := textures.Get(name, error);
			IF wall.texture = NIL THEN
				RETURN FALSE
			END;
			wall.uScale := DoomFormat.UnitsPerWorld / wall.texture.width;
			wall.vScale := DoomFormat.UnitsPerWorld / wall.texture.height;
			wall.uOffset := wall.xOffset * wall.uScale;
			wall.vOffset := wall.yOffset * wall.vScale
		END;
		IF neighbor < 0 THEN
			IF ~wall.omitMiddle & wall.middleFromFloor THEN
				wall.vOffset := wall.vOffset + (front.ceiling - front.floor) * -wall.vScale
			END
		ELSE
			back := regions[neighbor];
			IF ((back.ceiling < front.ceiling) OR doors.Moving(wall.sector) OR doors.Moving(neighbor)) &
				~((front.skyTexture # NIL) & (back.skyTexture # NIL)) THEN
				Name(archive.data^, offset + 4, name);
				wall.omitUpper := name = "-";
				IF ~wall.omitUpper THEN
					wall.upper := textures.Get(name, error);
					IF wall.upper = NIL THEN
						RETURN FALSE
					END;
					IF flags DIV 8 MOD 2 = 0 THEN
						wall.upperAnchor := back.ceiling + wall.upper.height / DoomFormat.UnitsPerWorld
					END
				END
			END;
			IF (back.floor > front.floor) OR floors.Moving(wall.sector) OR floors.Moving(neighbor) THEN
				Name(archive.data^, offset + 12, name);
				wall.omitLower := name = "-";
				IF ~wall.omitLower THEN
					wall.lower := textures.Get(name, error);
					IF wall.lower = NIL THEN
						RETURN FALSE
					END;
					wall.lowerAnchor := back.floor;
					IF flags DIV 16 MOD 2 = 1 THEN
						wall.lowerAnchor := front.ceiling
					END
				END
			END
		END
	END;
	IF ~world.Add(wall) THEN
		COPY("Map contains invalid or degenerate wall geometry", error);
		RETURN FALSE
	END;
	RETURN TRUE
END Side;

PROCEDURE LoadWithWeapons*(archive: DoomWad.Archive; CONST name: ARRAY OF CHAR; weapons: SET;
	VAR map: Map; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR marker, i, j, offset, v1, v2, front, back, flags, start,
	vertexCount, sideCount, sectorCount, lineCount, sector, frontSector, backSector, result, edges: SIGNED32;
	things, lines, sides, vertices, sectors, markerLump: DoomWad.Lump;
	world: GameGeometry.World;
	doors: DoomDoors.Controller;
	floors: DoomFloors.Controller;
	actions: DoomActions.Table;
	switches: DoomSwitches.Controller;
	textures: DoomTextures.Library;
	regions: POINTER TO ARRAY OF GameGeometry.Sector;
	degree: POINTER TO ARRAY OF SIGNED32;
	partitions: DoomBsp.Nodes;
	leaves: DoomBsp.Leaves;
	textureName, skyName: ARRAY DoomFormat.NameLength + 1 OF CHAR;
	x, y, angle, floor: FLOAT64;
BEGIN
	map.world := NIL;
	map.doors := NIL;
	map.floors := NIL;
	map.actions := NIL;
	map.exits := NIL;
	map.sprites := NIL;
	error[0] := 0X;
	IF ~DoomConfig.loaded THEN
		COPY("Load Doom configuration before loading a map", error);
		RETURN FALSE
	END;
	marker := archive.Find(name);
	IF (marker < 0) OR
		~MapLump(archive, marker + 1, "THINGS", DoomFormat.ThingSize, things) OR
		~MapLump(archive, marker + 2, "LINEDEFS", DoomFormat.LineSize, lines) OR
		~MapLump(archive, marker + 3, "SIDEDEFS", DoomFormat.SideSize, sides) OR
		~MapLump(archive, marker + 4, "VERTEXES", DoomFormat.VertexSize, vertices) OR
		~MapLump(archive, marker + 8, "SECTORS", DoomFormat.SectorSize, sectors) THEN
		COPY("Missing or malformed classic Doom map lumps", error);
		RETURN FALSE
	END;
	vertexCount := vertices.size DIV DoomFormat.VertexSize;
	sideCount := sides.size DIV DoomFormat.SideSize;
	sectorCount := sectors.size DIV DoomFormat.SectorSize;
	lineCount := lines.size DIV DoomFormat.LineSize;
	IF (lineCount > DoomFormat.MaximumRecords) OR (sideCount > DoomFormat.MaximumRecords) OR (vertexCount > DoomFormat.MaximumRecords) OR (sectorCount > DoomFormat.MaximumRecords) THEN
		COPY("Map record count exceeds 65536", error);
		RETURN FALSE
	END;
	FOR i := 0 TO sideCount - 1 DO
		IF GameBytes.U16(archive.data^, sides.offset + i * DoomFormat.SideSize + DoomFormat.SideSector) >= sectorCount THEN
			COPY("SIDEDEFS references an invalid sector", error);
			RETURN FALSE
		END
	END;
	FOR i := 0 TO lineCount - 1 DO
		offset := lines.offset + i * DoomFormat.LineSize;
		v1 := GameBytes.U16(archive.data^, offset);
		v2 := GameBytes.U16(archive.data^, offset + 2);
		front := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
		back := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
		flags := GameBytes.U16(archive.data^, offset + DoomFormat.LineFlags);
		IF (v1 >= vertexCount) OR (v2 >= vertexCount) OR (front >= sideCount) OR
			((back # DoomFormat.NoSide) & (back >= sideCount)) THEN
			COPY("LINEDEFS references an invalid vertex or sidedef", error);
			RETURN FALSE
		END;
		IF (v1 = v2) OR
			((GameBytes.I16(archive.data^, vertices.offset + v1 * DoomFormat.VertexSize) = GameBytes.I16(archive.data^, vertices.offset + v2 * DoomFormat.VertexSize)) &
			(GameBytes.I16(archive.data^, vertices.offset + v1 * DoomFormat.VertexSize + 2) = GameBytes.I16(archive.data^, vertices.offset + v2 * DoomFormat.VertexSize + 2))) THEN
			COPY("Map contains a degenerate linedef", error);
			RETURN FALSE
		END;
		IF (flags DIV 4 MOD 2 = 1) # (back # DoomFormat.NoSide) THEN
			COPY("Two-sided linedef flag disagrees with its back sidedef", error);
			RETURN FALSE
		END
	END;
	IF ~DoomBsp.Read(archive, marker, vertices, lines, sides, partitions, leaves, error) THEN
		RETURN FALSE
	END;
	IF leaves = NIL THEN
		IF sectorCount > MaximumValidationWork DIV (vertexCount + lineCount) THEN
			COPY("Sector contour validation exceeds the map work budget", error);
			RETURN FALSE
		END;
		NEW(degree, vertexCount);
		FOR sector := 0 TO sectorCount - 1 DO
			FOR j := 0 TO vertexCount - 1 DO
				degree[j] := 0
			END;
			edges := 0;
			FOR i := 0 TO lineCount - 1 DO
				offset := lines.offset + i * DoomFormat.LineSize;
				front := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
				back := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
				frontSector := GameBytes.U16(archive.data^, sides.offset + front * DoomFormat.SideSize + DoomFormat.SideSector);
				backSector := -1;
				IF back # DoomFormat.NoSide THEN
					backSector := GameBytes.U16(archive.data^, sides.offset + back * DoomFormat.SideSize + DoomFormat.SideSector)
				END;
				IF (frontSector # backSector) & ((frontSector = sector) OR (backSector = sector)) THEN
					INC(degree[GameBytes.U16(archive.data^, offset)]);
					INC(degree[GameBytes.U16(archive.data^, offset + 2)]);
					INC(edges)
				END
			END;
			IF edges = 0 THEN
				COPY("Sector has no closed boundary", error);
				RETURN FALSE
			END;
			FOR j := 0 TO vertexCount - 1 DO
				IF degree[j] MOD 2 # 0 THEN
					COPY("Sector boundary must form closed contours", error);
					RETURN FALSE
				END
			END
		END;
	END;
	textures := NIL;
	IF archive.Find("TEXTURE1") >= 0 THEN
		textures := DoomTextures.Open(archive, error);
		IF textures = NIL THEN
			RETURN FALSE
		END
	END;
	NEW(regions, sectorCount);
	markerLump := archive.Entry(marker);
	SkyName(markerLump.name, skyName);
	FOR sector := 0 TO sectorCount - 1 DO
		offset := sectors.offset + sector * DoomFormat.SectorSize;
		regions[sector].floor := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
		regions[sector].ceiling := GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
		regions[sector].light := GameBytes.I16(archive.data^, offset + 20);
		IF (regions[sector].light < 0) OR (regions[sector].light > DoomFormat.LightMaximum) THEN
			COPY("Sector has invalid light level", error);
			RETURN FALSE
		END;
		IF textures # NIL THEN
			Name(archive.data^, offset + 4, textureName);
			regions[sector].floorTexture := textures.Flat(textureName, error);
			IF regions[sector].floorTexture = NIL THEN
				RETURN FALSE
			END;
			Name(archive.data^, offset + 12, textureName);
			IF textureName = "F_SKY1" THEN
				regions[sector].skyTexture := textures.Get(skyName, error);
				IF regions[sector].skyTexture = NIL THEN
					RETURN FALSE
				END;
				regions[sector].skyUScale := 1024.0 / regions[sector].skyTexture.width;
				regions[sector].skyVScale := 200.0 / regions[sector].skyTexture.height;
				regions[sector].skyVOffset := 100.0 / regions[sector].skyTexture.height
			ELSE
				regions[sector].ceilingTexture := textures.Flat(textureName, error);
				IF regions[sector].ceilingTexture = NIL THEN
					RETURN FALSE
				END
			END
		END
	END;
	switches := DoomSwitches.Read(archive, lines, sides, textures, error);
	IF switches = NIL THEN
		RETURN FALSE
	END;
	NEW(actions, archive, lines, sectorCount, switches);
	NEW(doors, archive, lines, sides, sectors, vertices, actions);
	NEW(floors, archive, lines, sides, sectors, vertices, actions);
	NEW(world, lineCount * 2);
	ASSERT(world.SetSectors(regions^));
	IF leaves # NIL THEN
		IF ~world.SetPartition(partitions^, leaves^) THEN
			COPY("Map contains an invalid partition tree", error);
			RETURN FALSE
		END
	END;
	FOR i := 0 TO lineCount - 1 DO
		offset := lines.offset + i * DoomFormat.LineSize;
		v1 := GameBytes.U16(archive.data^, offset);
		v2 := GameBytes.U16(archive.data^, offset + 2);
		flags := GameBytes.U16(archive.data^, offset + DoomFormat.LineFlags);
		front := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
		back := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
		backSector := -1;
		IF back # DoomFormat.NoSide THEN
			backSector := GameBytes.U16(archive.data^, sides.offset + back * DoomFormat.SideSize + DoomFormat.SideSector)
		END;
		IF ~Side(archive, textures, doors, floors, world, regions^, vertices, sides, i, v1, v2, front, backSector, flags, error) THEN
			RETURN FALSE
		END;
		IF back # DoomFormat.NoSide THEN
			frontSector := GameBytes.U16(archive.data^, sides.offset + front * DoomFormat.SideSize + DoomFormat.SideSector);
			IF ~Side(archive, textures, doors, floors, world, regions^, vertices, sides, i, v2, v1, back, frontSector, flags, error) THEN
				RETURN FALSE
			END
		END
	END;
	world.Seal;
	start := -1;
	FOR i := 0 TO things.size DIV DoomFormat.ThingSize - 1 DO
		offset := things.offset + i * DoomFormat.ThingSize;
		IF (start < 0) & (GameBytes.I16(archive.data^, offset + DoomFormat.ThingType) = DoomFormat.PlayerOne) THEN
			start := offset
		END
	END;
	IF start < 0 THEN
		COPY("Map has no player-one start", error);
		RETURN FALSE
	END;
	x := GameBytes.I16(archive.data^, start) / DoomFormat.UnitsPerWorld;
	y := -GameBytes.I16(archive.data^, start + 2) / DoomFormat.UnitsPerWorld;
	sector := world.Locate(x, y);
	IF sector < 0 THEN
		COPY("Player start is outside all sectors", error);
		RETURN FALSE
	END;
	floor := regions[sector].floor;
	IF ~world.Stand(x, y, DoomConfig.values.playerRadius, floor,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, floor) THEN
		COPY("Player start intersects a wall or has insufficient clearance", error);
		RETURN FALSE
	END;
	result := GameBytes.I16(archive.data^, start + 4) MOD DoomFormat.DegreesPerCircle;
	angle := -result * MathL.pi / DoomFormat.DegreesPerHalfCircle;
	IF angle < -MathL.pi THEN
		angle := angle + MathL.pi * 2
	END;
	map.sprites := DoomSprites.Read(archive, things, textures, world, weapons, error);
	IF map.sprites = NIL THEN
		RETURN FALSE
	END;
	map.world := world;
	map.doors := doors;
	map.floors := floors;
	map.actions := actions;
	NEW(map.exits, archive, lines, vertices, actions);
	map.x := x;
	map.y := y;
	map.angle := angle;
	map.eye := floor + DoomConfig.values.playerEye;
	RETURN TRUE
END LoadWithWeapons;

PROCEDURE LoadMap*(archive: DoomWad.Archive; CONST name: ARRAY OF CHAR;
	VAR map: Map; VAR error: ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN LoadWithWeapons(archive, name, {}, map, error)
END LoadMap;

END DoomMap.
