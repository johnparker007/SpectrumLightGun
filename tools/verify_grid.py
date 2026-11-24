"""Time the grid TAP payload in MAME with four synthetic shots per machine."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

from build import ROOT, assembler_path, build
from mouse_gun import find_roms
from verify import unpack_tape


def check(mame, work, rompath, model):
    result = work / "result.txt"
    result.unlink(missing_ok=True)
    subprocess.run([mame, model, "-rompath", rompath, "-noreadconfig", "-nowriteconfig",
                    "-autoboot_delay", "0", "-autoboot_script", ROOT/"tools/grid_latency.lua",
                    "-skip_gameinfo", "-window", "-bench", "6"], cwd=work, check=True, timeout=40)
    rows = [[int(v) for v in line.split()] for line in result.read_text().splitlines()]
    assert len(rows) == 4, rows
    for row, ammo, live in zip(rows, (3, 2, 1, 0),
                               ((2, 0, 255, 2), (2, 0, 255, 255),
                                (2, 0, 255, 255), (255, 0, 255, 255))):
        reads, capture, decision, paint, decision_t, paint_t, bullets, *lanes = row
        assert reads == 1920 and decision == capture and paint == capture+1, row
        assert 58000 < decision_t < 70908 and 0 < paint_t < 14364, row
        assert bullets == ammo and tuple(lanes) == live, row
    print(model, "decision / board-ready T after respective ISR frame-counter writes",
          [(r[4], r[5]) for r in rows], flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=ROOT.parent/"mame/mame270.exe")
    parser.add_argument("--rompath", type=Path)
    parser.add_argument("--models", nargs="+", default=["specpls2", "specpl2a", "specpls3"])
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        build(assembler_path(), work/"grid.tap", symbols=work/"grid.sym", grid=True)
        (work/"grid.bin").write_bytes(unpack_tape((work/"grid.tap").read_bytes()))
        labels = dict(re.findall(r"^(\w+): EQU (0x[0-9A-Fa-f]+)$",
                                 (work/"grid.sym").read_text(), re.M))
        names = ("entry", "frame", "grid_rearm", "grid_shot", "first_ini", "grid_reads_end",
                 "grid_decided", "grid_board_ready", "grid_ammo", "grid_live")
        (work/"labels.lua").write_text("return {"+",".join(k+"="+labels[k] for k in names)+"}")
        for model in args.models:
            folder = work/model
            folder.mkdir()
            roms = find_roms(args.rompath, args.mame, folder, model)
            check(args.mame.resolve(), work, roms, model)
