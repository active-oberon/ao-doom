MODULE Doom;

IMPORT DoomFormat, DoomConfig, DoomCombat, DoomCampaign, DoomExits, DoomTeleports, DoomActions, GameLoop, GameGeometry, GameSurface, GameRenderer, GameMaterials, GameText, DoomWad, DoomMap, DoomDoors, DoomFloors, DoomSprites, DoomInventory, DoomHud, MathL, Logging, Streams, KernelLog;

CONST LevelChanged* = 1;
	CampaignComplete* = 2;
	TransitionFailed* = 3;
	DemoEastWall = 12;
	DemoSecondPartition = 8;
	DemoExitDepth = 1.5;
	DemoExitMinY = 1;
	DemoExitMaxY = 3;

VAR log-: Logging.Logger;
	logWriter: Streams.Writer;
	logContext: ARRAY 1 OF Logging.Attr;

TYPE
	Interaction* = POINTER TO RECORD
		map*: ARRAY DoomFormat.NameLength + 1 OF CHAR;
		tick*: SIGNED64;
		line*, special*, neededKey*: SIGNED32;
		accepted*: BOOLEAN
	END;

	Transition* = POINTER TO RECORD
		result*, kind*, line*: SIGNED32;
		previous*, target*: ARRAY DoomFormat.NameLength + 1 OF CHAR;
		error*: ARRAY 256 OF CHAR
	END;

	Pose* = RECORD
		x*, y*, angle*, eye*, pitch*: FLOAT64
	END;

	Game* = OBJECT
	VAR world-: GameGeometry.World;
		pose: Pose;
		ticks: SIGNED64;
		demoStartTick, demoRunTicks, demoSplitTicks: SIGNED64;
		demoBestTicks, demoBestSplitTicks, demoReferenceSplitTicks: SIGNED64;
		forward, strafe, turn: SIGNED32;
		doors: DoomDoors.Controller;
		floors: DoomFloors.Controller;
		actions: DoomActions.Table;
		exits: DoomExits.Controller;
		teleports: DoomTeleports.Controller;
		reaction: SIGNED32;
		archive: DoomWad.Archive;
		mapName: ARRAY DoomFormat.NameLength + 1 OF CHAR;
		transition: Transition;
		interaction: Interaction;
		completed, transitionFailed: BOOLEAN;
		sprites: DoomSprites.Scene;
		inventory: DoomInventory.State;
		use, firing, reloading, aiming: BOOLEAN;
		viewFrame: GameSurface.Frame;
		weapon: DoomCombat.Weapon;

		PROCEDURE &Init*;
		VAR colors: DoomConfig.DemoPalette;
		BEGIN
			ASSERT(DoomConfig.loaded);
			colors := DoomConfig.values.demoColors;
			NEW(world, 14);
			Wall(0, 0, DemoEastWall, 0, colors.horizontalWall);
			Wall(DemoEastWall, 0, DemoEastWall, DemoExitMinY, colors.verticalWall);
			Wall(DemoEastWall, DemoExitMinY, DemoEastWall, DemoExitMaxY, colors.exitMarker);
			Wall(DemoEastWall, DemoExitMaxY, DemoEastWall, 10, colors.verticalWall);
			Wall(DemoEastWall, 10, 0, 10, colors.horizontalWall);
			Wall(0, 10, 0, 0, colors.verticalWall);
			Wall(4, 0, 4, 3, colors.leftPartition);
			Wall(4, 5, 4, 10, colors.leftPartition);
			Wall(DemoSecondPartition, 0, DemoSecondPartition, 5, colors.rightPartition);
			Wall(DemoSecondPartition, 7, DemoSecondPartition, 10, colors.rightPartition);
			Wall(5, 7, 6, 7, colors.pillar);
			Wall(6, 7, 6, 8, colors.pillar);
			Wall(6, 8, 5, 8, colors.pillar);
			Wall(5, 8, 5, 7, colors.pillar);
			world.Seal;
			ticks := 0;
			demoBestTicks := 0;
			demoBestSplitTicks := 0;
			doors := NIL;
			floors := NIL;
			actions := NIL;
			exits := NIL;
			teleports := NIL;
			reaction := 0;
			archive := NIL;
			mapName[0] := 0X;
			transition := NIL;
			interaction := NIL;
			transitionFailed := FALSE;
			sprites := NIL;
			StartDemo
		END Init;

		(* StartDemo resets the run while keeping the simulation tick sequence. *)
		PROCEDURE StartDemo;
		BEGIN
			pose.x := 2;
			pose.y := 4;
			pose.angle := 0;
			pose.pitch := 0;
			pose.eye := DoomConfig.values.demoEye;
			forward := 0;
			strafe := 0;
			turn := 0;
			completed := FALSE;
			demoStartTick := 0;
			demoRunTicks := 0;
			demoSplitTicks := 0;
			demoReferenceSplitTicks := demoBestSplitTicks;
			DoomInventory.Reset(inventory);
			use := FALSE;
			firing := FALSE;
			reloading := FALSE;
			aiming := FALSE;
			DoomCombat.Reset(weapon, inventory);
			ASSERT(world.Free(pose.x, pose.y, DoomConfig.values.playerRadius))
		END StartDemo;

		PROCEDURE Wall(ax, ay, bx, by: FLOAT64; color: SIGNED32);
		VAR wall: GameGeometry.Wall;
		BEGIN
			wall.ax := ax;
			wall.ay := ay;
			wall.bx := bx;
			wall.by := by;
			wall.bottom := 0;
			wall.top := DoomConfig.values.demoWallHeight;
			wall.color := color;
			wall.light := DoomConfig.values.demoLight;
			wall.texture := Bricks(color);
			wall.uScale := 1;
			wall.vScale := 1;
			wall.uOffset := 0;
			wall.vOffset := 0;
			ASSERT(world.Add(wall))
		END Wall;

		PROCEDURE Load*(CONST path, name: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): BOOLEAN;
		VAR candidate: DoomWad.Archive;
			map: DoomMap.Map;
			i: SIGNED32;
		BEGIN {EXCLUSIVE}
			candidate := DoomWad.Open(path, error);
			IF candidate = NIL THEN
				RETURN FALSE
			END;
			IF ~DoomMap.LoadMap(candidate, name, map, error) THEN
				RETURN FALSE
			END;
			Publish(map);
			archive := candidate;
			COPY(name, mapName);
			FOR i := 0 TO LEN(mapName) - 1 DO
				mapName[i] := CAP(mapName[i])
			END;
			transition := NIL;
			interaction := NIL;
			DoomInventory.Reset(inventory);
			DoomCombat.Reset(weapon, inventory);
			RETURN TRUE
		END Load;

		(* Publish replaces a fully validated level without exposing a partially loaded world to rendering. *)
		PROCEDURE Publish(CONST map: DoomMap.Map);
		BEGIN
			world := map.world;
			doors := map.doors;
			floors := map.floors;
			actions := map.actions;
			exits := map.exits;
			teleports := map.teleports;
			reaction := 0;
			sprites := map.sprites;
			use := FALSE;
			firing := FALSE;
			reloading := FALSE;
			aiming := FALSE;
			completed := FALSE;
			transitionFailed := FALSE;
			pose.x := map.x;
			pose.y := map.y;
			pose.angle := map.angle;
			pose.pitch := 0;
			pose.eye := map.eye
		END Publish;

		(* Finish validates the next map and carried weapon resources before changing inventory or the current level. *)
		PROCEDURE Finish(kind, line: SIGNED32);
		VAR event: Transition;
			map: DoomMap.Map;
		BEGIN
			(* shortcut: transitions are immediate; add original intermissions and finales during game-flow delivery. *)
			NEW(event);
			event.kind := kind;
			event.line := line;
			COPY(mapName, event.previous);
			event.result := TransitionFailed;
			IF DoomCampaign.Target(mapName, kind = DoomExits.Secret, event.target, event.error) THEN
				IF event.target[0] = 0X THEN
					completed := TRUE;
					transitionFailed := FALSE;
					forward := 0;
					strafe := 0;
					turn := 0;
					firing := FALSE;
					reloading := FALSE;
					aiming := FALSE;
					inventory.keys := {};
					inventory.neededKey := -1;
					weapon.flashUntil := 0;
					weapon.reloadUntil := 0;
					event.result := CampaignComplete
				ELSIF DoomMap.LoadWithWeapons(archive, event.target, inventory.weapons, map, event.error) THEN
					Publish(map);
					forward := 0;
					strafe := 0;
					turn := 0;
					COPY(event.target, mapName);
					inventory.keys := {};
					inventory.neededKey := -1;
					inventory.pickups := 0;
					weapon.reloadUntil := 0;
					weapon.flashUntil := 0;
					weapon.nextShot := ticks;
					event.result := LevelChanged
				END
			END;
			transitionFailed := event.result = TransitionFailed;
			transition := event
		END Finish;

		PROCEDURE MapName*(VAR name: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			COPY(mapName, name)
		END MapName;

		PROCEDURE Finished*(): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN completed
		END Finished;

		(* TakeTransition lets the window log rare level events outside simulation and rendering. *)
		PROCEDURE TakeTransition*(): Transition;
		VAR event: Transition;
		BEGIN {EXCLUSIVE}
			event := transition;
			transition := NIL;
			RETURN event
		END TakeTransition;

		(* TakeInteraction lets the window report the last use result outside the simulation lock. *)
		PROCEDURE TakeInteraction*(): Interaction;
		VAR event: Interaction;
		BEGIN {EXCLUSIVE}
			event := interaction;
			interaction := NIL;
			RETURN event
		END TakeInteraction;

		PROCEDURE Controls*(move, sidestep, rotate: SIGNED32);
		BEGIN {EXCLUSIVE}
			ASSERT((move >= -1) & (move <= 1));
			ASSERT((sidestep >= -1) & (sidestep <= 1));
			ASSERT((rotate >= -1) & (rotate <= 1));
			forward := move;
			strafe := sidestep;
			turn := rotate
		END Controls;

		(* Use queues one interaction so input is consumed on the simulation tick. *)
		PROCEDURE Use*;
		BEGIN {EXCLUSIVE}
			IF archive = NIL THEN
				use := completed
			ELSE
				use := ~completed
			END
		END Use;

		PROCEDURE Fire*(held: BOOLEAN);
		BEGIN {EXCLUSIVE}
			firing := held & ~completed
		END Fire;

		PROCEDURE Aim*(held: BOOLEAN);
		BEGIN {EXCLUSIVE}
			aiming := held & ~completed
		END Aim;

		PROCEDURE Look*(dx, dy: SIGNED32);
		VAR sensitivity, vertical: FLOAT64;
		BEGIN {EXCLUSIVE}
			IF (inventory.health <= 0) OR completed THEN
				RETURN
			END;
			sensitivity := DoomConfig.values.mouseSensitivity;
			IF aiming THEN
				sensitivity := sensitivity * DoomConfig.values.aimSensitivity
			END;
			pose.angle := pose.angle + MAX(-DoomConfig.MaximumMouseDelta, MIN(DoomConfig.MaximumMouseDelta, dx)) * sensitivity;
			pose.angle := pose.angle - 2 * MathL.pi * ENTIER((pose.angle + MathL.pi) / (2 * MathL.pi));
			vertical := -MAX(-DoomConfig.MaximumMouseDelta, MIN(DoomConfig.MaximumMouseDelta, dy)) * sensitivity;
			IF DoomConfig.values.invertMouse THEN
				vertical := -vertical
			END;
			pose.pitch := MAX(-DoomConfig.values.pitchLimit, MIN(DoomConfig.values.pitchLimit, pose.pitch + vertical))
		END Look;

		PROCEDURE Reload*;
		BEGIN {EXCLUSIVE}
			reloading := ~completed
		END Reload;

		PROCEDURE SelectWeapon*(slot, cycle: SIGNED32);
		BEGIN {EXCLUSIVE}
			IF completed THEN
				RETURN
			END;
			IF slot # 0 THEN
				DoomCombat.Select(weapon, inventory, slot)
			END;
			DoomCombat.Cycle(weapon, inventory, MAX(-DoomConfig.MaximumWheelSteps, MIN(DoomConfig.MaximumWheelSteps, cycle)))
		END SelectWeapon;

		PROCEDURE Weapon*(): DoomCombat.Weapon;
		BEGIN {EXCLUSIVE}
			RETURN weapon
		END Weapon;

		(* StepDemo records milestones only after the engine accepts movement. *)
		PROCEDURE StepDemo(dx, dy: FLOAT64);
		VAR previousX, previousY: FLOAT64;
		BEGIN
			previousX := pose.x;
			previousY := pose.y;
			ASSERT(world.Move(pose.x, pose.y, dx, dy, DoomConfig.values.playerRadius));
			IF (demoStartTick = 0) & ((pose.x # previousX) OR (pose.y # previousY)) THEN
				demoStartTick := ticks
			END;
			IF demoStartTick # 0 THEN
				demoRunTicks := ticks - demoStartTick + 1
			END;
			IF (demoSplitTicks = 0) & (pose.x >= DemoSecondPartition) THEN
				demoSplitTicks := demoRunTicks
			END;
			IF (pose.x >= DemoEastWall - DemoExitDepth) & (pose.y >= DemoExitMinY) & (pose.y <= DemoExitMaxY) THEN
				IF (demoBestTicks = 0) OR (demoRunTicks < demoBestTicks) THEN
					demoBestTicks := demoRunTicks;
					demoBestSplitTicks := demoSplitTicks
				END;
				completed := TRUE;
				aiming := FALSE
			END
		END StepDemo;

		PROCEDURE Step*(tick: SIGNED64);
		VAR dx, dy, speed, feet: FLOAT64;
			used, reacting: BOOLEAN;
			kind, line: SIGNED32;
		BEGIN {EXCLUSIVE}
			ASSERT(tick = ticks + 1);
			ticks := tick;
			IF completed THEN
				IF use & (archive = NIL) THEN
					StartDemo
				ELSE
					use := FALSE;
					reloading := FALSE
				END;
				RETURN
			END;
			IF inventory.health > 0 THEN
				reacting := reaction > 0;
				IF reacting THEN
					DEC(reaction)
				ELSE
					pose.angle := pose.angle + turn * DoomConfig.values.turnSpeed
				END;
				IF pose.angle > MathL.pi THEN
					pose.angle := pose.angle - 2 * MathL.pi
				ELSIF pose.angle < -MathL.pi THEN
					pose.angle := pose.angle + 2 * MathL.pi
				END;
				speed := DoomConfig.values.moveSpeed;
				IF reacting THEN
					speed := 0
				END;
				IF (forward # 0) & (strafe # 0) THEN
					speed := speed / MathL.sqrt(2)
				END;
				dx := (forward * MathL.cos(pose.angle) -
					strafe * MathL.sin(pose.angle)) * speed;
				dy := (forward * MathL.sin(pose.angle) +
					strafe * MathL.cos(pose.angle)) * speed;
				IF world.SectorCount() = 0 THEN
					StepDemo(dx, dy);
					IF completed THEN
						RETURN
					END
				ELSE
					feet := pose.eye - DoomConfig.values.playerEye;
					IF use THEN
						NEW(interaction);
						COPY(mapName, interaction.map);
						interaction.tick := ticks;
						interaction.line := actions.UseLine(world, pose.x, pose.y, pose.angle);
						interaction.neededKey := -1;
						IF interaction.line >= 0 THEN
							interaction.special := actions.Special(interaction.line)
						END;
						used := doors.Use(world, pose.x, pose.y, pose.angle, inventory);
						IF ~used THEN
							used := floors.Use(world, pose.x, pose.y, pose.angle)
						END;
						interaction.accepted := used;
						interaction.neededKey := inventory.neededKey;
						IF ~used & exits.Use(world, pose.x, pose.y, pose.angle) THEN
							interaction.accepted := TRUE;
							kind := exits.Take(line);
							actions.Step(world);
							Finish(kind, line);
							use := FALSE;
							RETURN
						END
					END;
					doors.StepOccupied(world, pose.x, pose.y, DoomConfig.values.playerRadius, feet,
						DoomConfig.values.playerHeight, DoomConfig.values.playerStep, sprites.FitsCeilings);
					floors.Step(world, pose.x, pose.y, DoomConfig.values.playerRadius, feet,
						DoomConfig.values.playerHeight, DoomConfig.values.playerStep, MoveFloorActors);
					ASSERT(world.MovePlayerObserved(pose.x, pose.y, feet, dx, dy,
						DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, sprites.Free, Crossed));
					IF teleports.Take(pose.x, pose.y, feet, pose.angle) THEN
						reaction := DoomConfig.values.teleportReactionTicks;
						pose.pitch := 0
					END;
					doors.ApplyCrossings(world);
					floors.ApplyCrossings(world);
					pose.eye := feet + DoomConfig.values.playerEye;
					kind := exits.Take(line);
					IF kind # DoomExits.None THEN
						actions.Step(world);
						Finish(kind, line);
						use := FALSE;
						RETURN
					END
				END;
			END;
			IF reloading THEN
				DoomCombat.Reload(ticks, weapon, inventory)
			END;
			reloading := FALSE;
			sprites := DoomCombat.StepAimObserved(ticks, firing, weapon, world, sprites,
				pose.x, pose.y, pose.angle, pose.eye, MathL.sin(pose.pitch) / MathL.cos(pose.pitch), inventory, Shot);
			IF actions # NIL THEN
				actions.Step(world)
			END;
			IF sprites # NIL THEN
				sprites := sprites.Step(world, ticks, pose.x, pose.y, pose.eye - DoomConfig.values.playerEye, inventory);
				sprites := sprites.Touch(world, pose.x, pose.y, pose.eye - DoomConfig.values.playerEye,
					DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, inventory)
			END;
			use := FALSE
		END Step;

		PROCEDURE Crossed(x0, y0, x1, y1: FLOAT64);
		BEGIN
			teleports.Observe(world, sprites, x0, y0, x1, y1);
			doors.Crossed(x0, y0, x1, y1);
			floors.Crossed(x0, y0, x1, y1);
			exits.Crossed(x0, y0, x1, y1)
		END Crossed;

		(* Shot publishes floor surfaces to the active world while pellets retain their captured ray geometry. *)
		PROCEDURE Shot(geometry: GameGeometry.World; line: SIGNED32);
		BEGIN
			IF doors # NIL THEN
				doors.Shot(geometry, line);
				floors.Shot(world, line)
			END
		END Shot;

		(* MoveFloorActors publishes carried actor positions only when every valid solid volume still fits. *)
		PROCEDURE MoveFloorActors(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
		VAR candidate: DoomSprites.Scene;
		BEGIN
			candidate := sprites.FollowFloors(before, after, sector);
			IF candidate = NIL THEN
				RETURN FALSE
			END;
			sprites := candidate;
			RETURN TRUE
		END MoveFloorActors;

		PROCEDURE State*(): Pose;
		BEGIN {EXCLUSIVE}
			RETURN pose
		END State;

		PROCEDURE Inventory*(): DoomInventory.State;
		BEGIN {EXCLUSIVE}
			RETURN inventory
		END Inventory;

		PROCEDURE Ticks*(): SIGNED64;
		BEGIN {EXCLUSIVE}
			RETURN ticks
		END Ticks;

		PROCEDURE Capture(VAR snapshot: Pose; VAR geometry: GameGeometry.World; VAR actors: DoomSprites.Scene;
			VAR status: DoomInventory.State; VAR flashed, aimed, finished, failed: BOOLEAN; VAR equipped: DoomCombat.Weapon;
			VAR runTicks, bestTicks, splitTicks, referenceSplitTicks: SIGNED64);
		BEGIN {EXCLUSIVE}
			snapshot := pose;
			geometry := world;
			actors := sprites;
			status := inventory;
			flashed := ticks < weapon.flashUntil;
			aimed := aiming;
			finished := completed;
			failed := transitionFailed;
			equipped := weapon;
			runTicks := demoRunTicks;
			bestTicks := demoBestTicks;
			splitTicks := demoSplitTicks;
			referenceSplitTicks := demoReferenceSplitTicks
		END Capture;

		PROCEDURE Render*(frame: GameSurface.Frame);
		VAR snapshot: Pose;
			geometry: GameGeometry.World;
			actors: DoomSprites.Scene;
			status: DoomInventory.State;
			flashed, aimed, finished, failed: BOOLEAN;
			equipped: DoomCombat.Weapon;
			target: GameSurface.Frame;
			runTicks, bestTicks, splitTicks, referenceSplitTicks: SIGNED64;
			margin, x, y, sx, sy: SIGNED32;
			zoom, center: FLOAT64;
		BEGIN
			Capture(snapshot, geometry, actors, status, flashed, aimed, finished, failed, equipped,
				runTicks, bestTicks, splitTicks, referenceSplitTicks);
			target := frame;
			zoom := 1;
			IF aimed THEN
				zoom := DoomConfig.values.aimZoom
			END;
			IF (snapshot.pitch # 0) OR (zoom # 1) THEN
				margin := ENTIER(frame.width / 1.32 * MathL.sin(DoomConfig.values.pitchLimit) / MathL.cos(DoomConfig.values.pitchLimit)) + 1;
				IF (viewFrame = NIL) OR (viewFrame.width # frame.width) OR (viewFrame.height # frame.height + 2 * margin) THEN
					NEW(viewFrame, frame.width, frame.height + 2 * margin)
				END;
				target := viewFrame
			END;
			GameRenderer.Render(geometry, target, snapshot.x, snapshot.y, snapshot.angle, snapshot.eye);
			IF actors # NIL THEN
				actors.Render(geometry, target, snapshot.x, snapshot.y, snapshot.angle, snapshot.eye)
			END;
			IF target # frame THEN
				(* shortcut: pitch shears the existing 2.5D projection; replace with a 3D camera if steep look angles are needed. *)
				center := target.height / 2.0 - MathL.sin(snapshot.pitch) / MathL.cos(snapshot.pitch) * target.width / 1.32;
				FOR y := 0 TO frame.height - 1 DO
					sy := ENTIER(center + (y + 0.5 - frame.height / 2.0) / zoom);
					FOR x := 0 TO frame.width - 1 DO
						sx := ENTIER(target.width / 2.0 + (x + 0.5 - frame.width / 2.0) / zoom);
						frame.Span(x, y, y, target.Pixel(sx, sy))
					END
				END
			END;
			DoomHud.Draw(status, frame);
			DoomCombat.DrawStatus(equipped, status, frame);
			DoomCombat.DrawAim(frame, flashed);
			IF geometry.SectorCount() = 0 THEN
				DoomHud.DrawDemo(frame, finished, runTicks, bestTicks, splitTicks, referenceSplitTicks)
			ELSIF finished THEN
				GameText.Draw(frame, DoomConfig.values.campaign.statusX, DoomConfig.values.campaign.statusY,
					DoomConfig.values.campaign.statusColor, DoomConfig.values.campaign.completeText)
			ELSIF failed THEN
				GameText.Draw(frame, DoomConfig.values.campaign.statusX, DoomConfig.values.campaign.statusY,
					DoomConfig.values.campaign.statusColor, DoomConfig.values.campaign.errorText)
			END
		END Render;
	END Game;

PROCEDURE Bricks(color: SIGNED32): GameMaterials.Texture;
VAR texture: GameMaterials.Texture;
	appearance: DoomConfig.BrickSettings;
	x, y, shift, mortar, texel: SIGNED32;
BEGIN
	appearance := DoomConfig.values.demoBricks;
	NEW(texture, appearance.textureSize, appearance.textureSize);
	mortar := (color DIV 65536 MOD 256 DIV appearance.mortarShade) * 65536 +
		(color DIV 256 MOD 256 DIV appearance.mortarShade) * 256 + color MOD 256 DIV appearance.mortarShade;
	FOR y := 0 TO appearance.textureSize - 1 DO
		shift := y DIV appearance.courseHeight MOD 2 * (appearance.brickWidth DIV 2);
		FOR x := 0 TO appearance.textureSize - 1 DO
			texel := color;
			IF (y MOD appearance.courseHeight < appearance.mortarWidth) OR
				((x + shift) MOD appearance.brickWidth < appearance.mortarWidth) THEN
				texel := mortar
			END;
			texture.Set(x, y, texel)
		END
	END;
	texture.Seal;
	RETURN texture
END Bricks;

PROCEDURE Do*;
VAR game: Game;
	simulation: GameLoop.Simulation;
	frame: GameSurface.Frame;
	pose, preserved: Pose;
	error: ARRAY 128 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	NEW(game);
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	game.Render(frame);
	ASSERT(frame.Save("scene.ppm"));
	NEW(simulation, game.Step);
	game.Controls(1, 0, 0);
	ASSERT(simulation.Advance(70));
	pose := game.State();
	ASSERT((pose.x > 7.6) & (pose.x < 8 - DoomConfig.values.playerRadius));
	game.Controls(0, 1, 0);
	ASSERT(simulation.Advance(23));
	pose := game.State();
	ASSERT((pose.y > 6) & (pose.y < 6.2));
	game.Controls(1, 0, 0);
	ASSERT(simulation.Advance(140));
	pose := game.State();
	ASSERT((pose.x > 11.5) & (pose.x < 12 - DoomConfig.values.playerRadius));
	ASSERT(game.world.Free(pose.x, pose.y, DoomConfig.values.playerRadius));
	game.Controls(0, 0, 1);
	ASSERT(simulation.Advance(200));
	pose := game.State();
	ASSERT((pose.angle >= -MathL.pi) & (pose.angle <= MathL.pi));
	simulation.Close;
	ASSERT(game.Load("valid.wad", "E1M1", error));
	game.Render(frame);
	ASSERT(frame.Save("wad-scene.ppm"));
	pose := game.State();
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	preserved := game.State();
	ASSERT((preserved.x = pose.x) & (preserved.y = pose.y));
	ASSERT(log.Info("scene, movement, collision and WAD checks passed") = Streams.Ok)
END Do;

BEGIN
	NEW(logWriter, KernelLog.Send, 4096);
	NEW(log, Logging.NewJSONHandler(logWriter));
	logContext[0] := Logging.String("component", "doom");
	log := log.With(logContext)
END Doom.
