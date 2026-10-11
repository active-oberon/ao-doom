MODULE DoomLockedDoorsSmoke;

IMPORT DoomConfig, Doom, DoomInventory, DoomMap, DoomWad, GameGeometry, GameSurface, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Ceiling(world: GameGeometry.World): FLOAT64;
VAR region: GameGeometry.Sector;
BEGIN
	region := world.Region(1);
	RETURN region.ceiling
END Ceiling;

PROCEDURE Advance(VAR map: DoomMap.Map; ticks: SIGNED32);
VAR i: SIGNED32;
BEGIN
	FOR i := 1 TO ticks DO
		map.doors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, 0, DoomConfig.values.playerHeight, DoomConfig.values.playerStep)
	END
END Advance;

PROCEDURE Variant(CONST path, hidden: ARRAY OF CHAR; color: SIGNED32; stayOpen: BOOLEAN);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	old: GameGeometry.World;
	archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
	keys: SET;
	form, kind: SIGNED32;
BEGIN
	FOR form := 0 TO 1 DO
		Load(path, map);
		DoomInventory.Reset(player);
		old := map.world;
		ASSERT(~map.doors.Use(map.world, -1.000001, 0, 0, player));
		ASSERT(player.neededKey = -1);
		ASSERT(~map.doors.Use(map.world, 0.5, 0, MathL.pi, player));
		ASSERT(player.neededKey = -1);
		ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
		ASSERT(player.neededKey = color);
		Advance(map, 70);
		ASSERT(map.world = old);
		player.keys := {0..5} - {color, color + 3};
		ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
		ASSERT(player.neededKey = color);
		player.keys := {};
		kind := 40 - color;
		IF form = 0 THEN
			CASE color OF
			DoomInventory.BlueCard:
				kind := 5
			| DoomInventory.YellowCard:
				kind := 6
			| DoomInventory.RedCard:
				kind := 13
			END
		END;
		ASSERT(DoomInventory.Give(player, kind));
		ASSERT(player.neededKey = -1);
		keys := {color + form * 3};
		ASSERT(player.keys = keys);
		ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
		Advance(map, 1);
		ASSERT((Ceiling(map.world) = 2.0 / 64) & (Ceiling(old) = 0));
		IF ~stayOpen THEN
			player.keys := {};
			ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
			Advance(map, 1);
			ASSERT(Ceiling(map.world) = 4.0 / 64);
			player.keys := keys;
			ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
			Advance(map, 1);
			ASSERT(Ceiling(map.world) = 2.0 / 64);
			ASSERT(map.doors.Use(map.world, map.x, 0, 0, player))
		END;
		Advance(map, 61);
		ASSERT((Ceiling(map.world) = 124.0 / 64) & (player.keys = keys));
		IF stayOpen THEN
			ASSERT(~map.doors.Use(map.world, map.x, 0, 0, player));
			Advance(map, 250);
			ASSERT(Ceiling(map.world) = 124.0 / 64)
		ELSE
			Advance(map, 150);
			ASSERT(Ceiling(map.world) = 124.0 / 64);
			Advance(map, 1);
			ASSERT(Ceiling(map.world) = 122.0 / 64);
			Advance(map, 61);
			ASSERT(Ceiling(map.world) = 0);
			ASSERT(map.doors.Use(map.world, map.x, 0, 0, player));
			ASSERT((player.keys = keys) & (player.pickups = 1))
		END
	END;
	archive := DoomWad.Open(hidden, error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT((map.world = NIL) & (map.doors = NIL) & (error[0] # 0X))
END Variant;

PROCEDURE Blocked(CONST path: ARRAY OF CHAR);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
BEGIN
	Load(path, map);
	DoomInventory.Reset(player);
	player.keys := {DoomInventory.BlueCard};
	ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
	ASSERT((player.neededKey = -1) & (Ceiling(map.world) = 0))
END Blocked;

PROCEDURE Gameplay;
VAR game: Doom.Game;
	player, previous: DoomInventory.State;
	pose: Doom.Pose;
	old: GameGeometry.World;
	frame: GameSurface.Frame;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	NEW(frame, 320, 200);
	ASSERT(game.Load("door-key.wad", "E1M1", error));
	old := game.world;
	game.Use;
	game.Use;
	game.Step(1);
	previous := game.Inventory();
	ASSERT((previous.neededKey = DoomInventory.BlueCard) & (previous.keys = {}));
	ASSERT(game.world = old);
	game.Render(frame);
	ASSERT(frame.Save("locked-door-missing.ppm"));
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	player := game.Inventory();
	ASSERT(player.neededKey = DoomInventory.BlueCard);
	game.Controls(0, 1, 0);
	FOR i := 2 TO 7 DO
		game.Step(i)
	END;
	player := game.Inventory();
	ASSERT((player.keys = {DoomInventory.BlueCard}) & (player.pickups = 1));
	ASSERT(player.neededKey = -1);
	ASSERT((previous.keys = {}) & (previous.neededKey = DoomInventory.BlueCard));
	ASSERT(game.world = old);
	game.Controls(0, 0, 0);
	game.Render(frame);
	ASSERT(frame.Save("locked-door-key.ppm"));
	game.Use;
	FOR i := 8 TO 69 DO
		game.Step(i)
	END;
	ASSERT(Ceiling(game.world) = 124.0 / 64);
	game.Render(frame);
	ASSERT(frame.Save("locked-door-open.ppm"));
	game.Controls(1, 0, 0);
	FOR i := 70 TO 109 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT(pose.x > 2);
	player := game.Inventory();
	ASSERT((player.keys = {DoomInventory.BlueCard}) & (player.pickups = 1));
	ASSERT(game.Load("door-key.wad", "E1M1", error));
	player := game.Inventory();
	ASSERT((player.keys = {}) & (player.neededKey = -1) & (player.pickups = 0))
END Gameplay;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	Variant("door-blue.wad", "door-blue-hidden.wad", DoomInventory.BlueCard, FALSE);
	Variant("door-yellow.wad", "door-yellow-hidden.wad", DoomInventory.YellowCard, FALSE);
	Variant("door-red.wad", "door-red-hidden.wad", DoomInventory.RedCard, FALSE);
	Variant("door-blue-open.wad", "door-blue-open-hidden.wad", DoomInventory.BlueCard, TRUE);
	Variant("door-yellow-open.wad", "door-yellow-open-hidden.wad", DoomInventory.YellowCard, TRUE);
	Variant("door-red-open.wad", "door-red-open-hidden.wad", DoomInventory.RedCard, TRUE);
	Blocked("door-blue-no-back.wad");
	Blocked("door-blue-occluded.wad");
	Gameplay
END Do;

END DoomLockedDoorsSmoke.
