; Stage entry only. Screen 5 bitmap + NIRVANA 8x2 paint records in bank 0.
; Entries 1..255 select 8 bitmap bytes followed by four attribute bytes.
    include "art_size.inc"

; The single CODE block spans fixed bank 2 and the loader's current top
; bank. Stash its art tail in bank 3 before normalising the paging registers.
fair_store_art:
    ld hl,$c000
    ld de,$4000                 ; use screen bitmap and spare BASIC RAM
    ld bc,art_size <? $1800   ; as staging, leaving system variables untouched
    ldir
    if art_size > $1800
    ld de,$6000
    ld bc,art_size-$1800
    ldir
    endif
    ld a,19
    ld bc,$7ffd
    out (c),a
    ld hl,$4000
    ld de,$c000
    ld bc,art_size <? $1800
    ldir
    if art_size > $1800
    ld hl,$6000
    ld bc,art_size-$1800
    ldir
    endif
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
    call scenery_zx7
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
    ld (fair_tile.atlas+1),hl
    ld de,$0100                  ; row 1, column 0, leave HUD and hint free
.cell:
    ld a,(ix+0)
    inc ix
    or a
    jr z,.advance
    call fair_tile
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


fair_tile:
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
    ret

; Restore all four background cells when an expansion actor disappears or
; moves. Bank 0 retains the map and atlas between shots. D=row, E=column.
fair_restore_slot:
    call .cell
    inc e
    call .cell
    inc d
    call .cell
    dec e
    call .cell
    jp arc_show_scene
.cell:
    push de
    call arc_attr
    ld de,$c000-$5820
    add hl,de
    ld a,(hl)
    pop de
    jp fair_tile

; ZX7 standard decoder by Einar Saukas, Antonio Villena and Metalbrain.
; Standalone exit and documented shifts for SjASMPlus.
scenery_zx7:

   ; enter : hl = void *src
   ;         de = void *dst
   ;
   ; exit  : hl = & following uncompressed block
   ;
   ; uses  : af, bc, de, hl

        ld      a, $80
       
dzx7s_copy_byte_loop:

        ldi                              ; copy literal byte
        
dzx7s_main_loop:

        call    dzx7s_next_bit
        jr      nc, dzx7s_copy_byte_loop ; next bit indicates either literal or sequence

; determine number of bits used for length (Elias gamma coding)

        push    de
        ld      bc, 0
        ld      d, b
        
dzx7s_len_size_loop:

        inc     d
        call    dzx7s_next_bit
        jr      nc, dzx7s_len_size_loop

; determine length

dzx7s_len_value_loop:

        call    nc, dzx7s_next_bit
        rl      c
        rl      b
;;        jr      c, dzx7s_exit           ; check end marker
        jr      c, dzx7s_exit
        dec     d
        jr      nz, dzx7s_len_value_loop
        inc     bc                      ; adjust length

; determine offset

        ld      e, (hl)                 ; load offset flag (1 bit) + offset value (7 bits)
        inc     hl

        sla e
        inc e


        jr      nc, dzx7s_offset_end    ; if offset flag is set, load 4 extra bits
        ld      d, $10                  ; bit marker to load 4 bits
        
dzx7s_rld_next_bit:

        call    dzx7s_next_bit
        rl      d                       ; insert next bit into D
        jr      nc, dzx7s_rld_next_bit  ; repeat 4 times, until bit marker is out
        inc     d                       ; add 128 to DE
        srl	d			; retrieve fourth bit from D
        
dzx7s_offset_end:

        rr      e                       ; insert fourth bit into E

; copy previous sequence

        ex      (sp), hl                ; store source, restore destination
        push    hl                      ; store destination
        sbc     hl, de                  ; HL = destination - offset - 1
        pop     de                      ; DE = destination
        ldir

dzx7s_exit:

        pop     hl                      ; restore source address (compressed data)
        jr      nc, dzx7s_main_loop
        
dzx7s_next_bit:

        add     a, a                    ; check next bit
        ret     nz                      ; no more bits left?
        ld      a, (hl)                 ; load another group of 8 bits
        inc     hl
        rla
        ret
