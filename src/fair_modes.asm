; Four practice tickets per page. A fifth, shallow strip advances the page.
modes_menu:
    ld a,(mode_page)
    inc a
    ld hl,page_digit
    ld (hl),' '
    cp 10
    jr c,.units
    ld (hl),'1'
    sub 10
.units:
    add a,'0'
    inc hl
    ld (hl),a
    ld de,$0204
    ld ix,page_label
    call arc_card
    ; Leave one empty character row between navigation and the first ticket.
    ld hl,$5884
    ld b,24
.gap:
    ld (hl),0
    set 7,h
    ld (hl),0
    res 7,h
    inc hl
    djnz .gap
    ld a,(mode_page)
    add a,a
    add a,a
    ld c,a
    ld d,5
.loop:
    push bc
    push de
    ld a,c
    or a
    ld ix,tour_label
    jr z,.card
    dec a
    cp 64
    jr nc,.end
    call mode_title
.card:
    pop de
    push de
    ld e,4
    call arc_card
    pop de
    pop bc
    inc c
    ld a,d
    add a,5
    ld d,a
    cp 24
    jr c,.loop
    ret
.end:
    pop de
    pop bc
    ret

mode_choice:
    ld e,0
    cp 72
    jr c,.index
    inc e
    cp 112
    jr c,.index
    inc e
    cp 152
    jr c,.index
    inc e
.index:
    xor a
    ld (arc_tour),a
    ld (arc_total),a
    ld a,(mode_page)
    add a,a
    add a,a
    add a,e
    or a
    jr nz,.practice
    inc a
    ld (arc_tour),a
    xor a
    ret
.practice:
    dec a
    cp 64
    ret c
    ld a,$ff
    ret

mode_title:
    cp 16
    jr c,.original
    sub 16
    ld hl,extra_titles
    jr mode_string
.original:
    ld hl,mode_titles
    jr mode_string
mode_hint:
    ld hl,mode_hints
mode_string:
    add a,a
    ld e,a
    ld d,0
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    push de
    pop ix
    ret

modes_setup:
    ld a,4
    ld (arc_goal),a
    xor a
    ld (mode_clock),a
    ld (mode_gate),a
    ld (mode_expired),a
    add a,'0'
    ld (mode_sum_digit),a
    ld a,1
    ld (arc_alive+3),a
    ld a,(arc_rule)
    ld e,a
    ld d,0
    push de
    call stage_time_limit
    pop de
    ld (mode_seconds_left),a
    ld a,50
    ld (mode_clockdown),a
    ld hl,mode_rounds
    add hl,de
    ld a,(hl)
    ld (arc_ammo),a
    ld hl,mode_goals
    add hl,de
    ld a,(hl)
    ld (arc_goal),a
    ld a,(arc_rule)
    add a,a
    ld e,a
    ld hl,mode_icons
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (mode_art),de
    ld a,(arc_rule)
    cp 1
    ret z
    cp 2
    jr nz,.extra
    xor a
    ld (arc_alive+3),a
    jp parade_init
.extra:
    cp 4
    jr nz,.single
    ld hl,$0202
    ld (arc_alive),hl
    ld (arc_alive+2),hl
.single:
    cp 9
    jr nz,.clock
    xor a
    ld (arc_alive+0),a
    ld (arc_alive+1),a
    ld (arc_alive+3),a
.clock:
    ld a,(arc_rule)
    cp 13
    ret nz
    ; Rotate the remembered rack differently on successive visits.
    ld a,(mode_visit)
    inc a
    ld (mode_visit),a
    ld c,a
    ld hl,arc_pos
    ld b,4
.deal:
    ld a,c
    rlca
    rlca
    rlca
    and 24
    add a,(hl)
    and 31
    ld (hl),a
    rrc c
    inc hl
    inc hl
    djnz .deal
    ret

mode_draw:
    ld a,(arc_rule)
    cp 2
    jp z,parade_unmask
    cp 1
    jp z,arc_objects
    ; Redraw only actors whose colour, visibility or column changed. This
    ; keeps the Whack A Bell handover within the remaining border time.
    ld ix,arc_pos
    ld iy,arc_alive
    ld hl,nv_previous_ink
    ld de,mode_previous
    ld b,4
.actor:
    push bc
    push hl
    push de
    call mode_colour
    or a
    jr z,.ink
    ld a,(mode_ink)
.ink:
    pop de
    pop hl
    ld c,(hl)
    ld (hl),a
    push hl
    ld h,a
    ld a,(de)
    cp (ix+0)
    jr nz,.moved
    ld a,h
    cp c
    jr z,.next
    jr .draw
.moved:
    push hl
    push de
    ld e,a
    ld d,(ix+1)
    xor a
    call nv_slot
    pop de
    pop hl
.draw:
    ld a,(ix+0)
    ld (de),a
    push de
    ld e,a
    ld d,(ix+1)
    ld a,h
    call nv_slot
    pop de
.next:
    pop hl
    inc hl
    inc de
    inc de
    inc ix
    inc ix
    inc iy
    pop bc
    djnz .actor
    ret

nv_previous_ink: defs 4

; Existing arc_objects uses IX for position and IY for live state.
mode_colour:
    ld a,$44
    ld (mode_ink),a
    ld a,(iy+0)
    or a
    ret z
    push iy
    pop hl
    ld de,arc_alive
    or a
    sbc hl,de
    ld e,l                      ; lane number
    ld a,(arc_rule)
    cp 4
    jr z,.armour
    cp 10
    jr z,.mirror
    cp 3
    jr z,.relay
    cp 6
    jr z,.popup
    cp 8
    jr z,.shield
    cp 12
    jr z,.jackpot
    cp 13
    jr z,.memory
    cp 15
    jr nz,.live
    ld a,e
    add a,$42
    ld (mode_ink),a
.live:
    ld a,1
    ret
.armour:
    ld a,(iy+0)
    cp 2
    jr z,.live
    ld a,$46
    ld (mode_ink),a
    jr .live
.mirror:
    ld a,e
    or a
    jr z,.live
    cp 3
    jr z,.live
    ld a,$45
    ld (mode_ink),a
    jr .live
.relay:
    ld a,(arc_hits)
    cp e
    jr .equal
.popup:
    ld a,(mode_gate)
    cp e
.equal:
    jr z,.live
    xor a
    ret
.shield:
    ld a,(mode_gate)
    or a
    jr z,.live
    ld a,$41
    ld (mode_ink),a
    jr .live
.jackpot:
    ld a,(arc_hits)
    add a,a
    ld d,a
    ld a,(arc_hits)
    add a,d
    and 3
    cp e
    jr .equal
.memory:
    ld a,(mode_gate)
    or a
    jr z,.live
    ld a,$40
    ld (mode_ink),a
    jr .live

mode_mask_ink:
    ld a,(mode_ink)
    cp $41
    ld a,$7f
    ret nz
    xor a
    ret

mode_hit:
    ld hl,arc_alive
    add hl,de
    ld a,(hl)
    or a
    ret z
    ld a,(arc_rule)
    cp 4
    jr z,.armour
    cp 5
    jr z,.lamps
    cp 10
    jr z,.twins
    cp 12
    jr z,.score
    cp 15
    jr z,.change
.clear:
    ld (hl),0
.score:
    ld hl,arc_hits
    inc (hl)
    ret
.armour:
    dec (hl)
    ret nz
    jr .score
.twins:
    ld (hl),0
    ld a,e
    xor 3
    ld e,a
    ld hl,arc_alive
    add hl,de
    ld (hl),0
    ld hl,arc_hits
    inc (hl)
    inc (hl)
    ret
.lamps:
    ld (hl),0
    ld a,e
    or a
    jr z,.right
    dec hl
    ld a,(hl)
    xor 1
    ld (hl),a
    inc hl
.right:
    ld a,e
    cp 3
    jr z,.count
    inc hl
    ld a,(hl)
    xor 1
    ld (hl),a
.count:
    ld hl,arc_alive
    ld a,4
    ld b,4
.sub:
    sub (hl)
    inc hl
    djnz .sub
    ld (arc_hits),a
    ret
.change:
    ld (hl),0
    ld a,(arc_hits)
    inc a
    add a,e
    cp 6
    jr c,.sum
    xor a
    ld (arc_ammo),a
.sum:
    ld (arc_hits),a
    add a,'0'
    ld (mode_sum_digit),a
    ret

mode_tick:
    ld a,(arc_rule)
    cp 3
    ret c
    ld hl,mode_clock
    inc (hl)
    cp 13
    jr z,.memory
    cp 11
    jr z,.swing
    cp 9
    jr z,.swing
    cp 8
    jr z,.gate
    cp 6
    ret nz
    ld a,(hl)
    cp 24
    ret c
    ld (hl),0
    ld hl,mode_gate
    inc (hl)
    ld a,(hl)
    and 3
    ld (hl),a
    jp mode_draw
.memory:
    ld a,(mode_gate)
    or a
    ret nz
    ld a,(hl)
    cp 60
    ret nz
    jr .toggle
.gate:
    ld a,(hl)
    cp 30
    ret c
    ld (hl),0
.toggle:
    ld hl,mode_gate
    ld a,(hl)
    xor 1
    ld (hl),a
    jp mode_draw
.swing:
    ld a,(hl)
    and 3
    ret nz
    ld a,(hl)
    rrca
    rrca
    and 31
    bit 4,a
    jr z,.forward
    xor 31
.forward:
    add a,4
    ld hl,arc_pos
    ld b,4
.move:
    ld (hl),a
    xor 31
    inc hl
    inc hl
    djnz .move
    jp mode_draw

mode_after_shot:
    ld a,(arc_rule)
    cp 7
    jr nz,.pay
    ld hl,arc_pos
    ld b,4
.shift:
    ld a,(hl)
    add a,8
    and 31
    ld (hl),a
    inc hl
    inc hl
    djnz .shift
    ret
.pay:
    cp 15
    ret nz
    ld ix,mode_sum_digit
    ld de,$0013
    ld a,6
    jp arc_text

mode_timer_tick:
    ld a,(mode_seconds_left)
    or a
    ret z
    ld hl,mode_clockdown
    dec (hl)
    ret nz                     ; carry clear from OR A
    ld (hl),50
    ld hl,mode_seconds_left
    dec (hl)
    jr nz,.display
    ld a,1
    ld (mode_expired),a
    scf
    ret
.display:
    call mode_show_time
    or a
    ret

mode_show_time:
    ld a,(mode_seconds_left)
    call mode_split_seconds
    add a,'0'
    ld (mode_seconds+1),a
    ld a,b
    or a
    jr z,.blank
    add a,'0'
    jr .tens
.blank:
    ld a,' '
.tens:
    ld (mode_seconds),a
    ld a,(mode_seconds_left)
    cp 4
    ld a,$46
    jr nc,.paint
    ld a,$42
.paint:
    ld ix,mode_seconds
    ld de,$0011
    jp arc_text
    ; A = seconds (0..99). Return B = tens and A = units.
mode_split_seconds:
    ld b,0
.loop:
    cp 10
    ret c
    sub 10
    inc b
    jr .loop

mode_seconds: db " 0S",0
mode_expired: db 0
mode_seconds_left: db 0
mode_clockdown: db 50
mode_visit: db 0
mode_page: db 0
arc_goal: db 4
mode_clock: db 0
mode_gate: db 0
mode_ink: db $44
mode_previous: db 19,4,3,9,27,14,19,19
mode_art: dw arc_can
mode_icons:
    dw arc_can,arc_can,mode_star,mode_bell,mode_shield,mode_bulb,mode_bell,mode_cup
    dw mode_shield,mode_star,mode_gem,mode_weight,mode_coin,mode_eye,mode_fuse,mode_coin
mode_star: db 1,128,3,192,3,192,7,224,127,254,255,255,63,252,31,248,15,240,31,248,31,248,57,156,48,12,32,4,0,0,0,0
mode_bell: db 3,192,7,224,15,240,31,248,31,248,31,248,31,248,31,248,63,252,63,252,127,254,255,255,0,0,3,192,3,192,1,128
mode_sum_digit: db "0",0
page_label: db "MORE GAMES   "
page_digit: db " 1/17",0
mode_titles: dw titles_0,titles_1,titles_2,titles_3,titles_4,titles_5,titles_6,titles_7,titles_8,titles_9,titles_10,titles_11,titles_12,titles_13,titles_14,titles_15
titles_0: db "TIN CAN ALLEY",0
titles_1: db "THE POWDER YARD",0
titles_2: db "SINE PARADE",0
titles_3: db "CHAIN RELAY",0
titles_4: db "IRONCLAD",0
titles_5: db "LIGHTS OUT",0
titles_6: db "WHACK A BELL",0
titles_7: db "SHELL SHUFFLE",0
titles_8: db "SHIELD GATE",0
titles_9: db "GOLDEN SHOT",0
titles_10: db "MIRROR TWINS",0
titles_11: db "PENDULUM RANGE",0
titles_12: db "JACKPOT CHASE",0
titles_13: db "AFTERIMAGE",0
titles_14: db "SHORT FUSE",0
titles_15: db "EXACT CHANGE",0
mode_hints: dw hints_0,hints_1,hints_2,hints_3,hints_4,hints_5,hints_6,hints_7,hints_8,hints_9,hints_10,hints_11,hints_12,hints_13,hints_14,hints_15
hints_0: db "CLEAR FOUR GREEN TARGETS",0
hints_1: db "GREEN SCORES / RED COSTS TWO",0
hints_2: db "CATCH ALL THREE IN THE PARADE",0
hints_3: db "FOLLOW THE LIT RELAY",0
hints_4: db "EACH CAN NEEDS TWO HITS",0
hints_5: db "HITS FLIP NEIGHBOURING LAMPS",0
hints_6: db "CATCH EACH BELL AS IT APPEARS",0
hints_7: db "CANS JUMP AFTER EVERY SHOT",0
hints_8: db "FIRE ON GREEN / BLUE IS SHUT",0
hints_9: db "ONE ROUND / ONE MOVING STAR",0
hints_10: db "ONE HIT CLEARS ITS MIRROR TWIN",0
hints_11: db "TRACK THE OPPOSING SWINGS",0
hints_12: db "RING THE JACKPOT FOUR TIMES",0
hints_13: db "MEMORISE BEFORE LIGHTS GO OUT",0
hints_14: db "CLEAR THE RACK IN SEVEN SECONDS",0
hints_15: db "ROWS PAY 1-4 / TOTAL EXACTLY 5",0
mode_goals: db 4,4,3,4,4,4,4,4,4,1,4,4,4,4,4,5
mode_rounds: db 5,5,4,5,9,6,6,5,6,1,3,5,5,6,6,2


mode_shield: db $3f,$fc,$3f,$fc,$ff,$ff,$ff,$ff,$c3,$c3,$c3,$c3,$f3,$cf,$f3,$cf,$ff,$ff,$ff,$ff,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0,$03,$c0,$03,$c0
mode_bulb: db $0f,$f0,$0f,$f0,$3c,$3c,$3c,$3c,$f0,$0f,$f0,$0f,$f3,$cf,$f3,$cf,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0,$0c,$30,$0c,$30,$03,$c0,$03,$c0
mode_cup: db $03,$c0,$03,$c0,$0f,$f0,$0f,$f0,$0f,$f0,$0f,$f0,$3f,$3c,$3f,$3c,$3c,$3c,$3c,$3c,$fc,$3f,$fc,$3f,$ff,$ff,$ff,$ff,$c0,$03,$c0,$03
mode_gem: db $0f,$f0,$0f,$f0,$3c,$3c,$3c,$3c,$f3,$cf,$f3,$cf,$ff,$ff,$ff,$ff,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0,$03,$c0,$03,$c0,$00,$00,$00,$00
mode_weight: db $03,$c0,$03,$c0,$03,$c0,$03,$c0,$03,$c0,$03,$c0,$0f,$f0,$0f,$f0,$3f,$fc,$3f,$fc,$fc,$3f,$fc,$3f,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0
mode_coin: db $0f,$f0,$0f,$f0,$3c,$3c,$3c,$3c,$f3,$cf,$f3,$cf,$f3,$0f,$f3,$0f,$f0,$cf,$f0,$cf,$f3,$cf,$f3,$cf,$3c,$3c,$3c,$3c,$0f,$f0,$0f,$f0
mode_eye: db $00,$00,$00,$00,$0f,$f0,$0f,$f0,$3f,$fc,$3f,$fc,$f3,$cf,$f3,$cf,$f3,$cf,$f3,$cf,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0,$00,$00,$00,$00
mode_fuse: db $00,$33,$00,$33,$03,$cc,$03,$cc,$0f,$00,$0f,$00,$3f,$fc,$3f,$fc,$ff,$ff,$ff,$ff,$cf,$f3,$cf,$f3,$3f,$fc,$3f,$fc,$0f,$f0,$0f,$f0

    include "extra.inc"

extra_byte:
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)
    ret

extra_layout:
    ld a,(arc_stage)
    cp 16
    ret c
    sub 16
    add a,a
    add a,a
    ld e,a
    ld d,0
    ld hl,extra_columns
    add hl,de
    ld de,arc_pos
    ld b,4
.copy:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    inc de
    djnz .copy
    ret

stage_time_limit:
    ld a,(arc_stage)
    ld hl,stage_limits
    jr extra_byte
