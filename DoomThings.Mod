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
	name*: ARRAY 6 OF CHAR;
	fullbright*, ceiling*: BOOLEAN;
	height*: SIGNED32;
	radius*: SIGNED32 (* Solid footprint radius; zero leaves pickups and corpses passable. *)
END;

(* Lookup supplies classic spawn frames and solid footprints for compatible map objects. *)
PROCEDURE Lookup*(kind: SIGNED32; VAR info: Info): BOOLEAN;
BEGIN
	info.fullbright := FALSE;
	info.ceiling := FALSE;
	info.height := 0;
	info.radius := 0;
	CASE kind OF
	BlueCard:
		COPY("BKEYA", info.name)
	| YellowCard:
		COPY("YKEYA", info.name)
	| 7:
		COPY("SPIDA", info.name)
	| Backpack:
		COPY("BPAKA", info.name)
	| 9:
		COPY("SPOSA", info.name)
	| 10, 12:
		COPY("PLAYW", info.name)
	| RedCard:
		COPY("RKEYA", info.name)
	| 15:
		COPY("PLAYN", info.name)
	| 16:
		COPY("CYBRA", info.name)
	| CellPack:
		COPY("CELPA", info.name)
	| 18:
		COPY("POSSL", info.name)
	| 19:
		COPY("SPOSL", info.name)
	| 20:
		COPY("TROOM", info.name)
	| 21:
		COPY("SARGN", info.name)
	| 22:
		COPY("HEADL", info.name)
	| 23:
		COPY("SKULK", info.name)
	| 24:
		COPY("POL5A", info.name)
	| 25:
		COPY("POL1A", info.name)
	| 26:
		COPY("POL6A", info.name)
	| 27:
		COPY("POL4A", info.name)
	| 28:
		COPY("POL2A", info.name)
	| 29:
		COPY("POL3A", info.name)
	| 30:
		COPY("COL1A", info.name)
	| 31:
		COPY("COL2A", info.name)
	| 32:
		COPY("COL3A", info.name)
	| 33:
		COPY("COL4A", info.name)
	| 34:
		COPY("CANDA", info.name)
	| 35:
		COPY("CBRAA", info.name)
	| 36:
		COPY("COL5A", info.name)
	| 37:
		COPY("COL6A", info.name)
	| RedSkull:
		COPY("RSKUA", info.name)
	| YellowSkull:
		COPY("YSKUA", info.name)
	| BlueSkull:
		COPY("BSKUA", info.name)
	| 41:
		COPY("CEYEA", info.name)
	| 42:
		COPY("FSKUA", info.name)
	| 43:
		COPY("TRE1A", info.name)
	| 44:
		COPY("TBLUA", info.name)
	| 45:
		COPY("TGRNA", info.name)
	| 46:
		COPY("TREDA", info.name)
	| 47:
		COPY("SMITA", info.name)
	| 48:
		COPY("ELECA", info.name)
	| 49, 63:
		COPY("GOR1A", info.name)
	| 50, 59:
		COPY("GOR2A", info.name)
	| 51, 61:
		COPY("GOR3A", info.name)
	| 52, 60:
		COPY("GOR4A", info.name)
	| 53, 62:
		COPY("GOR5A", info.name)
	| 54:
		COPY("TRE2A", info.name)
	| 55:
		COPY("SMBTA", info.name)
	| 56:
		COPY("SMGTA", info.name)
	| 57:
		COPY("SMRTA", info.name)
	| 58, 3002:
		COPY("SARGA", info.name)
	| 64:
		COPY("VILEA", info.name)
	| 65:
		COPY("CPOSA", info.name)
	| 66:
		COPY("SKELA", info.name)
	| 67:
		COPY("FATTA", info.name)
	| 68:
		COPY("BSPIA", info.name)
	| 69:
		COPY("BOS2A", info.name)
	| 70:
		COPY("FCANA", info.name)
	| 71:
		COPY("PAINA", info.name)
	| 72:
		COPY("KEENA", info.name)
	| 73:
		COPY("HDB1A", info.name)
	| 74:
		COPY("HDB2A", info.name)
	| 75:
		COPY("HDB3A", info.name)
	| 76:
		COPY("HDB4A", info.name)
	| 77:
		COPY("HDB5A", info.name)
	| 78:
		COPY("HDB6A", info.name)
	| 79:
		COPY("POB1A", info.name)
	| 80:
		COPY("POB2A", info.name)
	| 81:
		COPY("BRS1A", info.name)
	| SuperShotgun:
		COPY("SGN2A", info.name)
	| Megasphere:
		COPY("MEGAA", info.name)
	| 84, 89:
		COPY("SSWVA", info.name)
	| 85:
		COPY("TLMPA", info.name)
	| 86:
		COPY("TLP2A", info.name)
	| 88:
		COPY("BBRNA", info.name)
	| Shotgun:
		COPY("SHOTA", info.name)
	| Chaingun:
		COPY("MGUNA", info.name)
	| Launcher:
		COPY("LAUNA", info.name)
	| Plasma:
		COPY("PLASA", info.name)
	| Chainsaw:
		COPY("CSAWA", info.name)
	| Bfg:
		COPY("BFUGA", info.name)
	| Clip:
		COPY("CLIPA", info.name)
	| Shells:
		COPY("SHELA", info.name)
	| Rocket:
		COPY("ROCKA", info.name)
	| Stimpack:
		COPY("STIMA", info.name)
	| Medikit:
		COPY("MEDIA", info.name)
	| SoulSphere:
		COPY("SOULA", info.name)
	| HealthBonus:
		COPY("BON1A", info.name)
	| ArmorBonus:
		COPY("BON2A", info.name)
	| GreenArmor:
		COPY("ARM1A", info.name)
	| BlueArmor:
		COPY("ARM2A", info.name)
	| 2022:
		COPY("PINVA", info.name)
	| 2023:
		COPY("PSTRA", info.name)
	| 2024:
		COPY("PINSA", info.name)
	| 2025:
		COPY("SUITA", info.name)
	| 2026:
		COPY("PMAPA", info.name)
	| 2028:
		COPY("COLUA", info.name)
	| 2035:
		COPY("BAR1A", info.name)
	| 2045:
		COPY("PVISA", info.name)
	| RocketBox:
		COPY("BROKA", info.name)
	| Cells:
		COPY("CELLA", info.name)
	| BulletBox:
		COPY("AMMOA", info.name)
	| ShellBox:
		COPY("SBOXA", info.name)
	| 3001:
		COPY("TROOA", info.name)
	| 3003:
		COPY("BOSSA", info.name)
	| 3004:
		COPY("POSSA", info.name)
	| 3005:
		COPY("HEADA", info.name)
	| 3006:
		COPY("SKULA", info.name)
	ELSE
		RETURN FALSE
	END;
	CASE kind OF
		29, 34, 35, 41, 42, 44, 45, 46, 55, 56, 57, 70, Megasphere, 85, 86, SoulSphere, 2022, 2023, 2024, 2025, 2026, 2028, 2045, 3006:
			info.fullbright := TRUE
	ELSE
	END;
	CASE kind OF
	53, 61, 62:
		info.ceiling := TRUE;
		info.height := 52
	| 75, 76, 77, 78:
		info.ceiling := TRUE;
		info.height := 64
	| 49, 52, 60, 63:
		info.ceiling := TRUE;
		info.height := 68
	| 72:
		info.ceiling := TRUE;
		info.height := 72
	| 50, 51, 59:
		info.ceiling := TRUE;
		info.height := 84
	| 73, 74:
		info.ceiling := TRUE;
		info.height := 88
	ELSE
	END;
	CASE kind OF
	2035:
		info.radius := 10
	| 25, 26, 27, 28, 29, 30, 31, 32, 33, 35, 36, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 55, 56, 57, 70, 72, 73, 74, 75, 76, 77, 78, 85, 86, 88, 2028, 3006:
		info.radius := 16
	| 9, 64, 65, 66, 84, 3001, 3004:
		info.radius := 20
	| 69, 3003:
		info.radius := 24
	| 58, 3002:
		info.radius := 30
	| 71, 3005:
		info.radius := 31
	| 54:
		info.radius := 32
	| 16:
		info.radius := 40
	| 67:
		info.radius := 48
	| 68:
		info.radius := 64
	| 7:
		info.radius := 128
	ELSE
	END;
	RETURN TRUE
END Lookup;

END DoomThings.
