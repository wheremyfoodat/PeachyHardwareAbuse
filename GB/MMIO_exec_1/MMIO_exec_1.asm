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
    call initFont

    ld a, $C9
    ld [rTMA], a ; store opcode for RET into TMA
    ld c, $0
    ld a, $A    
    ld [rTIMA], a
    ld a, %101
    ld [rTAC], a

    nop
    nop
    nop
    call rTIMA

    ; After test routine: Print results
    ld a, c
    ld hl, $9800

    cp a, $1
    call Z, Success
    call NZ, Failure
    call copyString

    ld a, %11100100
    ld [rBGP], a

    xor a
    ld [rSCY], a
    ld [rSCX], a

    call turnLCDOn
lock:
    jr lock

SECTION "strings", ROMX, Bank[1]

Success:
    ld de, SuccessStr
    ret

Failure:
    ld de, FailureStr
    ret

SuccessStr:
    db "Your emu doesn't\nsuck that much\ncock, congrats!", 0
FailureStr:
    db "Your emu suxxx lol", 0



