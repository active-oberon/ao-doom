MODULE DoomHud;

IMPORT DoomInventory, GameSurface, GameText;

CONST Height* = 20;

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

PROCEDURE Draw*(CONST player: DoomInventory.State; frame: GameSurface.Frame);
VAR x, y, i, color, owned: SIGNED32;
BEGIN
	y := frame.height - Height;
	FOR x := 0 TO frame.width - 1 DO
		frame.Span(x, y, frame.height - 1, 012161CH)
	END;
	GameText.Draw(frame, 4, y + 3, 0C0C8D0H, "HEALTH");
	Number(frame, 32, y + 3, 0FFFFFFH, player.health, 3);
	GameText.Draw(frame, 52, y + 3, 0C0C8D0H, "ARMOR");
	Number(frame, 76, y + 3, 0FFFFFFH, player.armor, 3);
	GameText.Draw(frame, 98, y + 3, 0C0C8D0H, "BUL");
	Number(frame, 114, y + 3, 0FFFFFFH, player.ammo[DoomInventory.Bullets], 3);
	GameText.Draw(frame, 138, y + 3, 0C0C8D0H, "SHL");
	Number(frame, 154, y + 3, 0FFFFFFH, player.ammo[DoomInventory.Shells], 3);
	GameText.Draw(frame, 178, y + 3, 0C0C8D0H, "CEL");
	Number(frame, 194, y + 3, 0FFFFFFH, player.ammo[DoomInventory.Cells], 3);
	GameText.Draw(frame, 218, y + 3, 0C0C8D0H, "RKT");
	Number(frame, 234, y + 3, 0FFFFFFH, player.ammo[DoomInventory.Rockets], 3);
	GameText.Draw(frame, 4, y + 13, 0C0C8D0H, "PICKUPS");
	Number(frame, 36, y + 13, 0FFFFFFH, player.pickups, 5);
	owned := 0;
	FOR i := 0 TO 8 DO
		IF i IN player.weapons THEN
			INC(owned)
		END
	END;
	GameText.Draw(frame, 68, y + 13, 0C0C8D0H, "WEAPONS");
	Number(frame, 100, y + 13, 0FFFFFFH, owned, 1);
	GameText.Draw(frame, 120, y + 13, 0C0C8D0H, "KEYS");
	FOR i := 0 TO 5 DO
		color := 0353D48H;
		IF i IN player.keys THEN
			CASE i MOD 3 OF
			0:
				color := 060A0FFH
			| 1:
				color := 0FFE060H
			| 2:
				color := 0FF6060H
			END
		END;
		IF i < 3 THEN
			GameText.Draw(frame, 144 + i * 12, y + 13, color, "C")
		ELSE
			GameText.Draw(frame, 144 + i * 12, y + 13, color, "S")
		END
	END
END Draw;

END DoomHud.
