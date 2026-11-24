local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local s = dofile("labels.lua")
local f = assert(io.open("grid.bin", "rb"))
local image = f:read("*a")
f:close()
for i=1,#image do mem:write_u8(s.entry+i-1,image:byte(i)) end
local report = assert(io.open("result.txt","w"))
local frames, irq, reads, shots = 0, 0, 0, 0
local origin, capture, decision, decision_t, first_read
local function ticks()
    return math.floor((machine.time:as_double()-origin)*3546900+0.5)
end
local taps = {}
taps[1] = mem:install_write_tap(s.frame,s.frame,"irq",function(_,value)
    irq = value
    origin = machine.time:as_double()
end)
taps[2] = cpu.spaces["io"]:install_read_tap(0xfffd,0xfffd,"gun",function(_,value)
    local pc = cpu.state["PC"].value
    if pc >= s.grid_rearm and pc < s.grid_shot then
        local held = frames>=70 and (frames-70)%12<7
        return (value & 0xcf) | (held and 0 or 32)
    end
    if pc < s.first_ini or pc > s.grid_reads_end then return end
    if reads==0 then
        shots=shots+1
        capture=irq
        first_read=ticks()
    end
    local elapsed=ticks()-first_read
    assert(math.abs(elapsed-(reads//10)*228-(reads%10)*16)<=1,"unexpected sample timing")
    -- Empty capture, bottom-row final slot, initially high, top-row first slot.
    local lit = (shots==2 and reads==1759) or (shots==3 and reads==0)
             or (shots==4 and reads==160)
    reads=reads+1
    return (value & 0xef) | (lit and 16 or 0)
end)
taps[3] = mem:install_read_tap(s.grid_decided,s.grid_decided,"decision",function()
    decision,decision_t=irq,ticks()
end)
taps[4] = mem:install_read_tap(s.grid_board_ready,s.grid_board_ready,"paint",function()
    local ammo=mem:read_u8(s.grid_ammo)
    for y=0,23 do
        for x=0,31 do
            local expected=0
            if y==0 and x%2==0 and x//2<ammo then expected=0x36 end
            if y%6>=2 and y%6<=3 and x%8>=3 and x%8<=4 then
                expected=mem:read_u8(s.grid_live+y//6)==x//8 and 0x64 or 0x09
            end
            assert(mem:read_u8(0x5800+y*32+x)==expected,"wrong result attribute")
        end
    end
    report:write(reads," ",capture," ",decision," ",irq," ",decision_t," ",ticks(),
                 " ",mem:read_u8(s.grid_ammo))
    for lane=0,3 do report:write(" ",mem:read_u8(s.grid_live+lane)) end
    report:write("\n")
    report:flush()
    reads=0
end)
cpu.state["PC"].value=s.entry
emu.register_frame_done(function()
    if #taps==0 then return end
    frames=frames+1
    if frames==125 then report:close();machine:exit() end
end)
