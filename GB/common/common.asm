include "hardware.inc"
include "font.asm"

SECTION "helpers", ROMX, BANK[1]

SaveRegisters: MACRO
               push af
               push bc
               push de
               push hl
               ENDM

RestoreRegisters: MACRO
                  pop hl
                  pop de
                  pop bc
                  pop af
                  ENDM

turnLCDOff:
    ld a, [rLY]
    cp $90 ; Check if the LCD is past VBlank
    jr nc, turnLCDOff

    xor a
    ld [rLCDC], a
    ret

turnLCDOn:
    ld a, %10000001
    ld [rLCDC], a
    ret
    
initFont:         ; wait till LCD is in VBlank to turn it off
                  ; All registers preserved   
    SaveRegisters
    call turnLCDOff
    call copyFont
    RestoreRegisters
    ret

copyFont:
    ld hl, $9000
    ld de, FontTiles
    ld bc, FontTilesEnd - FontTiles

copyFontLoop:
    ld a, [de] ; Grab 1 byte from the source
    ld [hl+], a ; Place it at the destination, incrementing hl
    inc de ; Move to next byte
    dec bc ; Decrement count
    ld a, b ; Check if count is 0, since `dec bc` does not update flags
    or c
    jr nz, copyFontLoop
    ret

copyString: ; params:   HL -> Tilemap address
            ;           DE -> Address of string 
    push af

copyStringLoop:
    ld a, [de]
    ld [hl+], a
    inc de
    and a ; Check if the byte we just copied is zero
    jr nz, copyStringLoop ; Continue if it is not

    pop af
    ret

