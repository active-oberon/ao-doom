MODULE DoomFloors;

IMPORT DoomConfig, DoomFormat, DoomActions, DoomWad, GameBytes, GameGeometry;

CONST WalkLowerHighest = 19;
	ButtonLowerHighest = 45;
	RepeatLowerHighest = 83;
	SwitchLowerHighest = 102;
	SwitchLowerLowest = 23;
	WalkLowerLowest = 38;
	ButtonLowerLowest = 60;
	RepeatLowerLowest = 82;
	SwitchRaiseNearest = 18;
	ButtonRaiseNearest = 69;
	WalkRaiseNearest = 119;
	RepeatRaiseNearest = 128;
	WalkRaiseCeiling = 5;
	GunRaiseCeiling = 24;
	ButtonRaiseCeiling = 64;
	RepeatRaiseCeiling = 91;
	SwitchRaiseCeiling = 101;
	WalkLift = 10;
	SwitchLift = 21;
	ButtonLift = 62;
	RepeatLift = 88;
	RepeatFastLift = 120;
	WalkFastLift = 121;
	SwitchFastLift = 122;
	ButtonFastLift = 123;
	Unsupported = 0;
	Using = 1;
	Walk = 2;
	Gun = 3;
	LowerHighest = 1;
	LowerLowest = 2;
	RaiseNearest = 3;
	RaiseCeiling = 4;
	Lift = 5;
	Idle = 0;
	Up = 1;
	Down = -1;
	Waiting = 2;

TYPE Occupants* = PROCEDURE {DELEGATE} (before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;

Trigger = RECORD
	geometry: GameGeometry.Wall;
	tag, front, back, activation, kind: SIGNED32;
	repeat, fast, pending: BOOLEAN
END;

Motion = RECORD
	direction, timer: SIGNED32;
	target, low, high, speed: FLOAT64;
	lift: BOOLEAN
END;

Controller* = OBJECT
VAR triggers: POINTER TO ARRAY OF Trigger;
	motions: POINTER TO ARRAY OF Motion;
	tags: POINTER TO ARRAY OF SIGNED32;
	moving: POINTER TO ARRAY OF BOOLEAN;
	heights: POINTER TO ARRAY OF FLOAT64;
	actions: DoomActions.Table;
	active: SIGNED32;

	PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines, sides, sectors, vertices: DoomWad.Lump;
		shared: DoomActions.Table);
	VAR i, offset, side, a, b, sectorCount: SIGNED32;
		movingTags: POINTER TO ARRAY OF BOOLEAN;
	BEGIN
		actions := shared;
		sectorCount := sectors.size DIV DoomFormat.SectorSize;
		NEW(triggers, lines.size DIV DoomFormat.LineSize);
		NEW(motions, sectorCount);
		NEW(tags, sectorCount);
		NEW(moving, sectorCount);
		NEW(heights, sectorCount);
		NEW(movingTags, DoomFormat.MaximumRecords);
		FOR i := 0 TO sectorCount - 1 DO
			tags[i] := GameBytes.U16(archive.data^, sectors.offset + i * DoomFormat.SectorSize + DoomFormat.SectorTag)
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			offset := lines.offset + i * DoomFormat.LineSize;
			Classify(actions.Special(i), triggers[i]);
			triggers[i].tag := GameBytes.U16(archive.data^, offset + DoomFormat.LineTag);
			side := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
			triggers[i].front := GameBytes.U16(archive.data^, sides.offset + side * DoomFormat.SideSize + DoomFormat.SideSector);
			triggers[i].back := -1;
			side := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
			IF side # DoomFormat.NoSide THEN
				triggers[i].back := GameBytes.U16(archive.data^, sides.offset + side * DoomFormat.SideSize + DoomFormat.SideSector)
			END;
			a := vertices.offset + GameBytes.U16(archive.data^, offset) * DoomFormat.VertexSize;
			b := vertices.offset + GameBytes.U16(archive.data^, offset + 2) * DoomFormat.VertexSize;
			triggers[i].geometry.ax := GameBytes.I16(archive.data^, a) / DoomFormat.UnitsPerWorld;
			triggers[i].geometry.ay := -GameBytes.I16(archive.data^, a + 2) / DoomFormat.UnitsPerWorld;
			triggers[i].geometry.bx := GameBytes.I16(archive.data^, b) / DoomFormat.UnitsPerWorld;
			triggers[i].geometry.by := -GameBytes.I16(archive.data^, b + 2) / DoomFormat.UnitsPerWorld;
			IF triggers[i].activation # Unsupported THEN
				movingTags[triggers[i].tag] := TRUE
			END
		END;
		FOR i := 0 TO sectorCount - 1 DO
			moving[i] := movingTags[tags[i]]
		END
	END Init;

	PROCEDURE Moving*(sector: SIGNED32): BOOLEAN;
	BEGIN
		RETURN moving[sector]
	END Moving;

	PROCEDURE Target(world: GameGeometry.World; sector, kind: SIGNED32): FLOAT64;
	VAR i, neighbor: SIGNED32;
		region, other: GameGeometry.Sector;
		result: FLOAT64;
	BEGIN
		region := world.Region(sector);
		result := region.floor;
		IF kind = LowerHighest THEN
			result := MIN(FLOAT64)
		ELSIF kind = RaiseNearest THEN
			result := MAX(FLOAT64)
		ELSIF kind = RaiseCeiling THEN
			result := region.ceiling
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			neighbor := -1;
			IF triggers[i].front = sector THEN
				neighbor := triggers[i].back
			ELSIF triggers[i].back = sector THEN
				neighbor := triggers[i].front
			END;
			IF (neighbor >= 0) & (neighbor # sector) THEN
				other := world.Region(neighbor);
				CASE kind OF
				LowerHighest:
					result := MAX(result, other.floor)
				| LowerLowest, Lift:
					result := MIN(result, other.floor)
				| RaiseNearest:
					IF other.floor > region.floor THEN
						result := MIN(result, other.floor)
					END
				| RaiseCeiling:
					result := MIN(result, other.ceiling)
				END
			END
		END;
		IF (result = MIN(FLOAT64)) OR (result = MAX(FLOAT64)) THEN
			RETURN region.floor
		END;
		RETURN result
	END Target;

	PROCEDURE Start(world: GameGeometry.World; sector: SIGNED32; CONST trigger: Trigger): BOOLEAN;
	VAR region: GameGeometry.Sector;
	BEGIN
		IF ~actions.Claim(sector) THEN
			RETURN FALSE
		END;
		region := world.Region(sector);
		motions[sector].lift := trigger.kind = Lift;
		motions[sector].high := region.floor;
		motions[sector].target := Target(world, sector, trigger.kind);
		motions[sector].speed := DoomConfig.values.floorSpeed;
		motions[sector].direction := Up;
		IF (trigger.kind = LowerHighest) OR (trigger.kind = LowerLowest) OR (trigger.kind = Lift) THEN
			motions[sector].direction := Down;
			motions[sector].target := MIN(region.floor, motions[sector].target)
		ELSE
			motions[sector].target := MAX(region.floor, motions[sector].target)
		END;
		motions[sector].low := motions[sector].target;
		IF motions[sector].lift THEN
			motions[sector].speed := DoomConfig.values.platformSpeed;
			IF trigger.fast THEN
				motions[sector].speed := DoomConfig.values.fastPlatformSpeed
			END
		END;
		INC(active);
		RETURN TRUE
	END Start;

	PROCEDURE Activate(world: GameGeometry.World; line: SIGNED32): BOOLEAN;
	VAR i: SIGNED32;
		started: BOOLEAN;
	BEGIN
		started := FALSE;
		FOR i := 0 TO SIGNED32(LEN(tags^)) - 1 DO
			IF (tags[i] = triggers[line].tag) & Start(world, i, triggers[line]) THEN
				started := TRUE
			END
		END;
		IF ~triggers[line].repeat & (started OR (triggers[line].activation = Walk) OR (triggers[line].activation = Gun)) THEN
			actions.Consume(line)
		END;
		RETURN started
	END Activate;

	PROCEDURE Use*(world: GameGeometry.World; x, y, angle: FLOAT64): BOOLEAN;
	VAR line: SIGNED32;
	BEGIN
		line := actions.UseLine(world, x, y, angle);
		IF (line < 0) OR (triggers[line].activation # Using) THEN
			RETURN FALSE
		END;
		RETURN Activate(world, line)
	END Use;

	PROCEDURE Crossed*(x0, y0, x1, y1: FLOAT64);
	VAR i: SIGNED32;
		fraction: FLOAT64;
	BEGIN
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			IF (actions.Special(i) # 0) & (triggers[i].activation = Walk) &
				GameGeometry.Crossing(triggers[i].geometry, x0, y0, x1, y1, fraction) THEN
				triggers[i].pending := TRUE
			END
		END
	END Crossed;

	PROCEDURE ApplyCrossings*(world: GameGeometry.World);
	VAR i: SIGNED32;
		started: BOOLEAN;
	BEGIN
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			IF triggers[i].pending THEN
				triggers[i].pending := FALSE;
				started := Activate(world, i)
			END
		END
	END ApplyCrossings;

	PROCEDURE Shot*(world: GameGeometry.World; line: SIGNED32);
	VAR started: BOOLEAN;
	BEGIN
		IF (actions.Special(line) # 0) & (triggers[line].activation = Gun) THEN
			started := Activate(world, line)
		END
	END Shot;

	(* Step carries occupants only after a proposed plane fits, and reverses a blocked ascending lift. *)
	PROCEDURE Step*(VAR world: GameGeometry.World; x, y, radius: FLOAT64; VAR feet: FLOAT64;
		height, step: FLOAT64; occupants: Occupants);
	VAR i: SIGNED32;
		candidate: GameGeometry.World;
		previous, floor: FLOAT64;
		fits: BOOLEAN;
	BEGIN
		IF active = 0 THEN
			RETURN
		END;
		FOR i := 0 TO SIGNED32(LEN(heights^)) - 1 DO
			heights[i] := world.Region(i).floor
		END;
		FOR i := 0 TO SIGNED32(LEN(motions^)) - 1 DO
			IF motions[i].direction = Waiting THEN
				DEC(motions[i].timer);
				IF motions[i].timer = 0 THEN
					motions[i].direction := Up;
					motions[i].target := motions[i].high
				END
			ELSIF motions[i].direction # Idle THEN
				previous := heights[i];
				IF motions[i].direction = Up THEN
					heights[i] := MIN(motions[i].target, heights[i] + motions[i].speed)
				ELSE
					heights[i] := MAX(motions[i].target, heights[i] - motions[i].speed)
				END;
				candidate := world;
				IF heights[i] # previous THEN
					candidate := world.WithFloors(heights^);
					ASSERT(candidate # NIL)
				END;
				fits := candidate.Stand(x, y, radius, feet, height, step, floor);
				IF ~fits THEN
					fits := candidate.Stand(x, y, radius, floor, height, step, floor)
				END;
				IF fits & ((occupants = NIL) OR (candidate = world) OR occupants(world, candidate, i)) THEN
					world := candidate;
					feet := floor;
					IF heights[i] = motions[i].target THEN
						IF motions[i].lift & (motions[i].direction = Down) THEN
							motions[i].direction := Waiting;
							motions[i].timer := DoomConfig.values.platformWait
						ELSE
							motions[i].direction := Idle;
							DEC(active);
							actions.Release(i)
						END
					END
				ELSE
					heights[i] := previous;
					IF motions[i].lift & (motions[i].direction = Up) THEN
						motions[i].direction := Down;
						motions[i].target := motions[i].low
					END
				END
			END
		END
	END Step;
END Controller;

PROCEDURE Classify(special: SIGNED32; VAR trigger: Trigger);
BEGIN
	CASE special OF
	WalkLowerHighest, ButtonLowerHighest, RepeatLowerHighest, SwitchLowerHighest:
		trigger.kind := LowerHighest
	| SwitchLowerLowest, WalkLowerLowest, ButtonLowerLowest, RepeatLowerLowest:
		trigger.kind := LowerLowest
	| SwitchRaiseNearest, ButtonRaiseNearest, WalkRaiseNearest, RepeatRaiseNearest:
		trigger.kind := RaiseNearest
	| WalkRaiseCeiling, GunRaiseCeiling, ButtonRaiseCeiling, RepeatRaiseCeiling, SwitchRaiseCeiling:
		trigger.kind := RaiseCeiling
	| WalkLift, SwitchLift, ButtonLift, RepeatLift, RepeatFastLift, WalkFastLift, SwitchFastLift, ButtonFastLift:
		trigger.kind := Lift
	ELSE
		RETURN
	END;
	trigger.activation := Using;
	CASE special OF
	WalkLowerHighest, RepeatLowerHighest, WalkLowerLowest, RepeatLowerLowest, WalkRaiseNearest, RepeatRaiseNearest,
		WalkRaiseCeiling, RepeatRaiseCeiling, WalkLift, RepeatLift, RepeatFastLift, WalkFastLift:
		trigger.activation := Walk
	| GunRaiseCeiling:
		trigger.activation := Gun
	ELSE
	END;
	CASE special OF
	ButtonLowerHighest, RepeatLowerHighest, ButtonLowerLowest, RepeatLowerLowest, ButtonRaiseNearest, RepeatRaiseNearest,
		ButtonRaiseCeiling, RepeatRaiseCeiling, ButtonLift, RepeatLift, RepeatFastLift, ButtonFastLift:
		trigger.repeat := TRUE
	ELSE
	END;
	trigger.fast := (special = RepeatFastLift) OR (special = WalkFastLift) OR
		(special = SwitchFastLift) OR (special = ButtonFastLift)
END Classify;

END DoomFloors.
