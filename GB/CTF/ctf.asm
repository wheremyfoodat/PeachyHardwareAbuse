include "hardware.inc"
include "common.asm"

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

SECTION "font", ROMX
Font: INCBIN "GB/CTF/ags-aging-font.chr"

SECTION "strings", ROMX
Test: db "DMG AGING CARTRIDGE",0
TestListText:
db " MEMORY....---\n"
db "\n"
db " LCD.......--\n"
db "\n"
db " TIMER.....-\n"
db "\n"
db " DMA.......--\n"
db "\n"
db " COM.......-\n"
db "\n"
db " KEY INPUT.-\n"
db "\n"
db " INTERRUPT.-\n",0
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
db "┌───────────┐\n"
db "┤Test Writer├───────\n"
db "└───────────┘\n"
db "Discord:\n"
db " guccirodakino#1457\n"
db "Nintendo Switch:\n"
db " SW-8356-6970-6111\n"
db "┌──────────────┐\n"
db "┤GUI Programmer├───────\n"
db "└──────────────┘\n"
db "Discord:\n" 
db " MLGxPwnentz#1728\n",0

SECTION "wram", WRAM0
AnimationTimer: db
AnimationFrame: db

SECTION "hram", HRAM
LastJoypad: db

