MODULE DoomFloors;

IMPORT DoomConfig, DoomFormat, DoomActions, DoomWad, GameBytes, GameGeometry, Random;

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
	WalkPerpetual = 53;
	RepeatPerpetual = 87;
	WalkStopLift = 54;
	RepeatStopLift = 89;
	SwitchStairs = 7;
	WalkStairs = 8;
	WalkFastStairs = 100;
	SwitchFastStairs = 127;
	Unsupported = 0;
	Using = 1;
	Walk = 2;
	Gun = 3;
	LowerHighest = 1;
	LowerLowest = 2;
	RaiseNearest = 3;
	RaiseCeiling = 4;
	Lift = 5;
	Perpetual = 6;
	StopLift = 7;
	Stairs = 8;
	Idle = 0;
	Up = 1;
	Down = -1;
	Waiting = 2;
	Paused = 3;

TYPE Occupants* = PROCEDURE {DELEGATE} (before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;

Trigger = RECORD
	geometry: GameGeometry.Wall;
	tag, front, back, activation, kind: SIGNED32;
	repeat, fast, pending, twoSided: BOOLEAN
END;

Motion = RECORD
	direction, oldDirection, timer: SIGNED32;
	target, low, high, speed: FLOAT64;
	lift, perpetual: BOOLEAN
END;

Controller* = OBJECT
VAR triggers: POINTER TO ARRAY OF Trigger;
	motions: POINTER TO ARRAY OF Motion;
	tags: POINTER TO ARRAY OF SIGNED32;
	first, next: POINTER TO ARRAY OF SIGNED32;
	flats: POINTER TO ARRAY OF ARRAY DoomFormat.NameLength + 1 OF CHAR;
	moving: POINTER TO ARRAY OF BOOLEAN;
	heights: POINTER TO ARRAY OF FLOAT64;
	actions: DoomActions.Table;
	random: Random.Generator;
	active: SIGNED32;

	PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines, sides, sectors, vertices: DoomWad.Lump;
		shared: DoomActions.Table);
	VAR i, j, offset, side, a, b, sectorCount, head, count, sector: SIGNED32;
		movingTags, stairTags, stairMoving: POINTER TO ARRAY OF BOOLEAN;
		pending: POINTER TO ARRAY OF SIGNED32;
	BEGIN
		actions := shared;
		NEW(random);
		sectorCount := sectors.size DIV DoomFormat.SectorSize;
		NEW(triggers, lines.size DIV DoomFormat.LineSize);
		NEW(motions, sectorCount);
		NEW(tags, sectorCount);
		NEW(first, sectorCount);
		NEW(next, LEN(triggers^));
		NEW(flats, sectorCount);
		NEW(moving, sectorCount);
		NEW(heights, sectorCount);
		NEW(movingTags, DoomFormat.MaximumRecords);
		NEW(stairTags, DoomFormat.MaximumRecords);
		NEW(stairMoving, sectorCount);
		NEW(pending, sectorCount);
		FOR i := 0 TO sectorCount - 1 DO
			offset := sectors.offset + i * DoomFormat.SectorSize;
			tags[i] := GameBytes.U16(archive.data^, offset + DoomFormat.SectorTag);
			first[i] := -1;
			FOR j := 0 TO DoomFormat.NameLength - 1 DO
				flats[i][j] := CAP(archive.data[offset + 4 + j])
			END;
			flats[i][DoomFormat.NameLength] := 0X
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			offset := lines.offset + i * DoomFormat.LineSize;
			Classify(actions.Special(i), triggers[i]);
			triggers[i].tag := GameBytes.U16(archive.data^, offset + DoomFormat.LineTag);
			triggers[i].twoSided := GameBytes.U16(archive.data^, offset + DoomFormat.LineFlags) DIV 4 MOD 2 = 1;
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
			IF (triggers[i].activation # Unsupported) & (triggers[i].kind # StopLift) THEN
				movingTags[triggers[i].tag] := TRUE
			END;
			IF triggers[i].kind = Stairs THEN
				stairTags[triggers[i].tag] := TRUE
			END
		END;
		FOR i := SIGNED32(LEN(triggers^)) - 1 TO 0 BY -1 DO
			next[i] := -1;
			IF triggers[i].twoSided & (triggers[i].back >= 0) THEN
				next[i] := first[triggers[i].front];
				first[triggers[i].front] := i
			END
		END;
		count := 0;
		FOR i := 0 TO sectorCount - 1 DO
			moving[i] := movingTags[tags[i]];
			IF stairTags[tags[i]] THEN
				stairMoving[i] := TRUE;
				pending[count] := i;
				INC(count)
			END
		END;
		head := 0;
		WHILE head < count DO
			sector := pending[head];
			INC(head);
			i := first[sector];
			WHILE i >= 0 DO
				b := triggers[i].back;
				IF ~stairMoving[b] & (flats[b] = flats[sector]) THEN
					stairMoving[b] := TRUE;
					pending[count] := b;
					INC(count)
				END;
				i := next[i]
			END
		END;
		FOR i := 0 TO sectorCount - 1 DO
			moving[i] := moving[i] OR stairMoving[i]
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
				| LowerLowest, Lift, Perpetual:
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
		IF trigger.kind = StopLift THEN
			IF motions[sector].lift & (motions[sector].direction # Idle) & (motions[sector].direction # Paused) THEN
				motions[sector].oldDirection := motions[sector].direction;
				motions[sector].direction := Paused;
				DEC(active);
				RETURN TRUE
			END;
			RETURN FALSE
		END;
		IF (trigger.kind = Perpetual) & (motions[sector].direction = Paused) THEN
			motions[sector].direction := motions[sector].oldDirection;
			INC(active);
			RETURN TRUE
		END;
		IF ~actions.Claim(sector) THEN
			RETURN FALSE
		END;
		region := world.Region(sector);
		motions[sector].perpetual := trigger.kind = Perpetual;
		motions[sector].lift := (trigger.kind = Lift) OR motions[sector].perpetual;
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
		IF motions[sector].perpetual THEN
			motions[sector].low := Target(world, sector, LowerLowest);
			motions[sector].high := MAX(region.floor, Target(world, sector, LowerHighest));
			motions[sector].speed := DoomConfig.values.perpetualPlatformSpeed;
			motions[sector].direction := Down;
			motions[sector].target := motions[sector].low;
			(* shortcut: platform randomness is controller-local; share the classic sequence when implementing demo compatibility. *)
			IF random.Dice(2) = 0 THEN
				motions[sector].direction := Up;
				motions[sector].target := motions[sector].high
			END
		ELSIF motions[sector].lift THEN
			motions[sector].speed := DoomConfig.values.platformSpeed;
			IF trigger.fast THEN
				motions[sector].speed := DoomConfig.values.fastPlatformSpeed
			END
		END;
		INC(active);
		RETURN TRUE
	END Start;

	(* BuildStairs follows front-to-back neighbors in WAD order and claims each moving step once. *)
	PROCEDURE BuildStairs(world: GameGeometry.World; VAR sector: SIGNED32; fast: BOOLEAN): BOOLEAN;
	VAR line, neighbor: SIGNED32;
		height, step, speed: FLOAT64;
		flat: ARRAY DoomFormat.NameLength + 1 OF CHAR;
		found: BOOLEAN;
	BEGIN
		IF ~actions.Claim(sector) THEN
			RETURN FALSE
		END;
		COPY(flats[sector], flat);
		height := world.Region(sector).floor;
		step := DoomConfig.values.stairStep;
		speed := DoomConfig.values.stairSpeed;
		IF fast THEN
			step := DoomConfig.values.fastStairStep;
			speed := DoomConfig.values.fastStairSpeed
		END;
		height := height + step;
		LOOP
			motions[sector].direction := Up;
			motions[sector].target := height;
			motions[sector].speed := speed;
			motions[sector].lift := FALSE;
			motions[sector].perpetual := FALSE;
			INC(active);
			found := FALSE;
			line := first[sector];
			WHILE (line >= 0) & ~found DO
				neighbor := triggers[line].back;
				IF flats[neighbor] = flat THEN
					height := height + step;
					IF actions.Claim(neighbor) THEN
						sector := neighbor;
						found := TRUE
						END
				END;
				line := next[line]
			END;
			IF ~found THEN
				EXIT
			END
		END;
		RETURN TRUE
	END BuildStairs;

	PROCEDURE Activate(world: GameGeometry.World; line: SIGNED32): BOOLEAN;
	VAR i: SIGNED32;
		started: BOOLEAN;
	BEGIN
		started := FALSE;
		i := 0;
		WHILE i < LEN(tags^) DO
			IF tags[i] = triggers[line].tag THEN
				IF triggers[line].kind = Stairs THEN
					started := BuildStairs(world, i, triggers[line].fast) OR started
				ELSIF Start(world, i, triggers[line]) THEN
					started := TRUE
				END
			END;
			INC(i)
		END;
		IF (started & (triggers[line].activation = Using)) OR (triggers[line].activation = Gun) THEN
			actions.Activated(line, triggers[line].repeat)
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
					motions[i].target := motions[i].high;
					IF world.Region(i).floor # motions[i].low THEN
						motions[i].direction := Down;
						motions[i].target := motions[i].low
					END
				END
			ELSIF (motions[i].direction = Up) OR (motions[i].direction = Down) THEN
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
						IF motions[i].lift & ((motions[i].direction = Down) OR motions[i].perpetual) THEN
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
	| WalkPerpetual, RepeatPerpetual:
		trigger.kind := Perpetual
	| WalkStopLift, RepeatStopLift:
		trigger.kind := StopLift
	| SwitchStairs, WalkStairs, WalkFastStairs, SwitchFastStairs:
		trigger.kind := Stairs
	ELSE
		RETURN
	END;
	trigger.activation := Using;
	CASE special OF
	WalkLowerHighest, RepeatLowerHighest, WalkLowerLowest, RepeatLowerLowest, WalkRaiseNearest, RepeatRaiseNearest,
		WalkRaiseCeiling, RepeatRaiseCeiling, WalkLift, RepeatLift, RepeatFastLift, WalkFastLift,
		WalkPerpetual, RepeatPerpetual, WalkStopLift, RepeatStopLift, WalkStairs, WalkFastStairs:
		trigger.activation := Walk
	| GunRaiseCeiling:
		trigger.activation := Gun
	ELSE
	END;
	CASE special OF
	ButtonLowerHighest, RepeatLowerHighest, ButtonLowerLowest, RepeatLowerLowest, ButtonRaiseNearest, RepeatRaiseNearest,
		ButtonRaiseCeiling, RepeatRaiseCeiling, ButtonLift, RepeatLift, RepeatFastLift, ButtonFastLift,
		RepeatPerpetual, RepeatStopLift:
		trigger.repeat := TRUE
	ELSE
	END;
	trigger.fast := (special = RepeatFastLift) OR (special = WalkFastLift) OR
		(special = SwitchFastLift) OR (special = ButtonFastLift) OR
		(special = WalkFastStairs) OR (special = SwitchFastStairs)
END Classify;

END DoomFloors.
