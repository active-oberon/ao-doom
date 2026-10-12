MODULE DoomCombat;

IMPORT DoomConfig, DoomInventory, DoomSprites, GameGeometry, GameSurface, GameText, Strings, MathL;

TYPE Weapon* = RECORD
	nextShot*, flashUntil*, reloadUntil*: SIGNED64;
	selected*: SIGNED32;
	loaded*: ARRAY DoomInventory.WeaponKinds OF SIGNED32;
	prepared: SET
END;

PROCEDURE Reset*(VAR weapon: Weapon; CONST player: DoomInventory.State);
VAR i, ammo: SIGNED32;
BEGIN
	weapon.nextShot := 0;
	weapon.flashUntil := 0;
	weapon.reloadUntil := 0;
	weapon.selected := DoomInventory.Pistol;
	weapon.prepared := {DoomInventory.Pistol};
	FOR i := 0 TO DoomInventory.WeaponKinds - 1 DO
		weapon.loaded[i] := 0
	END;
	ammo := DoomConfig.values.combat.weapons[DoomInventory.Pistol].ammo;
	weapon.loaded[DoomInventory.Pistol] := MIN(player.ammo[ammo], DoomConfig.values.combat.weapons[DoomInventory.Pistol].magazine)
END Reset;

(* Reserve counts loaded rounds inside inventory totals so shared ammunition cannot be created by switching. *)
PROCEDURE Reserve*(CONST weapon: Weapon; CONST player: DoomInventory.State; ammo: SIGNED32): SIGNED32;
VAR i, rounds: SIGNED32;
BEGIN
	ASSERT((ammo >= 0) & (ammo < DoomInventory.AmmoKinds));
	rounds := player.ammo[ammo];
	FOR i := 0 TO DoomInventory.WeaponKinds - 1 DO
		IF DoomConfig.values.combat.weapons[i].ammo = ammo THEN
			DEC(rounds, weapon.loaded[i])
		END
	END;
	RETURN MAX(0, rounds)
END Reserve;

PROCEDURE Change(VAR weapon: Weapon; CONST player: DoomInventory.State; choice: SIGNED32);
VAR rules: DoomConfig.WeaponSettings;
BEGIN
	IF (choice < 0) OR ~(choice IN player.weapons) OR (player.health <= 0) OR (choice = weapon.selected) THEN
		RETURN
	END;
	weapon.selected := choice;
	weapon.reloadUntil := 0;
	weapon.flashUntil := 0;
	rules := DoomConfig.values.combat.weapons[choice];
	IF ~(choice IN weapon.prepared) THEN
		IF rules.ammo >= 0 THEN
			weapon.loaded[choice] := MIN(rules.magazine, Reserve(weapon, player, rules.ammo))
		END;
		INCL(weapon.prepared, choice)
	END
END Change;

PROCEDURE Select*(VAR weapon: Weapon; CONST player: DoomInventory.State; slot: SIGNED32);
VAR choice, alternate: SIGNED32;
BEGIN
	choice := -1;
	alternate := -1;
	CASE slot OF
	1:
		choice := DoomInventory.Chainsaw;
		alternate := DoomInventory.Fist
	| 2:
		choice := DoomInventory.Pistol
	| 3:
		choice := DoomInventory.SuperShotgun;
		alternate := DoomInventory.Shotgun
	| 4:
		choice := DoomInventory.Chaingun
	| 5:
		choice := DoomInventory.Launcher
	| 6:
		choice := DoomInventory.Plasma
	| 7:
		choice := DoomInventory.Bfg
	ELSE
		RETURN
	END;
	IF (alternate >= 0) & (~(choice IN player.weapons) OR (choice = weapon.selected)) THEN
		choice := alternate
	END;
	Change(weapon, player, choice)
END Select;

PROCEDURE Cycle*(VAR weapon: Weapon; CONST player: DoomInventory.State; steps: SIGNED32);
VAR direction, step, i, choice: SIGNED32;
BEGIN
	direction := 1;
	IF steps < 0 THEN
		direction := -1
	END;
	FOR step := 1 TO ABS(MAX(-DoomConfig.MaximumWheelSteps, MIN(DoomConfig.MaximumWheelSteps, steps))) DO
		choice := weapon.selected;
		i := 0;
		REPEAT
			choice := (choice + direction) MOD DoomInventory.WeaponKinds;
			INC(i)
		UNTIL (choice IN player.weapons) OR (i = DoomInventory.WeaponKinds);
		Change(weapon, player, choice)
	END
END Cycle;

PROCEDURE Reload*(tick: SIGNED64; VAR weapon: Weapon; CONST player: DoomInventory.State);
VAR rules: DoomConfig.WeaponSettings;
BEGIN
	rules := DoomConfig.values.combat.weapons[weapon.selected];
	IF (player.health > 0) & (weapon.selected IN player.weapons) & (rules.ammo >= 0) &
		(weapon.reloadUntil = 0) & (weapon.loaded[weapon.selected] < rules.magazine) &
		(Reserve(weapon, player, rules.ammo) > 0) THEN
		weapon.reloadUntil := tick + rules.reloadTicks
	END
END Reload;

(* StepAim completes reloads before firing the selected weapon along the visible aim direction. *)
PROCEDURE StepAim*(tick: SIGNED64; held: BOOLEAN; VAR weapon: Weapon;
	world: GameGeometry.World; scene: DoomSprites.Scene; x, y, angle, eye, slope: FLOAT64;
	VAR player: DoomInventory.State): DoomSprites.Scene;
VAR rules: DoomConfig.WeaponSettings;
	i: SIGNED32;
	direction: FLOAT64;
BEGIN
	IF player.health <= 0 THEN
		RETURN scene
	END;
	rules := DoomConfig.values.combat.weapons[weapon.selected];
	IF weapon.reloadUntil > 0 THEN
		IF tick < weapon.reloadUntil THEN
			RETURN scene
		END;
		IF rules.ammo >= 0 THEN
			INC(weapon.loaded[weapon.selected], MIN(rules.magazine - weapon.loaded[weapon.selected], Reserve(weapon, player, rules.ammo)))
		END;
		weapon.reloadUntil := 0
	END;
	IF ~held OR (tick < weapon.nextShot) OR ~(weapon.selected IN player.weapons) THEN
		RETURN scene
	END;
	IF rules.ammo >= 0 THEN
		IF (player.ammo[rules.ammo] < rules.ammoCost) OR (weapon.loaded[weapon.selected] < rules.ammoCost) THEN
			RETURN scene
		END;
		DEC(player.ammo[rules.ammo], rules.ammoCost);
		DEC(weapon.loaded[weapon.selected], rules.ammoCost)
	END;
	weapon.nextShot := tick + rules.cooldown;
	weapon.flashUntil := tick + rules.flashTicks;
	IF scene = NIL THEN
		RETURN scene
	END;
	IF rules.projectile # NIL THEN
		RETURN scene.PlayerShot(weapon.selected, x, y, eye, angle, slope)
	END;
	FOR i := 0 TO rules.pellets - 1 DO
		direction := angle;
		IF rules.pellets > 1 THEN
			direction := angle + rules.spread * (2.0 * i / (rules.pellets - 1) - 1)
		END;
		scene := scene.ShootAim(world, x, y, direction, eye, slope, rules.range, rules.damage)
	END;
	RETURN scene
END StepAim;

PROCEDURE Step*(tick: SIGNED64; held: BOOLEAN; VAR weapon: Weapon;
	world: GameGeometry.World; scene: DoomSprites.Scene; x, y, angle, eye: FLOAT64;
	VAR player: DoomInventory.State): DoomSprites.Scene;
BEGIN
	RETURN StepAim(tick, held, weapon, world, scene, x, y, angle, eye, 0, player)
END Step;

PROCEDURE DrawStatus*(CONST weapon: Weapon; CONST player: DoomInventory.State; frame: GameSurface.Frame);
VAR rules: DoomConfig.WeaponSettings;
	text, number: ARRAY 64 OF CHAR;
BEGIN
	rules := DoomConfig.values.combat.weapons[weapon.selected];
	COPY(rules.label, text);
	IF weapon.reloadUntil > 0 THEN
		Strings.Append(text, " RELOADING")
	ELSIF rules.ammo >= 0 THEN
		Strings.IntToStr(weapon.loaded[weapon.selected], number);
		Strings.Append(text, " ");
		Strings.Append(text, number);
		Strings.Append(text, " LOADED ");
		Strings.IntToStr(Reserve(weapon, player, rules.ammo), number);
		Strings.Append(text, number);
		Strings.Append(text, " RESERVE")
	END;
	GameText.Draw(frame, DoomConfig.values.hud.margin,
		frame.height - DoomConfig.values.hud.height - DoomConfig.values.hud.margin - 5, DoomConfig.values.hud.value, text)
END DrawStatus;

PROCEDURE DrawAim*(frame: GameSurface.Frame; flashed: BOOLEAN);
VAR x, y, i, color: SIGNED32;
BEGIN
	x := frame.width DIV 2;
	y := frame.height DIV 2;
	IF (x < DoomConfig.values.combat.aimRadius) OR (y < DoomConfig.values.combat.aimRadius) THEN
		RETURN
	END;
	color := DoomConfig.values.combat.aimColor;
	IF flashed THEN
		color := DoomConfig.values.combat.fireColor
	END;
	FOR i := DoomConfig.values.combat.aimGap TO DoomConfig.values.combat.aimRadius DO
		frame.Span(x - i, y, y, color);
		frame.Span(x + i, y, y, color);
		frame.Span(x, y - i, y - i, color);
		frame.Span(x, y + i, y + i, color)
	END
END DrawAim;

END DoomCombat.
