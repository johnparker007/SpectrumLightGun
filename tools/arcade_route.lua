local m=manager.machine
local cpu=m.devices[":maincpu"]
local mem, ioport=cpu.spaces.program,cpu.spaces.io
local s=dofile("labels.lua")
local f=assert(io.open("arc.bin","rb"))
local data=f:read("*a")
f:close()
for i=1,#data do mem:write_u8(s.entry+i-1,data:byte(i)) end
local out=assert(io.open("route.txt","w"))
local function log(str) out:write(str,"\n");out:flush() end
local function byte(key) return mem:read_u8(s[key]) end
-- aim X,Y (negative X follows live actor index), captures, ending state/stage/hits/ammo
local route={
    {0,0,1,0,0,0,0}, {80,130,1,1,1,0,5},
    {160,40,1,1,1,1,4}, {96,80,2,1,1,1,2},
    {96,80,2,1,1,1,1}, {32,22,2,2,1,1,0},
    {90,60,1,1,1,0,5}, -- replay
    {0,0,2,1,1,0,4}, {0,0,2,1,1,0,3}, {0,0,2,1,1,0,2},
    {0,0,2,1,1,0,1}, {0,0,2,2,1,0,0},
    {80,104,1,0,1,0,0}, {80,172,1,1,2,0,4},
    {-1,0,1,1,2,1,3}, {-2,0,1,1,2,2,2}, {-3,0,1,2,2,3,1},
    {90,104,1,0,2,3,1}, {80,90,1,1,0,0,5},
    {-1,0,1,1,0,1,4}, {-2,0,1,1,0,2,3}, {-3,0,1,1,0,3,2},
    {-4,0,1,2,0,4,1},
    {80,104,1,0,0,4,1}, {80,48,1,1,0,0,5}
}
-- Expected lane sequence and cumulative score for each distinct rule.
local rounds={5,5,4,5,9,6,6,5,6,1,3,5,5,6,6,2}
local special={
    [2]={{1,2,3},{1,2,3}}, [4]={{1,1,2,2,3,3,4,4},{0,1,1,2,2,3,3,4}},
    [5]={{1,4},{2,4}}, [9]={{3},{1}}, [10]={{1,2},{2,4}},
    [12]={{1,4,3,2},{1,2,3,4}}, [15]={{1,4},{1,5}}}
for stage=0,15 do
    local rule=special[stage] or {{1,2,3,4},{1,2,3,4}}
    for n,actor in ipairs(rule[1]) do
        table.insert(route,{-actor,0,1,n==#rule[1] and 2 or 1,stage,rule[2][n],rounds[stage+1]-n})
    end
    if stage<15 then table.insert(route,{80,60,1,1,stage+1,0,rounds[stage+2]}) end
end
table.insert(route,{80,60,1,0,16,5,0})
-- Visit all five pages and enter the last practice ticket.
for page=1,4 do table.insert(route,{80,25,1,0,16,5,0}) end
table.insert(route,{80,48,1,1,15,0,2})
table.insert(route,{-4,0,1,1,15,4,1})
table.insert(route,{-3,0,1,2,15,0,0}) -- overshoot
local function add(x,y,masks,state,stage,hits,ammo)
    table.insert(route,{x,y,masks,state,stage,hits,ammo})
end
add(100,104,1,0,15,0,0)
for i=1,4 do add(80,25,1,0,15,0,0) end -- page four
add(80,172,1,1,14,0,6)
local timeout_step=#route
add(80,104,1,0,14,0,6) -- after timer expires, leave results
for i=1,4 do add(80,25,1,0,14,0,6) end -- page three
add(80,90,1,1,8,0,6)
local shield_step=#route
add(-1,0,1,1,8,0,5)
-- Complete the shield round, then let each new timer run out from practice.
for actor=1,4 do add(-actor,0,1,actor==4 and 2 or 1,8,actor,5-actor) end
add(80,104,1,0,8,4,1)
local timed_entries={}
local function timed_stage(page_clicks, previous, hits, ammo, y, stage, shots, seconds)
    for i=1,page_clicks do add(80,25,1,0,previous,hits,ammo) end
    add(80,y,1,1,stage,0,shots)
    timed_entries[#route]=seconds
    add(80,104,1,0,stage,0,shots)
end
timed_stage(1,8,4,1,90,12,5,10)
timed_stage(3,12,0,5,172,6,6,12)
timed_stage(4,6,0,6,172,2,4,15)
local briefing_phase,briefing_wait=0,0
local briefs,scenes={},{}
local function snapshot(title)
    m.video:snapshot()
    log("snapshot "..title)
end
local timer_start
local frames,step,reads,batches,reg,page,noise,music=0,0,0,0,0,0,0,0
local x,y,held,waiting=0,0,false,false
local wave_frames,wave_changes,wave_notes=0,0,0
local prev_phase,prev_note,prev_writes
local wave_writes=0
local first,last
local arc_white=false
local taps={}
local function check(ok,msg)
    if ok then return end
    log("FAIL "..msg);m:exit();error(msg)
end
-- After active play (and erase passes), every painted scenery pixel must
-- still be present in the normal display bitmap.
local function check_backdrop(name)
    local file=assert(io.open(name..".tiles","rb"))
    local tiles=file:read("*a")
    file:close()
    for cell=0,703 do
        local tile=tiles:byte(1+cell)
        if tile~=0 then
            local col=cell%32
            for scan=0,7 do
                local y=8+(cell//32)*8+scan
                local addr=0x4000+((y & 0xc0)<<5)+((y & 7)<<8)+((y & 0x38)<<2)+col
                local expected=tiles:byte(705+12*tile+scan)
                check((mem:read_u8(addr) & expected)==expected,"erased "..name.." scenery")
            end
        end
    end
end
taps[1]=ioport:install_write_tap(0x7ffd,0x7ffd,"page",function(_,v)
    if v==24 then
        if step==15 then
            -- Compare the actual flashed pixels to all three latched sub-cell rectangles.
            for line=0,191 do
                for col=0,31 do
                    local expected=0
                    for slot=0,2 do
                        local left=mem:read_u8(s.parade_last+6+slot*2)
                        local top=mem:read_u8(s.parade_last+1+slot*2)-8
                        if line>=top and line<top+16 then
                            for bit=0,7 do
                                local px=col*8+bit
                                if px>=left and px<left+16 then expected=expected | (128>>bit) end
                            end
                        end
                    end
                    local addr=0xc000+((line & 0xc0)<<5)+((line & 7)<<8)+((line & 0x38)<<2)+col
                    check(mem:read_u8(addr)==expected,"wave mask geometry")
                end
            end
        end
        local attr=mem:read_u8(0xd800+(y//8)*32+x//8)
        local bits=mem:read_u8(0xc000+((y & 0xc0)<<5)+((y & 7)<<8)+((y & 0x38)<<2)+x//8)
        local ink=(bits & (0x80>>(x%8)))~=0
        arc_white=((ink and attr or attr>>3) & 7)==7
    end
    page=v
end)
taps[2]=ioport:install_write_tap(0xfffd,0xfffd,"reg",function(_,v) reg=v end)
taps[3]=ioport:install_write_tap(0xbffd,0xbffd,"ay",function(_,v)
    if reg==10 and v>0 then noise=noise+1 end
    if reg==0 then music=music+1 end
end)
taps[4]=ioport:install_read_tap(0xfffd,0xfffd,"gun",function(_,v)
    local pc=cpu.state.PC.value
    if pc>=s.arc_poll and pc<s.arc_poll_end then
        check(reg==14,"AY register during trigger poll")
        if held and route[step][1]<0 then
            local slot=s.arc_pos+2*(-route[step][1]-1)
            x,y=8*mem:read_u8(slot)+8,8*mem:read_u8(slot+1)+8
        end
        return (v & 0xcf) | (held and 0 or 32)
    end
    if pc<s.first_ini or pc>s.grid_reads_end then return end
    check(reg==14 and page==24,"capture page/AY")
    local n=reads%1920
    if n==0 then
        first=m.time:as_double()
        batches=batches+1
        if batches==2 then check(math.abs((first-last)*3546900-70908)<6,"second mask delayed") end
        last=first
    end
    local line,i=n//10,n%10
    check(math.abs((m.time:as_double()-first)*3546900-line*228-i*16)<2,"line/sample timing at "..n.." clocks "..((m.time:as_double()-first)*3546900))
    reads=reads+1
    local beam=2*(-17+16*i)
    local lit=false
    if y==line and beam>=x and beam<x+32 then
        lit=arc_white
    end
    return (v & 0xef) | (lit and 16 or 0)
end)
cpu.state.PC.value=s.entry
emu.register_frame_done(function()
    if #taps==0 then return end
    frames=frames+1
    if frames%100==0 then log("frame "..frames.." pc "..cpu.state.PC.value.." step "..step) end
    if held and batches>0 then held=false end
    if step==14 and not held and byte("arc_state")==1 and byte("arc_stage")==2 and byte("arc_armed")==1 then
        local phase,note=byte("arc_wave_phase"),byte("arc_note")
        if prev_phase then
            wave_frames=wave_frames+1
            if phase==(prev_phase+1)%72 then wave_changes=wave_changes+1 end
            wave_notes=wave_notes+(note-prev_note)%256
            wave_writes=wave_writes+music-prev_writes
        end
        prev_phase,prev_note,prev_writes=phase,note,music
    end
    if frames<15 or held or byte("arc_armed")==0 then return end
    if waiting then
        local r=route[step]
        -- Stage entry, replay and tour progression must all stop at a briefing.
        if byte("arc_state")==3 then
            check(r[4]==1 and briefing_phase~=3,"unexpected briefing or ignored start")
            check(byte("arc_stage")==r[5] and reads==1920,"wrong briefing")
            if briefing_phase==0 then
                briefs[r[5]]=true
                if step==2 or step==14 then snapshot(step==2 and "brief-yard" or "brief-wave") end
                x,y=80,64 -- instruction panel is visible but optically inactive
                briefing_phase=1
                reads,batches,held=0,0,true
                return
            end
            if briefing_phase==1 then
                briefing_wait=frames+12
                briefing_phase=2
            end
            if frames<briefing_wait then return end
            x,y=100,172
            reads,batches,held=0,0,true
            briefing_phase=3
            return
        end
        if r[4]==1 and step>1 and route[step-1][4]~=1 then
            check(briefing_phase==3,"skipped briefing")
        end
        briefing_phase=0
        log(string.format("shot %d masks %d state %d stage %d hits %d ammo %d",step,batches,byte("arc_state"),byte("arc_stage"),byte("arc_hits"),byte("arc_ammo")))
        check(reads==1920*r[3] and byte("arc_state")==r[4] and byte("arc_stage")==r[5]
          and byte("arc_hits")==r[6] and byte("arc_ammo")==r[7],"route step "..step)
        if step==4 then
            check(mem:read_u8(s.arc_hazards+1)==0,"bomb lane")
            check_backdrop("yard")
        end
        if byte("arc_tour")==1 and byte("arc_stage")==16 then check(byte("arc_total")==61,"tour score") end
        if timed_entries[step] then
            check(byte("mode_seconds_left")==timed_entries[step],"timer initial value")
            timer_start=frames
        end
        if step==#route then for id=0,15 do check(briefs[id] and scenes[id],"missing briefing or scene "..id) end;check(noise>=step and music>2,"audio writes");log("PASS");m:exit();return end
        waiting=false
    end
    -- Let each scene render before shooting it.
    if step==14 then
        if wave_frames<160 then return end
        if wave_frames==160 then
        check_backdrop("midway")
        log(string.format("wave cadence %d/%d steps, %d AY beats",wave_changes,wave_frames,wave_notes))
        check(wave_changes==wave_frames and wave_writes==wave_notes and math.abs(wave_notes-wave_frames/8)<1,"wave cadence")
        end
    end
    if timed_entries[step] then
        if byte("arc_state")~=2 then return end
        check(byte("mode_expired")==1 and byte("mode_seconds_left")==0,"timed result")
        check(math.abs(frames-timer_start-50*timed_entries[step])<12,"timer duration")
    end
    if step==timeout_step and byte("arc_state")~=2 then return end
    if step==shield_step and byte("mode_gate")==0 then return end
    if frames%8~=0 then return end
    local stage=byte("arc_stage")
    if byte("arc_tour")==1 and byte("arc_state")==1 then
        local name=stage==1 and "yard" or stage==2 and "midway" or string.format("stage%02d",stage)
        check_backdrop(name)
        if not scenes[stage] then
            snapshot(string.format("stage-%02d",stage+1))
            scenes[stage]=true
        end
    end
    local nextshot=route[step+1]
    if nextshot and nextshot[1]<0 and byte("arc_stage")==13 and byte("mode_gate")==0 then return end
    if nextshot and nextshot[1]<0 and byte("arc_stage")==6 and byte("mode_gate")~=-nextshot[1]-1 then return end
    if step~=shield_step and nextshot and nextshot[1]<0 and byte("arc_stage")==8 and byte("mode_gate")~=0 then return end
    local card=({[0]="menu",[2]="yard",[14]="wave",[17]="results"})[step]
    if card then snapshot(card) end
    step=step+1
    x,y=route[step][1],route[step][2]
    reads,batches,held,waiting=0,0,true,true
end)

