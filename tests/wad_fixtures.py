#!/usr/bin/env python3
"""wad_fixtures creates original test data without distributing Doom assets."""

import pathlib
import re
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


def sky_lumps():
    lumps = sector_lumps()
    sectors = bytearray(lumps[8][1])
    for offset in range(0, len(sectors), 26):
        sectors[offset + 12:offset + 20] = b"F_SKY1\0\0"
    lumps[8] = ("SECTORS", bytes(sectors))
    sides = bytearray(lumps[3][1])
    for offset in range(8 * 30, len(sides), 30):
        sides[offset + 4:offset + 12] = b"-\0\0\0\0\0\0\0"
    lumps[3] = ("SIDEDEFS", bytes(sides))
    definitions = [lumps[14][1][8:]]
    for index in range(1, 5):
        definition = struct.pack("<8sIhhIh", f"SKY{index}".encode(), 0, 64, 64, 0, 1)
        definition += struct.pack("<hhhhh", index - 1, 0, 0, 1, 0)
        definitions.append(definition)
    lumps[14] = ("TEXTURE1", struct.pack("<i5i", 5, *range(24, 184, 32)) +
                 b"".join(definitions))
    return lumps


def masked_lumps(flags=0, x_offset=0, y_offset=0, second=False, composite=False, floor=0, ceiling=128):
    lumps = sector_lumps(floor=floor, ceiling=ceiling, blocking=bool(flags & 1))
    sides = bytearray(lumps[3][1])
    for index in (8, 9):
        struct.pack_into("<hh", sides, index * 30, x_offset, y_offset)
        sides[index * 30 + 20:index * 30 + 28] = b"GRATE\0\0\0"
    if second:
        for index in (10, 11):
            sides[index * 30 + 20:index * 30 + 28] = b"BACK\0\0\0\0"
    lumps[3] = ("SIDEDEFS", bytes(sides))
    lines = bytearray(lumps[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 4, 4 | flags)
    if second:
        struct.pack_into("<H", lines, 9 * 14 + 4, 4 | (flags & 16))
    lumps[2] = ("LINEDEFS", bytes(lines))
    patches = []
    for color in (2, 4):
        columns = []
        for x in range(64):
            if x % 16 < 4:
                column = bytes((0, 64, 0)) + bytes((color,)) * 56 + bytes((0,)) * 8 + bytes((0,))
            else:
                column = bytes((40, 8, 0)) + bytes((3,)) * 8 + bytes((0,))
                column += bytes((56, 8, 0)) + bytes((0,)) * 8 + bytes((0,))
            columns.append(column + bytes((255,)))
        offset, offsets = 8 + 64 * 4, []
        for column in columns:
            offsets.append(offset)
            offset += len(column)
        patches.append(struct.pack("<4h64i", 64, 64, 0, 0, *offsets) + b"".join(columns))
    lumps[12] = ("PNAMES", struct.pack("<i8s8s8s", 3, b"PATCH001", b"PGRATE", b"PBACK"))
    definitions = [lumps[14][1][8:]]
    for name, index in ((b"GRATE", 1), (b"BACK", 2)):
        count = 2 if composite and index == 1 else 1
        definition = struct.pack("<8sIhhIh", name, 0, 64, 64, 0, count)
        definition += struct.pack("<5h", 0, 0, index, 1, 0)
        if count == 2:
            definition += struct.pack("<5h", 4, 0, 2, 1, 0)
        definitions.append(definition)
    offsets, offset = [], 4 + len(definitions) * 4
    for definition in definitions:
        offsets.append(offset)
        offset += len(definition)
    lumps[14] = ("TEXTURE1", struct.pack("<i3i", 3, *offsets) + b"".join(definitions))
    return lumps + [("PGRATE", patches[0]), ("PBACK", patches[1])]


def bsp_lumps():
    lumps = sector_lumps()
    lumps[5] = ("SEGS", b"".join(struct.pack("<6H", i, i + 1, 0, i, 0, 0)
                               for i in range(3)))
    lumps[6] = ("SSECTORS", b"".join(struct.pack("<2H", 1, i) for i in range(3)))
    lumps[7] = ("NODES", struct.pack("<12h2H", 0, 0, 0, 256, *([0] * 8), 32769, 32768) +
               struct.pack("<12h2H", 256, 0, 0, 256, *([0] * 8), 32770, 0))
    return lumps


def sprite_patch(color=5, left=16, top=64):
    columns = []
    for x in range(32):
        if 4 <= x < 28:
            first = bytes((8, 16, 0)) + bytes((0 if x < 12 else color,)) * 16 + bytes((0,))
            second = bytes((40, 16, 0)) + bytes((color,)) * 16 + bytes((0,))
            columns.append(first + second + bytes((255,)))
        else:
            columns.append(bytes((255,)))
    offsets, offset = [], 8 + 32 * 4
    for column in columns:
        offsets.append(offset)
        offset += len(column)
    return struct.pack("<4h32i", 32, 64, left, top, *offsets) + b"".join(columns)


def corpse_patch(color=7):
    column = bytes((0, 16, 0)) + bytes([color] * 16) + bytes((0, 255))
    return struct.pack("<4h32i", 32, 16, 16, 16,
                       *(136 + x * len(column) for x in range(32))) + column * 32


def sprite_lumps(lumps=None, things=None, rotations=False):
    lumps = list(map_lumps() if lumps is None else lumps)
    palette = bytearray(lumps[11][1])
    palette[15:24] = bytes((255, 64, 192, 48, 192, 240, 224, 224, 32))
    lumps[11] = ("PLAYPAL", bytes(palette))
    if things is None:
        things = [(128, 0, 0, 3004 if rotations else 2015, 7)]
    lumps[1] = ("THINGS", lumps[1][1] + b"".join(struct.pack("<5h", *thing) for thing in things))
    patches = [("BON2A0", sprite_patch()), ("BON1A0", sprite_patch(6)),
               ("GOR1A0", sprite_patch()), ("TLMPA0", sprite_patch()),
               ("POSSL0", corpse_patch()), ("BEXPE0", corpse_patch())]
    if rotations:
        patches += [(name, sprite_patch(color, left=12)) for name, color in
                    [("POSSA1", 5), ("POSSA2A8", 6), ("POSSA3A7", 7), ("POSSA4A6", 3), ("POSSA5", 4)]]
    for prefix in ("POSS", "SPOS"):
        patches += [(prefix + frame + "0", sprite_patch(color))
                    for frame, color in zip("BCDEF", (6, 7, 4, 6, 7))]
    patches += [("SPOSA0", sprite_patch(5)), ("SPOSL0", corpse_patch())]
    effects = ["MISLB0", "MISLC0", "MISLD0", "BAL1C0", "BAL1D0", "BAL1E0",
               "PLSEA0", "PLSEB0", "PLSEC0", "PLSED0", "PLSEE0",
               "BFE1A0", "BFE1B0", "BFE1C0", "BFE1D0", "BFE1E0", "BFE1F0",
               "BEXPA0", "BEXPB0", "BEXPC0", "BEXPD0"]
    patches += [(name, sprite_patch(5 + index % 3)) for index, name in enumerate(effects)]
    return lumps + [("S_START", b""), *patches, ("S_END", b"")]



def pickup_lumps():
    things = [(128, 0, 0, kind, 7) for kind in (2014, 2015, 5, 2007, 2001, 8, 2012, 2022)]
    lumps = sprite_lumps(things=things)
    return lumps + [(name + "A0", sprite_patch(6))
                    for name in ("BKEY", "CLIP", "SHOT", "BPAK", "MEDI", "PINV")]


def door_lumps(special=1, flags=0):
    lumps = bsp_lumps()
    vertices = bytearray(lumps[4][1])
    for index in (2, 6):
        struct.pack_into("<h", vertices, index * 4, 64)
    lumps[4] = ("VERTEXES", bytes(vertices))
    lumps[1] = ("THINGS", struct.pack("<5h", -32, 0, 0, 1, 7))
    lines = bytearray(lumps[2][1])
    struct.pack_into("<7H", lines, 8 * 14, 5, 1, 4 | flags, special, 0, 8, 9)
    for index in (1, 5):
        struct.pack_into("<H", lines, index * 14 + 4, 1 | flags)
    lumps[2] = ("LINEDEFS", bytes(lines))
    nodes = bytearray(lumps[7][1])
    struct.pack_into("<h", nodes, 28, 64)
    lumps[7] = ("NODES", bytes(nodes))
    sectors = bytearray(lumps[8][1])
    struct.pack_into("<hh", sectors, 26, 0, 0)
    lumps[8] = ("SECTORS", bytes(sectors))
    return lumps


def exit_lumps(special=11, marker="E1M1", crossing=False):
    lumps = (sector_lumps(floor=0, ceiling=128) if crossing else map_lumps())[:11]
    lumps[0] = (marker, b"")
    lumps[1] = ("THINGS", struct.pack("<5h", -32 if crossing else 224, 0, 0, 1, 7))
    lines = bytearray(lumps[2][1])
    index = 8 if crossing else 1
    if not crossing:
        a, b = struct.unpack_from("<2H", lines, index * 14)
        struct.pack_into("<2H", lines, index * 14, b, a)
    struct.pack_into("<H", lines, index * 14 + 6, special)
    lumps[2] = ("LINEDEFS", bytes(lines))
    return lumps


def tagged_door_lumps(special=103, crossing=False, ceiling=0, tag=7, portal=False):
    lumps = sector_lumps(floor=0, ceiling=ceiling)
    portal = portal or crossing
    lumps[1] = ("THINGS", struct.pack("<5h", -32 if portal else -224, 0, 0 if portal else 180, 1, 7))
    lines = bytearray(lumps[2][1])
    index = 8 if portal else 7
    a, b = struct.unpack_from("<2H", lines, index * 14)
    struct.pack_into("<2H", lines, index * 14, b, a)
    struct.pack_into("<2H", lines, index * 14 + 6, special, tag)
    lumps[2] = ("LINEDEFS", bytes(lines))
    sectors = bytearray(lumps[8][1])
    if portal:
        struct.pack_into("<h", sectors, 26 + 2, 128)
        struct.pack_into("<h", sectors, 52 + 2, ceiling)
        struct.pack_into("<H", sectors, 52 + 24, 7)
    else:
        struct.pack_into("<H", sectors, 26 + 24, 7)
    lumps[8] = ("SECTORS", bytes(sectors))
    return lumps


def grouped_door_lumps():
    lumps = tagged_door_lumps(63)
    vertices = [(x, y) for y in (-256, 256) for x in (-256, 0, 256, 512, 768, 1024)]
    sides, lines = [], []
    edges = [(i, i + 1, i) for i in range(5)] + [(5, 11, 4)]
    edges += [(i + 7, i + 6, i) for i in range(4, -1, -1)] + [(0, 6, 0)]
    for a, b, sector in edges:
        lines.append(struct.pack("<7H", a, b, 1, 63 if (a, b) == (0, 6) else 0,
                                 7 if (a, b) == (0, 6) else 0, len(sides), 65535))
        sides.append(struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"WALL", sector))
    for i in range(1, 5):
        lines.append(struct.pack("<7H", i + 6, i, 4, 1 if i == 1 else 0, 0, len(sides), len(sides) + 1))
        sides.extend(struct.pack("<hh8s8s8sH", 0, 0, b"WALL", b"WALL", b"-", sector)
                     for sector in (i - 1, i))
    lumps[2] = ("LINEDEFS", b"".join(lines))
    lumps[3] = ("SIDEDEFS", b"".join(sides))
    lumps[4] = ("VERTEXES", b"".join(struct.pack("<2h", *v) for v in vertices))
    lumps[8] = ("SECTORS", b"".join(struct.pack("<hh8s8shhh", 0, 0 if i in (1, 3) else 128,
                                               b"FLOOR", b"CEILING", 192, 0, 7 if i in (1, 3) else 0)
                                      for i in range(5)))
    return lumps


def floor_lumps(special=62, crossing=False, floor=96, portal=True, ride=False):
    lumps = sector_lumps(floor=floor, ceiling=192)
    lumps[1] = ("THINGS", struct.pack("<5h", 224 if ride else -32 if portal or crossing else -224, 0,
                                    0 if portal or crossing else 180, 1, 7))
    lines = bytearray(lumps[2][1])
    index = 9 if ride else 8 if portal or crossing else 7
    a, b = struct.unpack_from("<2H", lines, index * 14)
    struct.pack_into("<2H", lines, index * 14, b, a)
    struct.pack_into("<2H", lines, index * 14 + 6, special, 7)
    lumps[2] = ("LINEDEFS", bytes(lines))
    sectors = bytearray(lumps[8][1])
    if crossing:
        struct.pack_into("<h", sectors, 26, 0)
        struct.pack_into("<hh", sectors, 52, floor, 192)
        struct.pack_into("<H", sectors, 52 + 24, 7)
    else:
        struct.pack_into("<H", sectors, 26 + 24, 7)
        struct.pack_into("<hh", sectors, 52, 64, 192)
    lumps[8] = ("SECTORS", bytes(sectors))
    return lumps


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
        "tangent-start.wad": (1, struct.pack("<hhhhh", 240, 0, 90, 1, 7)),
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
    files["inverted-portal.wad"] = wad(sector_lumps(ceiling=23))
    inverted = sector_lumps(ceiling=23)
    inverted[1] = ("THINGS", struct.pack("<5h", 128, 0, 0, 1, 7))
    files["inverted-start.wad"] = wad(inverted)
    files["level-portal.wad"] = wad(sector_lumps(floor=0, ceiling=128))
    files["masked.wad"] = wad(masked_lumps())
    files["masked-bottom.wad"] = wad(masked_lumps(flags=16))
    files["masked-offset.wad"] = wad(masked_lumps(x_offset=-5, y_offset=16))
    files["masked-layered.wad"] = wad(masked_lumps(flags=16, second=True))
    files["masked-blocked.wad"] = wad(masked_lumps(flags=1))
    files["masked-composite.wad"] = wad(masked_lumps(composite=True))
    files["masked-tiered.wad"] = wad(masked_lumps(floor=24, ceiling=80))
    masked = masked_lumps()
    sides = bytearray(masked[3][1])
    for offset in range(0, len(sides), 30):
        sector = struct.unpack_from("<H", sides, offset + 28)[0]
        struct.pack_into("<H", sides, offset + 28, 1 if sector == 2 else 0)
    masked[3] = ("SIDEDEFS", bytes(sides))
    masked[8] = ("SECTORS", masked[8][1][:26] + masked[8][1][52:])
    files["masked-same-sector.wad"] = wad(masked)
    masked = masked_lumps()
    sides = bytearray(masked[3][1])
    sides[8 * 30 + 20:8 * 30 + 28] = b"MISSING\0"
    masked[3] = ("SIDEDEFS", bytes(sides))
    files["masked-unknown.wad"] = wad(masked)
    masked = masked_lumps()
    masked[-2] = ("PGRATE", masked[-2][1][:-1])
    files["masked-no-end.wad"] = wad(masked)
    sprites = sprite_lumps()
    files["sprites.wad"] = wad(sprites)
    files["sprite-rotations.wad"] = wad(sprite_lumps(sector_lumps(floor=0, ceiling=128), rotations=True))
    files["sprites-layered.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 2015, 7), (192, 0, 0, 2014, 7)]))
    files["sprites-reordered.wad"] = wad(sprite_lumps(things=[(192, 0, 0, 2014, 7), (128, 0, 0, 2015, 7)]))
    files["sprites-grate.wad"] = wad(sprite_lumps(masked_lumps(flags=16)))
    files["sprites-front-grate.wad"] = wad(sprite_lumps(masked_lumps(flags=16), [(-64, 0, 0, 2015, 7)]))
    files["sprites-closed.wad"] = wad(sprite_lumps(sector_lumps(ceiling=24)))
    files["sprites-flags.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 2015, flag) for flag in (1, 18, 2)] +
                                                [(128, 0, 0, kind, 7) for kind in (14, 87, 9999)]))
    files["sprites-ceiling.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 49, 7)]))
    files["sprites-fullbright.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 85, 7)]))
    files["sprite-missing.wad"] = wad([lump for lump in sprites if lump[0] != "BON2A0"])
    files["sprite-missing-configured.wad"] = wad([lump for lump in sprites if lump[0] != "BON1A0"])
    files["sprite-short.wad"] = wad([(name, b"abc" if name == "BON2A0" else data) for name, data in sprites])
    files["sprite-no-end.wad"] = wad([(name, data[:-1] if name == "BON2A0" else data) for name, data in sprites])
    files["sprite-dimensions.wad"] = wad([(name, struct.pack("<h", 0) + data[2:] if name == "BON2A0" else data)
                                         for name, data in sprites])
    files["sprite-outside.wad"] = wad(sprite_lumps(things=[(2000, 0, 0, 2015, 7)]))
    rotated = sprite_lumps(rotations=True)
    files["sprite-missing-rotation.wad"] = wad([lump for lump in rotated if lump[0] != "POSSA5"])
    files["sprite-mixed-rotations.wad"] = wad(rotated + [("POSSA0", sprite_patch())])
    files["sprite-duplicate-rotation.wad"] = wad(rotated + [("POSSA1A2", sprite_patch())])
    files["sprite-invalid-rotation.wad"] = wad(sprites + [("BON2A9", sprite_patch())])
    files["sprite-last-lump.wad"] = wad(sprites + [("BON2A0", sprite_patch(6))])
    hidden = bsp_lumps()
    lines = bytearray(hidden[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 4, 1)
    struct.pack_into("<H", lines, 8 * 14 + 12, 65535)
    hidden[2] = ("LINEDEFS", bytes(lines))
    files["sprites-hidden-wall.wad"] = wad(sprite_lumps(hidden))
    files["sprites-no-resources.wad"] = wad(sprites[:11] + [("BON2A0", sprite_patch())])
    oversized = list(sprites)
    oversized[1] = ("THINGS", sprites[1][1] + struct.pack("<5h", 0, 0, 0, 1, 7) * 65536)
    files["sprites-too-many.wad"] = wad(oversized)
    files["pickups.wad"] = wad(pickup_lumps())
    files["pickups-many.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 2015, 7)] * 33))
    files["pickups-blocked.wad"] = wad(sprite_lumps(masked_lumps(flags=17), [(8, 0, 0, 2015, 7)]))
    files["pickups-passable.wad"] = wad(sprite_lumps(masked_lumps(flags=16), [(8, 0, 0, 2015, 7)]))
    files["pickups-closed.wad"] = wad(sprite_lumps(sector_lumps(ceiling=0), [(8, 0, 0, 2015, 7)]))
    files["pickups-solid.wad"] = wad(sprite_lumps(hidden, [(8, 0, 0, 2015, 7)]))

    for label, kind, name in (("barrel", 2035, "BAR1A0"), ("decoration", 2028, "COLUA0"),
                              ("corpse", 18, "POSSL0"), ("hanging", 49, "GOR1A0"),
                              ("hanging-passable", 63, "GOR1A0")):
        actor = sprite_lumps(things=[(128, 0, 0, kind, 7)])
        if name not in {entry[0] for entry in actor}:
            actor.append((name, sprite_patch(6)))
        files[f"actors-{label}.wad"] = wad(actor)
    files["actors-overlap.wad"] = wad(sprite_lumps(things=[(0, 0, 0, 2035, 7)]) +
                                     [("BAR1A0", sprite_patch(6))])
    files["actors-flags.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 2035, flag)
                                                       for flag in (1, 18)]) +
                                   [("BAR1A0", sprite_patch(6))])
    files["actors-step.wad"] = wad(sprite_lumps(sector_lumps(), [(128, 0, 0, 2035, 7)]) +
                                  [("BAR1A0", sprite_patch(6))])

    def combat_lumps(lumps=None, things=None):
        return sprite_lumps(lumps, things or [(128, 0, 0, 3004, 7)]) + [("POSSA0", sprite_patch(5))]

    combat = combat_lumps()
    files["combat.wad"] = wad(combat)
    arsenal = combat_lumps(things=[(128, 0, 0, 3004, 7)] +
                           [(0, 0, 0, kind, 7) for kind in (2001, 2002, 2003, 2004, 2005, 2006, 82)])
    arsenal += [(name, sprite_patch(6)) for name in
                ("SHOTA0", "MGUNA0", "LAUNA0", "PLASA0", "CSAWA0", "BFUGA0", "SGN2A0",
                 "MISLA0", "PLSSA0", "BFS1A0")]
    files["weapons.wad"] = wad(arsenal)
    files["weapons-missing.wad"] = wad([entry for entry in arsenal if entry[0] != "MISLA0"])
    files["weapons-bad.wad"] = wad([(name, b"abc" if name == "PLSSA0" else data) for name, data in arsenal])
    blast = sprite_lumps(things=[(128, 0, 0, 2035, 7), (128, 48, 0, 2035, 7),
                                (0, 0, 0, 2003, 7), (0, 0, 0, 2004, 7)])
    blast += [(name, sprite_patch(6)) for name in
              ("BAR1A0", "LAUNA0", "MISLA0", "PLASA0", "PLSSA0")]
    files["blast.wad"] = wad(blast)
    barrels = sprite_lumps(things=[(64, 0, 0, 2035, 7), (144, 0, 0, 2035, 7),
                                  (224, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch(6))]
    files["barrels-chain.wad"] = wad(barrels)
    for name, special, marker, crossing in [
            ("exits-use.wad", 11, "E1M1", False),
            ("exits-secret.wad", 51, "E1M3", False),
            ("exits-walk.wad", 52, "E1M1", True),
            ("exits-walk-secret.wad", 124, "E1M3", True)]:
        target = "E1M9" if special in (51, 124) else "E1M2"
        next_map = map_lumps()[:11]
        next_map[0] = (target, b"")
        files[name] = wad(exit_lumps(special, marker, crossing) + next_map + resources())
    files["exits-end.wad"] = wad(exit_lumps(marker="E1M8") + resources())
    files["exits-missing.wad"] = wad(exit_lumps() + resources())
    invalid = map_lumps()[:11]
    invalid[0] = ("E1M2", b"")
    invalid[4] = ("VERTEXES", b"abc")
    files["exits-bad.wad"] = wad(exit_lumps() + invalid + resources())
    next_map = map_lumps()[:11]
    next_map[0] = ("E1M2", b"")
    carry = sprite_lumps(exit_lumps() + resources(),
                         [(224, 0, 0, kind, 7) for kind in (2003, 2018, 5, 8)])
    carry += [(name, sprite_patch(6)) for name in ("LAUNA0", "MISLA0", "ARM1A0", "BKEYA0", "BPAKA0")]
    files["exits-carry.wad"] = wad(carry + next_map)
    missing = list(next_map)
    missing[1] = ("THINGS", next_map[1][1] + struct.pack("<5h", 128, 0, 0, 3004, 7))
    files["exits-resource-missing.wad"] = wad(exit_lumps() + missing + resources())
    files["exits-no-resources.wad"] = wad(exit_lumps() + next_map)
    next_map[0] = ("E1M3", b"")
    files["exits-custom.wad"] = wad(exit_lumps() + next_map + resources())
    files["exits-end-ii.wad"] = wad(exit_lumps(marker="MAP30") + resources())
    files["barrels-reversed.wad"] = wad(sprite_lumps(things=[(224, 0, 0, 2035, 7),
                                                              (144, 0, 0, 2035, 7),
                                                              (64, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch(6))])
    files["barrels-many.wad"] = wad(sprite_lumps(things=[(128, 0, 0, 2035, 7)] * 300) +
                                     [("BAR1A0", sprite_patch(6))])
    files["barrels-cover.wad"] = wad(sprite_lumps(hidden, [(-32, 0, 0, 2035, 7),
                                                          (32, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch(6))])
    files["barrels-grate.wad"] = wad(sprite_lumps(masked_lumps(flags=17), [(-32, 0, 0, 2035, 7),
                                                                          (32, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch(6))])
    files["barrels-missing.wad"] = wad([entry for entry in barrels if entry[0] != "BEXPC0"])
    files["impact-missing.wad"] = wad([entry for entry in arsenal if entry[0] != "MISLD0"])
    files["impact-bad.wad"] = wad([(name, b"abc" if name == "PLSEC0" else data) for name, data in arsenal])
    files["combat-nearest.wad"] = wad(combat_lumps(things=[(192, 0, 0, 3004, 7),
                                                          (128, 0, 0, 3004, 7)]))
    files["combat-off-axis.wad"] = wad(combat_lumps(things=[(128, 64, 0, 3004, 7)]))
    files["combat-closed.wad"] = wad(combat_lumps(sector_lumps(ceiling=0)))
    files["combat-step.wad"] = wad(combat_lumps(sector_lumps(floor=48)))
    files["combat-blocked.wad"] = wad(combat_lumps(hidden))
    files["combat-grate.wad"] = wad(combat_lumps(masked_lumps(flags=17)))
    files["combat-door.wad"] = wad(combat_lumps(door_lumps(), [(384, 0, 0, 3004, 7)]))
    files["combat-pickup.wad"] = wad(combat_lumps(things=[(128, 0, 0, 3004, 7),
                                                         (0, 0, 0, 2015, 7)]))
    files["combat-missing-death.wad"] = wad([entry for entry in combat if entry[0] != "POSSL0"])
    files["combat-bad-death.wad"] = wad([(name, b"abc" if name == "POSSL0" else data)
                                        for name, data in combat])

    def ai_lumps(lumps=None, things=None):
        frames = [(f"SARG{frame}0", sprite_patch(color))
                  for frame, color in zip("ABCDEFG", (5, 6, 7, 4, 6, 7, 5))]
        return sprite_lumps(lumps, [(128, 0, 0, 3002, 7)] if things is None else things) + frames + [("SARGN0", corpse_patch())]

    ai = ai_lumps()
    files["ai.wad"] = wad(ai)
    files["ai-spectre.wad"] = wad(ai_lumps(things=[(128, 0, 0, 58, 7)]))
    files["ai-hidden.wad"] = wad(ai_lumps(hidden))
    files["ai-hidden-near.wad"] = wad(ai_lumps(hidden, [(32, 0, 0, 3002, 7)]))
    files["ai-grate.wad"] = wad(ai_lumps(masked_lumps(flags=17)))
    files["ai-door.wad"] = wad(ai_lumps(door_lumps(), [(384, 0, 0, 3002, 7)]))
    files["ai-step.wad"] = wad(ai_lumps(sector_lumps()))
    files["ai-high-step.wad"] = wad(ai_lumps(sector_lumps(floor=48)))
    files["ai-low-ceiling.wad"] = wad(ai_lumps(sector_lumps(ceiling=32)))
    files["ai-climb.wad"] = wad(ai_lumps(sector_lumps(), [(-128, 0, 0, 3002, 7)]))
    files["ai-climb-high.wad"] = wad(ai_lumps(sector_lumps(floor=48), [(-128, 0, 0, 3002, 7)]))
    files["ai-pickup.wad"] = wad(ai_lumps(things=[(128, 0, 0, 3002, 7), (0, 0, 0, 2015, 7)]))
    files["ai-pair.wad"] = wad(ai_lumps(things=[(128, 0, 0, 3002, 7), (192, 0, 0, 3002, 7)]))
    files["ai-prop.wad"] = wad(ai_lumps(things=[(128, 0, 0, 3002, 7), (64, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch())])
    files["ai-missing-walk.wad"] = wad([entry for entry in ai if entry[0] != "SARGB0"])
    files["ai-bad-attack.wad"] = wad([(name, b"abc" if name == "SARGF0" else data) for name, data in ai])

    ranged = combat_lumps()
    files["hitscan.wad"] = wad(ranged)
    files["hitscan-shotgun.wad"] = wad(combat_lumps(things=[(128, 0, 0, 9, 7)]))
    files["hitscan-hidden.wad"] = wad(combat_lumps(hidden))
    files["hitscan-door.wad"] = wad(combat_lumps(door_lumps(), [(384, 0, 0, 3004, 7)]))
    files["hitscan-grate.wad"] = wad(combat_lumps(masked_lumps(flags=17)))
    files["hitscan-high.wad"] = wad(combat_lumps(sector_lumps(floor=64, ceiling=128)))
    files["hitscan-low-ceiling.wad"] = wad(combat_lumps(sector_lumps(ceiling=32)))
    files["hitscan-barrel.wad"] = wad(combat_lumps(things=[(192, 0, 0, 3004, 7),
                                                          (128, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch())])
    files["hitscan-shotgun-barrel.wad"] = wad(combat_lumps(things=[(192, 0, 0, 9, 7),
                                                                  (128, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch())])
    files["hitscan-friendly.wad"] = wad(combat_lumps(things=[(-128, 0, 0, 3004, 7), (-64, 0, 0, 3004, 7)]))
    files["hitscan-pickup.wad"] = wad(combat_lumps(things=[(128, 0, 0, 3004, 7), (0, 0, 0, 2015, 7)]))
    files["hitscan-missing-walk.wad"] = wad([entry for entry in ranged if entry[0] != "POSSB0"])
    files["hitscan-bad-attack.wad"] = wad([(name, b"abc" if name == "POSSF0" else data) for name, data in ranged])

    def projectile_lumps(lumps=None, things=None):
        actors = [(128, 0, 0, 3001, 7)] if things is None else things
        frames = [("TROO" + frame + "0", sprite_patch(color))
                  for frame, color in zip("ABCDEFG", (5, 6, 7, 4, 6, 7, 5))]
        return sprite_lumps(lumps, actors) + frames + [("TROOM0", corpse_patch()),
                                                     ("BAL1A0", corpse_patch(6))]

    projectiles = projectile_lumps()
    files["projectiles.wad"] = wad(projectiles)
    files["projectiles-hidden.wad"] = wad(projectile_lumps(hidden))
    files["projectiles-grate.wad"] = wad(projectile_lumps(masked_lumps(flags=17)))
    files["projectiles-door.wad"] = wad(projectile_lumps(door_lumps(), [(384, 0, 0, 3001, 7)]))
    files["projectiles-high.wad"] = wad(projectile_lumps(sector_lumps(floor=64, ceiling=128), [(64, 0, 0, 3001, 7)]))
    files["projectiles-low.wad"] = wad(projectile_lumps(sector_lumps(ceiling=32)))
    files["projectiles-barrel.wad"] = wad(projectile_lumps(things=[(192, 0, 0, 3001, 7),
                                                                (128, 0, 0, 2035, 7)]) + [("BAR1A0", sprite_patch())])
    files["projectiles-pickup.wad"] = wad(projectile_lumps(things=[(128, 0, 0, 3001, 7),
                                                                (0, 0, 0, 2015, 7)]))
    files["projectiles-missing.wad"] = wad([entry for entry in projectiles if entry[0] != "BAL1A0"])
    files["projectiles-bad.wad"] = wad([(name, b"abc" if name == "BAL1A0" else data) for name, data in projectiles])
    files["projectiles-many.wad"] = wad(projectile_lumps(things=[(128, 0, 0, 3001, 7)] * 300))
    files["projectiles-prop.wad"] = wad(projectile_lumps(things=[(192, 0, 0, 3001, 7),
                                                              (128, 0, 0, 2028, 7)]) + [("COLUA0", sprite_patch())])

    sky = sky_lumps()
    files["sky.wad"] = wad(sky)
    for marker in ("E2M1", "E3M1", "E4M1", "MAP01", "MAP11", "MAP12", "MAP20", "MAP21", "MAP32"):
        files[f"sky-{marker}.wad"] = wad([(marker, b"")] + sky[1:])
    files["missing-sky.wad"] = wad(sky[:14] + [lumps[14]] + sky[15:])
    missing = sector_lumps(ceiling=80)
    files["tiered-portal.wad"] = wad(missing)
    sides = bytearray(missing[3][1])
    sides[8 * 30 + 4:8 * 30 + 20] = b"-\0\0\0\0\0\0\0" * 2
    missing[3] = ("SIDEDEFS", bytes(sides))
    files["absent-tiers.wad"] = wad(missing)
    sides[8 * 30 + 12:8 * 30 + 20] = b"MISSING\0"
    missing[3] = ("SIDEDEFS", bytes(sides))
    files["unknown-tier.wad"] = wad(missing)
    absent = list(lumps)
    absent[3] = ("SIDEDEFS", struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"-", 0))
    files["absent-middle.wad"] = wad(absent)
    absent[3] = ("SIDEDEFS", struct.pack("<hh8s8s8sH", 0, 0, b"-", b"-", b"MISSING", 0))
    files["unknown-middle.wad"] = wad(absent)
    bsp = bsp_lumps()
    files["bsp-sectors.wad"] = wad(bsp)
    modified = list(bsp)
    modified[8] = ("SECTORS", bsp[8][1] + bsp[8][1][:26])
    files["bsp-unused-sector.wad"] = wad(modified)
    modified = list(bsp)
    modified[2] = ("LINEDEFS", bsp[2][1][:-14])
    files["bsp-open-sector.wad"] = wad(modified)
    modified = list(bsp)
    modified[6] = ("SSECTORS", struct.pack("<2H", 2, 0) + bsp[6][1][4:])
    files["bsp-mixed-subsector.wad"] = wad(modified)
    single = list(lumps)
    single[5] = ("SEGS", struct.pack("<6H", 0, 1, 0, 0, 0, 0))
    single[6] = ("SSECTORS", struct.pack("<2H", 1, 0))
    files["bsp-single.wad"] = wad(single)
    files["door.wad"] = wad(door_lumps())
    files["tagged-door-use.wad"] = wad(tagged_door_lumps())
    files["floor-lift.wad"] = wad(floor_lumps())
    files["floor-gun.wad"] = wad(floor_lumps(24, floor=16))
    floor_walks = (5, 10, 19, 38, 82, 83, 88, 91, 119, 120, 121, 128)
    floor_nearest = (18, 69, 119, 128)
    floor_variants = (5, 10, 18, 19, 21, 23, 24, 38, 45, 60, 62, 64, 69, 82, 83, 88, 91, 101, 102,
                      119, 120, 121, 122, 123, 128)
    for special in floor_variants:
        crossing = special in floor_walks
        start = (-24 if crossing else 0) if special in floor_nearest else 96
        files[f"floor-{special}.wad"] = wad(floor_lumps(special, crossing, start, portal=False))
    files["floor-lift-ride.wad"] = wad(floor_lumps(ride=True))
    riders = sprite_lumps(floor_lumps(ride=True), things=[(128, 64, 0, 2035, 7),
                                                       (128, -64, 0, 2014, 7),
                                                       (64, -128, 0, 49, 7)])
    riders += [("BAR1A0", sprite_patch())]
    files["floor-riders.wad"] = wad(riders)
    pinch = floor_lumps(101, floor=0)
    sectors = bytearray(pinch[8][1])
    struct.pack_into("<h", sectors, 26 + 2, 80)
    pinch[8] = ("SECTORS", bytes(sectors))
    files["floor-actor-block.wad"] = wad(sprite_lumps(pinch, things=[(128, 0, 0, 2035, 7)]) +
                                         [("BAR1A0", sprite_patch())])
    pinch = floor_lumps(101, floor=0, ride=True)
    sectors = bytearray(pinch[8][1])
    struct.pack_into("<h", sectors, 26 + 2, 80)
    pinch[8] = ("SECTORS", bytes(sectors))
    files["floor-player-block.wad"] = wad(pinch)
    hidden = floor_lumps(18, floor=0, portal=False)
    sides = bytearray(hidden[3][1])
    sides[9 * 30 + 12:9 * 30 + 20] = b"MISSING\0"
    hidden[3] = ("SIDEDEFS", bytes(sides))
    files["floor-hidden-texture.wad"] = wad(hidden)
    shared = floor_lumps(23, floor=24)
    vertices = bytearray(shared[4][1])
    for index in (2, 6):
        struct.pack_into("<h", vertices, index * 4, 32)
    shared[4] = ("VERTEXES", bytes(vertices))
    lines = bytearray(shared[2][1])
    struct.pack_into("<2H", lines, 9 * 14, 6, 2)
    struct.pack_into("<H", lines, 9 * 14 + 6, 31)
    shared[2] = ("LINEDEFS", bytes(lines))
    sectors = bytearray(shared[8][1])
    struct.pack_into("<hh", sectors, 52, 0, 0)
    shared[8] = ("SECTORS", bytes(sectors))
    files["floor-shared-actions.wad"] = wad(shared)
    busy = floor_lumps(18, floor=0, portal=False)
    lines = bytearray(busy[2][1])
    struct.pack_into("<2H", lines, 8 * 14, 5, 1)
    struct.pack_into("<H", lines, 8 * 14 + 6, 1)
    busy[2] = ("LINEDEFS", bytes(lines))
    sectors = bytearray(busy[8][1])
    struct.pack_into("<h", sectors, 26 + 2, 0)
    busy[8] = ("SECTORS", bytes(sectors))
    files["floor-door-busy.wad"] = wad(busy)
    blocked = floor_lumps(88, crossing=True)
    lines = bytearray(blocked[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 4, 5)
    blocked[2] = ("LINEDEFS", bytes(lines))
    files["floor-blocked-crossing.wad"] = wad(blocked)
    files["tagged-door-gui.wad"] = wad(tagged_door_lumps(portal=True))
    switches = (29, 42, 50, 61, 63, 99, 103, 111, 112, 113, 114, 115, 116, 133, 134, 135, 136, 137)
    walks = (2, 3, 4, 16, 75, 76, 86, 90, 105, 106, 107, 108, 109, 110)
    closes = (3, 16, 42, 50, 75, 76, 107, 110, 113, 116)
    for special in (*switches, *walks, 46):
        files[f"tagged-door-{special}.wad"] = wad(tagged_door_lumps(special, special in walks,
                                                                   128 if special in closes else 0))
    files["tagged-door-multi.wad"] = wad(grouped_door_lumps())
    busy = tagged_door_lumps()
    lines = bytearray(busy[2][1])
    struct.pack_into("<2H", lines, 8 * 14, 5, 1)
    struct.pack_into("<H", lines, 8 * 14 + 6, 1)
    busy[2] = ("LINEDEFS", bytes(lines))
    files["tagged-door-busy.wad"] = wad(busy)
    files["tagged-door-no-tag.wad"] = wad(tagged_door_lumps(tag=8))
    files["tagged-door-hidden.wad"] = wad(tagged_door_lumps(42, ceiling=128))
    hidden = tagged_door_lumps(42, ceiling=128)
    sides = bytearray(hidden[3][1])
    sides[8 * 30 + 4:8 * 30 + 12] = b"MISSING\0"
    hidden[3] = ("SIDEDEFS", bytes(sides))
    files["tagged-door-missing-texture.wad"] = wad(hidden)
    blocked = tagged_door_lumps(90, crossing=True)
    lines = bytearray(blocked[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 4, 5)
    blocked[2] = ("LINEDEFS", bytes(lines))
    files["tagged-door-blocked-crossing.wad"] = wad(blocked)
    occluded = tagged_door_lumps()
    occluded[4] = ("VERTEXES", occluded[4][1] + struct.pack("<8h", -240, -128, -232, -128, -232, 128, -240, 128))
    occluded[2] = ("LINEDEFS", occluded[2][1] + b"".join(struct.pack("<7H", a, b, 1, 0, 0, 0, 65535)
                                                       for a, b in ((8, 9), (9, 10), (10, 11), (11, 8))))
    occluded[1] = ("THINGS", struct.pack("<5h", -200, 0, 180, 1, 7))
    files["tagged-door-occluded.wad"] = wad(occluded)
    lines = bytearray(occluded[2][1])
    struct.pack_into("<H", lines, 7 * 14 + 6, 46)
    occluded[2] = ("LINEDEFS", bytes(lines))
    files["tagged-door-gun-occluded.wad"] = wad(occluded)
    actor = sprite_lumps(tagged_door_lumps(46), things=[(-224, 0, 0, 2035, 7)])
    actor += [("BAR1A0", sprite_patch(5))]
    files["tagged-door-gun-actor.wad"] = wad(actor)
    files["tagged-door-gun-portal.wad"] = wad(tagged_door_lumps(46, portal=True))
    files["tagged-door-gun-projectile.wad"] = wad(sprite_lumps(tagged_door_lumps(46),
                                                               things=[(-224, 0, 0, 2003, 7)]) +
                                                [("LAUNA0", sprite_patch()), ("MISLA0", sprite_patch())])
    files["door-open.wad"] = wad(door_lumps(31))
    files["door-fast.wad"] = wad(door_lumps(117))
    files["door-fast-open.wad"] = wad(door_lumps(118))
    files["door-locked.wad"] = wad(door_lumps(26))
    for name, special in (("blue", 26), ("yellow", 27), ("red", 28),
                          ("blue-open", 32), ("red-open", 33), ("yellow-open", 34)):
        locked = door_lumps(special)
        files[f"door-{name}.wad"] = wad(locked)
        sides = bytearray(locked[3][1])
        sides[9 * 30 + 4:9 * 30 + 12] = b"MISSING\0"
        locked[3] = ("SIDEDEFS", bytes(sides))
        files[f"door-{name}-hidden.wad"] = wad(locked)
    key = sprite_lumps(door_lumps(32), things=[(-32, -64, 0, 5, 7)])
    files["door-key.wad"] = wad(key + [("BKEYA0", sprite_patch(6))])
    files["door-unsupported.wad"] = wad(door_lumps(2))
    files["door-peg-top.wad"] = wad(door_lumps(flags=8))
    files["door-peg-bottom.wad"] = wad(door_lumps(flags=16))
    wall_use = door_lumps()
    lines = bytearray(wall_use[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 4, 1)
    struct.pack_into("<H", lines, 8 * 14 + 12, 65535)
    wall_use[2] = ("LINEDEFS", bytes(lines))
    files["door-no-back.wad"] = wad(wall_use)
    lines = bytearray(wall_use[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 6, 26)
    wall_use[2] = ("LINEDEFS", bytes(lines))
    files["door-blue-no-back.wad"] = wad(wall_use)
    occluded = door_lumps()
    occluded[4] = ("VERTEXES", occluded[4][1] + struct.pack("<4h", -16, -256, -16, 256))
    occluded[2] = ("LINEDEFS", occluded[2][1] + struct.pack("<7H", 8, 9, 1, 0, 0, 0, 65535))
    files["door-occluded.wad"] = wad(occluded)
    lines = bytearray(occluded[2][1])
    struct.pack_into("<H", lines, 8 * 14 + 6, 26)
    occluded[2] = ("LINEDEFS", bytes(lines))
    files["door-blue-occluded.wad"] = wad(occluded)
    unknown = door_lumps()
    sides = bytearray(unknown[3][1])
    sides[9 * 30 + 4:9 * 30 + 12] = b"MISSING\0"
    unknown[3] = ("SIDEDEFS", bytes(sides))
    files["door-hidden-unknown.wad"] = wad(unknown)
    bsp_variants = {
        "bsp-bad-seg-stride.wad": (5, b"abc"),
        "bsp-bad-sub-stride.wad": (6, b"abc"),
        "bsp-bad-node-stride.wad": (7, b"abc"),
        "bsp-no-segs.wad": (5, b""),
        "bsp-no-subsectors.wad": (6, b""),
        "bsp-no-nodes.wad": (7, b""),
        "bsp-bad-seg-vertex.wad": (5, struct.pack("<6H", 65535, 1, 0, 0, 0, 0)),
        "bsp-bad-seg-line.wad": (5, struct.pack("<6H", 0, 1, 0, 65535, 0, 0)),
        "bsp-bad-seg-side.wad": (5, struct.pack("<6H", 0, 1, 0, 0, 2, 0)),
        "bsp-missing-seg-side.wad": (5, struct.pack("<6H", 0, 1, 0, 0, 1, 0)),
        "bsp-empty-subsector.wad": (6, struct.pack("<2H", 0, 0)),
        "bsp-bad-sub-range.wad": (6, struct.pack("<2H", 2, 2)),
        "bsp-bad-leaf.wad": (7, struct.pack("<12h2H", 0, 0, 0, 256, *([0] * 8), 32771, 32768)),
        "bsp-self-cycle.wad": (7, struct.pack("<12h2H", 0, 0, 0, 256, *([0] * 8), 0, 32768)),
        "bsp-forward-child.wad": (7, struct.pack("<12h2H", 0, 0, 0, 256, *([0] * 8), 1, 32768) + bsp[7][1][28:]),
        "bsp-zero-direction.wad": (7, struct.pack("<12h2H", *([0] * 12), 32769, 32768)),
        "bsp-large-tree.wad": (7, bytes(28 * 32769)),
        "bsp-outside-start.wad": (1, struct.pack("<5h", 2000, 2000, 0, 1, 7)),
    }
    for name, (index, data) in bsp_variants.items():
        modified = list(bsp)
        modified[index] = (modified[index][0], data)
        files[name] = wad(modified)
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
    profile = (pathlib.Path(__file__).resolve().parent.parent / "doom.yaml").read_text()
    isolated = re.sub(r"      explosion:\n(?:        .*\n)+", "      explosion: null\n", profile)
    (directory / "doom-blast-only.yaml").write_text(isolated)
    start, marker, weapons = profile.partition("    launcher:\n")
    launcher, separator, tail = weapons.partition("    plasma:\n")
    assert marker and separator
    launcher = re.sub(r"(?m)^      range: .*", "      range: 1", launcher)
    (directory / "doom-blast-short.yaml").write_text(start + marker + launcher + separator + tail)
    print(f"Generated {len(files)} original WAD fixtures in {directory}")


if __name__ == "__main__":
    fixtures(pathlib.Path(sys.argv[1]))
