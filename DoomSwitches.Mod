MODULE DoomSwitches;

IMPORT DoomConfig, DoomFormat, DoomTextures, DoomWad, GameBytes, GameGeometry, GameMaterials;

TYPE Button = RECORD
	side, timer: SIGNED32;
	restore: BOOLEAN
END;

Surface = RECORD
	part: SIGNED32;
	first, second: GameMaterials.Texture;
	pressed, dirty: BOOLEAN
END;

Controller* = OBJECT
VAR buttons: POINTER TO ARRAY OF Button;
	surfaces: POINTER TO ARRAY OF Surface;
	wallSides: POINTER TO ARRAY OF SIGNED32;
	wallCount: SIGNED32;
	active: SIGNED32;
	dirty: BOOLEAN;

	PROCEDURE &Init(count, sideCount: SIGNED32);
	BEGIN
		NEW(buttons, count);
		NEW(surfaces, sideCount);
		NEW(wallSides, count * 2)
	END Init;

	(* Activate retains the first release deadline even when a pressed button is activated again. *)
	PROCEDURE Activate*(line: SIGNED32; repeat: BOOLEAN);
	VAR side: SIGNED32;
	BEGIN
		side := buttons[line].side;
		IF surfaces[side].first = NIL THEN
			RETURN
		END;
		IF repeat & (buttons[line].timer = 0) THEN
			buttons[line].restore := surfaces[side].pressed;
			buttons[line].timer := DoomConfig.values.buttonTicks;
			INC(active)
		END;
		surfaces[side].pressed := ~surfaces[side].pressed;
		surfaces[side].dirty := TRUE;
		dirty := TRUE
	END Activate;

	(* Step publishes material changes after activation callbacks so hitscan keeps a stable world. *)
	PROCEDURE Step*(VAR world: GameGeometry.World);
	VAR i, side, wall: SIGNED32;
		texture: GameMaterials.Texture;
	BEGIN
		IF (active = 0) & ~dirty THEN
			RETURN
		END;
		FOR i := 0 TO SIGNED32(LEN(buttons^)) - 1 DO
			IF buttons[i].timer > 0 THEN
				DEC(buttons[i].timer);
				IF buttons[i].timer = 0 THEN
					DEC(active);
					side := buttons[i].side;
					surfaces[side].pressed := buttons[i].restore;
					surfaces[side].dirty := TRUE
				END
			END
		END;
		FOR side := 0 TO SIGNED32(LEN(surfaces^)) - 1 DO
			IF surfaces[side].dirty THEN
				texture := surfaces[side].first;
				IF surfaces[side].pressed THEN
					texture := surfaces[side].second
				END;
				FOR wall := 0 TO wallCount - 1 DO
					IF wallSides[wall] = side THEN
						world := world.WithWallTexture(wall, surfaces[side].part, texture);
						ASSERT(world # NIL)
					END
				END;
				surfaces[side].dirty := FALSE
			END
		END;
		dirty := FALSE
	END Step;
END Controller;

(* Read validates both images of each authored switch before the level can replace the current world. *)
PROCEDURE Read*(archive: DoomWad.Archive; CONST lines, sides: DoomWad.Lump;
	textures: DoomTextures.Library; VAR error: ARRAY OF CHAR): Controller;
VAR controller: Controller;
	i, pair, part, side, offset, source: SIGNED32;
	names: ARRAY 3 OF ARRAY DoomFormat.NameLength + 1 OF CHAR;
	first, second: ARRAY DoomFormat.NameLength + 1 OF CHAR;
	j: SIGNED32;
BEGIN
	NEW(controller, lines.size DIV DoomFormat.LineSize, sides.size DIV DoomFormat.SideSize);
	IF textures = NIL THEN
		RETURN controller
	END;
	FOR i := 0 TO SIGNED32(LEN(controller.buttons^)) - 1 DO
		offset := lines.offset + i * DoomFormat.LineSize;
		side := GameBytes.U16(archive.data^, offset + DoomFormat.LineFront);
		controller.buttons[i].side := side;
		controller.wallSides[controller.wallCount] := side;
		INC(controller.wallCount);
		source := GameBytes.U16(archive.data^, offset + DoomFormat.LineBack);
		IF source # DoomFormat.NoSide THEN
			controller.wallSides[controller.wallCount] := source;
			INC(controller.wallCount)
		END;
		IF (GameBytes.U16(archive.data^, offset + DoomFormat.LineSpecial) # 0) &
			(controller.surfaces[side].first = NIL) THEN
			source := sides.offset + side * DoomFormat.SideSize;
			FOR part := 0 TO 2 DO
				FOR j := 0 TO DoomFormat.NameLength - 1 DO
					CASE part OF
					0:
						names[part][j] := CAP(archive.data[source + 4 + j])
					| 1:
						names[part][j] := CAP(archive.data[source + 20 + j])
					| 2:
						names[part][j] := CAP(archive.data[source + 12 + j])
					END
				END;
				names[part][DoomFormat.NameLength] := 0X
			END;
			pair := 0;
			WHILE (pair < LEN(DoomConfig.values.switchPairs^)) & (controller.surfaces[side].first = NIL) DO
				COPY(DoomConfig.values.switchPairs[pair].off, first);
				COPY(DoomConfig.values.switchPairs[pair].on, second);
				part := 0;
				WHILE (part < 3) & (controller.surfaces[side].first = NIL) DO
					IF (names[part] = first) OR (names[part] = second) THEN
						CASE part OF
						0:
							controller.surfaces[side].part := GameGeometry.UpperTexture
						| 1:
							controller.surfaces[side].part := GameGeometry.MiddleTexture
						| 2:
							controller.surfaces[side].part := GameGeometry.LowerTexture
						END;
						controller.surfaces[side].first := textures.Get(first, error);
						IF controller.surfaces[side].first = NIL THEN
							RETURN NIL
						END;
						controller.surfaces[side].second := textures.Get(second, error);
						IF controller.surfaces[side].second = NIL THEN
							RETURN NIL
						END;
						controller.surfaces[side].pressed := names[part] = second
					END;
					INC(part)
				END;
				INC(pair)
			END
		END
	END;
	RETURN controller
END Read;

END DoomSwitches.
