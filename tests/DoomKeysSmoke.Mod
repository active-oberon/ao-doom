MODULE DoomKeysSmoke;
IMPORT DoomKeys, KernelLog;
PROCEDURE Do*;
BEGIN
	ASSERT(DoomKeys.VirtualKey(ORD('w')) = 87);
	ASSERT(DoomKeys.VirtualKey(ORD('W')) = 87);
	ASSERT(DoomKeys.VirtualKey(0FF52H) = 38);
	ASSERT(DoomKeys.VirtualKey(0FFE3H) = 162);
	ASSERT(DoomKeys.VirtualKey(0FF1BH) = 27);
	ASSERT(DoomKeys.VirtualKey(ORD('7')) = 55);
	ASSERT(DoomKeys.VirtualKey(0FFBEH) = 112);
	ASSERT(DoomKeys.VirtualKey(0) = 0);
	KernelLog.String('DoomKeysSmoke: physical Windows key translation passed.'); KernelLog.Ln
END Do;
END DoomKeysSmoke.
