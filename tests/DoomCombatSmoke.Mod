MODULE DoomCombatSmoke;

IMPORT DoomConfig, DoomCombat, DoomInventory, DoomSprites, DoomWad, DoomMap,
	Doom, GameSurface, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE {TEST} NearestAndDeath*;
VAR map: DoomMap.Map;
	first, dead, after: DoomSprites.Scene;
	frame: GameSurface.Frame;
	player: DoomInventory.State;
BEGIN
	Load("combat-nearest.wad", map);
	ASSERT((map.sprites.Health(0) = 20) & (map.sprites.Health(1) = 20));
	first := map.sprites.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 10);
	ASSERT(first # map.sprites);
	ASSERT((first.Health(0) = 20) & (first.Health(1) = 10));
	ASSERT(map.sprites.Health(1) = 20);
	ASSERT(~first.Free(2, 0, DoomConfig.values.playerRadius));
	dead := first.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 10);
	ASSERT((dead.Health(0) = 20) & (dead.Health(1) = 0));
	ASSERT(dead.Free(2, 0, DoomConfig.values.playerRadius));
	ASSERT(dead.Count() = 2);
	after := dead.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 100);
	ASSERT((after.Health(0) = 0) & (after.Health(1) = 0));
	ASSERT(after.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 10) = after);
	Load("combat.wad", map);
	dead := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 32, 20);
	NEW(frame, 320, 200);
	frame.Background(0, 0);
	map.sprites.Render(map.world, frame, 0, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 80) # 0);
	frame.Background(0, 0);
	dead.Render(map.world, frame, 0, 0, 0, map.eye);
	ASSERT(frame.Pixel(160, 80) = 0);
	ASSERT(frame.Pixel(160, 160) # 0);
	Load("combat-pickup.wad", map);
	DoomInventory.Reset(player);
	first := map.sprites.Touch(map.world, map.x, map.y, 0,
		DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, player);
	ASSERT((first.Count() = 1) & (player.pickups = 1));
	dead := first.Shoot(map.world, 0, 0, 0, map.eye, 32, 20);
	ASSERT((dead.Count() = 1) & (dead.Health(0) = 0));
	ASSERT(dead.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius,
		DoomConfig.values.playerHeight, player) = dead);
	first := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 32, 20);
	DoomInventory.Reset(player);
	dead := first.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius,
		DoomConfig.values.playerHeight, player);
	ASSERT((dead.Health(0) = 0) & (first.Count() = 2) & (dead.Count() = 1))
END NearestAndDeath;

PROCEDURE Blocked(CONST path: ARRAY OF CHAR);
VAR map: DoomMap.Map;
BEGIN
	Load(path, map);
	ASSERT(map.sprites.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 20) = map.sprites);
	ASSERT(map.sprites.Health(0) = 20)
END Blocked;

PROCEDURE {TEST} WallsAndPortals*;
VAR map: DoomMap.Map;
	dead: DoomSprites.Scene;
	player: DoomInventory.State;
	i: SIGNED32;
BEGIN
	Blocked("combat-off-axis.wad");
	Blocked("combat-closed.wad");
	Blocked("combat-step.wad");
	Blocked("combat-blocked.wad");
	Blocked("combat-door.wad");
	Load("combat.wad", map);
	ASSERT(map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 1, 20) = map.sprites);
	ASSERT(map.sprites.Shoot(map.world, 0, 0, 0, 1, 32, 20) = map.sprites);
	ASSERT(map.sprites.Shoot(map.world, 2, 2, 0, map.eye, 32, 20) = map.sprites);
	dead := map.sprites.Shoot(map.world, 2, 2, -1.5707963267948966, map.eye, 32, 20);
	ASSERT(dead.Health(0) = 0);
	Load("combat-grate.wad", map);
	dead := map.sprites.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 20);
	ASSERT(dead.Health(0) = 0);
	Load("combat-door.wad", map);
	DoomInventory.Reset(player);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 1 TO 40 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius,
			0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	dead := map.sprites.Shoot(map.world, map.x, map.y, 0, map.eye, 32, 20);
	ASSERT(dead.Health(0) = 0)
END WallsAndPortals;

PROCEDURE {TEST} WeaponAndCustomConfig*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	frame: GameSurface.Frame;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("combat.wad", map);
	DoomInventory.Reset(player);
	ASSERT((player.health = 80) & (player.ammo[DoomInventory.Bullets] = 24));
	ASSERT(map.sprites.Health(0) = 15);
	weapon.nextShot := 0;
	weapon.flashUntil := 0;
	scene := DoomCombat.Step(1, FALSE, weapon, map.world, map.sprites, 0, 0, 0, map.eye, player);
	ASSERT((scene = map.sprites) & (player.ammo[DoomInventory.Bullets] = 24));
	scene := DoomCombat.Step(1, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 8) & (player.ammo[DoomInventory.Bullets] = 22));
	ASSERT((weapon.nextShot = 4) & (weapon.flashUntil = 3));
	scene := DoomCombat.Step(3, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 8) & (player.ammo[DoomInventory.Bullets] = 22));
	scene := DoomCombat.Step(4, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 1) & (player.ammo[DoomInventory.Bullets] = 20));
	scene := DoomCombat.Step(7, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 0) & (player.ammo[DoomInventory.Bullets] = 18));
	player.ammo[DoomInventory.Bullets] := 1;
	scene := DoomCombat.Step(10, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((player.ammo[DoomInventory.Bullets] = 1) & (weapon.nextShot = 10));
	player.ammo[DoomInventory.Bullets] := 10;
	player.health := 0;
	scene := DoomCombat.Step(10, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT(player.ammo[DoomInventory.Bullets] = 10);
	player.health := 80;
	player.weapons := {DoomInventory.Fist};
	scene := DoomCombat.Step(10, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT(player.ammo[DoomInventory.Bullets] = 10);
	INCL(player.weapons, DoomInventory.Pistol);
	scene := DoomCombat.Step(10, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT(player.ammo[DoomInventory.Bullets] = 8);
	NEW(frame, 400, 240);
	DoomCombat.DrawAim(frame, FALSE);
	ASSERT(frame.Pixel(200, 120) = 0224466H);
	ASSERT(frame.Pixel(205, 120) = 0224466H);
	ASSERT(frame.Pixel(206, 120) = 0);
	DoomCombat.DrawAim(frame, TRUE);
	ASSERT(frame.Pixel(200, 120) = 0FF8800H);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END WeaponAndCustomConfig;

PROCEDURE {TEST} GameIntegration*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("combat.wad", "E1M1", error));
	game.Fire(TRUE);
	game.Step(1);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49);
	ASSERT(~game.Load("combat-missing-death.wad", "E1M1", error));
	ASSERT(~game.Load("combat-bad-death.wad", "E1M1", error));
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49);
	FOR i := 2 TO 19 DO
		game.Step(i)
	END;
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49);
	game.Step(20);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 48);
	game.Fire(FALSE);
	game.Controls(1, 0, 0);
	FOR i := 21 TO 60 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT(pose.x > 3.5);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 48);
	ASSERT(game.Load("combat.wad", "E1M1", error));
	game.Controls(0, 0, 0);
	game.Step(61);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 50);
	game.Fire(TRUE);
	game.Step(62);
	ASSERT(game.Inventory().ammo[DoomInventory.Bullets] = 49)
END GameIntegration;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	NearestAndDeath;
	WallsAndPortals;
	WeaponAndCustomConfig;
	GameIntegration;
	KernelLog.String("DoomCombatSmoke: combat {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomCombatSmoke.
