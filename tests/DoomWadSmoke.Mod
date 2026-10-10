MODULE DoomWadSmoke;

IMPORT DoomWad, DoomMap, GameGeometry, MathL;

PROCEDURE RejectArchive(CONST path: ARRAY OF CHAR);
VAR archive: DoomWad.Archive;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive = NIL);
	ASSERT(error[0] # 0X)
END RejectArchive;

PROCEDURE RejectMap(CONST path: ARRAY OF CHAR);
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	ASSERT(~DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(map.world = NIL);
	ASSERT(error[0] # 0X)
END RejectMap;

PROCEDURE Do*;
VAR archive: DoomWad.Archive;
	map: DoomMap.Map;
	error: ARRAY 128 OF CHAR;
	wall: GameGeometry.Wall;
	distance: FLOAT64;
BEGIN
	RejectArchive("missing.wad");
	RejectArchive("short.wad");
	RejectArchive("magic.wad");
	RejectArchive("negative-count.wad");
	RejectArchive("huge-count.wad");
	RejectArchive("directory.wad");
	RejectArchive("lump-range.wad");
	RejectArchive("negative-lump.wad");
	archive := DoomWad.Open("duplicates.wad", error);
	ASSERT(archive # NIL);
	ASSERT(archive.Find("TeSt") = 1);
	ASSERT(archive.Find("DOESNOTEXIST") = -1);
	archive := DoomWad.Open("iwad.wad", error);
	ASSERT(archive # NIL);
	archive := DoomWad.Open("valid.wad", error);
	ASSERT(archive # NIL);
	ASSERT(archive.Count() = 19);
	ASSERT(DoomMap.LoadMap(archive, "e1m1", map, error));
	ASSERT(map.world.Count() = 8);
	ASSERT((map.x = 0) & (map.y = 0) & (map.angle = 0));
	ASSERT(ABS(map.eye - 41.0 / 64) < 0.000001);
	ASSERT(map.world.Cast(0, 0, 1, 0, distance, wall));
	ASSERT(ABS(distance - 4) < 0.000001);
	ASSERT(map.world.Cast(0, 0, MathL.cos(-MathL.pi / 4),
		MathL.sin(-MathL.pi / 4), distance, wall));
	ASSERT(distance < 2);
	ASSERT(~DoomMap.LoadMap(archive, "MAP01", map, error));
	archive := DoomWad.Open("no-textures.wad", error);
	ASSERT(archive # NIL);
	ASSERT(DoomMap.LoadMap(archive, "E1M1", map, error));
	ASSERT(map.world.Cast(0, 0, 1, 0, distance, wall));
	ASSERT(wall.texture = NIL);
	RejectMap("bad-vertex.wad");
	RejectMap("bad-side.wad");
	RejectMap("bad-sector.wad");
	RejectMap("no-start.wad");
	RejectMap("wall-start.wad");
	RejectMap("outside-start.wad");
	RejectMap("hole-start.wad");
	RejectMap("bad-stride.wad");
	RejectMap("multi-sector.wad");
	RejectMap("low-ceiling.wad");
	RejectMap("open-boundary.wad");
	RejectMap("open-sector.wad");
	RejectMap("bad-two-sided.wad");
	RejectMap("bad-flat.wad");
	RejectMap("missing-flat.wad")
END Do;

END DoomWadSmoke.
