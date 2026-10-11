MODULE DoomCombat;

IMPORT DoomConfig, DoomInventory, DoomSprites, GameGeometry, GameSurface;

TYPE Weapon* = RECORD
	nextShot*, flashUntil*: SIGNED64
END;

(* Step consumes ammunition only when a live player's owned pistol can fire. *)
PROCEDURE Step*(tick: SIGNED64; held: BOOLEAN; VAR weapon: Weapon;
	world: GameGeometry.World; scene: DoomSprites.Scene; x, y, angle, eye: FLOAT64;
	VAR player: DoomInventory.State): DoomSprites.Scene;
BEGIN
	IF ~held OR (tick < weapon.nextShot) OR (player.health <= 0) OR
		~(DoomInventory.Pistol IN player.weapons) OR
		(player.ammo[DoomInventory.Bullets] < DoomConfig.values.combat.ammoCost) THEN
		RETURN scene
	END;
	DEC(player.ammo[DoomInventory.Bullets], DoomConfig.values.combat.ammoCost);
	weapon.nextShot := tick + DoomConfig.values.combat.cooldown;
	weapon.flashUntil := tick + DoomConfig.values.combat.flashTicks;
	IF scene = NIL THEN
		RETURN scene
	END;
	(* shortcut: pistol damage is fixed and aim is horizontal; add spread/autoaim with weapon states. *)
	RETURN scene.Shoot(world, x, y, angle, eye, DoomConfig.values.combat.range, DoomConfig.values.combat.damage)
END Step;

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
