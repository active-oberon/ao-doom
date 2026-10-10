MODULE DoomTexturesSmoke;

IMPORT DoomWad, DoomTextures, GameMaterials;

PROCEDURE Reject(CONST path: ARRAY OF CHAR);
VAR archive: DoomWad.Archive;
	library: DoomTextures.Library;
	texture: GameMaterials.Texture;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open(path, error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	IF library # NIL THEN
		texture := library.Get("WALL", error);
		ASSERT(texture = NIL)
	END;
	ASSERT(error[0] # 0X)
END Reject;

PROCEDURE Do*;
VAR archive: DoomWad.Archive;
	library: DoomTextures.Library;
	texture, same: GameMaterials.Texture;
	error: ARRAY 128 OF CHAR;
BEGIN
	archive := DoomWad.Open("valid.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("WALL", error);
	ASSERT(texture # NIL);
	ASSERT((texture.width = 64) & (texture.height = 64));
	ASSERT(texture.Sample(0.001, 0.001) = 0282018H);
	ASSERT(texture.Sample(0.05, 0.05) = 0C87850H);
	same := library.Get("wall", error);
	ASSERT(same = texture);
	ASSERT(library.Get("MISSING", error) = NIL);
	ASSERT(error[0] # 0X);
	archive := DoomWad.Open("clipped-patch.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("WALL", error);
	ASSERT(texture # NIL);
	ASSERT(texture.Sample(0.001, 0.001) = 0C87850H);
	archive := DoomWad.Open("texture2.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("WALL", error);
	ASSERT(texture # NIL);
	archive := DoomWad.Open("composite.wad", error);
	ASSERT(archive # NIL);
	library := DoomTextures.Open(archive, error);
	ASSERT(library # NIL);
	texture := library.Get("WALL", error);
	ASSERT(texture # NIL);
	ASSERT(texture.Sample(0.001, 0.001) = 0C87850H);
	ASSERT(texture.Sample(63.0 / 64 + 0.001, 0.001) = 0282018H);
	Reject("no-palette.wad");
	Reject("palette-short.wad");
	Reject("pnames-short.wad");
	Reject("pnames-count.wad");
	Reject("texture-count.wad");
	Reject("texture-offset.wad");
	Reject("texture-header.wad");
	Reject("texture-dimensions.wad");
	Reject("texture-patch-index.wad");
	Reject("missing-patch.wad");
	Reject("patch-header.wad");
	Reject("patch-column.wad");
	Reject("patch-no-end.wad");
	Reject("patch-length.wad")
END Do;

END DoomTexturesSmoke.
