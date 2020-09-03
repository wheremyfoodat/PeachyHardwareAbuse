include "hardware.inc"
include "common.asm"

SECTION "start", ROM0[$0100]
Entrypoint:
    nop
    jp main

    REPT $150 - $104
        db 0
    ENDR

SECTION "rom", ROM0[$0150]
main:
    di
    ld sp, $FFFC

    ; init video (enable LCD later)
    call initFont    
    ld a, %11100100
    ld [rBGP], a
