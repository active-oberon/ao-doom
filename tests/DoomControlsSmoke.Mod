MODULE DoomControlsSmoke;

IMPORT DoomConfig, DoomInput, DoomCombat, DoomInventory, DoomThings, DoomSprites, DoomWad, DoomMap,
	Doom, GameSurface, MathL, KernelLog;

PROCEDURE Load(VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open("weapons.wad", error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE {TEST} MouseAndEdges*;
VAR input: DoomInput.Controller;
	move, strafe, turn, dx, dy, slot, cycle: SIGNED32;
	use, fire, reload, aim: BOOLEAN;
BEGIN
	NEW(input);
	input.Mouse({0, 2}, -2);
	input.Motion(10, -20);
	input.Motion(5, 6);
	input.Key(ORD("r"), FALSE);
	input.Key(ORD("3"), FALSE);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	ASSERT(fire);
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT((dx = 15) & (dy = -14) & (slot = 3) & (cycle = -2) & reload & aim);
	input.Key(ORD("r"), FALSE);
	input.Key(ORD("3"), FALSE);
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT((dx = 0) & (dy = 0) & (slot = 0) & (cycle = 0) & ~reload & aim);
	input.Key(ORD("r"), TRUE);
	input.Key(ORD("r"), FALSE);
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT(reload);
	input.Key(ORD("e"), FALSE);
	input.Focus(FALSE);
	input.Mouse({0, 2}, 1);
	input.Motion(10, 20);
	input.Key(ORD("w"), FALSE);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT((move = 0) & (dx = 0) & (dy = 0) & (cycle = 0) & ~use & ~fire & ~reload & ~aim);
	input.Focus(TRUE);
	input.Key(ORD("w"), FALSE);
	input.Key(ORD("d"), FALSE);
	input.Key(ORD("e"), FALSE);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	ASSERT((move = 1) & (strafe = 1) & (turn = 0) & use);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	ASSERT(~use)
END MouseAndEdges;

PROCEDURE {TEST} MagazineAndSelection*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	scene: DoomSprites.Scene;
	i: SIGNED32;
	tick: SIGNED64;
BEGIN
	Load(map);
	DoomInventory.Reset(player);
	DoomCombat.Reset(weapon, player);
	scene := map.sprites;
	FOR i := 0 TO 11 DO
		tick := 1 + i * DoomConfig.values.combat.cooldown;
		scene := DoomCombat.Step(tick, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player)
	END;
	ASSERT((weapon.loaded[DoomInventory.Pistol] = 0) & (player.ammo[DoomInventory.Bullets] = 38));
	scene := DoomCombat.Step(250, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT(player.ammo[DoomInventory.Bullets] = 38);
	DoomCombat.Reload(250, weapon, player);
	ASSERT(weapon.reloadUntil = 285);
	DoomCombat.Reload(251, weapon, player);
	ASSERT(weapon.reloadUntil = 285);
	scene := DoomCombat.Step(284, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT(player.ammo[DoomInventory.Bullets] = 38);
	scene := DoomCombat.Step(285, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((weapon.reloadUntil = 0) & (weapon.loaded[DoomInventory.Pistol] = 11));
	ASSERT(player.ammo[DoomInventory.Bullets] = 37);
	DoomCombat.Select(weapon, player, 7);
	ASSERT(weapon.selected = DoomInventory.Pistol);
	INCL(player.weapons, DoomInventory.Chaingun);
	DoomCombat.Select(weapon, player, 4);
	ASSERT((weapon.selected = DoomInventory.Chaingun) & (weapon.loaded[DoomInventory.Chaingun] = 26));
	ASSERT(DoomCombat.Reserve(weapon, player, DoomInventory.Bullets) = 0);
	DoomCombat.Reload(300, weapon, player);
	ASSERT(weapon.reloadUntil = 0);
	DoomCombat.Select(weapon, player, 2);
	DoomCombat.Select(weapon, player, 4);
	ASSERT((weapon.loaded[DoomInventory.Chaingun] = 26) & (player.ammo[DoomInventory.Bullets] = 37));
	DoomCombat.Cycle(weapon, player, 1);
	ASSERT(weapon.selected = DoomInventory.Fist);
	DoomCombat.Cycle(weapon, player, -1);
	ASSERT(weapon.selected = DoomInventory.Chaingun);
	INCL(player.weapons, DoomInventory.Shotgun);
	INCL(player.weapons, DoomInventory.SuperShotgun);
	DoomCombat.Select(weapon, player, 3);
	ASSERT(weapon.selected = DoomInventory.SuperShotgun);
	DoomCombat.Select(weapon, player, 3);
	ASSERT(weapon.selected = DoomInventory.Shotgun);
	DoomCombat.Select(weapon, player, 1);
	ASSERT(weapon.selected = DoomInventory.Fist);
	INCL(player.weapons, DoomInventory.Chainsaw);
	DoomCombat.Select(weapon, player, 1);
	ASSERT(weapon.selected = DoomInventory.Chainsaw);
	DoomCombat.Select(weapon, player, 1);
	ASSERT(weapon.selected = DoomInventory.Fist)
END MagazineAndSelection;

PROCEDURE {TEST} ReloadAndAimGeometry*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	scene: DoomSprites.Scene;
BEGIN
	Load(map);
	ASSERT(map.sprites.ShootAim(map.world, 0, 0, 0, map.eye, 0.6, 32, 20) = map.sprites);
	ASSERT(map.sprites.ShootAim(map.world, 0, 0, 0, map.eye, -0.6, 32, 20) = map.sprites);
	ASSERT(map.sprites.ShootAim(map.world, 0, 0, 0, map.eye, 0.1, 32, 20).Health(0) = 0);
	DoomInventory.Reset(player);
	DoomCombat.Reset(weapon, player);
	weapon.loaded[DoomInventory.Pistol] := 0;
	player.ammo[DoomInventory.Bullets] := 5;
	DoomCombat.Reload(1, weapon, player);
	scene := DoomCombat.Step(36, FALSE, weapon, map.world, map.sprites, 0, 0, 0, map.eye, player);
	ASSERT((weapon.loaded[DoomInventory.Pistol] = 5) & (player.ammo[DoomInventory.Bullets] = 5));
	ASSERT(DoomCombat.Reserve(weapon, player, DoomInventory.Bullets) = 0);
	ASSERT(DoomInventory.Give(player, DoomThings.Clip));
	DoomCombat.Reload(40, weapon, player);
	ASSERT(weapon.reloadUntil = 75);
	DoomCombat.Select(weapon, player, 1);
	scene := DoomCombat.Step(75, FALSE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((weapon.reloadUntil = 0) & (weapon.loaded[DoomInventory.Pistol] = 5));
	ASSERT(player.ammo[DoomInventory.Bullets] = 15);
	DoomCombat.Select(weapon, player, 2);
	DoomCombat.Reload(80, weapon, player);
	scene := DoomCombat.Step(115, FALSE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
	ASSERT((weapon.loaded[DoomInventory.Pistol] = 12) & (player.ammo[DoomInventory.Bullets] = 15));
	DoomCombat.Select(weapon, player, 1);
	scene := DoomCombat.Step(116, TRUE, weapon, map.world, map.sprites, 1, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 10) & (player.ammo[DoomInventory.Bullets] = 15));
	INCL(player.weapons, DoomInventory.Chainsaw);
	DoomCombat.Select(weapon, player, 1);
	scene := DoomCombat.Step(140, TRUE, weapon, map.world, scene, 1, 0, 0, map.eye, player);
	ASSERT((scene.Health(0) = 0) & (player.ammo[DoomInventory.Bullets] = 15))
END ReloadAndAimGeometry;

PROCEDURE {TEST} OwnedArsenal*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	weapon: DoomCombat.Weapon;
	scene, flight, branch: DoomSprites.Scene;
	i, slot, target: SIGNED32;
	tick: SIGNED64;
BEGIN
	FOR slot := 3 TO 7 DO
		Load(map);
		DoomInventory.Reset(player);
		scene := map.sprites.Touch(map.world, 0, 0, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, player);
		ASSERT(player.pickups = 7);
		DoomCombat.Reset(weapon, player);
		DoomCombat.Select(weapon, player, slot);
		flight := DoomCombat.Step(1, TRUE, weapon, map.world, scene, 0, 0, 0, map.eye, player);
		IF slot = 4 THEN
			flight := DoomCombat.Step(5, TRUE, weapon, map.world, flight, 0, 0, 0, map.eye, player)
		END;
		IF slot >= 5 THEN
			ASSERT((flight.ProjectileCount() = 1) & (scene.ProjectileCount() = 0));
			ASSERT(flight.ProjectileState(0).owner = -1);
			branch := scene.PlayerShot(weapon.selected, 0, 0, map.eye, MathL.pi / 2, 0);
			ASSERT(ABS(flight.ProjectileState(0).dy) < 0.000001);
			ASSERT(branch.ProjectileState(0).dy > 0.99);
			FOR i := 2 TO 15 DO
				tick := i;
				flight := flight.Step(map.world, tick, 0, 0, 0, player)
			END;
			ASSERT(flight.ProjectileCount() = 0)
		END;
		target := 0;
		ASSERT(flight.Health(target) = 0);
		ASSERT(scene.Health(target) = 20)
	END
END OwnedArsenal;

PROCEDURE {TEST} LookAimAndReset*;
VAR game: Doom.Game;
	frame: GameSurface.Frame;
	pose: Doom.Pose;
	weapon: DoomCombat.Weapon;
	error: ARRAY 256 OF CHAR;
BEGIN
	NEW(game);
	ASSERT(game.Load("combat.wad", "E1M1", error));
	game.Look(100, -100);
	pose := game.State();
	ASSERT((ABS(pose.angle - 0.3) < 0.000001) & (ABS(pose.pitch - 0.3) < 0.000001));
	game.Aim(TRUE);
	game.Look(100, -100);
	pose := game.State();
	ASSERT((ABS(pose.angle - 0.45) < 0.000001) & (ABS(pose.pitch - 0.45) < 0.000001));
	game.Look(32768, -32768);
	pose := game.State();
	ASSERT((pose.angle >= -MathL.pi) & (pose.angle <= MathL.pi) & (pose.pitch = DoomConfig.values.pitchLimit));
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	game.Render(frame);
	ASSERT(frame.Save("controls-look.ppm"));
	ASSERT(game.Load("combat.wad", "E1M1", error));
	ASSERT(game.State().pitch = 0);
	game.Fire(TRUE);
	game.Step(1);
	game.Reload;
	game.Step(2);
	ASSERT(game.Weapon().reloadUntil > 0);
	ASSERT(~game.Load("weapons-missing.wad", "E1M1", error));
	ASSERT(~game.Load("weapons-bad.wad", "E1M1", error));
	ASSERT(game.Weapon().reloadUntil > 0);
	ASSERT(game.Load("weapons.wad", "E1M1", error));
	weapon := game.Weapon();
	ASSERT((weapon.selected = DoomInventory.Pistol) & (weapon.reloadUntil = 0));
	game.Step(3);
	ASSERT(game.Inventory().pickups = 7);
	game.SelectWeapon(5, 0);
	ASSERT(game.Weapon().selected = DoomInventory.Launcher)
END LookAimAndReset;

PROCEDURE {TEST} CustomMouse*;
VAR game: Doom.Game;
	input: DoomInput.Controller;
	move, strafe, turn, dx, dy, slot, cycle: SIGNED32;
	use, fire, reload, aim: BOOLEAN;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	NEW(game);
	game.Look(100, 100);
	ASSERT((ABS(game.State().angle - 0.4) < 0.000001) & (ABS(game.State().pitch - 0.4) < 0.000001));
	game.Aim(TRUE);
	game.Look(100, 100);
	ASSERT((ABS(game.State().angle - 0.5) < 0.000001) & (game.State().pitch = 0.5));
	NEW(input);
	input.Mouse({2}, 0);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT(fire & ~aim);
	input.Mouse({0}, 0);
	ASSERT(input.Read(move, strafe, turn, use, fire));
	input.Extra(dx, dy, slot, cycle, reload, aim);
	ASSERT(~fire & aim);
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error))
END CustomMouse;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	MouseAndEdges;
	MagazineAndSelection;
	ReloadAndAimGeometry;
	OwnedArsenal;
	LookAimAndReset;
	CustomMouse;
	KernelLog.String("DoomControlsSmoke: mouse, reload, selection, arsenal and automatic pickup checks passed.");
	KernelLog.Ln
END Do;

END DoomControlsSmoke.
