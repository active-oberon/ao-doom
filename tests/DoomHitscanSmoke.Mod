MODULE DoomHitscanSmoke;

IMPORT DoomConfig, DoomInventory, DoomSprites, DoomWad, DoomMap, Doom,
	GameSurface, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE {TEST} WindupArmorAndSpread*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	frame: GameSurface.Frame;
	color, i: SIGNED32;
BEGIN
	Load("hitscan.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	ASSERT((scene.State(0).attackAt = 11) & (scene.State(0).attackUntil = 36));
	ASSERT((scene.State(0).x = 2) & ~scene.State(0).moving);
	NEW(frame, 320, 200);
	frame.Background(0, 0);
	scene.Render(map.world, frame, 0, 0, 0, map.eye);
	color := frame.Pixel(160, 80);
	FOR i := 2 TO 10 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT(player.health = 100);
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT(player.health = 97);
	frame.Background(0, 0);
	scene.Render(map.world, frame, 0, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 80) # color);
	FOR i := 12 TO 45 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT(player.health = 97);
	scene := scene.Step(map.world, 46, 0, 0, 0, player);
	ASSERT(player.health = 94);
	DoomInventory.Reset(player);
	ASSERT(DoomInventory.Give(player, 2018));
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT((player.health = 98) & (player.armor = 99));
	Load("hitscan-shotgun.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT(player.health = 91);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, -2, 0, 0, player);
	scene := scene.Step(map.world, 11, -2, 0, 0, player);
	ASSERT(player.health = 97)
END WindupArmorAndSpread;

PROCEDURE {TEST} CoverAndHeight*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	i: SIGNED32;
BEGIN
	DoomInventory.Reset(player);
	Load("hitscan-hidden.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	scene := map.sprites.Step(map.world, 1, 1, 0, 24.0 / 64, player);
	ASSERT(scene.State(0).attackAt = 11);
	scene := scene.Step(map.world, 11, map.x, map.y, 0, player);
	ASSERT(player.health = 100);
	Load("hitscan-high.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, -2, 0, 0, player) = map.sprites);
	scene := map.sprites.Step(map.world, 1, -3, 0, 0, player);
	ASSERT(scene.State(0).awake);
	scene := scene.Step(map.world, 11, -3, 0, 0, player);
	ASSERT(player.health = 97);
	Load("hitscan-low-ceiling.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	Load("hitscan-grate.wad", map);
	scene := map.sprites.Step(map.world, 1, map.x, map.y, 0, player);
	scene := scene.Step(map.world, 11, map.x, map.y, 0, player);
	ASSERT(player.health = 94);
	Load("hitscan-door.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 1 TO 40 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius,
			0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	scene := map.sprites.Step(map.world, 1, map.x, map.y, 0, player);
	scene := scene.Step(map.world, 11, map.x, map.y, 0, player);
	ASSERT(player.health = 91)
END CoverAndHeight;

PROCEDURE {TEST} InterceptionAndSnapshots*;
VAR map: DoomMap.Map;
	scene, before, dead: DoomSprites.Scene;
	player: DoomInventory.State;
BEGIN
	DoomInventory.Reset(player);
	Load("hitscan-barrel.wad", map);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	before := scene;
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT((player.health = 100) & (scene.Health(1) = 17));
	ASSERT((before.Health(1) = 20) & (scene.Health(0) = 20));
	dead := scene.Shoot(map.world, 0, 0, 0, map.eye, 32, 17);
	ASSERT((dead.Health(1) = 0) & (dead.State(0).attackUntil = 36));
	dead := dead.Step(map.world, 36, 0, 0, 0, player);
	dead := dead.Step(map.world, 46, 0, 0, 0, player);
	ASSERT(player.health = 97);
	Load("hitscan-pickup.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius,
		DoomConfig.values.playerHeight, player);
	ASSERT((scene.Count() = 1) & (scene.State(0).attackAt = 11));
	dead := scene.Shoot(map.world, 0, 0, 0, map.eye, 32, 20);
	ASSERT(dead.Step(map.world, 11, 0, 0, 0, player) = dead);
	ASSERT((player.health = 100) & (player.pickups = 1))
END InterceptionAndSnapshots;

PROCEDURE {TEST} PelletInterceptionAndDeath*;
VAR map: DoomMap.Map;
	scene, before: DoomSprites.Scene;
	player: DoomInventory.State;
BEGIN
	Load("hitscan-shotgun-barrel.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	before := scene;
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT((scene.Health(1) = 11) & (before.Health(1) = 20));
	ASSERT(player.health = 100);
	scene := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 32, 15);
	ASSERT(scene.Health(1) = 5);
	scene := scene.Step(map.world, 1, 0, 0, 0, player);
	before := scene;
	scene := scene.Step(map.world, 11, 0, 0, 0, player);
	ASSERT((scene.Health(1) = 0) & (before.Health(1) = 5));
	ASSERT(player.health = 97);
	ASSERT(scene.Health(0) = 30)
END PelletInterceptionAndDeath;

PROCEDURE {TEST} CustomChaseAndFriendlyFire*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInventory.Reset(player);
	Load("hitscan.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, -3, 0, 0, player) = map.sprites);
	scene := map.sprites.Step(map.world, 1, -1, 0, 0, player);
	ASSERT((scene.State(0).x = 2 - 2.0 / 64) & scene.State(0).moving);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 3, 0, 0, 0, player);
	ASSERT(player.health = 73);
	Load("hitscan-shotgun.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 3, 0, 0, 0, player);
	ASSERT(player.health = 68);
	Load("hitscan-friendly.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 3, 0, 0, 0, player);
	ASSERT((scene.Health(1) = 8) & (player.health = 73));
	scene := scene.Step(map.world, 8, 0, 0, 0, player);
	scene := scene.Step(map.world, 10, 0, 0, 0, player);
	ASSERT((scene.Health(1) = 1) & (player.health = 66));
	scene := scene.Step(map.world, 15, 0, 0, 0, player);
	scene := scene.Step(map.world, 17, 0, 0, 0, player);
	ASSERT((scene.Health(1) = 0) & (player.health = 66));
	ASSERT(scene.Free(-1, 0, DoomConfig.values.playerRadius));
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error))
END CustomChaseAndFriendlyFire;

PROCEDURE {TEST} GameAndResourceFailures*;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
	i, health: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("hitscan.wad", "E1M1", error));
	FOR i := 1 TO 50 DO
		game.Step(i)
	END;
	health := game.Inventory().health;
	ASSERT(health = 94);
	ASSERT(~game.Load("hitscan-missing-walk.wad", "E1M1", error));
	ASSERT(~game.Load("hitscan-bad-attack.wad", "E1M1", error));
	ASSERT(game.Inventory().health = health);
	ASSERT(game.Load("hitscan.wad", "E1M1", error));
	ASSERT(game.Inventory().health = 100);
	game.Step(51);
	game.Fire(TRUE);
	game.Step(52);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49)
END GameAndResourceFailures;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	WindupArmorAndSpread;
	CoverAndHeight;
	InterceptionAndSnapshots;
	PelletInterceptionAndDeath;
	CustomChaseAndFriendlyFire;
	GameAndResourceFailures;
	KernelLog.String("DoomHitscanSmoke: ranged attacks {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomHitscanSmoke.
