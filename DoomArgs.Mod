MODULE DoomArgs;
IMPORT Unix, Commands, Streams;
TYPE Reader* = OBJECT
	VAR argument: SIGNED32; command: Streams.Reader;
		PROCEDURE &Init*(context: Commands.Context);
		BEGIN
			argument := 1; context.arg.SkipWhitespace;
			IF context.arg.Peek() # 0X THEN command := context.arg ELSE command := NIL END
		END Init;
		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF command # NIL THEN RETURN command.GetString(value) END;
			IF argument >= Unix.argc THEN RETURN FALSE END;
			Unix.GetArg(argument, value); INC(argument); RETURN TRUE
		END Next;
	END Reader;
END DoomArgs.
