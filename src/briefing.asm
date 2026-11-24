; All practice, replay and tour entries share this stationary briefing.
; Only the start ticket is present on the optical screen.
arc_briefing:
    call arc_clear
    ld a,3
    ld (arc_state),a
    ld a,(arc_stage)
    call mode_title
    ld de,$0101
    call arc_marquee

    ld de,$0501
    ld bc,$051e
    ld a,$38
    call brief_panel
    ld a,(arc_stage)
    ld hl,brief_rules
    call mode_string
    ld de,$0602
    ld a,$38
    call arc_text
    inc ix                       ; second line follows the first terminator
    ld de,$0802
    ld a,$3a
    call arc_text

    ld de,$0c01
    ld bc,$060e
    ld a,$57
    call brief_panel
    ld de,$0c11
    ld bc,$060e
    ld a,$5f
    call brief_panel
    ld ix,brief_ammo
    ld de,$0d03
    ld a,$57
    call arc_text
    ld ix,brief_limit
    ld de,$0d13
    ld a,$5f
    call arc_text
    ld a,(arc_stage)
    ld e,a
    ld d,0
    ld hl,mode_rounds
    add hl,de
    ld a,(hl)
    add a,'0'
    ld (brief_number),a
    ld ix,brief_number
    ld de,$0e03
    call arc_marquee
    ld ix,brief_rounds_label
    ld a,(brief_number)
    cp '1'
    jr nz,.shots
    ld ix,brief_single
.shots:
    ld de,$0f06
    ld a,$57
    call arc_text
    ld de,$0e03
    ld bc,$0202
    ld a,$57
    call brief_panel
    ld a,(arc_stage)
    ld e,a
    ld d,0
    ld hl,mode_limits
    add hl,de
    ld a,(hl)
    or a
    jr z,.open
    ld hl,brief_time
    ld (hl),' '
    cp 10
    jr c,.units
    ld (hl),'1'
    sub 10
.units:
    inc hl
    add a,'0'
    ld (hl),a
    ld ix,brief_time
    jr .time
.open:
    ld ix,brief_open
.time:
    ld de,$0e13
    call arc_marquee
    ld de,$0e13
    ld bc,$0204
    ld a,$5f
    call brief_panel
    ld ix,brief_secs
    ld a,(arc_stage)
    ld e,a
    ld d,0
    ld hl,mode_limits
    add hl,de
    ld a,(hl)
    or a
    jr nz,.unit
    ld ix,brief_unlimited
.unit:
    ld de,$0f18
    ld a,$5f
    call arc_text

    ; Show the stage sprite beside the objective; the yard also shows the hazard.
    ld a,(arc_stage)
    ld e,a
    ld d,0
    ld hl,mode_icons
    add hl,de
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(arc_stage)
    cp 2
    jr nz,.picture
    ld de,brief_balloon
.picture:
    ld hl,$5862                 ; lower edge of heading
    call brief_icon
    ld a,(arc_stage)
    cp 1
    jr nz,.start
    ld de,arc_bomb
    ld hl,$587c
    ld a,$42
    call brief_icon.colour
.start:
    ld ix,brief_start
    ld de,$1404
    call arc_card
    jp arc_enter

brief_icon:
    ld a,$44
.colour:
    push de
    call arc_square
    pop de
    jp arc_icon

; Fill C columns by B rows, preserving bitmap ink.
brief_panel:
    push bc
    call arc_attr
    pop bc
.row:
    push hl
    push bc
    ld b,c
.col:
    ld (hl),a
    inc hl
    djnz .col
    pop bc
    pop hl
    ld de,32
    add hl,de
    djnz .row
    ret

brief_ammo: db "AMMUNITION",0
brief_limit: db "TIME LIMIT",0
brief_number: db "0",0
brief_single: db "SHOT",0
brief_rounds_label: db "SHOTS",0
brief_time: db "00",0
brief_open: db "NO",0
brief_secs: db "SEC",0
brief_unlimited: db "LIMIT",0
brief_start: db "SHOOT HERE TO START",0
brief_balloon: db $03,$c0,$0f,$f0,$1f,$f8,$3f,$fc,$7f,$fe,$7f,$fe,$e7,$e7,$e7,$e7
    db $ff,$ff,$7f,$fe,$7f,$fe,$3f,$fc,$1f,$f8,$0f,$f0,$06,$60,$0c,$30
brief_rules:
    dw brief_0,brief_1,brief_2,brief_3,brief_4,brief_5,brief_6,brief_7
    dw brief_8,brief_9,brief_10,brief_11,brief_12,brief_13,brief_14,brief_15
brief_0: db "KNOCK DOWN ALL FOUR CANS.",0,"ONE SHOT CLEARS ONE CAN.",0
brief_1: db "SHOOT ALL FOUR GREEN CANS.",0,"A RED BOMB COSTS TWO ROUNDS.",0
brief_2: db "POP ALL THREE BALLOONS.",0,"FOLLOW THE CURVE AS THEY FALL.",0
brief_3: db "RING ALL FOUR BELLS IN TURN.",0,"A HIT LIGHTS THE NEXT BELL.",0
brief_4: db "BREAK ALL FOUR SHIELDS.",0,"YELLOW NEEDS ONE MORE HIT.",0
brief_5: db "SWITCH OFF ALL FOUR LAMPS.",0,"HITS FLIP THE ADJACENT LAMPS.",0
brief_6: db "RING EACH OF THE FOUR BELLS.",0,"ONLY ONE LANE OPENS AT A TIME.",0
brief_7: db "CLEAR ALL FOUR CUPS.",0,"EVERY SHOT SHUFFLES THE REST.",0
brief_8: db "BREAK ALL FOUR GREEN SHIELDS.",0,"WAIT WHILE THE GATES ARE BLUE.",0
brief_9: db "HIT THE SWINGING STAR.",0,"YOU GET ONE SHOT.",0
brief_10: db "CLEAR BOTH PAIRS OF GEMS.",0,"A HIT TAKES ITS TWIN WITH IT.",0
brief_11: db "HIT THE FOUR SWINGING WEIGHTS.",0,"PAIRS MOVE IN OPPOSITE WAYS.",0
brief_12: db "HIT THE JACKPOT FOUR TIMES.",0,"FOLLOW IT TO THE NEXT LANE.",0
brief_13: db "MEMORISE ALL FOUR POSITIONS.",0,"SHOOT AFTER THE LIGHTS GO OUT.",0
brief_14: db "CLEAR THE FOUR FUSES.",0,"BEAT THE COUNTDOWN.",0
brief_15: db "MAKE EXACTLY FIVE POINTS.",0,"ROWS PAY 1, 2, 3, 4 FROM TOP.",0
