MODULE DoomBsp;

IMPORT DoomWad, GameBytes, GameGeometry;

TYPE
	Nodes* = POINTER TO ARRAY OF GameGeometry.Partition;
	Leaves* = POINTER TO ARRAY OF SIGNED32;

PROCEDURE Read*(archive: DoomWad.Archive; marker: SIGNED32;
	CONST vertices, lines, sides: DoomWad.Lump; VAR tree: Nodes; VAR leaves: Leaves;
	VAR error: ARRAY OF CHAR): BOOLEAN;
VAR segs, subsectors, nodes: DoomWad.Lump;
	regions: POINTER TO ARRAY OF SIGNED32;
	i, j, offset, first, count, line, side, child: SIGNED32;
BEGIN
	tree := NIL;
	leaves := NIL;
	segs := archive.Entry(marker + 5);
	subsectors := archive.Entry(marker + 6);
	nodes := archive.Entry(marker + 7);
	IF (segs.name # "SEGS") OR (subsectors.name # "SSECTORS") OR (nodes.name # "NODES") OR
		(segs.size MOD 12 # 0) OR (subsectors.size MOD 4 # 0) OR (nodes.size MOD 28 # 0) THEN
		COPY("Missing or malformed classic BSP lumps", error);
		RETURN FALSE
	END;
	IF (segs.size = 0) & (subsectors.size = 0) & (nodes.size = 0) THEN
		RETURN TRUE
	END;
	IF (segs.size = 0) OR (subsectors.size = 0) OR (segs.size DIV 12 > 65536) OR
		(subsectors.size DIV 4 > 32768) OR (nodes.size DIV 28 > 32768) OR
		((nodes.size = 0) & (subsectors.size # 4)) THEN
		COPY("Classic BSP record count is invalid", error);
		RETURN FALSE
	END;
	NEW(regions, segs.size DIV 12);
	FOR i := 0 TO SIGNED32(LEN(regions^)) - 1 DO
		offset := segs.offset + i * 12;
		line := GameBytes.U16(archive.data^, offset + 6);
		side := GameBytes.U16(archive.data^, offset + 8);
		IF (GameBytes.U16(archive.data^, offset) >= vertices.size DIV 4) OR
			(GameBytes.U16(archive.data^, offset + 2) >= vertices.size DIV 4) OR
			(line >= lines.size DIV 14) OR (side > 1) THEN
			COPY("SEGS references an invalid vertex, linedef or side", error);
			RETURN FALSE
		END;
		side := GameBytes.U16(archive.data^, lines.offset + line * 14 + 10 + side * 2);
		IF side >= sides.size DIV 30 THEN
			COPY("SEGS references a missing sidedef", error);
			RETURN FALSE
		END;
		regions[i] := GameBytes.U16(archive.data^, sides.offset + side * 30 + 28)
	END;
	NEW(leaves, subsectors.size DIV 4);
	FOR i := 0 TO SIGNED32(LEN(leaves^)) - 1 DO
		offset := subsectors.offset + i * 4;
		count := GameBytes.U16(archive.data^, offset);
		first := GameBytes.U16(archive.data^, offset + 2);
		IF (count = 0) OR (first >= LEN(regions^)) OR (count > LEN(regions^) - first) THEN
			COPY("SSECTORS references an invalid SEGS range", error);
			RETURN FALSE
		END;
		leaves[i] := regions[first]
	END;
	NEW(tree, nodes.size DIV 28);
	FOR i := 0 TO SIGNED32(LEN(tree^)) - 1 DO
		offset := nodes.offset + i * 28;
		tree[i].x := GameBytes.I16(archive.data^, offset) / 64.0;
		tree[i].y := -GameBytes.I16(archive.data^, offset + 2) / 64.0;
		tree[i].dx := GameBytes.I16(archive.data^, offset + 4) / 64.0;
		tree[i].dy := -GameBytes.I16(archive.data^, offset + 6) / 64.0;
		IF (tree[i].dx = 0) & (tree[i].dy = 0) THEN
			COPY("NODES contains a zero partition direction", error);
			RETURN FALSE
		END;
		FOR j := 0 TO 1 DO
			child := GameBytes.U16(archive.data^, offset + 24 + j * 2);
			IF child >= 32768 THEN
				child := child - 32768;
				IF child >= LEN(leaves^) THEN
					COPY("NODES references an invalid subsector", error);
					RETURN FALSE
				END;
				child := -child - 1
			ELSIF child >= i THEN
				COPY("NODES child must precede its parent", error);
				RETURN FALSE
			END;
			IF j = 0 THEN
				tree[i].front := child
			ELSE
				tree[i].back := child
			END
		END
	END;
	RETURN TRUE
END Read;

END DoomBsp.
