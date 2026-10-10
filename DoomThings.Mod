MODULE DoomThings;

TYPE Info* = RECORD
	name*: ARRAY 6 OF CHAR;
	fullbright*, ceiling*: BOOLEAN;
	height*: SIGNED32
END;

(* Lookup supplies classic spawn-frame facts; actor behavior remains separate. *)
PROCEDURE Lookup*(kind: SIGNED32; VAR info: Info): BOOLEAN;
BEGIN
	info.fullbright := FALSE;
	info.ceiling := FALSE;
	info.height := 0;
	CASE kind OF
	5:
		COPY("BKEYA", info.name)
	| 6:
		COPY("YKEYA", info.name)
	| 7:
		COPY("SPIDA", info.name)
	| 8:
		COPY("BPAKA", info.name)
	| 9:
		COPY("SPOSA", info.name)
	| 10, 12:
		COPY("PLAYW", info.name)
	| 13:
		COPY("RKEYA", info.name)
	| 15:
		COPY("PLAYN", info.name)
	| 16:
		COPY("CYBRA", info.name)
	| 17:
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
	| 38:
		COPY("RSKUA", info.name)
	| 39:
		COPY("YSKUA", info.name)
	| 40:
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
	| 82:
		COPY("SGN2A", info.name)
	| 83:
		COPY("MEGAA", info.name)
	| 84, 89:
		COPY("SSWVA", info.name)
	| 85:
		COPY("TLMPA", info.name)
	| 86:
		COPY("TLP2A", info.name)
	| 88:
		COPY("BBRNA", info.name)
	| 2001:
		COPY("SHOTA", info.name)
	| 2002:
		COPY("MGUNA", info.name)
	| 2003:
		COPY("LAUNA", info.name)
	| 2004:
		COPY("PLASA", info.name)
	| 2005:
		COPY("CSAWA", info.name)
	| 2006:
		COPY("BFUGA", info.name)
	| 2007:
		COPY("CLIPA", info.name)
	| 2008:
		COPY("SHELA", info.name)
	| 2010:
		COPY("ROCKA", info.name)
	| 2011:
		COPY("STIMA", info.name)
	| 2012:
		COPY("MEDIA", info.name)
	| 2013:
		COPY("SOULA", info.name)
	| 2014:
		COPY("BON1A", info.name)
	| 2015:
		COPY("BON2A", info.name)
	| 2018:
		COPY("ARM1A", info.name)
	| 2019:
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
	| 2046:
		COPY("BROKA", info.name)
	| 2047:
		COPY("CELLA", info.name)
	| 2048:
		COPY("AMMOA", info.name)
	| 2049:
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
		29, 34, 35, 41, 42, 44, 45, 46, 55, 56, 57, 70, 83, 85, 86, 2013, 2022, 2023, 2024, 2025, 2026, 2028, 2045, 3006:
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
	RETURN TRUE
END Lookup;

END DoomThings.
