MODULE DoomConfig;

IMPORT YAML, JSON, Strings, DoomFormat, DoomThings, GameAnimation, MathL;

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
	MaximumSwitchPairs = 256;
	Forward* = 0;
	Backward* = 1;
	Left* = 2;
	Right* = 3;
	StrafeLeft* = 4;
	StrafeRight* = 5;
	Use* = 6;
	Fire* = 7;
	Quit* = 8;
	Reload* = 9;
	Aim* = 10;
	Weapon1* = 11;
	Weapon7* = 17;
	InputActions* = 18;
	MaximumBindings = 8;
	MaximumActorRules = 128;
	MaximumRoutes = 128;
	MaximumThingRules = 128;
	MaximumHudStat = 999;
	MaximumPickupMultiplier = 8;
	MaximumActorHealth = 65535;
	MaximumTargetHeight = 1024;
	MaximumAimRadius = 16;
	MaximumAnimationFrames = GameAnimation.MaximumFrames;
	MaximumPellets = 32;
	MaximumMouseDelta* = 32768;
	MaximumWheelSteps* = 64;

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

KeyBindings* = RECORD
	count*: SIGNED32;
	keys*: ARRAY MaximumBindings OF SIGNED32
END;

InventorySettings* = RECORD
	initialHealth*, initialBullets*, healthMaximum*, bonusHealthMaximum*, armorUnit*, bonusArmorMaximum*: SIGNED32;
	healthBonus*, armorBonus*, stimpack*, medikit*, soulSphere*: SIGNED32;
	boxMultiplier*, weaponAmmoMultiplier*, backpackMultiplier*: SIGNED32;
	greenArmorDivisor*, blueArmorDivisor*: SIGNED32;
	maximum*, pickup*: ARRAY DoomFormat.AmmoKinds OF SIGNED32
END;

SpriteName* = ARRAY 6 OF CHAR;
SpriteFrames* = POINTER TO ARRAY OF SpriteName;

AnimationSettings* = POINTER TO RECORD
	kind*: SIGNED32;
	frames*: SpriteFrames;
	ticks*: POINTER TO ARRAY OF SIGNED32;
	timing*: GameAnimation.Clip;
	height*: FLOAT64;
	fullbright*: BOOLEAN
END;

ExplosionSettings* = POINTER TO RECORD
	blastDamage*, delay*: SIGNED32;
	blastRadius*: FLOAT64;
	animation*: AnimationSettings
END;

ProjectileSettings* = POINTER TO RECORD
	kind*, blastDamage*: SIGNED32;
	speed*, radius*, height*, blastRadius*: FLOAT64;
	frame*: SpriteName;
	fullbright*: BOOLEAN;
	impact*: AnimationSettings
END;

BehaviorSettings* = POINTER TO RECORD
	speed*, step*, sightRange*, range*: FLOAT64;
	damage*, windup*, cycle*: SIGNED32;
	walk*, attack*: SpriteFrames;
	walkTiming*, attackTiming*: GameAnimation.Clip;
	hitscan*: BOOLEAN;
	pellets*: SIGNED32;
	spread*: FLOAT64;
	projectile*: ProjectileSettings
END;

ActorSettings* = RECORD
	kind*, health*: SIGNED32;
	height*, radius*: FLOAT64;
	deathFrame*: SpriteName;
	behavior*: BehaviorSettings;
	explosion*: ExplosionSettings
END;

WeaponSettings* = RECORD
	label*: ARRAY 16 OF CHAR;
	ammo*, damage*, cooldown*, ammoCost*, flashTicks*, magazine*, reloadTicks*, pellets*: SIGNED32;
	range*, spread*: FLOAT64;
	projectile*: ProjectileSettings
END;

CombatSettings* = RECORD
	damage*, cooldown*, ammoCost*, flashTicks*, aimRadius*, aimGap*, aimColor*, fireColor*: SIGNED32;
	range*: FLOAT64;
	actors*: POINTER TO ARRAY OF ActorSettings;
	weapons*: ARRAY DoomFormat.WeaponKinds OF WeaponSettings
END;

Route* = RECORD
	name*, normal*, secret*: ARRAY DoomFormat.NameLength + 1 OF CHAR
END;

CampaignSettings* = RECORD
	routes*: POINTER TO ARRAY OF Route;
	statusX*, statusY*, statusColor*: SIGNED32;
	completeText*, errorText*: ARRAY 32 OF CHAR
END;

SwitchPair* = RECORD
	off*, on*: ARRAY DoomFormat.NameLength + 1 OF CHAR
END;

Settings* = RECORD
	width*, height*, ticksPerSecond*, maximumElapsed*, sleepMillis*, doorWait*, doorCloseWait*: SIGNED32;
	platformWait*: SIGNED32;
	buttonTicks*: SIGNED32;
	switchPairs*: POINTER TO ARRAY OF SwitchPair;
	playerRadius*, playerHeight*, playerStep*, playerEye*, moveSpeed*, turnSpeed*: FLOAT64;
	doorSpeed*, fastDoorSpeed*, useRange*, doorTopGap*: FLOAT64;
	floorSpeed*, platformSpeed*, fastPlatformSpeed*: FLOAT64;
	mouseSensitivity*, aimSensitivity*, pitchLimit*, aimZoom*: FLOAT64;
	invertMouse*: BOOLEAN;
	fireButton*, aimButton*: SIGNED32;
	pickupRadius*, pickupBelowFeet*: FLOAT64;
	hud*: HudSettings;
	campaign*: CampaignSettings;
	demoColors*: DemoPalette;
	demoEye*, demoWallHeight*: FLOAT64;
	demoLight*: SIGNED32;
	demoBricks*: BrickSettings;
	inventory*: InventorySettings;
	combat*: CombatSettings;
	things*: DoomThings.Definitions;
	controls*: ARRAY InputActions OF KeyBindings
END;

VAR values-: Settings;
	loaded-: BOOLEAN;
	actionNames: ARRAY InputActions OF ARRAY 16 OF CHAR;
	ammoNames: ARRAY DoomFormat.AmmoKinds OF ARRAY 8 OF CHAR;
	weaponNames: ARRAY DoomFormat.WeaponKinds OF ARRAY 16 OF CHAR;

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

PROCEDURE Boolean(object: JSON.Object; CONST key: ARRAY OF CHAR;
	VAR destination: BOOLEAN; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
BEGIN
	value := object.Get(key);
	IF (value = NIL) OR ~(value IS JSON.Bool) THEN
		COPY("Expected a boolean for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	destination := value(JSON.Bool).value;
	RETURN TRUE
END Boolean;

PROCEDURE FieldFits(CONST settings: Settings; x: SIGNED32; CONST label: ARRAY OF CHAR; digits: SIGNED32): BOOLEAN;
BEGIN
	RETURN x + (Strings.Length(label) + digits) * HudCharacterAdvance + settings.hud.labelGap <= settings.width
END FieldFits;

(* KeySymbol folds letter case so releasing Shift cannot leave a movement key held. *)
PROCEDURE KeySymbol*(key: SIGNED32): SIGNED32;
BEGIN
	IF (key >= ORD("A")) & (key <= ORD("Z")) THEN
		RETURN key + ORD("a") - ORD("A")
	END;
	RETURN key
END KeySymbol;

PROCEDURE Controls(root: JSON.Object; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR object: JSON.Object;
	value: JSON.Value;
	list: JSON.Array;
	action, other, i, j, key: SIGNED32;
	number: FLOAT64;
BEGIN
	IF ~Section(root, "controls", "|forward|backward|left|right|strafe_left|strafe_right|use|fire|quit|reload|aim|weapon_1|weapon_2|weapon_3|weapon_4|weapon_5|weapon_6|weapon_7|", object, error) THEN
		RETURN FALSE
	END;
	FOR action := 0 TO InputActions - 1 DO
		value := object.Get(actionNames[action]);
		IF (value = NIL) OR ~(value IS JSON.Array) THEN
			COPY("Expected key sequence for ", error);
			Strings.AppendX(error, actionNames[action]);
			RETURN FALSE
		END;
		list := value(JSON.Array);
		IF ((list.length < 1) & (action # Aim)) OR (list.length > MaximumBindings) THEN
			COPY("Invalid control binding count for ", error);
			Strings.AppendX(error, actionNames[action]);
			RETURN FALSE
		END;
		settings.controls[action].count := SIGNED32(list.length);
		FOR i := 0 TO settings.controls[action].count - 1 DO
			value := list.At(i);
			IF (value = NIL) OR ~(value IS JSON.Number) THEN
				COPY("Control keys must be integer key symbols", error);
				RETURN FALSE
			END;
			number := value(JSON.Number).value;
			IF (number < 1) OR (number > MAX(SIGNED32)) OR (number # ENTIER(number)) THEN
				COPY("Control key symbol is outside its integer range", error);
				RETURN FALSE
			END;
			key := ENTIER(number);
			FOR other := 0 TO action DO
				FOR j := 0 TO settings.controls[other].count - 1 DO
					IF ((other < action) & (KeySymbol(settings.controls[other].keys[j]) = KeySymbol(key))) OR
						((other = action) & (j < i) & (settings.controls[other].keys[j] = key)) THEN
						COPY("Duplicate control key for ", error);
						Strings.AppendX(error, actionNames[action]);
						RETURN FALSE
					END
				END
			END;
			settings.controls[action].keys[i] := key
		END
	END;
	RETURN TRUE
END Controls;

PROCEDURE Inventory(root: JSON.Object; VAR settings: InventorySettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR object, group: JSON.Object;
	i: SIGNED32;
BEGIN
	IF ~Section(root, "inventory", "|initial_health|initial_bullets|health_maximum|bonus_health_maximum|armor_unit|bonus_armor_maximum|health_bonus|armor_bonus|stimpack|medikit|soul_sphere|box_multiplier|weapon_ammo_multiplier|backpack_multiplier|green_armor_divisor|blue_armor_divisor|maximum_ammo|pickup_ammo|", object, error) OR
		~Integer(object, "initial_health", 1, MaximumHudStat, settings.initialHealth, error) OR
		~Integer(object, "initial_bullets", 0, MaximumHudStat, settings.initialBullets, error) OR
		~Integer(object, "health_maximum", 1, MaximumHudStat, settings.healthMaximum, error) OR
		~Integer(object, "bonus_health_maximum", 1, MaximumHudStat, settings.bonusHealthMaximum, error) OR
		~Integer(object, "armor_unit", 1, MaximumHudStat DIV 2, settings.armorUnit, error) OR
		~Integer(object, "bonus_armor_maximum", 1, MaximumHudStat, settings.bonusArmorMaximum, error) OR
		~Integer(object, "health_bonus", 1, MaximumHudStat, settings.healthBonus, error) OR
		~Integer(object, "armor_bonus", 1, MaximumHudStat, settings.armorBonus, error) OR
		~Integer(object, "stimpack", 1, MaximumHudStat, settings.stimpack, error) OR
		~Integer(object, "medikit", 1, MaximumHudStat, settings.medikit, error) OR
		~Integer(object, "soul_sphere", 1, MaximumHudStat, settings.soulSphere, error) OR
		~Integer(object, "box_multiplier", 1, MaximumPickupMultiplier, settings.boxMultiplier, error) OR
		~Integer(object, "weapon_ammo_multiplier", 1, MaximumPickupMultiplier, settings.weaponAmmoMultiplier, error) OR
		~Integer(object, "backpack_multiplier", 1, MaximumPickupMultiplier, settings.backpackMultiplier, error) OR
		~Integer(object, "green_armor_divisor", 1, MaximumHudStat, settings.greenArmorDivisor, error) OR
		~Integer(object, "blue_armor_divisor", 1, MaximumHudStat, settings.blueArmorDivisor, error) THEN
		RETURN FALSE
	END;
	IF ~Section(object, "maximum_ammo", "|bullets|shells|cells|rockets|", group, error) THEN
		RETURN FALSE
	END;
	FOR i := 0 TO DoomFormat.AmmoKinds - 1 DO
		IF ~Integer(group, ammoNames[i], 1, MaximumHudStat, settings.maximum[i], error) THEN
			RETURN FALSE
		END;
		IF settings.maximum[i] * settings.backpackMultiplier > MaximumHudStat THEN
			COPY("Backpack ammunition must fit the HUD", error);
			RETURN FALSE
		END
	END;
	IF ~Section(object, "pickup_ammo", "|bullets|shells|cells|rockets|", group, error) THEN
		RETURN FALSE
	END;
	FOR i := 0 TO DoomFormat.AmmoKinds - 1 DO
		IF ~Integer(group, ammoNames[i], 1, MaximumHudStat, settings.pickup[i], error) THEN
			RETURN FALSE
		END
	END;
	IF (settings.initialHealth > settings.healthMaximum) OR
		(settings.bonusHealthMaximum < settings.healthMaximum) OR
		(settings.bonusArmorMaximum < settings.armorUnit * 2) OR
		(settings.initialBullets > settings.maximum[0]) THEN
		COPY("Initial inventory and bonus limits must fit their capacities", error);
		RETURN FALSE
	END;
	RETURN TRUE
END Inventory;

PROCEDURE FrameName(value: JSON.Value; CONST key: ARRAY OF CHAR;
	VAR name: SpriteName; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR i, c: SIGNED32;
BEGIN
	IF (value = NIL) OR ~(value IS JSON.String) THEN
		COPY("Expected sprite frame string for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	IF Strings.Length(value(JSON.String).value^) # LEN(name) - 1 THEN
		COPY("Expected five-character sprite frame for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	COPY(value(JSON.String).value^, name);
	FOR i := 0 TO LEN(name) - 2 DO
		c := ORD(name[i]);
		IF ~((c >= ORD("A")) & (c <= ORD("Z"))) &
			~((i < 4) & (c >= ORD("0")) & (c <= ORD("9"))) THEN
			COPY("Invalid sprite frame for ", error);
			Strings.AppendX(error, key);
			RETURN FALSE
		END
	END;
	RETURN TRUE
END FrameName;

PROCEDURE FrameList(object: JSON.Object; CONST key: ARRAY OF CHAR;
	VAR frames: SpriteFrames; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	list: JSON.Array;
	i: SIGNED32;
BEGIN
	value := object.Get(key);
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Expected sprite frame sequence for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	list := value(JSON.Array);
	IF (list.length < 1) OR (list.length > MaximumAnimationFrames) THEN
		COPY("Invalid sprite frame count for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	NEW(frames, list.length);
	FOR i := 0 TO SIGNED32(list.length) - 1 DO
		IF ~FrameName(list.At(i), key, frames[i], error) THEN
			RETURN FALSE
		END
	END;
	RETURN TRUE
END FrameList;

PROCEDURE ThingRules(root: JSON.Object; VAR definitions: DoomThings.Definitions;
	VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	list: JSON.Array;
	rule: JSON.Object;
	i, j: SIGNED32;
BEGIN
	value := root.Get("things");
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Expected things sequence", error);
		RETURN FALSE
	END;
	list := value(JSON.Array);
	IF (list.length < 1) OR (list.length > MaximumThingRules) THEN
		COPY("Invalid things rule count", error);
		RETURN FALSE
	END;
	NEW(definitions, list.length);
	FOR i := 0 TO SIGNED32(list.length) - 1 DO
		value := list.At(i);
		IF (value = NIL) OR ~(value IS JSON.Object) THEN
			COPY("Expected thing rule mapping", error);
			RETURN FALSE
		END;
		rule := value(JSON.Object);
		IF ~Keys(rule, "|kind|spawn_frame|fullbright|ceiling|height|radius|", error) OR
			~Integer(rule, "kind", 1, DoomFormat.MaximumRecords - 1, definitions[i].kind, error) OR
			~FrameName(rule.Get("spawn_frame"), "spawn_frame", definitions[i].name, error) OR
			~Boolean(rule, "fullbright", definitions[i].fullbright, error) OR
			~Boolean(rule, "ceiling", definitions[i].ceiling, error) OR
			~Real(rule, "height", 0, MaximumTargetHeight, 1, definitions[i].height, error) OR
			~Real(rule, "radius", 0, MaximumTargetHeight, 1, definitions[i].radius, error) THEN
			RETURN FALSE
		END;
		IF definitions[i].ceiling & (definitions[i].height = 0) THEN
			COPY("Ceiling thing height must be positive", error);
			RETURN FALSE
		END;
		FOR j := 0 TO i - 1 DO
			IF definitions[j].kind = definitions[i].kind THEN
				COPY("Duplicate thing kind", error);
				RETURN FALSE
			END
		END
	END;
	RETURN TRUE
END ThingRules;

(* BlastRules requires an explicit disabled or finite blast so profiles cannot acquire hidden damage. *)
PROCEDURE BlastRules(object: JSON.Object; VAR damage: SIGNED32; VAR radius: FLOAT64; VAR error: ARRAY OF CHAR): BOOLEAN;
BEGIN
	IF ~Integer(object, "blast_damage", 0, MaximumActorHealth, damage, error) OR
		~Real(object, "blast_radius", 0, DoomFormat.MaximumRecords - 1, DoomFormat.UnitsPerWorld, radius, error) THEN
		RETURN FALSE
	END;
	IF (damage = 0) # (radius = 0) THEN
		COPY("Blast damage and radius must both be zero or positive", error);
		RETURN FALSE
	END;
	RETURN TRUE
END BlastRules;

(* AnimationRules keeps the first frame in things and validates one duration for every authored frame. *)
PROCEDURE AnimationRules(object: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR animation: AnimationSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR info: DoomThings.Info;
	extra: SpriteFrames;
	value: JSON.Value;
	ticks: JSON.Array;
	i: SIGNED32;
	number: FLOAT64;
BEGIN
	NEW(animation);
	IF ~Integer(object, "thing", 1, DoomFormat.MaximumRecords - 1, animation.kind, error) OR
		~DoomThings.Lookup(definitions, animation.kind, info) OR info.ceiling OR (info.height < 1) THEN
		COPY("Animation requires a finite ground thing with positive height", error);
		RETURN FALSE
	END;
	IF ~FrameList(object, "frames", extra, error) THEN
		RETURN FALSE
	END;
	IF LEN(extra^) >= MaximumAnimationFrames THEN
		COPY("Animation frame count includes the thing's first frame", error);
		RETURN FALSE
	END;
	NEW(animation.frames, LEN(extra^) + 1);
	COPY(info.name, animation.frames[0]);
	FOR i := 0 TO SIGNED32(LEN(extra^)) - 1 DO
		COPY(extra[i], animation.frames[i + 1])
	END;
	value := object.Get("ticks");
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Animation requires a ticks sequence", error);
		RETURN FALSE
	END;
	ticks := value(JSON.Array);
	IF ticks.length # LEN(animation.frames^) THEN
		COPY("Animation ticks must match its complete frame count", error);
		RETURN FALSE
	END;
	NEW(animation.ticks, ticks.length);
	FOR i := 0 TO SIGNED32(ticks.length) - 1 DO
		value := ticks.At(i);
		IF (value = NIL) OR ~(value IS JSON.Number) THEN
			COPY("Animation ticks must be positive integers", error);
			RETURN FALSE
		END;
		number := value(JSON.Number).value;
		IF (number >= 1) & (number <= MaximumClockValue) & (number = ENTIER(number)) THEN
			animation.ticks[i] := SIGNED32(ENTIER(number))
		ELSE
			COPY("Animation ticks must be positive bounded integers", error);
			RETURN FALSE
		END
	END;
	animation.timing := GameAnimation.Read(animation.ticks^);
	IF animation.timing = NIL THEN
		COPY("Animation timing exceeds engine bounds", error);
		RETURN FALSE
	END;
	animation.height := info.height / DoomFormat.UnitsPerWorld;
	animation.fullbright := info.fullbright;
	RETURN TRUE
END AnimationRules;

PROCEDURE ImpactRules(object: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	projectile: ProjectileSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR impact: JSON.Object;
BEGIN
	RETURN Section(object, "impact", "|thing|frames|ticks|", impact, error) &
		AnimationRules(impact, definitions, projectile.impact, error)
END ImpactRules;

PROCEDURE ExplosionRules(rule: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR explosion: ExplosionSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	object: JSON.Object;
BEGIN
	explosion := NIL;
	value := rule.Get("explosion");
	IF value = NIL THEN
		COPY("Actor requires explosion mapping or explicit null", error);
		RETURN FALSE
	ELSIF value IS JSON.Null THEN
		RETURN TRUE
	END;
	IF ~Section(rule, "explosion", "|thing|frames|ticks|blast_damage|blast_radius|delay_ticks|", object, error) THEN
		RETURN FALSE
	END;
	NEW(explosion);
	IF ~AnimationRules(object, definitions, explosion.animation, error) OR
		~BlastRules(object, explosion.blastDamage, explosion.blastRadius, error) OR
		~Integer(object, "delay_ticks", 1, MaximumClockValue, explosion.delay, error) THEN
		RETURN FALSE
	END;
	IF (explosion.blastDamage = 0) OR (explosion.delay >= explosion.animation.timing.duration) THEN
		COPY("Actor blast must be positive and its delay must fit the animation", error);
		RETURN FALSE
	END;
	RETURN TRUE
END ExplosionRules;

PROCEDURE Behavior(rule: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR actor: ActorSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	object: JSON.Object;
	info: DoomThings.Info;
	name: ARRAY 16 OF CHAR;
	keys: ARRAY 192 OF CHAR;
	frameTicks: SIGNED32;
BEGIN
	value := rule.Get("behavior");
	IF (value = NIL) OR ~(value IS JSON.String) THEN
		COPY("Expected behavior string", error);
		RETURN FALSE
	END;
	actor.behavior := NIL;
	IF value(JSON.String).value^ = "static" THEN
		IF (rule.Get("melee") # NIL) OR (rule.Get("hitscan") # NIL) OR (rule.Get("projectile") # NIL) THEN
			COPY("Static behavior cannot have attack settings", error);
			RETURN FALSE
		END;
		RETURN TRUE
	ELSIF (value(JSON.String).value^ # "melee") & (value(JSON.String).value^ # "hitscan") &
		(value(JSON.String).value^ # "projectile") THEN
		COPY("Unsupported actor behavior", error);
		RETURN FALSE
	END;
	COPY(value(JSON.String).value^, name);
	IF ((name # "melee") & (rule.Get("melee") # NIL)) OR
		((name # "hitscan") & (rule.Get("hitscan") # NIL)) OR
		((name # "projectile") & (rule.Get("projectile") # NIL)) THEN
		COPY("Actor behavior cannot mix attack settings", error);
		RETURN FALSE
	END;
	NEW(actor.behavior);
	actor.behavior.hitscan := name = "hitscan";
	actor.behavior.projectile := NIL;
	COPY("|speed_per_tick|step|sight_range|range|damage|windup_ticks|cycle_ticks|frame_ticks|walk_frames|attack_frames|", keys);
	IF actor.behavior.hitscan THEN
		Strings.AppendX(keys, "pellets|spread_radians|")
	ELSIF name = "projectile" THEN
		Strings.AppendX(keys, "thing|shot_speed_per_tick|blast_damage|blast_radius|impact|")
	END;
	IF ~Section(rule, name, keys, object, error) OR
		~Real(object, "speed_per_tick", 0, 64, DoomFormat.UnitsPerWorld, actor.behavior.speed, error) OR
		~Real(object, "step", 0, MaximumTargetHeight, DoomFormat.UnitsPerWorld, actor.behavior.step, error) OR
		~Real(object, "sight_range", 1, DoomFormat.MaximumRecords - 1, DoomFormat.UnitsPerWorld, actor.behavior.sightRange, error) OR
		~Real(object, "range", 1, DoomFormat.MaximumRecords - 1, DoomFormat.UnitsPerWorld, actor.behavior.range, error) OR
		~Integer(object, "damage", 1, MaximumActorHealth, actor.behavior.damage, error) OR
		~Integer(object, "windup_ticks", 1, MaximumClockValue, actor.behavior.windup, error) OR
		~Integer(object, "cycle_ticks", 1, MaximumClockValue, actor.behavior.cycle, error) OR
		~Integer(object, "frame_ticks", 1, MaximumClockValue, frameTicks, error) OR
		~FrameList(object, "walk_frames", actor.behavior.walk, error) OR
		~FrameList(object, "attack_frames", actor.behavior.attack, error) THEN
		RETURN FALSE
	END;
	IF (actor.behavior.step > actor.height) OR (actor.behavior.range > actor.behavior.sightRange) OR
		(actor.behavior.windup >= actor.behavior.cycle) THEN
		COPY("Actor step, range and windup must fit height, sight range and cycle", error);
		RETURN FALSE
	END;
	actor.behavior.walkTiming := GameAnimation.Uniform(SIGNED32(LEN(actor.behavior.walk^)), frameTicks);
	actor.behavior.attackTiming := GameAnimation.Uniform(SIGNED32(LEN(actor.behavior.attack^)), frameTicks);
	IF (actor.behavior.walkTiming = NIL) OR (actor.behavior.attackTiming = NIL) THEN
		COPY("Actor animation timing exceeds engine bounds", error);
		RETURN FALSE
	END;
	IF actor.behavior.hitscan &
		(~Integer(object, "pellets", 1, MaximumPellets, actor.behavior.pellets, error) OR
		~Real(object, "spread_radians", 0, 1, 1, actor.behavior.spread, error)) THEN
		RETURN FALSE
	END;
	IF name = "projectile" THEN
		NEW(actor.behavior.projectile);
		IF ~Integer(object, "thing", 1, DoomFormat.MaximumRecords - 1, actor.behavior.projectile.kind, error) OR
			~Real(object, "shot_speed_per_tick", 0.01, MaximumTargetHeight, DoomFormat.UnitsPerWorld,
				actor.behavior.projectile.speed, error) OR
			~BlastRules(object, actor.behavior.projectile.blastDamage, actor.behavior.projectile.blastRadius, error) OR
			~ImpactRules(object, definitions, actor.behavior.projectile, error) THEN
			RETURN FALSE
		END;
		IF ~DoomThings.Lookup(definitions, actor.behavior.projectile.kind, info) OR info.ceiling OR
			(info.radius < 1) OR (info.height < 1) THEN
			COPY("Projectile thing requires positive dimensions and ground attachment", error);
			RETURN FALSE
		END;
		actor.behavior.projectile.radius := info.radius / DoomFormat.UnitsPerWorld;
		actor.behavior.projectile.height := info.height / DoomFormat.UnitsPerWorld;
		actor.behavior.projectile.fullbright := info.fullbright;
		COPY(info.name, actor.behavior.projectile.frame)
	END;
	RETURN TRUE
END Behavior;

PROCEDURE ActorRules(object: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR settings: CombatSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	list: JSON.Array;
	rule: JSON.Object;
	info: DoomThings.Info;
	i, j: SIGNED32;
BEGIN
	value := object.Get("actors");
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Expected actors sequence", error);
		RETURN FALSE
	END;
	list := value(JSON.Array);
	IF (list.length < 1) OR (list.length > MaximumActorRules) THEN
		COPY("Invalid actors rule count", error);
		RETURN FALSE
	END;
	NEW(settings.actors, list.length);
	FOR i := 0 TO SIGNED32(list.length) - 1 DO
		value := list.At(i);
		IF (value = NIL) OR ~(value IS JSON.Object) THEN
			COPY("Expected actor rule mapping", error);
			RETURN FALSE
		END;
		rule := value(JSON.Object);
		IF ~Keys(rule, "|kind|health|death_frame|behavior|melee|hitscan|projectile|explosion|", error) OR
			~Integer(rule, "kind", 1, DoomFormat.MaximumRecords - 1, settings.actors[i].kind, error) OR
			~Integer(rule, "health", 1, MaximumActorHealth, settings.actors[i].health, error) THEN
			RETURN FALSE
		END;
		IF ~DoomThings.Lookup(definitions, settings.actors[i].kind, info) OR (info.radius < 1) OR (info.height < 1) THEN
			COPY("Actor thing radius and height must be at least one map unit", error);
			RETURN FALSE
		END;
		settings.actors[i].height := info.height / DoomFormat.UnitsPerWorld;
		settings.actors[i].radius := info.radius / DoomFormat.UnitsPerWorld;
		FOR j := 0 TO i - 1 DO
			IF settings.actors[j].kind = settings.actors[i].kind THEN
				COPY("Duplicate actor kind", error);
				RETURN FALSE
			END
		END;
		IF ~FrameName(rule.Get("death_frame"), "death_frame", settings.actors[i].deathFrame, error) OR
			~Behavior(rule, definitions, settings.actors[i], error) OR
			~ExplosionRules(rule, definitions, settings.actors[i].explosion, error) THEN
			RETURN FALSE
		END;
		IF ((settings.actors[i].behavior # NIL) OR (settings.actors[i].explosion # NIL)) & info.ceiling THEN
			COPY("Active behavior and explosions require a ground actor", error);
			RETURN FALSE
		END
	END;
	RETURN TRUE
END ActorRules;

PROCEDURE WeaponRules(combat: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR settings: CombatSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR group, object, flight: JSON.Object;
	value: JSON.Value;
	i, j, kind: SIGNED32;
	info: DoomThings.Info;
BEGIN
	IF ~Section(combat, "weapons", "|fist|shotgun|chaingun|launcher|plasma|bfg|chainsaw|super_shotgun|", group, error) THEN
		RETURN FALSE
	END;
	FOR i := 0 TO DoomFormat.WeaponKinds - 1 DO
		IF i = 1 THEN
			value := combat.Get("pistol")
		ELSE
			value := group.Get(weaponNames[i])
		END;
		IF (value = NIL) OR ~(value IS JSON.Object) THEN
			COPY("Missing weapon definition: ", error);
			Strings.AppendX(error, weaponNames[i]);
			RETURN FALSE
		END;
		object := value(JSON.Object);
		IF ~Keys(object, "|mode|label|ammo|damage|cooldown_ticks|ammo_cost|range|flash_ticks|magazine|reload_ticks|pellets|spread_radians|projectile|", error) OR
			~Integer(object, "damage", 1, MaximumActorHealth, settings.weapons[i].damage, error) OR
			~Integer(object, "cooldown_ticks", 1, MaximumClockValue, settings.weapons[i].cooldown, error) OR
			~Integer(object, "ammo_cost", 0, MaximumHudStat, settings.weapons[i].ammoCost, error) OR
			~Integer(object, "flash_ticks", 1, MaximumClockValue, settings.weapons[i].flashTicks, error) OR
			~Integer(object, "magazine", 0, MaximumHudStat, settings.weapons[i].magazine, error) OR
			~Integer(object, "reload_ticks", 1, MaximumClockValue, settings.weapons[i].reloadTicks, error) OR
			~Integer(object, "pellets", 1, MaximumPellets, settings.weapons[i].pellets, error) OR
			~Real(object, "spread_radians", 0, 1, 1, settings.weapons[i].spread, error) OR
			~Real(object, "range", 1, DoomFormat.MaximumRecords - 1, DoomFormat.UnitsPerWorld, settings.weapons[i].range, error) THEN
			RETURN FALSE
		END;
		value := object.Get("label");
		IF (value = NIL) OR ~(value IS JSON.String) THEN
			COPY("Weapon label must be a string", error);
			RETURN FALSE
		END;
		IF (Strings.Length(value(JSON.String).value^) < 1) OR (Strings.Length(value(JSON.String).value^) > 15) THEN
			COPY("Weapon label must contain 1 to 15 characters", error);
			RETURN FALSE
		END;
		COPY(value(JSON.String).value^, settings.weapons[i].label);
		value := object.Get("ammo");
		IF (value = NIL) OR ~(value IS JSON.String) THEN
			COPY("Weapon ammo must be an ammunition name or none", error);
			RETURN FALSE
		END;
		settings.weapons[i].ammo := -2;
		IF value(JSON.String).value^ = "none" THEN
			settings.weapons[i].ammo := -1
		END;
		FOR j := 0 TO DoomFormat.AmmoKinds - 1 DO
			IF value(JSON.String).value^ = ammoNames[j] THEN
				settings.weapons[i].ammo := j
			END
		END;
		IF (settings.weapons[i].ammo = -2) OR
			((settings.weapons[i].ammo < 0) # (settings.weapons[i].ammoCost = 0)) OR
			((settings.weapons[i].ammo < 0) # (settings.weapons[i].magazine = 0)) OR
			(settings.weapons[i].magazine < settings.weapons[i].ammoCost) OR
			(settings.weapons[i].flashTicks > settings.weapons[i].cooldown) THEN
			COPY("Weapon ammunition, magazine and timing must be consistent", error);
			RETURN FALSE
		END;
		settings.weapons[i].projectile := NIL;
		value := object.Get("mode");
		IF (value = NIL) OR ~(value IS JSON.String) THEN
			COPY("Expected weapon mode", error);
			RETURN FALSE
		END;
		IF value(JSON.String).value^ = "projectile" THEN
			IF (settings.weapons[i].pellets # 1) OR (settings.weapons[i].spread # 0) THEN
				COPY("Projectile weapons require one unspread shot", error);
				RETURN FALSE
			END;
			IF (i = 0) OR (i = 1) THEN
				COPY("Initial weapons must use hitscan mode", error);
				RETURN FALSE
			END;
			IF ~Section(object, "projectile", "|thing|speed_per_tick|blast_damage|blast_radius|impact|", flight, error) OR
				~Integer(flight, "thing", 1, DoomFormat.MaximumRecords - 1, kind, error) THEN
				RETURN FALSE
			END;
			IF ~DoomThings.Lookup(definitions, kind, info) OR info.ceiling OR (info.height <= 0) OR (info.radius <= 0) THEN
				COPY("Weapon projectile must reference a finite ground thing", error);
				RETURN FALSE
			END;
			NEW(settings.weapons[i].projectile);
			settings.weapons[i].projectile.kind := kind;
			settings.weapons[i].projectile.height := info.height / DoomFormat.UnitsPerWorld;
			settings.weapons[i].projectile.radius := info.radius / DoomFormat.UnitsPerWorld;
			settings.weapons[i].projectile.fullbright := info.fullbright;
			COPY(info.name, settings.weapons[i].projectile.frame);
			IF ~Real(flight, "speed_per_tick", 0.01, 1024, DoomFormat.UnitsPerWorld, settings.weapons[i].projectile.speed, error) OR
				~BlastRules(flight, settings.weapons[i].projectile.blastDamage, settings.weapons[i].projectile.blastRadius, error) OR
				~ImpactRules(flight, definitions, settings.weapons[i].projectile, error) THEN
				RETURN FALSE
			END
		ELSIF (value(JSON.String).value^ # "hitscan") OR (object.Get("projectile") # NIL) THEN
			COPY("Weapon mode must match its projectile settings", error);
			RETURN FALSE
		END
	END;
	RETURN TRUE
END WeaponRules;

PROCEDURE Combat(root: JSON.Object; CONST definitions: ARRAY OF DoomThings.Info;
	VAR settings: CombatSettings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR object, group: JSON.Object;
BEGIN
	IF ~Section(root, "combat", "|pistol|weapons|aim|actors|", object, error) OR
		~Section(object, "pistol", "|damage|cooldown_ticks|ammo_cost|range|flash_ticks|mode|label|ammo|magazine|reload_ticks|pellets|spread_radians|", group, error) OR
		~Integer(group, "damage", 1, MaximumActorHealth, settings.damage, error) OR
		~Integer(group, "cooldown_ticks", 1, MaximumClockValue, settings.cooldown, error) OR
		~Integer(group, "ammo_cost", 1, MaximumHudStat, settings.ammoCost, error) OR
		~Integer(group, "flash_ticks", 1, MaximumClockValue, settings.flashTicks, error) OR
		~Real(group, "range", 1, DoomFormat.MaximumRecords - 1, DoomFormat.UnitsPerWorld, settings.range, error) OR
		~Section(object, "aim", "|radius|gap|color|fire_color|", group, error) OR
		~Integer(group, "radius", 1, MaximumAimRadius, settings.aimRadius, error) OR
		~Integer(group, "gap", 0, MaximumAimRadius, settings.aimGap, error) OR
		~Integer(group, "color", 0, 0FFFFFFH, settings.aimColor, error) OR
		~Integer(group, "fire_color", 0, 0FFFFFFH, settings.fireColor, error) OR
		~ActorRules(object, definitions, settings, error) OR
		~WeaponRules(object, definitions, settings, error) THEN
		RETURN FALSE
	END;
	IF (settings.aimGap > settings.aimRadius) OR (settings.flashTicks > settings.cooldown) THEN
		COPY("Aim gap and flash duration must fit their radius and cooldown", error);
		RETURN FALSE
	END;
	RETURN TRUE
END Combat;

PROCEDURE RouteName(value: JSON.Value; CONST key: ARRAY OF CHAR; allowEnd: BOOLEAN;
	VAR name, error: ARRAY OF CHAR): BOOLEAN;
VAR i: SIGNED32;
	length: SIZE;
	c: CHAR;
BEGIN
	IF value = NIL THEN
		COPY("Missing required campaign key: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	ELSIF allowEnd & (value IS JSON.Null) THEN
		name[0] := 0X;
		RETURN TRUE
	ELSIF ~(value IS JSON.String) THEN
		COPY("Expected map name for ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	length := Strings.Length(value(JSON.String).value^);
	IF (length < 1) OR (length > DoomFormat.NameLength) THEN
		COPY("Campaign map name length is invalid: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	FOR i := 0 TO SIGNED32(length) - 1 DO
		c := CAP(value(JSON.String).value[i]);
		IF ~(((c >= "A") & (c <= "Z")) OR ((c >= "0") & (c <= "9")) OR (c = "_")) THEN
			COPY("Invalid campaign map name: ", error);
			Strings.AppendX(error, key);
			RETURN FALSE
		END;
		name[i] := c
	END;
	name[length] := 0X;
	RETURN TRUE
END RouteName;

PROCEDURE SwitchName(value: JSON.Value; CONST key: ARRAY OF CHAR; VAR name, error: ARRAY OF CHAR): BOOLEAN;
VAR i, length: SIGNED32;
	c: CHAR;
BEGIN
	IF value = NIL THEN
		COPY("Missing required switch key: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	ELSIF ~(value IS JSON.String) THEN
		COPY("Switch texture name must be a string", error);
		RETURN FALSE
	END;
	length := SIGNED32(Strings.Length(value(JSON.String).value^));
	IF (length < 1) OR (length > DoomFormat.NameLength) THEN
		COPY("Switch texture name must contain one to eight characters", error);
		RETURN FALSE
	END;
	FOR i := 0 TO length - 1 DO
		c := CAP(value(JSON.String).value[i]);
		IF ~(((c >= "A") & (c <= "Z")) OR ((c >= "0") & (c <= "9")) OR (c = "_") OR (c = "-")) THEN
			COPY("Invalid switch texture name", error);
			RETURN FALSE
		END;
		name[i] := c
	END;
	name[length] := 0X;
	IF name = "-" THEN
		COPY("Switch texture cannot be absent", error);
		RETURN FALSE
	END;
	RETURN TRUE
END SwitchName;

PROCEDURE Switches(root: JSON.Object; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR object, pair: JSON.Object;
	value: JSON.Value;
	list: JSON.Array;
	i, j: SIGNED32;
BEGIN
	IF ~Section(root, "switches", "|button_ticks|pairs|", object, error) OR
		~Integer(object, "button_ticks", 1, MAX(SIGNED32), settings.buttonTicks, error) THEN
		RETURN FALSE
	END;
	value := object.Get("pairs");
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Expected switch texture pairs sequence", error);
		RETURN FALSE
	END;
	list := value(JSON.Array);
	IF (list.length < 1) OR (list.length > MaximumSwitchPairs) THEN
		COPY("Switch texture pair count is outside bounds", error);
		RETURN FALSE
	END;
	NEW(settings.switchPairs, list.length);
	FOR i := 0 TO SIGNED32(list.length) - 1 DO
		value := list.At(i);
		IF (value = NIL) OR ~(value IS JSON.Object) THEN
			COPY("Expected switch texture pair mapping", error);
			RETURN FALSE
		END;
		pair := value(JSON.Object);
		IF ~Keys(pair, "|off|on|", error) OR
			~SwitchName(pair.Get("off"), "off", settings.switchPairs[i].off, error) OR
			~SwitchName(pair.Get("on"), "on", settings.switchPairs[i].on, error) THEN
			RETURN FALSE
		END;
		IF settings.switchPairs[i].off = settings.switchPairs[i].on THEN
			COPY("Switch texture names must differ", error);
			RETURN FALSE
		END;
		FOR j := 0 TO i - 1 DO
			IF (settings.switchPairs[i].off = settings.switchPairs[j].off) OR
				(settings.switchPairs[i].off = settings.switchPairs[j].on) OR
				(settings.switchPairs[i].on = settings.switchPairs[j].off) OR
				(settings.switchPairs[i].on = settings.switchPairs[j].on) THEN
				COPY("Duplicate switch texture name", error);
				RETURN FALSE
			END
		END
	END;
	RETURN TRUE
END Switches;

PROCEDURE CampaignLabel(object: JSON.Object; CONST key: ARRAY OF CHAR; VAR text, error: ARRAY OF CHAR): BOOLEAN;
VAR value: JSON.Value;
	i: SIGNED32;
	length: SIZE;
BEGIN
	value := object.Get(key);
	IF (value = NIL) OR ~(value IS JSON.String) THEN
		COPY("Expected campaign label: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	length := Strings.Length(value(JSON.String).value^);
	IF (length < 1) OR (length >= LEN(text)) THEN
		COPY("Invalid campaign label length: ", error);
		Strings.AppendX(error, key);
		RETURN FALSE
	END;
	FOR i := 0 TO SIGNED32(length) - 1 DO
		IF (value(JSON.String).value[i] < " ") OR (value(JSON.String).value[i] > "~") THEN
			COPY("Invalid campaign label: ", error);
			Strings.AppendX(error, key);
			RETURN FALSE
		END
	END;
	COPY(value(JSON.String).value^, text);
	RETURN TRUE
END CampaignLabel;

PROCEDURE Campaign(root: JSON.Object; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR object, route: JSON.Object;
	value: JSON.Value;
	routes: JSON.Array;
	i, j: SIGNED32;
	normal, secret: BOOLEAN;
BEGIN
	IF ~Section(root, "campaign", "|routes|status_x|status_y|status_color|complete_text|error_text|", object, error) OR
		~Integer(object, "status_x", 0, settings.width - 1, settings.campaign.statusX, error) OR
		~Integer(object, "status_y", 0, settings.height - 1, settings.campaign.statusY, error) OR
		~Integer(object, "status_color", 0, 0FFFFFFH, settings.campaign.statusColor, error) OR
		~CampaignLabel(object, "complete_text", settings.campaign.completeText, error) OR
		~CampaignLabel(object, "error_text", settings.campaign.errorText, error) THEN
		RETURN FALSE
	END;
	IF (settings.campaign.statusY + HudGlyphHeight > settings.height - settings.hud.height) OR
		(settings.campaign.statusX + MAX(Strings.Length(settings.campaign.completeText),
			Strings.Length(settings.campaign.errorText)) * HudCharacterAdvance > settings.width) THEN
		COPY("Campaign labels must fit the frame", error);
		RETURN FALSE
	END;
	value := object.Get("routes");
	IF (value = NIL) OR ~(value IS JSON.Array) THEN
		COPY("Expected campaign routes sequence", error);
		RETURN FALSE
	END;
	routes := value(JSON.Array);
	IF (routes.length < 1) OR (routes.length > MaximumRoutes) THEN
		COPY("Campaign routes count is outside bounds", error);
		RETURN FALSE
	END;
	NEW(settings.campaign.routes, routes.length);
	FOR i := 0 TO SIGNED32(routes.length) - 1 DO
		value := routes.At(i);
		IF ~(value IS JSON.Object) THEN
			COPY("Expected campaign route mapping", error);
			RETURN FALSE
		END;
		route := value(JSON.Object);
		IF ~Keys(route, "|name|normal|secret|", error) OR
			~RouteName(route.Get("name"), "name", FALSE, settings.campaign.routes[i].name, error) OR
			~RouteName(route.Get("normal"), "normal", TRUE, settings.campaign.routes[i].normal, error) OR
			~RouteName(route.Get("secret"), "secret", TRUE, settings.campaign.routes[i].secret, error) THEN
			RETURN FALSE
		END;
		FOR j := 0 TO i - 1 DO
			IF settings.campaign.routes[i].name = settings.campaign.routes[j].name THEN
				COPY("Duplicate campaign route name", error);
				RETURN FALSE
			END
		END
	END;
	FOR i := 0 TO SIGNED32(routes.length) - 1 DO
		normal := settings.campaign.routes[i].normal[0] = 0X;
		secret := settings.campaign.routes[i].secret[0] = 0X;
		FOR j := 0 TO SIGNED32(routes.length) - 1 DO
			normal := normal OR (settings.campaign.routes[i].normal = settings.campaign.routes[j].name);
			secret := secret OR (settings.campaign.routes[i].secret = settings.campaign.routes[j].name)
		END;
		IF ~normal OR ~secret THEN
			COPY("Campaign route target is not configured", error);
			RETURN FALSE
		END
	END;
	RETURN TRUE
END Campaign;

(* Decode validates the complete schema before replacing settings, so failed reads preserve the caller's state. *)
PROCEDURE Decode(value: JSON.Value; VAR settings: Settings; VAR error: ARRAY OF CHAR): BOOLEAN;
VAR root, object, hud, demo: JSON.Object;
	candidate: Settings;
	i, ammo: SIGNED32;
BEGIN
	error[0] := 0X;
	IF (value = NIL) OR ~(value IS JSON.Object) THEN
		COPY("Doom configuration must be a mapping", error);
		RETURN FALSE
	END;
	root := value(JSON.Object);
	IF ~Keys(root, "|video|simulation|player|doors|floors|platforms|switches|hud|demo|inventory|things|combat|controls|mouse|campaign|", error) OR
		~Section(root, "video", "|width|height|", object, error) OR
		~Integer(object, "width", MinimumWidth, MaximumDimension, candidate.width, error) OR
		~Integer(object, "height", MinimumHeight, MaximumDimension, candidate.height, error) OR
		~Section(root, "simulation", "|ticks_per_second|maximum_elapsed_ms|sleep_ms|", object, error) OR
		~Integer(object, "ticks_per_second", 1, MaximumClockValue, candidate.ticksPerSecond, error) OR
		~Integer(object, "maximum_elapsed_ms", 1, MaximumClockValue, candidate.maximumElapsed, error) OR
		~Integer(object, "sleep_ms", 1, MaximumClockValue, candidate.sleepMillis, error) OR
		~Section(root, "player", "|radius|height|step|eye|move_per_tick|turn_per_tick|pickup_radius|pickup_below_feet|", object, error) OR
		~Real(object, "radius", 1, 128, DoomFormat.UnitsPerWorld, candidate.playerRadius, error) OR
		~Real(object, "height", 1, 256, DoomFormat.UnitsPerWorld, candidate.playerHeight, error) OR
		~Real(object, "step", 0, 128, DoomFormat.UnitsPerWorld, candidate.playerStep, error) OR
		~Real(object, "eye", 0, 256, DoomFormat.UnitsPerWorld, candidate.playerEye, error) OR
		~Real(object, "move_per_tick", 0, 64, DoomFormat.UnitsPerWorld, candidate.moveSpeed, error) OR
		~Real(object, "turn_per_tick", 0, 1, 1, candidate.turnSpeed, error) OR
		~Real(object, "pickup_radius", 0, 128, DoomFormat.UnitsPerWorld, candidate.pickupRadius, error) OR
		~Real(object, "pickup_below_feet", 0, 128, DoomFormat.UnitsPerWorld, candidate.pickupBelowFeet, error) OR
		~Section(root, "doors", "|speed_per_tick|fast_speed_per_tick|wait_ticks|close_wait_ticks|use_range|top_gap|", object, error) OR
		~Real(object, "speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.doorSpeed, error) OR
		~Real(object, "fast_speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.fastDoorSpeed, error) OR
		~Integer(object, "wait_ticks", 1, MAX(SIGNED32), candidate.doorWait, error) OR
		~Integer(object, "close_wait_ticks", 1, MAX(SIGNED32), candidate.doorCloseWait, error) OR
		~Real(object, "use_range", 1, 1024, DoomFormat.UnitsPerWorld, candidate.useRange, error) OR
		~Real(object, "top_gap", 0, 128, DoomFormat.UnitsPerWorld, candidate.doorTopGap, error) OR
		~Section(root, "floors", "|speed_per_tick|", object, error) OR
		~Real(object, "speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.floorSpeed, error) OR
		~Section(root, "platforms", "|speed_per_tick|fast_speed_per_tick|wait_ticks|", object, error) OR
		~Real(object, "speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.platformSpeed, error) OR
		~Real(object, "fast_speed_per_tick", 0.01, 64, DoomFormat.UnitsPerWorld, candidate.fastPlatformSpeed, error) OR
		~Integer(object, "wait_ticks", 1, MAX(SIGNED32), candidate.platformWait, error) THEN
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
		~FieldFits(candidate, candidate.hud.ammoX + (DoomFormat.AmmoKinds - 1) * candidate.hud.ammoSpacing, "BUL", HudStatDigits) OR
		(candidate.hud.ammoSpacing < (Strings.Length("BUL") + HudStatDigits) * HudCharacterAdvance + candidate.hud.labelGap) OR
		~FieldFits(candidate, candidate.hud.weaponsX, "WEAPONS", 1) OR
		(candidate.hud.keysX + Strings.Length("KEYS") * HudCharacterAdvance > candidate.width) OR
		(candidate.hud.keyStartX + (DoomFormat.KeyKinds - 1) * candidate.hud.keySpacing + HudCharacterAdvance > candidate.width) OR
		(candidate.hud.hintX + Strings.Length("NEED YELLOW KEY") * HudCharacterAdvance > candidate.width) THEN
		COPY("HUD layout must fit inside the configured frame", error);
		RETURN FALSE
	END;
	IF (candidate.playerEye > candidate.playerHeight) OR (candidate.playerStep > candidate.playerHeight) THEN
		COPY("Player eye and step must not exceed player height", error);
		RETURN FALSE
	END;
	IF ~Switches(root, candidate, error) OR ~Campaign(root, candidate, error) OR ~ThingRules(root, candidate.things, error) OR
		~Inventory(root, candidate.inventory, error) OR
		~Combat(root, candidate.things^, candidate.combat, error) OR ~Controls(root, candidate, error) OR
		~Section(root, "mouse", "|sensitivity|aim_sensitivity|invert_y|pitch_limit|aim_zoom|fire_button|aim_button|", object, error) OR
		~Real(object, "sensitivity", 0.00001, 0.1, 1, candidate.mouseSensitivity, error) OR
		~Real(object, "aim_sensitivity", 0.01, 1, 1, candidate.aimSensitivity, error) OR
		~Real(object, "pitch_limit", 0, 0.8, 1, candidate.pitchLimit, error) OR
		~Real(object, "aim_zoom", 1, 4, 1, candidate.aimZoom, error) OR
		~Boolean(object, "invert_y", candidate.invertMouse, error) OR
		~Integer(object, "fire_button", 0, 2, candidate.fireButton, error) OR
		~Integer(object, "aim_button", 0, 2, candidate.aimButton, error) THEN
		RETURN FALSE
	END;
	IF (candidate.height DIV 2 + candidate.combat.aimRadius >= candidate.height - candidate.hud.height) OR
		(candidate.combat.ammoCost > candidate.inventory.maximum[0] * candidate.inventory.backpackMultiplier) THEN
		COPY("Aim and ammunition cost must fit the configured frame and capacity", error);
		RETURN FALSE
	END;
	FOR i := 0 TO DoomFormat.WeaponKinds - 1 DO
		ammo := candidate.combat.weapons[i].ammo;
		IF (ammo >= 0) & (candidate.combat.weapons[i].ammoCost > candidate.inventory.maximum[ammo] * candidate.inventory.backpackMultiplier) THEN
			COPY("Weapon ammo_cost must fit inventory capacity", error);
			RETURN FALSE
		END
	END;
	IF (candidate.fireButton = candidate.aimButton) OR
		(candidate.height + 2 * (ENTIER(candidate.width / 1.32 * MathL.sin(candidate.pitchLimit) / MathL.cos(candidate.pitchLimit)) + 1) > MaximumDimension) THEN
		COPY("Mouse buttons must differ and the pitched viewport must fit the frame limit", error);
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
		item: JSON.Item;
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
			ELSIF original IS JSON.Array THEN
				item := original(JSON.Array).items;
				WHILE item # NIL DO
					IF item.value IS JSON.Object THEN
						MissingFields(item.value(JSON.Object))
					END;
					item := item.next
				END
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

PROCEDURE {TEST} SwitchBounds*;
VAR value: JSON.Value;
	root, switches, pair, other: JSON.Object;
	pairs, oversized: JSON.Array;
	settings: Settings;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	ASSERT(settings.buttonTicks = 35);
	ASSERT(LEN(settings.switchPairs^) = 40);
	settings.width := 640;
	value := root.Get("switches");
	switches := value(JSON.Object);
	value := switches.Get("pairs");
	pairs := value(JSON.Array);
	value := pairs.At(0);
	pair := value(JSON.Object);
	value := pairs.At(1);
	other := value(JSON.Object);
	RejectField(root, switches, "button_ticks", JSON.NewNumber(0), settings);
	RejectField(root, switches, "button_ticks", JSON.NewNumber(1.5), settings);
	RejectField(root, switches, "button_ticks", JSON.NewNumber(MAX(SIGNED32) + 1.0), settings);
	RejectField(root, switches, "pairs", JSON.NewArray(), settings);
	RejectField(root, switches, "pairs", JSON.NewNull(), settings);
	oversized := JSON.NewArray();
	FOR i := 0 TO MaximumSwitchPairs DO
		oversized.Add(pair)
	END;
	RejectField(root, switches, "pairs", oversized, settings);
	RejectField(root, pair, "off", JSON.NewString(""), settings);
	RejectField(root, pair, "off", JSON.NewString("-"), settings);
	RejectField(root, pair, "off", JSON.NewString("TOO_LONG_NAME"), settings);
	RejectField(root, pair, "off", JSON.NewString("BAD NAME"), settings);
	RejectField(root, pair, "off", JSON.NewNumber(1), settings);
	RejectField(root, pair, "on", pair.Get("off"), settings);
	RejectField(root, pair, "off", other.Get("on"), settings);
	RejectField(root, pair, "on", other.Get("off"), settings);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	RejectField(root, pair, "unknown", JSON.NewNull(), settings)
END SwitchBounds;

PROCEDURE {TEST} CampaignBounds*;
VAR value: JSON.Value;
	root, campaign, route, other: JSON.Object;
	routes, oversized: JSON.Array;
	settings: Settings;
	i: SIGNED32;
	control: ARRAY 2 OF CHAR;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	ASSERT(LEN(settings.campaign.routes) = 68);
	settings.width := 640;
	value := root.Get("campaign");
	campaign := value(JSON.Object);
	value := campaign.Get("routes");
	routes := value(JSON.Array);
	value := routes.At(0);
	route := value(JSON.Object);
	value := routes.At(1);
	other := value(JSON.Object);
	RejectField(root, campaign, "routes", JSON.NewArray(), settings);
	RejectField(root, campaign, "routes", JSON.NewString("routes"), settings);
	oversized := JSON.NewArray();
	FOR i := 0 TO MaximumRoutes DO
		oversized.Add(route)
	END;
	RejectField(root, campaign, "routes", oversized, settings);
	RejectField(root, route, "name", JSON.NewNull(), settings);
	RejectField(root, route, "name", JSON.NewString(""), settings);
	RejectField(root, route, "name", JSON.NewString("TOO_LONG_NAME"), settings);
	RejectField(root, route, "name", JSON.NewString("E1-M1"), settings);
	RejectField(root, other, "name", JSON.NewString("e1m1"), settings);
	RejectField(root, route, "normal", JSON.NewString("UNKNOWN"), settings);
	RejectField(root, route, "secret", JSON.NewNumber(9), settings);
	RejectField(root, campaign, "status_x", JSON.NewNumber(319), settings);
	RejectField(root, campaign, "status_y", JSON.NewNumber(settings.height - settings.hud.height), settings);
	RejectField(root, campaign, "status_color", JSON.NewNumber(01000000H), settings);
	RejectField(root, campaign, "complete_text", JSON.NewString(""), settings);
	RejectField(root, campaign, "error_text", JSON.NewString("01234567890123456789012345678901"), settings);
	control[0] := 09X;
	control[1] := 0X;
	RejectField(root, campaign, "error_text", JSON.NewString(control), settings);
	ASSERT(Decode(root, settings, error))
END CampaignBounds;

PROCEDURE {TEST} ThingBounds*;
VAR value: JSON.Value;
	root, rule, combat, actor: JSON.Object;
	things, actors, oversized: JSON.Array;
	settings: Settings;
	preserved: DoomThings.Definitions;
	info: DoomThings.Info;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	preserved := settings.things;
	settings.width := 640;
	value := root.Get("things");
	things := value(JSON.Array);
	value := things.At(0);
	rule := value(JSON.Object);
	RejectField(root, root, "things", JSON.NewArray(), settings);
	RejectField(root, root, "things", JSON.NewObject(), settings);
	oversized := JSON.NewArray();
	oversized.Add(JSON.NewNull());
	RejectField(root, root, "things", oversized, settings);
	oversized := JSON.NewArray();
	FOR i := 0 TO MaximumThingRules DO
		oversized.Add(rule)
	END;
	RejectField(root, root, "things", oversized, settings);
	RejectField(root, rule, "kind", JSON.NewNumber(0), settings);
	RejectField(root, rule, "kind", JSON.NewNumber(65536), settings);
	RejectField(root, rule, "kind", JSON.NewNumber(1.5), settings);
	value := things.At(1);
	RejectField(root, rule, "kind", value(JSON.Object).Get("kind"), settings);
	RejectField(root, rule, "spawn_frame", JSON.NewString("possa"), settings);
	RejectField(root, rule, "spawn_frame", JSON.NewString("POSSA0"), settings);
	RejectField(root, rule, "fullbright", JSON.NewNumber(1), settings);
	RejectField(root, rule, "ceiling", JSON.NewString("false"), settings);
	RejectField(root, rule, "ceiling", JSON.NewBool(TRUE), settings);
	RejectField(root, rule, "height", JSON.NewNumber(-1), settings);
	RejectField(root, rule, "height", JSON.NewNumber(MaximumTargetHeight + 1), settings);
	RejectField(root, rule, "radius", JSON.NewNumber(-1), settings);
	RejectField(root, rule, "radius", JSON.NewNumber(MaximumTargetHeight + 1), settings);
	FOR i := 0 TO SIGNED32(things.length) - 1 DO
		value := things.At(i);
		IF value(JSON.Object).Get("kind")(JSON.Number).value = 3004 THEN
			rule := value(JSON.Object)
		END
	END;
	RejectField(root, rule, "kind", JSON.NewNumber(9999), settings);
	RejectField(root, rule, "radius", JSON.NewNumber(0), settings);
	RejectField(root, rule, "radius", JSON.NewNumber(0.5), settings);
	RejectField(root, rule, "height", JSON.NewNumber(0), settings);
	RejectField(root, rule, "height", JSON.NewNumber(0.5), settings);
	RejectField(root, rule, "ceiling", JSON.NewBool(TRUE), settings);
	ASSERT(settings.things = preserved);
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("actors");
	actors := value(JSON.Array);
	value := actors.At(0);
	actor := value(JSON.Object);
	rule.Set("kind", JSON.NewNumber(9999));
	rule.Set("radius", JSON.NewNumber(20.5));
	rule.Set("height", JSON.NewNumber(56.5));
	actor.Set("kind", JSON.NewNumber(9999));
	ASSERT(Decode(root, settings, error));
	ASSERT(DoomThings.Lookup(settings.things^, 9999, info));
	ASSERT((info.radius = 20.5) & (info.height = 56.5));
	ASSERT(settings.combat.actors[0].radius = info.radius / DoomFormat.UnitsPerWorld);
	ASSERT(settings.combat.actors[0].height = info.height / DoomFormat.UnitsPerWorld);
	settings.width := 640;
	RejectField(root, actor, "radius", JSON.NewNumber(20.5), settings)
END ThingBounds;

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
	value := root.Get("doors");
	object := value(JSON.Object);
	RejectField(root, object, "close_wait_ticks", JSON.NewNumber(0), settings);
	RejectField(root, object, "close_wait_ticks", JSON.NewNumber(1.5), settings);
	RejectField(root, object, "close_wait_ticks", JSON.NewNumber(MAX(SIGNED32) + 1.0), settings);
	value := root.Get("floors");
	object := value(JSON.Object);
	RejectField(root, object, "speed_per_tick", JSON.NewNumber(0), settings);
	RejectField(root, object, "speed_per_tick", JSON.NewNumber(65), settings);
	value := root.Get("platforms");
	object := value(JSON.Object);
	RejectField(root, object, "speed_per_tick", JSON.NewNumber(0), settings);
	RejectField(root, object, "fast_speed_per_tick", JSON.NewNumber(65), settings);
	RejectField(root, object, "wait_ticks", JSON.NewNumber(0.5), settings);
	RejectField(root, object, "wait_ticks", JSON.NewNumber(0), settings);
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

PROCEDURE {TEST} CombatAndInputBounds*;
VAR value: JSON.Value;
	root, combat, pistol, aim, inventory, controls, rule: JSON.Object;
	actors, keys: JSON.Array;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("pistol");
	pistol := value(JSON.Object);
	RejectField(root, pistol, "damage", JSON.NewNumber(0), settings);
	RejectField(root, pistol, "damage", JSON.NewNumber(1.5), settings);
	RejectField(root, pistol, "range", JSON.NewNumber(0), settings);
	RejectField(root, pistol, "ammo_cost", JSON.NewNumber(401), settings);
	RejectField(root, pistol, "cooldown_ticks", JSON.NewNumber(0), settings);
	RejectField(root, pistol, "flash_ticks", JSON.NewNumber(20), settings);
	value := combat.Get("aim");
	aim := value(JSON.Object);
	RejectField(root, aim, "gap", JSON.NewNumber(4), settings);
	RejectField(root, aim, "color", JSON.NewNumber(01000000H), settings);
	value := combat.Get("actors");
	actors := value(JSON.Array);
	value := actors.At(0);
	rule := value(JSON.Object);
	RejectField(root, rule, "kind", JSON.NewNumber(9999), settings);
	RejectField(root, rule, "kind", JSON.NewNumber(9), settings);
	RejectField(root, rule, "health", JSON.NewNumber(0), settings);
	RejectField(root, rule, "death_frame", JSON.NewString("POSSL0"), settings);
	RejectField(root, rule, "death_frame", JSON.NewString("possl"), settings);
	RejectField(root, combat, "actors", JSON.NewArray(), settings);
	value := root.Get("inventory");
	inventory := value(JSON.Object);
	RejectField(root, inventory, "initial_health", JSON.NewNumber(101), settings);
	RejectField(root, inventory, "initial_bullets", JSON.NewNumber(201), settings);
	RejectField(root, inventory, "backpack_multiplier", JSON.NewNumber(4), settings);
	RejectField(root, inventory, "bonus_armor_maximum", JSON.NewNumber(199), settings);
	value := root.Get("controls");
	controls := value(JSON.Object);
	RejectField(root, controls, "fire", JSON.NewNumber(1), settings);
	RejectField(root, controls, "fire", JSON.NewArray(), settings);
	keys := JSON.NewArray();
	keys.Add(JSON.NewNumber(077H));
	RejectField(root, controls, "fire", keys, settings);
	keys := JSON.NewArray();
	keys.Add(JSON.NewNumber(057H));
	RejectField(root, controls, "fire", keys, settings);
	keys := JSON.NewArray();
	keys.Add(JSON.NewNumber(0));
	RejectField(root, controls, "fire", keys, settings);
	keys := JSON.NewArray();
	keys.Add(JSON.NewNumber(1.5));
	RejectField(root, controls, "fire", keys, settings);
	ASSERT(Decode(root, settings, error))
END CombatAndInputBounds;

PROCEDURE {TEST} MeleeBounds*;
VAR value: JSON.Value;
	root, combat, rule, melee, inventory: JSON.Object;
	actors, frames: JSON.Array;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("actors");
	actors := value(JSON.Array);
	value := actors.At(0);
	rule := value(JSON.Object);
	RejectField(root, rule, "behavior", JSON.NewString("unknown"), settings);
	RejectField(root, rule, "behavior", JSON.NewNumber(0), settings);
	RejectField(root, rule, "melee", JSON.NewObject(), settings);
	value := actors.At(7);
	rule := value(JSON.Object);
	ASSERT(rule.Get("kind")(JSON.Number).value = 3002);
	value := rule.Get("melee");
	melee := value(JSON.Object);
	RejectField(root, rule, "behavior", JSON.NewString("static"), settings);
	RejectField(root, melee, "speed_per_tick", JSON.NewNumber(-1), settings);
	RejectField(root, melee, "step", JSON.NewNumber(57), settings);
	RejectField(root, melee, "sight_range", JSON.NewNumber(79), settings);
	RejectField(root, melee, "damage", JSON.NewNumber(0), settings);
	RejectField(root, melee, "windup_ticks", JSON.NewNumber(24), settings);
	RejectField(root, melee, "cycle_ticks", JSON.NewNumber(8), settings);
	RejectField(root, melee, "frame_ticks", JSON.NewNumber(0), settings);
	RejectField(root, melee, "walk_frames", JSON.NewArray(), settings);
	frames := JSON.NewArray();
	frames.Add(JSON.NewString("sarga"));
	RejectField(root, melee, "attack_frames", frames, settings);
	frames := JSON.NewArray();
	frames.Add(JSON.NewNumber(0));
	RejectField(root, melee, "attack_frames", frames, settings);
	value := root.Get("inventory");
	inventory := value(JSON.Object);
	RejectField(root, inventory, "green_armor_divisor", JSON.NewNumber(0), settings);
	RejectField(root, inventory, "blue_armor_divisor", JSON.NewNumber(1.5), settings);
	ASSERT(Decode(root, settings, error))
END MeleeBounds;

PROCEDURE {TEST} HitscanBounds*;
VAR value: JSON.Value;
	root, combat, rule, hitscan: JSON.Object;
	actors: JSON.Array;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("actors");
	actors := value(JSON.Array);
	value := actors.At(0);
	rule := value(JSON.Object);
	value := rule.Get("hitscan");
	hitscan := value(JSON.Object);
	RejectField(root, rule, "behavior", JSON.NewString("melee"), settings);
	RejectField(root, rule, "behavior", JSON.NewString("static"), settings);
	RejectField(root, rule, "melee", JSON.NewObject(), settings);
	RejectField(root, hitscan, "pellets", JSON.NewNumber(0), settings);
	RejectField(root, hitscan, "pellets", JSON.NewNumber(MaximumPellets + 1), settings);
	RejectField(root, hitscan, "pellets", JSON.NewNumber(1.5), settings);
	RejectField(root, hitscan, "spread_radians", JSON.NewNumber(-0.1), settings);
	RejectField(root, hitscan, "spread_radians", JSON.NewNumber(1.1), settings);
	RejectField(root, hitscan, "range", JSON.NewNumber(1025), settings);
	RejectField(root, hitscan, "windup_ticks", JSON.NewNumber(35), settings);
	ASSERT(Decode(root, settings, error))
END HitscanBounds;

PROCEDURE {TEST} ProjectileBounds*;
VAR value: JSON.Value;
	root, combat, rule, settingsObject, thing: JSON.Object;
	actors, things: JSON.Array;
	i: SIGNED32;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("actors");
	actors := value(JSON.Array);
	value := actors.At(6);
	rule := value(JSON.Object);
	ASSERT(rule.Get("kind")(JSON.Number).value = 3001);
	value := rule.Get("projectile");
	settingsObject := value(JSON.Object);
	RejectField(root, rule, "behavior", JSON.NewString("static"), settings);
	RejectField(root, rule, "behavior", JSON.NewString("hitscan"), settings);
	RejectField(root, rule, "hitscan", JSON.NewObject(), settings);
	RejectField(root, settingsObject, "thing", JSON.NewNumber(9999), settings);
	RejectField(root, settingsObject, "thing", JSON.NewNumber(2015), settings);
	RejectField(root, settingsObject, "shot_speed_per_tick", JSON.NewNumber(0), settings);
	RejectField(root, settingsObject, "shot_speed_per_tick", JSON.NewNumber(MaximumTargetHeight + 1), settings);
	RejectField(root, settingsObject, "shot_speed_per_tick", JSON.NewString("10"), settings);
	RejectField(root, settingsObject, "blast_damage", JSON.NewNumber(1), settings);
	RejectField(root, settingsObject, "blast_radius", JSON.NewNumber(1), settings);
	RejectField(root, settingsObject, "blast_damage", JSON.NewNumber(-1), settings);
	value := root.Get("things");
	things := value(JSON.Array);
	thing := NIL;
	value := things.At(0);
	FOR i := 0 TO SIGNED32(things.length) - 1 DO
		value := things.At(i);
		IF value(JSON.Object).Get("kind")(JSON.Number).value = 60000 THEN
			thing := value(JSON.Object)
		END
	END;
	ASSERT(thing # NIL);
	RejectField(root, thing, "ceiling", JSON.NewBool(TRUE), settings);
	RejectField(root, thing, "radius", JSON.NewNumber(0), settings);
	RejectField(root, thing, "height", JSON.NewNumber(0), settings);
	ASSERT(Decode(root, settings, error));
	ASSERT(settings.combat.actors[6].behavior.projectile.speed = 10.0 / 64);
	ASSERT(settings.combat.actors[6].behavior.projectile.fullbright)
END ProjectileBounds;

PROCEDURE {TEST} ExplosionBounds*;
VAR value: JSON.Value;
	root, combat, rule, explosion, impact: JSON.Object;
	actors, sequence: JSON.Array;
	i: SIGNED32;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	settings.width := 640;
	combat := root.Get("combat")(JSON.Object);
	actors := combat.Get("actors")(JSON.Array);
	rule := NIL;
	FOR i := 0 TO SIGNED32(actors.length) - 1 DO
		value := actors.At(i);
		IF value(JSON.Object).Get("kind")(JSON.Number).value = 2035 THEN
			rule := value(JSON.Object)
		END
	END;
	ASSERT(rule # NIL);
	explosion := rule.Get("explosion")(JSON.Object);
	RejectField(root, rule, "explosion", JSON.NewNumber(1), settings);
	RejectField(root, explosion, "thing", JSON.NewNumber(9999), settings);
	RejectField(root, explosion, "thing", JSON.NewNumber(49), settings);
	RejectField(root, explosion, "frames", JSON.NewArray(), settings);
	sequence := JSON.NewArray();
	FOR i := 1 TO MaximumAnimationFrames DO
		sequence.Add(JSON.NewString("BEXPB"))
	END;
	RejectField(root, explosion, "frames", sequence, settings);
	RejectField(root, explosion, "ticks", JSON.NewString("5"), settings);
	RejectField(root, explosion, "ticks", JSON.NewArray(), settings);
	FOR i := 0 TO 4 DO
		sequence := JSON.NewArray();
		CASE i OF
			0:
				sequence.Add(JSON.NewNumber(0))
			| 1:
				sequence.Add(JSON.NewNumber(-1))
			| 2:
				sequence.Add(JSON.NewNumber(1.5))
			| 3:
				sequence.Add(JSON.NewNumber(MaximumClockValue + 1))
			| 4:
				sequence.Add(JSON.NewString("5"))
		END;
		sequence.Add(JSON.NewNumber(5));
		sequence.Add(JSON.NewNumber(5));
		sequence.Add(JSON.NewNumber(10));
		sequence.Add(JSON.NewNumber(10));
		RejectField(root, explosion, "ticks", sequence, settings)
	END;
	RejectField(root, explosion, "delay_ticks", JSON.NewNumber(0), settings);
	RejectField(root, explosion, "delay_ticks", JSON.NewNumber(35), settings);
	RejectField(root, explosion, "delay_ticks", JSON.NewNumber(1.5), settings);
	RejectField(root, explosion, "blast_damage", JSON.NewNumber(0), settings);
	RejectField(root, explosion, "blast_radius", JSON.NewNumber(0), settings);
	impact := combat.Get("weapons")(JSON.Object).Get("launcher")(JSON.Object).Get("projectile")(JSON.Object).Get("impact")(JSON.Object);
	RejectField(root, impact, "thing", JSON.NewNumber(9999), settings);
	RejectField(root, impact, "ticks", JSON.NewArray(), settings);
	ASSERT(Decode(root, settings, error));
	ASSERT(settings.combat.weapons[4].projectile.impact.timing.duration = 18)
END ExplosionBounds;

PROCEDURE {TEST} WeaponMouseBounds*;
VAR value: JSON.Value;
	root, combat, weapons, pistol, rocket, mouse, flight: JSON.Object;
	settings: Settings;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(YAML.Load(DefaultFile, value, error));
	root := value(JSON.Object);
	ASSERT(Decode(root, settings, error));
	ASSERT((settings.combat.weapons[1].magazine = 12) & (settings.combat.weapons[1].ammo = 0));
	ASSERT((settings.combat.weapons[4].projectile.kind = 60001) & (settings.combat.weapons[6].ammoCost = 40));
	settings.width := 640;
	value := root.Get("mouse");
	mouse := value(JSON.Object);
	RejectField(root, mouse, "sensitivity", JSON.NewNumber(0), settings);
	RejectField(root, mouse, "aim_sensitivity", JSON.NewNumber(2), settings);
	RejectField(root, mouse, "pitch_limit", JSON.NewNumber(1), settings);
	RejectField(root, mouse, "aim_zoom", JSON.NewNumber(0.9), settings);
	RejectField(root, mouse, "invert_y", JSON.NewNumber(0), settings);
	RejectField(root, mouse, "fire_button", JSON.NewNumber(2), settings);
	RejectField(root, mouse, "aim_button", JSON.NewNumber(3), settings);
	value := root.Get("combat");
	combat := value(JSON.Object);
	value := combat.Get("pistol");
	pistol := value(JSON.Object);
	RejectField(root, pistol, "magazine", JSON.NewNumber(0), settings);
	RejectField(root, pistol, "magazine", JSON.NewNumber(1.5), settings);
	RejectField(root, pistol, "reload_ticks", JSON.NewNumber(0), settings);
	RejectField(root, pistol, "mode", JSON.NewString("projectile"), settings);
	RejectField(root, pistol, "ammo", JSON.NewString("unknown"), settings);
	RejectField(root, pistol, "ammo", JSON.NewString("none"), settings);
	RejectField(root, pistol, "label", JSON.NewString(""), settings);
	RejectField(root, pistol, "label", JSON.NewString("TOO LONG WEAPON NAME"), settings);
	value := combat.Get("weapons");
	weapons := value(JSON.Object);
	value := weapons.Get("launcher");
	rocket := value(JSON.Object);
	RejectField(root, rocket, "mode", JSON.NewString("hitscan"), settings);
	RejectField(root, rocket, "pellets", JSON.NewNumber(0), settings);
	RejectField(root, rocket, "pellets", JSON.NewNumber(2), settings);
	RejectField(root, rocket, "spread_radians", JSON.NewNumber(-1), settings);
	RejectField(root, rocket, "spread_radians", JSON.NewNumber(0.1), settings);
	value := rocket.Get("projectile");
	flight := value(JSON.Object);
	RejectField(root, flight, "thing", JSON.NewNumber(9999), settings);
	RejectField(root, flight, "thing", JSON.NewNumber(2015), settings);
	RejectField(root, flight, "speed_per_tick", JSON.NewNumber(0), settings);
	RejectField(root, flight, "blast_damage", JSON.NewNumber(0), settings);
	RejectField(root, flight, "blast_damage", JSON.NewNumber(-1), settings);
	RejectField(root, flight, "blast_damage", JSON.NewNumber(MaximumActorHealth + 1), settings);
	RejectField(root, flight, "blast_damage", JSON.NewNumber(1.5), settings);
	RejectField(root, flight, "blast_radius", JSON.NewNumber(0), settings);
	RejectField(root, flight, "blast_radius", JSON.NewNumber(-1), settings);
	RejectField(root, flight, "blast_radius", JSON.NewNumber(DoomFormat.MaximumRecords), settings);
	RejectField(root, flight, "blast_radius", JSON.NewString("128"), settings);
	ASSERT(Decode(root, settings, error))
END WeaponMouseBounds;

BEGIN
	loaded := FALSE;
	COPY("forward", actionNames[Forward]);
	COPY("backward", actionNames[Backward]);
	COPY("left", actionNames[Left]);
	COPY("right", actionNames[Right]);
	COPY("strafe_left", actionNames[StrafeLeft]);
	COPY("strafe_right", actionNames[StrafeRight]);
	COPY("use", actionNames[Use]);
	COPY("fire", actionNames[Fire]);
	COPY("quit", actionNames[Quit]);
	COPY("reload", actionNames[Reload]);
	COPY("aim", actionNames[Aim]);
	COPY("weapon_1", actionNames[Weapon1]);
	COPY("weapon_2", actionNames[Weapon1 + 1]);
	COPY("weapon_3", actionNames[Weapon1 + 2]);
	COPY("weapon_4", actionNames[Weapon1 + 3]);
	COPY("weapon_5", actionNames[Weapon1 + 4]);
	COPY("weapon_6", actionNames[Weapon1 + 5]);
	COPY("weapon_7", actionNames[Weapon7]);
	COPY("fist", weaponNames[0]);
	COPY("pistol", weaponNames[1]);
	COPY("shotgun", weaponNames[2]);
	COPY("chaingun", weaponNames[3]);
	COPY("launcher", weaponNames[4]);
	COPY("plasma", weaponNames[5]);
	COPY("bfg", weaponNames[6]);
	COPY("chainsaw", weaponNames[7]);
	COPY("super_shotgun", weaponNames[8]);
	COPY("bullets", ammoNames[0]);
	COPY("shells", ammoNames[1]);
	COPY("cells", ammoNames[2]);
	COPY("rockets", ammoNames[3])
END DoomConfig.
