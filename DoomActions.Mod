MODULE DoomActions;

IMPORT DoomConfig, DoomFormat, DoomWad, GameBytes, GameGeometry, MathL;

TYPE Table* = OBJECT
VAR specials: POINTER TO ARRAY OF SIGNED32;
	busy: POINTER TO ARRAY OF BOOLEAN;

	PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines: DoomWad.Lump; sectorCount: SIGNED32);
	VAR i: SIGNED32;
	BEGIN
		NEW(specials, lines.size DIV DoomFormat.LineSize);
		NEW(busy, sectorCount);
		FOR i := 0 TO SIGNED32(LEN(specials^)) - 1 DO
			specials[i] := GameBytes.U16(archive.data^, lines.offset + i * DoomFormat.LineSize + DoomFormat.LineSpecial)
		END
	END Init;

	PROCEDURE Special*(line: SIGNED32): SIGNED32;
	BEGIN
		RETURN specials[line]
	END Special;

	PROCEDURE Consume*(line: SIGNED32);
	BEGIN
		specials[line] := 0
	END Consume;

	(* Claim prevents doors and floors from driving the same sector at the same time. *)
	PROCEDURE Claim*(sector: SIGNED32): BOOLEAN;
	BEGIN
		IF busy[sector] THEN
			RETURN FALSE
		END;
		busy[sector] := TRUE;
		RETURN TRUE
	END Claim;

	PROCEDURE Release*(sector: SIGNED32);
	BEGIN
		ASSERT(busy[sector]);
		busy[sector] := FALSE
	END Release;

	(* UseLine shares consumed line state so later actions remain reachable through open portals. *)
	PROCEDURE UseLine*(world: GameGeometry.World; x, y, angle: FLOAT64): SIGNED32;
	VAR wall: GameGeometry.Wall;
		front, back: GameGeometry.Sector;
		i: SIGNED32;
		near, distance: FLOAT64;
	BEGIN
		near := 0;
		(* shortcut: use traces stop after 256 hits; add spatial traversal for denser edited maps. *)
		FOR i := 1 TO MIN(world.Count(), DoomFormat.MaximumTraceHits) DO
			IF ~world.CastSector(-1, x, y, MathL.cos(angle), MathL.sin(angle), near, distance, wall) OR
				(distance > DoomConfig.values.useRange) THEN
				RETURN -1
			END;
			IF specials[wall.id] # 0 THEN
				IF (x - wall.ax) * (wall.by - wall.ay) > (y - wall.ay) * (wall.bx - wall.ax) THEN
					RETURN -1
				END;
				RETURN wall.id
			END;
			IF wall.neighbor < 0 THEN
				RETURN -1
			END;
			front := world.Region(wall.sector);
			back := world.Region(wall.neighbor);
			IF MAX(front.floor, back.floor) >= MIN(front.ceiling, back.ceiling) THEN
				RETURN -1
			END;
			near := distance
		END;
		RETURN -1
	END UseLine;
END Table;

END DoomActions.
