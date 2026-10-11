MODULE DoomHud;

IMPORT DoomConfig, DoomInventory, GameSurface, GameText, Strings;

CONST CharacterAdvance = DoomConfig.HudCharacterAdvance;
	StatDigits = DoomConfig.HudStatDigits;
	PickupDigits = DoomConfig.HudPickupDigits;

VAR ammoLabels: ARRAY DoomInventory.AmmoKinds OF ARRAY 4 OF CHAR;
	keyHints: ARRAY DoomInventory.KeyColors OF ARRAY 16 OF CHAR;

PROCEDURE Number(frame: GameSurface.Frame; x, y, color, value, digits: SIGNED32);
VAR text: ARRAY 6 OF CHAR;
	i: SIGNED32;
BEGIN
	text[digits] := 0X;
	FOR i := digits - 1 TO 0 BY -1 DO
		text[i] := CHR(ORD("0") + value MOD 10);
		value := value DIV 10
	END;
	GameText.Draw(frame, x, y, color, text)
END Number;

(* Field derives the value position from its label so a label edit cannot overlap its number. *)
PROCEDURE Field(CONST appearance: DoomConfig.HudSettings; frame: GameSurface.Frame; x, y: SIGNED32; CONST label: ARRAY OF CHAR;
	value, digits: SIGNED32);
BEGIN
	GameText.Draw(frame, x, y, appearance.label, label);
	Number(frame, x + SIGNED32(Strings.Length(label)) * CharacterAdvance + appearance.labelGap, y, appearance.value, value, digits)
END Field;

PROCEDURE KeyColor(CONST appearance: DoomConfig.HudSettings; key: SIGNED32): SIGNED32;
BEGIN
	CASE key MOD DoomInventory.KeyColors OF
	DoomInventory.BlueCard:
		RETURN appearance.blueKey
	| DoomInventory.YellowCard:
		RETURN appearance.yellowKey
	| DoomInventory.RedCard:
		RETURN appearance.redKey
	END
END KeyColor;

PROCEDURE Supplies(CONST appearance: DoomConfig.HudSettings; CONST player: DoomInventory.State; frame: GameSurface.Frame; y: SIGNED32);
VAR i: SIGNED32;
BEGIN
	FOR i := 0 TO DoomInventory.AmmoKinds - 1 DO
		Field(appearance, frame, appearance.ammoX + i * appearance.ammoSpacing, y, ammoLabels[i], player.ammo[i], StatDigits)
	END
END Supplies;

PROCEDURE Keys(CONST appearance: DoomConfig.HudSettings; CONST player: DoomInventory.State; frame: GameSurface.Frame; y: SIGNED32);
VAR i, color: SIGNED32;
BEGIN
	GameText.Draw(frame, appearance.keysX, y, appearance.label, "KEYS");
	FOR i := 0 TO DoomInventory.KeyKinds - 1 DO
		color := appearance.missingKey;
		IF i IN player.keys THEN
			color := KeyColor(appearance, i)
		END;
		IF i < DoomInventory.KeyColors THEN
			GameText.Draw(frame, appearance.keyStartX + i * appearance.keySpacing, y, color, "C")
		ELSE
			GameText.Draw(frame, appearance.keyStartX + i * appearance.keySpacing, y, color, "S")
		END
	END;
	IF (player.neededKey >= 0) & (player.neededKey < DoomInventory.KeyColors) THEN
		GameText.Draw(frame, appearance.hintX, y, KeyColor(appearance, player.neededKey), keyHints[player.neededKey])
	END
END Keys;

PROCEDURE WeaponCount(CONST player: DoomInventory.State): SIGNED32;
VAR i, count: SIGNED32;
BEGIN
	count := 0;
	FOR i := 0 TO DoomInventory.WeaponKinds - 1 DO
		IF i IN player.weapons THEN
			INC(count)
		END
	END;
	RETURN count
END WeaponCount;

PROCEDURE Draw*(CONST player: DoomInventory.State; frame: GameSurface.Frame);
VAR x, y: SIGNED32;
	appearance: DoomConfig.HudSettings;
BEGIN
	appearance := DoomConfig.values.hud;
	IF (frame.height < appearance.height) OR (frame.width < DoomConfig.values.width) THEN
		RETURN
	END;
	y := frame.height - appearance.height;
	FOR x := 0 TO frame.width - 1 DO
		frame.Span(x, y, frame.height - 1, appearance.background)
	END;
	Field(appearance, frame, appearance.margin, y + appearance.topRow, "HEALTH", player.health, StatDigits);
	Field(appearance, frame, appearance.armorX, y + appearance.topRow, "ARMOR", player.armor, StatDigits);
	Supplies(appearance, player, frame, y + appearance.topRow);
	Field(appearance, frame, appearance.margin, y + appearance.bottomRow, "PICKUPS", player.pickups, PickupDigits);
	Field(appearance, frame, appearance.weaponsX, y + appearance.bottomRow, "WEAPONS", WeaponCount(player), 1);
	Keys(appearance, player, frame, y + appearance.bottomRow)
END Draw;

PROCEDURE {TEST} Panel*;
VAR frame, small: GameSurface.Frame;
	player: DoomInventory.State;
BEGIN
	NEW(small, 1, 1);
	DoomInventory.Reset(player);
	Draw(player, small);
	ASSERT(small.Pixel(0, 0) = 0);
	NEW(frame, DoomConfig.values.width, DoomConfig.values.hud.height * 2);
	frame.Background(0, 0);
	DoomInventory.Reset(player);
	Draw(player, frame);
	ASSERT(frame.Pixel(0, frame.height - DoomConfig.values.hud.height) = DoomConfig.values.hud.background);
	ASSERT(frame.Pixel(0, frame.height - DoomConfig.values.hud.height - 1) = 0);
	ASSERT(frame.Pixel(DoomConfig.values.hud.keyStartX, frame.height - DoomConfig.values.hud.height + DoomConfig.values.hud.bottomRow) = DoomConfig.values.hud.missingKey);
	INCL(player.keys, DoomInventory.BlueCard);
	player.neededKey := DoomInventory.RedCard;
	Draw(player, frame);
	ASSERT(frame.Pixel(DoomConfig.values.hud.keyStartX, frame.height - DoomConfig.values.hud.height + DoomConfig.values.hud.bottomRow) = DoomConfig.values.hud.blueKey);
	ASSERT(frame.Pixel(DoomConfig.values.hud.hintX, frame.height - DoomConfig.values.hud.height + DoomConfig.values.hud.bottomRow) = DoomConfig.values.hud.redKey)
END Panel;

BEGIN
	COPY("BUL", ammoLabels[DoomInventory.Bullets]);
	COPY("SHL", ammoLabels[DoomInventory.Shells]);
	COPY("CEL", ammoLabels[DoomInventory.Cells]);
	COPY("RKT", ammoLabels[DoomInventory.Rockets]);
	COPY("NEED BLUE KEY", keyHints[DoomInventory.BlueCard]);
	COPY("NEED YELLOW KEY", keyHints[DoomInventory.YellowCard]);
	COPY("NEED RED KEY", keyHints[DoomInventory.RedCard])
END DoomHud.
