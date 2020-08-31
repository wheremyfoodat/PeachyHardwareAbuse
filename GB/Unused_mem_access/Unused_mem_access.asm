; This test makes sure that you do not let writes to unused memory addresses
; go through, and that you return 0xFF when an unused memory address gets accessed
; This tests:
; -eRAM when the cartridge does not have any
; -unused MMIO
; -the unused mem near the end of the mem map

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
    
    ld a, %11100100 ; init video
    ld [rBGP], a

    xor a
    ld [rSCY], a
    ld [rSCX], a

; ----------- Round 1: FEA0 - FEFF test
    ld hl, $FEA0
round1:
    ld a, l
    ld [hl], a ; This write should normally do nothing as the region is unmapped
    ld a, [hl]
    cp a, $00
    call NZ, Round1Fail
    inc l
    jp NZ, round1

; ----------- Round 2: eWRAM access without an MBC
    ld hl, $A000
round2:
    ld a, l
    ld [hl], a ; This write should normally do nothing as the region is unmapped
    ld a, [hl]
    cp a, $FF
    call NZ, Round2Fail
    inc hl
    ld a, h
    cp a, $C0
    jp NZ, round2

; ------------ Round 3: Unused  MMIO address
round3:
    ld a, [$FF51] ; This register only exists on CGB, so reading it should return 0xFF as this is a DMG ROM
    cp a, $FF
    jp NZ, Round3Fail

    ld a, [$FF00]
    and a, %11000000 ; Top 2 bits of joypad reg should always be 1
    cp a, %11000000
    jp NZ, Round3Fail
        
    call Success
    call copyString
    call turnLCDOn

lock:
    jr lock ; The stop should lock the system, but this jr is just in case 

SECTION "strings", ROMX, Bank[1]

Success:
    ld hl, $9800
    ld de, SuccessStr
    ret

Failure:
    ld hl, $9800
    call copyString
    call turnLCDOn
    jp lock

Round1Fail:
    ld de, FailureUnmappedMemStr
    call Failure

Round2Fail:
    ld de, FailureEWRAMStr
    call Failure

Round3Fail:
    ld de, FailureMMIOStr
    call Failure

SuccessStr:
    db "All tests passed!", 0

FailureUnmappedMemStr:
    db "Unmapped mem test failed!", 0

FailureEWRAMStr:
    db "Unmapped eRAM test failed!", 0

FailureMMIOStr:
    db "Unmapped MMIO test failed!", 0