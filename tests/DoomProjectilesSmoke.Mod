MODULE DoomProjectilesSmoke;

IMPORT DoomConfig, DoomProjectiles, DoomSprites, DoomWad, DoomMap, DoomInventory,
	Doom, GameSurface, GameRenderer, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Fire(CONST map: DoomMap.Map; x, y, feet: FLOAT64; VAR player: DoomInventory.State): DoomSprites.Scene;
VAR scene: DoomSprites.Scene;
BEGIN
	scene := map.sprites.Step(map.world, 1, x, y, feet, player);
	RETURN scene.Step(map.world, 9, x, y, feet, player)
END Fire;

PROCEDURE {TEST} FlightAndDodge*;
VAR map: DoomMap.Map;
	launched, moved, dead, scene: DoomSprites.Scene;
	player: DoomInventory.State;
	shot: DoomProjectiles.State;
	frame: GameSurface.Frame;
	i: SIGNED32;
BEGIN
	Load("projectiles.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	ASSERT((scene.State(0).attackAt = 9) & (scene.ProjectileCount() = 0));
	launched := scene.Step(map.world, 9, 0, 0, 0, player);
	ASSERT((launched.ProjectileCount() = 1) & (player.health = 100));
	ASSERT(scene.State(0).attackAt = 9);
	ASSERT(map.sprites.ProjectileCount() = 0);
	shot := launched.ProjectileState(0);
	ASSERT((shot.owner = 0) & (shot.x = 2) & (shot.dx = -1) & (shot.dy = 0));
	moved := launched.Step(map.world, 10, 0, 0, 0, player);
	ASSERT(moved.ProjectileState(0).x = 2 - 10.0 / 64);
	ASSERT(launched.ProjectileState(0).x = 2);
	NEW(frame, 320, 200);
	GameRenderer.Render(map.world, frame, 0, 0, 0, 41.0 / 64);
	moved.Render(map.world, frame, 0, 0, 0, 41.0 / 64);
	ASSERT(frame.Save("projectiles-flight.ppm"));
	FOR i := 11 TO 20 DO
		moved := moved.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT((player.health = 88) & (moved.ProjectileCount() = 0));
	ASSERT(launched.ProjectileCount() = 1);
	DoomInventory.Reset(player);
	dead := launched.Shoot(map.world, 0, 0, 0, 41.0 / 64, 32, 100);
	ASSERT((dead.Health(0) = 0) & (dead.ProjectileCount() = 1));
	scene := dead;
	FOR i := 10 TO 80 DO
		scene := scene.Step(map.world, i, 0, 1, 0, player)
	END;
	ASSERT((player.health = 100) & (scene.ProjectileCount() = 0));
	ASSERT((dead.ProjectileCount() = 1) & (dead.ProjectileState(0).x = 2));
	DoomInventory.Reset(player);
	scene := dead;
	FOR i := 10 TO 20 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT(player.health = 88);
	player.health := 0;
	ASSERT(dead.Step(map.world, 10, 0, 0, 0, player) = dead)
END FlightAndDodge;

PROCEDURE {TEST} CoverAndPlanes*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	shot: DoomProjectiles.State;
	i: SIGNED32;
	limit: FLOAT64;
BEGIN
	DoomInventory.Reset(player);
	Load("projectiles-hidden.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	Load("projectiles-low.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	Load("projectiles-grate.wad", map);
	scene := Fire(map, 0, 0, 0, player);
	FOR i := 10 TO 30 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT(player.health = 88);
	DoomInventory.Reset(player);
	Load("projectiles-high.wad", map);
	scene := Fire(map, -3, 0, 0, player);
	ASSERT(scene.ProjectileCount() = 1);
	ASSERT(scene.ProjectileState(0).dz < 0);
	FOR i := 10 TO 40 DO
		scene := scene.Step(map.world, i, -3, 0, 0, player)
	END;
	ASSERT(player.health = 88);
	Load("projectiles.wad", map);
	shot.x := 0;
	shot.y := 0;
	shot.z := 0.5;
	shot.dx := 0;
	shot.dy := 0;
	shot.dz := -1;
	limit := DoomProjectiles.Trace(map.world, shot, 6.0 / 64, 8.0 / 64, 8);
	ASSERT(limit = 0.5 - 4.0 / 64);
	shot.dz := 1;
	limit := DoomProjectiles.Trace(map.world, shot, 6.0 / 64, 8.0 / 64, 8);
	ASSERT(limit = 2 - 4.0 / 64 - 0.5);
	shot.dz := 0;
	shot.dx := -1;
	limit := DoomProjectiles.Trace(map.world, shot, 6.0 / 64, 8.0 / 64, 8);
	ASSERT(limit = 4 - 6.0 / 64)
END CoverAndPlanes;

PROCEDURE {TEST} DoorsAndInterception*;
VAR map: DoomMap.Map;
	scene, old: DoomSprites.Scene;
	player: DoomInventory.State;
	i: SIGNED32;
BEGIN
	DoomInventory.Reset(player);
	Load("projectiles-door.wad", map);
	ASSERT(map.sprites.Step(map.world, 1, map.x, map.y, 0, player) = map.sprites);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 1 TO 40 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius,
			0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END;
	scene := Fire(map, map.x, map.y, 0, player);
	ASSERT(scene.ProjectileCount() = 1);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	FOR i := 10 TO 90 DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius,
			0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep);
		scene := scene.Step(map.world, i, map.x, map.y, 0, player)
	END;
	ASSERT((player.health = 100) & (scene.ProjectileCount() = 0));
	Load("projectiles-barrel.wad", map);
	old := Fire(map, 0, 0, 0, player);
	scene := old;
	FOR i := 10 TO 20 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT((scene.Health(1) = 8) & (player.health = 100));
	ASSERT((old.Health(1) = 20) & (old.ProjectileCount() = 1));
	Load("projectiles.wad", map);
	DoomInventory.Reset(player);
	ASSERT(DoomInventory.Give(player, 2018));
	scene := Fire(map, 0, 0, 0, player);
	FOR i := 10 TO 20 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT((player.health = 92) & (player.armor = 96))
END DoorsAndInterception;

PROCEDURE {TEST} CustomAndCapacity*;
VAR map: DoomMap.Map;
	scene, old: DoomSprites.Scene;
	player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInventory.Reset(player);
	Load("projectiles.wad", map);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 3, 0, 0, 0, player);
	ASSERT(scene.ProjectileCount() = 1);
	scene := scene.Step(map.world, 4, 0, 0, 0, player);
	ASSERT((player.health = 80) & (scene.ProjectileState(0).x = 1));
	scene := scene.Step(map.world, 5, 0, 0, 0, player);
	ASSERT((player.health = 56) & (scene.ProjectileCount() = 0));
	DoomInventory.Reset(player);
	scene := map.sprites.Step(map.world, 1, 0, 0, 0, player);
	scene := scene.Step(map.world, 3, 0, 0, 0, player);
	scene := scene.Step(map.world, 4, 0, 1, 0, player);
	scene := scene.Step(map.world, 5, 0, 1, 0, player);
	ASSERT((player.health = 80) & (scene.ProjectileCount() = 0));
	Load("projectiles-prop.wad", map);
	scene := map.sprites.Step(map.world, 1, 1, 0, 0, player);
	scene := scene.Step(map.world, 3, 1, 0, 0, player);
	ASSERT(scene.ProjectileCount() = 1);
	scene := scene.Step(map.world, 4, 1, 0, 0, player);
	ASSERT((player.health = 80) & (scene.ProjectileCount() = 0));
	ASSERT(scene.Health(1) = 0);
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Load("projectiles-many.wad", map);
	old := Fire(map, 0, 0, 0, player);
	ASSERT(old.ProjectileCount() = 256);
	ASSERT(old.ProjectileState(255).owner = 255);
	scene := old.Step(map.world, 10, 0, 0, 0, player);
	ASSERT(old.ProjectileState(0).x = 2);
	ASSERT(old.Health(0) = 60);
	ASSERT(scene.Health(0) < 60)
END CustomAndCapacity;

PROCEDURE {TEST} ReplacementAndPickups*;
VAR game: Doom.Game;
	map: DoomMap.Map;
	scene, old: DoomSprites.Scene;
	player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("projectiles-pickup.wad", map);
	DoomInventory.Reset(player);
	old := Fire(map, 0, 0, 0, player);
	scene := old.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, player);
	ASSERT((player.armor = 1) & (scene.ProjectileCount() = 1));
	ASSERT(old.Count() = scene.Count() + 1);
	FOR i := 10 TO 20 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT(player.health = 89);
	NEW(game);
	ASSERT(game.Load("projectiles.wad", "E1M1", error));
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(~game.Load("projectiles-missing.wad", "E1M1", error));
	ASSERT(~game.Load("projectiles-bad.wad", "E1M1", error));
	FOR i := 11 TO 20 DO
		game.Step(i)
	END;
	ASSERT(game.Inventory().health = 88);
	ASSERT(game.Load("valid.wad", "E1M1", error));
	FOR i := 21 TO 40 DO
		game.Step(i)
	END;
	ASSERT(game.Inventory().health = 100)
END ReplacementAndPickups;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	FlightAndDodge;
	CoverAndPlanes;
	DoorsAndInterception;
	CustomAndCapacity;
	ReplacementAndPickups;
	KernelLog.String("DoomProjectilesSmoke: projectile {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomProjectilesSmoke.
