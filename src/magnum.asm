; PAL AUX Magnum. SjASMPlus 1.20+. All addresses in the acquisition path
; (including stack, I/R refresh address and IM2 vector) are in fixed bank 2.
    device zxspectrum128
    org $8000
    ifdef ARCADE
alias_count equ 1               ; game capture reads the canonical port only
    else
    ifdef EDGE_DIAG
alias_count equ 57
    else
alias_count equ 10
    endif
    endif
entry: jp start
    defs $8080-$
irq:
    ex af,af'                   ; preserve flags across trigger and UI branches
    push hl
    ld hl,frame
    inc (hl)
    pop hl
    ex af,af'
    ei
    ret
    defs $8100-$
vectors: defs 257,$80
start:
    di
    ld sp,stack_top
    ifdef ARCADE
    call fair_store_art
    endif
    xor a
    out ($fe),a
    ; Ordinary 128 BASIC loader. Select normal mapping, ROM 3 on +3,
    ; ROM 1 on +2, bank 5 displayed and bank 0 at C000 on both.
    ld bc,$1ffd
    ld a,4
    out (c),a
    ld bc,$7ffd
    ld a,16
    out (c),a
    ld bc,$fffd
    ld a,7
    out (c),a
    in a,(c)
    res 6,a
    ld b,$bf
    out (c),a
    ld b,$ff
    in a,(c)
    bit 6,a
    jr z,.input
    ld a,$ff
    ld (bad_port),a
.input:
    xor a                       ; save R0 while testing partial port decoding
    out (c),a
    in a,(c)
    push af
    ld a,$59
    call check_aliases
    ld a,$a6
    call check_aliases
    pop af
    ld bc,$bffd
    out (c),a
    ld b,$ff
    ld a,14
    out (c),a
    ld a,(bad_port)
    or a
    jr z,.configured
    ifndef ARCADE
    ld hl,ui_port
    call hex
    ld a,'!'
    ld (status),a
    endif
.configured:
    ld a,$81
    ld i,a
    im 2
    ld hl,$4000
    ld de,$4001
    ld bc,6911
    ld (hl),0
    ldir
    ifdef EDGE_DIAG
    jp edge_start
    endif
    ifdef GRID_GAME
    ifdef ARCADE
    jp arcade_start
    else
    jp grid_start
    endif
    endif
    ifndef ARCADE
    call dashboard
rearm:
    ld bc,$fffd
    in a,(c)
    bit 5,a
    jr z,rearm
idle:
    ld bc,$effe                 ; 6 is bit 4 of the 0,9,8,7,6 half-row
    in a,(c)
    bit 4,a
    jp z,inspect
    bit 0,a                      ; key 0: full-screen colour map
    jp z,inspect_colour
    bit 1,a                      ; key 9: full-screen scanline replay
    jp z,inspect_bitmap
    ld bc,$f7fe                 ; keys 1..5
    in a,(c)
    bit 0,a
    jr z,toggle
    bit 1,a
    jp z,sweep
    bit 2,a
    jp z,track
    bit 3,a
    jp z,review
    bit 4,a
    jp z,change_guide
    ld bc,$fffd
    in a,(c)
    bit 5,a
    jr nz,idle
shot:
    xor a
    ld (phase),a
    ld a,'R'
    ld (mode),a
    ld a,(preblack)
    or a
    jr z,.white
    ld hl,samples+1920
    ld de,0
    call capture
.white:
    ld hl,samples
    ld de,$7f7f
    call capture
    call blackout
    ld hl,samples
    call decode
    call mark
    ld a,(preblack)
    or a
    call nz,count_black
    ld a,(preblack)
    inc a
    ld (trace_valid),a
    call dashboard
    call mark
    ld b,25                    ; minimum viewing time, even for rapid clicks
.hold:
    call wait_frame
    djnz .hold
    jp rearm
toggle:
    ld a,(preblack)
    xor 1
    ld (preblack),a
    xor a
    ld (dark_valid),a
    call dashboard
    call mark
    call key_up
    jp rearm
; Two complementary patterns distinguish a decoded AY read from an
; open-bus constant. Record the first failing port's high byte.
    endif
check_aliases:
    ld e,a
    ld bc,$bffd
    out (c),a
    ld b,$ff
    ld hl,samples
    dup alias_count
    ini
    edup
    ld hl,samples
    ld d,$ff
    ld b,alias_count
.check:
    ld a,(hl)
    cp e
    jr nz,.fail
    inc hl
    dec d
    djnz .check
    ret
.fail:
    ld a,(bad_port)
    or a
    ret nz
    ld a,d
    ld (bad_port),a
    ret

    ifndef ARCADE
key_up:
    ld bc,$f7fe
    in a,(c)
    and 31
    cp 31
    jr nz,key_up
    ret

; 16 flashes per keypress. Frame numbers are modulo 256. IRQ counter runs
; during analysis so data-dependent decoding/rendering cannot stretch a slot.
sweep:
    call key_up
    xor a
    ld (trace_valid),a
    ld (phase),a
    ld (review_at),a
    ld a,'S'
    ld (mode),a
    di
    ld a,(frame)
    inc a
    ld (deadline),a
    jr .wait
.next:
    call blackout              ; one completely black raster before white
    ld hl,samples
    ld de,$7f7f
    call capture
    ld a,(frame)
    add a,25
    ld (deadline),a
    call blackout
    ld hl,samples
    call decode
    call mark
    call dashboard
    call mark
    ld a,(phase)
    call history_slot
    ex de,hl
    ld hl,status
    ld bc,8
    ldir
    ld a,1
    ld (history_valid),a
    ld a,(phase)
    inc a
    cp 16
    jp z,finish_mode
    ld (phase),a
.wait:
    call wait_frame
    ld a,(deadline)
    ld hl,frame
    cp (hl)
    jr nz,.wait
    ; Lock the HALT bus-cycle phase before the next flash. Sample a busy
    ; display RAM fetch window on this last black frame (see timing notes).
    call align_sweep
    jr .next
history_slot:
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,history
    add hl,de
    ret

review:
    call key_up
    ld a,(history_valid)
    or a
    jp z,rearm
    call blackout
    ld a,'V'
    ld (mode),a
    ld a,(review_at)
    ld (phase),a
    call history_slot
    ld de,status
    ld bc,8
    ldir
    call dashboard
    call mark
    ld a,(phase)
    inc a
    and 15
    ld (review_at),a
    jp rearm

track:
    xor a
    ld (trace_valid),a
    ld (phase),a
    call key_up
    ld a,'T'
    ld (mode),a
    ld hl,samples
    ld a,6
.burst:
    push af
    ld de,$7f7f
    call capture                ; HL advances exactly 1920
    pop af
    dec a
    jr nz,.burst
    call blackout
    ld hl,samples
    xor a
.replay:
    push hl
    ld (clip_index),a
    call decode
    call dashboard
    call mark
    ld b,10
.hold:
    call wait_frame
    djnz .hold
    pop hl
    ld de,1920
    add hl,de
    ld a,(clip_index)
    inc a
    cp 6
    jr z,finish_mode
    push af
    call clear_attrs
    pop af
    jr .replay
finish_mode:
    xor a
    ld (phase),a
    ld a,'R'
    ld (mode),a
    jp rearm

    endif
wait_frame:
    ei
    halt
    ret
; IM2 + handler 83T, RET 10, deadline check 37, CALL 17 = 147T.
; Read normal display RAM during contention; exact anchor audited in verify.
align_sweep:
    ld b,0
    dup 4
    djnz $
    ld b,0
    edup
    ld b,73
    djnz $
    ld a,($4000)
    ret

; Output a solid attribute image in the top border. Ink equals paper, so
; the existing UI bitmap never shows through. Caller has disabled interrupts.
    macro FILL_ATTR

    ld (.restore+1),sp
    ld sp,$5b00
    dup 384
    push de
    edup
.restore: ld sp,0
    endm
blackout:
    ei
    halt
clear_attrs:
    di
    ld de,0
    FILL_ATTR
    ei
    ret

capture:
    ; Dispatch resolved before interrupt. Branch lengths in phase_table
    ; add exactly phase T-states to a common 12T base.
    ld a,(phase)
    add a,a
    ld c,a
    ld b,0
    push hl
    ld hl,phase_table
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld (dispatch+1),hl
    pop hl
    ld ixh,192
    ei
    halt
capture_resume:
    di
    ifdef ARCADE
    ld bc,$7ffd
    ld a,31
    out (c),a                   ; select the prepared shadow screen (29T)
    ld (arc_restore_sp+1),sp
arc_fill_sp:
    ld sp,$f000                 ; scratch for target mask, $db00 for bomb mask
    dup 384
    push de
    edup
arc_restore_sp:
    ld sp,0
    ld a,24                     ; display 7, page uncontended bank 0 for FFFD
    out (c),a
    else
    FILL_ATTR
    endif
    ld bc,$fffd
dispatch:
    jp phase0
    macro PHASE_DELAY n
    if (12+n) & 1
    ld a,0                      ; 7
    if ((12+n-7) & 3) == 2
    inc de                      ; 6; attr fill has finished
    dup (12+n-13)/4
    nop
    edup
    else
    dup (12+n-7)/4
    nop
    edup
    endif
    else
    if ((12+n) & 3) == 2
    inc de
    dup (12+n-6)/4
    nop
    edup
    else
    dup (12+n)/4
    nop
    edup
    endif
    endif
    jp coarse
    endm
phase_table:
    dw phase0,phase1,phase2,phase3,phase4,phase5,phase6,phase7,phase8,phase9,phase10,phase11,phase12,phase13,phase14,phase15
phase0: PHASE_DELAY 0
phase1: PHASE_DELAY 1
phase2: PHASE_DELAY 2
phase3: PHASE_DELAY 3
phase4: PHASE_DELAY 4
phase5: PHASE_DELAY 5
phase6: PHASE_DELAY 6
phase7: PHASE_DELAY 7
phase8: PHASE_DELAY 8
phase9: PHASE_DELAY 9
phase10: PHASE_DELAY 10
phase11: PHASE_DELAY 11
phase12: PHASE_DELAY 12
phase13: PHASE_DELAY 13
phase14: PHASE_DELAY 14
phase15: PHASE_DELAY 15
coarse:
    dup 2
    ld b,0
    djnz $
    edup
    ifdef ARCADE
    ld b,246                    ; 52T shorter plus one NOP pays for both page writes
    else
    ld b,250
    endif
    djnz $
    ifdef ARCADE
    nop
    endif
    dup 6
    nop
    edup
    ifdef EDGE_DIAG
    ; From the normal first-line schedule, advance 48*228 + 16 clocks
    ; so the first latch is at nominal picture line 48, horizontal phase 0.
    dup 3
    ld b,0
    djnz $
    edup
    ld b,72
    djnz $
    dup 8
    nop
    edup
edge_blocks:
    dup 24
    ld b,$ff
    dup 57
    ini
    edup
    edup
edge_capture_end:
    ret
    endif
line:
    ld b,$ff
first_ini:
    ifdef GRID_GAME
    ; Every read uses FFFD. Keep the first level and the OR of all ten.
    in a,(c)
    ld e,a
    dup 9
    in d,(c)
    or d
    edup
grid_reads_end:
    ld (hl),e
    inc hl
    ld (hl),a
    inc hl
    ; 26T for the stores/increments, then 17T padding.
    ld a,0
    inc de
    nop
    else
    dup 10
    ini
    edup
    ; 7 + 160 + 7 + 36 + 8 + 10 = 228 even on the last line.
    ld a,0
    dup 9
    nop
    edup
    endif
    dec ixh
    jp nz,line
capture_end:
    ret

; First observed high. Index zero has no adjacent low on THIS line.
; For edge samples lower/upper are closed geometric timing boundaries
; (the transition occurred after the lower sample and by the upper).
    ifndef ARCADE
decode:
    ld a,(bad_port)
    or a
    ld a,'!'
    jp nz,.status
    ld d,0
.row:
    push hl
    xor a
    dup 10
    or (hl)
    inc hl
    edup
    and 16
    jr nz,.nonempty
    pop bc
    inc d
    ld a,d
    cp 192
    jr nz,.row
    ld a,'-'
    jr .status
.nonempty:
    pop hl
    ld a,d
    ld (row),a
    ld b,10
.sample:
    bit 4,(hl)
    jr nz,.found
    inc hl
    djnz .sample
.found:
    ld a,10
    sub b
    ld (idx),a
    or a
    ld a,'H'
    jr z,.status
    ld a,(idx)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld a,(phase)
    ld e,a
    ld d,0
    add hl,de
    ld de,-16
    add hl,de
    add hl,hl                   ; signed right boundary in pixels
    ld de,6                     ; HALT acceptance spans up to three T
    add hl,de
    ld (upper),hl
    ld de,-38
    add hl,de
    ld (lower),hl
    bit 7,h
    jr nz,.left
    ld a,h
    or a
    jr nz,.outside
    jr .left_ok
.left:
    ld l,0
.left_ok:
    ld de,(upper)
    bit 7,d
    jr nz,.outside
    ld a,d
    or a
    jr z,.right_ok
    ld e,255
.right_ok:
    ld a,e
    add a,l
    rra
    ld (raw_x),a
    ld a,'E'
    jr .status
.outside:
    ld a,'B'
.status:
    ld (status),a
    ret

count_black:
    ld hl,samples+1920
    ld bc,1920
    ld de,0
.loop:
    bit 4,(hl)
    jr z,.low
    inc de
.low:
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,.loop
    ld a,1
    ld (dark_valid),a
    ld (dark_count),de
    ret

; Draw in the attribute file only. Raw data stay intact under calibration.
mark:
    ld a,(status)
    cp 'E'
    ret nz
    ld a,(raw_x)
    ld de,OFFSET_X
    call replay_offset
    call corrected
    ld (shown_x),a
    rrca
    rrca
    rrca
    and 31
    ld c,a
    ld a,(row)
    ld de,OFFSET_Y
    call replay_offset
    call corrected
    cp 192
    jr c,.inside
    ld a,191
.inside:
    ld (shown_y),a
    and $f8
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld b,$58
    add hl,bc
    ld (hl),9                   ; original dark-blue 8x8 measurement marker
    ; Bright cyan sight arms, clipped independently at each screen edge.
    ld a,l
    and 31
    jr z,.right
    dec hl
    ld (hl),$6d
    inc hl
.right:
    cp 31
    jr z,.vertical
    inc hl
    ld (hl),$6d
    dec hl
.vertical:
    ld de,-32
    add hl,de
    ld a,h
    cp $58
    jr c,.below
    ld (hl),$6d
.below:
    ld de,64
    add hl,de
    ld a,h
    cp $5b
    ret nc
    ld (hl),$6d
    ret
replay_offset:
    push af
    ld a,(mode)
    cp 'T'
    jr nz,.done
    ld de,0
.done:
    pop af
    ret
corrected:
    ld l,a
    ld h,0
    add hl,de
    ld a,l
    bit 7,h
    jr z,.positive
    xor a
    ret
.positive:
    inc h
    dec h
    ret z
    ld a,255
    ret

; A four-row instrument panel, ROM font. Keep the normal display dim.
dashboard:
    ld a,(mode)
    ld (ui_mode),a
    ld a,(preblack)
    add a,'0'
    ld (ui_pre),a
    ld a,(phase)
    ld hl,ui_phase
    call hex
    ld a,(clip_index)
    add a,'0'
    ld (ui_clip),a
    ld a,(status)
    ld hl,label_edge
    cp 'E'
    jr z,.label
    ld hl,label_high
    cp 'H'
    jr z,.label
    ld hl,label_none
    cp '-'
    jr z,.label
    ld hl,label_border
    cp 'B'
    jr z,.label
    ld hl,label_port
    cp '!'
    jr z,.label
    ld hl,label_ready
.label:
    ld de,ui_status
    ld bc,5
    ldir
    ld a,(guide)
    add a,'0'
    ld (ui_guide),a
    ld hl,ui_line
    ld b,fields_end-ui_line
.wipe:
    ld a,(hl)
    cp ':'
    jr z,.skip
    cp ' '
    jr z,.skip
    ld (hl),'-'
.skip:
    inc hl
    djnz .wipe
    ld a,(status)
    cp '-'
    jr z,.black
    cp '?'
    jr z,.black
    cp '!'
    jr z,.black
    ld hl,ui_line
    ld a,(row)
    call hex
    ld hl,ui_i
    ld a,(idx)
    call hex
    ld a,(status)
    cp 'H'
    jr z,.black
    ld hl,ui_lo
    ld de,(lower)
    call hexword
    ld hl,ui_hi
    ld de,(upper)
    call hexword
    ld a,(status)
    cp 'E'
    jr nz,.black
    call mark
    ld hl,ui_x
    ld a,(raw_x)
    call hex
    ld hl,ui_cx
    ld a,(shown_x)
    call hex
    ld hl,ui_cy
    ld a,(shown_y)
    call hex
.black:
    ld hl,ui_dark
    ld de,(dark_count)
    call hexword
    ld a,(preblack)
    ld hl,mode
    cp 1
    jr nz,.no_dark
    ld a,(hl)
    cp 'R'
    jr nz,.no_dark
    ld a,(dark_valid)
    or a
    jr nz,.paint
.no_dark:
    ld hl,$2d2d
    ld (ui_dark),hl
    ld (ui_dark+2),hl
.paint:
    ld ix,panel
    ld de,$4000
    ld c,4
.rows:
    ld b,32
.chars:
    push bc
    ld l,(ix+0)
    inc ix
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld bc,$3c00
    add hl,bc
    push de
    ld b,8
.glyph:
    ld a,(hl)
    ld (de),a
    inc hl
    inc d
    djnz .glyph
    pop de
    inc de
    pop bc
    djnz .chars
    dec c
    jr nz,.rows
    ld hl,$5800
    ld de,$5801
    ld bc,127
    ld (hl),5
    ldir
    ld a,(mode)
    cp 'R'
    ret nz
    ld a,(guide)
    or a
    ret z
    call guide_data
    ld a,(hl)
    or (ix+4)
    ld (hl),a
    ld a,5
    ld (de),a
    ret
hexword:
    ld a,d
    call hex
    ld a,e
hex:
    push af
    rrca
    rrca
    rrca
    rrca
    call nibble
    pop af
nibble:
    and 15
    add a,'0'
    cp '9'+1
    jr c,.digit
    add a,7
.digit:
    ld (hl),a
    inc hl
    ret

; Bitmap byte, attribute address, bit mask for each metrology point.
    macro POINT x,y
    dw $4000+((y & $c0)<<5)+((y & 7)<<8)+((y & $38)<<2)+(x>>3)
    dw $5800+(y>>3)*32+(x>>3)
    db $80>>(x & 7)
    endm
guide_points:
    POINT 32,32
    POINT 224,160
    POINT 128,96
    POINT 108,96
    POINT 148,96
guide_data:
    dec a
    ld c,a
    add a,a
    add a,a
    add a,c
    ld c,a
    ld b,0
    ld ix,guide_points
    add ix,bc
    ld l,(ix+0)
    ld h,(ix+1)
    ld e,(ix+2)
    ld d,(ix+3)
    ret

change_guide:
    call key_up
    call blackout
    ld a,(guide)
    or a
    jr z,.next
    call guide_data
    ld (hl),0                   ; all guide points are below the text
.next:
    ld a,(guide)
    inc a
    cp 6
    jr c,.store
    xor a
.store:
    ld (guide),a
    ld a,'R'
    ld (mode),a
    call dashboard
    call mark
    jp rearm
; Frozen logic-level map: horizontal axis is the 10 sample slots, vertical
; axis is the 192 scanlines. Bank 0 scratch preserves the exact result screen.
inspect:
    ld d,16                      ; key 6
    jr inspect_shot
inspect_bitmap:
    ld d,2                       ; key 9
    jr inspect_shot
inspect_colour:
    ld d,1                       ; key 0
inspect_shot:
    call map_key_up
    ld a,(trace_valid)
    or a
    jp z,rearm
    push de
    ld hl,$4000
    ld de,$c000
    ld bc,6912
    ldir
    call clear_attrs
    pop de
    push de
    ld a,d
    cp 1
    jr z,.colour
    cp 2
    jr nz,.raw
    call draw_bitmap
    jr .view
.colour:
    call draw_colour
    jr .view
.raw:
    ld hl,samples
    ld e,4
    call draw_trace
    ld a,(trace_valid)
    cp 2
    jr nz,.view
    ld hl,samples+1920
    ld e,18
    call draw_trace
.view:
    pop de
    ld bc,$effe
.wait:
    in a,(c)
    and d
    jr nz,.wait
    call map_key_up
    ld hl,$c000
    ld de,$4000
    ld bc,6912
    ldir
    jp rearm
map_key_up:
    ld bc,$effe
    in a,(c)
    and d
    jr z,map_key_up
    ret

; Plot the state at each right-hand sample over its preceding interval:
; X=0 uses slot 1, X=1..32 slot 2, ..., X=225..255 slot 9. Slot 0 is
; before the visible picture. Each stored scanline gets its own pixel row.
draw_bitmap:
    ld hl,samples
    ld de,$4000
    ld b,192
.line:
    push bc
    push de
    inc hl
    ld a,(hl)
    and 16
    neg
    sbc a,a
    ld c,a                       ; previous level for the left endpoint
    inc hl
    ld b,8
.strip:
    ld a,(hl)
    inc hl
    and 16
    neg
    sbc a,a                      ; full byte of current level
    rl c                         ; carry = previous level
    ld c,a
    rra                          ; first pixel previous, next seven current
    ld (de),a
    inc e
    ld a,c
    dup 3
    ld (de),a
    inc e
    edup
    djnz .strip
    pop de
    call next_bitmap_line
    pop bc
    djnz .line
    ld hl,$5800
    ld de,$5801
    ld bc,767
    ld (hl),7                    ; white ink on black, no attribute averaging
    ldir
    ret

; A high read at X=32 covers the preceding interval, not the next 32 pixels.
; Fold the clipped X=0 endpoint into the first bin, at most one vote per line.
draw_colour:
    ld hl,samples+2
    ld de,$5800
    ld b,24
.row:
    push bc
    ld b,8
.column:
    push bc
    push hl
    ld c,0
    ld a,b
    cp 8
    ld b,8
    jr nz,.one
.left:
    dec hl
    ld a,(hl)
    inc hl
    or (hl)
    and 16
    jr z,.left_low
    inc c
.left_low:
    push de
    ld de,10
    add hl,de
    pop de
    djnz .left
    jr .paint
.one:
    bit 4,(hl)
    jr z,.low
    inc c
.low:
    push de
    ld de,10
    add hl,de
    pop de
    djnz .one
.paint:
    ld hl,colour_attrs
    add hl,bc                    ; B=0 after DJNZ, C=0..8
    ld a,(hl)
    dup 4
    ld (de),a
    inc de
    edup
    pop hl
    inc hl
    pop bc
    djnz .column
    ld bc,72
    add hl,bc
    pop bc
    djnz .row
    ret
colour_attrs:
    ; round(7*count/8), equal ink and paper so the hidden bitmap is immaterial
    db 0,9,18,27,36,36,45,54,63

next_bitmap_line:
    inc d
    ld a,d
    and 7
    ret nz
    ld a,e
    add a,32
    ld e,a
    ret c
    ld a,d
    sub 8
    ld d,a
    ret

draw_trace:
    ld d,$40
    push de
    ld b,192
.line:
    push bc
    push de
    ld b,10
.slot:
    ld a,(hl)
    inc hl
    and 16
    jr z,.low
    ld a,$7e
.low:
    or $80                      ; grid boundary visible even on an empty map
    ld (de),a
    inc e
    djnz .slot
    pop de
    call next_bitmap_line
    pop bc
    djnz .line
    pop hl
    ld h,$58
    ld b,24
.attr_row:
    push bc
    push hl
    ld b,10
.attr:
    ld (hl),5
    inc hl
    djnz .attr
    pop hl
    ld bc,32
    add hl,bc
    pop bc
    djnz .attr_row
    ret
label_edge: db "EDGE "
label_high: db "HIGH "
label_none: db "MISS "
label_border: db "BORDR"
label_ready: db "READY"
label_port: db "PORT!"

panel:
    db "1PRE 2SWP 3TRK 4LOG 5AIM"
ui_guide: db "0  "
ui_mode: db "R 6MP"
    defs 32-($-panel),' '
panel1:
    db "PRE "
ui_pre: db "0 PH "
ui_phase: db "00 F "
ui_clip: db "0 BLACK "
ui_dark: db "---- "
ui_status: db "READY"
    defs 32-($-panel1),' '
panel2:
    db "Y  I  LO   HI   X  CORR X:Y P"
ui_port: db "--"
    defs 32-($-panel2),' '
panel3:
ui_line: db "-- "
ui_i: db "-- "
ui_lo: db "---- "
ui_hi: db "---- "
ui_x: db "-- "
ui_cx: db "--:"
ui_cy: db "--"
fields_end:
    defs 32-($-panel3),' '
    endif
trace_valid: db 0               ; 1 white, 2 white and black, 0 unavailable
bad_port: db 0
guide: db 0
frame: db 0
deadline: db 0
mode: db 'R'
phase: db 0
clip_index: db 0
preblack: db 1
dark_valid: db 0
dark_count: dw 0
status: db '?'
row: db 0
idx: db 0
lower: dw 0
upper: dw 0
raw_x: db 0
shown_x: db 0
shown_y: db 0
history_valid: db 0
review_at: db 0
history: defs 128
    ifdef EDGE_DIAG
    include "edges.asm"
    endif
    ifdef GRID_GAME
    ifdef ARCADE
    include "arcade.asm"
    else
    include "grid.asm"
    endif
    endif
image_end:
    defs 128
stack_top:
samples:
    ifdef EDGE_DIAG
    defs 1368
    else
    ifdef GRID_GAME
    defs 192*2
    else
    defs 6*1920
    endif
    endif
arc_payload_end:
    assert $ <= $c000


