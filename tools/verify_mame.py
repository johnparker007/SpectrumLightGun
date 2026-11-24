"""Validate the actual INI addresses, values and startup self-test in MAME."""
import argparse
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from build import assembler_path, build
from verify import unpack_tape


def check(mame, rompath, work, model, s, image):
    # Load the same machine code into fixed RAM, then divert just the idle
    # entry to capture a known tone-register value through the acquisition path.
    ram = bytearray(image)
    probe = 0xbe00
    ram[s["rearm"]-32768:s["rearm"]-32768+3] = b"\xc3"+struct.pack("<H", probe)
    stub = (bytes.fromhex("01 fd ff af ed 79 06 bf 3e 59 ed 79 21") +
            struct.pack("<H", s["samples"]) + bytes.fromhex("11 00 00 cd") +
            struct.pack("<H", s["capture"]) + bytes.fromhex("f3 76"))
    (work/"probe.bin").write_bytes(ram)
    (work/"stub.bin").write_bytes(stub)
    lua = f"""
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local ioport = cpu.spaces["io"]
local function load_at(name, addr)
    local f = assert(io.open(name, "rb"))
    local data = f:read("*a")
    f:close()
    for i=1,#data do mem:write_u8(addr+i-1, data:byte(i)) end
end
load_at("probe.bin", 32768)
load_at("stub.bin", {probe})
local n, bad = 0, 0
-- Retain the tap object until the run completes. Limit inspection to INI.
local tap = ioport:install_read_tap(0xf6fd, 0xfffd, "ay-raster", function(off, value)
    local pc = cpu.state["PC"].value
    if pc >= {s['first_ini']} and pc <= {s['first_ini']+20} then
        if off ~= 0xfffd-256*(n%10) or value ~= 0x59 then bad=bad+1 end
        n=n+1
    end
end)
cpu.state["PC"].value=32768
local frames=0
emu.register_frame_done(function()
    frames=frames+1
    if frames == 15 then
        local mismatches=0
        for i=0,1919 do
            if mem:read_u8({s['samples']}+i) ~= 0x59 then mismatches=mismatches+1 end
        end
        local f=assert(io.open("result.txt","w"))
        f:write(n," ",bad," ",mismatches," ",mem:read_u8({s['bad_port']}))
        f:close()
        tap:remove()
        machine:exit()
    end
end)
"""
    script = work/"probe.lua"
    script.write_text(lua)
    result = work/"result.txt"
    result.unlink(missing_ok=True)
    run = subprocess.run([mame, model, "-rompath", rompath, "-noreadconfig", "-nowriteconfig",
                          "-autoboot_delay", "0", "-autoboot_script", script,
                          "-skip_gameinfo", "-window", "-bench", "3"], cwd=work,
                         capture_output=True, text=True, errors="replace", timeout=30)
    assert result.exists(), run.stdout + run.stderr
    assert result.read_text().split() == ["1920", "0", "0", "0"], (model, result.read_text())
    # Now run the unmodified app. Inject signals only at the documented
    # ports. Hold both presses for many frames to test release/rearm.
    (work/"probe.bin").write_bytes(image)
    live = lua[:lua.index("load_at(\"probe.bin\",")] + f"""
load_at("probe.bin",32768)
local frames, n, bad = 0, 0, 0
local started={{}}
local sweep_runs=0
local function check(ok) if not ok then bad=bad+1 end end
local gun = ioport:install_read_tap(0xf6fd,0xfffd,"gun",function(off,value)
    local pc=cpu.state["PC"].value
    local held=(frames>=20 and frames<32) or (frames>=70 and frames<82)
    local level=held and 0 or 32
    if pc>={s['first_ini']} and pc<={s['first_ini']+20} then
        local batch=math.floor(n/1920)+1
        local sample=n%1920
        if sample==0 then
            started[batch]=frames
            local attr=batch==2 and 0 or 127
            for i=0,767 do check(mem:read_u8(0x5800+i)==attr) end
        end
        n=n+1
        if ((batch==1 or batch==4) and sample==1809) or (batch==2 and sample<2) then level=level+16 end
        return level
    end
    if off==0xfffd and pc>={s['rearm']} and pc<{s['shot']} then return level end
end)
local keyboard=ioport:install_read_tap(0xf7fe,0xf7fe,"key1",function(off,value)
    if frames>=104 and frames<108 then return 253 end
    return ((frames>=8 and frames<11) or (frames>=65 and frames<69)) and 254 or 255
end)
local bitmapkey=ioport:install_read_tap(0xeffe,0xeffe,"key9",function(off,value)
    return ((frames>=50 and frames<52) or (frames>=60 and frames<62)) and 253 or 255
end)
cpu.state["PC"].value=32768
emu.register_frame_done(function()
    frames=frames+1
    if frames>=24 and frames<49 then
        check(n==1920)
        check(mem:read_u8({s['status']})==69)
        check(mem:read_u8({s['row']})==180 and mem:read_u8({s['idx']})==9)
        check(mem:read_u8(0x5800+22*32+29)==9)
        check(mem:read_u8(0x5800+22*32+28)==0x6d)
    end
    if frames==60 then
        -- The single injected high is slot 9 on line 180: X=225..255.
        local addr=0x4000+0x1000+0x400+6*32+28
        check(mem:read_u8(addr)==0x7f and mem:read_u8(addr+1)==255)
        check(mem:read_u8(addr-1)==0 and mem:read_u8(0x5800)==7)
    end
    if frames==88 then
        check(n==5760 and started[3]==started[2]+1)
        check(mem:read_u8({s['status']})==45 and mem:read_u16({s['dark_count']})==2)
        for i=0,767 do check(mem:read_u8(0x5800+i)~=9 and mem:read_u8(0x5800+i)~=0x6d) end
    end
    -- Frame callbacks observe the screen drawn during the preceding frame.
    if started[4] then
        local elapsed=frames-started[4]
        if elapsed>=2 and elapsed<=26 then
            check(mem:read_u8(0x5800+22*32+29)==9)
            check(mem:read_u8(0x5800+22*32+28)==0x6d)
            sweep_runs=sweep_runs+1
        elseif elapsed==27 then
            for i=0,767 do check(mem:read_u8(0x5800+i)==0) end
        end
    end
    if frames==148 then
        check(sweep_runs==25 and started[5]==started[4]+27)
        local f=assert(io.open("result.txt","w"))
        f:write(bad," ",n," frames ",table.concat(started,",")," pre ",mem:read_u8({s['preblack']})," status ",mem:read_u8({s['status']}))
        f:close()
        gun:remove()
        keyboard:remove()
        bitmapkey:remove()
        machine:exit()
    end
end)
"""
    script.write_text(live)
    result.unlink()
    run = subprocess.run(run.args, cwd=work, capture_output=True, text=True, timeout=30)
    assert result.exists() and result.read_text().startswith("0 9600 "), (
        model, result.read_text() if result.exists() else run.stderr)
    print(f"{model}: all AY aliases passed; held trigger, direct hit, black preframe, "
          "white miss, 25 marker frames and blank sweep preframe passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, required=True)
    parser.add_argument("--rompath", type=Path, required=True)
    parser.add_argument("--assembler", default=assembler_path())
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        sym, tap = work/"magnum.sym", work/"magnum.tap"
        build(args.assembler, tap, symbols=sym)
        symbols = {k: int(v, 16) for k, v in re.findall(r"^(\S+): EQU 0x(\w+)$", sym.read_text(), re.M)}
        for model in ("specpls2", "specpl2a", "specpls3"):
            check(args.mame.resolve(), args.rompath.resolve(), work, model, symbols,
                  unpack_tape(tap.read_bytes()))


