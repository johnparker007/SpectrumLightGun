"""Run a gun-only route through Raster Fair using the TAP payload in MAME."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from build import ROOT, assembler_path, build
from mouse_gun import find_roms
from verify import unpack_tape
from fair_scenery import write_scenery


def check(model, args):
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        build(assembler_path(), work/"arcade.tap", symbols=work/"arc.sym", arcade=True)
        payload = unpack_tape((work/"arcade.tap").read_bytes())
        assert payload == unpack_tape((ROOT/"build/arcade.tap").read_bytes())
        (work/"arc.bin").write_bytes(payload)
        names = ("entry", "arc_poll", "arc_poll_end", "first_ini", "grid_reads_end", "arc_state",
                 "arc_stage", "mode_seconds_left", "mode_expired", "arc_tour", "mode_gate", "arc_note", "arc_total", "arc_ammo", "arc_hits", "arc_pos", "arc_hazards", "arc_armed",
                 "parade_last", "arc_wave_phase", "arc_raw_y", "arc_last_tick", "frame", "arc_alive")
        symbols = dict(re.findall(r"^(\w+): EQU (0x[0-9A-Fa-f]+)$", (work/"arc.sym").read_text(), re.M))
        (work/"labels.lua").write_text("return {"+",".join(k+"="+symbols[k] for k in names)+"}")
        write_scenery(work, ROOT)
        roms = find_roms(args.rompath, args.mame, work, model)
        script = ROOT/"tools/arcade_route.lua"
        run = subprocess.run([args.mame, model, "-rompath", roms, "-noreadconfig", "-nowriteconfig",
                              "-skip_gameinfo", "-window", "-bench", "145", "-snapshot_directory", work/"snap",
                              "-autoboot_delay", "0", "-autoboot_script", script],
                             cwd=work, capture_output=True, text=True, timeout=50)
        report = (work/"route.txt").read_text() if (work/"route.txt").exists() else ""
        print(model, [line for line in report.splitlines() if "cadence" in line], report[-350:], flush=True)
        assert report.rstrip().endswith("PASS"), report + run.stderr + run.stdout
        if args.screens:
            args.screens.mkdir(exist_ok=True, parents=True)
            titles = re.findall(r"^snapshot (.+)$", report, re.M)
            for file, title in zip(sorted((work/"snap").rglob("*.png")), titles, strict=True):
                shutil.copyfile(file, args.screens/f"arcade-{title}.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=ROOT.parent/"mame/mame270.exe")
    parser.add_argument("--rompath", type=Path)
    parser.add_argument("--models", nargs="+", default=["specpls2", "specpl2a", "specpls3"])
    parser.add_argument("--screens", type=Path)
    args = parser.parse_args()
    for model in args.models:
        check(model, args)
