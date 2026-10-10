MODULE Doom;

IMPORT GameLoop, GameGeometry, GameSurface, GameRenderer, GameMaterials, DoomWad, DoomMap, DoomDoors, DoomSprites, DoomInventory, DoomHud, MathL, KernelLog;

CONST TicksPerSecond* = 35;
	PlayerRadius* = 0.25;
	PlayerHeight* = 56.0 / 64;
	PlayerStep* = 24.0 / 64;
	PlayerEye* = 41.0 / 64;

TYPE
	Pose* = RECORD
		x*, y*, angle*, eye*: FLOAT64
	END;

	Game* = OBJECT
	VAR world-: GameGeometry.World;
		pose: Pose;
		ticks: SIGNED64;
		forward, strafe, turn: SIGNED32;
		doors: DoomDoors.Controller;
		sprites: DoomSprites.Scene;
		inventory: DoomInventory.State;
		use: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			NEW(world, 12);
			Wall(0, 0, 12, 0, 0897060H);
			Wall(12, 0, 12, 10, 0607889H);
			Wall(12, 10, 0, 10, 0897060H);
			Wall(0, 10, 0, 0, 0607889H);
			Wall(4, 0, 4, 3, 0678160H);
			Wall(4, 5, 4, 10, 0678160H);
			Wall(8, 0, 8, 5, 0806060H);
			Wall(8, 7, 8, 10, 0806060H);
			Wall(5, 7, 6, 7, 0B39258H);
			Wall(6, 7, 6, 8, 0B39258H);
			Wall(6, 8, 5, 8, 0B39258H);
			Wall(5, 8, 5, 7, 0B39258H);
			world.Seal;
			pose.x := 2;
			pose.y := 4;
			pose.angle := 0;
			pose.eye := 1.3;
			ticks := 0;
			forward := 0;
			strafe := 0;
			turn := 0;
			doors := NIL;
			sprites := NIL;
			DoomInventory.Reset(inventory);
			use := FALSE;
			ASSERT(world.Free(pose.x, pose.y, PlayerRadius))
		END Init;

		PROCEDURE Wall(ax, ay, bx, by: FLOAT64; color: SIGNED32);
		VAR wall: GameGeometry.Wall;
		BEGIN
			wall.ax := ax;
			wall.ay := ay;
			wall.bx := bx;
			wall.by := by;
			wall.bottom := 0;
			wall.top := 2.8;
			wall.color := color;
			wall.light := 255;
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
			pose.x := map.x;
			pose.y := map.y;
			pose.angle := map.angle;
			pose.eye := map.eye;
			DoomInventory.Reset(inventory);
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

		PROCEDURE Step*(tick: SIGNED64);
		VAR dx, dy, speed, feet: FLOAT64;
			used: BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(tick = ticks + 1);
			ticks := tick;
			pose.angle := pose.angle + turn * 0.065;
			IF pose.angle > MathL.pi THEN
				pose.angle := pose.angle - 2 * MathL.pi
			ELSIF pose.angle < -MathL.pi THEN
				pose.angle := pose.angle + 2 * MathL.pi
			END;
			speed := 0.09;
			IF (forward # 0) & (strafe # 0) THEN
				speed := speed / MathL.sqrt(2)
			END;
			dx := (forward * MathL.cos(pose.angle) -
				strafe * MathL.sin(pose.angle)) * speed;
			dy := (forward * MathL.sin(pose.angle) +
				strafe * MathL.cos(pose.angle)) * speed;
			IF world.SectorCount() = 0 THEN
				ASSERT(world.Move(pose.x, pose.y, dx, dy, PlayerRadius))
			ELSE
				feet := pose.eye - PlayerEye;
				IF use THEN
					used := doors.Use(world, pose.x, pose.y, pose.angle, inventory)
				END;
				doors.Step(world, pose.x, pose.y, PlayerRadius, feet, PlayerHeight, PlayerStep);
				ASSERT(world.MovePlayerChecked(pose.x, pose.y, feet, dx, dy,
					PlayerRadius, PlayerHeight, PlayerStep, sprites.Free));
				pose.eye := feet + PlayerEye
			END;
			IF sprites # NIL THEN
				sprites := sprites.Touch(world, pose.x, pose.y, pose.eye - PlayerEye,
					PlayerRadius, PlayerHeight, inventory)
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
			VAR status: DoomInventory.State);
		BEGIN {EXCLUSIVE}
			snapshot := pose;
			geometry := world;
			actors := sprites;
			status := inventory
		END Capture;

		PROCEDURE Render*(frame: GameSurface.Frame);
		VAR snapshot: Pose;
			geometry: GameGeometry.World;
			actors: DoomSprites.Scene;
			status: DoomInventory.State;
		BEGIN
			Capture(snapshot, geometry, actors, status);
			GameRenderer.Render(geometry, frame, snapshot.x, snapshot.y, snapshot.angle, snapshot.eye);
			IF actors # NIL THEN
				actors.Render(geometry, frame, snapshot.x, snapshot.y, snapshot.angle, snapshot.eye)
			END;
			DoomHud.Draw(status, frame)
		END Render;
	END Game;

PROCEDURE Bricks(color: SIGNED32): GameMaterials.Texture;
VAR texture: GameMaterials.Texture;
	x, y, shift, mortar, texel: SIGNED32;
BEGIN
	NEW(texture, 64, 64);
	mortar := (color DIV 65536 MOD 256 DIV 3) * 65536 +
		(color DIV 256 MOD 256 DIV 3) * 256 + color MOD 256 DIV 3;
	FOR y := 0 TO 63 DO
		shift := y DIV 16 MOD 2 * 16;
		FOR x := 0 TO 63 DO
			texel := color;
			IF (y MOD 16 < 2) OR ((x + shift) MOD 32 < 2) THEN
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
	NEW(game);
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(frame.Save("scene.ppm"));
	NEW(simulation, game.Step);
	game.Controls(1, 0, 0);
	ASSERT(simulation.Advance(70));
	pose := game.State();
	ASSERT((pose.x > 7.6) & (pose.x < 8 - PlayerRadius));
	game.Controls(0, 1, 0);
	ASSERT(simulation.Advance(23));
	pose := game.State();
	ASSERT((pose.y > 6) & (pose.y < 6.2));
	game.Controls(1, 0, 0);
	ASSERT(simulation.Advance(140));
	pose := game.State();
	ASSERT((pose.x > 11.5) & (pose.x < 12 - PlayerRadius));
	ASSERT(game.world.Free(pose.x, pose.y, PlayerRadius));
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
	KernelLog.String("Doom: scene, movement, collision and WAD checks passed.");
	KernelLog.Ln
END Do;

END Doom.
