MODULE DoomConfig;

IMPORT YAML, JSON, Strings, DoomFormat, DoomInventory;

CONST HudCharacterAdvance* = 4;
	HudGlyphHeight = 5;
	HudStatDigits* = 3;
	HudPickupDigits* = 5;
	DefaultFile* = "doom.yaml";
	DefaultTicksPerSecond* = 35;
	DefaultPlayerRadius* = 16.0 / DoomFormat.UnitsPerWorld;
	DefaultPlayerHeight* = 56.0 / DoomFormat.UnitsPerWorld;
	DefaultPlayerStep* = 24.0 / DoomFormat.UnitsPerWorld;
	DefaultPlayerEye* = 41.0 / DoomFormat.UnitsPerWorld;
	MinimumWidth = 320;
	MinimumHeight = 40;
	MaximumDimension = 4096;
	MaximumClockValue = 1000;

TYPE HudSettings* = RECORD
	height*, margin*, topRow*, bottomRow*, labelGap*: SIGNED32;
	armorX*, ammoX*, ammoSpacing*, weaponsX*, keysX*, keyStartX*, keySpacing*, hintX*: SIGNED32;
	background*, label*, value*, missingKey*, blueKey*, yellowKey*, redKey*: SIGNED32
END;

Settings* = RECORD
	width*, height*, ticksPerSecond*, maximumElapsed*, sleepMillis*, doorWait*: SIGNED32;
	playerRadius*, playerHeight*, playerStep*, playerEye*, moveSpeed*, turnSpeed*: FLOAT64;
	doorSpeed*, fastDoorSpeed*, useRange*, doorTopGap*: FLOAT64;
	hud*: HudSettings
END;

VAR values-: Settings;

(* Defaults preserves the original scene and classic player dimensions without requiring a file for library callers. *)
PROCEDURE Defaults*(VAR settings: Settings);
BEGIN
	settings.width := 320;
	settings.height := 200;
	settings.ticksPerSecond := DefaultTicksPerSecond;
	settings.maximumElapsed := 250;
	settings.sleepMillis := 5;
	settings.playerRadius := DefaultPlayerRadius;
	settings.playerHeight := DefaultPlayerHeight;
	settings.playerStep := DefaultPlayerStep;
	settings.playerEye := DefaultPlayerEye;
	settings.moveSpeed := 0.09;
	settings.turnSpeed := 0.065;
	settings.doorSpeed := 2.0 / DoomFormat.UnitsPerWorld;
	settings.fastDoorSpeed := 8.0 / DoomFormat.UnitsPerWorld;
	settings.doorWait := 150;
	settings.useRange := 1;
	settings.doorTopGap := 4.0 / DoomFormat.UnitsPerWorld;
	settings.hud.height := 20;
	settings.hud.margin := 4;
	settings.hud.topRow := 3;
	settings.hud.bottomRow := 13;
	settings.hud.labelGap := 4;
	settings.hud.armorX := 52;
	settings.hud.ammoX := 98;
	settings.hud.ammoSpacing := 40;
	settings.hud.weaponsX := 68;
	settings.hud.keysX := 120;
	settings.hud.keyStartX := 144;
	settings.hud.keySpacing := 12;
	settings.hud.hintX := 216;
	settings.hud.background := 012161CH;
	settings.hud.label := 0C0C8D0H;
	settings.hud.value := 0FFFFFFH;
	settings.hud.missingKey := 0353D48H;
	settings.hud.blueKey := 060A0FFH;
	settings.hud.yellowKey := 0FFE060H;
	settings.hud.redKey := 0FF6060H
END Defaults;

PROCEDURE Keys(object: JSON.Object; CONST allowed: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR member: JSON.Member;
	key: ARRAY 256 OF CHAR;
BEGIN
	member := object.members;
	WHILE member # NIL DO
		IF (Strings.Length(member.key^) > LEN(key) - 3) OR
			Strings.ContainsChar(member.key^, "|", FALSE) THEN
			COPY("Invalid configuration key", error);
			RETURN FALSE
		END;
		COPY("|", key);
		Strings.Append(key, member.key^);
		Strings.Append(key, "|");
		IF Strings.Pos(key, allowed) < 0 THEN
			COPY("Unknown configuration key: ", error);
			Strings.AppendX(error, member.key^);
			RETURN FALSE
		END;
		member := member.next
	END;
	RETURN TRUE
END Keys;

PROCEDURE Section(root: JSON.Object; CONST name, allowed: ARRAY OF CHAR;
	VAR object: JSON.Object; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
BEGIN
	value := root.Get(name);
	IF value = NIL THEN
		object := JSON.NewObject();
		RETURN TRUE
	END;
	IF ~(value IS JSON.Object) THEN
		COPY("Expected a mapping for ", error);
		Strings.AppendX(error, name);
		RETURN FALSE
	END;
	object := value(JSON.Object);
	RETURN Keys(object, allowed, error)
END Section;

PROCEDURE Real(object: JSON.Object; CONST key: ARRAY OF CHAR; minimum, maximum, scale: FLOAT64;
	VAR destination: FLOAT64; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	number: FLOAT64;
BEGIN
	value := object.Get(key);
	IF value = NIL THEN
		RETURN TRUE
	END;
	IF value IS JSON.Number THEN
		number := value(JSON.Number).value;
		IF (number >= minimum) & (number <= maximum) THEN
			destination := number / scale;
			RETURN TRUE
		END
	END;
	COPY("Expected a number in range for ", error);
	Strings.AppendX(error, key);
	RETURN FALSE
END Real;

PROCEDURE Integer(object: JSON.Object; CONST key: ARRAY OF CHAR; minimum, maximum: SIGNED32;
	VAR destination: SIGNED32; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR number: FLOAT64;
BEGIN
	number := destination;
	IF ~Real(object, key, minimum, maximum, 1, number, error) THEN
		RETURN FALSE
	END;
	IF number # ENTIER(number) THEN
		COPY("Expected an integer for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	destination := ENTIER(number);
	RETURN TRUE
END Integer;

PROCEDURE FieldFits(CONST settings: Settings; x: SIGNED32; CONST label: ARRAY OF CHAR; digits: SIGNED32): BOOLEAN;
BEGIN
	RETURN x + (Strings.Length(label) + digits) * HudCharacterAdvance + settings.hud.labelGap <= settings.width
END FieldFits;

(* Decode validates the complete schema before replacing settings, so failed reads preserve the caller's state. *)
PROCEDURE Decode(value: JSON.Value; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR root, object, hud: JSON.Object;
	candidate: Settings;
BEGIN
	error[0] := 0X;
	Defaults(candidate);
	IF ~(value IS JSON.Object) THEN
		COPY("Doom configuration must be a mapping", error);
		RETURN FALSE
	END;
	root := value(JSON.Object);
	IF ~Keys(root, "|video|simulation|player|doors|hud|", error) OR
		~Section(root, "video", "|width|height|", object, error) OR
		~Integer(object, "width", MinimumWidth, MaximumDimension, candidate.width, error) OR
		~Integer(object, "height", MinimumHeight, MaximumDimension, candidate.height, error) OR
		~Section(root, "simulation", "|ticks_per_second|maximum_elapsed_ms|sleep_ms|", object, error) OR
		~Integer(object, "ticks_per_second", 1, MaximumClockValue, candidate.ticksPerSecond, error) OR
		~Integer(object, "maximum_elapsed_ms", 1, MaximumClockValue, candidate.maximumElapsed, error) OR
		~Integer(object, "sleep_ms", 1, MaximumClockValue, candidate.sleepMillis, error) OR
		~Section(root, "player", "|radius|height|step|eye|move_per_tick|turn_per_tick|", object, error) OR
		~Real(object, "radius", 1, 128, DoomFormat.UnitsPerWorld, candidate.playerRadius, error) OR
		~Real(object, "height", 1, 256, DoomFormat.UnitsPerWorld, candidate.playerHeight, error) OR
		~Real(object, "step", 0, 128, DoomFormat.UnitsPerWorld, candidate.playerStep, error) OR
		~Real(object, "eye", 0, 256, DoomFormat.UnitsPerWorld, candidate.playerEye, error) OR
		~Real(object, "move_per_tick", 0, 64, DoomFormat.UnitsPerWorld, candidate.moveSpeed, error) OR
		~Real(object, "turn_per_tick", 0, 1, 1, candidate.turnSpeed, error) OR
		~Section(root, "doors", "|speed_per_tick|fast_speed_per_tick|wait_ticks|use_range|top_gap|", object, error) OR
		~Real(object, "speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.doorSpeed, error) OR
		~Real(object, "fast_speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.fastDoorSpeed, error) OR
		~Integer(object, "wait_ticks", 1, MAX(SIGNED32), candidate.doorWait, error) OR
		~Real(object, "use_range", 1, 1024, DoomFormat.UnitsPerWorld, candidate.useRange, error) OR
		~Real(object, "top_gap", 0, 128, DoomFormat.UnitsPerWorld, candidate.doorTopGap, error) THEN
		RETURN FALSE
	END;
	IF ~Section(root, "hud", "|height|margin|top_row|bottom_row|label_gap|armor_x|ammo_x|ammo_spacing|weapons_x|keys_x|key_start_x|key_spacing|hint_x|colors|", hud, error) OR
		~Integer(hud, "height", 5, MaximumDimension, candidate.hud.height, error) OR
		~Integer(hud, "margin", 0, MaximumDimension, candidate.hud.margin, error) OR
		~Integer(hud, "top_row", 0, MaximumDimension, candidate.hud.topRow, error) OR
		~Integer(hud, "bottom_row", 0, MaximumDimension, candidate.hud.bottomRow, error) OR
		~Integer(hud, "label_gap", 0, 64, candidate.hud.labelGap, error) OR
		~Integer(hud, "armor_x", 0, MaximumDimension, candidate.hud.armorX, error) OR
		~Integer(hud, "ammo_x", 0, MaximumDimension, candidate.hud.ammoX, error) OR
		~Integer(hud, "ammo_spacing", 1, MaximumDimension, candidate.hud.ammoSpacing, error) OR
		~Integer(hud, "weapons_x", 0, MaximumDimension, candidate.hud.weaponsX, error) OR
		~Integer(hud, "keys_x", 0, MaximumDimension, candidate.hud.keysX, error) OR
		~Integer(hud, "key_start_x", 0, MaximumDimension, candidate.hud.keyStartX, error) OR
		~Integer(hud, "key_spacing", 4, MaximumDimension, candidate.hud.keySpacing, error) OR
		~Integer(hud, "hint_x", 0, MaximumDimension, candidate.hud.hintX, error) OR
		~Section(hud, "colors", "|background|label|value|missing_key|blue_key|yellow_key|red_key|", object, error) OR
		~Integer(object, "background", 0, 0FFFFFFH, candidate.hud.background, error) OR
		~Integer(object, "label", 0, 0FFFFFFH, candidate.hud.label, error) OR
		~Integer(object, "value", 0, 0FFFFFFH, candidate.hud.value, error) OR
		~Integer(object, "missing_key", 0, 0FFFFFFH, candidate.hud.missingKey, error) OR
		~Integer(object, "blue_key", 0, 0FFFFFFH, candidate.hud.blueKey, error) OR
		~Integer(object, "yellow_key", 0, 0FFFFFFH, candidate.hud.yellowKey, error) OR
		~Integer(object, "red_key", 0, 0FFFFFFH, candidate.hud.redKey, error) THEN
		RETURN FALSE
	END;
	IF (candidate.hud.height > candidate.height) OR
		(candidate.hud.topRow + HudGlyphHeight > candidate.hud.height) OR
		(candidate.hud.bottomRow + HudGlyphHeight > candidate.hud.height) OR
		~FieldFits(candidate, candidate.hud.margin, "HEALTH", HudStatDigits) OR
		~FieldFits(candidate, candidate.hud.margin, "PICKUPS", HudPickupDigits) OR
		~FieldFits(candidate, candidate.hud.armorX, "ARMOR", HudStatDigits) OR
		~FieldFits(candidate, candidate.hud.ammoX + (DoomInventory.AmmoKinds - 1) * candidate.hud.ammoSpacing, "BUL", HudStatDigits) OR
		(candidate.hud.ammoSpacing < (Strings.Length("BUL") + HudStatDigits) * HudCharacterAdvance + candidate.hud.labelGap) OR
		~FieldFits(candidate, candidate.hud.weaponsX, "WEAPONS", 1) OR
		(candidate.hud.keysX + Strings.Length("KEYS") * HudCharacterAdvance > candidate.width) OR
		(candidate.hud.keyStartX + (DoomInventory.KeyKinds - 1) * candidate.hud.keySpacing + HudCharacterAdvance > candidate.width) OR
		(candidate.hud.hintX + Strings.Length("NEED YELLOW KEY") * HudCharacterAdvance > candidate.width) THEN
		COPY("HUD layout must fit inside the configured frame", error);
		RETURN FALSE
	END;
	IF (candidate.playerEye > candidate.playerHeight) OR (candidate.playerStep > candidate.playerHeight) THEN
		COPY("Player eye and step must not exceed player height", error);
		RETURN FALSE
	END;
	settings := candidate;
	RETURN TRUE
END Decode;

(* Read loads a startup configuration without publishing partially validated values. *)
PROCEDURE Read*(CONST path: ARRAY OF CHAR; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
BEGIN
	RETURN YAML.Load(path, value, error) & Decode(value, settings, error)
END Read;

(* Load publishes validated settings before constructing games; runtime reload is unsupported. *)
PROCEDURE Load*(CONST path: ARRAY OF CHAR; VAR error: ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN Read(path, values, error)
END Load;

PROCEDURE {TEST} DefaultsAndOverrides*;
VAR value: JSON.Value;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Parse("{}", value, error));
	ASSERT(Decode(value, settings, error));
	ASSERT((settings.width = 320) & (settings.height = 200));
	ASSERT((settings.ticksPerSecond = 35) & (settings.playerHeight = 56.0 / 64));
	ASSERT(YAML.Parse("{player: {move_per_tick: 11.52, radius: 20}, doors: {wait_ticks: 12}}", value, error));
	ASSERT(Decode(value, settings, error));
	ASSERT(ABS(settings.moveSpeed - 0.18) < 0.00000001);
	ASSERT(settings.playerRadius = 20.0 / 64);
	ASSERT((settings.doorWait = 12) & (settings.height = 200))
END DefaultsAndOverrides;

PROCEDURE {TEST} RejectInvalidAndPreserve*;
VAR value: JSON.Value;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	Defaults(settings);
	settings.width := 640;
	ASSERT(YAML.Parse("{video: {width: 800}, player: {radius: 0}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(settings.width = 640);
	ASSERT(YAML.Parse("{video: {width: 320.5}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{player: {eye: 57}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{player: {move_per_tik: 1}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{video: null}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{simulation: {ticks_per_second: '35'}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{unknown: {}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{hud: {colors: {background: 0x1000000}}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{hud: {height: 10}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("{hud: {hint_x: 300}}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(~Read("missing-doom-config.yaml", settings, error));
	ASSERT(settings.width = 640)
END RejectInvalidAndPreserve;

BEGIN
	Defaults(values)
END DoomConfig.
