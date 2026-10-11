MODULE DoomConfig;

IMPORT YAML, JSON, Strings, DoomFormat, DoomInventory;

CONST HudCharacterAdvance* = 4;
	HudGlyphHeight = 5;
	HudStatDigits* = 3;
	HudPickupDigits* = 5;
	DefaultFile* = "doom.yaml";
	MinimumWidth = 320;
	MinimumHeight = 40;
	MaximumDimension = 4096;
	MaximumTextureDimension = 1024;
	MaximumClockValue = 1000;

TYPE HudSettings* = RECORD
	height*, margin*, topRow*, bottomRow*, labelGap*: SIGNED32;
	armorX*, ammoX*, ammoSpacing*, weaponsX*, keysX*, keyStartX*, keySpacing*, hintX*: SIGNED32;
	background*, label*, value*, missingKey*, blueKey*, yellowKey*, redKey*: SIGNED32
END;

DemoPalette* = RECORD
	horizontalWall*, verticalWall*, leftPartition*, rightPartition*, pillar*: SIGNED32
END;

BrickSettings* = RECORD
	textureSize*, courseHeight*, brickWidth*, mortarWidth*, mortarShade*: SIGNED32
END;

Settings* = RECORD
	width*, height*, ticksPerSecond*, maximumElapsed*, sleepMillis*, doorWait*: SIGNED32;
	playerRadius*, playerHeight*, playerStep*, playerEye*, moveSpeed*, turnSpeed*: FLOAT64;
	doorSpeed*, fastDoorSpeed*, useRange*, doorTopGap*: FLOAT64;
	hud*: HudSettings;
	demoColors*: DemoPalette;
	demoEye*, demoWallHeight*: FLOAT64;
	demoLight*: SIGNED32;
	demoBricks*: BrickSettings
END;

VAR values-: Settings;
	loaded-: BOOLEAN;

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
	IF (value = NIL) OR ~(value IS JSON.Object) THEN
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
		COPY("Missing required configuration key: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
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
VAR root, object, hud, demo: JSON.Object;
	candidate: Settings;
BEGIN
	error[0] := 0X;
	IF (value = NIL) OR ~(value IS JSON.Object) THEN
		COPY("Doom configuration must be a mapping", error);
		RETURN FALSE
	END;
	root := value(JSON.Object);
	IF ~Keys(root, "|video|simulation|player|doors|hud|demo|", error) OR
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
	IF ~Section(root, "demo", "|eye|wall_height|light|bricks|colors|", demo, error) OR
		~Real(demo, "eye", 0, 1024, DoomFormat.UnitsPerWorld, candidate.demoEye, error) OR
		~Real(demo, "wall_height", 1, 1024, DoomFormat.UnitsPerWorld, candidate.demoWallHeight, error) OR
		~Integer(demo, "light", 0, 255, candidate.demoLight, error) OR
		~Section(demo, "bricks", "|texture_size|course_height|brick_width|mortar_width|mortar_shade|", object, error) OR
		~Integer(object, "texture_size", 1, MaximumTextureDimension, candidate.demoBricks.textureSize, error) OR
		~Integer(object, "course_height", 1, MaximumTextureDimension, candidate.demoBricks.courseHeight, error) OR
		~Integer(object, "brick_width", 1, MaximumTextureDimension, candidate.demoBricks.brickWidth, error) OR
		~Integer(object, "mortar_width", 0, MaximumTextureDimension, candidate.demoBricks.mortarWidth, error) OR
		~Integer(object, "mortar_shade", 1, 256, candidate.demoBricks.mortarShade, error) OR
		~Section(demo, "colors", "|horizontal_wall|vertical_wall|left_partition|right_partition|pillar|", object, error) OR
		~Integer(object, "horizontal_wall", 0, 0FFFFFFH, candidate.demoColors.horizontalWall, error) OR
		~Integer(object, "vertical_wall", 0, 0FFFFFFH, candidate.demoColors.verticalWall, error) OR
		~Integer(object, "left_partition", 0, 0FFFFFFH, candidate.demoColors.leftPartition, error) OR
		~Integer(object, "right_partition", 0, 0FFFFFFH, candidate.demoColors.rightPartition, error) OR
		~Integer(object, "pillar", 0, 0FFFFFFH, candidate.demoColors.pillar, error) THEN
		RETURN FALSE
	END;
	IF candidate.demoEye > candidate.demoWallHeight THEN
		COPY("Demo eye must not exceed wall height", error);
		RETURN FALSE
	END;
	IF (candidate.demoBricks.courseHeight > candidate.demoBricks.textureSize) OR
		(candidate.demoBricks.brickWidth > candidate.demoBricks.textureSize) OR
		(candidate.demoBricks.mortarWidth >= candidate.demoBricks.courseHeight) OR
		(candidate.demoBricks.mortarWidth >= candidate.demoBricks.brickWidth) THEN
		COPY("Brick dimensions must fit the texture and leave a brick interior", error);
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
	IF ~Read(path, values, error) THEN
		RETURN FALSE
	END;
	loaded := TRUE;
	RETURN TRUE
END Load;

PROCEDURE {TEST} CompleteAndRequired*;
VAR value: JSON.Value;
	root: JSON.Object;
	settings: Settings;
	error: ARRAY 256 OF CHAR;

	PROCEDURE MissingFields(object: JSON.Object);
	VAR member: JSON.Member;
		original: JSON.Value;
	BEGIN
		member := object.members;
		WHILE member # NIL DO
			original := member.value;
			object.Set(member.key^, NIL);
			ASSERT(~Decode(root, settings, error));
			ASSERT(Strings.Pos(member.key^, error) >= 0);
			ASSERT(settings.width = 640);
			object.Set(member.key^, original);
			IF original IS JSON.Object THEN
				MissingFields(original(JSON.Object))
			END;
			member := member.next
		END
	END MissingFields;

BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	MissingFields(root);
	ASSERT(Decode(root, settings, error));
	ASSERT(YAML.Parse("{}", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(YAML.Parse("null", value, error));
	ASSERT(~Decode(value, settings, error));
	ASSERT(~Decode(NIL, settings, error))
END CompleteAndRequired;

PROCEDURE RejectField(root, object: JSON.Object; CONST key: ARRAY OF CHAR;
	value: JSON.Value; VAR settings: Settings);
VAR original: JSON.Value;
	error: ARRAY 256 OF CHAR;
BEGIN
	original := object.Get(key);
	object.Set(key, value);
	ASSERT(~Decode(root, settings, error));
	ASSERT(error[0] # 0X);
	ASSERT(settings.width = 640);
	object.Set(key, original)
END RejectField;

PROCEDURE {TEST} PaletteBounds*;
VAR value: JSON.Value;
	root, demo, colors: JSON.Object;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	value := root.Get("demo");
	demo := value(JSON.Object);
	value := demo.Get("colors");
	colors := value(JSON.Object);
	colors.Set("horizontal_wall", JSON.NewNumber(0));
	colors.Set("pillar", JSON.NewNumber(0FFFFFFH));
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	RejectField(root, colors, "pillar", JSON.NewNumber(01000000H), settings);
	RejectField(root, colors, "pillar", JSON.NewNumber(-1), settings);
	RejectField(root, colors, "pillar", JSON.NewNumber(1.5), settings);
	RejectField(root, colors, "pillar", JSON.NewString("0xffffff"), settings);
	RejectField(root, demo, "colors", JSON.NewNull(), settings);
	RejectField(root, root, "demo", JSON.NewNull(), settings);
	RejectField(root, colors, "pilllar", JSON.NewNumber(1), settings);
	ASSERT(settings.demoColors.horizontalWall = 0);
	ASSERT(settings.demoColors.pillar = 0FFFFFFH)
END PaletteBounds;

PROCEDURE {TEST} DemoAppearanceBounds*;
VAR value: JSON.Value;
	root, demo, bricks: JSON.Object;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("demo");
	demo := value(JSON.Object);
	value := demo.Get("bricks");
	bricks := value(JSON.Object);
	RejectField(root, demo, "eye", JSON.NewNumber(1025), settings);
	RejectField(root, demo, "eye", JSON.NewNumber(180), settings);
	RejectField(root, demo, "wall_height", JSON.NewNumber(0), settings);
	RejectField(root, demo, "light", JSON.NewNumber(256), settings);
	RejectField(root, demo, "light", JSON.NewNumber(-1), settings);
	RejectField(root, demo, "light", JSON.NewNumber(1.5), settings);
	RejectField(root, demo, "bricks", JSON.NewNull(), settings);
	RejectField(root, bricks, "texture_size", JSON.NewNumber(0), settings);
	RejectField(root, bricks, "texture_size", JSON.NewNumber(MaximumTextureDimension + 1), settings);
	RejectField(root, bricks, "texture_size", JSON.NewNumber(8), settings);
	RejectField(root, bricks, "course_height", JSON.NewNumber(0), settings);
	RejectField(root, bricks, "course_height", JSON.NewNumber(65), settings);
	RejectField(root, bricks, "brick_width", JSON.NewNumber(0), settings);
	RejectField(root, bricks, "brick_width", JSON.NewNumber(65), settings);
	RejectField(root, bricks, "brick_width", JSON.NewNumber(1), settings);
	RejectField(root, bricks, "mortar_width", JSON.NewNumber(-1), settings);
	RejectField(root, bricks, "mortar_width", JSON.NewNumber(16), settings);
	RejectField(root, bricks, "mortar_shade", JSON.NewNumber(0), settings);
	RejectField(root, bricks, "mortar_shade", JSON.NewNumber(257), settings);
	demo.Set("eye", JSON.NewNumber(0));
	demo.Set("wall_height", JSON.NewNumber(1));
	demo.Set("light", JSON.NewNumber(0));
	bricks.Set("texture_size", JSON.NewNumber(1));
	bricks.Set("course_height", JSON.NewNumber(1));
	bricks.Set("brick_width", JSON.NewNumber(1));
	bricks.Set("mortar_width", JSON.NewNumber(0));
	bricks.Set("mortar_shade", JSON.NewNumber(256));
	ASSERT(Decode(root, settings, error));
	ASSERT((settings.demoEye = 0) & (settings.demoWallHeight = 1.0 / 64));
	ASSERT((settings.demoLight = 0) & (settings.demoBricks.textureSize = 1));
	ASSERT((settings.demoBricks.mortarWidth = 0) & (settings.demoBricks.mortarShade = 256))
END DemoAppearanceBounds;

PROCEDURE {TEST} RejectInvalidAndPreserve*;
VAR value: JSON.Value;
	root, object: JSON.Object;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("video");
	object := value(JSON.Object);
	RejectField(root, object, "width", JSON.NewNumber(320.5), settings);
	RejectField(root, root, "video", JSON.NewNull(), settings);
	value := root.Get("simulation");
	object := value(JSON.Object);
	RejectField(root, object, "ticks_per_second", JSON.NewString("35"), settings);
	value := root.Get("player");
	object := value(JSON.Object);
	RejectField(root, object, "radius", JSON.NewNumber(0), settings);
	RejectField(root, object, "eye", JSON.NewNumber(settings.playerHeight * DoomFormat.UnitsPerWorld + 1), settings);
	value := root.Get("hud");
	object := value(JSON.Object);
	RejectField(root, object, "height", JSON.NewNumber(settings.hud.bottomRow + HudGlyphHeight - 1), settings);
	RejectField(root, object, "hint_x", JSON.NewNumber(settings.width), settings);
	RejectField(root, root, "unknown", JSON.NewObject(), settings);
	ASSERT(~Read("missing-doom-config.yaml", settings, error));
	ASSERT(settings.width = 640)
END RejectInvalidAndPreserve;

BEGIN
	loaded := FALSE
END DoomConfig.
