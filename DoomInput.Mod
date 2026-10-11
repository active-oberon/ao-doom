MODULE DoomInput;

IMPORT DoomConfig;

TYPE
	Controller* = OBJECT
	VAR held: ARRAY DoomConfig.InputActions OF SET;
		quit, use: BOOLEAN;

		PROCEDURE &Init*;
		VAR i: SIGNED32;
		BEGIN
			ASSERT(DoomConfig.loaded);
			FOR i := 0 TO DoomConfig.InputActions - 1 DO
				held[i] := {}
			END;
			quit := FALSE;
			use := FALSE
		END Init;

		PROCEDURE Focus*(focused: BOOLEAN);
		VAR action: SIGNED32;
		BEGIN {EXCLUSIVE}
			IF ~focused THEN
				FOR action := 0 TO DoomConfig.InputActions - 1 DO
					held[action] := {}
				END;
				use := FALSE
			END
		END Focus;

		PROCEDURE Key*(keysym: SIGNED32; released: BOOLEAN);
		VAR action, binding: SIGNED32;
		BEGIN {EXCLUSIVE}
			FOR action := 0 TO DoomConfig.InputActions - 1 DO
				FOR binding := 0 TO DoomConfig.values.controls[action].count - 1 DO
					IF DoomConfig.KeySymbol(keysym) = DoomConfig.KeySymbol(DoomConfig.values.controls[action].keys[binding]) THEN
						IF released THEN
							EXCL(held[action], binding)
						ELSE
							IF (action = DoomConfig.Use) & (held[action] = {}) THEN
								use := TRUE
							END;
							IF action = DoomConfig.Quit THEN
								quit := TRUE
							END;
							INCL(held[action], binding)
						END
					END
				END
			END
		END Key;

		PROCEDURE Read*(VAR move, strafe, turn: SIGNED32; VAR activate, firing: BOOLEAN): BOOLEAN;
		BEGIN {EXCLUSIVE}
			move := 0;
			strafe := 0;
			turn := 0;
			activate := use;
			use := FALSE;
			firing := held[DoomConfig.Fire] # {};
			IF held[DoomConfig.Forward] # {} THEN
				INC(move)
			END;
			IF held[DoomConfig.Backward] # {} THEN
				DEC(move)
			END;
			IF held[DoomConfig.StrafeRight] # {} THEN
				INC(strafe)
			END;
			IF held[DoomConfig.StrafeLeft] # {} THEN
				DEC(strafe)
			END;
			IF held[DoomConfig.Right] # {} THEN
				INC(turn)
			END;
			IF held[DoomConfig.Left] # {} THEN
				DEC(turn)
			END;
			RETURN ~quit
		END Read;
	END Controller;

PROCEDURE {TEST} Bindings*;
VAR keyboard: Controller;
	keysym: SIGNED32;
	released: BOOLEAN;
	move, strafe, turn: SIGNED32;
	activate, firing: BOOLEAN;
BEGIN
	NEW(keyboard);
	released := FALSE;
	keysym := DoomConfig.values.controls[DoomConfig.Forward].keys[0];
	keyboard.Key(keysym, released);
	keysym := DoomConfig.values.controls[DoomConfig.Forward].keys[DoomConfig.values.controls[DoomConfig.Forward].count - 1];
	keyboard.Key(keysym, released);
	keysym := DoomConfig.values.controls[DoomConfig.Forward].keys[0];
	released := TRUE;
	keyboard.Key(keysym, released);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT(move = 1);
	released := FALSE;
	keysym := DoomConfig.values.controls[DoomConfig.Use].keys[0];
	keyboard.Key(keysym, released);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT(activate);
	keyboard.Key(keysym, released);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT(~activate);
	keysym := DoomConfig.values.controls[DoomConfig.Fire].keys[0];
	keyboard.Key(keysym, released);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT(firing);
	keyboard.Focus(FALSE);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT((move = 0) & ~firing & ~activate);
	keysym := DoomConfig.values.controls[DoomConfig.Forward].keys[1];
	keyboard.Key(keysym, FALSE);
	keysym := DoomConfig.values.controls[DoomConfig.Forward].keys[0];
	keyboard.Key(keysym, TRUE);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	ASSERT(move = 0);
	keysym := DoomConfig.values.controls[DoomConfig.Quit].keys[0];
	released := TRUE;
	keyboard.Key(keysym, released);
	ASSERT(keyboard.Read(move, strafe, turn, activate, firing));
	released := FALSE;
	keyboard.Key(keysym, released);
	ASSERT(~keyboard.Read(move, strafe, turn, activate, firing))
END Bindings;

END DoomInput.
