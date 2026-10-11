MODULE DoomAISmoke;

IMPORT DoomConfig, DoomActors, DoomInventory, DoomSprites, DoomWad, DoomMap,
	Doom, GameSurface, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE {TEST} WakeAndSnapshots*;
VAR map: DoomMap.Map;
	scene, moved, touched, shot: DoomSprites.Scene;
	player: DoomInventory.State;
	frame: GameSurface.Frame;
	firstColor: SIGNED32;
	i: SIGNED32;
BEGIN
	Load("ai-pickup.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites;
	moved := scene.Step(map.world, 1, 0, 0, 0, player);
	ASSERT(moved # scene);
	ASSERT((scene.State(0).x = 2) & ~scene.State(0).awake);
	ASSERT((moved.State(0).x = 2 - 4.0 / 64) & moved.State(0).moving);
	ASSERT(moved.State(0).awake);
	ASSERT(~moved.Free(moved.State(0).x, 0, DoomConfig.values.playerRadius));
	touched := moved.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius,
		DoomConfig.values.playerHeight, player);
	ASSERT((touched.Count() = 1) & (player.pickups = 1));
	ASSERT(touched.State(0).x = moved.State(0).x);
	shot := touched.Shoot(map.world, 0, 0, 0, map.eye, 32, 10);
	ASSERT((shot.Health(0) = 140) & (touched.Health(0) = 150));
	ASSERT((shot.Count() = 1) & (shot.State(0).x = moved.State(0).x));
	NEW(frame, 320, 200);
	frame.Background(0, 0);
	moved.Render(map.world, frame, 0, 0, 0, map.eye);
	firstColor := frame.Pixel(160, 80);
	ASSERT(firstColor # 0);
	FOR i := 2 TO 5 DO
		moved := moved.Step(map.world, i, 0, 0, 0, player)
	END;
	frame.Background(0, 0);
	moved.Render(map.world, frame, 0, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 80) # firstColor);
	Load("ai-spectre.wad", map);
	moved := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	ASSERT(moved.State(0).x < 2);
	Load("ai-hidden.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	Load("ai-door.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 1 TO 40 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius,
			0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	moved := map.sprites.Step(map.world, 1, map.x, map.y, 0, player);
	ASSERT(moved.State(0).awake & moved.State(0).moving)
END WakeAndSnapshots;

PROCEDURE {TEST} WindupAndDodge*;
VAR map: DoomMap.Map;
	scene, dead: DoomSprites.Scene;
	player: DoomInventory.State;
	frame: GameSurface.Frame;
	i, attackColor: SIGNED32;
BEGIN
	Load("ai.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 1, 0, 0, player);
	ASSERT((scene.State(0).attackAt = 9) & (scene.State(0).attackUntil = 25));
	ASSERT(~scene.State(0).moving);
	NEW(frame, 320, 200);
	frame.Background(0, 0);
	scene.Render(map.world, frame, 0, 0, 0, map.eye);
	attackColor := frame.Pixel(160, 80);
	ASSERT(attackColor # 0);
	FOR i := 2 TO 8 DO
		scene := scene.Step(map.world, i, 1, 0, 0, player)
	END;
	ASSERT(player.health = 100);
	frame.Background(0, 0);
	scene.Render(map.world, frame, 0, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 80) # attackColor);
	scene := scene.Step(map.world, 9, 1, 0, 0, player);
	ASSERT(player.health = 80);
	FOR i := 10 TO 32 DO
		scene := scene.Step(map.world, i, 1, 0, 0, player)
	END;
	ASSERT(player.health = 80);
	scene := scene.Step(map.world, 33, 1, 0, 0, player);
	ASSERT(player.health = 60);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 1, 0, 0, player);
	scene := scene.Step(map.world, 9, -2, 0, 0, player);
	ASSERT(player.health = 100);
	ASSERT(scene.State(0).attackAt = 0);
	scene := map.sprites.Step(map.world, 1, 1, 0, 0, player);
	dead := scene.Shoot(map.world, 0, 0, 0, map.eye, 32, 150);
	ASSERT(dead.Health(0) = 0);
	ASSERT(dead.Step(map.world, 9, 1, 0, 0, player) = dead);
	ASSERT(player.health = 100);
	Load("ai-hidden-near.wad", map);
	scene := map.sprites.Step(map.world, 1, 0.75, 0, 24.0 / 64, player);
	ASSERT(scene.State(0).attackAt = 9);
	scene := scene.Step(map.world, 9, -0.5, 0, 0, player);
	ASSERT(player.health = 100)
END WindupAndDodge;

PROCEDURE {TEST} CollisionAndSteps*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	i: SIGNED32;
	radius: FLOAT64;
BEGIN
	DoomInventory.Reset(player);
	Load("ai-prop.wad", map);
	scene := map.sprites;
	FOR i := 1 TO 80 DO
		scene := scene.Step(map.world, i, -2, 0, 0, player)
	END;
	ASSERT(scene.State(0).x >= 1 + 40.0 / 64);
	ASSERT(player.health = 100);
	scene := scene.Shoot(map.world, -2, 0, 0, map.eye, 32, 20);
	ASSERT(scene.Health(1) = 0);
	FOR i := 81 TO 120 DO
		scene := scene.Step(map.world, i, -2, 0, 0, player)
	END;
	ASSERT(scene.State(0).x < 1);
	Load("ai-pair.wad", map);
	scene := map.sprites;
	FOR i := 1 TO 40 DO
		scene := scene.Step(map.world, i, -2, 0, 0, player);
		ASSERT(scene.State(1).x - scene.State(0).x >= 60.0 / 64)
	END;
	Load("ai-grate.wad", map);
	scene := map.sprites;
	FOR i := 1 TO 80 DO
		scene := scene.Step(map.world, i, map.x, map.y, 0, player)
	END;
	ASSERT(scene.State(0).awake);
	ASSERT(scene.State(0).x >= 30.0 / 64);
	Load("ai-climb.wad", map);
	scene := map.sprites;
	FOR i := 1 TO 50 DO
		scene := scene.Step(map.world, i, 2, 0, 24.0 / 64, player)
	END;
	ASSERT((scene.State(0).x > 0) & (scene.State(0).feet = 24.0 / 64));
	Load("ai-climb-high.wad", map);
	scene := map.sprites;
	FOR i := 1 TO 50 DO
		scene := scene.Step(map.world, i, 2, 0, 48.0 / 64, player)
	END;
	ASSERT((scene.State(0).x < 0) & (scene.State(0).feet = 0));
	Load("ai-low-ceiling.wad", map);
	scene := map.sprites.Step(map.world, 1, map.x, map.y, 0, player);
	ASSERT(scene.State(0).x = 2);
	Load("ai.wad", map);
	scene := map.sprites;
	radius := DoomConfig.values.playerRadius + 30.0 / 64;
	FOR i := 1 TO 80 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player);
		ASSERT(scene.State(0).x >= radius)
	END
END CollisionAndSteps;

PROCEDURE {TEST} CustomBehavior*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInventory.Reset(player);
	Load("ai.wad", map);
	ASSERT(map.sprites.Free(2.65, 0, DoomConfig.values.playerRadius));
	ASSERT(map.sprites.Step(map.world, 1, -3, 0, 0, player) = map.sprites);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	ASSERT(scene.State(0).x = 2 - 2.0 / 64);
	scene := map.sprites.Step(map.world, 1, 1, 0, 0, player);
	ASSERT((scene.State(0).attackAt = 3) & (scene.State(0).attackUntil = 8));
	scene := scene.Step(map.world, 3, 1, 0, 0, player);
	ASSERT(player.health = 71);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomBehavior;

PROCEDURE {TEST} DeathAndReload*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	error: ARRAY 256 OF CHAR;
	i, bullets: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("ai.wad", "E1M1", error));
	FOR i := 1 TO 50 DO
		game.Step(i)
	END;
	ASSERT((game.Inventory().health < 100) & (game.Inventory().health > 0));
	ASSERT(~game.Load("ai-missing-walk.wad", "E1M1", error));
	ASSERT(~game.Load("ai-bad-attack.wad", "E1M1", error));
	FOR i := 51 TO 150 DO
		game.Step(i)
	END;
	ASSERT(game.Inventory().health = 0);
	pose := game.State();
	bullets := game.Inventory().ammo[DoomInventory.Bullets];
	game.Controls(1, 1, 1);
	game.Fire(TRUE);
	game.Use;
	FOR i := 151 TO 170 DO
		game.Step(i)
	END;
	ASSERT((game.State().x = pose.x) & (game.State().y = pose.y));
	ASSERT(game.State().angle = pose.angle);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = bullets);
	ASSERT(game.Load("ai.wad", "E1M1", error));
	ASSERT(game.Inventory().health = 100);
	game.Controls(0, 0, 0);
	game.Step(171);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 50);
	game.Fire(TRUE);
	game.Step(172);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49)
END DeathAndReload;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	WakeAndSnapshots;
	WindupAndDodge;
	CollisionAndSteps;
	CustomBehavior;
	DeathAndReload;
	KernelLog.String("DoomAISmoke: melee AI {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomAISmoke.
