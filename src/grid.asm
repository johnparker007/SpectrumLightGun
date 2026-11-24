; One layout byte per lane: active column 0..3, or $ff for no target.
; The bitmap holds the white mask. Solid blue/green attributes conceal it
; during play; capture's uniform white-ink/black-paper fill reveals it.
grid_start:
    ld a,(bad_port)
    or a
    jp nz,dashboard_error
grid_round:
    call blackout
    ld a,4
    ld (grid_ammo),a
    ld hl,grid_live
    ld de,$ffff
    ld (hl),e
    inc hl
    ld (hl),e
    inc hl
    ld (hl),e
    inc hl
    ld (hl),e
    call grid_draw
    ld b,50
.ready:
    call wait_frame
    djnz .ready
    ld a,(grid_layout)
    add a,a
    add a,a
    ld e,a
    ld d,0
    ld hl,grid_layouts
    add hl,de
    ld de,grid_live
    ld bc,4
    ldir
    call wait_frame
    call grid_draw
grid_rearm:
    ld bc,$fffd
    in a,(c)
    bit 5,a
    jr z,grid_rearm
grid_idle:
    in a,(c)
    bit 5,a
    jr nz,grid_idle
grid_shot:
    ld hl,samples
    ld de,$4747
    call capture
    ld hl,grid_ammo
    dec (hl)
    ld hl,samples
    bit 4,(hl)                 ; already high at first read: spend a round only
    jr nz,grid_decided
    inc hl                     ; first line's OR byte
    ld de,2
    ld ix,grid_live
    ld c,4
.lane:
    ld b,48
.line:
    bit 4,(hl)
    jr nz,.hit
    add hl,de
    djnz .line
    inc ix
    dec c
    jr nz,.lane
    jr grid_decided
.hit:
    ld (ix+0),$ff              ; an inactive lane stays inactive
grid_decided:
    call blackout              ; next interrupt; clear and repaint in top border
    call grid_draw
grid_board_ready:
    ld hl,grid_live
    ld a,(hl)
    inc hl
    and (hl)
    inc hl
    and (hl)
    inc hl
    and (hl)
    cp $ff
    ld a,4                     ; green win border
    jr z,.done
    ld a,(grid_ammo)
    or a
    jr nz,grid_rearm
    ld a,2                     ; red loss border
.done:
    out ($fe),a
    ld b,50
.hold:
    call wait_frame
    djnz .hold
    xor a
    out ($fe),a
    ld hl,grid_layout
    inc (hl)
    ld a,(hl)
    and 7
    ld (hl),a
    jp grid_round

dashboard_error:
    call dashboard
    jr $

; 2x2 native attributes at columns 3,11,19,27 and rows 2,8,14,20.
grid_draw:
    ld ix,grid_live
    ld hl,$5843
    ld b,4
.lane:
    push bc
    ld c,0
.slot:
    ld a,(ix+0)
    cp c
    ld a,$09                    ; blue, black mask
    ld e,0
    jr nz,.paint
    ld a,$64                    ; bright green, white mask
    dec e
.paint:
    push hl
    push bc
    ld (hl),a
    inc hl
    ld (hl),a
    ld bc,31
    add hl,bc
    ld (hl),a
    inc hl
    ld (hl),a
    pop bc
    pop hl
    push hl
    push bc
    ; Attribute address $58xx/$59xx/$5axx -> bitmap third $40/$48/$50.
    ld a,h
    sub $58
    rlca
    rlca
    rlca
    add a,$40
    ld h,a
    ld a,(hl)                  ; all pixels of a slot have the same mask byte
    cp e
    jr z,.mask_ready
    call .bitmap_cell_pair
    ld a,l
    add a,32                    ; each chosen pair stays in its screen third
    ld l,a
    call .bitmap_cell_pair
.mask_ready:
    pop bc
    pop hl
    ld de,8
    add hl,de
    inc c
    ld a,c
    cp 4
    jr nz,.slot
    ld de,160
    add hl,de
    inc ix
    pop bc
    djnz .lane
    ld hl,$5800
    ld a,(grid_ammo)
    ld b,a
    or a
    ret z
.bullet:
    ld (hl),$36                 ; yellow ammunition pips
    inc hl
    inc hl
    djnz .bullet
    ret
.bitmap_cell_pair:
    push hl
    ld b,8
.line:
    ld (hl),e
    inc l
    ld (hl),e
    dec l
    inc h
    djnz .line
    pop hl
    ret
grid_ammo: db 4
grid_live: defs 4
grid_layout: db 0
grid_layouts:
    db 2,0,$ff,2                 ; separated pair in column 3
    db 1,1,0,2                   ; adjacent upper lanes in column 2
    db $ff,2,0,3
    db 3,1,2,0
    db 0,$ff,3,2
    db 1,1,1,1                   ; same X in every lane
    db 3,1,2,$ff
    db 0,2,3,1
