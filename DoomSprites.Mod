MODULE DoomSprites;

IMPORT DoomFormat, DoomWad, DoomTextures, DoomThings, DoomInventory, GameBytes, GameGeometry, GameRenderer, GameSurface, MathL;

CONST MaximumWork = 64 * 1024 * 1024;

TYPE
	Images = POINTER TO RECORD
		name: ARRAY 6 OF CHAR;
		views: ARRAY DoomFormat.SpriteRotations OF GameRenderer.Sprite;
		next: Images
	END;

	(* shortcut: actors keep fixed spawn positions and frames; add movement and animation with combat. *)
	Actor = RECORD
		x, y, angle, radius: FLOAT64;
		sector, height, kind: SIGNED32;
		ceiling, fullbright: BOOLEAN;
		images: Images
	END;

	Scene* = OBJECT
	VAR actors: POINTER TO ARRAY OF Actor;
		collected: POINTER TO ARRAY OF SET32;
		count, remaining: SIGNED32;

		PROCEDURE &Init(capacity: SIGNED32);
		BEGIN
			IF capacity > 0 THEN
				NEW(actors, capacity);
				NEW(collected, (capacity + DoomFormat.CollectionWordBits - 1) DIV DoomFormat.CollectionWordBits)
			END;
			count := 0;
			remaining := 0
		END Init;

		PROCEDURE Count*(): SIGNED32;
		BEGIN
			RETURN remaining
		END Count;

		(* Free checks solid footprints on both axes regardless of height, as classic player collision does. *)
		PROCEDURE Free*(x, y, radius: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			FOR i := 0 TO count - 1 DO
				IF (actors[i].radius > 0) &
					(ABS(actors[i].x - x) < radius + actors[i].radius) &
					(ABS(actors[i].y - y) < radius + actors[i].radius) THEN
					RETURN FALSE
				END
			END;
			RETURN TRUE
		END Free;

		(* Touch publishes copied collection bits only after a useful reachable pickup. *)
		PROCEDURE Touch*(world: GameGeometry.World; x, y, feet, radius, height: FLOAT64;
			VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			i, j: SIGNED32;
			delta: FLOAT64;
		BEGIN
			snapshot := SELF;
			FOR i := 0 TO count - 1 DO
				IF ~(i MOD DoomFormat.CollectionWordBits IN collected[i DIV DoomFormat.CollectionWordBits]) & DoomInventory.Supported(actors[i].kind) &
					(ABS(actors[i].x - x) < radius + DoomFormat.PickupRadius) &
					(ABS(actors[i].y - y) < radius + DoomFormat.PickupRadius) THEN
					delta := world.Region(actors[i].sector).floor - feet;
					IF (delta >= -DoomFormat.PickupBelowFeet) & (delta <= height) &
						Reachable(world, x, y, actors[i].x, actors[i].y, height) &
						DoomInventory.Give(player, actors[i].kind) THEN
						IF snapshot = SELF THEN
							NEW(snapshot, 0);
							snapshot.actors := actors;
							snapshot.count := count;
							snapshot.remaining := remaining;
							NEW(snapshot.collected, LEN(collected^));
							FOR j := 0 TO SIGNED32(LEN(collected^)) - 1 DO
								snapshot.collected[j] := collected[j]
							END
						END;
						INCL(snapshot.collected[i DIV DoomFormat.CollectionWordBits], i MOD DoomFormat.CollectionWordBits);
						DEC(snapshot.remaining)
					END
				END
			END;
			RETURN snapshot
		END Touch;

		PROCEDURE Render*(world: GameGeometry.World; frame: GameSurface.Frame;
			x, y, angle, eye: FLOAT64);
		VAR i, rotation: SIGNED32;
			view: FLOAT64;
			sprite: GameRenderer.Sprite;
			region: GameGeometry.Sector;
		BEGIN
			FOR i := 0 TO count - 1 DO
				IF ~(i MOD DoomFormat.CollectionWordBits IN collected[i DIV DoomFormat.CollectionWordBits]) THEN
					view := actors[i].angle - MathL.arctan2(y - actors[i].y, x - actors[i].x);
					rotation := ENTIER((view + MathL.pi / 8) * 4 / MathL.pi) MOD DoomFormat.SpriteRotations;
					sprite := actors[i].images.views[rotation];
					sprite.x := actors[i].x;
					sprite.y := actors[i].y;
					region := world.Region(actors[i].sector);
					sprite.z := region.floor;
					IF actors[i].ceiling THEN
						sprite.z := region.ceiling - actors[i].height / DoomFormat.UnitsPerWorld
					END;
					sprite.light := region.light;
					sprite.fullbright := actors[i].fullbright;
					GameRenderer.DrawSprite(sprite, frame, x, y, angle, eye)
				END
			END
		END Render;
	END Scene;

PROCEDURE Reachable(world: GameGeometry.World; x, y, targetX, targetY, height: FLOAT64): BOOLEAN;
VAR wall: GameGeometry.Wall;
	front, back: GameGeometry.Sector;
	i, sector: SIGNED32;
	near, distance: FLOAT64;
BEGIN
	IF (x = targetX) & (y = targetY) THEN
		RETURN TRUE
	END;
	sector := world.Locate(x, y);
	near := 0;
	FOR i := 0 TO MIN(world.Count(), DoomFormat.MaximumTraceHits) - 1 DO
		IF ~world.CastSector(sector, x, y, targetX - x, targetY - y, near, distance, wall) OR
			(distance >= 1) THEN
			RETURN TRUE
		END;
		IF (wall.neighbor < 0) OR wall.blocking THEN
			RETURN FALSE
		END;
		front := world.Region(sector);
		back := world.Region(wall.neighbor);
		IF MIN(front.ceiling, back.ceiling) - MAX(front.floor, back.floor) < height THEN
			RETURN FALSE
		END;
		sector := wall.neighbor;
		near := distance
	END;
	RETURN FALSE
END Reachable;

PROCEDURE Install(index, rotation: SIGNED32; flipped: BOOLEAN;
	VAR indices: ARRAY OF SIGNED32; VAR flips: SET; VAR mode: SIGNED32;
	VAR error: ARRAY OF CHAR): BOOLEAN;
VAR i: SIGNED32;
BEGIN
	IF (rotation < 0) OR (rotation > DoomFormat.SpriteRotations) THEN
		COPY("Sprite name contains an invalid rotation", error);
		RETURN FALSE
	END;
	IF rotation = 0 THEN
		IF mode # -1 THEN
			COPY("Sprite frame mixes or duplicates rotations", error);
			RETURN FALSE
		END;
		mode := 0;
		FOR i := 0 TO DoomFormat.SpriteRotations - 1 DO
			indices[i] := index;
			IF flipped THEN
				INCL(flips, i)
			END
		END
	ELSE
		DEC(rotation);
		IF (mode = 0) OR (indices[rotation] >= 0) THEN
			COPY("Sprite frame mixes or duplicates rotations", error);
			RETURN FALSE
		END;
		mode := 1;
		indices[rotation] := index;
		IF flipped THEN
			INCL(flips, rotation)
		END
	END;
	RETURN TRUE
END Install;

PROCEDURE Frame(archive: DoomWad.Archive; textures: DoomTextures.Library;
	CONST name: ARRAY OF CHAR; VAR cache: Images; VAR work: SIGNED32;
	VAR error: ARRAY OF CHAR): Images;
VAR found: Images;
	indices: ARRAY DoomFormat.SpriteRotations OF SIGNED32;
	flips: SET;
	mode, i, left, top: SIGNED32;
	lump: DoomWad.Lump;
BEGIN
	found := cache;
	WHILE found # NIL DO
		IF found.name = name THEN
			RETURN found
		END;
		found := found.next
	END;
	mode := -1;
	flips := {};
	FOR i := 0 TO DoomFormat.SpriteRotations - 1 DO
		indices[i] := -1
	END;
	IF archive.Count() > MaximumWork - work THEN
		COPY("Sprite directory scan exceeds the resource budget", error);
		RETURN NIL
	END;
	INC(work, archive.Count());
	FOR i := 0 TO archive.Count() - 1 DO
		lump := archive.Entry(i);
		IF (lump.name[0] = name[0]) & (lump.name[1] = name[1]) &
			(lump.name[2] = name[2]) & (lump.name[3] = name[3]) &
			((lump.name[4] = name[4]) OR (lump.name[6] = name[4])) THEN
			IF archive.Count() > MaximumWork - work THEN
				COPY("Sprite directory scan exceeds the resource budget", error);
				RETURN NIL
			END;
			INC(work, archive.Count());
			IF archive.Find(lump.name) = i THEN
				IF ((lump.name[6] # 0X) & ((lump.name[6] < "A") OR (lump.name[6] > "]"))) OR
					(lump.name[4] < "A") OR (lump.name[4] > "]") OR
					(lump.name[5] < "0") OR (lump.name[5] > "8") OR
					((lump.name[6] # 0X) & ((lump.name[7] < "0") OR (lump.name[7] > "8"))) OR
					((lump.name[6] = 0X) & (lump.name[7] # 0X)) THEN
					COPY("Sprite lump has a malformed frame or rotation name", error);
					RETURN NIL
				END;
				IF lump.name[4] = name[4] THEN
					IF ~Install(i, ORD(lump.name[5]) - ORD("0"), FALSE, indices, flips, mode, error) THEN
						RETURN NIL
					END
				END;
				IF lump.name[6] = name[4] THEN
					IF ~Install(i, ORD(lump.name[7]) - ORD("0"), TRUE, indices, flips, mode, error) THEN
						RETURN NIL
					END
				END
			END
		END
	END;
	NEW(found);
	COPY(name, found.name);
	FOR i := 0 TO DoomFormat.SpriteRotations - 1 DO
		IF indices[i] < 0 THEN
			COPY("Sprite frame is missing one or more rotations", error);
			RETURN NIL
		END;
		found.views[i].texture := textures.Sprite(indices[i], left, top, error);
		IF found.views[i].texture = NIL THEN
			RETURN NIL
		END;
		found.views[i].left := left;
		found.views[i].top := top;
		found.views[i].texelsPerUnit := DoomFormat.UnitsPerWorld;
		found.views[i].flipped := i IN flips
	END;
	found.next := cache;
	cache := found;
	RETURN found
END Frame;

PROCEDURE Read*(archive: DoomWad.Archive; CONST things: DoomWad.Lump;
	textures: DoomTextures.Library; world: GameGeometry.World;
	VAR error: ARRAY OF CHAR): Scene;
VAR scene: Scene;
	cache: Images;
	info: DoomThings.Info;
	actor: Actor;
	i, offset, flags, kind, work: SIGNED32;
BEGIN
	error[0] := 0X;
	IF things.size DIV DoomFormat.ThingSize > DoomFormat.MaximumRecords THEN
		COPY("THINGS record count exceeds 65536", error);
		RETURN NIL
	END;
	NEW(scene, things.size DIV DoomFormat.ThingSize);
	cache := NIL;
	work := 0;
	FOR i := 0 TO things.size DIV DoomFormat.ThingSize - 1 DO
		offset := things.offset + i * DoomFormat.ThingSize;
		flags := GameBytes.U16(archive.data^, offset + 8);
		kind := GameBytes.U16(archive.data^, offset + 6);
		(* shortcut: unknown thing types are skipped in previews; reject them when full gameplay is supported. *)
		IF (flags DIV 2 MOD 2 = 1) & (flags DIV 16 MOD 2 = 0) & DoomThings.Lookup(kind, info) THEN
			IF textures = NIL THEN
				COPY("Map sprites require palette and texture resources", error);
				RETURN NIL
			END;
			actor.x := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
			actor.y := -GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
			actor.sector := world.Locate(actor.x, actor.y);
			IF actor.sector < 0 THEN
				COPY("Sprite thing is outside all sectors", error);
				RETURN NIL
			END;
			actor.angle := -(GameBytes.I16(archive.data^, offset + 4) DIV 45) * MathL.pi / 4;
			actor.ceiling := info.ceiling;
			actor.fullbright := info.fullbright;
			actor.height := info.height;
			actor.radius := info.radius / DoomFormat.UnitsPerWorld;
			actor.kind := kind;
			actor.images := Frame(archive, textures, info.name, cache, work, error);
			IF actor.images = NIL THEN
				RETURN NIL
			END;
			scene.actors[scene.count] := actor;
			INC(scene.count)
		END
	END;
	scene.remaining := scene.count;
	RETURN scene
END Read;

END DoomSprites.
