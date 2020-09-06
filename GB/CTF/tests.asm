SECTION "Tests", ROM0
InitTests:
    di
    ld sp, $FFFC

    ; init video (enable LCD later)
    call initFont    
    ld a, %11100100
    ld [rBGP], a

    ret

round1:
    ld a, $C9 ; RET
    ld [rTMA], a
    call rTMA

    ; if you made it back, you passed
    jp TestSuccess

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
    jp z, TestSuccess
    jp TestFailure

round3:               ; make sure DMA is not instant
    call turnLCDOff

    ld hl, $FF80
    ld bc, OAMDMARoutine1

.copyOAMDMARoutine1:    
    ld a, [bc]
    ld [hl+], a
    inc bc
    cp a, $C9
    jp nz, .copyOAMDMARoutine1

    ld hl, $FE9F
    xor a
    ld [hl], a ; store 0 into last OAM byte

    call $FF80 ; go to OAM handling routine

    push af
    call turnLCDOn
    pop af

    cp a, $69

    jp z, TestFailure
    jp nz, TestSuccess

round4:           ; How is your serial port doing?
    ld a, [rIE]
    ld [IEBackup], a

    xor a
    ld d, a
    ld [rSB], a ; set data to be transferred (0)
    ld a, %00000 ; Enable no interrupts, we're just gonna check IF
    ld [rIE],   a ; final blow: Enable serial IRQ
    ld [rIF],   a
    ei            ; This is getting fucking mean

    ld a, %10000001
    ld [rSC], a ; enable transfer with internal clock

.pollSB:

    ld a, 32
.wait ; Each iteration of this loop takes 4M
    dec a        ; 1M
    jr nz, .wait ; 3M with branch

    ld a, [rSB]
    cp a, $0
    jp z, .restoreIeAndFail
    
.checkSerialIRQ:

    ld a, 255
.waitAgain ; Each iteration of this loop takes 4M
    dec a        ; 1M
    jr nz, .waitAgain ; 3M with branch

    ld hl, rIF
    bit 3, [hl]
    jp z, .restoreIeAndFail

.restoreIeAndSucceed
    ld a, [IEBackup]
    ld [rIE], a

    jp TestSuccess

.restoreIeAndFail:
    ld a, [IEBackup]
    ld [rIE], a

    jp TestFailure

round5:
    ld bc, $0000
    ld hl, $0000
    
.writeToROM:          ; try to catch MBC bugs
    ld a, $69
    ld [hl+], a
    bit 7, h
    jp z, .writeToROM

    ld a, [bc] ; check if a write went through
    cp a, $69

    jp z, TestFailure
    jp TestSuccess

round6:               ; checks VRAM locking works
    call turnLCDOff

    ld a, $C9   ; inject RET into VRAM for round 6
    ld hl, $8B80
    ld [hl], a

    call turnLCDOn

.waitForLCDTransfer:
    ld a, [rSTAT]
    and a, $3
    cp a, $3
    jp nz, .waitForLCDTransfer
    ld d, a

    ld hl, $8B80
    ld a, $16     ; Attempt to inject LD d, $69; RET into VRAM and jump into it
                  ; this should do nothing cause VRAM will be locked when this code executes
    ld [hl+], a
    ld a, $69
    ld [hl+], a
    ld a, $C9
    ld [hl+], a

    call turnLCDOff
    call $8B80

    ld a, d
    cp a, $69

    call turnLCDOn

    jp z, TestFailure
    jp TestSuccess

round7:         ; Make sure the PPU is unable to lock OAM on the first scanline after being enabled
    call turnLCDOff

    ld a, $C9 
    ld hl, $FE00
    ld [hl], a ; Write 0xC9 into OAM for round 7

    ld hl, $FE00
    call turnLCDOn
    ld a, [hl]
    ld c, a
    call turnLCDOff
    
    ld a, c
    cp a, $FF    ; The PPU fails to lock OAM in the first scanline after enabling the turnLCDOn
                ; hence this read should read the 0xC9 we injected at the start

    call turnLCDOn

    jp z, TestFailure
    jp nz, TestSuccess

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

.pollJoypad:
    ld a, [rP1]
    and a, %1111
    cp a, %1111
    jp z, .pollJoypad

    nop 
    nop

    ld a, $FE ; checks if the joypad IRQ occured
    cp a, d
    jp z, TestSuccess
    jp nz, TestFailure


round9:          ; DMA bus conflicts!
    call turnLCDOff

    ld a, $FF ; Set NR11 to 255 for test 9
    ld [rNR11], a

    ld hl, $FF80
    ld bc, OAMDMARoutine2

.copyOAMDMARoutine2:    
    ld a, [bc]
    ld [hl+], a
    inc bc
    cp a, $C9
    jp nz, .copyOAMDMARoutine2

    jp $FF80

round10:      ; POP timing (PUSH timing is pretty much the same thing so I don't test it out of laziness)
    ld [SPBackup], sp

    ld sp, rDIV
    xor a
    ld [rDIV], a
    
    REPT 62  ; 62 NOPs
        db 0
    ENDR

    pop de

    ld hl, SPBackup
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a

    ld h, b
    ld l, c
    
    ld sp, hl
    
    ld a, e
    cp $1

    jp nz, TestFailure
    jp TestSuccess

round11:     ; HALT bug
    ld a, [rIE]
    ld [IEBackup], a

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

    ld a, [IEBackup]
    ld [rIE], a

    jp nz, TestFailure
    jp z, TestSuccess
    
round12:     ; EI/DI
    xor a
    ld [rIF], a

    di
    ld d, a
    ld a, %100
    ld [rIF], a

    ei ; Timer IRQs have been requested since round11
    di

    ei

    ld a, d
    cp $69
    jp z, TestFailure
    jp nz, TestSuccess

; print results
    ld hl, $9800
    call Success
    call copyString

    call turnLCDOn

round13: ; MMIO_exec_1 by Peach
    di

    ld [rDIV], a ; Reset DIV to initialize timer

    ld a, $C9
    ld [rTMA], a ; store opcode for RET into TMA
    ld a, $39    
    ld [rTIMA], a
    ld a, %101
    ld [rTAC], a

    xor a
    call rTIMA ; TIMA should increment to 0x3C / inc a just in time.

    ei
    
    cp a, $1
    jp Z, TestSuccess
    jp NZ, TestFailure

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

SECTION "SP Backup lol", WRAM0
SPBackup: dw
IEBackup: db

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
        db $69
    ENDR

SECTION "DMA routine 1", ROM0[$3FA0] 
; the DMA routine that checks if your DMA is instant
; @return a Correct if a = $69
OAMDMARoutine1:
    ld a, $3F ; set OAM source addr to 0x3F00
    ld [$FF46], a
    ld a, [hl] ; hl = $FE9F

    ld c, a

    ld a, $28

.oamDMADelay1:
    dec a
    jr nz, .oamDMADelay1

    ld a, c
    ret

Section "DMA routine 2", ROM0[$3FC0] ; checks if you've implemented bus conflicts
OAMDMARoutine2:
    ld hl, $C000
    ld a, $3F ; set OAM source addr to 0x3F00
    ld [hl], a
    ld [$FF46], a
    nop
    ld a, [hl] ; this should cause a bus conflict and make it read the value on the bus instead of $3F
    cp a, $3F
    jr z, .endFail
    ; cp a, $69 ; also check the bus conflict value to be correct
    ; jr nz, .endFail

    jr .endSucc

    ld a, [rNR11] ; This is an MMIO address, so accessing it shouldn't cause a bus conflict
    cp a, $FF
    jr nz, .endFail
    jr z, .endSucc

.endSucc:
    ld c, 1
    jr .Test12End

.endFail:
    ld c, 0

.Test12End:    
    ld a, $28

.oamDMADelay2:
    dec a
    jr nz, .oamDMADelay2

    call turnLCDOn
    ld a, c

    ret