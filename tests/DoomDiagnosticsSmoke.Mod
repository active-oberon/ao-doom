MODULE DoomDiagnosticsSmoke;

IMPORT DoomConfig, Doom, GameGeometry, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR): Doom.Game;
VAR game: Doom.Game;
	error: ARRAY 256 OF CHAR;
BEGIN
	NEW(game);
	ASSERT(game.Load(path, "E1M1", error));
	RETURN game
END Load;

PROCEDURE {TEST} EmptyAndAcceptedUse*;
VAR game: Doom.Game;
	event: Doom.Interaction;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	game := Load("valid.wad");
	ASSERT(game.TakeInteraction() = NIL);
	game.Use;
	ASSERT(game.TakeInteraction() = NIL);
	game.Step(1);
	event := game.TakeInteraction();
	ASSERT((event # NIL) & (event.map = "E1M1") & (event.tick = 1));
	ASSERT((event.line = -1) & (event.special = 0) & (event.neededKey = -1) & ~event.accepted);
	ASSERT(game.TakeInteraction() = NIL);
	game.Step(2);
	ASSERT(game.TakeInteraction() = NIL);
	game := Load("door.wad");
	game.Use;
	game.Step(1);
	event := game.TakeInteraction();
	ASSERT((event # NIL) & event.accepted & (event.line = 8) & (event.special = 1));
	ASSERT(event.neededKey = -1);
	ASSERT(game.world.Region(1).ceiling > 0)
END EmptyAndAcceptedUse;

PROCEDURE {TEST} LockedUseAndSnapshots*;
VAR game: Doom.Game;
	first, second: Doom.Interaction;
BEGIN
	game := Load("door-locked.wad");
	game.Use;
	game.Step(1);
	first := game.TakeInteraction();
	ASSERT((first # NIL) & ~first.accepted & (first.special = 26));
	ASSERT((first.line = 8) & (first.neededKey = 0) & (first.tick = 1));
	game.Use;
	game.Step(2);
	second := game.TakeInteraction();
	ASSERT((second # NIL) & (second # first) & (second.tick = 2));
	ASSERT(~second.accepted & (second.neededKey = 0));
	ASSERT(first.tick = 1)
END LockedUseAndSnapshots;

PROCEDURE {TEST} ExitsAndReplacement*;
VAR game: Doom.Game;
	event: Doom.Interaction;
	world: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
BEGIN
	game := Load("exits-use.wad");
	game.Use;
	game.Step(1);
	event := game.TakeInteraction();
	ASSERT((event # NIL) & event.accepted & (event.special = 11) & (event.line = 1));
	ASSERT(event.map = "E1M1");
	ASSERT(game.TakeTransition().target = "E1M2");
	game := Load("stairs-7.wad");
	game.Use;
	game.Step(1);
	world := game.world;
	ASSERT(~game.Load("stairs-hidden-texture.wad", "E1M1", error));
	ASSERT(game.world = world);
	event := game.TakeInteraction();
	ASSERT((event # NIL) & event.accepted & (event.special = 7) & (event.line = 11));
	game.Use;
	game.Step(2);
	ASSERT(game.Load("valid.wad", "E1M1", error));
	ASSERT(game.TakeInteraction() = NIL)
END ExitsAndReplacement;

PROCEDURE Do*;
BEGIN
	EmptyAndAcceptedUse;
	LockedUseAndSnapshots;
	ExitsAndReplacement;
	KernelLog.String("DoomDiagnosticsSmoke: use results, key denial, snapshots and level replacement passed.");
	KernelLog.Ln
END Do;

END DoomDiagnosticsSmoke.
