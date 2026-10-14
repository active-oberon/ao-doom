MODULE DoomSprites;

IMPORT DoomActors, DoomProjectiles, DoomConfig, DoomFormat, DoomWad, DoomTextures, DoomThings, DoomInventory, GameBytes, GameGeometry, GameRenderer, GameSurface, MathL;

CONST MaximumWork = 64 * 1024 * 1024;
	MaximumProjectiles = 256;
	MaximumEffects = 256;

TYPE
	LineHit* = PROCEDURE {DELEGATE} (world: GameGeometry.World; line: SIGNED32);

	Images = POINTER TO RECORD
		name: ARRAY 6 OF CHAR;
		views: ARRAY DoomFormat.SpriteRotations OF GameRenderer.Sprite;
		next: Images
	END;
	Frames = POINTER TO ARRAY OF Images;
	Effect* = RECORD
		x*, y*, z*: FLOAT64;
		start*: SIGNED64;
		animation: DoomConfig.AnimationSettings;
		images: Frames
	END;

	(* shortcut: unsupported monster kinds retain spawn behavior until their attacks are implemented. *)
	Actor = RECORD
		radius, targetHeight, height: FLOAT64;
		kind, initialHealth: SIGNED32;
		ceiling, fullbright: BOOLEAN;
		images, deadImages: Images;
		projectileImages: Images;
		impactImages, explosionImages: Frames;
		explosion: DoomConfig.ExplosionSettings;
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
		effects: POINTER TO ARRAY OF Effect;
		effectCount: SIGNED32;
		playerImages: ARRAY DoomInventory.WeaponKinds OF Images;
		playerImpacts: ARRAY DoomInventory.WeaponKinds OF Frames;
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
			effects := NIL;
			effectCount := 0;
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

		PROCEDURE EffectCount*(): SIGNED32;
		BEGIN
			RETURN effectCount
		END EffectCount;

		PROCEDURE EffectState*(index: SIGNED32): Effect;
		BEGIN
			ASSERT((index >= 0) & (index < effectCount));
			RETURN effects[index]
		END EffectState;

		PROCEDURE EffectPhase*(index: SIGNED32): SIGNED32;
		BEGIN
			ASSERT((index >= 0) & (index < effectCount));
			RETURN effects[index].animation.timing.Frame(tick - effects[index].start, FALSE)
		END EffectPhase;

		PROCEDURE Copy(): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
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
			snapshot.effects := effects;
			snapshot.effectCount := effectCount;
			FOR i := 0 TO DoomInventory.WeaponKinds - 1 DO
				snapshot.playerImages[i] := playerImages[i];
				snapshot.playerImpacts[i] := playerImpacts[i]
			END;
			RETURN snapshot
		END Copy;

		PROCEDURE CopyState(now: SIGNED64; x, y: FLOAT64): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
		BEGIN
			snapshot := Copy();
			NEW(snapshot.states, count);
			FOR i := 0 TO count - 1 DO
				snapshot.states[i] := states[i]
			END;
			snapshot.tick := now;
			snapshot.playerX := x;
			snapshot.playerY := y;
			RETURN snapshot
		END CopyState;

		(* FollowFloors carries grounded things and rejects pinching valid solid volumes before publication. *)
		PROCEDURE FollowFloors*(before, after: GameGeometry.World; sector: SIGNED32): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
			feet, oldFloor, newFloor, height: FLOAT64;
			solid, valid, fits: BOOLEAN;
		BEGIN
			snapshot := SELF;
			FOR i := 0 TO count - 1 DO
				IF ~(i MOD DoomFormat.CollectionWordBits IN collected[i DIV DoomFormat.CollectionWordBits]) &
					after.TouchesSector(sector, states[i].x, states[i].y, MAX(actors[i].radius, DoomFormat.TraceTolerance)) THEN
					oldFloor := before.Region(states[i].sector).floor;
					newFloor := after.Region(states[i].sector).floor;
					feet := states[i].feet;
					height := actors[i].height / DoomFormat.UnitsPerWorld;
					solid := (actors[i].radius > 0) & ((actors[i].initialHealth = 0) OR (hitpoints[i] > 0));
					IF actors[i].ceiling THEN
						feet := before.Region(states[i].sector).ceiling - height
					END;
					(* shortcut: pre-existing invalid spawn volumes do not block planes; enforce valid spawns during full object compatibility. *)
					valid := FALSE;
					IF solid THEN
						valid := before.Stand(states[i].x, states[i].y, actors[i].radius, feet, height, 0, oldFloor)
					END;
					IF ~actors[i].ceiling & (ABS(feet - oldFloor) <= DoomFormat.TraceTolerance) THEN
						IF valid THEN
							fits := after.Stand(states[i].x, states[i].y, actors[i].radius, feet, height, 0, newFloor)
						END;
						feet := newFloor
					END;
					IF valid & ~after.Stand(states[i].x, states[i].y, actors[i].radius, feet, height, 0, newFloor) THEN
						RETURN NIL
					END;
					IF ~actors[i].ceiling & (feet # states[i].feet) THEN
						IF snapshot = SELF THEN
							snapshot := CopyState(tick, playerX, playerY)
						END;
						snapshot.states[i].feet := feet
					END
				END
			END;
			RETURN snapshot
		END FollowFloors;

		(* Emit bounds visuals independently from barrel damage so a full effect pool cannot cancel a detonation. *)
		PROCEDURE Emit(animation: DoomConfig.AnimationSettings; images: Frames; x, y, z: FLOAT64): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
		BEGIN
			IF effectCount >= MaximumEffects THEN
				RETURN SELF
			END;
			snapshot := Copy();
			NEW(snapshot.effects, effectCount + 1);
			FOR i := 0 TO effectCount - 1 DO
				snapshot.effects[i] := effects[i]
			END;
			snapshot.effects[effectCount].x := x;
			snapshot.effects[effectCount].y := y;
			snapshot.effects[effectCount].z := z;
			snapshot.effects[effectCount].start := tick;
			snapshot.effects[effectCount].animation := animation;
			snapshot.effects[effectCount].images := images;
			INC(snapshot.effectCount);
			RETURN snapshot
		END Emit;

		PROCEDURE ExpireEffects;
		VAR active: POINTER TO ARRAY OF Effect;
			i, kept: SIGNED32;
		BEGIN
			IF effectCount = 0 THEN
				RETURN
			END;
			NEW(active, effectCount);
			kept := 0;
			FOR i := 0 TO effectCount - 1 DO
				IF tick - effects[i].start < effects[i].animation.timing.duration THEN
					active[kept] := effects[i];
					INC(kept)
				END
			END;
			effectCount := kept;
			effects := active;
			IF kept = 0 THEN
				effects := NIL
			END
		END ExpireEffects;

		PROCEDURE ExplosionPending(): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			FOR i := 0 TO count - 1 DO
				IF (actors[i].explosion # NIL) & (hitpoints[i] = 0) & ~states[i].detonated THEN
					RETURN TRUE
				END
			END;
			RETURN FALSE
		END ExplosionPending;

		PROCEDURE StartDeaths(): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
		BEGIN
			snapshot := SELF;
			FOR i := 0 TO count - 1 DO
				IF (actors[i].explosion # NIL) & (snapshot.hitpoints[i] = 0) & (snapshot.states[i].deathAt < 0) THEN
					snapshot.states[i].deathAt := tick;
					snapshot := snapshot.Emit(actors[i].explosion.animation, actors[i].explosionImages,
						states[i].x, states[i].y, states[i].feet + actors[i].targetHeight / 2)
				END
			END;
			RETURN snapshot
		END StartDeaths;

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

		(* Shoot retains horizontal aim for existing callers. *)
		PROCEDURE Shoot*(world: GameGeometry.World; x, y, angle, eye, range: FLOAT64; damage: SIGNED32): Scene;
		BEGIN
			RETURN ShootAim(world, x, y, angle, eye, 0, range, damage)
		END Shoot;

		PROCEDURE ShootAim*(world: GameGeometry.World; x, y, angle, eye, slope, range: FLOAT64; damage: SIGNED32): Scene;
		BEGIN
			RETURN ShootAimObserved(world, x, y, angle, eye, slope, range, damage, NIL)
		END ShootAim;

		(* ShootAimObserved clips line notifications at geometry and the closest live actor before damage. *)
		PROCEDURE ShootAimObserved*(world: GameGeometry.World; x, y, angle, eye, slope, range: FLOAT64;
			damage: SIGNED32; onLine: LineHit): Scene;
		VAR target, i: SIGNED32;
			wall: GameGeometry.Wall;
			dx, dy, limit, near, distance: FLOAT64;
		BEGIN
			ASSERT((range > 0) & (damage > 0));
			dx := MathL.cos(angle);
			dy := MathL.sin(angle);
			limit := world.TraceRay(x, y, dx, dy, eye, slope, range);
			target := Target(world, -1, x, y, dx, dy, eye, slope, limit);
			IF onLine # NIL THEN
				near := 0;
				i := 0;
				LOOP
					IF (i >= MIN(world.Count(), DoomFormat.MaximumTraceHits)) OR
						~world.CastSector(-1, x, y, dx, dy, near, distance, wall) OR
						(distance > limit + DoomFormat.TraceTolerance) THEN
						EXIT
					END;
					onLine(world, wall.id);
					near := distance;
					INC(i)
				END
			END;
			IF target < 0 THEN
				RETURN SELF
			END;
			RETURN Damage(target, damage)
		END ShootAimObserved;

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
				limit := world.TraceRay(states[index].x, states[index].y, dx, dy, eye, slope, rules.range);
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

		PROCEDURE PlayerShot*(weapon: SIGNED32; x, y, z, angle, slope: FLOAT64): Scene;
		VAR snapshot: Scene;
			shot: DoomProjectiles.State;
			i: SIGNED32;
		BEGIN
			ASSERT((weapon >= 0) & (weapon < DoomInventory.WeaponKinds));
			IF (projectileCount = MaximumProjectiles) OR (playerImages[weapon] = NIL) THEN
				RETURN SELF
			END;
			snapshot := Copy();
			NEW(snapshot.projectiles, projectileCount + 1);
			FOR i := 0 TO projectileCount - 1 DO
				snapshot.projectiles[i] := projectiles[i]
			END;
			shot.owner := -1;
			shot.weapon := weapon;
			shot.x := x;
			shot.y := y;
			shot.z := z;
			shot.remaining := DoomConfig.values.combat.weapons[weapon].range;
			DoomProjectiles.Aim(shot, x + MathL.cos(angle), y + MathL.sin(angle), z + slope, angle);
			snapshot.projectiles[projectileCount] := shot;
			INC(snapshot.projectileCount);
			RETURN snapshot
		END PlayerShot;

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

		(* Blast publishes independent hitpoints and uses normal armor protection even for the shooter's own rocket. *)
		PROCEDURE Blast(world: GameGeometry.World; CONST shot: DoomProjectiles.State;
			damage: SIGNED32; range, x, y, feet: FLOAT64; VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			i, amount: SIGNED32;
			bottom: FLOAT64;
		BEGIN
			snapshot := SELF;
			FOR i := 0 TO count - 1 DO
				IF snapshot.hitpoints[i] > 0 THEN
					bottom := states[i].feet;
					IF actors[i].ceiling THEN
						bottom := world.Region(states[i].sector).ceiling - actors[i].height / DoomFormat.UnitsPerWorld
					END;
					amount := DoomProjectiles.BlastDamage(world, shot, damage, range,
						states[i].x, states[i].y, bottom, actors[i].radius, actors[i].targetHeight);
					IF amount > 0 THEN
						IF snapshot = SELF THEN
							snapshot := Damage(i, amount)
						ELSE
							snapshot.hitpoints[i] := MAX(0, snapshot.hitpoints[i] - amount)
						END
					END
				END
			END;
			amount := DoomProjectiles.BlastDamage(world, shot, damage, range,
				x, y, feet, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight);
			DoomInventory.Hurt(player, amount);
			RETURN snapshot
		END Blast;

		(* Detonate marks each due barrel once before applying damage; new deaths start after the pass. *)
		PROCEDURE Detonate(world: GameGeometry.World; x, y, feet: FLOAT64; VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			i: SIGNED32;
			shot: DoomProjectiles.State;
			rules: DoomConfig.ExplosionSettings;
		BEGIN
			snapshot := SELF;
			FOR i := 0 TO count - 1 DO
				rules := actors[i].explosion;
				IF (player.health > 0) & (rules # NIL) & (snapshot.hitpoints[i] = 0) &
					(snapshot.states[i].deathAt >= 0) & ~snapshot.states[i].detonated &
					(tick >= snapshot.states[i].deathAt + rules.delay) THEN
					snapshot.states[i].detonated := TRUE;
					shot.x := snapshot.states[i].x;
					shot.y := snapshot.states[i].y;
					shot.z := snapshot.states[i].feet + actors[i].targetHeight / 2;
					snapshot := snapshot.Blast(world, shot, rules.blastDamage, rules.blastRadius, x, y, feet, player)
				END
			END;
			RETURN snapshot
		END Detonate;

		(* AdvanceProjectiles copies flight state and applies each first impact once. *)
		PROCEDURE AdvanceProjectiles(world: GameGeometry.World; x, y, feet: FLOAT64;
			VAR player: DoomInventory.State): Scene;
		VAR snapshot: Scene;
			previous: POINTER TO ARRAY OF DoomProjectiles.State;
			shot: DoomProjectiles.State;
			rules: DoomConfig.ProjectileSettings;
			images: Frames;
			i, j, kept, target, damage: SIGNED32;
			travel, limit, bottom: FLOAT64;
			playerHit, impact: BOOLEAN;
		BEGIN
			snapshot := SELF;
			previous := projectiles;
			NEW(snapshot.projectiles, LEN(previous^));
			kept := 0;
			FOR i := 0 TO projectileCount - 1 DO
				shot := previous[i];
				IF shot.owner < 0 THEN
					rules := DoomConfig.values.combat.weapons[shot.weapon].projectile;
					images := playerImpacts[shot.weapon];
					damage := DoomConfig.values.combat.weapons[shot.weapon].damage
				ELSE
					rules := actors[shot.owner].behavior.projectile;
					images := actors[shot.owner].impactImages;
					damage := actors[shot.owner].behavior.damage
				END;
				IF player.health > 0 THEN
					impact := FALSE;
					travel := MIN(shot.remaining, rules.speed);
					limit := DoomProjectiles.Trace(world, shot, rules.radius, rules.height, travel);
					playerHit := (shot.owner >= 0) & DoomProjectiles.Hit(shot, rules.radius, rules.height,
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
						impact := TRUE;
						IF snapshot.hitpoints[target] > 0 THEN
							IF snapshot = SELF THEN
								snapshot := Damage(target, damage)
							ELSE
								snapshot.hitpoints[target] := MAX(0, snapshot.hitpoints[target] - damage)
							END
						END
					ELSIF playerHit THEN
						impact := TRUE;
						DoomInventory.Hurt(player, damage)
					ELSIF limit >= travel THEN
						shot.x := shot.x + shot.dx * travel;
						shot.y := shot.y + shot.dy * travel;
						shot.z := shot.z + shot.dz * travel;
						shot.remaining := shot.remaining - travel;
						IF shot.remaining > DoomFormat.TraceTolerance THEN
							snapshot.projectiles[kept] := shot;
							INC(kept)
						END
					ELSE
						impact := TRUE
					END;
					IF impact THEN
						shot.x := shot.x + shot.dx * limit;
						shot.y := shot.y + shot.dy * limit;
						shot.z := shot.z + shot.dz * limit;
						IF rules.blastDamage > 0 THEN
							snapshot := snapshot.Blast(world, shot, rules.blastDamage, rules.blastRadius, x, y, feet, player)
						END;
						snapshot := snapshot.Emit(rules.impact, images, shot.x, shot.y, shot.z)
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
			i: SIGNED32;
			attack: BOOLEAN;
		BEGIN
			IF player.health <= 0 THEN
				RETURN SELF
			END;
			snapshot := SELF;
			IF (projectileCount > 0) OR (effectCount > 0) OR ExplosionPending() THEN
				snapshot := CopyState(now, x, y);
				snapshot.ExpireEffects;
				IF projectileCount > 0 THEN
					snapshot := snapshot.AdvanceProjectiles(world, x, y, feet, player)
				END;
				snapshot := snapshot.StartDeaths();
				snapshot := snapshot.Detonate(world, x, y, feet, player);
				snapshot := snapshot.StartDeaths()
			END;
			FOR i := 0 TO count - 1 DO
				IF (player.health > 0) & (snapshot.hitpoints[i] > 0) & (actors[i].behavior # NIL) &
					(states[i].awake OR DoomActors.CanWake(world, states[i], actors[i].behavior,
						actors[i].targetHeight, x, y, feet)) THEN
					IF snapshot = SELF THEN
						snapshot := CopyState(now, x, y)
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
			IF snapshot # SELF THEN
				snapshot := snapshot.StartDeaths()
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
				IF ~(i MOD DoomFormat.CollectionWordBits IN collected[i DIV DoomFormat.CollectionWordBits]) &
					~((actors[i].explosion # NIL) & (hitpoints[i] = 0) & (states[i].deathAt >= 0)) THEN
					view := states[i].angle - MathL.arctan2(y - states[i].y, x - states[i].x);
					rotation := ENTIER((view + MathL.pi / 8) * 4 / MathL.pi) MOD DoomFormat.SpriteRotations;
					sprite := actors[i].images.views[rotation];
					IF (actors[i].initialHealth > 0) & (hitpoints[i] = 0) THEN
						sprite := actors[i].deadImages.views[0]
					ELSIF (actors[i].behavior # NIL) & states[i].awake THEN
						IF tick < states[i].attackUntil THEN
							phase := actors[i].behavior.attackTiming.Frame(tick - states[i].attackStart, FALSE);
							sprite := actors[i].attackImages[phase].views[rotation]
						ELSIF states[i].moving THEN
							phase := actors[i].behavior.walkTiming.Frame(tick - states[i].walkStart, TRUE);
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
				IF shot.owner < 0 THEN
					rules := DoomConfig.values.combat.weapons[shot.weapon].projectile
				ELSE
					rules := actors[shot.owner].behavior.projectile
				END;
				view := MathL.arctan2(shot.dy, shot.dx) - MathL.arctan2(y - shot.y, x - shot.x);
				rotation := ENTIER((view + MathL.pi / 8) * 4 / MathL.pi) MOD DoomFormat.SpriteRotations;
				IF shot.owner < 0 THEN
					sprite := playerImages[shot.weapon].views[rotation]
				ELSE
					sprite := actors[shot.owner].projectileImages.views[rotation]
				END;
				sprite.x := shot.x;
				sprite.y := shot.y;
				sprite.z := shot.z - rules.height / 2;
				sector := world.Locate(shot.x, shot.y);
				IF sector >= 0 THEN
					sprite.light := world.Region(sector).light;
					sprite.fullbright := rules.fullbright;
					GameRenderer.DrawSprite(sprite, frame, x, y, angle, eye)
				END
			END;
			FOR i := 0 TO effectCount - 1 DO
				sprite := effects[i].images[EffectPhase(i)].views[0];
				sprite.x := effects[i].x;
				sprite.y := effects[i].y;
				sprite.z := effects[i].z - effects[i].animation.height / 2;
				sector := world.Locate(sprite.x, sprite.y);
				IF sector >= 0 THEN
					sprite.light := world.Region(sector).light;
					sprite.fullbright := effects[i].animation.fullbright;
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

PROCEDURE AnimationImages(archive: DoomWad.Archive; textures: DoomTextures.Library;
	animation: DoomConfig.AnimationSettings; VAR cache: Images; VAR work: SIGNED32; VAR error: ARRAY OF CHAR): Frames;
VAR images: Frames;
	i: SIGNED32;
BEGIN
	NEW(images, LEN(animation.frames^));
	FOR i := 0 TO SIGNED32(LEN(images^)) - 1 DO
		images[i] := Frame(archive, textures, animation.frames[i], cache, work, error);
		IF images[i] = NIL THEN
			RETURN NIL
		END
	END;
	RETURN images
END AnimationImages;

PROCEDURE Read*(archive: DoomWad.Archive; CONST things: DoomWad.Lump;
	textures: DoomTextures.Library; world: GameGeometry.World;
	weapons: SET; VAR error: ARRAY OF CHAR): Scene;
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
			actor.impactImages := NIL;
			actor.explosionImages := NIL;
			actor.explosion := NIL;
			actor.behavior := NIL;
			state.feet := world.Region(state.sector).floor;
			state.awake := FALSE;
			state.moving := FALSE;
			state.walkStart := 0;
			state.attackStart := 0;
			state.attackAt := 0;
			state.attackUntil := 0;
			state.deathAt := -1;
			state.detonated := FALSE;
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
					actor.explosion := DoomConfig.values.combat.actors[j].explosion;
					actor.deadImages := Frame(archive, textures, DoomConfig.values.combat.actors[j].deathFrame, cache, work, error);
					IF actor.deadImages = NIL THEN
						RETURN NIL
					END;
					IF actor.explosion # NIL THEN
						actor.explosionImages := AnimationImages(archive, textures, actor.explosion.animation, cache, work, error);
						IF actor.explosionImages = NIL THEN
							RETURN NIL
						END
					END;
					IF actor.behavior # NIL THEN
						IF actor.behavior.projectile # NIL THEN
							actor.projectileImages := Frame(archive, textures, actor.behavior.projectile.frame, cache, work, error);
							IF actor.projectileImages = NIL THEN
								RETURN NIL
							END;
							actor.impactImages := AnimationImages(archive, textures, actor.behavior.projectile.impact, cache, work, error);
							IF actor.impactImages = NIL THEN
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
			CASE kind OF
			DoomThings.Shotgun:
				j := DoomInventory.Shotgun
			| DoomThings.Chaingun:
				j := DoomInventory.Chaingun
			| DoomThings.Launcher:
				j := DoomInventory.Launcher
			| DoomThings.Plasma:
				j := DoomInventory.Plasma
			| DoomThings.Bfg:
				j := DoomInventory.Bfg
			| DoomThings.Chainsaw:
				j := DoomInventory.Chainsaw
			| DoomThings.SuperShotgun:
				j := DoomInventory.SuperShotgun
			ELSE
				j := -1
			END;
			IF (j >= 0) & (DoomConfig.values.combat.weapons[j].projectile # NIL) THEN
				scene.playerImages[j] := Frame(archive, textures, DoomConfig.values.combat.weapons[j].projectile.frame, cache, work, error);
				IF scene.playerImages[j] = NIL THEN
					RETURN NIL
				END;
				scene.playerImpacts[j] := AnimationImages(archive, textures, DoomConfig.values.combat.weapons[j].projectile.impact, cache, work, error);
				IF scene.playerImpacts[j] = NIL THEN
					RETURN NIL
				END
			END;
			scene.actors[scene.count] := actor;
			scene.states[scene.count] := state;
			scene.hitpoints[scene.count] := actor.initialHealth;
			INC(scene.count)
		END
	END;
	FOR j := 0 TO DoomInventory.WeaponKinds - 1 DO
		IF (j IN weapons) & (scene.playerImages[j] = NIL) &
			(DoomConfig.values.combat.weapons[j].projectile # NIL) THEN
			IF textures = NIL THEN
				COPY("Carried projectile weapons require sprite resources", error);
				RETURN NIL
			END;
			scene.playerImages[j] := Frame(archive, textures, DoomConfig.values.combat.weapons[j].projectile.frame, cache, work, error);
			IF scene.playerImages[j] = NIL THEN
				RETURN NIL
			END;
			scene.playerImpacts[j] := AnimationImages(archive, textures, DoomConfig.values.combat.weapons[j].projectile.impact, cache, work, error);
			IF scene.playerImpacts[j] = NIL THEN
				RETURN NIL
			END
		END
	END;
	scene.remaining := scene.count;
	RETURN scene
END Read;

END DoomSprites.
