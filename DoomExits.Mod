MODULE DoomExits;

IMPORT DoomFormat, DoomActions, DoomWad, GameBytes, GameGeometry;

CONST None* = 0;
	Normal* = 1;
	Secret* = 2;
	UseNormal = 11;
	UseSecret = 51;
	WalkNormal = 52;
	WalkSecret = 124;

TYPE
	Line = RECORD
		geometry: GameGeometry.Wall
	END;

	Controller* = OBJECT
	VAR lines: POINTER TO ARRAY OF Line;
		pending, triggered: SIGNED32;
		actions: DoomActions.Table;

		PROCEDURE &Init*(archive: DoomWad.Archive; CONST source, vertices: DoomWad.Lump; shared: DoomActions.Table);
		VAR i, offset, a, b: SIGNED32;
		BEGIN
			actions := shared;
			NEW(lines, source.size DIV DoomFormat.LineSize);
			pending := None;
			triggered := -1;
			FOR i := 0 TO SIGNED32(LEN(lines^)) - 1 DO
				offset := source.offset + i * DoomFormat.LineSize;
				a := vertices.offset + GameBytes.U16(archive.data^, offset) * DoomFormat.VertexSize;
				b := vertices.offset + GameBytes.U16(archive.data^, offset + 2) * DoomFormat.VertexSize;
				lines[i].geometry.ax := GameBytes.I16(archive.data^, a) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.ay := -GameBytes.I16(archive.data^, a + 2) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.bx := GameBytes.I16(archive.data^, b) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.by := -GameBytes.I16(archive.data^, b + 2) / DoomFormat.UnitsPerWorld
			END
		END Init;

		PROCEDURE Use*(world: GameGeometry.World; x, y, angle: FLOAT64): BOOLEAN;
		VAR line, special: SIGNED32;
		BEGIN
			line := actions.UseLine(world, x, y, angle);
			IF line < 0 THEN
				RETURN FALSE
			END;
			special := actions.Special(line);
			IF (special # UseNormal) & (special # UseSecret) THEN
				RETURN FALSE
			END;
			pending := Normal;
			IF special = UseSecret THEN
				pending := Secret
			END;
			triggered := line;
			actions.Activated(line, FALSE);
			RETURN TRUE
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
				IF ((actions.Special(i) = WalkNormal) OR (actions.Special(i) = WalkSecret)) &
					GameGeometry.Crossing(lines[i].geometry, x0, y0, x1, y1, fraction) & (fraction < nearest) THEN
					nearest := fraction;
					triggered := i;
					pending := Normal;
					IF actions.Special(i) = WalkSecret THEN
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
