MODULE DoomExitsSmoke;

IMPORT DoomConfig, DoomCampaign, DoomExits, DoomCombat, Doom, DoomMap, DoomWad, DoomInventory, DoomFormat,
	GameSurface, KernelLog, MathL;

PROCEDURE Load(CONST path, name: ARRAY OF CHAR): Doom.Game;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
BEGIN
	NEW(game);
	ASSERT(game.Load(path, name, error));
	RETURN game
END Load;

PROCEDURE Name(game: Doom.Game; CONST expected: ARRAY OF CHAR);
VAR name: ARRAY DoomFormat.NameLength + 1 OF CHAR;
BEGIN
	game.MapName(name);
	ASSERT(name = expected)
END Name;

PROCEDURE {TEST} Routes*;
VAR target: ARRAY DoomFormat.NameLength + 1 OF CHAR;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomCampaign.Target("e1m1", FALSE, target, error));
	ASSERT(target = "E1M2");
	ASSERT(DoomCampaign.Target("E1M3", TRUE, target, error));
	ASSERT(target = "E1M9");
	ASSERT(DoomCampaign.Target("E1M9", FALSE, target, error));
	ASSERT(target = "E1M4");
	ASSERT(DoomCampaign.Target("E2M9", FALSE, target, error));
	ASSERT(target = "E2M6");
	ASSERT(DoomCampaign.Target("E3M9", FALSE, target, error));
	ASSERT(target = "E3M7");
	ASSERT(DoomCampaign.Target("E4M9", FALSE, target, error));
	ASSERT(target = "E4M3");
	ASSERT(DoomCampaign.Target("E1M8", FALSE, target, error));
	ASSERT(target[0] = 0X);
	ASSERT(DoomCampaign.Target("MAP15", TRUE, target, error));
	ASSERT(target = "MAP31");
	ASSERT(DoomCampaign.Target("MAP31", TRUE, target, error));
	ASSERT(target = "MAP32");
	ASSERT(DoomCampaign.Target("MAP32", FALSE, target, error));
	ASSERT(target = "MAP16");
	ASSERT(DoomCampaign.Target("MAP30", FALSE, target, error));
	ASSERT(target[0] = 0X);
	ASSERT(~DoomCampaign.Target("UNKNOWN", FALSE, target, error));
	ASSERT(error[0] # 0X)
END Routes;

PROCEDURE {TEST} UseAndWalk*;
VAR game: Doom.Game;
	event: Doom.Transition;
	archive: DoomWad.Archive;
	map: DoomMap.Map;
	i, line: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	game := Load("exits-use.wad", "E1M1");
	game.Controls(1, 0, 0);
	game.Use;
	game.Step(1);
	Name(game, "E1M2");
	ASSERT((game.State().x = 0) & ~game.Finished());
	event := game.TakeTransition();
	ASSERT((event # NIL) & (event.result = Doom.LevelChanged) & (event.kind = DoomExits.Normal));
	ASSERT((event.previous = "E1M1") & (event.target = "E1M2") & (event.line = 1));
	ASSERT(game.TakeTransition() = NIL);
	game.Step(2);
	Name(game, "E1M2");
	ASSERT(game.State().x = 0);
	game := Load("exits-secret.wad", "E1M3");
	game.Use;
	game.Step(1);
	Name(game, "E1M9");
	ASSERT(game.TakeTransition().kind = DoomExits.Secret);
	FOR i := 0 TO 1 DO
		IF i = 0 THEN
			game := Load("exits-walk.wad", "E1M1")
		ELSE
			game := Load("exits-walk-secret.wad", "E1M3")
		END;
		game.Controls(1, 0, 0);
		FOR line := 1 TO 8 DO
			game.Step(line)
		END;
		IF i = 0 THEN
			Name(game, "E1M2")
		ELSE
			Name(game, "E1M9")
		END;
		event := game.TakeTransition();
		ASSERT((event # NIL) & (event.result = Doom.LevelChanged));
		ASSERT(event.line = 8)
	END;
	archive := DoomWad.Open("exits-use.wad", error);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(~map.exits.Use(map.world, 0, 0, 0));
	ASSERT(~map.exits.Use(map.world, 4.5, 0, MathL.pi));
	ASSERT(map.exits.Take(line) = DoomExits.None);
	archive := DoomWad.Open("exits-no-resources.wad", error);
	ASSERT(DoomMap.LoadMap(archive, "E1M2", map, error));
	ASSERT(~DoomMap.LoadWithWeapons(archive, "E1M2", {DoomInventory.Launcher}, map, error));
	ASSERT(error[0] # 0X)
END UseAndWalk;

PROCEDURE {TEST} CarryInventoryAndWeapon*;
VAR game: Doom.Game;
	before, after: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	a, b: GameSurface.Frame;
	x, y, changes, i: SIGNED32;
BEGIN
	game := Load("exits-carry.wad", "E1M1");
	game.Step(1);
	game.SelectWeapon(5, 0);
	before := game.Inventory();
	ASSERT((before.armor = 100) & before.backpack & (DoomInventory.BlueCard IN before.keys));
	ASSERT(DoomInventory.Launcher IN before.weapons);
	weapon := game.Weapon();
	game.Use;
	game.Step(2);
	Name(game, "E1M2");
	after := game.Inventory();
	ASSERT((after.health = before.health) & (after.armor = before.armor));
	ASSERT(after.backpack & (after.weapons = before.weapons));
	FOR i := 0 TO DoomInventory.AmmoKinds - 1 DO
		ASSERT((after.ammo[i] = before.ammo[i]) & (after.maximum[i] = before.maximum[i]))
	END;
	ASSERT((after.keys = {}) & (after.pickups = 0) & (after.neededKey = -1));
	ASSERT(game.Weapon().selected = weapon.selected);
	FOR i := 0 TO DoomInventory.WeaponKinds - 1 DO
		ASSERT(game.Weapon().loaded[i] = weapon.loaded[i])
	END;
	NEW(a, 320, 200);
	NEW(b, 320, 200);
	game.Render(a);
	game.Fire(TRUE);
	game.Step(3);
	game.Fire(FALSE);
	game.Render(b);
	changes := 0;
	FOR y := 0 TO 159 DO
		FOR x := 0 TO 319 DO
			IF a.Pixel(x, y) # b.Pixel(x, y) THEN
				INC(changes)
			END
		END
	END;
	ASSERT(changes > 100);
	ASSERT(game.Inventory().ammo[DoomInventory.Rockets] = before.ammo[DoomInventory.Rockets] - 1)
END CarryInventoryAndWeapon;

PROCEDURE {TEST} FailureAndReset*;
VAR game: Doom.Game;
	before: DoomInventory.State;
	event: Doom.Transition;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	FOR i := 0 TO 2 DO
		CASE i OF
			0:
				game := Load("exits-missing.wad", "E1M1")
			| 1:
				game := Load("exits-bad.wad", "E1M1")
			| 2:
				game := Load("exits-resource-missing.wad", "E1M1")
		END;
		before := game.Inventory();
		game.Use;
		game.Step(1);
		Name(game, "E1M1");
		ASSERT((game.State().x = 3.5) & ~game.Finished());
		ASSERT(game.Inventory().health = before.health);
		ASSERT(game.Inventory().ammo[0] = before.ammo[0]);
		event := game.TakeTransition();
		ASSERT((event # NIL) & (event.result = Doom.TransitionFailed) & (event.error[0] # 0X));
		game.Step(2);
		ASSERT(game.TakeTransition() = NIL);
		game.Use;
		game.Step(3);
		ASSERT(game.TakeTransition().result = Doom.TransitionFailed);
		ASSERT(game.Load("valid.wad", "E1M1", error));
		ASSERT((game.Inventory().health = 100) & ~game.Finished())
	END
END FailureAndReset;

PROCEDURE {TEST} CompletionAndCustom*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	before: DoomInventory.State;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	game := Load("exits-end.wad", "E1M8");
	game.Use;
	game.Step(1);
	ASSERT(game.Finished());
	ASSERT(game.TakeTransition().result = Doom.CampaignComplete);
	pose := game.State();
	before := game.Inventory();
	game.Controls(1, 0, 1);
	game.Fire(TRUE);
	game.Aim(TRUE);
	game.Look(100, 100);
	game.Reload;
	game.Use;
	FOR i := 2 TO 40 DO
		game.Step(i)
	END;
	ASSERT((game.State().x = pose.x) & (game.State().angle = pose.angle));
	FOR i := 0 TO DoomInventory.AmmoKinds - 1 DO
		ASSERT(game.Inventory().ammo[i] = before.ammo[i])
	END;
	ASSERT(game.TakeTransition() = NIL);
	ASSERT(~game.Load("short.wad", "E1M1", error));
	ASSERT(game.Finished());
	game := Load("exits-end-ii.wad", "MAP30");
	game.Use;
	game.Step(1);
	ASSERT(game.Finished());
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	game := Load("exits-custom.wad", "E1M1");
	game.Use;
	game.Step(1);
	Name(game, "E1M3");
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CompletionAndCustom;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Routes;
	UseAndWalk;
	CarryInventoryAndWeapon;
	FailureAndReset;
	CompletionAndCustom;
	KernelLog.String("DoomExitsSmoke: normal/secret use and crossing exits, routes, inventory, resources, failure and completion passed.");
	KernelLog.Ln
END Do;

END DoomExitsSmoke.
