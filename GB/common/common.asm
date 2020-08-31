include "hardware.inc"
include "font.asm"

SECTION "helpers", ROMX, BANK[1]

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
    
initFont:         ; wait till LCD its in VBlank to turn it off
                  ; All registers preserved   
    push af
    push bc
    push de
    push hl

    call turnLCDOff
    call copyFont

    pop af
    pop bc
    pop de
    pop hl
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
    jr nz, copyStringLoop ; Continue if it's not

    pop af
    ret