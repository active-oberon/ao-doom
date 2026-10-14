MODULE DoomExits;

IMPORT DoomConfig, DoomFormat, DoomWad, GameBytes, GameGeometry, MathL;

CONST None* = 0;
	Normal* = 1;
	Secret* = 2;
	UseNormal = 11;
	UseSecret = 51;
	WalkNormal = 52;
	WalkSecret = 124;

TYPE
	Line = RECORD
		geometry: GameGeometry.Wall;
		special: SIGNED32
	END;

	Controller* = OBJECT
	VAR lines: POINTER TO ARRAY OF Line;
		pending, triggered: SIGNED32;

		PROCEDURE &Init*(archive: DoomWad.Archive; CONST source, vertices: DoomWad.Lump);
		VAR i, offset, a, b: SIGNED32;
		BEGIN
			NEW(lines, source.size DIV DoomFormat.LineSize);
			pending := None;
			triggered := -1;
			FOR i := 0 TO SIGNED32(LEN(lines^)) - 1 DO
				offset := source.offset + i * DoomFormat.LineSize;
				lines[i].special := GameBytes.U16(archive.data^, offset + DoomFormat.LineSpecial);
				a := vertices.offset + GameBytes.U16(archive.data^, offset) * DoomFormat.VertexSize;
				b := vertices.offset + GameBytes.U16(archive.data^, offset + 2) * DoomFormat.VertexSize;
				lines[i].geometry.ax := GameBytes.I16(archive.data^, a) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.ay := -GameBytes.I16(archive.data^, a + 2) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.bx := GameBytes.I16(archive.data^, b) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.by := -GameBytes.I16(archive.data^, b + 2) / DoomFormat.UnitsPerWorld
			END
		END Init;

		PROCEDURE Use*(world: GameGeometry.World; x, y, angle: FLOAT64): BOOLEAN;
		VAR wall, line: GameGeometry.Wall;
			front, back: GameGeometry.Sector;
			i, special: SIGNED32;
			near, distance: FLOAT64;
		BEGIN
			near := 0;
			FOR i := 1 TO MIN(world.Count(), DoomFormat.MaximumTraceHits) DO
				IF ~world.CastSector(-1, x, y, MathL.cos(angle), MathL.sin(angle), near, distance, wall) OR
					(distance > DoomConfig.values.useRange) THEN
					RETURN FALSE
				END;
				special := lines[wall.id].special;
				IF special # 0 THEN
					line := lines[wall.id].geometry;
					IF ((special # UseNormal) & (special # UseSecret)) OR
						((x - line.ax) * (line.by - line.ay) > (y - line.ay) * (line.bx - line.ax)) THEN
						RETURN FALSE
					END;
					pending := Normal;
					IF special = UseSecret THEN
						pending := Secret
					END;
					triggered := wall.id;
					RETURN TRUE
				END;
				IF wall.neighbor < 0 THEN
					RETURN FALSE
				END;
				front := world.Region(wall.sector);
				back := world.Region(wall.neighbor);
				IF MAX(front.floor, back.floor) >= MIN(front.ceiling, back.ceiling) THEN
					RETURN FALSE
				END;
				near := distance
			END;
			RETURN FALSE
		END Use;

		(* Crossed observes accepted movement and chooses the first exit along that substep. *)
		PROCEDURE Crossed*(x0, y0, x1, y1: FLOAT64);
		VAR i: SIGNED32;
			fraction, nearest: FLOAT64;
		BEGIN
			IF pending # None THEN
				RETURN
			END;
			nearest := MAX(FLOAT64);
			FOR i := 0 TO SIGNED32(LEN(lines^)) - 1 DO
				IF ((lines[i].special = WalkNormal) OR (lines[i].special = WalkSecret)) &
					GameGeometry.Crossing(lines[i].geometry, x0, y0, x1, y1, fraction) & (fraction < nearest) THEN
					nearest := fraction;
					triggered := i;
					pending := Normal;
					IF lines[i].special = WalkSecret THEN
						pending := Secret
					END
				END
			END
		END Crossed;

		PROCEDURE Take*(VAR line: SIGNED32): SIGNED32;
		VAR kind: SIGNED32;
		BEGIN
			kind := pending;
			line := triggered;
			pending := None;
			triggered := -1;
			RETURN kind
		END Take;
	END Controller;

END DoomExits.
