MODULE DoomOriginalDoorsSmoke;

IMPORT Doom, DoomWad, DoomMap, GameBytes, GameGeometry, GameSurface, GameRenderer,
	MathL, KernelLog, Unix, Commands;

PROCEDURE Do*(context: Commands.Context);
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	lines, vertices: DoomWad.Lump;
	region: GameGeometry.Sector;
	wall: GameGeometry.Wall;
	frame: GameSurface.Frame;
	path: ARRAY 512 OF CHAR;
	marker: ARRAY 9 OF CHAR;
	error: ARRAY 128 OF CHAR;
	i, j, offset, a, b, special, sector: SIGNED32;
	ax, ay, bx, by, rx, ry, length, x, y, angle, feet, floor, before,
	blockedX, blockedY, blockedFeet, distance: FLOAT64;
BEGIN
	IF Unix.argc < 3 THEN
		KernelLog.String("Usage: original-doors-check WAD MAP");
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	Unix.GetArg(1, path);
	Unix.GetArg(2, marker);
	archive := DoomWad.Open(path, error);
	IF (archive = NIL) OR ~DoomMap.LoadMap(archive, marker, map, error) THEN
		KernelLog.String(error);
		KernelLog.Ln;
		context.result := Commands.CommandError;
		RETURN
	END;
	lines := archive.Entry(archive.Find(marker) + 2);
	vertices := archive.Entry(archive.Find(marker) + 4);
	FOR i := 0 TO lines.size DIV 14 - 1 DO
		offset := lines.offset + i * 14;
		special := GameBytes.U16(archive.data^, offset + 6);
		IF (special = 1) OR (special = 31) OR (special = 117) OR (special = 118) THEN
			a := GameBytes.U16(archive.data^, offset);
			b := GameBytes.U16(archive.data^, offset + 2);
			ax := GameBytes.I16(archive.data^, vertices.offset + a * 4) / 64.0;
			ay := -GameBytes.I16(archive.data^, vertices.offset + a * 4 + 2) / 64.0;
			bx := GameBytes.I16(archive.data^, vertices.offset + b * 4) / 64.0;
			by := -GameBytes.I16(archive.data^, vertices.offset + b * 4 + 2) / 64.0;
			length := MathL.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
			rx := (by - ay) / length;
			ry := -(bx - ax) / length;
			x := (ax + bx) / 2 - rx * 0.5;
			y := (ay + by) / 2 - ry * 0.5;
			sector := map.world.Locate(x, y);
			IF sector >= 0 THEN
				region := map.world.Region(sector);
				feet := region.floor;
				IF map.world.Stand(x, y, Doom.PlayerRadius, feet, Doom.PlayerHeight, Doom.PlayerStep, floor) THEN
					IF rx = 0 THEN
						angle := MathL.pi / 2;
						IF ry < 0 THEN
							angle := -angle
						END
					ELSE
						angle := MathL.arctan(ry / rx);
						IF rx < 0 THEN
							angle := angle + MathL.pi
						END
					END;
					blockedX := x;
					blockedY := y;
					blockedFeet := feet;
					ASSERT(map.world.MovePlayer(blockedX, blockedY, blockedFeet, rx, ry,
						Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
					IF (blockedX * rx + blockedY * ry <= x * rx + y * ry + 0.5) &
						map.world.Cast(x, y, rx, ry, distance, wall) & (wall.id = i) &
						map.doors.Use(map.world, x, y, angle) THEN
						NEW(frame, 320, 200);
						GameRenderer.Render(map.world, frame, x, y, angle, feet + Doom.PlayerEye);
						ASSERT(frame.Save("original-door-closed.ppm"));
						FOR j := 1 TO 70 DO
							map.doors.Step(map.world, x, y, Doom.PlayerRadius, feet, Doom.PlayerHeight, Doom.PlayerStep)
						END;
						GameRenderer.Render(map.world, frame, x, y, angle, feet + Doom.PlayerEye);
						ASSERT(frame.Save("original-door-open.ppm"));
						before := x * rx + y * ry;
						ASSERT(map.world.MovePlayer(x, y, feet, rx, ry, Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep));
						ASSERT(x * rx + y * ry > before + 0.5);
						ASSERT(map.world.Stand(x, y, Doom.PlayerRadius, feet, Doom.PlayerHeight, Doom.PlayerStep, floor));
						KernelLog.String(marker);
						KernelLog.String(": opened and crossed manual door line ");
						KernelLog.Int(i, 1);
						KernelLog.String(" (type ");
						KernelLog.Int(special, 1);
						KernelLog.String(")");
						KernelLog.Ln;
						RETURN
					END
				END
			END
		END
	END;
	KernelLog.String("No reachable supported manual door was found");
	KernelLog.Ln;
	context.result := Commands.CommandError
END Do;

END DoomOriginalDoorsSmoke.
