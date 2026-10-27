MODULE DoomArgs;

IMPORT Kernel32, Commands, Streams;

TYPE Reader* = OBJECT
	VAR line: ARRAY 32768 OF CHAR; position: SIGNED32; command: Streams.Reader;

		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		VAR quoted: BOOLEAN; length, slashes, i: SIGNED32; ch: CHAR;

			PROCEDURE Put(ch: CHAR);
			BEGIN
				IF length < LEN(value) - 1 THEN value[length] := ch; INC(length) END
			END Put;

		BEGIN
			IF command # NIL THEN RETURN command.GetString(value) END;
			WHILE (line[position] = " ") OR (line[position] = 9X) DO INC(position) END;
			IF line[position] = 0X THEN RETURN FALSE END;
			quoted := FALSE; length := 0;
			LOOP
				ch := line[position];
				IF (ch = 0X) OR (~quoted & ((ch = " ") OR (ch = 9X))) THEN EXIT END;
				slashes := 0;
				WHILE line[position] = 5CX DO INC(slashes); INC(position) END;
				IF line[position] = 22X THEN
					FOR i := 1 TO slashes DIV 2 DO Put(5CX) END;
					IF ODD(slashes) THEN Put(22X)
					ELSIF quoted & (line[position + 1] = 22X) THEN Put(22X); INC(position)
					ELSE quoted := ~quoted
					END;
					INC(position)
				ELSE
					FOR i := 1 TO slashes DO Put(5CX) END;
					ch := line[position];
					IF (ch = 0X) OR (~quoted & ((ch = " ") OR (ch = 9X))) THEN EXIT END;
					Put(ch); INC(position)
				END
			END;
			value[length] := 0X; RETURN TRUE
		END Next;

		PROCEDURE &Init*(context: Commands.Context);
		VAR executable: ARRAY 32768 OF CHAR;
		BEGIN
			context.arg.SkipWhitespace;
			IF context.arg.Peek() # 0X THEN command := context.arg ELSE command := NIL END;
			Kernel32.CopyString(Kernel32.GetCommandLine(), line); position := 0;
			IF command = NIL THEN IF Next(executable) THEN END END
		END Init;
	END Reader;

END DoomArgs.
