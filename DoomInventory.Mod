MODULE DoomInventory;

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

TYPE State* = RECORD
	health*, armor*, armorType*, pickups*: SIGNED32;
	(* shortcut: key hints persist until use or matching pickup; add expiry with timed player messages. *)
	neededKey*: SIGNED32;
	ammo*, maximum*: ARRAY 4 OF SIGNED32;
	weapons*, keys*: SET;
	backpack*: BOOLEAN
END;

PROCEDURE Reset*(VAR player: State);
VAR i: SIGNED32;
BEGIN
	player.health := 100;
	player.armor := 0;
	player.armorType := 0;
	player.pickups := 0;
	player.weapons := {Fist, Pistol};
	player.keys := {};
	player.neededKey := -1;
	player.backpack := FALSE;
	FOR i := 0 TO 3 DO
		player.ammo[i] := 0
	END;
	player.ammo[Bullets] := 50;
	player.maximum[Bullets] := 200;
	player.maximum[Shells] := 50;
	player.maximum[Cells] := 300;
	player.maximum[Rockets] := 50
END Reset;

PROCEDURE Supported*(kind: SIGNED32): BOOLEAN;
BEGIN
	CASE kind OF
	5, 6, 8, 13, 17, 38..40, 82, 83, 2001..2008, 2010..2015, 2018, 2019, 2046..2049:
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
	IF player.health >= 100 THEN
		RETURN FALSE
	END;
	player.health := MIN(100, player.health + amount);
	RETURN TRUE
END Health;

PROCEDURE Armor(VAR player: State; kind: SIGNED32): BOOLEAN;
BEGIN
	IF player.armor >= kind * 100 THEN
		RETURN FALSE
	END;
	player.armor := kind * 100;
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
	2014:
		player.health := MIN(200, player.health + 1)
	| 2015:
		player.armor := MIN(200, player.armor + 1);
		IF player.armorType = 0 THEN
			player.armorType := 1
		END
	| 2013:
		player.health := MIN(200, player.health + 100)
	| 83:
		player.health := 200;
		taken := Armor(player, 2)
	| 2011, 2012:
		i := 10;
		IF kind = 2012 THEN
			i := 25
		END;
		IF ~Health(player, i) THEN
			RETURN FALSE
		END
	| 2018, 2019:
		IF ~Armor(player, kind - 2017) THEN
			RETURN FALSE
		END
	| 2007, 2048:
		i := 10;
		IF kind = 2048 THEN
			i := 50
		END;
		IF ~Ammo(player, Bullets, i) THEN
			RETURN FALSE
		END
	| 2008, 2049:
		i := 4;
		IF kind = 2049 THEN
			i := 20
		END;
		IF ~Ammo(player, Shells, i) THEN
			RETURN FALSE
		END
	| 2047, 17:
		i := 20;
		IF kind = 17 THEN
			i := 100
		END;
		IF ~Ammo(player, Cells, i) THEN
			RETURN FALSE
		END
	| 2010, 2046:
		i := 1;
		IF kind = 2046 THEN
			i := 5
		END;
		IF ~Ammo(player, Rockets, i) THEN
			RETURN FALSE
		END
	| 5:
		INCL(player.keys, BlueCard)
	| 6:
		INCL(player.keys, YellowCard)
	| 13:
		INCL(player.keys, RedCard)
	| 40:
		INCL(player.keys, BlueSkull)
	| 39:
		INCL(player.keys, YellowSkull)
	| 38:
		INCL(player.keys, RedSkull)
	| 8:
		IF ~player.backpack THEN
			FOR i := 0 TO 3 DO
				player.maximum[i] := player.maximum[i] * 2
			END;
			player.backpack := TRUE
		END;
		taken := Ammo(player, Bullets, 10);
		taken := Ammo(player, Shells, 4);
		taken := Ammo(player, Cells, 20);
		taken := Ammo(player, Rockets, 1)
	| 2001, 82:
		i := Shotgun;
		IF kind = 82 THEN
			i := SuperShotgun
		END;
		IF ~Weapon(player, i, Shells, 8) THEN
			RETURN FALSE
		END
	| 2002:
		IF ~Weapon(player, Chaingun, Bullets, 20) THEN
			RETURN FALSE
		END
	| 2003:
		IF ~Weapon(player, Launcher, Rockets, 2) THEN
			RETURN FALSE
		END
	| 2004, 2006:
		i := Plasma;
		IF kind = 2006 THEN
			i := Bfg
		END;
		IF ~Weapon(player, i, Cells, 40) THEN
			RETURN FALSE
		END
	| 2005:
		IF ~Weapon(player, Chainsaw, -1, 0) THEN
			RETURN FALSE
		END
	ELSE
		(* shortcut: powerups remain visible until combat and environment effects are implemented. *)
		RETURN FALSE
	END;
	IF (player.neededKey >= 0) &
		((player.neededKey IN player.keys) OR (player.neededKey + 3 IN player.keys)) THEN
		player.neededKey := -1
	END;
	INC(player.pickups);
	RETURN TRUE
END Give;

END DoomInventory.
