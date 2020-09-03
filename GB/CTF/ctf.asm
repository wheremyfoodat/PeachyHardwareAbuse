include "hardware.inc"
include "common.asm"

Section "VBLANK ISR", ROM0[$40]
    ; Invert colors for title bar
    ld a, %00011011
    ld [rBGP], a
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

    xor a
    ld [rLCDC], a

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

.lockup:
    jr .lockup

SECTION "font", ROMX
Font: INCBIN "GB/CTF/ags-aging-font.chr"

SECTION "strings", ROMX
Test: db "DMG AGING CARTRIDGE",0
; Character $10 is right arrow
MemoryText:    db "MEMORY....OOOO",$10,"PASS",0
LcdText:       db "LCD.......OOOO",$10,"PASS",0
TimerText:     db "TIMER.....OOOO",$10,"PASS",0
DmaText:       db "DMA.......OOOO",$10,"PASS",0
ComText:       db "COM.......OOOO",$10,"PASS",0
KeyInputText:  db "KEY INPUT.OOOO",$10,"PASS",0
InterruptText: db "INTERRUPT.OOOO",$10,"PASS",0
PushStartText: db "PUSH START TO GO",0

SECTION "util", ROMX
; Copies until null terminator is hit, including the null terminator
; @param DE: Source Pointer
; @param HL: Destination Pointer
Strcpy:
    ld a, [de]
    ld [hl], a

    or a ; Check for null terminator
    ret z

    inc de
    inc hl
    
    jr Strcpy

; Copies until null terminator is hit, excluding the null terminator
; @param DE: Source Pointer
; @param HL: Destination Pointer
StrcpyNoNull:
    ld a, [de]

    or a ; Check for null terminator
    ret z

    ld [hl], a

    inc de
    inc hl
    
    jr StrcpyNoNull

; Copies memory
; @param BC: Bytes to copy
; @param DE: Source Pointer
; @param HL: Destination Pointer
Memcpy:
    ld a, [de]
    ld [hl], a

    inc de
    inc hl

    dec bc

    ld a, b
    or a
    jr nz, Memcpy
    ld a, c
    or a
    jr nz, Memcpy
    ret

; Sets a block of memory to a value
; BC: Bytes to copy
; HL: Pointer to destination
; D: Byte to set with
Memset:
    ld a, d
    ld [hl], a

    inc hl
    dec bc

    ld a, b
    or a
    jr nz, Memset
    ld a, c
    or a
    jr nz, Memset
    ret