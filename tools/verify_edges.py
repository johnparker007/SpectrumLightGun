"""Run the edge tape's actual trigger path with known AUX waveforms in MAME."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

from build import ROOT, assembler_path, build
from mouse_gun import find_roms
from verify import unpack_tape


def check(mame, work, model, roms, s):
    script = work / "test.lua"
    script.write_text(f"""
local m=manager.machine
local cpu=m.devices[":maincpu"]
local mem=cpu.spaces["program"]
local f=assert(io.open("edges.bin","rb"))
local bytes=f:read("*a"); f:close()
for i=1,#bytes do mem:write_u8(32767+i,bytes:byte(i)) end
local frame,reads,errors=0,0,0
local previous_read
local function expect(a,b) if a~=b then errors=errors+1; print("expected",b,"got",a) end end
local function field(addr,n)
    local str=""
    for i=0,n-1 do str=str..string.char(mem:read_u8(addr+i)) end
    return str
end
local tap=cpu.spaces.io:install_read_tap(0xc7fd,0xfffd,"dense",function(port,v)
    local pc=cpu.state.PC.value
    if pc>={s['edge_blocks']}+2 and pc<={s['edge_capture_end']} then
        local i=reads%1368
        local now=m.time:as_double()
        if i>0 then
            local elapsed=math.floor((now-previous_read)*3546900+0.5)
            expect(elapsed,(i%57==0) and 23 or 16)
        end
        previous_read=now
        expect(port,0xfffd-(i%57)*256)
        -- No debugger reads of contended screen RAM during acquisition.
        local shot=reads//1368
        reads=reads+1
        local high=(shot==0 and i>=57 and i<700) or shot==2 or (shot==3 and i%2==1)
        return high and 48 or 32
    end
    if port==0xfffd and pc>={s['edge_rearm']} and pc<{s['edge_shot']} then
        return (frame>=12 and frame%50>=12 and frame%50<24) and 0 or 32
    end
end)
local key=cpu.spaces.io:install_read_tap(0xeffe,0xeffe,"next",function()
    return (frame>=44 and frame<47) and 251 or 255
end)
cpu.state.PC.value=32768
emu.register_frame_done(function()
    frame=frame+1
    if frame==40 then
        expect(mem:read_u16({s['edge_count']}),2)
        expect(field({s['edge_rise']},5),"{stamp(57)}")
        expect(field({s['edge_fall']},5),"{stamp(700)}")
        expect(field({s['edge_event']},17),"0001 + {stamp(57)} W 17")
        expect(mem:read_u8(0x5800+22*32),0)
    elseif frame==50 then
        expect(field({s['edge_event']},17),"0002 - {stamp(700)} W 10")
    elseif frame==90 or frame==140 then
        expect(mem:read_u16({s['edge_count']}),0)
        expect(field({s['edge_start_bit']},1),frame==90 and "0" or "1")
        expect(field({s['edge_end_bit']},1),frame==90 and "0" or "1")
        expect(field({s['edge_rise']},5),"--:--")
        expect(field({s['edge_fall']},5),"--:--")
    elseif frame==192 then
        expect(mem:read_u16({s['edge_count']}),1367)
        expect(field({s['edge_rise']},5),"{stamp(1)}")
        expect(field({s['edge_fall']},5),"{stamp(1366)}")
        expect(reads,5472)
        local out=assert(io.open("result.txt","w")); out:write(errors); out:close()
        key:remove(); tap:remove(); m:exit()
    end
end)
""")
    result = work/"result.txt"
    result.unlink(missing_ok=True)
    run = subprocess.run([mame, model, "-rompath", roms, "-noreadconfig", "-nowriteconfig",
                          "-autoboot_delay", "0", "-autoboot_script", script,
                          "-skip_gameinfo", "-window", "-bench", "5"], cwd=work,
                         capture_output=True, text=True, timeout=30)
    assert result.exists() and result.read_text() == "0", run.stdout[-4000:]+run.stderr
    print(model, "trigger, aliases, edge bounds, navigation, flat and alternating inputs passed")


def stamp(index):
    y, t = divmod(16*index+7*(index//57), 228)
    return f"{48+y:02X}:{t:02X}"


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mame", type=Path, required=True)
    p.add_argument("--rompath", type=Path)
    args = p.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        sym, tap = work/"edges.sym", work/"edges.tap"
        build(assembler_path(), tap, symbols=sym, edges=True)
        assert tap.read_bytes() == (ROOT/"build/edges.tap").read_bytes()
        data = unpack_tape(tap.read_bytes())
        (work/"edges.bin").write_bytes(data)
        s = {k:int(v,16) for k,v in re.findall(r"^(\w+): EQU 0x(\w+)$",sym.read_text(),re.M)}
        assert data[s["edge_blocks"]-32768:s["edge_capture_end"]-32768] == (b"\x06\xff"+b"\xed\xa2"*57)*24
        assert s["samples"]+1368 <= 0xc000
        for model in ("specpls2","specpl2a","specpls3"):
            mame = args.mame.resolve()
            check(mame, work, model, find_roms(args.rompath,mame,work,model), s)


