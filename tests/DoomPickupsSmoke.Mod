MODULE DoomPickupsSmoke;

IMPORT Doom, DoomInventory, DoomHud, DoomWad, DoomMap, DoomSprites,
	GameRenderer, GameSurface;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Difference(first, second: GameSurface.Frame): SIGNED32;
VAR x, y, count: SIGNED32;
BEGIN
	count := 0;
	FOR y := 0 TO first.height - DoomHud.Height - 1 DO
		FOR x := 0 TO first.width - 1 DO
			IF first.Pixel(x, y) # second.Pixel(x, y) THEN
				INC(count)
			END
		END
	END;
	RETURN count
END Difference;

PROCEDURE Blocked(CONST path: ARRAY OF CHAR);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	scene: DoomSprites.Scene;
BEGIN
	Load(path, map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, -0.25, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene = map.sprites);
	ASSERT((scene.Count() = 1) & (player.pickups = 0))
END Blocked;

PROCEDURE Do*;
VAR map: DoomMap.Map;
	scene, again: DoomSprites.Scene;
	player, copy: DoomInventory.State;
	game: Doom.Game;
	pose: Doom.Pose;
	plain, old, collected: GameSurface.Frame;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("sprites-grate.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2 - 36.0 / 64, 0, 0,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene = map.sprites);
	scene := scene.Touch(map.world, 2 - 36.0 / 64 + 0.000001, 0, 0,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((scene # map.sprites) & (scene.Count() = 0));
	ASSERT((player.armor = 1) & (player.pickups = 1));
	ASSERT(map.sprites.Count() = 1);
	again := scene.Touch(map.world, 2, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((again = scene) & (player.pickups = 1));
	NEW(plain, 320, 200);
	NEW(old, 320, 200);
	NEW(collected, 320, 200);
	GameRenderer.Render(map.world, plain, map.x, map.y, map.angle, map.eye);
	GameRenderer.Render(map.world, old, map.x, map.y, map.angle, map.eye);
	map.sprites.Render(map.world, old, map.x, map.y, map.angle, map.eye);
	GameRenderer.Render(map.world, collected, map.x, map.y, map.angle, map.eye);
	scene.Render(map.world, collected, map.x, map.y, map.angle, map.eye);
	ASSERT(Difference(plain, collected) = 0);
	ASSERT(Difference(old, collected) > 100);
	ASSERT(old.Save("pickups-before.ppm"));
	ASSERT(collected.Save("pickups-after.ppm"));
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2, 36.0 / 64, 0,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene = map.sprites);
	scene := map.sprites.Touch(map.world, 2, 0, 8.0 / 64 + 0.000001,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene = map.sprites);
	scene := map.sprites.Touch(map.world, 2, 0, -Doom.PlayerHeight - 0.000001,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene = map.sprites);
	scene := map.sprites.Touch(map.world, 2, 0, 8.0 / 64,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene.Count() = 0);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2, 0, -Doom.PlayerHeight,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT(scene.Count() = 0);
	Blocked("pickups-blocked.wad");
	Blocked("pickups-solid.wad");
	Blocked("pickups-closed.wad");
	Load("pickups-passable.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, -0.25, 0, 0,
		Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((scene.Count() = 0) & (player.armor = 1));
	Load("pickups-many.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((map.sprites.Count() = 33) & (scene.Count() = 0));
	ASSERT((player.armor = 33) & (player.pickups = 33));
	Load("pickups.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((map.sprites.Count() = 8) & (scene.Count() = 2));
	ASSERT((player.health = 101) & (player.armor = 1));
	ASSERT((player.ammo[0] = 70) & (player.ammo[1] = 12));
	ASSERT((player.ammo[2] = 20) & (player.ammo[3] = 1));
	ASSERT(DoomInventory.BlueCard IN player.keys);
	ASSERT(DoomInventory.Shotgun IN player.weapons);
	ASSERT(player.backpack & (player.pickups = 6));
	ASSERT(scene.Touch(map.world, 2, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player) = scene);
	NEW(game);
	ASSERT(game.Load("pickups.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 40 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT(pose.x > 3.5);
	copy := game.Inventory();
	ASSERT((copy.pickups = 6) & (copy.armor = 1) & (copy.health = 101));
	ASSERT((copy.keys = player.keys) & (copy.weapons = player.weapons));
	game.Render(old);
	ASSERT(old.Pixel(144, 193) = 060A0FFH);
	ASSERT(old.Save("pickups-hud.ppm"));
	copy.health := 0;
	copy.ammo[0] := 0;
	copy := game.Inventory();
	ASSERT((copy.health = 101) & (copy.ammo[0] = 70));
	ASSERT(~game.Load("sprite-missing.wad", "E1M1", error));
	game.Render(collected);
	ASSERT(Difference(old, collected) = 0);
	copy := game.Inventory();
	ASSERT((copy.pickups = 6) & (copy.armor = 1));
	game.Controls(0, 0, 0);
	game.Step(41);
	copy := game.Inventory();
	ASSERT(copy.pickups = 6);
	ASSERT(game.Load("sprites-grate.wad", "E1M1", error));
	copy := game.Inventory();
	ASSERT((copy.pickups = 0) & (copy.keys = {}) & (copy.armor = 0));
	ASSERT((copy.health = 100) & (copy.maximum[0] = 200))
END Do;

END DoomPickupsSmoke.
