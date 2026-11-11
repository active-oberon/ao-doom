MODULE DoomRaiseChangesSmoke;

IMPORT DoomConfig, Doom, DoomMap, DoomWad, DoomSprites, GameGeometry, GameMaterials, GameSurface, GameRenderer;

TYPE Carrier = OBJECT
VAR scene: DoomSprites.Scene;

	PROCEDURE Follow(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
	VAR candidate: DoomSprites.Scene;
	BEGIN
		candidate := scene.FollowFloors(before, after, sector);
		IF candidate = NIL THEN
			RETURN FALSE
		END;
		scene := candidate;
		RETURN TRUE
	END Follow;
END Carrier;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Cross(VAR map: DoomMap.Map);
BEGIN
	map.floors.Crossed(-0.5, 0, 0.5, 0);
	map.floors.ApplyCrossings(map.world)
END Cross;

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

PROCEDURE Variant(CONST path: ARRAY OF CHAR; special: SIGNED32);
VAR map: DoomMap.Map;
	old, changed: GameGeometry.World;
	texture: GameMaterials.Texture;
	frame: GameSurface.Frame;
	pixel: SIGNED32;
BEGIN
	Load(path, map);
	old := map.world;
	texture := old.Region(0).floorTexture;
	ASSERT(texture # old.Region(1).floorTexture);
	ASSERT(texture # old.Region(2).floorTexture);
	ASSERT(~map.floors.Use(map.world, map.x, map.y, map.angle));
	map.floors.Shot(map.world, 8);
	map.floors.Crossed(-0.5, 5, 0.5, 5);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 1);
	ASSERT(map.world = old);
	Cross(map);
	changed := map.world;
	ASSERT(changed.Region(2).floor = 0);
	ASSERT(changed.Region(2).floorTexture = texture);
	ASSERT(map.floors.SectorSpecial(2) = 5);
	ASSERT(map.floors.SectorSpecial(1) = 7);
	ASSERT(~map.actions.Claim(2));
	IF special = 59 THEN
		ASSERT(map.actions.Special(8) = 0)
	ELSE
		ASSERT(map.actions.Special(8) = special)
	END;
	(* Only the material changed: compare pixels from the same height snapshot. *)
	NEW(frame, 32, 20);
	GameRenderer.Render(old, frame, 5, 0, 0, 0.3);
	pixel := frame.Pixel(16, 19);
	GameRenderer.Render(changed, frame, 5, 0, 0, 0.3);
	ASSERT(frame.Pixel(16, 19) # pixel);
	GameRenderer.Render(old, frame, 5, 0, 0, 0.3);
	ASSERT(frame.Pixel(16, 19) = pixel);
	Advance(map, 23);
	ASSERT(map.world.Region(2).floor = 23.0 / 64);
	Cross(map);
	Advance(map, 1);
	ASSERT(map.world.Region(2).floor = 24.0 / 64);
	ASSERT(map.world.Region(2).floorTexture = texture);
	ASSERT(map.actions.Claim(2));
	map.actions.Release(2);
	ASSERT(changed.Region(2).floor = 0);
	ASSERT(old.Region(2).floorTexture # texture);
	(* Both crossing directions use the linedef's authored front sector. *)
	map.floors.Crossed(0.5, 0, -0.5, 0);
	map.floors.ApplyCrossings(map.world);
	Advance(map, 24);
	IF special = 59 THEN
		ASSERT(map.world.Region(2).floor = 24.0 / 64)
	ELSE
		ASSERT(map.world.Region(2).floor = 48.0 / 64)
	END
END Variant;

PROCEDURE {TEST} ImmediateSurfaceAndCrossings*;
BEGIN
	Variant("floor-raise-change-59.wad", 59);
	Variant("floor-raise-change-93.wad", 93)
END ImmediateSurfaceAndCrossings;

PROCEDURE {TEST} FrontModelAndRepeat*;
VAR map: DoomMap.Map;
	texture, replacement: GameMaterials.Texture;
BEGIN
	Load("floor-raise-change-reversed.wad", map);
	texture := map.world.Region(1).floorTexture;
	Cross(map);
	ASSERT(map.world.Region(2).floorTexture = texture);
	ASSERT(map.floors.SectorSpecial(2) = 7);
	Load("floor-raise-change-93.wad", map);
	texture := map.world.Region(0).floorTexture;
	replacement := map.world.Region(1).floorTexture;
	Cross(map);
	map.world := map.world.WithFloorTexture(0, replacement);
	Cross(map);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floorTexture = texture);
	Cross(map);
	ASSERT(map.world.Region(2).floorTexture = replacement);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 48.0 / 64);
	ASSERT(map.world.Region(2).floorTexture = replacement);
	Load("floor-raise-change-untextured.wad", map);
	Cross(map);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floorTexture = NIL);
	ASSERT(map.floors.SectorSpecial(2) = 5)
END FrontModelAndRepeat;

PROCEDURE {TEST} BusyTargets*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("floor-raise-change-59.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(2));
	Cross(map);
	ASSERT(map.world = old);
	ASSERT(map.floors.SectorSpecial(2) = 9);
	ASSERT(map.actions.Special(8) = 0);
	map.actions.Release(2);
	Cross(map);
	Advance(map, 24);
	ASSERT(map.world = old);
	Load("floor-raise-change-93.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(2));
	Cross(map);
	ASSERT(map.world = old);
	ASSERT(map.floors.SectorSpecial(2) = 9);
	ASSERT(map.actions.Special(8) = 93);
	map.actions.Release(2);
	Cross(map);
	ASSERT(map.floors.SectorSpecial(2) = 5);
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 24.0 / 64);
	Load("floor-raise-change-no-tag.wad", map);
	old := map.world;
	Cross(map);
	Advance(map, 24);
	ASSERT(map.world = old)
END BusyTargets;

PROCEDURE Reject(before, after: GameGeometry.World; sector: SIGNED32): BOOLEAN;
BEGIN
	RETURN FALSE
END Reject;

PROCEDURE {TEST} BlockedMotionKeepsSurface*;
VAR map: DoomMap.Map;
	changed: GameGeometry.World;
	feet: FLOAT64;
BEGIN
	Load("floor-raise-change-93.wad", map);
	Cross(map);
	changed := map.world;
	feet := 0;
	map.floors.Step(map.world, map.x, map.y, DoomConfig.values.playerRadius, feet,
		DoomConfig.values.playerHeight, DoomConfig.values.playerStep, Reject);
	ASSERT(map.world = changed);
	ASSERT(map.world.Region(2).floor = 0);
	ASSERT(map.world.Region(2).floorTexture = map.world.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(2) = 5);
	ASSERT(~map.actions.Claim(2));
	Advance(map, 24);
	ASSERT(map.world.Region(2).floor = 24.0 / 64);
	ASSERT(map.actions.Claim(2))
END BlockedMotionKeepsSurface;

PROCEDURE {TEST} GroupedAndSelfModel*;
VAR map: DoomMap.Map;
	old: GameGeometry.World;
BEGIN
	Load("floor-raise-change-grouped.wad", map);
	old := map.world;
	ASSERT(map.actions.Claim(1));
	Cross(map);
	ASSERT(map.world.Region(1).floorTexture = old.Region(1).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 7);
	ASSERT(map.world.Region(2).floorTexture = old.Region(0).floorTexture);
	map.actions.Release(1);
	Advance(map, 24);
	Cross(map);
	ASSERT(map.world.Region(1).floorTexture = old.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(1) = 5);
	Advance(map, 24);
	ASSERT(map.world.Region(1).floor = 24.0 / 64);
	ASSERT(map.world.Region(2).floor = 48.0 / 64);
	Load("floor-raise-change-self-model.wad", map);
	old := map.world;
	Cross(map);
	Advance(map, 24);
	ASSERT(map.world.Region(0).floor = 24.0 / 64);
	ASSERT(map.world.Region(2).floor = 24.0 / 64);
	ASSERT(map.world.Region(2).floorTexture = old.Region(0).floorTexture);
	ASSERT(map.floors.SectorSpecial(0) = 5);
	ASSERT(map.floors.SectorSpecial(2) = 5)
END GroupedAndSelfModel;

PROCEDURE {TEST} StairNamesAndValidation*;
VAR map: DoomMap.Map;
	archive: DoomWad.Archive;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	Load("floor-raise-change-stairs.wad", map);
	FOR i := 1 TO 4 DO
		ASSERT(map.floors.Moving(i))
	END;
	Cross(map);
	Advance(map, 24);
	ASSERT(map.floors.Use(map.world, map.x, map.y, map.angle));
	Advance(map, 22);
	FOR i := 1 TO 4 DO
		ASSERT(map.world.Region(i).floor = (24 + i * 16.0) / 64)
	END;
	archive := DoomWad.Open("floor-raise-change-stairs-hidden.wad", error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT((map.world = NIL) & (error[0] # 0X))
END StairNamesAndValidation;

PROCEDURE {TEST} Riding*;
VAR map: DoomMap.Map;
	carrier: Carrier;
	old: DoomSprites.Scene;
	feet: FLOAT64;
	i: SIGNED32;
BEGIN
	Load("floor-raise-change-actors.wad", map);
	NEW(carrier);
	carrier.scene := map.sprites;
	old := carrier.scene;
	Cross(map);
	feet := 0;
	FOR i := 1 TO 24 DO
		map.floors.Step(map.world, 1, -1, DoomConfig.values.playerRadius, feet,
			DoomConfig.values.playerHeight, DoomConfig.values.playerStep, carrier.Follow)
	END;
	ASSERT(feet = 24.0 / 64);
	ASSERT(carrier.scene.State(0).feet = feet);
	ASSERT(old.State(0).feet = 0)
END Riding;

PROCEDURE {TEST} AcceptedMovementAndReplacement*;
VAR game: Doom.Game;
	old: GameGeometry.World;
	error: ARRAY 256 OF CHAR;
	i: SIGNED32;
BEGIN
	NEW(game);
	ASSERT(game.Load("floor-raise-change-riding.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 1 TO 10 DO
		game.Step(i)
	END;
	ASSERT(game.State().x > 0);
	ASSERT(game.world.Region(1).floorTexture = old.Region(0).floorTexture);
	game.Controls(0, 0, 0);
	ASSERT(~game.Load("bad-vertex.wad", "E1M1", error));
	FOR i := 11 TO 40 DO
		game.Step(i)
	END;
	ASSERT(game.world.Region(1).floor = 24.0 / 64);
	ASSERT(game.State().eye = 24.0 / 64 + DoomConfig.values.playerEye);
	ASSERT(old.Region(1).floor = 0);
	ASSERT(game.Load("floor-raise-change-blocked.wad", "E1M1", error));
	old := game.world;
	game.Controls(1, 0, 0);
	FOR i := 41 TO 80 DO
		game.Step(i)
	END;
	ASSERT(game.State().x < 0);
	ASSERT(game.world.Region(1).floor = 1.5);
	ASSERT(game.world.Region(1).floorTexture = old.Region(1).floorTexture);
	ASSERT(game.Load("floor-raise-change-riding.wad", "E1M1", error));
	ASSERT(game.world.Region(1).floor = 0);
	ASSERT(game.world.Region(1).floorTexture # game.world.Region(0).floorTexture)
END AcceptedMovementAndReplacement;

PROCEDURE {TEST} CustomSettings*;
VAR map: DoomMap.Map;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	Load("floor-raise-change-93.wad", map);
	Cross(map);
	ASSERT(map.floors.SectorSpecial(2) = 5);
	Advance(map, 1);
	ASSERT(map.world.Region(2).floor = 2.0 / 64);
	Advance(map, 7);
	ASSERT(map.world.Region(2).floor = 16.0 / 64);
	ASSERT(map.actions.Claim(2));
	ASSERT(DoomConfig.Load("doom.yaml", error))
END CustomSettings;

PROCEDURE Do*;
VAR error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom.yaml", error));
	ImmediateSurfaceAndCrossings;
	FrontModelAndRepeat;
	BusyTargets;
	BlockedMotionKeepsSurface;
	GroupedAndSelfModel;
	StairNamesAndValidation;
	Riding;
	AcceptedMovementAndReplacement;
	CustomSettings
END Do;

END DoomRaiseChangesSmoke.
