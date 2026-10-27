MODULE DoomArgs;
IMPORT Commands;
TYPE Reader* = OBJECT
	VAR context: Commands.Context;
		PROCEDURE &Init*(command: Commands.Context);
		BEGIN context := command END Init;
		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		BEGIN RETURN context.arg.GetString(value) END Next;
	END Reader;
END DoomArgs.
