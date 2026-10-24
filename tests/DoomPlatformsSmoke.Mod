MODULE DoomPlatformsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, GameGeometry, GameSurface, KernelLog;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
	feet: FLOAT64;
BEGIN
	feet := 0;
	FOR i := 1 TO ticks DO
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, NIL)
	END
END Advance;

PROCEDURE Start(VAR map: DoomMap.Map);
BEGIN
	map.floors.Crossed(-0.5, 0, 0.5, 0);
	map.floors.ApplyCrossings(map.world)
END Start;

PROCEDURE Stop(VAR map: DoomMap.Map);
BEGIN
	map.floors.Crossed(3.5, 0, 4.5, 0);
	map.floors.ApplyCrossings(map.world)
END Stop;

PROCEDURE Resume(VAR map: DoomMap.Map);
BEGIN
	map.floors.Crossed(-2, 3.5, -2, 4.5);
	map.floors.ApplyCrossings(map.world)
END Resume;

PROCEDURE {TEST} PerpetualCycle*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	first: FLOAT64;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	Load("platform-87-89.wad", map);
	old := map.world;
	Start(map);
	ASSERT(~map.actions.Claim(1));
	ASSERT(map.actions.Special(8) = 87);
	Advance(map, 32);
	first := map.world.Region(1).floor;
	ASSERT((first = 0) OR (first = 1));
	Advance(map, DoomConfig.values.platformWait);
	ASSERT(map.world.Region(1).floor = first);
	Advance(map, 64);
	ASSERT(map.world.Region(1).floor = 1 - first);
	Advance(map, DoomConfig.values.platformWait + 64);
	ASSERT(map.world.Region(1).floor = first);
	ASSERT(old.Region(1).floor = 0.5);
	ASSERT(~map.actions.Claim(1))
END PerpetualCycle;

PROCEDURE StasisVariant(CONST path: ARRAY OF CHAR; startSpecial, stopSpecial, units: SIGNED32; perpetual: BOOLEAN);
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	height, delta: FLOAT64;
BEGIN
	Load(path, map);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	map.floors.Shot(map.world, 8);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0.5);
	Start(map);
	ASSERT((map.actions.Special(8) = startSpecial) = ((startSpecial = 87) OR (startSpecial = 88) OR (startSpecial = 120)));
	Advance(map, 1);
	delta := map.world.Region(1).floor - 0.5;
	ASSERT(ABS(delta) = units / 64.0);
	Start(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 0.5 + 2 * delta);
	height := map.world.Region(1).floor;
	Stop(map);
	ASSERT((map.actions.Special(9) = stopSpecial) = (stopSpecial = 89));
	ASSERT(~map.actions.Claim(1));
	old := map.world;
	Advance(map, 300);
	ASSERT(map.world = old);
	Stop(map);
	Advance(map, 3);
	ASSERT(map.world = old);
	Resume(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = height + delta);
	ASSERT(old.Region(1).floor = height);
	IF ~perpetual THEN
		Advance(map, 500);
		ASSERT(map.world.Region(1).floor = 0.5);
		ASSERT(map.actions.Claim(1));
		map.actions.Release(1)
	END
END StasisVariant;

PROCEDURE {TEST} StopAndResumeVariants*;
BEGIN
	StasisVariant("platform-53-54.wad", 53, 54, 1, TRUE);
	StasisVariant("platform-53-89.wad", 53, 89, 1, TRUE);
	StasisVariant("platform-87-54.wad", 87, 54, 1, TRUE);
	StasisVariant("platform-87-89.wad", 87, 89, 1, TRUE);
	StasisVariant("platform-10-54.wad", 10, 54, 4, FALSE);
	StasisVariant("platform-10-89.wad", 10, 89, 4, FALSE);
	StasisVariant("platform-88-54.wad", 88, 54, 4, FALSE);
	StasisVariant("platform-88-89.wad", 88, 89, 4, FALSE);
	StasisVariant("platform-121-54.wad", 121, 54, 8, FALSE);
	StasisVariant("platform-121-89.wad", 121, 89, 8, FALSE);
	StasisVariant("platform-120-54.wad", 120, 54, 8, FALSE);
	StasisVariant("platform-120-89.wad", 120, 89, 8, FALSE)
END StopAndResumeVariants;

PROCEDURE {TEST} WaitingStasis*;
VAR map: DoomMap.Map;
	first: FLOAT64;
BEGIN
	Load("platform-87-89.wad", map);
	Start(map);
	Advance(map, 32 + 20);
	first := map.world.Region(1).floor;
	Stop(map);
	Advance(map, 300);
	Resume(map);
	Advance(map, 85);
	ASSERT(map.world.Region(1).floor = first);
	Advance(map, 1);
	ASSERT(ABS(map.world.Region(1).floor - first) = 1.0 / 64);
	Advance(map, 63 + 20);
	Stop(map);
	Advance(map, 300);
	Resume(map);
	Advance(map, 85);
	ASSERT(map.world.Region(1).floor = 1 - first);
	Advance(map, 1);
	ASSERT(ABS(map.world.Region(1).floor - (1 - first)) = 1.0 / 64)
END WaitingStasis;

PROCEDURE {TEST} OppositeDirectionStasis*;
VAR map: DoomMap.Map;
	delta, height: FLOAT64;
BEGIN
	Load("platform-87-89.wad", map);
	Start(map);
	Advance(map, 1);
	delta := map.world.Region(1).floor - 0.5;
	Advance(map, 31 + 105 + 10);
	height := map.world.Region(1).floor;
	Stop(map);
	Advance(map, 300);
	Resume(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = height - delta)
END OppositeDirectionStasis;

PROCEDURE LimitFloor(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN after.Region(sector).floor <= 48.0 / 64
END LimitFloor;

PROCEDURE {TEST} ObstructionReversal*;
VAR map: DoomMap.Map;
	i: SIGNED32;
	feet, previous: FLOAT64;
	blocked: BOOLEAN;
BEGIN
	Load("platform-87-89.wad", map);
	Start(map);
	feet := 0;
	blocked := FALSE;
	FOR i := 1 TO 400 DO
		previous := map.world.Region(1).floor;
		map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, LimitFloor);
		IF blocked THEN
			ASSERT(map.world.Region(1).floor = 47.0 / 64);
			RETURN
		END;
		blocked := (previous = 48.0 / 64) & (map.world.Region(1).floor = previous)
	END;
	ASSERT(blocked)
END ObstructionReversal;

PROCEDURE {TEST} BusyAndUnmatchedActions*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("platform-53-54.wad", map);
	Stop(map);
	ASSERT(map.actions.Special(9) = 0);
	ASSERT(map.actions.Claim(1));
	Start(map);
	ASSERT(map.actions.Special(8) = 0);
	map.actions.Release(1);
	Advance(map, 3);
	ASSERT(map.world.Region(1).floor = 0.5);
	Resume(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor # 0.5);
	Load("platform-38-89.wad", map);
	Start(map);
	Advance(map, 1);
	Stop(map);
	Advance(map, 1);
	ASSERT(map.world.Region(1).floor = 30.0 / 64);
	Load("platform-87-89.wad", map);
	map.floors.Crossed(-0.5, 5, 0.5, 5);
	map.floors.ApplyCrossings(map.world);
	old := map.world;
	Advance(map, 10);
	ASSERT(map.world = old)
END BusyAndUnmatchedActions;

PROCEDURE {TEST} GroupedAndSeparateTags*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
	i: SIGNED32;
BEGIN
	Load("platform-grouped.wad", map);
	Start(map);
	FOR i := 0 TO 2 DO
		ASSERT(~map.actions.Claim(i))
	END;
	Advance(map, 4);
	Stop(map);
	old := map.world;
	Advance(map, 300);
	ASSERT(map.world = old);
	Resume(map);
	Advance(map, 120);
	ASSERT(map.world # old);
	Load("platform-separate.wad", map);
	Start(map);
	map.floors.Crossed(2, -3.5, 2, -4.5);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 5);
	Stop(map);
	old := map.world;
	Advance(map, 180);
	ASSERT(map.world.Region(1).floor = old.Region(1).floor);
	ASSERT(map.world.Region(2).floor # old.Region(2).floor)
END GroupedAndSeparateTags;

PROCEDURE {TEST} EqualBounds*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("platform-flat.wad", map);
	old := map.world;
	Start(map);
	Advance(map, 300);
	ASSERT(map.world = old);
	ASSERT(~map.actions.Claim(1));
	Stop(map);
	Advance(map, 300);
	Resume(map);
	Advance(map, 300);
	ASSERT(map.world = old);
	ASSERT(~map.actions.Claim(1))
END EqualBounds;

PROCEDURE {TEST} CustomTiming*;
VAR map: DoomMap.Map;
	height: FLOAT64;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("platform-87-89.wad", map);
	Start(map);
	Advance(map, 1);
	ASSERT(ABS(map.world.Region(1).floor - 0.5) = 2.0 / 64);
	Advance(map, 15);
	height := map.world.Region(1).floor;
	ASSERT((height = 0) OR (height = 1));
	Advance(map, 7);
	ASSERT(map.world.Region(1).floor = height);
	Advance(map, 1);
	ASSERT(ABS(map.world.Region(1).floor - height) = 2.0 / 64);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomTiming;

PROCEDURE {TEST} AcceptedMovementAndRiding*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	i: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	NEW(game);
	ASSERT(game.Load("platform-riding.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	game.Controls(0, 0, 0);
	ASSERT(game.State().x > DoomConfig.values.playerRadius);
	old := game.world;
	ASSERT(~game.Load("floor-hidden-texture.wad", "E1M1", error));
	ASSERT(game.world = old);
	FOR i := 11 TO 300 DO
		game.Step(i);
		ASSERT(ABS(game.State().eye - game.world.Region(1).floor - DoomConfig.values.playerEye) < 0.00000001)
	END;
	ASSERT(game.world # old);
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(frame.Save("platform-riding.ppm"))
END AcceptedMovementAndRiding;

PROCEDURE Do*;
BEGIN
	PerpetualCycle;
	StopAndResumeVariants;
	WaitingStasis;
	OppositeDirectionStasis;
	ObstructionReversal;
	BusyAndUnmatchedActions;
	GroupedAndSeparateTags;
	EqualBounds;
	CustomTiming;
	AcceptedMovementAndRiding;
	KernelLog.String("DoomPlatformsSmoke: perpetual platform checks passed.");
	KernelLog.Ln
END Do;

END DoomPlatformsSmoke.
