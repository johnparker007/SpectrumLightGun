"""Run the Spectrum diagnostic with an explicit mouse-to-AUX model in MAME."""
import argparse
import os
import re
import shutil
import subprocess
import tempfile
import zlib
from pathlib import Path

from build import ROOT, assembler_path, build
from verify import unpack_tape


def find_roms(configured, mame, work, model):
    if configured:
        return configured.resolve()
    installed = mame.parent / "roms"
    if any((installed / name).exists() for name in (model, model+".zip", model+".7z")):
        return installed
    # The local ZEsarUX installation stores the same Sinclair ROMs concatenated.
    source = Path(os.getenv("ZESARUX_HOME", "C:/ZEsarUX_windows-10.2"))
    if model == "specpls2":
        data = (source / "p2.rom").read_bytes()
        chips = (("zxp2_0.rom", 0x5d2e8c66), ("zxp2_1.rom", 0x98b1320b))
    else:
        data = (source / "p2a40.rom").read_bytes()
        chips = (("40092.ic7", 0x9bc85686), ("40093.ic8", 0xdb551783))
    folder = work / "roms" / model
    folder.mkdir(parents=True)
    half = len(data)//2
    for i, (name, crc) in enumerate(chips):
        chip = data[i*half:(i+1)*half]
        if zlib.crc32(chip) != crc:
            raise ValueError(f"Installed ROM differs from the expected {name}")
        (folder / name).write_bytes(chip)
    return folder.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=os.getenv("MAME") or shutil.which("mame")
                        or ROOT.parent / "mame/mame270.exe")
    parser.add_argument("--rompath", type=Path, default=os.getenv("MAME_ROMPATH"))
    parser.add_argument("--model", choices=["specpls2", "specpl2a", "specpls3"], default="specpl2a")
    parser.add_argument("--assembler", default=assembler_path())
    variant = parser.add_mutually_exclusive_group()
    variant.add_argument("--arcade", action="store_true")
    variant.add_argument("--grid", action="store_true", help="Play the target grid prototype")
    args = parser.parse_args()
    mame = args.mame.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="magnum-mouse-") as directory:
        work = Path(directory)
        rompath = find_roms(args.rompath, mame, work, args.model)
        sym, tap = work/"magnum.sym", work/"magnum.tap"
        build(args.assembler, tap, symbols=sym, grid=args.grid, arcade=args.arcade)
        (work/"magnum.bin").write_bytes(unpack_tape(tap.read_bytes()))
        labels = dict(re.findall(r"^(\w+): EQU (0x[0-9A-Fa-f]+)$", sym.read_text(), re.M))
        names = ("entry", "rearm", "shot", "first_ini", "phase", "status", "shown_x", "shown_y")
        if args.arcade:
            names += ("grid_reads_end", "arcade_start")
            labels["rearm"] = labels["arc_poll"]
            labels["shot"] = labels["arc_poll_end"]
        if args.grid:
            names += ("grid_reads_end",)
            labels["rearm"] = labels["grid_rearm"]
            labels["shot"] = labels["grid_shot"]
        (work/"labels.lua").write_text("return {"+",".join(f"{n}={labels[n]}" for n in names)+"}")
        cmd = [mame, args.model, "-rompath", rompath.resolve(), "-noreadconfig", "-nowriteconfig",
               "-skip_gameinfo", "-window", "-nomaximize", "-video", "gdi", "-resolution", "704x592",
               "-autoboot_delay", "0", "-autoboot_script", ROOT/"tools/mouse_gun.lua"]
        subprocess.run(cmd, cwd=work, check=True)


if __name__ == "__main__":
    main()

