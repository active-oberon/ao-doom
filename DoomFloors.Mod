MODULE DoomFloors;

IMPORT DoomConfig, DoomFormat, DoomActions, DoomWad, GameBytes, GameGeometry, GameMaterials, Random;

CONST WalkLowerHighest = 19;
	ButtonLowerHighest = 45;
	RepeatLowerHighest = 83;
	SwitchLowerHighest = 102;
	SwitchLowerLowest = 23;
	WalkLowerLowest = 38;
	ButtonLowerLowest = 60;
	RepeatLowerLowest = 82;
	WalkLowerChange = 37;
	RepeatLowerChange = 84;
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
	WalkRaiseStep = 58;
	RepeatRaiseStep = 92;
	WalkRaiseStepChange = 59;
	RepeatRaiseStepChange = 93;
	SwitchRaiseLarge = 140;
	WalkTurboLower = 36;
	ButtonTurboLower = 70;
	SwitchTurboLower = 71;
	RepeatTurboLower = 98;
	RepeatFastNearest = 129;
	WalkFastNearest = 130;
	SwitchFastNearest = 131;
	ButtonFastNearest = 132;
	SwitchDonut = 9;
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
	LowerChange = 9;
	RaiseStep = 10;
	RaiseLarge = 11;
	TurboLower = 12;
	RaiseStepChange = 13;
	Donut = 14;
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
	lift, perpetual, change: BOOLEAN;
	texture: GameMaterials.Texture;
	flat: ARRAY DoomFormat.NameLength + 1 OF CHAR;
	special: SIGNED32
END;

Controller* = OBJECT
VAR triggers: POINTER TO ARRAY OF Trigger;
	motions: POINTER TO ARRAY OF Motion;
	tags: POINTER TO ARRAY OF SIGNED32;
	specials: POINTER TO ARRAY OF SIGNED32;
	first, next: POINTER TO ARRAY OF SIGNED32;
	flats: POINTER TO ARRAY OF ARRAY DoomFormat.NameLength + 1 OF CHAR;
	moving: POINTER TO ARRAY OF BOOLEAN;
	heights: POINTER TO ARRAY OF FLOAT64;
	actions: DoomActions.Table;
	random: Random.Generator;
	active: SIGNED32;

	PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines, sides, sectors, vertices: DoomWad.Lump;
		shared: DoomActions.Table);
	VAR i, j, offset, side, a, b, sectorCount, head, count, sector, ring, model: SIGNED32;
		movingTags, stairTags, stairMoving, donutTags: POINTER TO ARRAY OF BOOLEAN;
		pending: POINTER TO ARRAY OF SIGNED32;
		mutableFlats: BOOLEAN;
	BEGIN
		actions := shared;
		mutableFlats := FALSE;
		NEW(random);
		sectorCount := sectors.size DIV DoomFormat.SectorSize;
		NEW(triggers, lines.size DIV DoomFormat.LineSize);
		NEW(motions, sectorCount);
		NEW(tags, sectorCount);
		NEW(specials, sectorCount);
		NEW(first, sectorCount);
		NEW(next, LEN(triggers^));
		NEW(flats, sectorCount);
		NEW(moving, sectorCount);
		NEW(heights, sectorCount);
		NEW(movingTags, DoomFormat.MaximumRecords);
		NEW(stairTags, DoomFormat.MaximumRecords);
		NEW(donutTags, DoomFormat.MaximumRecords);
		NEW(stairMoving, sectorCount);
		NEW(pending, sectorCount);
		FOR i := 0 TO sectorCount - 1 DO
			offset := sectors.offset + i * DoomFormat.SectorSize;
			tags[i] := GameBytes.U16(archive.data^, offset + DoomFormat.SectorTag);
			specials[i] := GameBytes.U16(archive.data^, offset + DoomFormat.SectorSpecial);
			first[i] := -1;
			FOR j := 0 TO DoomFormat.NameLength - 1 DO
				flats[i][j] := CAP(archive.data[offset + 4 + j])
			END;
			flats[i][DoomFormat.NameLength] := 0X
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			offset := lines.offset + i * DoomFormat.LineSize;
			Classify(actions.Special(i), triggers[i]);
			mutableFlats := mutableFlats OR (triggers[i].kind = LowerChange) OR
				(triggers[i].kind = RaiseStepChange) OR (triggers[i].kind = Donut);
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
			ELSIF triggers[i].kind = Donut THEN
				donutTags[triggers[i].tag] := TRUE
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
		FOR i := 0 TO sectorCount - 1 DO
			IF donutTags[tags[i]] & DonutSectors(i, ring, model) THEN
				moving[ring] := TRUE
			END
		END;
		head := 0;
		WHILE head < count DO
			sector := pending[head];
			INC(head);
			i := first[sector];
			WHILE i >= 0 DO
				b := triggers[i].back;
				(* A changed flat can join previously separate stair chains; validate every directed reachable step. *)
				IF ~stairMoving[b] & (mutableFlats OR (flats[b] = flats[sector])) THEN
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

	PROCEDURE SectorSpecial*(sector: SIGNED32): SIGNED32;
	BEGIN
		RETURN specials[sector]
	END SectorSpecial;

	PROCEDURE Neighbor(line, sector: SIGNED32): SIGNED32;
	VAR neighbor: SIGNED32;
	BEGIN
		neighbor := -1;
		IF triggers[line].twoSided THEN
			IF triggers[line].front = sector THEN
				neighbor := triggers[line].back
			ELSIF triggers[line].back = sector THEN
				neighbor := triggers[line].front
			END
		END;
		IF neighbor = sector THEN
			neighbor := -1
		END;
		RETURN neighbor
	END Neighbor;

	(* DonutSectors chooses the first ring and outer neighbor in WAD order without unsafe side assumptions. *)
	PROCEDURE DonutSectors(sector: SIGNED32; VAR ring, model: SIGNED32): BOOLEAN;
	VAR i, neighbor: SIGNED32;
	BEGIN
		ring := -1;
		model := -1;
		i := 0;
		WHILE (i < LEN(triggers^)) & (ring < 0) DO
			ring := Neighbor(i, sector);
			INC(i)
		END;
		IF ring < 0 THEN
			RETURN FALSE
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			neighbor := Neighbor(i, ring);
			IF (neighbor >= 0) & (neighbor # sector) THEN
				model := neighbor;
				RETURN TRUE
			END
		END;
		RETURN FALSE
	END DonutSectors;

	PROCEDURE Target(world: GameGeometry.World; sector, kind: SIGNED32): FLOAT64;
	VAR i, neighbor: SIGNED32;
		region, other: GameGeometry.Sector;
		result: FLOAT64;
	BEGIN
		region := world.Region(sector);
		result := region.floor;
		IF (kind = LowerHighest) OR (kind = TurboLower) THEN
			result := MIN(FLOAT64)
		ELSIF kind = RaiseNearest THEN
			result := MAX(FLOAT64)
		ELSIF kind = RaiseCeiling THEN
			result := region.ceiling
		ELSIF (kind = RaiseStep) OR (kind = RaiseStepChange) THEN
			RETURN region.floor + DoomConfig.values.floorRaiseStep
		ELSIF kind = RaiseLarge THEN
			RETURN region.floor + DoomConfig.values.floorLargeRaiseStep
		END;
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			neighbor := -1;
			IF triggers[i].front = sector THEN
				neighbor := triggers[i].back
			ELSIF triggers[i].back = sector THEN
				neighbor := triggers[i].front
			END;
			IF (neighbor >= 0) & (neighbor # sector) & ((kind # LowerChange) OR triggers[i].twoSided) THEN
				other := world.Region(neighbor);
				CASE kind OF
				LowerHighest, TurboLower:
					result := MAX(result, other.floor)
				| LowerLowest, Lift, Perpetual, LowerChange:
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
		IF (kind = TurboLower) & (result # region.floor) THEN
			result := result + DoomConfig.values.floorTurboLowerGap
		END;
		RETURN result
	END Target;

	(* Capture the first adjacent model at the destination in WAD linedef order, before motion starts. *)
	PROCEDURE LowerModel(world: GameGeometry.World; sector: SIGNED32);
	VAR i, neighbor: SIGNED32;
	BEGIN
		motions[sector].texture := world.Region(sector).floorTexture;
		COPY(flats[sector], motions[sector].flat);
		motions[sector].special := specials[sector];
		FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
			neighbor := -1;
			IF triggers[i].twoSided THEN
				IF triggers[i].front = sector THEN
					neighbor := triggers[i].back
				ELSIF triggers[i].back = sector THEN
					neighbor := triggers[i].front
				END
			END;
			IF (neighbor >= 0) & (neighbor # sector) & (world.Region(neighbor).floor = motions[sector].target) THEN
				motions[sector].texture := world.Region(neighbor).floorTexture;
				COPY(flats[neighbor], motions[sector].flat);
				motions[sector].special := specials[neighbor];
				RETURN
			END
		END
	END LowerModel;

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
		motions[sector].change := trigger.kind = LowerChange;
		motions[sector].lift := (trigger.kind = Lift) OR motions[sector].perpetual;
		motions[sector].high := region.floor;
		motions[sector].target := Target(world, sector, trigger.kind);
		motions[sector].speed := DoomConfig.values.floorSpeed;
		IF trigger.fast THEN
			motions[sector].speed := DoomConfig.values.fastFloorSpeed
		END;
		motions[sector].direction := Up;
		IF (trigger.kind = LowerHighest) OR (trigger.kind = LowerLowest) OR
			(trigger.kind = TurboLower) OR (trigger.kind = Lift) OR (trigger.kind = LowerChange) THEN
			motions[sector].direction := Down;
			motions[sector].target := MIN(region.floor, motions[sector].target)
		ELSE
			motions[sector].target := MAX(region.floor, motions[sector].target)
		END;
		motions[sector].low := motions[sector].target;
		IF motions[sector].change THEN
			LowerModel(world, sector)
		END;
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
			motions[sector].change := FALSE;
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

	(* StartDonut claims both floors before changing either controller and captures the eventual ring surface. *)
	PROCEDURE StartDonut(world: GameGeometry.World; sector: SIGNED32): BOOLEAN;
	VAR ring, model: SIGNED32;
		height: FLOAT64;
	BEGIN
		IF ~DonutSectors(sector, ring, model) THEN
			RETURN FALSE
		END;
		height := world.Region(model).floor;
		IF (height < world.Region(ring).floor) OR (height > world.Region(sector).floor) THEN
			RETURN FALSE
		END;
		IF ~actions.Claim(sector) THEN
			RETURN FALSE
		END;
		IF ~actions.Claim(ring) THEN
			actions.Release(sector);
			RETURN FALSE
		END;
		motions[sector].direction := Down;
		motions[sector].target := height;
		motions[sector].speed := DoomConfig.values.donutSpeed;
		motions[sector].lift := FALSE;
		motions[sector].perpetual := FALSE;
		motions[sector].change := FALSE;
		motions[ring].direction := Up;
		motions[ring].target := height;
		motions[ring].speed := DoomConfig.values.donutSpeed;
		motions[ring].lift := FALSE;
		motions[ring].perpetual := FALSE;
		motions[ring].change := TRUE;
		motions[ring].texture := world.Region(model).floorTexture;
		COPY(flats[model], motions[ring].flat);
		motions[ring].special := 0;
		INC(active, 2);
		RETURN TRUE
	END StartDonut;

	(* Trigger-model raises change the surface immediately, even if subsequent motion is blocked. *)
	PROCEDURE ChangeSurface(VAR world: GameGeometry.World; sector, model: SIGNED32);
	VAR candidate: GameGeometry.World;
	BEGIN
		candidate := world.WithFloorTexture(sector, world.Region(model).floorTexture);
		ASSERT(candidate # NIL);
		world := candidate;
		COPY(flats[model], flats[sector]);
		specials[sector] := specials[model]
	END ChangeSurface;

	PROCEDURE Activate(VAR world: GameGeometry.World; line: SIGNED32): BOOLEAN;
	VAR i: SIGNED32;
		started: BOOLEAN;
	BEGIN
		started := FALSE;
		i := 0;
		WHILE i < LEN(tags^) DO
			IF tags[i] = triggers[line].tag THEN
				IF triggers[line].kind = Stairs THEN
					started := BuildStairs(world, i, triggers[line].fast) OR started
				ELSIF triggers[line].kind = Donut THEN
					started := StartDonut(world, i) OR started
				ELSIF Start(world, i, triggers[line]) THEN
					IF triggers[line].kind = RaiseStepChange THEN
						ChangeSurface(world, i, triggers[line].front)
					END;
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

	PROCEDURE Use*(VAR world: GameGeometry.World; x, y, angle: FLOAT64): BOOLEAN;
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

	PROCEDURE ApplyCrossings*(VAR world: GameGeometry.World);
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
						IF motions[i].change THEN
							candidate := world.WithFloorTexture(i, motions[i].texture);
							ASSERT(candidate # NIL);
							world := candidate;
							COPY(motions[i].flat, flats[i]);
							specials[i] := motions[i].special;
							motions[i].change := FALSE
						END;
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
	| WalkLowerChange, RepeatLowerChange:
		trigger.kind := LowerChange
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
	| WalkRaiseStep, RepeatRaiseStep:
		trigger.kind := RaiseStep
	| WalkRaiseStepChange, RepeatRaiseStepChange:
		trigger.kind := RaiseStepChange
	| SwitchRaiseLarge:
		trigger.kind := RaiseLarge
	| SwitchDonut:
		trigger.kind := Donut
	| WalkTurboLower, ButtonTurboLower, SwitchTurboLower, RepeatTurboLower:
		trigger.kind := TurboLower
	| RepeatFastNearest, WalkFastNearest, SwitchFastNearest, ButtonFastNearest:
		trigger.kind := RaiseNearest
	ELSE
		RETURN
	END;
	trigger.activation := Using;
	CASE special OF
	WalkLowerHighest, RepeatLowerHighest, WalkLowerLowest, RepeatLowerLowest, WalkRaiseNearest, RepeatRaiseNearest,
		WalkRaiseCeiling, RepeatRaiseCeiling, WalkLift, RepeatLift, RepeatFastLift, WalkFastLift,
		WalkPerpetual, RepeatPerpetual, WalkStopLift, RepeatStopLift, WalkStairs, WalkFastStairs,
		WalkLowerChange, RepeatLowerChange, WalkRaiseStep, RepeatRaiseStep, WalkTurboLower, RepeatTurboLower,
		RepeatFastNearest, WalkFastNearest, WalkRaiseStepChange, RepeatRaiseStepChange:
		trigger.activation := Walk
	| GunRaiseCeiling:
		trigger.activation := Gun
	ELSE
	END;
	CASE special OF
	ButtonLowerHighest, RepeatLowerHighest, ButtonLowerLowest, RepeatLowerLowest, ButtonRaiseNearest, RepeatRaiseNearest,
		ButtonRaiseCeiling, RepeatRaiseCeiling, ButtonLift, RepeatLift, RepeatFastLift, ButtonFastLift,
		RepeatPerpetual, RepeatStopLift, RepeatLowerChange, RepeatRaiseStep, ButtonTurboLower, RepeatTurboLower,
		RepeatFastNearest, ButtonFastNearest, RepeatRaiseStepChange:
		trigger.repeat := TRUE
	ELSE
	END;
	trigger.fast := (special = RepeatFastLift) OR (special = WalkFastLift) OR
		(special = SwitchFastLift) OR (special = ButtonFastLift) OR
		(special = WalkFastStairs) OR (special = SwitchFastStairs) OR
		(trigger.kind = TurboLower) OR (special = RepeatFastNearest) OR (special = WalkFastNearest) OR
		(special = SwitchFastNearest) OR (special = ButtonFastNearest)
END Classify;

END DoomFloors.
