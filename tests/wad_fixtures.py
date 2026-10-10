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
    palette[9:12] = bytes((64, 160, 80))
    palette[12:15] = bytes((80, 96, 176))
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
            ("TEXTURE1", struct.pack("<ii", 1, 8) + definition),
            ("F_START", b""),
            ("FLOOR", bytes(1 if (x // 8 + y // 8) % 2 else 3
                            for y in range(64) for x in range(64))),
            ("CEILING", bytes(4 for _ in range(4096))),
            ("F_END", b"")]


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


def sector_lumps(floor=24, ceiling=112, blocking=False):
    vertices = [(-256, -256), (0, -256), (256, -256), (512, -256),
                (-256, 256), (0, 256), (256, 256), (512, 256)]
    edges = [(0, 1, 0), (1, 2, 1), (2, 3, 2), (3, 7, 2),
             (7, 6, 2), (6, 5, 1), (5, 4, 0), (4, 0, 0)]
    sides, lines = [], []
    for a, b, sector in edges:
        lines.append(struct.pack("<7H", a, b, 1, 0, 0, len(sides), 65535))
        sides.append(struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"WALL", sector))
    for a, b, front, back in [(1, 5, 0, 1), (2, 6, 1, 2)]:
        index = len(sides)
        flags = 4 | (1 if blocking and front == 0 else 0)
        lines.append(struct.pack("<7H", a, b, flags, 0, 0, index, index + 1))
        sides.extend(struct.pack("<hh8s8s8sH", 0, 0, b"WALL", b"WALL", b"-", sector)
                     for sector in (front, back))
    sectors = b"".join(struct.pack("<hh8s8shhh", low, high, b"FLOOR", b"CEILING", light, 0, 0)
                       for low, high, light in [(0, 128, 192), (floor, ceiling, 160), (0, 128, 224)])
    lumps = map_lumps()[:11]
    lumps[1] = ("THINGS", struct.pack("<5h", -128, 0, 0, 1, 7))
    lumps[2] = ("LINEDEFS", b"".join(lines))
    lumps[3] = ("SIDEDEFS", b"".join(sides))
    lumps[4] = ("VERTEXES", b"".join(struct.pack("<hh", x, y) for x, y in vertices))
    lumps[8] = ("SECTORS", sectors)
    return lumps + resources()


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
                                           ("TEXTURE2", lumps[14][1])] + lumps[15:])
    composite = struct.pack("<8sIhhIh", b"WALL", 0, 64, 64, 0, 2)
    composite += struct.pack("<hhhhh", 0, 0, 0, 1, 0)
    composite += struct.pack("<hhhhh", -3, -3, 0, 1, 0)
    files["composite.wad"] = wad(lumps[:14] + [("TEXTURE1", struct.pack("<ii", 1, 8) + composite)] + lumps[15:])
    files["flat-name-collision.wad"] = wad(lumps + [("WALL", bytes((3,)) * 4096)])
    files["sectors.wad"] = wad(sector_lumps())
    files["blocked-portal.wad"] = wad(sector_lumps(blocking=True))
    files["high-step.wad"] = wad(sector_lumps(floor=25))
    files["low-portal.wad"] = wad(sector_lumps(ceiling=79))
    files["closed-portal.wad"] = wad(sector_lumps(ceiling=24))
    files["level-portal.wad"] = wad(sector_lumps(floor=0, ceiling=128))
    files["bad-flat.wad"] = wad([(name, data[:-1] if name == "FLOOR" else data)
                                  for name, data in lumps])
    files["missing-flat.wad"] = wad([(name, data) for name, data in lumps if name != "FLOOR"])
    damaged = sector_lumps()
    damaged[2] = ("LINEDEFS", damaged[2][1][:-14])
    files["open-sector.wad"] = wad(damaged)
    damaged = sector_lumps()
    data = damaged[2][1]
    damaged[2] = ("LINEDEFS", data[:8 * 14 + 4] + struct.pack("<H", 0) + data[8 * 14 + 6:])
    files["bad-two-sided.wad"] = wad(damaged)
    for name, data in files.items():
        (directory / name).write_bytes(data)
    print(f"Generated {len(files)} original WAD fixtures in {directory}")


if __name__ == "__main__":
    fixtures(pathlib.Path(sys.argv[1]))
