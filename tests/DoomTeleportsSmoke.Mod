MODULE DoomTeleportsSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry, GameSurface, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Cross(VAR map: DoomMap.Map; x0, y0, x1, y1: FLOAT64): BOOLEAN;
VAR feet: FLOAT64;
BEGIN
	feet := map.eye - DoomConfig.values.playerEye;
	map.teleports.Observe(map.world, map.sprites, x0, y0, x1, y1);
	IF map.teleports.Take(map.x, map.y, feet, map.angle) THEN
		map.eye := feet + DoomConfig.values.playerEye;
		RETURN TRUE
	END;
	RETURN FALSE
END Cross;

PROCEDURE {TEST} DirectionsAndConsumption*;
VAR map: DoomMap.Map;
	world: GameGeometry.World;
BEGIN
	Load("teleport-39.wad", map);
	world := map.world;
	ASSERT(~Cross(map, -0.5, 5, 0.5, 5));
	ASSERT(map.actions.Special(8) = 39);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.actions.Special(8) = 0);
	ASSERT((map.x = 6) & (map.y = -1));
	ASSERT(ABS(map.angle + MathL.pi / 2) < 0.0000001);
	ASSERT(map.eye = 1 + DoomConfig.values.playerEye);
	ASSERT(map.world = world);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	Load("teleport-39.wad", map);
	ASSERT(~Cross(map, 0.5, 0, -0.5, 0));
	ASSERT(map.actions.Special(8) = 0);
	Load("teleport-97.wad", map);
	ASSERT(~Cross(map, 0.5, 0, -0.5, 0));
	ASSERT(map.actions.Special(8) = 97);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.actions.Special(8) = 97)
END DirectionsAndConsumption;

PROCEDURE {TEST} DestinationSelection*;
VAR map: DoomMap.Map;
BEGIN
	Load("teleport-first.wad", map);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.x = 6) & (map.y = -1));
	Load("teleport-sector-order.wad", map);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.x = 2) & (map.y = -0.5));
	ASSERT(ABS(map.angle + MathL.pi) < 0.0000001);
	Load("teleport-flags.wad", map);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.x = 6) & (map.y = -1));
	Load("teleport-angle.wad", map);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(ABS(map.angle - MathL.pi / 4) < 0.0000001);
	Load("teleport-missing.wad", map);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.actions.Special(8) = 0);
	Load("teleport-outside.wad", map);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	Load("teleport-no-fallback.wad", map);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0))
END DestinationSelection;

PROCEDURE {TEST} SafeLandingAndTelefrags*;
VAR map: DoomMap.Map;
	old: DoomSprites.Scene;
	world: GameGeometry.World;
	heights: ARRAY 3 OF FLOAT64;
	i: SIGNED32;
BEGIN
	Load("teleport-wall.wad", map);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.x = -2) & (map.y = 0));
	Load("teleport-low.wad", map);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	Load("teleport-enemy.wad", map);
	old := map.sprites;
	ASSERT(old.Health(0) > 0);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.sprites.Health(0) = 0);
	ASSERT(old.Health(0) > 0);
	ASSERT(map.sprites.Free(map.x, map.y, DoomConfig.values.playerRadius));
	Load("teleport-multiple.wad", map);
	old := map.sprites;
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.sprites.Health(0) = 0) & (map.sprites.Health(1) = 0));
	ASSERT((old.Health(0) > 0) & (old.Health(1) > 0));
	Load("teleport-decoration.wad", map);
	old := map.sprites;
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.sprites = old);
	ASSERT(map.sprites.Health(0) > 0);
	Load("teleport-enemy.wad", map);
	old := map.sprites;
	FOR i := 0 TO 2 DO heights[i] := map.world.Region(i).ceiling END;
	heights[2] := 1.5;
	map.world := map.world.WithCeilings(heights);
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.sprites = old);
	Load("teleport-39.wad", map);
	world := map.world;
	FOR i := 0 TO 2 DO heights[i] := map.world.Region(i).floor END;
	heights[2] := 0.5;
	map.world := map.world.WithFloors(heights);
	ASSERT(Cross(map, -0.5, 0, 0.5, 0));
	ASSERT(map.eye = 0.5 + DoomConfig.values.playerEye);
	ASSERT(world.Region(2).floor = 1)
END SafeLandingAndTelefrags;

PROCEDURE {TEST} GameMovementAndReaction*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	frame: GameSurface.Frame;
	error: ARRAY 256 OF CHAR;
	i, health, armor: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("teleport-pickup.wad", "E1M1", error));
	health := game.Inventory().health;
	armor := game.Inventory().armor;
	game.Use;
	game.Step(1);
	ASSERT(~game.TakeInteraction().accepted);
	game.Controls(1, 0, 0);
	i := 1;
	WHILE (i < 24) & (game.State().x # 6) DO
		INC(i);
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x = 6) & (pose.y = -1));
	ASSERT(game.Inventory().health = health);
	ASSERT(game.Inventory().armor = armor + 1);
	ASSERT(game.Inventory().pickups = 1);
	game.Controls(1, 0, 1);
	FOR i := 1 TO DoomConfig.values.teleportReactionTicks DO
		game.Step(game.Ticks() + 1);
		ASSERT((game.State().x = pose.x) & (game.State().y = pose.y));
		ASSERT(game.State().angle = pose.angle)
	END;
	game.Controls(1, 0, 0);
	game.Step(game.Ticks() + 1);
	ASSERT(game.State().y < pose.y);
	NEW(frame, 64, 40);
	game.Render(frame);
	ASSERT(game.Load("teleport-remote-exit.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 30 DO game.Step(game.Ticks() + 1) END;
	ASSERT(game.TakeTransition() = NIL);
	ASSERT(game.State().x = 6)
END GameMovementAndReaction;

PROCEDURE {TEST} BlockedMovementAndReplacement*;
VAR game: Doom.Game;
	pose: Doom.Pose;
	world: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("teleport-blocked.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 40 DO game.Step(i) END;
	ASSERT(game.State().x < 0);
	game.Controls(-1, 0, 0);
	FOR i := 41 TO 45 DO game.Step(i) END;
	ASSERT(game.State().x > -2);
	ASSERT(game.Load("teleport-39.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	world := game.world;
	ASSERT(~game.Load("bad-flat.wad", "E1M1", error));
	ASSERT(game.world = world);
	FOR i := 1 TO 24 DO game.Step(game.Ticks() + 1) END;
	pose := game.State();
	ASSERT(pose.x = 6);
	ASSERT(game.Load("sectors.wad", "E1M1", error));
	game.Step(game.Ticks() + 1);
	ASSERT(game.State().x > -2)
END BlockedMovementAndReplacement;

PROCEDURE {TEST} CustomSettings*;
VAR game: Doom.Game;
	map: DoomMap.Map;
	old: DoomSprites.Scene;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	ASSERT(DoomConfig.values.teleportReactionTicks = 3);
	ASSERT(DoomConfig.values.telefragDamage = 1);
	Load("teleport-enemy.wad", map);
	old := map.sprites;
	ASSERT(~Cross(map, -0.5, 0, 0.5, 0));
	ASSERT((map.sprites = old) & (map.sprites.Health(0) > 1));
	NEW(game);
	ASSERT(game.Load("teleport-39.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	i := 0;
	WHILE (i < 20) & (game.State().x # 6) DO
		INC(i);
		game.Step(i)
	END;
	ASSERT(game.State().x = 6);
	FOR i := 1 TO 3 DO game.Step(game.Ticks() + 1) END;
	ASSERT(game.State().y = -1);
	game.Step(game.Ticks() + 1);
	ASSERT(game.State().y < -1);
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSettings;

PROCEDURE Do*;
BEGIN
	DirectionsAndConsumption;
	DestinationSelection;
	SafeLandingAndTelefrags;
	GameMovementAndReaction;
	BlockedMovementAndReplacement;
	CustomSettings
END Do;

END DoomTeleportsSmoke.
