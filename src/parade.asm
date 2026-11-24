; Restore z88dk's wide-sprite NIRVANA+ kernel and its self-modifying tables.
parade_install:
    call arc_nv_bank
    ld hl,arc_payload_end
    ld de,$db09
    call fair_expand
    ld hl,parade_tiles
    ld ($db2f),hl
    jp arc_show_scene

fair_expand:
.token:
    ld a,(hl)
    inc hl
    or a
    ret z
    ld b,0
    bit 7,a
    jr nz,.copy
    ld c,a
    ldir
    jr .token
.copy:
    and 127
    add a,3
    ld c,a
    push bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    push hl
    ex de,hl
    push hl
    or a
    sbc hl,bc
    pop de
    pop ix
    pop bc
    ldir
    push ix
    pop hl
    jr .token

parade_init:
    ld hl,$d800
    ld de,$d801
    ld bc,767
    ld (hl),$47
    ldir
    ld hl,parade_last
    ld de,parade_last+1
    ld bc,5
    ld (hl),0
    ldir
    ; The normal NIRVANA interrupt paints rows 1..23; preserve the hint.
    call arc_nv_bank
    ld de,$c000
.hint:
    ld hl,nv_text
    call arc_nv_sync.cell
    inc e
    ld a,e
    cp 32
    jr nz,.hint
    jp arc_show_scene

; Three blank wide tiles erase the last frame; three shifted wide tiles
; paint the new frame inside NIRVANA's scheduled interrupt slots.
parade_frame:
    call arc_nv_bank
    ld ix,$dc95                 ; first LD DE,nn operand in wide sprite ISR
    ld iy,parade_last
    ld hl,arc_wave_phase
    inc (hl)
    ld a,(hl)
    cp 72
    jr c,.phase
    xor a
    ld (hl),a
.phase:
    ld hl,arc_pos
    ld de,arc_alive
    ld b,3
.actor:
    push bc
    push af
    ld c,a
    ld a,(iy+0)
    ld (ix+0),a
    ld a,(iy+1)
    ld (ix+1),a
    ld (ix+3),0
    ld a,(de)
    or a
    jr z,.hidden
    push de
    push hl
    ld b,0
    ld hl,parade_x
    add hl,bc
    ld a,(hl)
    pop hl
    ld (iy+6),a                 ; pixel X for optical mask
    ld e,a
    and 7
    inc a
    ld (ix+27),a
    ld a,e
    srl a
    srl a
    srl a
    ld (hl),a
    ld (ix+24),a
    ld (iy+0),a
    ld a,c
    add a,a
    add a,24                    ; display Y 16..158, engine line = Y+8
    ld (ix+25),a
    ld (iy+1),a
    sub 8
    inc hl
    srl a
    srl a
    srl a
    ld (hl),a
    dec hl
    pop de
    jr .next
.hidden:
    xor a
    ld (ix+24),a
    ld (ix+25),a
    ld (ix+27),a
    ld (iy+0),a
    ld (iy+1),a
.next:
    inc hl
    inc hl
    inc de
    ld bc,8
    add ix,bc
    inc iy
    inc iy
    pop af
    add a,24
    cp 72
    jr c,.nowrap
    sub 72
.nowrap:
    pop bc
    djnz .actor
    jp arc_nv_frame

; Only perform optical bitmap work on a trigger. Exact 16x16 footprint,
; including fractional-character X/Y; menu and HUD pixels are excluded.
parade_mask:
    ld a,$ff
    jr parade_stamp
parade_unmask:
    xor a
parade_stamp:
    ld (parade_bits),a
    ld ix,parade_last
    ld b,3
.actor:
    push bc
    ld a,(ix+1)
    or a
    jr z,.next
    sub 8
    ld d,a
    ld a,(ix+6)
    and 7
    ld c,a
    ld a,(parade_bits)
    ld e,a
    ld a,c
    or a
    jr z,.aligned
.shift:
    srl e
    dec c
    jr nz,.shift
.aligned:
    ld a,(parade_bits)
    xor e
    ld c,a
    ld b,16
.line:
    ld a,d
    and 7
    or $c0
    ld h,a
    ld a,d
    and $c0
    rrca
    rrca
    rrca
    or h
    ld h,a
    ld a,d
    rlca
    rlca
    and $e0
    or (ix+0)
    ld l,a
    ld (hl),e
    inc l
    ld a,(parade_bits)
    ld (hl),a
    inc l
    ld (hl),c
    inc d
    djnz .line
.next:
    inc ix
    inc ix
    pop bc
    djnz .actor
    ret
parade_last: defs 12
parade_bits: db 0
parade_x:
    db 120,127,134,140,147,153,159,165,170,175,180,184,188,191,193,195,197,198,198,198,197,195,193,191,188,184,180,175,170,165,159,153,147,140,134,127,120,113,106,100,93,87,81,75,70,65,60,56,52,49,47,45,43,42,42,42,43,45,47,49,52,56,60,65,70,75,81,87,93,100,106,113
parade_tiles:
    defs 72,0
    db $03,$c0,$00,$0f,$f0,$00,$1f,$f8,$00,$3f,$fc,$00,$7f,$fe,$00,$7f,$fe,$00,$e7,$e7,$00,$e7,$e7,$00,$ff,$ff,$00,$7f,$fe,$00,$7f,$fe,$00,$3f,$fc,$00,$1f,$f8,$00,$0f,$f0,$00,$06,$60,$00,$0c,$30,$00
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $01,$e0,$00,$07,$f8,$00,$0f,$fc,$00,$1f,$fe,$00,$3f,$ff,$00,$3f,$ff,$00,$73,$f3,$80,$73,$f3,$80,$7f,$ff,$80,$3f,$ff,$00,$3f,$ff,$00,$1f,$fe,$00,$0f,$fc,$00,$07,$f8,$00,$03,$30,$00,$06,$18,$00
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$f0,$00,$03,$fc,$00,$07,$fe,$00,$0f,$ff,$00,$1f,$ff,$80,$1f,$ff,$80,$39,$f9,$c0,$39,$f9,$c0,$3f,$ff,$c0,$1f,$ff,$80,$1f,$ff,$80,$0f,$ff,$00,$07,$fe,$00,$03,$fc,$00,$01,$98,$00,$03,$0c,$00
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$78,$00,$01,$fe,$00,$03,$ff,$00,$07,$ff,$80,$0f,$ff,$c0,$0f,$ff,$c0,$1c,$fc,$e0,$1c,$fc,$e0,$1f,$ff,$e0,$0f,$ff,$c0,$0f,$ff,$c0,$07,$ff,$80,$03,$ff,$00,$01,$fe,$00,$00,$cc,$00,$01,$86,$00
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$3c,$00,$00,$ff,$00,$01,$ff,$80,$03,$ff,$c0,$07,$ff,$e0,$07,$ff,$e0,$0e,$7e,$70,$0e,$7e,$70,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0,$01,$ff,$80,$00,$ff,$00,$00,$66,$00,$00,$c3,$00
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$1e,$00,$00,$7f,$80,$00,$ff,$c0,$01,$ff,$e0,$03,$ff,$f0,$03,$ff,$f0,$07,$3f,$38,$07,$3f,$38,$07,$ff,$f8,$03,$ff,$f0,$03,$ff,$f0,$01,$ff,$e0,$00,$ff,$c0,$00,$7f,$80,$00,$33,$00,$00,$61,$80
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$0f,$00,$00,$3f,$c0,$00,$7f,$e0,$00,$ff,$f0,$01,$ff,$f8,$01,$ff,$f8,$03,$9f,$9c,$03,$9f,$9c,$03,$ff,$fc,$01,$ff,$f8,$01,$ff,$f8,$00,$ff,$f0,$00,$7f,$e0,$00,$3f,$c0,$00,$19,$80,$00,$30,$c0
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
    db $00,$07,$80,$00,$1f,$e0,$00,$3f,$f0,$00,$7f,$f8,$00,$ff,$fc,$00,$ff,$fc,$01,$cf,$ce,$01,$cf,$ce,$01,$ff,$fe,$00,$ff,$fc,$00,$ff,$fc,$00,$7f,$f8,$00,$3f,$f0,$00,$1f,$e0,$00,$0c,$c0,$00,$18,$60
    db 69,69,69,68,68,68,70,70,70,69,69,69,68,68,68,68,68,68,69,69,69,70,70,70
