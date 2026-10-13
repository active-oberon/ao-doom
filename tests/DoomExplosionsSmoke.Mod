MODULE DoomExplosionsSmoke;

IMPORT DoomConfig, DoomSprites, DoomWad, DoomMap, DoomInventory, Doom, GameSurface, GameRenderer, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Equal(a, b: GameSurface.Frame): BOOLEAN;
VAR x, y: SIGNED32;
BEGIN
	FOR y := 0 TO a.height - 1 DO
		FOR x := 0 TO a.width - 1 DO
			IF a.Pixel(x, y) # b.Pixel(x, y) THEN
				RETURN FALSE
			END
		END
	END;
	RETURN TRUE
END Equal;

PROCEDURE {TEST} ChainTimingAndSnapshots*;
VAR map: DoomMap.Map;
	scene, original, first: DoomSprites.Scene;
	player: DoomInventory.State;
	a, b: GameSurface.Frame;
BEGIN
	Load("barrels-chain.wad", map);
	DoomInventory.Reset(player);
	original := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 4, 20);
	first := original.Step(map.world, 1, -3, 0, 0, player);
	ASSERT((first.EffectCount() = 1) & (first.EffectPhase(0) = 0));
	ASSERT((original.EffectCount() = 0) & (original.State(0).deathAt = -1));
	NEW(a, 320, 200);
	NEW(b, 320, 200);
	GameRenderer.Render(map.world, a, 0, 0, 0, map.eye);
	first.Render(map.world, a, 0, 0, 0, map.eye);
	ASSERT(a.Save("explosion-first.ppm"));
	scene := first.Step(map.world, 6, -3, 0, 0, player);
	ASSERT((scene.EffectPhase(0) = 1) & (first.EffectPhase(0) = 0));
	GameRenderer.Render(map.world, b, 0, 0, 0, map.eye);
	scene.Render(map.world, b, 0, 0, 0, map.eye);
	ASSERT(~Equal(a, b));
	ASSERT(b.Save("explosion-second.ppm"));
	scene := scene.Step(map.world, 15, -3, 0, 0, player);
	ASSERT((scene.Health(1) = 20) & ~scene.State(0).detonated);
	scene := scene.Step(map.world, 16, -3, 0, 0, player);
	ASSERT((scene.Health(1) = 0) & (scene.Health(2) = 20));
	ASSERT((scene.State(1).deathAt = 16) & scene.State(0).detonated);
	ASSERT((scene.EffectCount() = 2) & (scene.EffectPhase(0) = 3));
	scene := scene.Step(map.world, 31, -3, 0, 0, player);
	ASSERT((scene.Health(2) = 0) & (scene.State(2).deathAt = 31));
	scene := scene.Step(map.world, 46, -3, 0, 0, player);
	ASSERT(scene.State(2).detonated);
	scene := scene.Step(map.world, 66, -3, 0, 0, player);
	ASSERT((scene.EffectCount() = 0) & (player.health = 100));
	GameRenderer.Render(map.world, a, 0, 0, 0, map.eye);
	GameRenderer.Render(map.world, b, 0, 0, 0, map.eye);
	scene.Render(map.world, b, 0, 0, 0, map.eye);
	ASSERT(Equal(a, b));
	ASSERT((first.Health(1) = 20) & (first.EffectCount() = 1));
	Load("barrels-reversed.wad", map);
	scene := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 4, 20);
	scene := scene.Step(map.world, 1, -3, 0, 0, player);
	scene := scene.Step(map.world, 16, -3, 0, 0, player);
	ASSERT((scene.Health(1) = 0) & (scene.Health(0) = 20));
	scene := scene.Step(map.world, 31, -3, 0, 0, player);
	ASSERT((scene.Health(0) = 0) & (scene.State(0).deathAt = 31))
END ChainTimingAndSnapshots;

PROCEDURE {TEST} CoverArmorAndFreeze*;
VAR map: DoomMap.Map;
	scene, pending: DoomSprites.Scene;
	player: DoomInventory.State;
BEGIN
	Load("barrels-cover.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Shoot(map.world, -2, 0, 0, map.eye, 4, 20);
	scene := scene.Step(map.world, 1, -3, 0, 0, player);
	scene := scene.Step(map.world, 16, -3, 0, 0, player);
	ASSERT((scene.Health(1) = 20) & scene.State(0).detonated);
	Load("barrels-grate.wad", map);
	scene := map.sprites.Shoot(map.world, -2, 0, 0, map.eye, 4, 20);
	scene := scene.Step(map.world, 1, -3, 0, 0, player);
	scene := scene.Step(map.world, 16, -3, 0, 0, player);
	ASSERT(scene.Health(1) = 0);
	Load("barrels-chain.wad", map);
	DoomInventory.Reset(player);
	pending := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 4, 20);
	pending := pending.Step(map.world, 1, 0, 0, 0, player);
	scene := pending.Step(map.world, 16, 0, 0, 0, player);
	ASSERT(player.health = 20);
	DoomInventory.Reset(player);
	ASSERT(DoomInventory.Give(player, 2018));
	scene := pending.Step(map.world, 16, 0, 0, 0, player);
	ASSERT((player.health = 46) & (player.armor = 74));
	player.health := 0;
	ASSERT(pending.Step(map.world, 100, 0, 0, 0, player) = pending);
	ASSERT(~pending.State(0).detonated)
END CoverArmorAndFreeze;

PROCEDURE {TEST} ProjectileImpacts*;
VAR map: DoomMap.Map;
	scene, original, impact: DoomSprites.Scene;
	player: DoomInventory.State;
	weapon, i: SIGNED32;
	start: SIGNED64;
BEGIN
	FOR weapon := DoomInventory.Launcher TO DoomInventory.Bfg DO
		Load("weapons.wad", map);
		DoomInventory.Reset(player);
		original := map.sprites.PlayerShot(weapon, 0, 0, map.eye, 0, 0);
		scene := original;
		FOR i := 1 TO 8 DO
			scene := scene.Step(map.world, i, -3, 0, 0, player)
		END;
		ASSERT((scene.ProjectileCount() = 0) & (scene.EffectCount() = 1));
		ASSERT((scene.EffectState(0).x > 0) & (scene.EffectState(0).x < 2));
		ASSERT((original.EffectCount() = 0) & (original.ProjectileCount() = 1));
		start := scene.EffectState(0).start;
		impact := scene.Step(map.world, start + DoomConfig.values.combat.weapons[weapon].projectile.impact.ticks[0], -3, 0, 0, player);
		ASSERT(impact.EffectPhase(0) = 1);
		scene := impact.Step(map.world, start + DoomConfig.values.combat.weapons[weapon].projectile.impact.timing.duration, -3, 0, 0, player);
		ASSERT(scene.EffectCount() = 0)
	END;
	Load("projectiles.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites;
	FOR i := 1 TO 22 DO
		scene := scene.Step(map.world, i, 0, 0, 0, player)
	END;
	ASSERT((scene.EffectCount() = 1) & (player.health = 88));
	ASSERT(scene.EffectState(0).x > 0)
END ProjectileImpacts;

PROCEDURE {TEST} CapacityAndCustom*;
VAR map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	Load("barrels-many.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 4, 20);
	scene := scene.Step(map.world, 1, -3, 0, 0, player);
	scene := scene.Step(map.world, 16, -3, 0, 0, player);
	ASSERT(scene.EffectCount() = 256);
	scene := scene.Step(map.world, 31, -3, 0, 0, player);
	FOR i := 0 TO 299 DO
		ASSERT((scene.Health(i) = 0) & scene.State(i).detonated)
	END;
	scene := scene.Step(map.world, 60, -3, 0, 0, player);
	ASSERT(scene.EffectCount() = 0);
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("barrels-chain.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Shoot(map.world, 0, 0, 0, map.eye, 4, 100);
	scene := scene.Step(map.world, 1, -3, 0, 0, player);
	scene := scene.Step(map.world, 4, -3, 0, 0, player);
	ASSERT(scene.Health(1) > 0);
	scene := scene.Step(map.world, 5, -3, 0, 0, player);
	ASSERT((scene.Health(1) = 0) & scene.State(0).detonated);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CapacityAndCustom;

PROCEDURE {TEST} ReplacementResources*;
VAR game: Doom.Game;
	a, b: GameSurface.Frame;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	NEW(game);
	ASSERT(game.Load("barrels-chain.wad", "E1M1", error));
	game.Fire(TRUE);
	FOR i := 1 TO 20 DO
		game.Step(i)
	END;
	game.Fire(FALSE);
	NEW(a, 320, 200);
	NEW(b, 320, 200);
	game.Render(a);
	ASSERT(~game.Load("barrels-missing.wad", "E1M1", error));
	ASSERT(~game.Load("impact-missing.wad", "E1M1", error));
	ASSERT(~game.Load("impact-bad.wad", "E1M1", error));
	game.Render(b);
	ASSERT(Equal(a, b));
	ASSERT(game.Load("valid.wad", "E1M1", error));
	ASSERT(game.Inventory().health = 100)
END ReplacementResources;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	ChainTimingAndSnapshots;
	CoverArmorAndFreeze;
	ProjectileImpacts;
	CapacityAndCustom;
	ReplacementResources;
	KernelLog.String("DoomExplosionsSmoke: impact frames, delayed chains, cover, armor, snapshots and capacity passed.");
	KernelLog.Ln
END Do;

END DoomExplosionsSmoke.
