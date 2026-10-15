MODULE DoomSwitchesSmoke;

IMPORT Doom, DoomConfig, DoomMap, DoomWad, DoomInventory, GameGeometry, GameMaterials, Strings, KernelLog, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Front(world: GameGeometry.World; portal: BOOLEAN): GameGeometry.Wall;
VAR wall: GameGeometry.Wall;
	distance: FLOAT64;
BEGIN
	IF portal THEN
		ASSERT(world.CastSector(0, -0.5, 0, 1, 0, 0, distance, wall))
	ELSE
		ASSERT(world.CastSector(0, -3.5, 0, -1, 0, 0, distance, wall))
	END;
	RETURN wall
END Front;

PROCEDURE Variant(special: SIGNED32; floor, repeat, locked: BOOLEAN);
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	old: GameGeometry.World;
	texture: GameMaterials.Texture;
	i, line: SIGNED32;
	path: ARRAY 64 OF CHAR;
	number: ARRAY 12 OF CHAR;
BEGIN
	COPY("switch-", path);
	Strings.IntToStr(special, number);
	Strings.Append(path, number);
	Strings.Append(path, ".wad");
	Load(path, map);
	old := map.world;
	texture := Front(old, FALSE).texture;
	DoomInventory.Reset(player);
	IF locked THEN
		ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
		map.actions.Step(map.world);
		ASSERT(map.world = old);
		player.keys := {0..5}
	END;
	IF special = 24 THEN
		map.sprites := map.sprites.ShootAimObserved(map.world, map.x, map.y, map.angle, map.eye, 0,
			8, 1, map.floors.Shot)
	ELSIF special = 46 THEN
		map.sprites := map.sprites.ShootAimObserved(map.world, map.x, map.y, map.angle, map.eye, 0,
			8, 1, map.doors.Shot)
	ELSIF (special = 11) OR (special = 51) THEN
		ASSERT(map.exits.Use(map.world, map.x, map.y, map.angle));
		ASSERT(map.exits.Take(line) # 0)
	ELSIF floor THEN
		ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle))
	ELSE
		ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player))
	END;
	ASSERT(map.world = old);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture # texture);
	ASSERT(Front(map.world, FALSE).texture.Sample(0.2, 0.2) # texture.Sample(0.2, 0.2));
	ASSERT(Front(old, FALSE).texture = texture);
	FOR i := 2 TO DoomConfig.values.buttonTicks DO
		map.actions.Step(map.world)
	END;
	ASSERT((Front(map.world, FALSE).texture = texture) = repeat);
	IF (special # 11) & (special # 51) THEN
		ASSERT((map.actions.Special(7) = special) = repeat)
	END
END Variant;

PROCEDURE {TEST} ActionBindings*;
BEGIN
	Variant(11, FALSE, FALSE, FALSE);
	Variant(51, FALSE, FALSE, FALSE);
	Variant(18, TRUE, FALSE, FALSE);
	Variant(21, TRUE, FALSE, FALSE);
	Variant(23, TRUE, FALSE, FALSE);
	Variant(24, TRUE, FALSE, FALSE);
	Variant(45, TRUE, TRUE, FALSE);
	Variant(60, TRUE, TRUE, FALSE);
	Variant(62, TRUE, TRUE, FALSE);
	Variant(64, TRUE, TRUE, FALSE);
	Variant(69, TRUE, TRUE, FALSE);
	Variant(101, TRUE, FALSE, FALSE);
	Variant(102, TRUE, FALSE, FALSE);
	Variant(122, TRUE, FALSE, FALSE);
	Variant(123, TRUE, TRUE, FALSE);
	Variant(29, FALSE, FALSE, FALSE);
	Variant(42, FALSE, TRUE, FALSE);
	Variant(46, FALSE, TRUE, FALSE);
	Variant(50, FALSE, FALSE, FALSE);
	Variant(61, FALSE, TRUE, FALSE);
	Variant(63, FALSE, TRUE, FALSE);
	Variant(99, FALSE, TRUE, TRUE);
	Variant(103, FALSE, FALSE, FALSE);
	Variant(111, FALSE, FALSE, FALSE);
	Variant(112, FALSE, FALSE, FALSE);
	Variant(113, FALSE, FALSE, FALSE);
	Variant(114, FALSE, TRUE, FALSE);
	Variant(115, FALSE, TRUE, FALSE);
	Variant(116, FALSE, TRUE, FALSE);
	Variant(133, FALSE, FALSE, TRUE);
	Variant(134, FALSE, TRUE, TRUE);
	Variant(135, FALSE, FALSE, TRUE);
	Variant(136, FALSE, TRUE, TRUE);
	Variant(137, FALSE, FALSE, TRUE)
END ActionBindings;

PROCEDURE {TEST} ButtonTimingAndBusyShots*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	texture: GameMaterials.Texture;
	i: SIGNED32;
BEGIN
	Load("switch-46.wad", map);
	texture := Front(map.world, FALSE).texture;
	ASSERT(map.actions.Claim(1));
	map.doors.Shot(map.world, 7);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture # texture);
	map.doors.Shot(map.world, 7);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture = texture);
	map.doors.Shot(map.world, 7);
	FOR i := 3 TO DoomConfig.values.buttonTicks - 1 DO
		map.actions.Step(map.world)
	END;
	ASSERT(Front(map.world, FALSE).texture # texture);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture = texture);
	Load("switch-24.wad", map);
	texture := Front(map.world, FALSE).texture;
	ASSERT(map.actions.Claim(1));
	map.floors.Shot(map.world, 7);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture # texture);
	ASSERT(map.actions.Special(7) = 0);
	Load("switch-button.wad", map);
	texture := Front(map.world, FALSE).texture;
	ASSERT(map.actions.Claim(1));
	DoomInventory.Reset(player);
	ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture = texture)
END ButtonTimingAndBusyShots;

PROCEDURE {TEST} PartsAndInitialState*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	before, after, back: GameGeometry.Wall;
	distance: FLOAT64;
	i: SIGNED32;
BEGIN
	DoomInventory.Reset(player);
	Load("switch-upper.wad", map);
	before := Front(map.world, TRUE);
	ASSERT(map.world.CastSector(1, 0.5, 0, -1, 0, 0, distance, back));
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	after := Front(map.world, TRUE);
	ASSERT(after.upper # before.upper);
	ASSERT(after.texture = before.texture);
	ASSERT(map.world.CastSector(1, 0.5, 0, -1, 0, 0, distance, before));
	ASSERT(before.upper = back.upper);
	Load("switch-lower.wad", map);
	before := Front(map.world, TRUE);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	ASSERT(Front(map.world, TRUE).lower # before.lower);
	Load("switch-on.wad", map);
	before := Front(map.world, FALSE);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture # before.texture);
	FOR i := 2 TO DoomConfig.values.buttonTicks DO
		map.actions.Step(map.world)
	END;
	ASSERT(Front(map.world, FALSE).texture = before.texture)
END PartsAndInitialState;

PROCEDURE {TEST} GameAndFailedReplacement*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	texture: GameMaterials.Texture;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("switch-button.wad", "E1M1", error));
	old := game.world;
	texture := Front(old, FALSE).texture;
	game.Use;
	game.Step(1);
	ASSERT(Front(game.world, FALSE).texture # texture);
	ASSERT(~game.Load("switch-missing.wad", "E1M1", error));
	ASSERT(error[0] # 0X);
	ASSERT(Front(game.world, FALSE).texture # texture);
	ASSERT(~game.Load("switch-corrupt.wad", "E1M1", error));
	ASSERT(error[0] # 0X);
	FOR i := 2 TO DoomConfig.values.buttonTicks DO
		game.Step(i)
	END;
	ASSERT(Front(game.world, FALSE).texture = texture);
	ASSERT(Front(old, FALSE).texture = texture);
	ASSERT(game.Load("switch-custom.wad", "E1M1", error));
	texture := Front(game.world, FALSE).texture;
	game.Use;
	game.Step(36);
	ASSERT(Front(game.world, FALSE).texture = texture);
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	ASSERT(game.Load("switch-custom.wad", "E1M1", error));
	texture := Front(game.world, FALSE).texture;
	game.Use;
	game.Step(37);
	ASSERT(Front(game.world, FALSE).texture # texture);
	FOR i := 38 TO 40 DO
		game.Step(i)
	END;
	ASSERT(Front(game.world, FALSE).texture = texture);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END GameAndFailedReplacement;

PROCEDURE {TEST} ManualAndCrossings*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	texture: GameMaterials.Texture;
BEGIN
	DoomInventory.Reset(player);
	Load("switch-manual.wad", map);
	texture := Front(map.world, TRUE).texture;
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	ASSERT(Front(map.world, TRUE).texture = texture);
	Load("switch-walk.wad", map);
	texture := Front(map.world, TRUE).texture;
	map.doors.Crossed(-0.5, 0, 0.5, 0);
	map.doors.ApplyCrossings(map.world);
	map.actions.Step(map.world);
	ASSERT(Front(map.world, TRUE).texture = texture)
END ManualAndCrossings;

PROCEDURE {TEST} SharedSidesAndPriority*;
VAR map: DoomMap.Map;
	player: DoomInventory.State;
	before, after, shared: GameGeometry.Wall;
	distance: FLOAT64;
BEGIN
	DoomInventory.Reset(player);
	Load("switch-shared.wad", map);
	before := Front(map.world, FALSE);
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	after := Front(map.world, FALSE);
	ASSERT(after.texture # before.texture);
	ASSERT(map.world.CastSector(0, -3.5, 0, 0, -1, 0, distance, shared));
	ASSERT(shared.texture = after.texture);
	Load("switch-priority.wad", map);
	before := Front(map.world, TRUE);
	ASSERT(~map.doors.Use(map.world, 0.5, 0, -MathL.pi, player));
	ASSERT(map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	after := Front(map.world, TRUE);
	ASSERT(after.upper # before.upper);
	ASSERT(after.texture = before.texture);
	Load("switch-no-target.wad", map);
	before := Front(map.world, FALSE);
	ASSERT(~map.doors.Use(map.world, map.x, map.y, map.angle, player));
	map.actions.Step(map.world);
	ASSERT(Front(map.world, FALSE).texture = before.texture)
END SharedSidesAndPriority;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	ActionBindings;
	ButtonTimingAndBusyShots;
	PartsAndInitialState;
	GameAndFailedReplacement;
	ManualAndCrossings;
	SharedSidesAndPriority;
	KernelLog.String("DoomSwitchesSmoke: switch materials and button checks passed.");
	KernelLog.Ln
END Do;

END DoomSwitchesSmoke.
