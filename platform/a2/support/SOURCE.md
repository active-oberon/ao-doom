# A2 support libraries

`YAML.Mod` and `Logging.Mod` are copied without changes from the adjacent
MiniA2 checkout (HEAD `39023192139c0b49f18aaade17e40fd065a391b7`).
They provide the same configuration and logging APIs used by the game on the
standalone SDK. They compile against the full A2 libraries; there is no Unix
or Windows dependency in these two modules.

The original MiniA2/ETH A2 license is included in `LICENSE.txt`.

The portable game engine is supplied separately by `ao-game-engine`.
