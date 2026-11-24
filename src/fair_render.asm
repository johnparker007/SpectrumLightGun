; Einar Saukas's NIRVANA+ runs in bank 0 with its own IM2 for one display
; interrupt. No paging or AUX capture takes place during its 8x2 raster.
arc_nv_bank:
    ld bc,$7ffd
    ld a,16
    out (c),a
    ret
arc_nv_frame:
    call arc_nv_bank
    call $fde3
    halt
    di
    ld a,$81
    ld i,a
    ld hl,frame                 ; NIRVANA serviced this interrupt
    inc (hl)
    call arc_show_scene
    ei
    ret

; Paint four 2-scanline attributes per cell in the engine's own code.
arc_nv_sync:
    call arc_nv_bank
    ld ix,arc_pos
    ld iy,arc_alive
    ld b,4
.row:
    push bc
    ld e,3
.column:
    push de
    ld hl,nv_dark
    ld a,(ix+0)
    cp e
    jr nz,.hazard
    ld a,(iy+0)
    or a
    jr z,.paint
    ld hl,nv_green
    jr .paint
.hazard:
    ld a,(iy+arc_hazards-arc_alive)
    or a
    jr z,.paint
    ld hl,nv_red
.paint:
    ld a,(ix+1)
    add a,a
    add a,a
    add a,a
    add a,8                     ; NIRVANA pixel line 16 is display Y=8
    ld d,a
    call .cell
    inc e
    call .cell
    ld a,d
    add a,8
    ld d,a
    call .cell
    dec e
    call .cell
    pop de
    ld a,e
    add a,8
    ld e,a
    cp 32
    jr c,.column
    inc ix
    inc ix
    inc iy
    pop bc
    djnz .row
.hint_setup:
    ld de,$c000                 ; hint on screen row 23
.hint:
    ld hl,nv_text
    call .cell
    inc e
    ld a,e
    cp 32
    jr c,.hint
    jp arc_show_scene
.cell:
    push hl
    push de
    ld b,h
    ld c,l
    call $dc62
    pop de
    pop hl
    ret
nv_dark: db 0,0,0,0
nv_red: db $42,$46,$42,$02
nv_green: db $44,$45,$44,$04
nv_text: db 7,7,7,7

    include "parade.asm"
; Hand-drawn 16x16 silhouettes. HL = top-left attribute, DE = 32-byte art.
arc_icon:
    call arc_pixel
    push hl
    call .eight
    pop hl
    ld a,l
    add a,32
    ld l,a
    jr nc,.eight
    ld a,h
    add a,8
    ld h,a
.eight:
    ld b,8
.line:
    ld a,(de)
    ld (hl),a
    inc de
    inc l
    ld a,(de)
    ld (hl),a
    inc de
    dec l
    inc h
    djnz .line
    ret
arc_can:
    db $1f,$f8,$3f,$fc,$7f,$fe,$6c,$06,$7f,$fe,$7f,$fe,$61,$86,$63,$c6
    db $67,$e6,$63,$c6,$61,$86,$7f,$fe,$7f,$fe,$60,$06,$3f,$fc,$1f,$f8
arc_bomb:
    db $00,$14,$00,$2a,$00,$14,$03,$e0,$03,$c0,$07,$e0,$1f,$f8,$37,$fc
    db $2f,$fc,$5f,$fe,$7f,$fe,$7f,$fe,$3f,$fc,$3f,$fc,$1f,$f8,$07,$e0

arc_ticket_ends:
    call arc_attr
    ld b,3
.stripe:
    push hl
    ld (hl),$6d
    ld de,23
    add hl,de
    ld (hl),$49
    pop hl
    ld de,32
    add hl,de
    djnz .stripe
    ret

; Double-width, double-height arcade type with a two-colour marquee.
arc_marquee:
    call arc_attr
.letter:
    ld a,(ix+0)
    inc ix
    or a
    ret z
    push hl
    ld (hl),$46
    inc hl
    ld (hl),$46
    ld de,31
    add hl,de
    ld (hl),$45
    inc hl
    ld (hl),$45
    pop hl
    push hl
    push af
    call arc_pixel
    ex de,hl
    pop af
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    ld bc,arc_font_base
    add hl,bc
    ld b,8
.line:
    push bc
    ld a,(hl)
    inc hl
    push hl
    ld hl,0
    ld b,8
.double:
    rlca
    adc hl,hl
    rrca
    rlca
    adc hl,hl
    djnz .double
    ld a,h
    ld (de),a
    inc e
    ld a,l
    ld (de),a
    inc d
    ld (de),a
    dec e
    ld a,h
    ld (de),a
    inc d
    pop hl
    pop bc
    ld a,b
    cp 5
    jr nz,.next
    ld a,d
    sub 8
    ld d,a
    ld a,e
    add a,32
    ld e,a
.next:
    djnz .line
    pop hl
    inc hl
    inc hl
    jr .letter
 ; DE=slot position, A=visible ink (zero erases). Update bitmap, the
; independent optical mask, and the same slot in the raster colour stream.
nv_slot:
    push de
    push af
    call arc_attr
    call arc_square
    or a
    jr z,.mask
    push hl
    ld de,(mode_art)
    call arc_icon
    pop hl
    call mode_mask_ink
.mask:
    set 7,h
    call arc_square
    call arc_nv_bank
    pop af
    and 7
    jr nz,.paint
    ld a,(arc_stage)
    cp 16
    jr c,.dark
    pop de
    jp fair_restore_slot
.dark:
    xor a
.paint:
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld de,nv_actor_inks
    add hl,de
    pop de
    ld a,d
    add a,a
    add a,a
    add a,a
    add a,8
    ld d,a
    call arc_nv_sync.cell
    inc e
    call arc_nv_sync.cell
    ld a,d
    add a,8
    ld d,a
    call arc_nv_sync.cell
    dec e
    call arc_nv_sync.cell
    jp arc_show_scene
nv_actor_inks:
    db 0,0,0,0, $41,1,$41,1, $42,2,$42,2, $43,3,$43,3
    db $44,$45,$44,4, $45,5,$45,5, $46,6,$46,6, $47,7,$47,7
