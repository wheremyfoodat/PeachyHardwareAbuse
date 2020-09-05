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

    ld a, $FF ; Set NR11 to 255 for test 9
    ld [rNR11, a]

    ld hl, $8B80
    ld a, $C9   ; inject RET into VRAM for round 6
    ld [hl], a
    ld hl, $FE00
    ld [hl], a ; Write 0xC9 into OAM for round 7


round1:
    ld [rTMA], a
    call rTMA
    ld a, 1 ; if you made it back, you passed

round2:
    ld hl, $C000
    ld a, $1
    ld [hl], a

    ld a, $FF
    ld hl, $E000 ; check echo RAM works
    ld [hl], a
    
    ld hl, $C000
    ld a, [hl]
    cp a, $FF
    call z, TestSuccess
    call nz, TestFailure

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
    REPT 25
        db 0
    end

    ld a, [rSB]
    cp a, $0
    call z, TestFailure
    call z, round5 ; *THIS SKIPS TO ROUND 5 IF YOU FAIL, MAKE SURE TO ADJUST THE JUMP HOWEVER YOU WANT FOR THE GUI*

    REPT 512
        db 0 ; Wait 512 NOPs to make sure the interrupt has fired. MIGHT NEED CHANGING!
    end

checkSerialIRQ:
    ld a, d
    cp a, $1
    call nz, TestFailure
    call z, TestSuccess

round5:
    ld bc, $0000
    ld hl, $0000
    
writeToROM:          ; try to catch MBC bugs
    ld a, $69
    ld [hl+], a
    bit 7, h
    jp z, writeToROM

    ld a, [bc] ; check if a write went through
    cp a, $69

    jp z, TestFailure
    jp nz, TestSuccess

round6:               ; checks VRAM locking works
    call turnLCDOn

waitForLCDTransfer:
    ld a, [rSTAT]
    and a, $3
    cp a, $3
    jp nz, waitForLCDTransfer
    ld d, a

    ld hl, $8B80
    ld a, $16     ; Attempt to inject LD d, $69; RET into VRAM and jump into it
                  ; this should do nothing cause VRAM will be locked when this ISR occurs
    ld [hl+], a
    ld a, $69
    ld [hl+], a
    ld a, $C9
    ld [hl+], a

    call turnLCDOff
    call $8B80

    ld a, d
    cp a, $69
    call z, TestFailure
    call nz, TestSuccess

round7:         ; Make sure the PPU is unable to lock OAM on the first scanline after being enabled
    ld hl, $FE00
    call turnLCDOn
    ld a, [hl]
    ld c, a
    call turnLCDOff
    
    ld a, c
    cp a, $FF    ; The PPU fails to lock OAM in the first scanline after enabling the turnLCDOn
                ; hence this read should read the 0xC9 we injected at the start
    call z, TestFailure
    call nz, TestSuccess

round8:       ; Joypad interrupt!
    di
    ld a, %11011111
    ld [rP1], a
    ld a, %10000
    ld [rIE], a
    ei

    ld de, ButtonStr
    ld hl, $9800
    call copyString
    call turnLCDOn

pollJoypad:
    ld a, [rP1]
    and a, %1111
    cp a, %1111
    jp z, pollJoypad

    nop 
    nop

    ld a, $FE ; checks if the joypad IRQ occured
    cp a, d
    call z, TestSuccess
    call nz, TestFailure

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

round10:      ; POP timing (PUSH timing is pretty much the same thing so I don't test it out of laziness)
    ld sp, rDIV
    xor a
    ld [rDIV], a
    
    REPT 62  ; 62 NOPs
        db 0
    ENDR

    pop bc

    ld sp, $FFFC
    ld a, c
    cp $1
    call nz, TestFailure
    call z, TestSuccess

round11:     ; HALT bug
    di
    xor a
    ld [rTIMA], a
    ld [rIF], a

    ld a, %100
    ld [rIE], a
    inc a
    ld [rTAC], a

    db $76  ; opcode for HALT. The assembler automatically adds a NOP after the halt otherwise
    inc a 
    cp a, %110 
    call nz, TestFailure
    call nz, round12      ; THIS JUMPS OVER THE NEXT TEST IF YOU FAIL! MAKE SURE THIS IS WHAT YOU WANT

    REPT 60  ; 60 NOPs
        db 0
    ENDR

    db $76  ; opcode for HALT. The assembler automatically adds a NOP after the halt otherwise
    inc a   ; this should trigger the halt bug. therefore this instruction should be executed twice
    cp a, %1000 
    call nz, TestFailure
    call z, TestSuccess
    
    xor a
    ld [rIF], a

round12:     ; EI/DI
    di
    ld d, a
    ld a, %101
    ld [rIF], a

    ei ; Timer IRQs have been requested since round11
    di

    ld a, d
    cp $69
    call z, TestFailure
    call nz, TestSuccess

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

TestSuccess:
    ld a, $1
    ret 

TestFailure:
    ld a, $0
    ret

SuccessStr:
    db "You... You survived!                         Nice!", 0
FailureStr:
    db "Your emu suxxx lol", 0

ButtonStr:
    db "Press a button!", 0

SECTION "STAT IRQ vector", ROM0[$048]
    ret

SECTION "Timer IRQ vector", ROM0[$050]
    ld d, $69
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
    call z, TestFailure
    call nz, TestSuccess
    ld c, a

    ld a, $28

oamDMADelay1:
    dec a
    jr nz, oamDMADelay1
    ld a, c
    ret


Section "DMA routine 2", ROM0[$3FC0] ; checks if you've implemented bus conflicts
    ld hl, $C000
    ld a, $3F ; set OAM source addr to 0x3F00
    ld [hl], a
    ld [$FF46], a
    ld a, [hl]
    cp a, $3F ; this should cause a bus conflict and make it read the value on the bus instead of $3F
    call z, TestFailure
    jp z, Test12End

    ld a, [rNR11] ; This is an MMIO address, so accessing it shouldn't cause a bus conflict
    cp a, $FF 
    call nz, TestFailure
    call z, TestSuccess

Test12End:    
    ld a, $28

oamDMADelay2:
    dec a
    jr nz, oamDMADelay2
    ret