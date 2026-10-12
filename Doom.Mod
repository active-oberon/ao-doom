MODULE Doom;

IMPORT DoomConfig, DoomCombat, GameLoop, GameGeometry, GameSurface, GameRenderer, GameMaterials, DoomWad, DoomMap, DoomDoors, DoomSprites, DoomInventory, DoomHud, MathL, Logging, Streams, KernelLog;

VAR log-: Logging.Logger;
	logWriter: Streams.Writer;
	logContext: ARRAY 1 OF Logging.Attr;

TYPE
	Pose* = RECORD
		x*, y*, angle*, eye*, pitch*: FLOAT64
	END;

	Game* = OBJECT
	VAR world-: GameGeometry.World;
		pose: Pose;
		ticks: SIGNED64;
		forward, strafe, turn: SIGNED32;
		doors: DoomDoors.Controller;
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
			NEW(world, 12);
			Wall(0, 0, 12, 0, colors.horizontalWall);
			Wall(12, 0, 12, 10, colors.verticalWall);
			Wall(12, 10, 0, 10, colors.horizontalWall);
			Wall(0, 10, 0, 0, colors.verticalWall);
			Wall(4, 0, 4, 3, colors.leftPartition);
			Wall(4, 5, 4, 10, colors.leftPartition);
			Wall(8, 0, 8, 5, colors.rightPartition);
			Wall(8, 7, 8, 10, colors.rightPartition);
			Wall(5, 7, 6, 7, colors.pillar);
			Wall(6, 7, 6, 8, colors.pillar);
			Wall(6, 8, 5, 8, colors.pillar);
			Wall(5, 8, 5, 7, colors.pillar);
			world.Seal;
			pose.x := 2;
			pose.y := 4;
			pose.angle := 0;
			pose.pitch := 0;
			pose.eye := DoomConfig.values.demoEye;
			ticks := 0;
			forward := 0;
			strafe := 0;
			turn := 0;
			doors := NIL;
			sprites := NIL;
			DoomInventory.Reset(inventory);
			use := FALSE;
			firing := FALSE;
			reloading := FALSE;
			aiming := FALSE;
			DoomCombat.Reset(weapon, inventory);
			ASSERT(world.Free(pose.x, pose.y, DoomConfig.values.playerRadius))
		END Init;

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
		VAR archive: DoomWad.Archive;
			map: DoomMap.Map;
		BEGIN {EXCLUSIVE}
			archive := DoomWad.Open(path, error);
			IF archive = NIL THEN
				RETURN FALSE
			END;
			IF ~DoomMap.LoadMap(archive, name, map, error) THEN
				RETURN FALSE
			END;
			world := map.world;
			doors := map.doors;
			sprites := map.sprites;
			use := FALSE;
			firing := FALSE;
			reloading := FALSE;
			aiming := FALSE;
			pose.x := map.x;
			pose.y := map.y;
			pose.angle := map.angle;
			pose.pitch := 0;
			pose.eye := map.eye;
			DoomInventory.Reset(inventory);
			DoomCombat.Reset(weapon, inventory);
			RETURN TRUE
		END Load;

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
			use := TRUE
		END Use;

		PROCEDURE Fire*(held: BOOLEAN);
		BEGIN {EXCLUSIVE}
			firing := held
		END Fire;

		PROCEDURE Aim*(held: BOOLEAN);
		BEGIN {EXCLUSIVE}
			aiming := held
		END Aim;

		PROCEDURE Look*(dx, dy: SIGNED32);
		VAR sensitivity, vertical: FLOAT64;
		BEGIN {EXCLUSIVE}
			IF inventory.health <= 0 THEN
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
			reloading := TRUE
		END Reload;

		PROCEDURE SelectWeapon*(slot, cycle: SIGNED32);
		BEGIN {EXCLUSIVE}
			IF slot # 0 THEN
				DoomCombat.Select(weapon, inventory, slot)
			END;
			DoomCombat.Cycle(weapon, inventory, MAX(-DoomConfig.MaximumWheelSteps, MIN(DoomConfig.MaximumWheelSteps, cycle)))
		END SelectWeapon;

		PROCEDURE Weapon*(): DoomCombat.Weapon;
		BEGIN {EXCLUSIVE}
			RETURN weapon
		END Weapon;

		PROCEDURE Step*(tick: SIGNED64);
		VAR dx, dy, speed, feet: FLOAT64;
			used: BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(tick = ticks + 1);
			ticks := tick;
			IF inventory.health > 0 THEN
				pose.angle := pose.angle + turn * DoomConfig.values.turnSpeed;
				IF pose.angle > MathL.pi THEN
					pose.angle := pose.angle - 2 * MathL.pi
				ELSIF pose.angle < -MathL.pi THEN
					pose.angle := pose.angle + 2 * MathL.pi
				END;
				speed := DoomConfig.values.moveSpeed;
				IF (forward # 0) & (strafe # 0) THEN
					speed := speed / MathL.sqrt(2)
				END;
				dx := (forward * MathL.cos(pose.angle) -
					strafe * MathL.sin(pose.angle)) * speed;
				dy := (forward * MathL.sin(pose.angle) +
					strafe * MathL.cos(pose.angle)) * speed;
				IF world.SectorCount() = 0 THEN
					ASSERT(world.Move(pose.x, pose.y, dx, dy, DoomConfig.values.playerRadius))
				ELSE
					feet := pose.eye - DoomConfig.values.playerEye;
					IF use THEN
						used := doors.Use(world, pose.x, pose.y, pose.angle, inventory)
					END;
					doors.Step(world, pose.x, pose.y, DoomConfig.values.playerRadius, feet, DoomConfig.values.playerHeight, DoomConfig.values.playerStep);
					ASSERT(world.MovePlayerChecked(pose.x, pose.y, feet, dx, dy,
						DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep, sprites.Free));
					pose.eye := feet + DoomConfig.values.playerEye
				END;
			END;
			IF reloading THEN
				DoomCombat.Reload(ticks, weapon, inventory)
			END;
			reloading := FALSE;
			sprites := DoomCombat.StepAim(ticks, firing, weapon, world, sprites,
				pose.x, pose.y, pose.angle, pose.eye, MathL.sin(pose.pitch) / MathL.cos(pose.pitch), inventory);
			IF sprites # NIL THEN
				sprites := sprites.Step(world, ticks, pose.x, pose.y, pose.eye - DoomConfig.values.playerEye, inventory);
				sprites := sprites.Touch(world, pose.x, pose.y, pose.eye - DoomConfig.values.playerEye,
					DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, inventory)
			END;
			use := FALSE
		END Step;

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
			VAR status: DoomInventory.State; VAR flashed, aimed: BOOLEAN; VAR equipped: DoomCombat.Weapon);
		BEGIN {EXCLUSIVE}
			snapshot := pose;
			geometry := world;
			actors := sprites;
			status := inventory;
			flashed := ticks < weapon.flashUntil;
			aimed := aiming;
			equipped := weapon
		END Capture;

		PROCEDURE Render*(frame: GameSurface.Frame);
		VAR snapshot: Pose;
			geometry: GameGeometry.World;
			actors: DoomSprites.Scene;
			status: DoomInventory.State;
			flashed, aimed: BOOLEAN;
			equipped: DoomCombat.Weapon;
			target: GameSurface.Frame;
			margin, x, y, sx, sy: SIGNED32;
			zoom, center: FLOAT64;
		BEGIN
			Capture(snapshot, geometry, actors, status, flashed, aimed, equipped);
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
			DoomCombat.DrawAim(frame, flashed)
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
