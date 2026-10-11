MODULE DoomInventory;

IMPORT DoomConfig, DoomFormat, DoomThings;

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
	AmmoKinds* = DoomFormat.AmmoKinds;
	WeaponKinds* = DoomFormat.WeaponKinds;
	KeyColors* = DoomFormat.KeyColors;
	KeyKinds* = DoomFormat.KeyKinds;
	GreenArmorClass = 1;
	BlueArmorClass = 2;

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
	ASSERT(DoomConfig.loaded);
	player.health := DoomConfig.values.inventory.initialHealth;
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
	player.ammo[Bullets] := DoomConfig.values.inventory.initialBullets;
	player.maximum[Bullets] := DoomConfig.values.inventory.maximum[Bullets];
	player.maximum[Shells] := DoomConfig.values.inventory.maximum[Shells];
	player.maximum[Cells] := DoomConfig.values.inventory.maximum[Cells];
	player.maximum[Rockets] := DoomConfig.values.inventory.maximum[Rockets]
END Reset;

(* Hurt spends configured armor protection before reducing live-player health. *)
PROCEDURE Hurt*(VAR player: State; damage: SIGNED32);
VAR saved: SIGNED32;
BEGIN
	ASSERT(damage >= 0);
	IF player.health <= 0 THEN
		RETURN
	END;
	saved := 0;
	IF player.armorType = GreenArmorClass THEN
		saved := damage DIV DoomConfig.values.inventory.greenArmorDivisor
	ELSIF player.armorType = BlueArmorClass THEN
		saved := damage DIV DoomConfig.values.inventory.blueArmorDivisor
	END;
	saved := MIN(player.armor, saved);
	DEC(player.armor, saved);
	IF player.armor = 0 THEN
		player.armorType := 0
	END;
	player.health := MAX(0, player.health - damage + saved)
END Hurt;

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
	IF player.health >= DoomConfig.values.inventory.healthMaximum THEN
		RETURN FALSE
	END;
	player.health := MIN(DoomConfig.values.inventory.healthMaximum, player.health + amount);
	RETURN TRUE
END Health;

PROCEDURE Armor(VAR player: State; kind: SIGNED32): BOOLEAN;
BEGIN
	IF player.armor >= kind * DoomConfig.values.inventory.armorUnit THEN
		RETURN FALSE
	END;
	player.armor := kind * DoomConfig.values.inventory.armorUnit;
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
		player.health := MIN(DoomConfig.values.inventory.bonusHealthMaximum, player.health + DoomConfig.values.inventory.healthBonus)
	| DoomThings.ArmorBonus:
		player.armor := MIN(DoomConfig.values.inventory.bonusArmorMaximum, player.armor + DoomConfig.values.inventory.armorBonus);
		IF player.armorType = 0 THEN
			player.armorType := GreenArmorClass
		END
	| DoomThings.SoulSphere:
		player.health := MIN(DoomConfig.values.inventory.bonusHealthMaximum, player.health + DoomConfig.values.inventory.soulSphere)
	| DoomThings.Megasphere:
		player.health := DoomConfig.values.inventory.bonusHealthMaximum;
		taken := Armor(player, BlueArmorClass)
	| DoomThings.Stimpack, DoomThings.Medikit:
		i := DoomConfig.values.inventory.stimpack;
		IF kind = DoomThings.Medikit THEN
			i := DoomConfig.values.inventory.medikit
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
		i := DoomConfig.values.inventory.pickup[Bullets];
		IF kind = DoomThings.BulletBox THEN
			i := DoomConfig.values.inventory.pickup[Bullets] * DoomConfig.values.inventory.boxMultiplier
		END;
		IF ~Ammo(player, Bullets, i) THEN
			RETURN FALSE
		END
	| DoomThings.Shells, DoomThings.ShellBox:
		i := DoomConfig.values.inventory.pickup[Shells];
		IF kind = DoomThings.ShellBox THEN
			i := DoomConfig.values.inventory.pickup[Shells] * DoomConfig.values.inventory.boxMultiplier
		END;
		IF ~Ammo(player, Shells, i) THEN
			RETURN FALSE
		END
	| DoomThings.Cells, DoomThings.CellPack:
		i := DoomConfig.values.inventory.pickup[Cells];
		IF kind = DoomThings.CellPack THEN
			i := DoomConfig.values.inventory.pickup[Cells] * DoomConfig.values.inventory.boxMultiplier
		END;
		IF ~Ammo(player, Cells, i) THEN
			RETURN FALSE
		END
	| DoomThings.Rocket, DoomThings.RocketBox:
		i := DoomConfig.values.inventory.pickup[Rockets];
		IF kind = DoomThings.RocketBox THEN
			i := DoomConfig.values.inventory.pickup[Rockets] * DoomConfig.values.inventory.boxMultiplier
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
				player.maximum[i] := player.maximum[i] * DoomConfig.values.inventory.backpackMultiplier
			END;
			player.backpack := TRUE
		END;
		taken := Ammo(player, Bullets, DoomConfig.values.inventory.pickup[Bullets]);
		taken := Ammo(player, Shells, DoomConfig.values.inventory.pickup[Shells]);
		taken := Ammo(player, Cells, DoomConfig.values.inventory.pickup[Cells]);
		taken := Ammo(player, Rockets, DoomConfig.values.inventory.pickup[Rockets])
	| DoomThings.Shotgun, DoomThings.SuperShotgun:
		i := Shotgun;
		IF kind = DoomThings.SuperShotgun THEN
			i := SuperShotgun
		END;
		IF ~Weapon(player, i, Shells, DoomConfig.values.inventory.pickup[Shells] * DoomConfig.values.inventory.weaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Chaingun:
		IF ~Weapon(player, Chaingun, Bullets, DoomConfig.values.inventory.pickup[Bullets] * DoomConfig.values.inventory.weaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Launcher:
		IF ~Weapon(player, Launcher, Rockets, DoomConfig.values.inventory.pickup[Rockets] * DoomConfig.values.inventory.weaponAmmoMultiplier) THEN
			RETURN FALSE
		END
	| DoomThings.Plasma, DoomThings.Bfg:
		i := Plasma;
		IF kind = DoomThings.Bfg THEN
			i := Bfg
		END;
		IF ~Weapon(player, i, Cells, DoomConfig.values.inventory.pickup[Cells] * DoomConfig.values.inventory.weaponAmmoMultiplier) THEN
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
