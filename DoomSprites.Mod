MODULE DoomSprites;

IMPORT DoomActors, DoomProjectiles, DoomConfig, DoomFormat, DoomWad, DoomTextures, DoomThings, DoomInventory, GameBytes, GameGeometry, GameRenderer, GameSurface, MathL;

CONST MaximumWork = 64 * 1024 * 1024;
	MaximumProjectiles = 256;

TYPE
	Images = POINTER TO RECORD
		name: ARRAY 6 OF CHAR;
		views: ARRAY DoomFormat.SpriteRotations OF GameRenderer.Sprite;
		next: Images
	END;

	(* shortcut: unsupported monster kinds retain spawn behavior until their attacks are implemented. *)
	Actor = RECORD
		radius, targetHeight, height: FLOAT64;
		kind, initialHealth: SIGNED32;
		ceiling, fullbright: BOOLEAN;
		images, deadImages: Images;
		projectileImages: Images;
		walkImages, attackImages: POINTER TO ARRAY OF Images;
		behavior: DoomConfig.BehaviorSettings
	END;

	Scene* = OBJECT
	VAR actors: POINTER TO ARRAY OF Actor;
		collected: POINTER TO ARRAY OF SET32;
		hitpoints: POINTER TO ARRAY OF SIGNED32;
		states: POINTER TO ARRAY OF DoomActors.State;
		projectiles: POINTER TO ARRAY OF DoomProjectiles.State;
		projectileCount: SIGNED32;
		count, remaining, movingActor: SIGNED32;
		tick: SIGNED64;
		playerX, playerY: FLOAT64;

		PROCEDURE &Init(capacity: SIGNED32);
		BEGIN
			IF capacity > 0 THEN
				NEW(actors, capacity);
				NEW(states, capacity);
				NEW(hitpoints, capacity);
				NEW(collected, (capacity + DoomFormat.CollectionWordBits - 1) DIV DoomFormat.CollectionWordBits)
			END;
			count := 0;
			remaining := 0;
			projectileCount := 0;
			projectiles := NIL;
			tick := 0
		END Init;

		PROCEDURE Count*(): SIGNED32;
		BEGIN
			RETURN remaining
		END Count;

		PROCEDURE Health*(index: SIGNED32): SIGNED32;
		BEGIN
			ASSERT((index >= 0) & (index < count));
			RETURN hitpoints[index]
		END Health;

		PROCEDURE State*(index: SIGNED32): DoomActors.State;
		BEGIN
			ASSERT((index >= 0) & (index < count));
			RETURN states[index]
		END State;

		PROCEDURE ProjectileCount*(): SIGNED32;
		BEGIN
			RETURN projectileCount
		END ProjectileCount;

		PROCEDURE ProjectileState*(index: SIGNED32): DoomProjectiles.State;
		BEGIN
			ASSERT((index >= 0) & (index < projectileCount));
			RETURN projectiles[index]
		END ProjectileState;

		PROCEDURE Copy(): Scene;
		VAR snapshot: Scene;
		BEGIN
			NEW(snapshot, 0);
			snapshot.actors := actors;
			snapshot.states := states;
			snapshot.hitpoints := hitpoints;
			snapshot.collected := collected;
			snapshot.count := count;
			snapshot.remaining := remaining;
			snapshot.tick := tick;
			snapshot.projectiles := projectiles;
			snapshot.projectileCount := projectileCount;
			RETURN snapshot
		END Copy;

		(* Free checks solid footprints on both axes regardless of height, as classic player collision does. *)
		PROCEDURE Free*(x, y, radius: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			FOR i := 0 TO count - 1 DO
				IF (actors[i].radius > 0) &
					((actors[i].initialHealth = 0) OR (hitpoints[i] > 0)) &
					(ABS(states[i].x - x) < radius + actors[i].radius) &
					(ABS(states[i].y - y) < radius + actors[i].radius) THEN
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
					(ABS(states[i].x - x) < radius + DoomConfig.values.pickupRadius) &
					(ABS(states[i].y - y) < radius + DoomConfig.values.pickupRadius) THEN
					delta := world.Region(states[i].sector).floor - feet;
					IF (delta >= -DoomConfig.values.pickupBelowFeet) & (delta <= height) &
						Reachable(world, x, y, states[i].x, states[i].y, height) &
						DoomInventory.Give(player, actors[i].kind) THEN
						IF snapshot = SELF THEN
							snapshot := Copy();
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

		PROCEDURE Target(world: GameGeometry.World; skip: SIGNED32; x, y, dx, dy, eye, slope: FLOAT64; VAR limit: FLOAT64): SIGNED32;
		VAR i, target: SIGNED32;
			near, far, bottom: FLOAT64;
		BEGIN
			target := -1;
			FOR i := 0 TO count - 1 DO
				IF (i # skip) & (hitpoints[i] > 0) THEN
					bottom := states[i].feet;
					IF actors[i].ceiling THEN
						bottom := world.Region(states[i].sector).ceiling - actors[i].height / DoomFormat.UnitsPerWorld
					END;
					near := 0;
					far := limit;
					IF DoomProjectiles.Axis(x, dx, states[i].x - actors[i].radius, states[i].x + actors[i].radius, near, far) &
						DoomProjectiles.Axis(y, dy, states[i].y - actors[i].radius, states[i].y + actors[i].radius, near, far) &
						DoomProjectiles.Axis(eye, slope, bottom, bottom + actors[i].targetHeight, near, far) & (near < limit) THEN
						target := i;
						limit := near
					END
				END
			END;
			RETURN target
		END Target;

		PROCEDURE Damage(index, amount: SIGNED32): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
		BEGIN
			snapshot := Copy();
			NEW(snapshot.hitpoints, LEN(hitpoints^));
			FOR i := 0 TO count - 1 DO
				snapshot.hitpoints[i] := hitpoints[i]
			END;
			snapshot.hitpoints[index] := MAX(0, hitpoints[index] - amount);
			RETURN snapshot
		END Damage;

		(* Shoot shares target clipping with enemy shots while retaining horizontal player aim. *)
		PROCEDURE Shoot*(world: GameGeometry.World; x, y, angle, eye, range: FLOAT64; damage: SIGNED32): Scene;
		VAR target: SIGNED32;
			dx, dy, limit: FLOAT64;
		BEGIN
			ASSERT((range > 0) & (damage > 0));
			dx := MathL.cos(angle);
			dy := MathL.sin(angle);
			limit := DoomActors.TraceLimit(world, x, y, dx, dy, eye, range);
			target := Target(world, -1, x, y, dx, dy, eye, 0, limit);
			IF target < 0 THEN
				RETURN SELF
			END;
			RETURN Damage(target, damage)
		END Shoot;

		(* EnemyShot resolves each configured pellet against the closest current live volume. *)
		PROCEDURE EnemyShot(world: GameGeometry.World; index: SIGNED32;
			x, y, feet: FLOAT64; VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			rules: DoomConfig.BehaviorSettings;
			i, target: SIGNED32;
			distance, eye, slope, angle, dx, dy, limit, near, far: FLOAT64;
			playerHit: BOOLEAN;
		BEGIN
			snapshot := SELF;
			rules := actors[index].behavior;
			distance := MathL.sqrt((x - states[index].x) * (x - states[index].x) +
				(y - states[index].y) * (y - states[index].y));
			eye := states[index].feet + actors[index].targetHeight / 2;
			slope := 0;
			IF distance > DoomFormat.TraceTolerance THEN
				slope := (feet + DoomConfig.values.playerHeight / 2 - eye) / distance
			END;
			(* shortcut: pellets use fixed symmetric spread; add random spread with deterministic game randomness. *)
			FOR i := 0 TO rules.pellets - 1 DO
				angle := states[index].angle;
				IF rules.pellets > 1 THEN
					angle := angle + rules.spread * (2.0 * i / (rules.pellets - 1) - 1)
				END;
				dx := MathL.cos(angle);
				dy := MathL.sin(angle);
				limit := DoomActors.Trace(world, states[index].x, states[index].y, dx, dy, eye, slope, rules.range);
				near := 0;
				far := limit;
				playerHit := DoomProjectiles.Axis(states[index].x, dx, x - DoomConfig.values.playerRadius, x + DoomConfig.values.playerRadius, near, far) &
					DoomProjectiles.Axis(states[index].y, dy, y - DoomConfig.values.playerRadius, y + DoomConfig.values.playerRadius, near, far) &
					DoomProjectiles.Axis(eye, slope, feet, feet + DoomConfig.values.playerHeight, near, far) & (near < limit);
				IF playerHit THEN
					limit := near
				END;
				target := snapshot.Target(world, index, states[index].x, states[index].y, dx, dy, eye, slope, limit);
				IF target >= 0 THEN
					IF snapshot = SELF THEN
						snapshot := Damage(target, rules.damage)
					ELSE
						snapshot.hitpoints[target] := MAX(0, snapshot.hitpoints[target] - rules.damage)
					END
				ELSIF playerHit THEN
					DoomInventory.Hurt(player, rules.damage)
				END
			END;
			RETURN snapshot
		END EnemyShot;

		PROCEDURE Launch(index: SIGNED32; x, y, feet: FLOAT64);
		VAR expanded: POINTER TO ARRAY OF DoomProjectiles.State;
			shot: DoomProjectiles.State;
			i, capacity: SIGNED32;
		BEGIN
			(* shortcut: launches above the active-shot cap are dropped; revisit the budget for larger battles. *)
			IF projectileCount = MaximumProjectiles THEN
				RETURN
			END;
			capacity := 0;
			IF projectiles # NIL THEN
				capacity := SIGNED32(LEN(projectiles^))
			END;
			IF projectileCount = capacity THEN
				NEW(expanded, MIN(MaximumProjectiles, MAX(4, capacity * 2)));
				FOR i := 0 TO projectileCount - 1 DO
					expanded[i] := projectiles[i]
				END;
				projectiles := expanded
			END;
			shot.owner := index;
			shot.x := states[index].x;
			shot.y := states[index].y;
			shot.z := states[index].feet + actors[index].targetHeight / 2;
			shot.remaining := actors[index].behavior.range;
			DoomProjectiles.Aim(shot, x, y, feet + DoomConfig.values.playerHeight / 2, states[index].angle);
			projectiles[projectileCount] := shot;
			INC(projectileCount)
		END Launch;

		(* AdvanceProjectiles copies flight state and applies each first impact once. *)
		PROCEDURE AdvanceProjectiles(world: GameGeometry.World; x, y, feet: FLOAT64;
			VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			previous: POINTER TO ARRAY OF DoomProjectiles.State;
			shot: DoomProjectiles.State;
			rules: DoomConfig.ProjectileSettings;
			i, j, kept, target: SIGNED32;
			travel, limit, bottom: FLOAT64;
			playerHit: BOOLEAN;
		BEGIN
			snapshot := SELF;
			previous := projectiles;
			NEW(snapshot.projectiles, LEN(previous^));
			kept := 0;
			FOR i := 0 TO projectileCount - 1 DO
				shot := previous[i];
				rules := actors[shot.owner].behavior.projectile;
				IF player.health > 0 THEN
					travel := MIN(shot.remaining, rules.speed);
					limit := DoomProjectiles.Trace(world, shot, rules.radius, rules.height, travel);
					playerHit := DoomProjectiles.Hit(shot, rules.radius, rules.height,
						x, y, feet, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, limit);
					target := -1;
					FOR j := 0 TO count - 1 DO
						IF (j # shot.owner) & (actors[j].radius > 0) & (actors[j].height > 0) &
							((actors[j].initialHealth = 0) OR (snapshot.hitpoints[j] > 0)) THEN
							bottom := states[j].feet;
							IF actors[j].ceiling THEN
								bottom := world.Region(states[j].sector).ceiling - actors[j].height / DoomFormat.UnitsPerWorld
							END;
							IF DoomProjectiles.Hit(shot, rules.radius, rules.height,
								states[j].x, states[j].y, bottom, actors[j].radius, actors[j].height / DoomFormat.UnitsPerWorld, limit) THEN
								target := j
							END
						END
					END;
					IF target >= 0 THEN
						IF snapshot.hitpoints[target] > 0 THEN
							IF snapshot = SELF THEN
								snapshot := Damage(target, actors[shot.owner].behavior.damage)
							ELSE
								snapshot.hitpoints[target] := MAX(0, snapshot.hitpoints[target] - actors[shot.owner].behavior.damage)
							END
						END
					ELSIF playerHit THEN
						DoomInventory.Hurt(player, actors[shot.owner].behavior.damage)
					ELSIF limit >= travel THEN
						shot.x := shot.x + shot.dx * travel;
						shot.y := shot.y + shot.dy * travel;
						shot.z := shot.z + shot.dz * travel;
						shot.remaining := shot.remaining - travel;
						IF shot.remaining > DoomFormat.TraceTolerance THEN
							snapshot.projectiles[kept] := shot;
							INC(kept)
						END
					END
				ELSE
					snapshot.projectiles[kept] := shot;
					INC(kept)
				END
			END;
			snapshot.projectileCount := kept;
			IF kept = 0 THEN
				snapshot.projectiles := NIL
			END;
			RETURN snapshot
		END AdvanceProjectiles;

		(* MoveFree uses the unpublished snapshot so later monsters see earlier accepted movement. *)
		PROCEDURE MoveFree(x, y, radius: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			IF (ABS(playerX - x) < radius + DoomConfig.values.playerRadius) &
				(ABS(playerY - y) < radius + DoomConfig.values.playerRadius) THEN
				RETURN FALSE
			END;
			FOR i := 0 TO count - 1 DO
				IF (i # movingActor) & (actors[i].radius > 0) &
					((actors[i].initialHealth = 0) OR (hitpoints[i] > 0)) &
					(ABS(states[i].x - x) < radius + actors[i].radius) &
					(ABS(states[i].y - y) < radius + actors[i].radius) THEN
					RETURN FALSE
				END
			END;
			RETURN TRUE
		END MoveFree;

		(* Step publishes movement and attack timers without changing old render snapshots. *)
		PROCEDURE Step*(world: GameGeometry.World; now: SIGNED64; x, y, feet: FLOAT64;
			VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			i, j: SIGNED32;
			attack: BOOLEAN;
		BEGIN
			snapshot := SELF;
			IF (projectileCount > 0) & (player.health > 0) THEN
				snapshot := Copy();
				NEW(snapshot.states, count);
				FOR j := 0 TO count - 1 DO
					snapshot.states[j] := states[j]
				END;
				snapshot.tick := now;
				snapshot.playerX := x;
				snapshot.playerY := y;
				snapshot := snapshot.AdvanceProjectiles(world, x, y, feet, player)
			END;
			FOR i := 0 TO count - 1 DO
				IF (player.health > 0) & (snapshot.hitpoints[i] > 0) & (actors[i].behavior # NIL) &
					(states[i].awake OR DoomActors.CanWake(world, states[i], actors[i].behavior,
						actors[i].targetHeight, x, y, feet)) THEN
					IF snapshot = SELF THEN
						snapshot := Copy();
						NEW(snapshot.states, count);
						FOR j := 0 TO count - 1 DO
							snapshot.states[j] := states[j]
						END;
						snapshot.tick := now;
						snapshot.playerX := x;
						snapshot.playerY := y
					END;
					snapshot.movingActor := i;
					attack := DoomActors.Step(world, now, actors[i].behavior, actors[i].radius, actors[i].targetHeight,
						x, y, feet, snapshot.states[i], player, snapshot.MoveFree);
					IF attack THEN
						IF actors[i].behavior.projectile # NIL THEN
							snapshot.Launch(i, x, y, feet)
						ELSIF actors[i].behavior.hitscan THEN
							snapshot := snapshot.EnemyShot(world, i, x, y, feet, player);
							snapshot.playerX := x;
							snapshot.playerY := y
						ELSE
							DoomInventory.Hurt(player, actors[i].behavior.damage)
						END
					END
				END
			END;
			RETURN snapshot
		END Step;

		PROCEDURE Render*(world: GameGeometry.World; frame: GameSurface.Frame;
			x, y, angle, eye: FLOAT64);
		VAR i, rotation, phase, sector: SIGNED32;
			view: FLOAT64;
			shot: DoomProjectiles.State;
			rules: DoomConfig.ProjectileSettings;
			sprite: GameRenderer.Sprite;
			region: GameGeometry.Sector;
		BEGIN
			FOR i := 0 TO count - 1 DO
				IF ~(i MOD DoomFormat.CollectionWordBits IN collected[i DIV DoomFormat.CollectionWordBits]) THEN
					view := states[i].angle - MathL.arctan2(y - states[i].y, x - states[i].x);
					rotation := ENTIER((view + MathL.pi / 8) * 4 / MathL.pi) MOD DoomFormat.SpriteRotations;
					sprite := actors[i].images.views[rotation];
					IF (actors[i].initialHealth > 0) & (hitpoints[i] = 0) THEN
						sprite := actors[i].deadImages.views[0]
					ELSIF (actors[i].behavior # NIL) & states[i].awake THEN
						IF tick < states[i].attackUntil THEN
							phase := SIGNED32(MIN(LEN(actors[i].attackImages^) - 1,
								(tick - states[i].attackStart) DIV actors[i].behavior.frameTicks));
							sprite := actors[i].attackImages[phase].views[rotation]
						ELSIF states[i].moving THEN
							phase := SIGNED32((tick - states[i].walkStart) DIV actors[i].behavior.frameTicks MOD
								LEN(actors[i].walkImages^));
							sprite := actors[i].walkImages[phase].views[rotation]
						END
					END;
					sprite.x := states[i].x;
					sprite.y := states[i].y;
					region := world.Region(states[i].sector);
					sprite.z := states[i].feet;
					IF actors[i].ceiling THEN
						sprite.z := region.ceiling - actors[i].height / DoomFormat.UnitsPerWorld
					END;
					sprite.light := region.light;
					sprite.fullbright := actors[i].fullbright;
					GameRenderer.DrawSprite(sprite, frame, x, y, angle, eye)
				END
			END;
			FOR i := 0 TO projectileCount - 1 DO
				shot := projectiles[i];
				rules := actors[shot.owner].behavior.projectile;
				view := MathL.arctan2(shot.dy, shot.dx) - MathL.arctan2(y - shot.y, x - shot.x);
				rotation := ENTIER((view + MathL.pi / 8) * 4 / MathL.pi) MOD DoomFormat.SpriteRotations;
				sprite := actors[shot.owner].projectileImages.views[rotation];
				sprite.x := shot.x;
				sprite.y := shot.y;
				sprite.z := shot.z - rules.height / 2;
				sector := world.Locate(shot.x, shot.y);
				IF sector >= 0 THEN
					sprite.light := world.Region(sector).light;
					sprite.fullbright := rules.fullbright;
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
	state: DoomActors.State;
	i, j, k, offset, flags, kind, work: SIGNED32;
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
		IF (flags DIV 2 MOD 2 = 1) & (flags DIV 16 MOD 2 = 0) &
			DoomThings.Lookup(DoomConfig.values.things^, kind, info) THEN
			IF textures = NIL THEN
				COPY("Map sprites require palette and texture resources", error);
				RETURN NIL
			END;
			state.x := GameBytes.I16(archive.data^, offset) / DoomFormat.UnitsPerWorld;
			state.y := -GameBytes.I16(archive.data^, offset + 2) / DoomFormat.UnitsPerWorld;
			state.sector := world.Locate(state.x, state.y);
			IF state.sector < 0 THEN
				COPY("Sprite thing is outside all sectors", error);
				RETURN NIL
			END;
			state.angle := -(GameBytes.I16(archive.data^, offset + 4) DIV 45) * MathL.pi / 4;
			actor.ceiling := info.ceiling;
			actor.fullbright := info.fullbright;
			actor.height := info.height;
			actor.radius := info.radius / DoomFormat.UnitsPerWorld;
			actor.kind := kind;
			actor.initialHealth := 0;
			actor.targetHeight := 0;
			actor.deadImages := NIL;
			actor.walkImages := NIL;
			actor.attackImages := NIL;
			actor.projectileImages := NIL;
			actor.behavior := NIL;
			state.feet := world.Region(state.sector).floor;
			state.awake := FALSE;
			state.moving := FALSE;
			state.walkStart := 0;
			state.attackStart := 0;
			state.attackAt := 0;
			state.attackUntil := 0;
			actor.images := Frame(archive, textures, info.name, cache, work, error);
			IF actor.images = NIL THEN
				RETURN NIL
			END;
			FOR j := 0 TO SIGNED32(LEN(DoomConfig.values.combat.actors^)) - 1 DO
				IF DoomConfig.values.combat.actors[j].kind = kind THEN
					actor.initialHealth := DoomConfig.values.combat.actors[j].health;
					actor.targetHeight := DoomConfig.values.combat.actors[j].height;
					actor.radius := DoomConfig.values.combat.actors[j].radius;
					actor.behavior := DoomConfig.values.combat.actors[j].behavior;
					actor.deadImages := Frame(archive, textures, DoomConfig.values.combat.actors[j].deathFrame, cache, work, error);
					IF actor.deadImages = NIL THEN
						RETURN NIL
					END;
					IF actor.behavior # NIL THEN
						IF actor.behavior.projectile # NIL THEN
							actor.projectileImages := Frame(archive, textures, actor.behavior.projectile.frame, cache, work, error);
							IF actor.projectileImages = NIL THEN
								RETURN NIL
							END
						END;
						NEW(actor.walkImages, LEN(actor.behavior.walk^));
						NEW(actor.attackImages, LEN(actor.behavior.attack^));
						FOR k := 0 TO SIGNED32(LEN(actor.walkImages^)) - 1 DO
							actor.walkImages[k] := Frame(archive, textures, actor.behavior.walk[k], cache, work, error);
							IF actor.walkImages[k] = NIL THEN
								RETURN NIL
							END
						END;
						FOR k := 0 TO SIGNED32(LEN(actor.attackImages^)) - 1 DO
							actor.attackImages[k] := Frame(archive, textures, actor.behavior.attack[k], cache, work, error);
							IF actor.attackImages[k] = NIL THEN
								RETURN NIL
							END
						END
					END
				END
			END;
			scene.actors[scene.count] := actor;
			scene.states[scene.count] := state;
			scene.hitpoints[scene.count] := actor.initialHealth;
			INC(scene.count)
		END
	END;
	scene.remaining := scene.count;
	RETURN scene
END Read;

END DoomSprites.
