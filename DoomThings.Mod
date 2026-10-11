MODULE DoomThings;

CONST BlueCard* = 5;
	YellowCard* = 6;
	Backpack* = 8;
	RedCard* = 13;
	CellPack* = 17;
	RedSkull* = 38;
	YellowSkull* = 39;
	BlueSkull* = 40;
	SuperShotgun* = 82;
	Megasphere* = 83;
	Shotgun* = 2001;
	Chaingun* = 2002;
	Launcher* = 2003;
	Plasma* = 2004;
	Chainsaw* = 2005;
	Bfg* = 2006;
	Clip* = 2007;
	Shells* = 2008;
	Rocket* = 2010;
	Stimpack* = 2011;
	Medikit* = 2012;
	SoulSphere* = 2013;
	HealthBonus* = 2014;
	ArmorBonus* = 2015;
	GreenArmor* = 2018;
	BlueArmor* = 2019;
	RocketBox* = 2046;
	Cells* = 2047;
	BulletBox* = 2048;
	ShellBox* = 2049;

TYPE Info* = RECORD
	kind*: SIGNED32;
	name*: ARRAY 6 OF CHAR;
	fullbright*, ceiling*: BOOLEAN;
	height*, radius*: FLOAT64
END;

Definitions* = POINTER TO ARRAY OF Info;

(* Lookup resolves validated game data while keeping WAD identifiers in code. *)
PROCEDURE Lookup*(CONST definitions: ARRAY OF Info; kind: SIGNED32; VAR info: Info): BOOLEAN;
VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO SIGNED32(LEN(definitions)) - 1 DO
		IF definitions[i].kind = kind THEN
			info := definitions[i];
			RETURN TRUE
		END
	END;
	RETURN FALSE
END Lookup;

END DoomThings.
