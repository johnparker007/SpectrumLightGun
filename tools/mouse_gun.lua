-- Ideal mouse gun for this diagnostic. No alteration of Z80 code or samples.
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local labels = dofile("labels.lua")
if labels.arcade_start then
for _,bank in ipairs({1,4,6}) do
    local f=assert(io.open("bank"..bank..".bin","rb"))
    local data=f:read("*a")
    f:close()
    cpu.spaces.io:write_u8(0x7ffd,16+bank)
    for i=1,#data do mem:write_u8(0xbfff+i,data:byte(i)) end
end
cpu.spaces.io:write_u8(0x7ffd,16)
end
local f = assert(io.open("magnum.bin", "rb"))
local image = f:read("*a")
f:close()
for i = 1, #image do mem:write_u8(labels.entry+i-1, image:byte(i)) end

local view = machine.render.ui_target.current_view
local paper_x, paper_y, held = -1, -1, false
view.show_pointers = true
view:set_pointer_updated_callback(function(kind, id, device, x, y, buttons)
    -- Default single-screen view, 352x296 visible pixels including border.
    paper_x = math.floor(x*352)-48
    paper_y = math.floor(y*296)-48
    held = (buttons & 1) ~= 0
end)
local function leave()
    paper_x, paper_y, held = -1, -1, false
end
view:set_pointer_left_callback(leave)
view:set_pointer_aborted_callback(leave)

local function white_at(x, y)
    local screen = labels.arcade_start and 0xc000 or 0x4000
    local attr = mem:read_u8(screen+0x1800+(y//8)*32+x//8)
    local addr = screen + ((y & 0xc0)<<5) + ((y & 7)<<8) + ((y & 0x38)<<2) + x//8
    local ink = (mem:read_u8(addr) & (0x80 >> (x%8))) ~= 0
    return ((ink and attr or (attr >> 3)) & 7) == 7
end

-- Sample the optical mask while bank 7 is still mapped, just before the
-- Z80 pages uncontended bank 0 under the AY read address.
local arcade_white = false
local page_tap
if labels.arcade_start then
    page_tap = cpu.spaces.io:install_write_tap(0x7ffd,0x7ffd,"mouse-mask",function(_,v)
        if v==24 then
            arcade_white = paper_x>=0 and paper_x<256 and paper_y>=0 and paper_y<192
                and white_at(paper_x,paper_y)
        end
    end)
end

local reads_end = labels.grid_reads_end or labels.first_ini+20
local first_phase = labels.grid_reads_end and -17 or -16
local sample = 0
local tap = cpu.spaces["io"]:install_read_tap(0xf6fd, 0xfffd, "mouse-magnum", function(port, value)
    local pc = cpu.state["PC"].value
    local reading = pc >= labels.first_ini and pc <= reads_end
    local trigger = port == 0xfffd and pc >= labels.rearm and pc < labels.shot
    if not reading and not trigger then return end
    value = (value & 0xcf) | (held and 0 or 0x20)
    if reading then
        local row, index = sample // 10, sample % 10
        sample = (sample+1) % 1920
        -- One artificial 16T pulse on the selected line under white illumination.
        local beam = 2*(first_phase+mem:read_u8(labels.phase)+16*index)
        if row == paper_y and paper_x >= 0 and paper_x < 256
                and beam >= paper_x and beam < paper_x+32
                and ((page_tap and arcade_white) or (not page_tap and white_at(paper_x,row))) then
            value = value | 0x10
        end
    end
    return value
end)
cpu.state["PC"].value = labels.entry
local previous = ""
emu.register_frame_done(function()
    -- Retain the tap, and expose results to the launcher console for checks.
    if not tap then return end
    local result = string.char(mem:read_u8(labels.status))
    if result == "E" then
        result = string.format("EDGE %d,%d", mem:read_u8(labels.shown_x), mem:read_u8(labels.shown_y))
    end
    if previous ~= result then print("Mouse Magnum: "..result); io.stdout:flush(); previous = result end
end)

