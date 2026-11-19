MODULE DoomTeleports;

IMPORT DoomConfig, DoomFormat, DoomActions, DoomWad, DoomSprites, GameBytes, GameGeometry, MathL;

CONST Once = 39;
	Repeat = 97;
	DestinationThing = 14;
	DegreesPerFacing = 45;

TYPE
	Line = RECORD
		geometry: GameGeometry.Wall;
		tag: SIGNED32
	END;
	Destination = RECORD
		present: BOOLEAN;
		x, y, angle: FLOAT64;
		tag: SIGNED32
	END;

	Controller* = OBJECT
	VAR lines: POINTER TO ARRAY OF Line;
		destinations: POINTER TO ARRAY OF Destination;
		actions: DoomActions.Table;
		pending: BOOLEAN;
		targetX, targetY, targetFeet, targetAngle: FLOAT64;

		PROCEDURE &Init*(archive: DoomWad.Archive; CONST source, vertices, things, sectors: DoomWad.Lump;
			world: GameGeometry.World; shared: DoomActions.Table);
		VAR i, offset, a, b, flags, sector, heading: SIGNED32;
			x, y: FLOAT64;
		BEGIN
			actions := shared;
			NEW(lines, source.size DIV DoomFormat.LineSize);
			NEW(destinations, sectors.size DIV DoomFormat.SectorSize);
			FOR i := 0 TO SIGNED32(LEN(lines^)) - 1 DO
				offset := source.offset + i * DoomFormat.LineSize;
				lines[i].tag := GameBytes.U16(archive.data^, offset + DoomFormat.LineTag);
				a := vertices.offset + GameBytes.U16(archive.data^, offset) * DoomFormat.VertexSize;
				b := vertices.offset + GameBytes.U16(archive.data^, offset + 2) * DoomFormat.VertexSize;
				lines[i].geometry.ax := GameBytes.I16(archive.data^, a) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.ay := -GameBytes.I16(archive.data^, a + 2) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.bx := GameBytes.I16(archive.data^, b) / DoomFormat.UnitsPerWorld;
				lines[i].geometry.by := -GameBytes.I16(archive.data^, b + 2) / DoomFormat.UnitsPerWorld
			END;
			FOR i := 0 TO SIGNED32(LEN(destinations^)) - 1 DO
				destinations[i].tag := GameBytes.U16(archive.data^, sectors.offset + i * DoomFormat.SectorSize + DoomFormat.SectorTag)
			END;
			FOR i := 0 TO things.size DIV DoomFormat.ThingSize - 1 DO
				offset := things.offset + i * DoomFormat.ThingSize;
				flags := GameBytes.U16(archive.data^, offset + DoomFormat.ThingFlags);
				IF (GameBytes.U16(archive.data^, offset + DoomFormat.ThingType) = DestinationThing) &
					(flags DIV 2 MOD 2 = 1) & (flags DIV 16 MOD 2 = 0) THEN
					x := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
					y := -GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
					sector := world.Locate(x, y);
					IF (sector >= 0) & ~destinations[sector].present THEN
						destinations[sector].present := TRUE;
						destinations[sector].x := x;
						destinations[sector].y := y;
						(* Map things use Doom's eight authored facing directions. *)
						heading := -(GameBytes.U16(archive.data^, offset + 4) MOD
							DoomFormat.DegreesPerCircle DIV DegreesPerFacing) * DegreesPerFacing;
						IF heading < -DoomFormat.DegreesPerHalfCircle THEN
							INC(heading, DoomFormat.DegreesPerCircle)
						END;
						destinations[sector].angle := FLOAT64(heading) * MathL.pi /
							FLOAT64(DoomFormat.DegreesPerHalfCircle)
					END
				END
			END
		END Init;

		PROCEDURE Activate(world: GameGeometry.World; VAR scene: DoomSprites.Scene; line: SIGNED32): BOOLEAN;
		VAR i: SIGNED32;
			floor: FLOAT64;
			candidate: DoomSprites.Scene;
		BEGIN
			FOR i := 0 TO SIGNED32(LEN(destinations^)) - 1 DO
				IF destinations[i].present & (destinations[i].tag = lines[line].tag) THEN
					floor := world.Region(i).floor;
					(* shortcut: reject invalid landing volumes instead of vanilla's unchecked placement. *)
					IF ~world.Stand(destinations[i].x, destinations[i].y, DoomConfig.values.playerRadius,
						floor, DoomConfig.values.playerHeight, 0, floor) THEN
						RETURN FALSE
					END;
					candidate := scene.TeleportPlayer(destinations[i].x, destinations[i].y, DoomConfig.values.playerRadius);
					IF candidate = NIL THEN
						RETURN FALSE
					END;
					scene := candidate;
					targetX := destinations[i].x;
					targetY := destinations[i].y;
					targetFeet := floor;
					targetAngle := destinations[i].angle;
					pending := TRUE;
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END Activate;

		(* Observe clips further action observations at the first successful teleport.
		   Take replaces the sweep's temporary end position without tracing the jump. *)
		PROCEDURE Observe*(world: GameGeometry.World; VAR scene: DoomSprites.Scene;
			x0, y0: FLOAT64; VAR x1, y1: FLOAT64);
		VAR i, selected, previous, special: SIGNED32;
			fraction, nearest, cursor, side: FLOAT64;
		BEGIN
			IF pending THEN
				x1 := x0;
				y1 := y0;
				RETURN
			END;
			cursor := -1;
			previous := -1;
			LOOP
				selected := -1;
				nearest := MAX(FLOAT64);
				FOR i := 0 TO SIGNED32(LEN(lines^)) - 1 DO
					special := actions.Special(i);
					IF ((special = Once) OR (special = Repeat)) &
						GameGeometry.Crossing(lines[i].geometry, x0, y0, x1, y1, fraction) &
						((fraction > cursor) OR ((fraction = cursor) & (i > previous))) & (fraction < nearest) THEN
						selected := i;
						nearest := fraction
					END
				END;
				IF selected < 0 THEN
					RETURN
				END;
				IF actions.Special(selected) = Once THEN
					actions.Consume(selected)
				END;
				side := (x0 - lines[selected].geometry.ax) * (lines[selected].geometry.by - lines[selected].geometry.ay) -
					(y0 - lines[selected].geometry.ay) * (lines[selected].geometry.bx - lines[selected].geometry.ax);
				(* Crossing classifies points on the line with the back side. *)
				IF (side < 0) & Activate(world, scene, selected) THEN
					x1 := x0 + (x1 - x0) * nearest;
					y1 := y0 + (y1 - y0) * nearest;
					RETURN
				END;
				cursor := nearest;
				previous := selected
			END
		END Observe;

		PROCEDURE Take*(VAR x, y, feet, angle: FLOAT64): BOOLEAN;
		BEGIN
			IF ~pending THEN
				RETURN FALSE
			END;
			pending := FALSE;
			x := targetX;
			y := targetY;
			feet := targetFeet;
			angle := targetAngle;
			RETURN TRUE
		END Take;
	END Controller;

END DoomTeleports.
