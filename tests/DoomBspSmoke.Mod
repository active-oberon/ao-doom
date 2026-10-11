MODULE DoomBspSmoke;

IMPORT DoomConfig, DoomWad, DoomMap, GameSurface, GameRenderer, MathL;

PROCEDURE Load(CONST path: ARRAY OF CHAR; VAR map: DoomMap.Map);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error))
END Load;

PROCEDURE Reject(CONST path: ARRAY OF CHAR);
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(map.world = NIL);
	ASSERT(error[0] # 0X)
END Reject;

PROCEDURE Do*;
VAR map: DoomMap.Map;
	frame: GameSurface.Frame;
	x, y, feet: FLOAT64;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	Load("bsp-sectors.wad", map);
	ASSERT(map.world.Locate(-2, 0) = 0);
	ASSERT(map.world.Locate(2, 0) = 1);
	ASSERT(map.world.Locate(6, 0) = 2);
	ASSERT(map.world.Locate(0, 0) = 0);
	ASSERT(map.world.Locate(4, 0) = 1);
	ASSERT(map.world.Locate(9, 0) = -1);
	ASSERT(map.world.Contains(1, 2, 0));
	ASSERT(~map.world.Contains(0, 2, 0));
	NEW(frame, 320, 200);
	GameRenderer.Render(map.world, frame, map.x, map.y, map.angle, map.eye);
	ASSERT(frame.Pixel(160, 100) # 0202938H);
	GameRenderer.Render(map.world, frame, 0, 0, 0, map.eye + DoomConfig.values.playerStep);
	ASSERT((frame.Pixel(160, 100) # 0202938H) & (frame.Pixel(160, 100) # 035302CH));
	GameRenderer.Render(map.world, frame, 0, 0, MathL.pi, map.eye + DoomConfig.values.playerStep);
	ASSERT((frame.Pixel(160, 100) # 0202938H) & (frame.Pixel(160, 100) # 035302CH));
	x := map.x;
	y := map.y;
	feet := 0;
	ASSERT(map.world.MovePlayer(x, y, feet, 4, 0, DoomConfig.values.playerRadius, DoomConfig.values.playerHeight, DoomConfig.values.playerStep));
	ASSERT((ABS(x - 2) < 0.000001) & (feet = DoomConfig.values.playerStep));
	Load("bsp-unused-sector.wad", map);
	ASSERT(map.world.SectorCount() = 4);
	ASSERT(map.world.Locate(-2, 0) = 0);
	ASSERT(~map.world.Contains(3, -2, 0));
	Load("bsp-open-sector.wad", map);
	ASSERT(map.world.Locate(6, 0) = 2);
	Load("bsp-mixed-subsector.wad", map);
	ASSERT(map.world.Locate(-2, 0) = 0);
	Load("bsp-single.wad", map);
	ASSERT(map.world.Locate(0, 0) = 0);
	ASSERT(map.world.Locate(20, 0) = -1);
	Reject("bsp-bad-seg-stride.wad");
	Reject("bsp-bad-sub-stride.wad");
	Reject("bsp-bad-node-stride.wad");
	Reject("bsp-no-segs.wad");
	Reject("bsp-no-subsectors.wad");
	Reject("bsp-no-nodes.wad");
	Reject("bsp-bad-seg-vertex.wad");
	Reject("bsp-bad-seg-line.wad");
	Reject("bsp-bad-seg-side.wad");
	Reject("bsp-missing-seg-side.wad");
	Reject("bsp-empty-subsector.wad");
	Reject("bsp-bad-sub-range.wad");
	Reject("bsp-bad-leaf.wad");
	Reject("bsp-self-cycle.wad");
	Reject("bsp-forward-child.wad");
	Reject("bsp-zero-direction.wad");
	Reject("bsp-large-tree.wad");
	Reject("bsp-outside-start.wad")
END Do;

END DoomBspSmoke.
