MODULE DoomDoors;

IMPORT DoomConfig, DoomFormat, DoomActions, DoomWad, DoomInventory, GameBytes, GameGeometry;

CONST Raise = 1;
	BlueRaise = 26;
	YellowRaise = 27;
	RedRaise = 28;
	Open = 31;
	BlueOpen = 32;
	RedOpen = 33;
	YellowOpen = 34;
	FastRaise = 117;
	FastOpen = 118;
	WalkOpen = 2;
	WalkClose = 3;
	WalkRaise = 4;
	WalkCloseWaitOpen = 16;
	SwitchRaise = 29;
	ButtonClose = 42;
	GunOpen = 46;
	SwitchClose = 50;
	ButtonOpen = 61;
	ButtonRaise = 63;
	SwitchOpen = 103;
	WalkRepeatClose = 75;
	WalkRepeatCloseWaitOpen = 76;
	WalkRepeatOpen = 86;
	WalkRepeatRaise = 90;
	BlueButtonOpen = 99;
	WalkRepeatFastRaise = 105;
	WalkRepeatFastOpen = 106;
	WalkRepeatFastClose = 107;
	WalkFastRaise = 108;
	WalkFastOpen = 109;
	WalkFastClose = 110;
	SwitchFastRaise = 111;
	SwitchFastOpen = 112;
	SwitchFastClose = 113;
	ButtonFastRaise = 114;
	ButtonFastOpen = 115;
	ButtonFastClose = 116;
	BlueSwitchOpen = 133;
	RedButtonOpen = 134;
	RedSwitchOpen = 135;
	YellowButtonOpen = 136;
	YellowSwitchOpen = 137;
	Unsupported = 0;
	Manual = 1;
	Switch = 2;
	Walk = 3;
	Gun = 4;
	RaiseDoor = 0;
	OpenDoor = 1;
	CloseDoor = 2;
	CloseWaitOpenDoor = 3;
	Closed = 0;
	Opening = 1;
	Closing = -1;
	Waiting = 2;

TYPE
	Trigger = RECORD
		special, front, back, tag, activation, kind, key: SIGNED32;
		fast, repeat, pending: BOOLEAN;
		geometry: GameGeometry.Wall
	END;

	Door = RECORD
		direction, timer, kind: SIGNED32;
		top, speed: FLOAT64
	END;

	Controller* = OBJECT
	VAR triggers: POINTER TO ARRAY OF Trigger;
		doors: POINTER TO ARRAY OF Door;
		moving: POINTER TO ARRAY OF BOOLEAN;
		heights: POINTER TO ARRAY OF FLOAT64;
		tags: POINTER TO ARRAY OF SIGNED32;
		active: SIGNED32;
		actions: DoomActions.Table;

		PROCEDURE &Init*(archive: DoomWad.Archive; CONST lines, sides, sectors, vertices: DoomWad.Lump; shared: DoomActions.Table);
		VAR i, offset, side, sectorCount, a, b: SIGNED32;
			movingTags: POINTER TO ARRAY OF BOOLEAN;
		BEGIN
			ASSERT(DoomConfig.loaded);
			actions := shared;
			sectorCount := sectors.size DIV DoomFormat.SectorSize;
			NEW(triggers, lines.size DIV DoomFormat.LineSize);
			NEW(doors, sectorCount);
			NEW(moving, sectorCount);
			NEW(heights, sectorCount);
			NEW(tags, sectorCount);
			NEW(movingTags, DoomFormat.MaximumRecords);
			FOR i := 0 TO sectorCount - 1 DO
				tags[i] := GameBytes.U16(archive.data^, sectors.offset + i * DoomFormat.SectorSize + DoomFormat.SectorTag)
			END;
			FOR i := 0 TO SIGNED32(LEN(triggers^)) - 1 DO
				offset := lines.offset + i * DoomFormat.LineSize;
				triggers[i].special := GameBytes.U16(archive.data^, offset + DoomFormat.LineSpecial);
				triggers[i].tag := GameBytes.U16(archive.data^, offset + DoomFormat.LineTag);
				Classify(triggers[i]);
				a := vertices.offset + GameBytes.U16(archive.data^, offset) * DoomFormat.VertexSize;
				b := vertices.offset + GameBytes.U16(archive.data^, offset + 2) * DoomFormat.VertexSize;
				triggers[i].geometry.ax := GameBytes.I16(archive.data^, a) / DoomFormat.UnitsPerWorld;
				triggers[i].geometry.ay := -GameBytes.I16(archive.data^, a + 2) / DoomFormat.UnitsPerWorld;
				triggers[i].geometry.bx := GameBytes.I16(archive.data^, b) / DoomFormat.UnitsPerWorld;
				triggers[i].geometry.by := -GameBytes.I16(archive.data^, b + 2) / DoomFormat.UnitsPerWorld;
				side := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
				triggers[i].front := GameBytes.U16(archive.data^, sides.offset + side * DoomFormat.SideSize + DoomFormat.SideSector);
				triggers[i].back := -1;
				side := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
				IF side # DoomFormat.NoSide THEN
					triggers[i].back := GameBytes.U16(archive.data^, sides.offset + side * DoomFormat.SideSize + DoomFormat.SideSector);
					IF triggers[i].activation = Manual THEN
						moving[triggers[i].back] := TRUE
					END
				END;
				IF triggers[i].activation > Manual THEN
					movingTags[triggers[i].tag] := TRUE
				END
			END;
			FOR i := 0 TO sectorCount - 1 DO
				moving[i] := moving[i] OR movingTags[tags[i]]
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
			IF height = MAX(FLOAT64) THEN
				RETURN height
			END;
			RETURN height - DoomConfig.values.doorTopGap
		END Top;

		PROCEDURE Start(world: GameGeometry.World; sector: SIGNED32; CONST trigger: Trigger): BOOLEAN;
		VAR region: GameGeometry.Sector;
			top: FLOAT64;
		BEGIN
			IF doors[sector].direction # Closed THEN
				IF (trigger.activation = Manual) & (trigger.kind = RaiseDoor) THEN
					IF doors[sector].direction = Closing THEN
						doors[sector].direction := Opening
					ELSE
						doors[sector].direction := Closing
					END;
					RETURN TRUE
				END;
				RETURN FALSE
			END;
			region := world.Region(sector);
			top := region.ceiling;
			IF (trigger.kind = RaiseDoor) OR (trigger.kind = OpenDoor) THEN
				top := Top(world, sector);
				IF (top = MAX(FLOAT64)) OR (top < region.floor) OR
					((trigger.activation = Manual) & (top <= region.ceiling)) THEN
					RETURN FALSE
				END
			END;
			IF ~actions.Claim(sector) THEN
				RETURN FALSE
			END;
			doors[sector].top := top;
			doors[sector].kind := trigger.kind;
			doors[sector].speed := DoomConfig.values.doorSpeed;
			IF trigger.fast THEN
				doors[sector].speed := DoomConfig.values.fastDoorSpeed
			END;
			doors[sector].direction := Opening;
			IF (trigger.kind = CloseDoor) OR (trigger.kind = CloseWaitOpenDoor) THEN
				doors[sector].direction := Closing
			END;
			INC(active);
			RETURN TRUE
		END Start;

		(* Activate starts every idle tagged sector while manual doors retain their local toggle behavior. *)
		PROCEDURE Activate(world: GameGeometry.World; line: SIGNED32): BOOLEAN;
		VAR i: SIGNED32;
			started: BOOLEAN;
		BEGIN
			started := FALSE;
			IF triggers[line].activation = Manual THEN
				i := triggers[line].back;
				IF i >= 0 THEN
					started := Start(world, i, triggers[line])
				END
			ELSE
				FOR i := 0 TO SIGNED32(LEN(tags^)) - 1 DO
					IF (tags[i] = triggers[line].tag) & Start(world, i, triggers[line]) THEN
						started := TRUE
					END
				END
			END;
			IF (started & (triggers[line].activation = Switch)) OR (triggers[line].activation = Gun) THEN
				actions.Activated(line, triggers[line].repeat)
			END;
			IF ~triggers[line].repeat & (started OR (triggers[line].activation = Walk)) THEN
				actions.Consume(line)
			END;
			RETURN started
		END Activate;

		PROCEDURE Use*(world: GameGeometry.World; x, y, angle: FLOAT64;
			VAR player: DoomInventory.State): BOOLEAN;
		VAR line, key: SIGNED32;
		BEGIN
			player.neededKey := -1;
			line := actions.UseLine(world, x, y, angle);
			IF (line < 0) OR ((triggers[line].activation # Manual) & (triggers[line].activation # Switch)) OR
				((triggers[line].activation = Manual) & (triggers[line].back < 0)) THEN
				RETURN FALSE
			END;
			key := triggers[line].key;
			IF (key >= 0) & ~((key IN player.keys) OR (key + DoomInventory.KeyColors IN player.keys)) THEN
				player.neededKey := key;
				RETURN FALSE
			END;
			RETURN Activate(world, line)
		END Use;

		(* Crossed queues accepted origin crossings without replacing geometry inside the movement callback. *)
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

		(* Shot receives only linedefs reached by an actual clipped hitscan, including open portals. *)
		PROCEDURE Shot*(world: GameGeometry.World; line: SIGNED32);
		VAR started: BOOLEAN;
		BEGIN
			IF (actions.Special(line) # 0) & (triggers[line].activation = Gun) THEN
				started := Activate(world, line)
			END
		END Shot;

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
				IF doors[i].direction = Waiting THEN
					DEC(doors[i].timer);
					IF doors[i].timer = 0 THEN
						IF doors[i].kind = CloseWaitOpenDoor THEN
							doors[i].direction := Opening
						ELSE
							doors[i].direction := Closing
						END
					END
				ELSIF doors[i].direction # Closed THEN
					previous := heights[i];
					IF doors[i].direction = Opening THEN
						heights[i] := MIN(doors[i].top, heights[i] + doors[i].speed)
					ELSE
						region := world.Region(i);
						heights[i] := MAX(region.floor, heights[i] - doors[i].speed)
					END;
					candidate := world.WithCeilings(heights^);
					ASSERT(candidate # NIL);
					IF ~candidate.Stand(x, y, radius, feet, height, step, floor) THEN
						heights[i] := previous;
						IF doors[i].kind # CloseDoor THEN
							doors[i].direction := Opening
						END
					ELSE
						world := candidate;
						IF (doors[i].direction = Opening) & (heights[i] = doors[i].top) THEN
							IF doors[i].kind # RaiseDoor THEN
								doors[i].direction := Closed;
								DEC(active);
								actions.Release(i)
							ELSE
								doors[i].direction := Waiting;
								doors[i].timer := DoomConfig.values.doorWait
							END
						ELSIF doors[i].direction = Closing THEN
							region := world.Region(i);
							IF heights[i] = region.floor THEN
								IF doors[i].kind = CloseWaitOpenDoor THEN
									doors[i].direction := Waiting;
									doors[i].timer := DoomConfig.values.doorCloseWait
								ELSE
									doors[i].direction := Closed;
									DEC(active);
									actions.Release(i)
								END
							END
						END
					END
				END
			END
		END Step;
	END Controller;

PROCEDURE Classify(VAR trigger: Trigger);
BEGIN
	trigger.activation := Unsupported;
	trigger.key := -1;
	CASE trigger.special OF
	Raise, BlueRaise, YellowRaise, RedRaise, Open, BlueOpen, RedOpen, YellowOpen, FastRaise, FastOpen:
		trigger.activation := Manual
	| SwitchRaise, SwitchClose, SwitchOpen, ButtonClose, ButtonOpen, ButtonRaise,
		SwitchFastRaise, SwitchFastOpen, SwitchFastClose, ButtonFastRaise, ButtonFastOpen, ButtonFastClose,
		BlueSwitchOpen, BlueButtonOpen, RedSwitchOpen, RedButtonOpen, YellowSwitchOpen, YellowButtonOpen:
		trigger.activation := Switch
	| WalkOpen, WalkClose, WalkRaise, WalkCloseWaitOpen, WalkRepeatClose, WalkRepeatCloseWaitOpen,
		WalkRepeatOpen, WalkRepeatRaise, WalkFastRaise, WalkFastOpen, WalkFastClose,
		WalkRepeatFastRaise, WalkRepeatFastOpen, WalkRepeatFastClose:
		trigger.activation := Walk
	| GunOpen:
		trigger.activation := Gun
	ELSE
	END;
	CASE trigger.special OF
	Open, BlueOpen, RedOpen, YellowOpen, FastOpen, SwitchOpen, ButtonOpen, GunOpen,
		WalkOpen, WalkRepeatOpen, WalkFastOpen, WalkRepeatFastOpen, SwitchFastOpen, ButtonFastOpen,
		BlueSwitchOpen, BlueButtonOpen, RedSwitchOpen, RedButtonOpen, YellowSwitchOpen, YellowButtonOpen:
		trigger.kind := OpenDoor
	| WalkClose, WalkRepeatClose, WalkFastClose, WalkRepeatFastClose, SwitchClose, ButtonClose, SwitchFastClose, ButtonFastClose:
		trigger.kind := CloseDoor
	| WalkCloseWaitOpen, WalkRepeatCloseWaitOpen:
		trigger.kind := CloseWaitOpenDoor
	ELSE
		trigger.kind := RaiseDoor
	END;
	CASE trigger.special OF
	BlueRaise, BlueOpen, BlueSwitchOpen, BlueButtonOpen:
		trigger.key := DoomInventory.BlueCard
	| RedRaise, RedOpen, RedSwitchOpen, RedButtonOpen:
		trigger.key := DoomInventory.RedCard
	| YellowRaise, YellowOpen, YellowSwitchOpen, YellowButtonOpen:
		trigger.key := DoomInventory.YellowCard
	ELSE
	END;
	trigger.fast := (trigger.special = FastRaise) OR (trigger.special = FastOpen) OR
		((trigger.special >= WalkRepeatFastRaise) & (trigger.special <= ButtonFastClose)) OR
		(trigger.special = BlueButtonOpen) OR ((trigger.special >= BlueSwitchOpen) & (trigger.special <= YellowSwitchOpen));
	CASE trigger.special OF
	Raise, BlueRaise, YellowRaise, RedRaise, FastRaise, ButtonClose, ButtonOpen, ButtonRaise, GunOpen,
		WalkRepeatClose, WalkRepeatCloseWaitOpen, WalkRepeatOpen, WalkRepeatRaise,
		WalkRepeatFastRaise, WalkRepeatFastOpen, WalkRepeatFastClose, ButtonFastRaise, ButtonFastOpen, ButtonFastClose,
		BlueButtonOpen, RedButtonOpen, YellowButtonOpen:
		trigger.repeat := TRUE
	ELSE
		trigger.repeat := FALSE
	END
END Classify;

END DoomDoors.
