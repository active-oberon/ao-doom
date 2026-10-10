MODULE DoomDoors;

IMPORT DoomWad, DoomInventory, GameBytes, GameGeometry, MathL;

CONST Speed = 2.0 / 64;
	Wait = 150;
	UseRange = 1.0;

TYPE
	Trigger = RECORD
		special, front, back: SIGNED32
	END;

	Door = RECORD
		direction, timer: SIGNED32;
		top, speed: FLOAT64;
		stayOpen: BOOLEAN
	END;

	Controller* = OBJECT
	VAR triggers: POINTER TO ARRAY OF Trigger;
		doors: POINTER TO ARRAY OF Door;
		moving: POINTER TO ARRAY OF BOOLEAN;
		heights: POINTER TO ARRAY OF FLOAT64;
		active: SIGNED32;

		PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines, sides: DoomWad.Lump;
			sectorCount: SIGNED32);
		VAR i, offset, side: SIGNED32;
		BEGIN
			NEW(triggers, lines.size DIV 14);
			NEW(doors, sectorCount);
			NEW(moving, sectorCount);
			NEW(heights, sectorCount);
			FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
				offset := lines.offset + i * 14;
				triggers[i].special := GameBytes.U16(archive.data^, offset + 6);
				side := GameBytes.U16(archive.data^, offset + 10);
				triggers[i].front := GameBytes.U16(archive.data^, sides.offset + side * 30 + 28);
				triggers[i].back := -1;
				side := GameBytes.U16(archive.data^, offset + 12);
				IF side # 65535 THEN
					triggers[i].back := GameBytes.U16(archive.data^, sides.offset + side * 30 + 28);
					IF Supported(triggers[i].special) THEN
						moving[triggers[i].back] := TRUE
					END
				END
			END
		END Init;

		PROCEDURE Moving*(sector: SIGNED32): BOOLEAN;
		BEGIN
			RETURN moving[sector]
		END Moving;

		PROCEDURE Top(world: GameGeometry.World; sector: SIGNED32): FLOAT64;
		VAR i, neighbor: SIGNED32;
			height: FLOAT64;
			region: GameGeometry.Sector;
		BEGIN
			height := MAX(FLOAT64);
			FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
				neighbor := -1;
				IF triggers[i].front = sector THEN
					neighbor := triggers[i].back
				ELSIF triggers[i].back = sector THEN
					neighbor := triggers[i].front
				END;
				IF (neighbor >= 0) & (neighbor # sector) THEN
					region := world.Region(neighbor);
					height := MIN(height, region.ceiling)
				END
			END;
			RETURN height - 4.0 / 64
		END Top;

		PROCEDURE Use*(world: GameGeometry.World; x, y, angle: FLOAT64;
			VAR player: DoomInventory.State): BOOLEAN;
		VAR wall: GameGeometry.Wall;
			front, back: GameGeometry.Sector;
			i, sector, special, key: SIGNED32;
			distance, near, top: FLOAT64;
		BEGIN
			player.neededKey := -1;
			near := 0;
			(* shortcut: use traces stop after 256 hits; add spatial traversal for denser edited maps. *)
			FOR i := 1 TO MIN(world.Count(), 256) DO
				IF ~world.CastSector(-1, x, y, MathL.cos(angle), MathL.sin(angle), near, distance, wall) OR
					(distance > UseRange) THEN
					RETURN FALSE
				END;
				ASSERT((wall.id >= 0) & (wall.id < LEN(triggers^)));
				special := triggers[wall.id].special;
				IF special # 0 THEN
					sector := triggers[wall.id].back;
					IF ~Supported(special) OR (sector < 0) OR
						((x - wall.ax) * (wall.by - wall.ay) > (y - wall.ay) * (wall.bx - wall.ax)) THEN
						RETURN FALSE
					END;
					CASE special OF
					26, 32:
						key := DoomInventory.BlueCard
					| 27, 34:
						key := DoomInventory.YellowCard
					| 28, 33:
						key := DoomInventory.RedCard
					ELSE
						key := -1
					END;
					IF (key >= 0) & ~((key IN player.keys) OR (key + 3 IN player.keys)) THEN
						player.neededKey := key;
						RETURN FALSE
					END;
					IF doors[sector].direction # 0 THEN
						IF (special = 1) OR ((special >= 26) & (special <= 28)) OR (special = 117) THEN
							IF doors[sector].direction = -1 THEN
								doors[sector].direction := 1
							ELSE
								doors[sector].direction := -1
							END;
							RETURN TRUE
						END;
						RETURN FALSE
					END;
					top := Top(world, sector);
					back := world.Region(sector);
					IF (top = MAX(FLOAT64)) OR (top <= back.ceiling) OR (top <= back.floor) THEN
						RETURN FALSE
					END;
					doors[sector].top := top;
					doors[sector].speed := Speed;
					IF special >= 117 THEN
						doors[sector].speed := Speed * 4
					END;
					doors[sector].stayOpen := ((special >= 31) & (special <= 34)) OR (special = 118);
					IF doors[sector].stayOpen THEN
						triggers[wall.id].special := 0
					END;
					doors[sector].direction := 1;
					INC(active);
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

		PROCEDURE Step*(VAR world: GameGeometry.World; x, y, radius, feet, height, step: FLOAT64);
		VAR i: SIGNED32;
			region: GameGeometry.Sector;
			candidate: GameGeometry.World;
			previous, floor: FLOAT64;
		BEGIN
			IF active = 0 THEN
				RETURN
			END;
			FOR i := 0 TO SIGNED32(LEN(heights^)) - 1 DO
				region := world.Region(i);
				heights[i] := region.ceiling
			END;
			FOR i := 0 TO SIGNED32(LEN(doors^)) - 1 DO
				IF doors[i].direction = 2 THEN
					DEC(doors[i].timer);
					IF doors[i].timer = 0 THEN
						doors[i].direction := -1
					END
				ELSIF doors[i].direction # 0 THEN
					previous := heights[i];
					IF doors[i].direction = 1 THEN
						heights[i] := MIN(doors[i].top, heights[i] + doors[i].speed)
					ELSE
						region := world.Region(i);
						heights[i] := MAX(region.floor, heights[i] - doors[i].speed)
					END;
					candidate := world.WithCeilings(heights^);
					ASSERT(candidate # NIL);
					IF ~candidate.Stand(x, y, radius, feet, height, step, floor) THEN
						heights[i] := previous;
						doors[i].direction := 1
					ELSE
						world := candidate;
						IF (doors[i].direction = 1) & (heights[i] = doors[i].top) THEN
							IF doors[i].stayOpen THEN
								doors[i].direction := 0;
								DEC(active)
							ELSE
								doors[i].direction := 2;
								doors[i].timer := Wait
							END
						ELSIF doors[i].direction = -1 THEN
							region := world.Region(i);
							IF heights[i] = region.floor THEN
								doors[i].direction := 0;
								DEC(active)
							END
						END
					END
				END
			END
		END Step;
	END Controller;

PROCEDURE Supported(special: SIGNED32): BOOLEAN;
BEGIN
	RETURN (special = 1) OR ((special >= 26) & (special <= 28)) OR
		((special >= 31) & (special <= 34)) OR (special = 117) OR (special = 118)
END Supported;

END DoomDoors.
