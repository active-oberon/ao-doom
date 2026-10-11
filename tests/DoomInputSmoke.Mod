MODULE DoomInputSmoke;

IMPORT DoomConfig, DoomInput, KernelLog;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	DoomInput.Bindings;
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInput.Bindings;
	KernelLog.String("DoomInputSmoke: configurable keyboard {TEST} checks passed.");
	KernelLog.Ln
END Do;

END DoomInputSmoke.
