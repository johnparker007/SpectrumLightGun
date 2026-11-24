; Stage entry only. Screen 5 bitmap + NIRVANA 8x2 paint records in bank 0.
; Entries 1..255 select 8 bitmap bytes followed by four attribute bytes.
    include "art_size.inc"

; The single CODE block spans fixed bank 2 and the loader's current top
; bank. Stash its art tail in bank 3 before normalising the paging registers.
fair_store_art:
    ld hl,$c000
    ld de,$4000                 ; use screen bitmap and spare BASIC RAM
    ld bc,$1800                 ; as staging, leaving system variables untouched
    ldir
    ld de,$6000
    ld bc,art_size-$1800
    ldir
    ld a,19
    ld bc,$7ffd
    out (c),a
    ld hl,$4000
    ld de,$c000
    ld bc,$1800
    ldir
    ld hl,$6000
    ld bc,art_size-$1800
    ldir
fair_art_stored:
    ret

fair_banks: db 19,17,20,22
fair_backdrop:
    ld a,(arc_stage)
    rrca
    rrca
    rrca
    rrca
    and 3
    ld hl,fair_banks
    call extra_byte
    ld bc,$7ffd
    out (c),a
    ld a,(arc_stage)
    and 15
    add a,a
    add a,a
    ld l,a
    ld h,$c0
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    ex de,hl
    ld de,$4000                 ; staging, before scene text or sprites
    ldir
    call arc_nv_bank
    ld hl,$4000
    ld de,$c000
    call fair_expand
    ld hl,$4000
    ld de,$4001
    ld bc,6143
    ld (hl),0
    ldir
    ld ix,$c000
    push ix
    pop hl
    ld de,32*22
    add hl,de
    ld (.atlas+1),hl
    ld de,$0100                  ; row 1, column 0, leave HUD and hint free
.cell:
    ld a,(ix+0)
    inc ix
    or a
    jr z,.advance
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld b,h
    ld c,l
    add hl,hl
    add hl,bc
.atlas:
    ld bc,0
    add hl,bc
    push de
    push hl
    call arc_attr
    call arc_pixel
    ex de,hl
    pop hl
    ld b,8
.scan:
    ld a,(hl)
    ld (de),a
    inc hl
    inc d
    djnz .scan
    pop de
    push de
    ld b,h
    ld c,l
    ld a,d
    add a,a
    add a,a
    add a,a
    add a,8
    ld d,a
    call $dc62
    pop de
.advance:
    inc e
    ld a,e
    cp 32
    jr c,.cell
    ld e,0
    inc d
    ld a,d
    cp 23
    jr c,.cell
    jp arc_show_scene

