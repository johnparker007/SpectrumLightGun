; Raster Fair. Bank 5 is the visible scene, bank 7 is a private optical mask.
; HUD, labels and sprites never enter either capture. R14 idle outside audio.
arcade_start:
    ld a,(bad_port)
    or a
    jp nz,arc_port_error
    call arc_show_scene
    ld a,7
    ld e,$1c                    ; A/B tone, C noise; both AY ports input
    call arc_ay
    ld a,8
    ld e,8
    call arc_ay
    ld a,9
    ld e,6
    call arc_ay
    ld a,10
    ld e,0
    call arc_ay
    call arc_select_gun
    jp arc_menu

arc_show_scene:
    ld bc,$7ffd
    ld a,23                     ; display 5, page 7 at C000
    out (c),a
    ret

arc_clear:
    call arc_show_scene
    xor a
    out ($fe),a
    ld hl,$4000
    ld de,$4001
    ld bc,6911
    ld (hl),a
    ldir
    ld hl,$c000
    ld de,$c001
    ld bc,6911
    ld (hl),a
    ldir
    ret

; D=character row, E=column -> HL=bank 5 attribute address. Preserves DE.
arc_attr:
    ld l,d
    ld h,0
    dup 5
    add hl,hl
    edup
    ld b,0
    ld c,e
    add hl,bc
    ld bc,$5800
    add hl,bc
    ret
; Convert attribute address to top pixel byte in its screen.
arc_pixel:
    ld a,h
    and 3
    rlca
    rlca
    rlca
    ld b,a
    ld a,h
    and $80
    or $40
    or b
    ld h,a
    ret

; IX=NUL-terminated ROM text, DE=position, A=colour.
arc_text:
    ld (arc_ink),a
    call arc_attr
.char:
    ld a,(ix+0)
    or a
    ret z
    inc ix
    push hl
    push af
    ld a,(arc_ink)
    ld (hl),a
    call arc_pixel
    ex de,hl
    pop af
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    ld bc,$3c00
    add hl,bc
    ld b,8
.line:
    ld a,(hl)
    ld (de),a
    inc hl
    inc d
    djnz .line
    pop hl
    inc hl
    jr .char

; Cards use equally sized visible and optical rectangles.
arc_card:
    push de
    push ix
    call arc_attr
    ld a,$0d                    ; cyan type on blue
    call arc_card_rect
    set 7,h
    ld a,$7f
    call arc_card_rect
    pop ix
    pop de
    push de
    call arc_ticket_ends
    pop de
    inc d
    inc e
    inc e
    ld a,$4f
    jp arc_text
arc_card_rect:
    push hl
    ld c,3
.row:
    push hl
    ld b,24
.col:
    ld (hl),a
    inc hl
    djnz .col
    pop hl
    ld de,32
    add hl,de
    dec c
    jr nz,.row
    pop hl
    ret

arc_menu:
    call arc_clear
    xor a
    ld (arc_state),a
    ld ix,fair_title
    ld de,$0004
    call arc_marquee
    call modes_menu
    jp arc_enter

arc_begin:
    call arc_clear
    ld a,1
    ld (arc_state),a
    ld (arc_alive),a
    ld (arc_alive+1),a
    ld (arc_alive+2),a
    ld (arc_alive+3),a
    ld hl,$0101
    ld (arc_hazards),hl
    ld (arc_hazards+2),hl
    ld a,5
    ld (arc_ammo),a
    xor a
    ld (arc_wave_phase),a
    ld (arc_hits),a
    ld (arc_blast),a
    ld hl,arc_initial_pos
    ld de,arc_pos
    ld bc,8
    ldir
    call parade_install
    call modes_setup
    ld hl,$ffff
    ld (nv_previous_ink),hl
    ld (nv_previous_ink+2),hl
    ld hl,arc_pos
    ld de,mode_previous
    ld bc,8
    ldir
    call fair_backdrop
    call arc_nv_bank
    call arc_nv_sync.hint_setup
    ld a,(arc_stage)
    call mode_title
.header:
    ld de,$0001
    ld a,$45
    call arc_text
    ld ix,ammo_label
    ld de,$0016
    ld a,6
    call arc_text
    ld a,(arc_stage)
    call mode_hint
    ld de,$1701
    ld a,7
    call arc_text
    call mode_draw
    call arc_draw_ammo
    ld a,(mode_seconds_left)
    or a
    call nz,mode_show_time
    ld a,(arc_stage)
    cp 1
    call z,arc_nv_sync
arc_enter:
    xor a
    ld (arc_armed),a
    ei
arc_idle:
    ld a,(frame)
    ld hl,arc_last_tick
    cp (hl)
    call nz,arc_tick
arc_poll:
    ld bc,$fffd
    in a,(c)
    bit 5,a
arc_poll_end:
    jr z,.down
    ld a,1
    ld (arc_armed),a
    jr arc_idle
.down:
    ld a,(arc_armed)
    or a
    jr z,arc_idle
    xor a
    ld (arc_armed),a
    ld a,(arc_state)
    cp 1
    jr nz,.mask_ready
    ld a,(arc_stage)
    cp 13
    jr nz,.wave
    ld a,(mode_gate)
    or a
    jp z,arc_idle
    jr .mask_ready
.wave:
    cp 2
    call z,parade_mask
.mask_ready:
    call arc_shot_sound
    ld hl,$f000
    ld (arc_fill_sp+1),hl
    call arc_capture
    ld (arc_raw_y),a
    ld a,(arc_state)
    cp 1
    jp nz,arc_card_shot
    ld hl,arc_ammo
    dec (hl)
    ld a,(arc_raw_y)
    cp 192
    jr nc,.check_bombs
    call arc_find_lane
    jr nc,.finish
    call mode_hit
    jr .finish
.check_bombs:
    cp $ff                      ; only a wholly dark target frame qualifies
    jr nz,.finish
    ld a,(arc_stage)
    cp 1
    jr nz,.finish
    ld hl,$db00                 ; all attributes white ink on black paper;
    ld (arc_fill_sp+1),hl       ; only the bombs have set bitmap pixels
    call arc_capture
    cp 192
    jr nc,.finish
    call arc_find_lane
    jr nc,.finish
    ld hl,arc_hazards
    add hl,de
    ld a,(hl)
    or a
    jr z,.finish
    ld (hl),0
    ld hl,arc_ammo
    ld a,(hl)
    or a
    jr z,.blast
    dec (hl)
.blast:
    ld a,e
    inc a
    ld (arc_blast),a
.finish:
    call arc_restore
    call arc_draw_ammo
    call mode_after_shot
    ld a,(arc_fill_sp+2)
    cp $db
    call z,arc_reset_mask
    call mode_draw
    ld a,(arc_stage)
    cp 1
    call z,arc_nv_sync
    ld a,(arc_blast)
    or a
    call nz,arc_explode
    ld a,(arc_goal)
    ld hl,arc_hits
    cp (hl)
    jp z,arc_result
    ld a,(arc_ammo)
    or a
    jp z,arc_result
    jp arc_enter

arc_reset_mask:
    di
    ld (arc_mask_sp+1),sp
    ld sp,$db00
    ld de,0
    dup 384
    push de
    edup
arc_mask_sp:
    ld sp,0
    ei
    ret

arc_capture:
    ld de,$4747
    ld hl,samples
    call capture
    ; Account for the flash frame once, after the timing-critical reads.
    ld a,(frame)
    ld hl,arc_last_tick
    cp (hl)
    jr z,.sampled
    ld (hl),a
    call arc_music
.sampled:
    ld hl,samples
    bit 4,(hl)
    ld a,$fe
    ret nz
    inc hl
    ld b,192
    ld de,2
.scan:
    bit 4,(hl)
    jr nz,.found
    add hl,de
    djnz .scan
    ld a,$ff
    ret
.found:
    ld a,192
    sub b
    ret
arc_restore:
    call wait_frame
    jp arc_show_scene

; E=lane with carry if within the target's 16 lines plus 8 lines of tolerance.
arc_find_lane:
    ld c,a
    ld hl,arc_pos+1
    ld de,0
.next:
    ld a,(hl)
    add a,a
    add a,a
    add a,a
    sub c
    add a,23
    cp 32
    ret c
    inc hl
    inc hl
    inc e
    ld a,e
    cp 4
    jr nz,.next
    or a
    ret

arc_card_shot:
    call arc_restore
    ld a,(arc_raw_y)
    cp 192
    jp nc,arc_enter
    ld c,a
    ld a,(arc_state)
    cp 3
    jp z,arc_begin
    or a
    jr nz,.result
    ld a,c
    cp 40
    jr nc,.ticket
    ld hl,mode_page
    inc (hl)
    ld a,(hl)
    cp 5
    jp c,arc_menu
    ld (hl),0
    jp arc_menu
.ticket:
    call mode_choice
    cp $ff
    jp z,arc_enter
    ld (arc_stage),a
    jp arc_briefing
.result:
    ld a,c
    cp 80
    jp nc,arc_menu
    ld a,(arc_tour)
    or a
    jp z,arc_briefing
    ld hl,arc_stage
    inc (hl)
    ld a,(hl)
    cp 16
    jp c,arc_briefing
    jp arc_menu

arc_result:
    xor a
    ld (arc_armed),a             ; timeout can enter while the trigger is armed
    call arc_clear
    ld a,2
    ld (arc_state),a
    ld ix,try_text
    ld a,(mode_expired)
    or a
    jr z,.score
    ld ix,time_up
.score:
    ld a,(arc_goal)
    ld hl,arc_hits
    cp (hl)
    jr nz,.banner
    ld ix,win_text
.banner:
    ld de,$0204
    ld a,$46
    call arc_text
    ld a,(arc_hits)
    add a,'0'
    ld (arc_score_digit),a
    ld a,(arc_goal)
    add a,'0'
    ld (arc_score_digit+4),a
    ld ix,score_text
    ld de,$0404
    ld a,7
    call arc_text
    ld ix,replay_label
    ld a,(arc_tour)
    or a
    jr z,.buttons
    ld a,(arc_hits)
    ld hl,arc_total
    add a,(hl)
    ld (hl),a
    ld ix,next_label
    ld a,(arc_stage)
    cp 15
    jr nz,.buttons
    ld a,(arc_total)
    ld hl,tour_digits
    ld (hl),'0'
.tens:
    cp 10
    jr c,.ones
    inc (hl)
    sub 10
    jr .tens
.ones:
    add a,'0'
    inc hl
    ld (hl),a
    ld ix,total_label
    ld de,$1204
    ld a,$46
    call arc_text
    ld ix,finish_label
.buttons:
    ld de,$0604
    call arc_card
    ld ix,menu_label
    ld de,$0c04
    call arc_card
    jp arc_enter

arc_draw_ammo:
    ld a,(arc_ammo)
    add a,'0'
    ld (arc_ammo_digit),a
    ld ix,arc_ammo_digit
    ld de,$001c
    ld a,$46
    jp arc_text

arc_tick:
    ld (arc_last_tick),a
    call arc_music
    ld a,(arc_state)
    cp 1
    ret nz
    call mode_timer_tick
    jr nc,.running
    pop hl                     ; arc_idle called arc_tick; the round has ended
    jp arc_result
.running:
    ld a,(arc_stage)
    cp 2
    jp z,parade_frame
    call mode_tick
    jp arc_nv_frame

arc_objects:
    ld ix,arc_pos
    ld iy,arc_alive
    ld b,4
.loop:
    push bc
    ld e,(ix+0)
    ld d,(ix+1)
    call arc_attr
    push hl
    call mode_colour
    pop hl
    or a
    ld a,0
    jr z,.body
    ld a,(mode_ink)
.body:
    call arc_square
    or a
    jr z,.no_icon
    push hl
    ld de,(mode_art)
    call arc_icon
    pop hl
    ld a,$44
.no_icon:
    set 7,h
    or a
    jr z,.target
    call mode_mask_ink
.target:
    call arc_square
    ld a,(arc_stage)
    cp 1
    call z,arc_bombs
    inc ix
    inc ix
    inc iy
    pop bc
    djnz .loop
    ret

; Three bombs share each target's row. A row can explode only once.
arc_bombs:
    ld c,3
    ld b,4
.col:
    push bc
    ld a,(ix+0)
    cp c
    jr z,.skip
    ld e,c
    ld d,(ix+1)
    call arc_attr
    ld a,(iy+arc_hazards-arc_alive)
    or a
    ld a,0
    jr z,.colour
    ld a,$42                    ; red fuse icon in normal view
.colour:
    call arc_square
    or a
    jr z,.no_icon
    push hl
    ld de,arc_bomb
    call arc_icon
    pop hl
.no_icon:
    set 7,h
    call arc_pixel
    ld a,(iy+arc_hazards-arc_alive)
    neg
    ld e,a
    call arc_bitmap_square
.skip:
    pop bc
    ld a,c
    add a,8
    ld c,a
    djnz .col
    ret
arc_square:                     ; 2x2 attribute cells; preserves HL and A
    push hl
    ld (hl),a
    inc hl
    ld (hl),a
    ld de,31
    add hl,de
    ld (hl),a
    inc hl
    ld (hl),a
    pop hl
    ret
arc_bitmap_square:
    ld a,(hl)
    cp e
    ret z
    push hl
    call .eight
    pop hl
    ; Use attribute-to-pixel conversion for rows straddling a screen third.
    ld a,l
    add a,32
    ld l,a
    jr nc,.eight
    ld a,h
    add a,8
    ld h,a
.eight:
    ld b,8
.scan:
    ld (hl),e
    inc l
    ld (hl),e
    dec l
    inc h
    djnz .scan
    ret

arc_explode:
    ; Light every former bomb in this lane for eight normal display frames.
    dec a
    add a,a
    ld e,a
    ld d,0
    ld hl,arc_pos+1
    add hl,de
    ld d,(hl)
    ld e,3
    ld b,4
.flare:
    push bc
    push de
    call arc_attr
    ld a,$76
    call arc_square
    pop de
    ld a,e
    add a,8
    ld e,a
    pop bc
    djnz .flare
    ld a,6
    ld e,28
    call arc_ay
    ld a,10
    ld e,14
    call arc_ay
    ld a,7
    ld (arc_noise_left),a
    ld b,8
.hold:
    push bc
    call wait_frame
    call arc_music
    pop bc
    djnz .hold
    xor a
    ld (arc_blast),a
    call arc_objects
    jp arc_nv_sync

    include "briefing.asm"
    include "fair_modes.asm"
    include "fair_render.asm"
    include "fair_backdrop.asm"

arc_port_error:
    ld ix,port_label
    ld de,$0202
    ld a,$42
    call arc_text
    jr $

arc_ay:                         ; A=register, E=compiled value
    ld bc,$fffd
    out (c),a
    ld b,$bf
    out (c),e
    ret
arc_select_gun:
    ld bc,$fffd
    ld a,14
    out (c),a
    ret
arc_shot_sound:
    ld e,9
    ld a,6
    call arc_ay
    ld e,13
    ld a,10
    call arc_ay
    ld a,3
    ld (arc_noise_left),a
    jp arc_select_gun
arc_music:
    ld hl,arc_noise_left
    ld a,(hl)
    or a
    jr z,.tune
    dec (hl)
    ld e,(hl)
    sla e
    ld a,10
    call arc_ay
.tune:
    ld hl,arc_beat
    dec (hl)
    jr nz,arc_select_gun
    ld (hl),8
    ld a,(arc_note)
    and 7
    add a,a
    add a,a
    ld e,a
    ld d,0
    ld hl,arc_song
    add hl,de
    xor a
.notes:
    push af
    ld e,(hl)
    inc hl
    call arc_ay
    pop af
    inc a
    cp 4
    jr nz,.notes
    ld hl,arc_note
    inc (hl)
    jp arc_select_gun
arc_song:                       ; compiled AY periods, channels A and B
    dw 424,1695, 336,1695, 283,1131, 336,1131
    dw 378,1509, 318,1509, 252,1008, 318,1008
fair_title: db "RASTER FAIR",0
tour_label: db "PLAY ALL SIXTEEN",0
next_label: db "NEXT CHALLENGE",0
finish_label: db "FINISH TOUR",0
total_label: db "FAIR TOTAL  "
tour_digits: db "00 / 61",0
arc_total: db 0
arc_tour: db 0
ammo_label: db "SHOTS",0
win_text: db "CLEAN SWEEP!",0
try_text: db "OUT OF SHOTS",0
time_up: db "TIME UP!",0
score_text: db "SCORE    "
arc_score_digit: db "0 / 4",0
replay_label: db "PLAY AGAIN",0
menu_label: db "CHOOSE A CHALLENGE",0
port_label: db "AUX PORT TEST FAILED",0
arc_initial_pos: db 19,4, 3,9, 27,14, 19,19
arc_pos: defs 8
arc_alive: defs 4
arc_hazards: defs 4
arc_stage: db 0
arc_state: db 0
arc_ammo: db 0
arc_ammo_digit: db "0",0
arc_hits: db 0
arc_blast: db 0
arc_raw_y: db 0
arc_wave_phase: db 0
arc_last_tick: db 0
arc_armed: db 0
arc_noise_left: db 0
arc_note: db 0
arc_beat: db 1
arc_ink: db 0
