MODULE DoomInventory;

IMPORT DoomThings;

CONST Bullets* = 0;
	Shells* = 1;
	Cells* = 2;
	Rockets* = 3;
	Fist* = 0;
	Pistol* = 1;
	Shotgun* = 2;
	Chaingun* = 3;
	Launcher* = 4;
	Plasma* = 5;
	Bfg* = 6;
	Chainsaw* = 7;
	SuperShotgun* = 8;
	BlueCard* = 0;
	YellowCard* = 1;
	RedCard* = 2;
	BlueSkull* = 3;
	YellowSkull* = 4;
	RedSkull* = 5;
	AmmoKinds* = 4;
	WeaponKinds* = 9;
	KeyColors* = 3;
	KeyKinds* = KeyColors * 2;
	HealthMaximum = 100;
	BonusHealthMaximum = 200;
	ArmorUnit = 100;
	GreenArmorClass = 1;
	BlueArmorClass = 2;
	BonusArmorMaximum = 200;
	InitialBullets = 50;
	MaximumBullets = 200;
	MaximumShells = 50;
	MaximumCells = 300;
	MaximumRockets = 50;
	ClipBullets = 10;
	ShellPickup = 4;
	CellPickup = 20;
	RocketPickup = 1;
	BoxMultiplier = 5;
	WeaponAmmoMultiplier = 2;
	BackpackCapacityMultiplier = 2;
	StimpackHealth = 10;
	MedikitHealth = 25;
	SoulSphereHealth = 100;

TYPE State* = RECORD
	health*, armor*, armorType*, pickups*: SIGNED32;
	(* shortcut: key hints persist until use or matching pickup; add expiry with timed player messages. *)
	neededKey*: SIGNED32;
	ammo*, maximum*: ARRAY AmmoKinds OF SIGNED32;
	weapons*, keys*: SET;
	backpack*: BOOLEAN
END;

PROCEDURE Reset*(VAR player: State);
VAR i: SIGNED32;
BEGIN
	player.health := HealthMaximum;
	player.armor := 0;
	player.armorType := 0;
	player.pickups := 0;
	player.weapons := {Fist, Pistol};
	player.keys := {};
	player.neededKey := -1;
	player.backpack := FALSE;
	FOR i := 0 TO AmmoKinds - 1 DO
		player.ammo[i] := 0
	END;
	player.ammo[Bullets] := InitialBullets;
	player.maximum[Bullets] := MaximumBullets;
	player.maximum[Shells] := MaximumShells;
	player.maximum[Cells] := MaximumCells;
	player.maximum[Rockets] := MaximumRockets
END Reset;

PROCEDURE Supported*(kind: SIGNED32): BOOLEAN;
BEGIN
	CASE kind OF
	DoomThings.BlueCard, DoomThings.YellowCard, DoomThings.Backpack, DoomThings.RedCard, DoomThings.CellPack,
	DoomThings.RedSkull, DoomThings.YellowSkull, DoomThings.BlueSkull, DoomThings.SuperShotgun, DoomThings.Megasphere,
	DoomThings.Shotgun, DoomThings.Chaingun, DoomThings.Launcher, DoomThings.Plasma, DoomThings.Chainsaw,
	DoomThings.Bfg, DoomThings.Clip, DoomThings.Shells, DoomThings.Rocket, DoomThings.Stimpack,
	DoomThings.Medikit, DoomThings.SoulSphere, DoomThings.HealthBonus, DoomThings.ArmorBonus, DoomThings.GreenArmor,
	DoomThings.BlueArmor, DoomThings.RocketBox, DoomThings.Cells, DoomThings.BulletBox, DoomThings.ShellBox:
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END Supported;

PROCEDURE Ammo(VAR player: State; kind, amount: SIGNED32): BOOLEAN;
BEGIN
	IF player.ammo[kind] >= player.maximum[kind] THEN
		RETURN FALSE
	END;
	player.ammo[kind] := MIN(player.maximum[kind], player.ammo[kind] + amount);
	RETURN TRUE
END Ammo;

PROCEDURE Health(VAR player: State; amount: SIGNED32): BOOLEAN;
BEGIN
	IF player.health >= HealthMaximum THEN
		RETURN FALSE
	END;
	player.health := MIN(HealthMaximum, player.health + amount);
	RETURN TRUE
END Health;

PROCEDURE Armor(VAR player: State; kind: SIGNED32): BOOLEAN;
BEGIN
	IF player.armor >= kind * ArmorUnit THEN
		RETURN FALSE
	END;
	player.armor := kind * ArmorUnit;
	player.armorType := kind;
	RETURN TRUE
END Armor;

PROCEDURE Weapon(VAR player: State; kind, ammo, amount: SIGNED32): BOOLEAN;
VAR supplied: BOOLEAN;
BEGIN
	supplied := FALSE;
	IF ammo >= 0 THEN
		supplied := Ammo(player, ammo, amount)
	END;
	IF kind IN player.weapons THEN
		RETURN supplied
	END;
	INCL(player.weapons, kind);
	RETURN TRUE
END Weapon;

(* Give applies medium-skill placed-item effects without weapon selection or dropped loot. *)
PROCEDURE Give*(VAR player: State; kind: SIGNED32): BOOLEAN;
VAR i: SIGNED32;
	taken: BOOLEAN;
BEGIN
	IF player.health <= 0 THEN
		RETURN FALSE
	END;
	CASE kind OF
	DoomThings.HealthBonus:
		player.health := MIN(BonusHealthMaximum, player.health + 1)
	| DoomThings.ArmorBonus:
		player.armor := MIN(BonusArmorMaximum, player.armor + 1);
		IF player.armorType = 0 THEN
			player.armorType := GreenArmorClass
		END
	| DoomThings.SoulSphere:
		player.health := MIN(BonusHealthMaximum, player.health + SoulSphereHealth)
	| DoomThings.Megasphere:
		player.health := BonusHealthMaximum;
		taken := Armor(player, BlueArmorClass)
	| DoomThings.Stimpack, DoomThings.Medikit:
		i := StimpackHealth;
		IF kind = DoomThings.Medikit THEN
			i := MedikitHealth
		END;
		IF ~Health(player, i) THEN
			RETURN FALSE
		END
	| DoomThings.GreenArmor, DoomThings.BlueArmor:
		i := GreenArmorClass;
		IF kind = DoomThings.BlueArmor THEN
			i := BlueArmorClass
		END;
		IF ~Armor(player, i) THEN
			RETURN FALSE
		END
	| DoomThings.Clip, DoomThings.BulletBox:
		i := ClipBullets;
		IF kind = DoomThings.BulletBox THEN
			i := ClipBullets * BoxMultiplier
		END;
		IF ~Ammo(player, Bullets, i) THEN
			RETURN FALSE
		END
	| DoomThings.Shells, DoomThings.ShellBox:
		i := ShellPickup;
		IF kind = DoomThings.ShellBox THEN
			i := ShellPickup * BoxMultiplier
		END;
		IF ~Ammo(player, Shells, i) THEN
			RETURN FALSE
		END
	| DoomThings.Cells, DoomThings.CellPack:
		i := CellPickup;
		IF kind = DoomThings.CellPack THEN
			i := CellPickup * BoxMultiplier
		END;
		IF ~Ammo(player, Cells, i) THEN
			RETURN FALSE
		END
	| DoomThings.Rocket, DoomThings.RocketBox:
		i := RocketPickup;
		IF kind = DoomThings.RocketBox THEN
			i := RocketPickup * BoxMultiplier
		END;
		IF ~Ammo(player, Rockets, i) THEN
			RETURN FALSE
		END
	| DoomThings.BlueCard:
		INCL(player.keys, BlueCard)
	| DoomThings.YellowCard:
		INCL(player.keys, YellowCard)
	| DoomThings.RedCard:
		INCL(player.keys, RedCard)
	| DoomThings.BlueSkull:
		INCL(player.keys, BlueSkull)
	| DoomThings.YellowSkull:
		INCL(player.keys, YellowSkull)
	| DoomThings.RedSkull:
		INCL(player.keys, RedSkull)
	| DoomThings.Backpack:
		IF ~player.backpack THEN
			FOR i := 0 TO AmmoKinds - 1 DO
				player.maximum[i] := player.maximum[i] * BackpackCapacityMultiplier
			END;
			player.backpack := TRUE
		END;
		taken := Ammo(player, Bullets, ClipBullets);
		taken := Ammo(player, Shells, ShellPickup);
		taken := Ammo(player, Cells, CellPickup);
		taken := Ammo(player, Rockets, RocketPickup)
	| DoomThings.Shotgun, DoomThings.SuperShotgun:
		i := Shotgun;
		IF kind = DoomThings.SuperShotgun THEN
			i := SuperShotgun
		END;
		IF ~Weapon(player, i, Shells, ShellPickup * WeaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Chaingun:
		IF ~Weapon(player, Chaingun, Bullets, ClipBullets * WeaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Launcher:
		IF ~Weapon(player, Launcher, Rockets, RocketPickup * WeaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Plasma, DoomThings.Bfg:
		i := Plasma;
		IF kind = DoomThings.Bfg THEN
			i := Bfg
		END;
		IF ~Weapon(player, i, Cells, CellPickup * WeaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Chainsaw:
		IF ~Weapon(player, Chainsaw, -1, 0) THEN
			RETURN FALSE
		END
	ELSE
		(* shortcut: powerups remain visible until combat and environment effects are implemented. *)
		RETURN FALSE
	END;
	IF (player.neededKey >= 0) &
		((player.neededKey IN player.keys) OR (player.neededKey + KeyColors IN player.keys)) THEN
		player.neededKey := -1
	END;
	INC(player.pickups);
	RETURN TRUE
END Give;

END DoomInventory.
