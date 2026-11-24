"""Exercise the assembled Z80 routines with synthetic input in z88dk-ticks."""
import argparse
import operator
import re
import struct
import subprocess
import tempfile
from functools import reduce
from pathlib import Path

from build import ROOT, assembler_path, build


def word(n):
    return struct.pack("<H", n)


def unpack_tape(data):
    blocks = []
    while data:
        size, = struct.unpack_from("<H", data)
        body, data = data[2:2+size], data[2+size:]
        assert len(body) == size and reduce(operator.xor, body) == 0
        blocks.append(body[:-1])
    loader, basic, header, payload = blocks
    assert loader[0:2] == bytes([0, 0]) and loader[14:16] == word(10)
    assert basic[0] == payload[0] == 255 and header[:2] == bytes([0, 3])
    assert header[12:16] == word(len(payload)-1) + word(32768)
    return payload[1:]


def verify(work, ticks, asm):
    symbols, tap = work/"probe.sym", work/"probe.tap"
    build(asm, tap, symbols=symbols)
    assert tap.read_bytes() == (ROOT/"build/magnum.tap").read_bytes()
    image = unpack_tape(tap.read_bytes())
    s = {k: int(v, 16) for k, v in re.findall(r"^(\S+): EQU 0x(\w+)$", symbols.read_text(), re.M)}
    base = bytearray(65536)
    base[32768:32768+len(image)] = image
    assert 0x8000 <= s["capture"] < s["samples"] <= 0xc000-6*1920
    assert base[s["first_ini"]:s["first_ini"]+20] == b"\xed\xa2"*10
    assert base[s["line"]:s["first_ini"]] == b"\x06\xff"
    ram_path, out = work/"input.bin", work/"out.bin"

    def run(ram, code, end=None, limit=300000):
        # Small call site in spare memory. No interrupts or peripherals.
        pc = 0xc000
        ram[pc:pc+len(code)] = code
        ram_path.write_bytes(ram)
        stop = pc+len(code) if end is None else end
        subprocess.run([ticks, ram_path, "-pc", f"{pc:x}", "-end", f"{stop:x}",
                        "-counter", str(limit), "-output", out], capture_output=True, check=True)
        return out.read_bytes()[:65536]

    call = lambda name: b"\xcd" + word(s[name])
    init = b"\x31" + word(s["stack_top"])
    decode = init + call("clear_attrs") + b"\x21" + word(s["samples"]) + call("decode") + call("mark")
    for phase in range(16):
        for idx in range(-1, 10):
            ram = base.copy()
            ram[s["phase"]] = phase
            ram[0x5800:0x5b00] = bytes([9])*768  # a stale result must disappear
            row = (191, 0, 79)[idx % 3]
            if idx >= 0:
                ram[s["samples"]+10*row+idx] = 0x30
            ram = run(ram, decode)
            status = chr(ram[s["status"]])
            assert status == ("-" if idx < 0 else "H" if idx == 0 else "E")
            marks = [i for i, attr in enumerate(ram[0x5800:0x5b00]) if attr == 9]
            if idx >= 0:
                assert (ram[s["row"]], ram[s["idx"]]) == (row, idx)
            if idx <= 0:
                assert marks == []
                continue
            hi = 2*(phase-16+idx*16)
            lo = hi-32
            hi += 6
            x = (max(lo, 0)+min(hi, 255))//2
            assert struct.unpack_from("<hh", ram, s["lower"]) == (lo, hi)
            assert ram[s["raw_x"]] == x and marks == [32*(row//8)+x//8]

    ram = base.copy()
    ram[s["samples"]+1920:s["samples"]+3840] = bytes([16, 32, 255])*640
    ram = run(ram, init + call("count_black"))
    assert struct.unpack_from("<H", ram, s["dark_count"])[0] == 1280

    # A long HIGH can hide later edges in the primary reading. Both raw maps
    # must still show every bit, including data across Spectrum bitmap thirds.
    for slot, column in enumerate((4, 18)):
        ram = base.copy()
        addr = s["samples"] + slot*1920
        pattern = bytes(16 if (i//10*3+i%10)%11 < 4 else 32 for i in range(1920))
        ram[addr:addr+1920] = pattern
        code = init + b"\x21" + word(addr) + bytes([0x1e, column]) + call("draw_trace")
        ram = run(ram, code)
        for y in range(192):
            bitmap = 0x4000 + ((y&192)<<5) + ((y&7)<<8) + ((y&56)<<2) + column
            for k in range(10):
                assert ram[bitmap+k] == (0xfe if pattern[10*y+k]&16 else 0x80)
                assert ram[0x5800+32*(y//8)+column+k] == 5

    # Each bin exercises a high count from 0 to 8. Set the leading border slot
    # high and unrelated AY bits throughout to catch false colour or padding.
    ram = base.copy()
    for y in range(192):
        for slot in range(10):
            count = (y//8 + max(0,slot-2)) % 9
            high = slot == 0 or (y%8 < count and (slot >= 3 or slot == 1+(y&1)))
            ram[s["samples"]+10*y+slot] = 0xef | (16 if high else 0)
    before = ram[s["samples"]:s["samples"]+1920]
    ram = run(ram, init + call("draw_colour"))
    assert ram[s["samples"]:s["samples"]+1920] == before
    for row in range(24):
        for x in range(32):
            count = (row+x//4) % 9
            assert ram[0x5800+row*32+x] == 9*((7*count+4)//8)

    # Compare all 49,152 replay pixels with the stored right-hand sample.
    # Include both bitmap-third boundaries, dark lines and isolated edge hits.
    ram = base.copy()
    pattern = bytes(0xef | (16 if (y*3+i)%13 < y%11 else 0)
                    for y in range(192) for i in range(10))
    ram[s["samples"]:s["samples"]+1920] = pattern
    ram = run(ram, init + call("draw_bitmap"))
    assert ram[s["samples"]:s["samples"]+1920] == pattern
    assert ram[0x5800:0x5b00] == bytes([7])*768
    for y in range(192):
        addr = 0x4000 + ((y&192)<<5) + ((y&7)<<8) + ((y&56)<<2)
        for x in range(256):
            actual = ram[addr+x//8] & (128>>(x%8))
            assert bool(actual) == bool(pattern[10*y+1+(x+31)//32] & 16)

    # Replace IN A,(C) with LD A,(BC); NOP only for the button-state tests.
    # Reaching the sentinels sets RAM flags, so a timeout cannot pass as an edge.
    for entry, level, expected in [("rearm", 0, None), ("rearm", 32, "idle"),
                                    ("idle", 32, None), ("idle", 0, "shot")]:
        ram = base.copy()
        for pos in range(s["rearm"], s["shot"]):
            if ram[pos:pos+2] == b"\xed\x78":
                ram[pos:pos+2] = b"\x0a\x00"
        ram[0xfffd] = level
        ram[0xf7fe] = ram[0xeffe] = 255
        dest = s["idle" if entry == "rearm" else "shot"]
        ram[dest:dest+5] = b"\x3e\x01\x32\x00\xf0"
        ram = run(ram, init + b"\xc3" + word(s[entry]),
                  end=dest+5, limit=8000)
        assert ram[0xf000] == bool(expected)
    print("TAP reproducibility/checksums, 176 synthetic sample frames, dark counts and trigger gates passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ticks", default="z88dk-ticks")
    parser.add_argument("--assembler", default=assembler_path())
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        verify(Path(tmp), args.ticks, args.assembler)
