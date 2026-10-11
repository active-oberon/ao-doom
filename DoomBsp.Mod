MODULE DoomBsp;

IMPORT DoomFormat, DoomWad, GameBytes, GameGeometry;

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
		(segs.size MOD DoomFormat.SegSize # 0) OR (subsectors.size MOD DoomFormat.SubsectorSize # 0) OR (nodes.size MOD DoomFormat.NodeSize # 0) THEN
		COPY("Missing or malformed classic BSP lumps", error);
		RETURN FALSE
	END;
	IF (segs.size = 0) & (subsectors.size = 0) & (nodes.size = 0) THEN
		RETURN TRUE
	END;
	IF (segs.size = 0) OR (subsectors.size = 0) OR (segs.size DIV DoomFormat.SegSize > DoomFormat.MaximumRecords) OR
		(subsectors.size DIV DoomFormat.SubsectorSize > DoomFormat.LeafFlag) OR (nodes.size DIV DoomFormat.NodeSize > DoomFormat.LeafFlag) OR
		((nodes.size = 0) & (subsectors.size # DoomFormat.SubsectorSize)) THEN
		COPY("Classic BSP record count is invalid", error);
		RETURN FALSE
	END;
	NEW(regions, segs.size DIV DoomFormat.SegSize);
	FOR i := 0 TO SIGNED32(LEN(regions^)) - 1 DO
		offset := segs.offset + i * DoomFormat.SegSize;
		line := GameBytes.U16(archive.data^, offset + 6);
		side := GameBytes.U16(archive.data^, offset + 8);
		IF (GameBytes.U16(archive.data^, offset) >= vertices.size DIV DoomFormat.VertexSize) OR
			(GameBytes.U16(archive.data^, offset + 2) >= vertices.size DIV DoomFormat.VertexSize) OR
			(line >= lines.size DIV DoomFormat.LineSize) OR (side > 1) THEN
			COPY("SEGS references an invalid vertex, linedef or side", error);
			RETURN FALSE
		END;
		side := GameBytes.U16(archive.data^, lines.offset + line * DoomFormat.LineSize + DoomFormat.LineFront + side * 2);
		IF side >= sides.size DIV DoomFormat.SideSize THEN
			COPY("SEGS references a missing sidedef", error);
			RETURN FALSE
		END;
		regions[i] := GameBytes.U16(archive.data^, sides.offset + side * DoomFormat.SideSize + DoomFormat.SideSector)
	END;
	NEW(leaves, subsectors.size DIV DoomFormat.SubsectorSize);
	FOR i := 0 TO SIGNED32(LEN(leaves^)) - 1 DO
		offset := subsectors.offset + i * DoomFormat.SubsectorSize;
		count := GameBytes.U16(archive.data^, offset);
		first := GameBytes.U16(archive.data^, offset + 2);
		IF (count = 0) OR (first >= LEN(regions^)) OR (count > LEN(regions^) - first) THEN
			COPY("SSECTORS references an invalid SEGS range", error);
			RETURN FALSE
		END;
		leaves[i] := regions[first]
	END;
	NEW(tree, nodes.size DIV DoomFormat.NodeSize);
	FOR i := 0 TO SIGNED32(LEN(tree^)) - 1 DO
		offset := nodes.offset + i * DoomFormat.NodeSize;
		tree[i].x := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
		tree[i].y := -GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
		tree[i].dx := GameBytes.I16(archive.data^, offset + 4) / DoomFormat.UnitsPerWorld;
		tree[i].dy := -GameBytes.I16(archive.data^, offset + 6) / DoomFormat.UnitsPerWorld;
		IF (tree[i].dx = 0) & (tree[i].dy = 0) THEN
			COPY("NODES contains a zero partition direction", error);
			RETURN FALSE
		END;
		FOR j := 0 TO 1 DO
			child := GameBytes.U16(archive.data^, offset + 24 + j * 2);
			IF child >= DoomFormat.LeafFlag THEN
				child := child - DoomFormat.LeafFlag;
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
