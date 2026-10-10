MODULE DoomActorsSmoke;

IMPORT Doom, DoomWad, DoomMap, DoomSprites, DoomInventory, DoomThings, GameSurface;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Solid(CONST path: ARRAY OF CHAR; radius: SIGNED32);
VAR map: DoomMap.Map;
	x, y, feet, contact: FLOAT64;
BEGIN
	Load(path, map);
	contact := 2 - Doom.PlayerRadius - radius / 64.0;
	ASSERT(map.sprites.Free(contact, 0, Doom.PlayerRadius));
	ASSERT(~map.sprites.Free(contact + 0.000001, 0, Doom.PlayerRadius));
	ASSERT(map.sprites.Free(2, Doom.PlayerRadius + radius / 64.0, Doom.PlayerRadius));
	ASSERT(~map.sprites.Free(2, Doom.PlayerRadius + radius / 64.0 - 0.000001, Doom.PlayerRadius));
	ASSERT(~map.sprites.Free(contact + 0.000001, Doom.PlayerRadius + radius / 64.0 - 0.000001,
		Doom.PlayerRadius));
	x := map.x;
	y := map.y;
	feet := map.eye - Doom.PlayerEye;
	ASSERT(map.world.MovePlayerChecked(x, y, feet, 6, 0,
		Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep, map.sprites.Free));
	ASSERT((x <= contact) & (x > contact - Doom.PlayerRadius / 2));
	ASSERT(map.sprites.Free(x, y, Doom.PlayerRadius));
	ASSERT(map.world.MovePlayerChecked(x, y, feet, 1, 1,
		Doom.PlayerRadius, Doom.PlayerHeight, Doom.PlayerStep, map.sprites.Free));
	ASSERT((x > contact) & (y > 0.9));
	ASSERT(map.sprites.Free(x, y, Doom.PlayerRadius))
END Solid;

PROCEDURE Passable(CONST path: ARRAY OF CHAR);
VAR game: Doom.Game;
	pose: Doom.Pose;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load(path, "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 40 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT(pose.x > 3.5)
END Passable;

PROCEDURE Do*;
VAR game: Doom.Game;
	map: DoomMap.Map;
	scene: DoomSprites.Scene;
	player: DoomInventory.State;
	info: DoomThings.Info;
	pose, preserved: Doom.Pose;
	frame: GameSurface.Frame;
	error: ARRAY 128 OF CHAR;
	i: SIGNED32;
BEGIN
	ASSERT(DoomThings.Lookup(2035, info));
	ASSERT(info.radius = 10);
	ASSERT(DoomThings.Lookup(3004, info));
	ASSERT(info.radius = 20);
	ASSERT(DoomThings.Lookup(7, info));
	ASSERT(info.radius = 128);
	ASSERT(DoomThings.Lookup(49, info));
	ASSERT(info.radius = 16);
	ASSERT(DoomThings.Lookup(63, info));
	ASSERT(info.radius = 0);
	ASSERT(DoomThings.Lookup(18, info));
	ASSERT(info.radius = 0);
	Solid("actors-barrel.wad", 10);
	Solid("actors-decoration.wad", 16);
	Solid("actors-hanging.wad", 16);
	Solid("sprite-rotations.wad", 20);
	Passable("actors-corpse.wad");
	Passable("actors-hanging-passable.wad");
	Passable("actors-flags.wad");
	Passable("sprites.wad");
	Load("pickups.wad", map);
	DoomInventory.Reset(player);
	scene := map.sprites.Touch(map.world, 2, 0, 0, Doom.PlayerRadius, Doom.PlayerHeight, player);
	ASSERT((scene # map.sprites) & (player.pickups = 6));
	ASSERT(map.sprites.Free(2, 0, Doom.PlayerRadius));
	ASSERT(scene.Free(2, 0, Doom.PlayerRadius));
	NEW(game);
	ASSERT(game.Load("actors-barrel.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 1 TO 70 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x <= 2 - 26.0 / 64) & (pose.x > 1.5));
	NEW(frame, 320, 200);
	game.Render(frame);
	ASSERT(frame.Save("actors-blocked.ppm"));
	ASSERT(~game.Load("sprite-missing.wad", "E1M1", error));
	preserved := game.State();
	ASSERT((preserved.x = pose.x) & (preserved.y = pose.y));
	game.Step(71);
	preserved := game.State();
	ASSERT(preserved.x = pose.x);
	game.Controls(1, 1, 0);
	FOR i := 72 TO 91 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x > 2) & (pose.y > 1.2));
	game.Render(frame);
	ASSERT(frame.Save("actors-sliding.ppm"));
	ASSERT(game.Load("actors-corpse.wad", "E1M1", error));
	game.Controls(1, 0, 0);
	FOR i := 92 TO 131 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT(pose.x > 3.5);
	ASSERT(game.Load("actors-overlap.wad", "E1M1", error));
	game.Controls(0, 0, 0);
	game.Step(132);
	game.Controls(1, 0, 0);
	game.Step(133);
	pose := game.State();
	ASSERT((pose.x = 0) & (pose.y = 0));
	ASSERT(game.Load("actors-step.wad", "E1M1", error));
	FOR i := 134 TO 203 DO
		game.Step(i)
	END;
	pose := game.State();
	ASSERT((pose.x <= 2 - 26.0 / 64) & (pose.x > 1.5));
	ASSERT(ABS(pose.eye - Doom.PlayerEye - 24.0 / 64) < 0.000001)
END Do;

END DoomActorsSmoke.
