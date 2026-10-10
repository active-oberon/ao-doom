#!/usr/bin/env python3
"""wad_fixtures creates original test data without distributing Doom assets."""

import pathlib
import struct
import sys


def wad(lumps, magic=b"PWAD"):
    payload = bytearray()
    directory = bytearray()
    for name, data in lumps:
        directory.extend(struct.pack("<ii8s", 12 + len(payload), len(data), name.encode()))
        payload.extend(data)
    return magic + struct.pack("<ii", len(lumps), 12 + len(payload)) + payload + directory


def resources():
    palette = bytearray(768)
    palette[3:6] = bytes((40, 32, 24))
    palette[6:9] = bytes((200, 120, 80))
    columns = []
    for x in range(64):
        values = bytes(1 if y % 16 < 2 or (x + (y // 16 % 2) * 16) % 32 < 2
                       else 2 for y in range(64))
        columns.append(bytes((0, 64, 0)) + values + bytes((0, 255)))
    offsets = []
    offset = 8 + 64 * 4
    for column in columns:
        offsets.append(offset)
        offset += len(column)
    patch = struct.pack("<hhhh", 64, 64, 0, 0)
    patch += struct.pack("<64i", *offsets) + b"".join(columns)
    definition = struct.pack("<8sIhhIh", b"WALL", 0, 64, 64, 0, 1)
    definition += struct.pack("<hhhhh", 0, 0, 0, 1, 0)
    return [("PLAYPAL", bytes(palette)),
            ("PNAMES", struct.pack("<i8s", 1, b"PATCH001")),
            ("PATCH001", patch),
            ("TEXTURE1", struct.pack("<ii", 1, 8) + definition)]


def map_lumps():
    vertices = [(-256, -256), (256, -256), (256, 256), (-256, 256),
                (64, 64), (128, 64), (128, 128), (64, 128)]
    edges = [(0, 1), (1, 2), (2, 3), (3, 0),
             (4, 5), (5, 6), (6, 7), (7, 4)]
    return [
        ("E1M1", b""),
        ("THINGS", struct.pack("<hhhhh", 0, 0, 0, 1, 7)),
        ("LINEDEFS", b"".join(struct.pack("<HHHHHHH", a, b, 1, 0, 0, 0, 65535)
                              for a, b in edges)),
        ("SIDEDEFS", struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"WALL", 0)),
        ("VERTEXES", b"".join(struct.pack("<hh", x, y) for x, y in vertices)),
        ("SEGS", b""), ("SSECTORS", b""), ("NODES", b""),
        ("SECTORS", struct.pack("<hh8s8shhh", 0, 128, b"FLOOR", b"CEILING", 192, 0, 0)),
        ("REJECT", b""), ("BLOCKMAP", b""),
    ] + resources()


def fixtures(directory):
    directory.mkdir(parents=True, exist_ok=True)
    lumps = map_lumps()
    valid = wad(lumps)
    files = {"valid.wad": valid, "iwad.wad": wad(lumps, b"IWAD"),
             "short.wad": b"PWAD", "magic.wad": wad(lumps, b"NOPE"),
             "negative-count.wad": b"PWAD" + struct.pack("<ii", -1, 12),
             "huge-count.wad": b"PWAD" + struct.pack("<ii", 2147483647, 12),
             "directory.wad": b"PWAD" + struct.pack("<ii", 1, 2147483647),
             "lump-range.wad": b"PWAD" + struct.pack("<ii", 1, 12) +
             struct.pack("<ii8s", 2147483647, 2147483647, b"BAD"),
             "negative-lump.wad": b"PWAD" + struct.pack("<ii", 1, 12) +
             struct.pack("<ii8s", -1, 0, b"BAD"),
             "duplicates.wad": wad([("TEST", b"first"), ("test", b"last")])}
    variants = {
        "bad-vertex.wad": (2, struct.pack("<HHHHHHH", 65535, 1, 1, 0, 0, 0, 65535)),
        "bad-side.wad": (2, struct.pack("<HHHHHHH", 0, 1, 1, 0, 0, 99, 65535)),
        "bad-sector.wad": (3, struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"WALL", 1)),
        "no-start.wad": (1, struct.pack("<hhhhh", 0, 0, 0, 2, 7)),
        "wall-start.wad": (1, struct.pack("<hhhhh", 256, 0, 0, 1, 7)),
        "outside-start.wad": (1, struct.pack("<hhhhh", 1000, 1000, 0, 1, 7)),
        "hole-start.wad": (1, struct.pack("<hhhhh", 96, 96, 0, 1, 7)),
        "bad-stride.wad": (4, b"abc"),
        "multi-sector.wad": (8, lumps[8][1] * 2),
        "low-ceiling.wad": (8, struct.pack("<hh8s8shhh", 0, 32, b"F", b"C", 192, 0, 0)),
        "open-boundary.wad": (2, lumps[2][1][14:]),
    }
    for name, (index, data) in variants.items():
        modified = list(lumps)
        modified[index] = (modified[index][0], data)
        files[name] = wad(modified)
    texture_variants = {
        "palette-short.wad": (11, lumps[11][1][:767]),
        "pnames-short.wad": (12, b"abc"),
        "pnames-count.wad": (12, struct.pack("<i", 2147483647)),
        "texture-count.wad": (14, struct.pack("<i", -1)),
        "texture-offset.wad": (14, struct.pack("<ii", 1, 2147483647)),
        "texture-header.wad": (14, struct.pack("<ii", 1, 8) + b"WALL"),
        "missing-patch.wad": (12, struct.pack("<i8s", 1, b"MISSING")),
        "patch-header.wad": (13, b"abc"),
        "patch-no-end.wad": (13, lumps[13][1][:-1]),
    }
    def changed(data, offset, value):
        return data[:offset] + value + data[offset + len(value):]
    texture_variants.update({
        "texture-dimensions.wad": (14, changed(lumps[14][1], 20, struct.pack("<h", 0))),
        "texture-patch-index.wad": (14, changed(lumps[14][1], 34, struct.pack("<H", 65535))),
        "patch-column.wad": (13, changed(lumps[13][1], 8, struct.pack("<i", 2147483647))),
        "patch-length.wad": (13, changed(lumps[13][1], 265, bytes((255,)))),
        "clipped-patch.wad": (14, changed(lumps[14][1], 30, struct.pack("<hh", -3, -3))),
    })
    for name, (index, data) in texture_variants.items():
        modified = list(lumps)
        modified[index] = (modified[index][0], data)
        files[name] = wad(modified)
    files["no-palette.wad"] = wad([lump for lump in lumps if lump[0] != "PLAYPAL"])
    files["no-textures.wad"] = wad(lumps[:11])
    files["texture2.wad"] = wad(lumps[:14] + [("TEXTURE1", struct.pack("<i", 0)),
                                           ("TEXTURE2", lumps[14][1])])
    composite = struct.pack("<8sIhhIh", b"WALL", 0, 64, 64, 0, 2)
    composite += struct.pack("<hhhhh", 0, 0, 0, 1, 0)
    composite += struct.pack("<hhhhh", -3, -3, 0, 1, 0)
    files["composite.wad"] = wad(lumps[:14] + [("TEXTURE1", struct.pack("<ii", 1, 8) + composite)])
    for name, data in files.items():
        (directory / name).write_bytes(data)
    print(f"Generated {len(files)} original WAD fixtures in {directory}")


if __name__ == "__main__":
    fixtures(pathlib.Path(sys.argv[1]))
