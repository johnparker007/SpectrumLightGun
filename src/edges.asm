; Dedicated single-white-raster timing experiment. Event list is in bank 2.
; Four bytes per event: level after change, line, phase, bracket width in T.
edge_start:
    ld a,4
    ld (guide),a
    ld a,(bad_port)
    or a
    jr z,.ready
    ld hl,edge_error
    ld de,edge_title
    ld bc,9
    ldir
    ld a,(bad_port)
    ld hl,edge_title+6
    call hex
    call edge_panel
.stop:
    jr .stop
.ready:
    call edge_panel
edge_rearm:
    ld bc,$fffd
    in a,(c)
    bit 5,a
    jr z,edge_rearm
edge_idle:
    ld bc,$f7fe
    in a,(c)
    bit 4,a
    jr z,edge_aim
    ld bc,$effe
    in a,(c)
    bit 2,a                      ; key 8
    jr z,edge_next
    ld bc,$fffd
    in a,(c)
    bit 5,a
    jr nz,edge_idle
edge_shot:
    call blackout
    ld hl,samples
    ld de,$7f7f
    call capture
    call blackout
    call edge_analyse
    call edge_panel
    ld b,25
.hold:
    call wait_frame
    djnz .hold
    jp edge_rearm

edge_aim:
    call key_up
    call blackout
    ld a,(guide)
    call guide_data
    ld (hl),0
    ld a,(guide)
    xor 1
    ld (guide),a
    call edge_panel
    jp edge_rearm
edge_next:
    in a,(c)
    bit 2,a
    jr z,edge_next
    ld hl,(edge_count)
    ld a,h
    or l
    jr z,edge_rearm
    ld de,(edge_selected)
    inc de
    or a
    sbc hl,de
    jr nz,.save
    ld de,0
.save:
    ld (edge_selected),de
    call edge_detail
    call edge_panel
    jp edge_rearm

edge_panel:
    ld a,(guide)
    add a,'A'-4
    ld (edge_target),a
    ld ix,edge_screen
    ld de,$4000
    ld c,4
    jp dashboard.rows

edge_analyse:
    ld hl,edge_empty
    ld de,edge_rise
    ld bc,5
    ldir
    ld hl,edge_empty
    ld de,edge_fall
    ld bc,5
    ldir
    ld hl,0
    ld (edge_selected),hl
    ld (edge_count),hl
    ld hl,samples
    ld ix,events
    ld a,(hl)
    and 16
    ld (edge_prev),a
    call edge_digit
    ld (edge_start_bit),a
    ld de,$3000                  ; line 48, phase zero
    ld b,24
.group:
    push bc
    ld b,57
.slot:
    ; First high/low is a level, never an inferred transition.
    ld a,(hl)
    and 16
    ld c,a
    ld a,(edge_prev)
    cp c
    jr z,.advance
    ld a,c
    ld (edge_prev),a
    ld (ix+0),a
    ld (ix+1),d
    ld (ix+2),e
    ld a,b
    cp 57
    ld a,16
    jr nz,.width
    ld a,23
.width:
    ld (ix+3),a
    inc ix
    inc ix
    inc ix
    inc ix
    push hl
    ld hl,(edge_count)
    inc hl
    ld (edge_count),hl
    ld a,c
    or a
    ld hl,edge_fall
    jr z,.record
    ld hl,edge_rise
    ld a,(hl)
    cp '-'
    jr nz,.saved
.record:
    call edge_stamp
.saved:
    pop hl
.advance:
    inc hl
    ld a,b
    cp 1
    ld a,16
    jr nz,.add
    ld a,23
.add:
    add a,e                      ; e <= 227, +23 fits in a byte
    cp 228
    jr c,.same
    sub 228
    inc d
.same:
    ld e,a
    djnz .slot
    pop bc
    djnz .group
    ld a,(edge_prev)
    call edge_digit
    ld (edge_end_bit),a
    ld de,(edge_count)
    ld hl,edge_n
    call hexword
    ld hl,edge_none
    ld de,edge_event
    ld bc,17
    ldir
    ld hl,(edge_count)
    ld a,h
    or l
    ret z
edge_detail:
    ld de,(edge_selected)
    ld hl,edge_event
    inc de
    call hexword
    ld hl,(edge_selected)
    add hl,hl
    add hl,hl
    ld de,events
    add hl,de
    ld a,(hl)
    or a
    ld a,'-'
    jr z,.sign
    ld a,'+'
.sign:
    ld (edge_event+5),a
    inc hl
    ld d,(hl)
    inc hl
    ld e,(hl)
    inc hl
    ld a,(hl)
    push af
    ld hl,edge_event+7
    call edge_stamp
    pop af
    ld hl,edge_event+15
    jp hex

edge_digit:
    or a
    ld a,'0'
    ret z
    inc a
    ret
edge_stamp:
    ld a,d
    call hex
    inc hl
    ld a,e
    jp hex

edge_error: db "PORT! -- "
edge_empty: db "--:--"
edge_none: db "---- - --:-- W --"
edge_screen:
edge_title: db "EDGE TEST  5 AIM "
edge_target: db "A  8 NEXT"
    defs 32-($-edge_screen),' '
edge_row1:
    db "FIRST+ "
edge_rise: db "--:-- LAST- "
edge_fall: db "--:--"
    defs 32-($-edge_row1),' '
edge_row2:
    db "EDGES "
edge_n: db "---- START "
edge_start_bit: db "- END "
edge_end_bit: db "-"
    defs 32-($-edge_row2),' '
edge_row3: db "EVENT "
edge_event: db "---- - --:-- W --"
    defs 32-($-edge_row3),' '
edge_prev: db 0
edge_count: dw 0
edge_selected: dw 0
; 1368 samples give at most 1367 transitions, even on alternating input.
events: defs 1367*4

