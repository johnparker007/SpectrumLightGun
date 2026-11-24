"""Run ZEsarUX breakpoint probes against TAP startup and the assembled capture code."""
import argparse
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from build import ROOT, assembler_path, build


def trace(emulator, model, image, points, seconds):
    load = (["--fastautoload", "--tape"] if image.suffix == ".tap"
            else ["--snap-no-change-machine", "--snap"])
    args = [emulator, "--noconfigfile", "--vo", "null", "--ao", "null",
            "--disable-debug-console-win", "--nowelcomemessage", "--stats-disable-check-updates",
            "--stats-disable-check-yesterday-users", "--machine", model, "--realvideo",
            *load, image, "--enable-breakpoints", "--exit-after", str(seconds),
            "--quickexit", "--verbose", "2"]
    if model.startswith("P3") and image.suffix == ".tap":
        # +3 Loader checks drive A first and prompts before using cassette.
        keys = image.with_suffix(".keys")
        keys.write_bytes(b"\r" * 100)
        args += ["--keyboardspoolfile", keys, "--keyboardspoolfile-play",
                 "--keyboardspoolfile-keylength", "4"]
    for n, (condition, expression) in enumerate(points, 1):
        args += ["--set-breakpoint", str(n), condition,
                 "--set-breakpointaction", str(n), "printe " + expression]
    out = subprocess.run(args, cwd=emulator.parent, capture_output=True, text=True,
                         errors="replace", check=True, timeout=seconds+45).stdout
    return [(int(pc, 16), int(value)) for pc, value in
            re.findall(r"Catch breakpoint: PC=([A-F0-9]+)H[^\n]*\n(-?\d+)", out)]


def check(emulator, model, work, symbols, snap, tap):
    s = symbols
    pc = lambda key: f"PC={s[key]:04X}H"
    peek = lambda key: f"PEEK({s[key]:04X}H)"
    boot = trace(emulator, model, tap, [(pc("start"), "PC")], 10)
    assert (s["start"], s["start"]) in boot, (model, "TAP did not start")
    original = snap.read_bytes()

    def force_mode(label):
        # Only redirect the idle entry in a disposable snapshot. The complete
        # frame scheduler, IRQ, ULA accesses and acquisition routine are real.
        data = bytearray(original)
        at = 27 + s["rearm"] - 0x4000
        data[at:at+3] = b"\xc3" + struct.pack("<H", s[label])
        out = work / (label + ".sna")
        out.write_bytes(data)
        return out

    # Check the port decoder with a known value in a readable AY tone
    # register. Leave the original input-mode setup and acquisition intact.
    addr = 0xbd00
    data = bytearray(original)
    at = 27+s["rearm"]-0x4000
    data[at:at+3] = b"\xc3" + struct.pack("<H", addr)
    code = bytearray.fromhex("01 fd ff af ed 79 06 bf 3e 59 ed 79")
    code += b"\x21" + struct.pack("<H", s["samples"]) + bytes.fromhex("11 00 00 cd")
    code += struct.pack("<H", s["capture"])
    code += b"\x21" + struct.pack("<H", s["samples"])
    # LD BC,1920; LD A,(HL); CP $59; JR NZ,done; INC HL; DEC BC;
    # LD A,B; OR C; JR NZ,loop. A full pass leaves BC=0.
    code += bytes.fromhex("01 80 07 7e fe 59 20 06 23 0b 78 b1 20 f5")
    done = addr+len(code)
    code += bytes.fromhex("f3 76")
    offset = 27+addr-0x4000
    data[offset:offset+len(code)] = code
    alias_image = work/"aliases.sna"
    alias_image.write_bytes(data)
    probe = trace(emulator, model, alias_image, [(f"PC={done:04X}H", "BC")], 2)
    assert probe, (model, "AY probe did not finish")
    remaining = probe[0][1]
    # Cross-check the independent full-raster readback against the on-device
    # self-test. Some ZEsarUX versions only implement the canonical port.
    flag = trace(emulator, model, alias_image, [(f"PC={done:04X}H", peek("bad_port"))], 2)
    assert flag and bool(flag[0][1]) == bool(remaining), (model, probe, flag)
    alias_report = (f"alias failure detected at {flag[0][1]:02X}FD"
                    if remaining else "1920 AY readbacks passed")

    events = trace(emulator, model, force_mode("sweep"), [
        (pc("first_ini") + f" AND HL={s['samples']:04X}H",
         f"{peek('frame')}*100000+TSTATES"),
        (pc("capture_end"), "TSTATES")], 25)
    starts = [divmod(v, 100000) for p, v in events if p == s["first_ini"]][:16]
    ends = [v for p, v in events if p == s["capture_end"]][:16]
    assert len(starts) == len(ends) == 16, (model, starts, ends)
    for phase, ((frame, t), end) in enumerate(zip(starts, ends)):
        assert (frame-starts[0][0]) % 256 == (phase*27) % 256, starts
        assert t == starts[0][1]+phase, starts
        assert end-t == 192*228-7, (model, phase, end-t)
    # Check all six frames were consecutive, including the last buffer.
    expr = f"{peek('frame')}*100000+TSTATES"
    burst = trace(emulator, model, force_mode("track"), [(pc("capture_end"), expr)], 3)
    frames = [v//100000 for _, v in burst[:6]]
    assert len(frames) == 6 and frames == list(range(frames[0], frames[0]+6)), frames
    print(f"{model}: TAP boot, {alias_report}, 16 phases, 27-frame cadence, 6-frame burst; "
          f"first INI starts at T={starts[0][1]}..{starts[-1][1]}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emulator", type=Path, required=True)
    parser.add_argument("--assembler", default=assembler_path())
    parser.add_argument("--models", nargs="+", default=["P2", "P2A41", "P341"])
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        symbols, snap, tap = [work / ("magnum." + ext) for ext in ("sym", "sna", "tap")]
        build(args.assembler, tap, symbols=symbols, snapshot=snap)
        table = {k: int(v, 16) for k, v in re.findall(r"^(\S+): EQU 0x(\w+)$",
                                                       symbols.read_text(), re.M)}
        for model in args.models:
            check(args.emulator.resolve(), model, work, table, snap, tap)
