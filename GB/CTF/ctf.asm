include "hardware.inc"
include "common.asm"

Section "VBLANK ISR", ROM0[$40]
    ld hl, VblankCounter
    inc [hl]
    reti

Section "STAT ISR", ROM0[$48]
    ; Return colors to normal after title bar
    ld a, %11100100
    ld [rBGP], a
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

    ; Zero fill WRAM
    ld d, 0
    ld bc, $2000
    ld hl, $C000
    call Memset

    ld d, 0
    ld bc, 32
    ld hl, $FF80
    call Memset

    call TestScreen    

.lockup:
    jr .lockup

TestScreen:
    call turnLCDOff

    ld a, 30
    ld [AnimationTimer], a

    ld a, 1
    ld [AnimationFrame], a

    ld bc, $2000
    ld hl, $8000
    ld d, 0
    call Memset

    ; Copy in font
    ld bc, 128 * 16 ; 16 bytes per tile
    ld de, Font
    ld hl, $9000
    call Memcpy

    ; Copy in title
    ld de, Test
    ld hl, $9801
    call StrcpyNoNull

VRAMADDR SET $9841
    ld de, MemoryText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, LcdText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, TimerText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, DmaText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, ComText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, KeyInputText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40
    ld de, InterruptText
    ld hl, VRAMADDR
    call StrcpyNoNull
VRAMADDR SET VRAMADDR + $40

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

    ; Has a Vblank interrupt occurred?
    ld hl, VblankCounter
    ld a, [hl]
    ; Test if a is zero
    or a 
    ld a, 0
    ld [hl], a

    jr z, .rehalt

    ; Invert colors for title bar
    ld a, %00011011
    ld [rBGP], a

    ld hl, AnimationTimer
    dec [hl]
    ld a, [hl]

    jr nz, .rehalt

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

    jr .rehalt

.eraseText:
    ld d, 0
    ld bc, 16
    ld hl, $9A02
    call Memset

    jr .rehalt

SECTION "font", ROMX
Font: INCBIN "GB/CTF/ags-aging-font.chr"

SECTION "strings", ROMX
Test: db "DMG AGING CARTRIDGE",0
; Character $10 is right arrow
MemoryText:    db "MEMORY....OOO ",$10,"PASS",0
LcdText:       db "LCD.......OO  ",$10,"PASS",0
TimerText:     db "TIMER.....O   ",$10,"PASS",0
DmaText:       db "DMA.......OO  ",$10,"PASS",0
ComText:       db "COM.......O   ",$10,"PASS",0
KeyInputText:  db "KEY INPUT.O   ",$10,"PASS",0
InterruptText: db "INTERRUPT.-   ",0,$10,"PASS",0
PushStartText: db "PUSH START TO GO",0

CreditsText: 
db "CONTACT US\n"
db "Test Writer --------\n"
db "Discord:\n"
db " guccirodakino#1457\n"
db "Nintendo\n" 
db "Switch Online:\n"
db " SW-8356-6970-6111"
db "GUI Programmer -----\n"
db "Discord:\n" 
db " MLGxPwnentz#1728\n",0

SECTION "wram", WRAM0
AnimationTimer: db
AnimationFrame: db

SECTION "hram", HRAM
VblankCounter: db