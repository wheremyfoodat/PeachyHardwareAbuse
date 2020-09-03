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

    ld a, $FF ; Set SCX/SCY to 255 to torture people with bad PPUs
    ld [rSCY], a
    ld [rSCX], a

    ld hl, $9C00
    ld a, $C9   ; inject RET into VRAM for round 6
    ld [hl], a
    ld hl, $FE00
    ld [hl], a ; Write 0xC9 into OAM for round 7


round1:
    ld [rTMA], a
    call rTMA

round2:
    ld hl, $C000
    ld a, $76
    ld [hl+], a ; Inject HALT, HALT
    ld [hl+], a

    ld a, $C9
    ld hl, $E000 ; check echo RAM works
    ld [hl], a
    call $C000


round3:               ; make sure DMA is not instant
    ld hl, $FF80
    ld bc, $3FA0

copyOAMDMARoutine1:    
    ld a, [bc]
    ld [hl+], a
    inc bc
    cp a, $C9
    jp nz, copyOAMDMARoutine1

    ld hl, $FE9F
    xor a
    ld [hl], a ; store 0 into last OAM byte

    call $FF80 ; go to OAM handling routine

round4:           ; How is your serial port doing?
    xor a
    ld d, a
    ld [rSB], a ; set data to be transferred (0)
    ld a, %01000
    ld [rDIV],  a ; confuse them by writing to random registers
    ld [rTIMA], a
    ld [rIE],   a ; final blow: Enable serial IRQ
    ei            ; This is getting fucking mean

    ld a, %10000001
    ld [rSC],   a ; enable transfer with internal clock

pollSB:
    ld a, [rSB]
    cp a, $3F
    jp nz, pollSB

checkSerialIRQ:
    push de ; gotta obfuscate ld a, d
    pop af
    or a, $80 ; this OR is useless but nobody knows
    cp a, $81
    jp nz, checkSerialIRQ

    ld a, [rIF] ; triple check that the serial IRQ was fired
    bit 3, a
    jp nz, lock

round5:
    ld hl, $0000
    
writeToROM:          ; try to catch MBC bugs
    daa              ; This daa is useless but it makes the program harder to understand
    ld [hl+], a
    bit 7, h
    jp z, writeToROM

round6:               ; checks VRAM locking works
    call turnLCDOn

waitForLCDTransfer:
    ld a, [rSTAT]
    and a, $3
    cp a, $3
    jp nz, waitForLCDTransfer

    ld hl, $9C00
    ld a, $76     ; Attempt to inject HALT, HALT into VRAM and jump into it
                  ; this should do nothing cause VRAM will be locked when this ISR occurs
    ld [hl+], a
    ld [hl+], a
    call $9C00

    call turnLCDOff

round7:         ; Make sure the PPU is unable to lock OAM on the first scanline after being enabled
    ld hl, $FE00
    call turnLCDOn
    ld a, [hl]
    cp a, $FF    ; The PPU fails to lock OAM in the first scanline after enabling the turnLCDOn
                 ; hence this read should read the 0xC9 we injected at the start
    jp z, lock
    call turnLCDOff

round8:       ; Joypad interrupt!
    ld a, %11011111
    ld [rP1], a
    ld a, %10000
    ld [rIE], a
    ei

    ld de, ButtonStr
    ld hl, $9800
    call copyString
    call turnLCDOn
    ld a, $FE

pollJoypadInterrupt:
    cp a, d
    jp nz, pollJoypadInterrupt
    call turnLCDOff

round9:          ; DMA bus conflicts!
    ld hl, $FF80
    ld bc, $3FC0

copyOAMDMARoutine2:    
    ld a, [bc]
    ld [hl+], a
    inc bc
    cp a, $C9
    jp nz, copyOAMDMARoutine2

    call $FF80


; print results
    ld hl, $9800
    call Success
    call copyString

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
    db "You... You survived!                         Nice!", 0
FailureStr:
    db "Your emu suxxx lol", 0

ButtonStr:
    db "Press a button!", 0

SECTION "STAT IRQ vector", ROM0[$048]
    ret

SECTION "Serial IRQ vector", ROM0[$058]
    inc d
    ret

SECTION "Joypad IRQ vector", ROM0[$060]
    ld d, $FE
    ret

SECTION "OAM info", ROM0[$3F00]
    REPT $3F9F - $3F00
        db 69
    ENDR

SECTION "DMA routine 1", ROM0[$3FA0] ; the DMA routine that checks if your DMA is instant
    ld a, $3F ; set OAM source addr to 0x3F00
    ld [$FF46], a
    ld a, [hl]
    cp a, $69
    JP Z, lock

    ld a, $28

oamDMADelay1:
    dec a
    jr nz, oamDMADelay1
    ret


Section "DMA routine 2", ROM0[$3FC0] ; checks if you've implemented bus conflicts
    ld a, $3F ; set OAM source addr to 0x3F00
    ld [$FF46], a
    ld hl, rSCX ; the CPU can't read from the main bus during a DMA.
               ; reading from rWX (which we previously set to $FF)
               ; should not return $FF, but the current value on the bus, which is, thank god, not $FF
    ld a, [hl]
    cp a, $FF 
    jp Z, lock

    ld a, $28

oamDMADelay2:
    dec a
    jr nz, oamDMADelay2
    ret