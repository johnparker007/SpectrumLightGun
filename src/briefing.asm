; All practice, replay and tour entries share this stationary briefing.
; Only the start ticket is present on the optical screen.
arc_briefing:
    ld a,(arc_stage)
    cp 16
    jr c,.rule
    sub 16
    ld hl,extra_rules
    call extra_byte
.rule:
    ld (arc_rule),a
    call arc_clear
    ld hl,brief_board
    ld de,$4000
    call scenery_zx7
    ld a,3
    ld (arc_state),a
    ld a,(arc_stage)
    call mode_title
    call brief_length
    ld a,16
    sub b                       ; centre the double-width title
    ld e,a
    ld d,1
    call arc_marquee

    ld a,(arc_rule)
    ld hl,brief_rules
    call mode_string
    ld d,5
    call brief_centre
    ld a,$38
    call arc_text
    inc ix                       ; second line follows the first terminator
    ld d,7
    call brief_centre
    ld a,$3a
    call arc_text

    ld ix,brief_ammo
    ld de,$0c03
    ld a,$57
    call arc_text
    ld ix,brief_limit
    ld de,$0c13
    ld a,$5f
    call arc_text
    ld a,(arc_rule)
    ld e,a
    ld d,0
    ld hl,mode_rounds
    add hl,de
    ld a,(hl)
    push af
    ld de,$0d07
    call brief_figure
    pop af
    ld ix,brief_rounds_label
    cp 1
    jr nz,.shots
    ld ix,brief_single
.shots:
    ld de,$1106
    ld a,$57
    call arc_text
    call stage_time_limit
    or a
    jr z,.open
    cp 10
    jr c,.single_digit
    sub 10
    push af
    ld a,1
    ld de,$0d15
    call brief_figure
    pop af
    ld de,$0d18
    jr .last_digit
.single_digit:
    ld de,$0d17
.last_digit:
    call brief_figure
    ld ix,brief_secs
    ld de,$1115
    jr .unit
.open:
    ld a,10                     ; N and O follow the digits
    ld de,$0d15
    call brief_figure
    ld a,11
    ld de,$0d18
    call brief_figure
    ld ix,brief_unlimited
    ld de,$1116
.unit:
    ld a,$5f
    call arc_text

    ; Show the stage sprite on the ammunition sign; the yard also shows the hazard.
    ld a,(arc_rule)
    ld e,a
    ld d,0
    ld hl,mode_icons
    add hl,de
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(arc_rule)
    cp 2
    jr nz,.picture
    ld de,brief_balloon
.picture:
    ld hl,$5a02                 ; target sample on the ammunition sign
    call brief_icon
    ld a,(arc_rule)
    cp 1
    jr nz,.start
    ld de,arc_bomb
    ld hl,$5a0c
    ld a,$57
    call brief_icon.colour
.start:
    ld ix,brief_start
    ld de,$1506
    ld a,$4f
    call arc_text
    ld hl,$da84                 ; same 24x3 optical start ticket as the menu
    ld a,$7f
    call arc_card_rect
    jp arc_enter

; D=row. Centre one rule inside the 30-cell instruction plaque.
brief_centre:
    call brief_length
    ld a,32
    sub b
    srl a
    ld e,a
    ret
brief_length:
    push ix
    pop hl
    ld b,0
    xor a
.loop:
    cp (hl)
    ret z
    inc hl
    inc b
    jr .loop

brief_board:
    incbin "briefing.zx7"

brief_icon:
    ld a,$56
.colour:
    push de
    call arc_square
    pop de
    jp arc_icon

; A=glyph, DE=cell. Copy three character bands to the interleaved bitmap.
brief_figure:
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    push hl
    add hl,hl
    add hl,hl
    add hl,hl
    pop bc
    add hl,bc                   ; 72 bytes per glyph
    ld bc,brief_figures
    add hl,bc
    ld b,3
.band:
    push bc
    push de
    push hl
    call arc_attr
    ld a,(hl)
    or 7                        ; white ink, preserve panel paper
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    dec hl
    dec hl
    call arc_pixel
    ex de,hl
    pop hl
    ld b,8
.line:
    dup 2
    ld a,(hl)
    inc hl
    ld (de),a
    inc e
    edup
    ld a,(hl)
    inc hl
    ld (de),a
    dec e
    dec e
    inc d
    djnz .line
    pop de
    inc d
    pop bc
    djnz .band
    ret
brief_figures:
    incbin "brief-figures.bin"

brief_ammo: db "AMMUNITION",0
brief_limit: db "TIME LIMIT",0
brief_single: db "SHOT",0
brief_rounds_label: db "SHOTS",0
brief_secs: db "SECONDS",0
brief_unlimited: db "LIMIT",0
brief_start: db "SHOOT HERE TO START",0
brief_balloon: db $03,$c0,$0f,$f0,$1f,$f8,$3f,$fc,$7f,$fe,$7f,$fe,$e7,$e7,$e7,$e7
    db $ff,$ff,$7f,$fe,$7f,$fe,$3f,$fc,$1f,$f8,$0f,$f0,$06,$60,$0c,$30
brief_rules:
    dw brief_0,brief_1,brief_2,brief_3,brief_4,brief_5,brief_6,brief_7
    dw brief_8,brief_9,brief_10,brief_11,brief_12,brief_13,brief_14,brief_15
brief_0: db "KNOCK DOWN ALL FOUR CANS.",0,"ONE SHOT CLEARS ONE CAN.",0
brief_1: db "SHOOT ALL FOUR GREEN CANS.",0,"A RED BOMB COSTS TWO ROUNDS.",0
brief_2: db "POP ALL THREE BALLOONS.",0,"FOLLOW THEIR FALLING CURVE.",0
brief_3: db "RING ALL FOUR BELLS IN TURN.",0,"A HIT LIGHTS THE NEXT BELL.",0
brief_4: db "BREAK ALL FOUR SHIELDS.",0,"YELLOW NEEDS ONE MORE HIT.",0
brief_5: db "SWITCH OFF ALL FOUR LAMPS.",0,"HITS FLIP NEARBY LAMPS.",0
brief_6: db "RING EACH OF THE FOUR BELLS.",0,"ONE LANE OPENS AT A TIME.",0
brief_7: db "CLEAR ALL FOUR CUPS.",0,"SHOTS SHUFFLE THE REST.",0
brief_8: db "BREAK FOUR GREEN SHIELDS.",0,"WAIT WHILE GATES ARE BLUE.",0
brief_9: db "HIT THE SWINGING STAR.",0,"YOU GET ONE SHOT.",0
brief_10: db "CLEAR BOTH PAIRS OF GEMS.",0,"A HIT ALSO CLEARS ITS TWIN.",0
brief_11: db "HIT FOUR SWINGING WEIGHTS.",0,"PAIRS MOVE IN OPPOSITE WAYS.",0
brief_12: db "HIT THE JACKPOT FOUR TIMES.",0,"FOLLOW IT TO THE NEXT LANE.",0
brief_13: db "MEMORISE ALL FOUR POSITIONS.",0,"FIRE WHEN THE LIGHTS GO OUT.",0
brief_14: db "CLEAR THE FOUR FUSES.",0,"BEAT THE COUNTDOWN.",0
brief_15: db "MAKE EXACTLY FIVE POINTS.",0,"ROWS PAY 1 TO 4, TOP DOWN.",0
