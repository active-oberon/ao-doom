MODULE DoomInputSmoke;

IMPORT DoomConfig, DoomInput, KernelLog;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
	input: DoomInput.Controller;
	move, strafe, turn: SIGNED32; use, fire: BOOLEAN;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	DoomInput.Bindings;
	NEW(input);
	input.Stop;
	ASSERT(~input.Read(move, strafe, turn, use, fire));
	input.Focus(TRUE);
	ASSERT(~input.Read(move, strafe, turn, use, fire));
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInput.Bindings;
	KernelLog.String("DoomInputSmoke: configurable keyboard {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomInputSmoke.
