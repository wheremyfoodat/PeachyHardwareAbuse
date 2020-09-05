include "hardware.inc"
include "common.asm"
include "GB/CTF/tests.asm"

Section "VBLANK ISR", ROM0[$40]
    ld a, %00000001
    reti

Section "STAT ISR", ROM0[$48]
    ; Return colors to normal after title bar
    ld a, %11100100
    ld [rBGP], a
    ld a, %00000010
    reti

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

    call turnLCDOff

    ; Zero fill WRAM
    ld d, 0
    ld bc, $2000
    ld hl, $C000
    call Memset

    ld d, 0
    ld bc, 32
    ld hl, $FF80
    call Memset

    ; Copy in font
    ld bc, 128 * 16 ; 16 bytes per tile
    ld de, Font
    ld hl, $9000
    call Memcpy

    jp TestScreen    

.lockup:
    jr .lockup

TestScreen:
    call turnLCDOff

    ld a, 30
    ld [AnimationTimer], a

    ld a, 1
    ld [AnimationFrame], a

    ; Erase tilemap
    ld bc, 1024
    ld hl, $9800
    ld d, 0
    call Memset

    ; Copy in title
    ld de, Test
    ld hl, $9801
    call StrcpyNoNull

    ld de, TestListText
    ld hl, $9840
    call StrcpyNoNullTilemapSmart

    ld de, PushStartText
    ld hl, $9A02
    call StrcpyNoNull

    ld a, %11100100
    ld [rBGP], a
    
    ld a, LCDCF_BGON | LCDCF_ON | LCDCF_BG8800 | LCDCF_BG9800
    ld [rLCDC], a

    ei
    ld a, IEF_LCDC | IEF_VBLANK
    ld [rIE], a

    ld a, STATF_LYC
    ld [rSTAT], a

    ; Use LY=LYC STAT interrupt for resetting colors after the title bar
    ld a, 8
    ld [rLYC], a

    call RunTests

.rehalt
    halt 
    
    ; Check unHALTing source
    and a, %00000001
    jr z, .rehalt

    jr z, .continue

    ; Invert colors for title bar
    ld a, %00011011
    ld [rBGP], a

    ld hl, AnimationTimer
    dec [hl]
    ld a, [hl]

    jr nz, .continue

    ; if the animation timer is zero

    ld a, 30
    ld [hl], a

    ld hl, AnimationFrame
    ld a, [hl]
    xor a, 1 ; Toggle bit 0
    ld [hl], a

    jr z, .eraseText

    ; Copy text

    ld de, PushStartText
    ld hl, $9A02
    call StrcpyNoNull

    jr .continue

.eraseText:
    ld d, 0
    ld bc, 16
    ld hl, $9A02
    call Memset

.continue:
    ld a, [LastJoypad]
    ld c, a
    
    call PollJoypad

    and a, %10000000 ; Check for START
    jr nz, .rehalt

    ld a, c
    and a, %10000000 ; Make sure it's a START rising edge
    jr z, .rehalt

    jp CreditsScreen

    jr .rehalt

CreditsScreen:
    call turnLCDOff

    ; Erase tilemap
    ld bc, 1024
    ld hl, $9800
    ld d, 0
    call Memset
    
    ld de, CreditsText
    ld hl, $9800
    call StrcpyNoNullTilemapSmart

    ld de, StartGoBackText
    ld hl, $9A01
    call StrcpyNoNull

    ld a, LCDCF_BGON | LCDCF_ON | LCDCF_BG8800 | LCDCF_BG9800
    ld [rLCDC], a

.rehalt
    halt 

    ; Check unHALTing source
    and a, %00000001
    jr z, .rehalt

    ; Invert colors for title bar
    ld a, %00011011
    ld [rBGP], a

    ld a, [LastJoypad]
    ld c, a
    
    call PollJoypad

    and a, %10000000 ; Check for START
    jr nz, .rehalt

    ld a, c
    and a, %10000000 ; Make sure it's a START rising edge
    jr z, .rehalt

    jp TestScreen

    jr .rehalt

; Polls the joypad
; @return A: joypad status 
; @destroys A B H L
; 7 - Start
; 6 - Select
; 5 - Button B
; 4 - Button A
; 3 - Down
; 2 - Up
; 1 - Left
; 0 - Right
PollJoypad:
    ld hl, rP1

    ; Put buttons in upper nibble of b
    ld a, P1F_GET_BTN
    ld [hl], a
    ld a, [hl]
    and $0F
    ld b, a
    swap b

    ld a, P1F_GET_DPAD
    ld [hl], a
    ld a, [hl]
    and $0F
    or a, b

    ldh [LastJoypad], a

    ret

RunTests:
    xor a
    ld [CurrentTestNumber], a

.nextTest:
    ld a, [CurrentTestNumber]
    ld c, a
    call DispatchTestNumber
    ; Test returns success value in a, back that up.
    ld d, a
    ld a, [CurrentTestNumber]
    ld c, a
    ld a, d
    call SetTestNumberSuccess
    
    ld hl, CurrentTestNumber
    ld a, [hl]
    inc a
    ld [hl], a

    cp TestCount
    jr nz, .nextTest

    ret

; Dispatches a test.
; Ends with JP HL, test is required to execute RET
; @param c - Test number 0-127
; @returns a - 1 for success, 0 for failure
; @trashes c
DispatchTestNumber:
    ld b, 0

    ; Puts the VRAM address in BC
    sla c
    ld hl, TestTable
    add hl, bc
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a

    ld h, b
    ld l, c

    jp hl

; Sets a test success value on the screen
; @param a - 1 for success, 0 for failure
; @param c - Test number 0-127
SetTestNumberSuccess:
    ld d, a

    ld b, 0

    ; Puts the VRAM address in BC
    sla c
    ld hl, SymbolVramTable
    add hl, bc
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a

.loop:
    ld a, [rLY]
    cp $90 ; Check if the LCD is past VBlank
    jr nz, .loop

    ld a, d

    ; Check if A is 0
    and a
    jp z, .zero

    ld a, "O"
    ld [bc], a
    ret
.zero:
    ld a, "X"
    ld [bc], a
    ret


TestCount EQU 11
TestTable:
    dw round1  ; 0 - MEMORY
    dw round2  ; 1 - MEMORY
    dw round5  ; 2 - MEMORY
    dw round10 ; 3 - MEMORY
    dw round6  ; 4 - LCD
    dw round7  ; 5 - LCD
    dw round3  ; 6 - DMA
    dw round9  ; 7 - DMA
    dw round4  ; 8 - COM
    dw round11 ; 9 - INTERRUPT
    dw round12 ; A - INTERRUPT

SymbolVramTable: 
    dw $984B ; dw round1 ; MEMORY
    dw $984C ; dw round2 ; MEMORY
    dw $984D ; dw round5 ; MEMORY
    dw $984E ; dw round10 ; MEMORY
    dw $988B ; dw round6 ; LCD
    dw $988C ; dw round7 ; LCD
    dw $990B ; dw round3 ; DMA
    dw $990C ; dw round9 ; DMA
    dw $994B ; dw round4 ; COM
    dw $99CB ; dw round11 ; INTERRUPT
    dw $99CC ; dw round12 ; INTERRUPT

SECTION "font", ROMX
Font: INCBIN "GB/CTF/ags-aging-font.chr"

SECTION "UIStrings", ROMX
Test: db "DMG AGING CARTRIDGE",0
TestListText:
db " MEMORY....----\n"
db "\n"
db " LCD.......--\n"
db "\n"
db " TIMER.....\n"
db "\n"
db " DMA.......--\n"
db "\n"
db " COM.......-\n"
db "\n"
db " KEY INPUT.\n"
db "\n"
db " INTERRUPT.--\n",0
PushStartText: db "PUSH START TO GO",0

CHARMAP "→", $10
PassText: db "→PASS",0
FailText: db "→FAIL",0 

; $04,$05,$06: Start button 
StartGoBackText: db $04,$05,$06," Go Back",0

CreditsText: 
CHARMAP "─", $1C
CHARMAP "┤", $0B
CHARMAP "├", $09
CHARMAP "┌", $1E
CHARMAP "└", $08
CHARMAP "┐", $1F
CHARMAP "┘", $07
CHARMAP "│", $1D

db " CONTACT US\n"
db "┌──────────────┐\n"
db "┤GUI Programmer├───────\n"
db "└──────────────┘\n"
db "Discord:\n" 
db " MLGxPwnentz#1728\n"
db "┌───────────┐\n"
db "┤Test Writer├───────\n"
db "└───────────┘\n"
db "Discord:\n"
db " guccirodakino#1457\n"
db "Nintendo Switch:\n"
db " SW-8356-6970-6111\n",0

SECTION "wram", WRAM0
AnimationTimer: db
AnimationFrame: db
CurrentTestNumber: db

SECTION "hram", HRAM
LastJoypad: db

