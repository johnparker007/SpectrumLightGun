"""Assemble in a temporary directory and package a self-starting 128 BASIC tape."""
import argparse
import operator
import os
import re
import shutil
import struct
import subprocess
import tempfile
from functools import reduce
from pathlib import Path

from fair_scenery import write_scenery

ROOT = Path(__file__).resolve().parents[1]


def block(flag, data):
    body = bytes([flag]) + data
    return struct.pack("<H", len(body) + 1) + body + bytes([reduce(operator.xor, body)])


def tape_file(kind, name, data, param1, param2):
    header = struct.pack("<B10sHHH", kind, name.ljust(10), len(data), param1, param2)
    return block(0, header) + block(255, data)


def pack_engine(data):
    """Literal runs and backward copies; the Z80 expands these once per scene."""
    output, literals = bytearray(), bytearray()
    def flush():
        if literals:
            output.append(len(literals))
            output.extend(literals)
            literals.clear()
    pos = 0
    while pos < len(data):
        length = 3
        source = data.rfind(data[pos:pos+3], 0, pos)
        if source >= 0 and pos+3 <= len(data):
            while length < min(130, len(data)-pos) and data[source+length] == data[pos+length]:
                length += 1
            flush()
            output.append(128+length-3)
            output.extend(struct.pack("<H", pos-source))
            pos += length
        else:
            literals.append(data[pos])
            pos += 1
            if len(literals) == 127:
                flush()
    flush()
    return bytes(output)+b"\0"


def build(assembler, output, dx=0, dy=0, symbols=None, snapshot=None, edges=False, grid=False, arcade=False):
    if max(abs(dx), abs(dy)) > 255:
        raise ValueError("Offsets must fit -255..255 pixels")
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        if arcade:
            scenes = []
            for scene in write_scenery(work, ROOT):
                packed = pack_engine(scene)
                if len(scene) > 0xdb09 - 0xc000 or len(packed) > 0x1800:
                    raise ValueError("Backdrop exceeds runtime staging space")
                scenes.append(packed)
            offset = 4*len(scenes)
            directory = bytearray()
            for scene in scenes:
                directory.extend(struct.pack("<HH", 0xc000+offset, len(scene)))
                offset += len(scene)
            artwork = directory + b"".join(scenes)
            if not 0x1800 < len(artwork) <= 0x3800:
                raise ValueError("Artwork does not fit startup staging areas")
            (work/"art_size.inc").write_text(f"art_size equ {offset}\n")
        subprocess.run([str(assembler), "--nologo", "--raw=main.bin", "--sym=main.sym",
                        *(["-DARCADE=1"] if arcade else []), *(["-DGRID_GAME=1"] if grid or arcade else []), *(["-DEDGE_DIAG=1"] if edges else []), f"-DOFFSET_X={dx}", f"-DOFFSET_Y={dy}", str(ROOT/"src/magnum.asm")],
                       cwd=work, check=True)
        image = (work/"main.bin").read_bytes()
        if arcade:
            # Build the installed z88dk NIRVANA+ source in isolation. The game
            # pages this engine in at its linked address for each playable stage.
            z88dk = Path(os.getenv("Z88DK", "C:/z88dk"))
            source = z88dk/"libsrc/_DEVELOPMENT/arch/zx/nirvanap/z80/NIRVANAP_ENGINE.asm"
            (work/"nirvana.asm").write_text(source.read_text().replace(
                "defc __NIRVANAP_OPTIONS = 0", "defc __NIRVANAP_OPTIONS = 3"))
            binary = shutil.which("z88dk-z80asm") or z88dk/"bin/z80asm.exe"
            subprocess.run([str(binary), "-b", "-m", "nirvana.asm"], cwd=work, check=True)
            engine_map = (work/"nirvana.map").read_text()
            for name, addr in {"org_nirvanap": 0xdb09, "_NIRVANAP_WIDE_IMAGES": 0xdb2f,
                               "main_engine": 0xdc86, "asm_NIRVANAP_paintC": 0xdc62,
                               "asm_NIRVANAP_start": 0xfde3}.items():
                match = re.search(r"^"+name+r"\s+= \$([0-9A-F]+)", engine_map, re.M)
                if not match or int(match[1], 16) != addr:
                    raise ValueError("Incompatible NIRVANA+ layout: "+name)
            engine = (work/"nirvana_NIRVANAP.bin").read_bytes()
            # The serialised engine is first loaded into fixed RAM. Expand into
            # bank zero at stage entry, independent of the BASIC loader's top bank.
            if len(engine) != 0x2459:
                raise ValueError("Unexpected NIRVANA+ engine size")
            engine = pack_engine(engine)
            if len(image)+len(engine) > 0x4000:
                raise ValueError("Fixed-bank staging space exceeded")
            image = (image+engine).ljust(0x4000,b"\0") + artwork
        if symbols:
            shutil.copyfile(work/"main.sym", symbols)
        if snapshot:
            # 48K SNA for emulator probes; target model supplied by debugger.
            ram = bytearray(49152)
            ram[0x4000:0x4000+len(image)] = image
            ram[0x3ffe:0x4000] = b'\x00\x80'
            regs = bytearray(27)
            regs[23:25] = b'\xfe\x7f'
            snapshot.write_bytes(regs + ram)
    line = b'\xfd\xb0"32767":\xef""\xaf:\xf9\xc0\xb0"32768"\r'
    basic = b'\0\x0a' + struct.pack("<H", len(line)) + line
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(tape_file(0, b"MAGNUM", basic, 10, len(basic))
                       + tape_file(3, b"RASTER", image, 32768, 32768))
    print(f"{output} ({len(image)} code/data/reserved bytes)")


def assembler_path():
    return (os.getenv("SJASMPLUS") or shutil.which("sjasmplus")
            or Path.home()/"Desktop/_temp/sjasmplus-1.20.2.win/sjasmplus.exe")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assembler", default=assembler_path())
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--offset-x", type=int, default=0)
    parser.add_argument("--offset-y", type=int, default=0)
    parser.add_argument("--symbols", type=Path)
    parser.add_argument("--snapshot", type=Path)
    variant = parser.add_mutually_exclusive_group()
    variant.add_argument("--arcade", action="store_true", help="Build the gun-controlled arcade")
    variant.add_argument("--grid", action="store_true", help="Build the four-lane target game")
    variant.add_argument("--edges", action="store_true", help="Build the mid-screen transition timing test")
    args = parser.parse_args()
    args.output = args.output or ROOT/"build"/("arcade.tap" if args.arcade else "grid.tap" if args.grid else "edges.tap" if args.edges else "magnum.tap")
    build(args.assembler, args.output, args.offset_x, args.offset_y, args.symbols, args.snapshot, args.edges, args.grid, args.arcade)
