#!/usr/bin/env python3
"""logging_smoke checks game startup errors and the headless logger output."""

import json
import pathlib
import re
import subprocess
import sys
import tempfile


def records(output):
    entries = [json.loads(line) for line in output.splitlines() if line.startswith('{"time":')]
    assert entries, output
    for entry in entries:
        assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", entry["time"])
        assert entry["attrs"]["component"] == "doom"
    return entries


def run(executable, arguments, cwd=None):
    return subprocess.run([str(executable), *arguments], timeout=10,
                          cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def main():
    headless, window = (pathlib.Path(arg).resolve() for arg in sys.argv[1:3])
    result = run(headless, [], cwd=headless.parent)
    assert result.returncode == 0, result.stdout
    entries = records(result.stdout)
    assert len(entries) == 1 and entries[0]["level"] == "INFO", entries
    assert entries[0]["msg"] == "scene, movement, collision and WAD checks passed"
    with tempfile.TemporaryDirectory(prefix="ao-doom-log-check-") as directory:
        missing = str(pathlib.Path(directory) / 'missing "profile".yaml')
        cases = [(["--config"], "--config requires a YAML file path", {}),
                 (["--config", missing], "configuration load failed", {"path": missing}),
                 (["--config", "tests/doom-incomplete.yaml"], "configuration load failed",
                  {"path": "tests/doom-incomplete.yaml"}),
                 (["build/bad-vertex.wad", "E1M1"], "map load failed",
                  {"path": "build/bad-vertex.wad", "map": "E1M1"})]
        for arguments, message, expected in cases:
            result = run(window, arguments)
            assert result.returncode != 0, result.stdout
            entry = records(result.stdout)[-1]
            assert entry["level"] == "ERROR" and entry["msg"] == message, entry
            for key, value in expected.items():
                assert entry["attrs"][key] == value, entry
            if expected:
                assert entry["attrs"]["error"], entry
    print("Logging GUI check passed: INFO/ERROR, context, typed fields and escaped failure paths")


if __name__ == "__main__":
    main()
