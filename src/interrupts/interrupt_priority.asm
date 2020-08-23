include "src/inc/hardware.inc"

section "Interrupt Handlers", rom0[$40]
rept 5
    ; Write low byte of interrupt vector to HL++
    ld a, low(@)
    ld [hli], a
    reti
    ds 4, $FF
endr

section "Header", rom0[$100]
	di
	jp EntryPoint

section "Main Code", rom0[$150]
EntryPoint:
    ; Wait for VBlank
    ld de, $0000
.waitVblank
    inc de
    ld a, d
    cp $50
    jr z, .vblankTimeout
    ld a, [$ff41]
    and $03
    jr nz, .waitVblank
.vblankTimeout

    ; Disable LCD
    xor a
    ld [rLCDC], a

    ; Initialize VRAM
    call InitFont

    ; Initialize RAM (first 256 bytes)
    ld de, $C000
    ld a, $68         ; Not a valid interrupt handler address, for "no interrupt occurred"
.ramInit
    ld [de], a
    inc e
    jr nz, .ramInit

    ; Init VRAM offset and print test title
    ld a, $02
    ld [$c010], a
    ld de, strTitle
    call PrintStringSerial
    call PrintStringGFX

    ; Add 'VRAM linebreak'
    ld hl, $c010
    inc [hl]
    inc [hl]

    ; Enable and queue all interrupts
    ld a, $FF
    ld [rIE], a
    ld [rIF], a

    ; Initialize HL and RAM
    ld hl, $C000

    ; Enable interrupts wait, then disable
    ei 
    nop
    di

    ; Initialize registers for comparison
    ld bc, $4000
    ld hl, $C000

    ; Compare values
.compareLoop
    ld a, [hli]
    cp b
    jr z, .skipFail
    ; Comparison Mismatch
    ld c, b
    call PrintFailSerial
    call PrintFailGFX
.skipFail
    ld a, b
    add $08
    cp $68
    jr z, .breakCompare
    ld b, a
    jr .compareLoop
.breakCompare

    ; Check if any comparison failed
    ld a, c
    and a
    jr nz, .skipPrintSuccess
    ; If C register is zero - passed test
    ld de, strPass
    call PrintStringSerial
    call PrintStringGFX
.skipPrintSuccess

    ; Disallow and clear all interrupts
    xor a
    ld [rIE], a
    ld [rIF], a

    ; Restart LCD
    ld a, %10000001
    ld [rLCDC], a

	jr @

;-------------------------------------------------------------------------
; Prints failure message for interrupt to the screen
;-------------------------------------------------------------------------
PrintFailGFX:
    ; Preserve registers
    push af
    push bc
    push hl

    ; Initialize type string offset
    ld a, c
    sub $40
    ld c, a

    ; Load RAM string pointer
    ld hl, $c020

    ; Load "Expected " into RAM
    ld de, strFailExpected
    call CopyString

    ; Load interrupt type string into RAM
    ld de, strIntTypes
    ld a, e
    add c
    ld e, a
    ld a, d
    adc $00
    ld d, a
    call CopyString

    ; Load string ending null char into RAM
    xor a
    ld [hl], a

    ; Print "Expected" line
    ld de, $c020
    call PrintStringGFX

    ; Load RAM string pointer
    ld hl, $c020

    ; Load "Got " into RAM
    ld de, strFailGot
    call CopyString

    ; Load tested interrupt type string into RAM
    push hl
    ld hl, sp+2
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    ld h, d
    ld l, e
    ld de, strIntTypes
    dec hl
    ld a, [hli]
    pop hl
    sub $40
    add e
    ld e, a
    ld a, d
    adc $00
    ld d, a
    call CopyString

    ; Load string ending null char into RAM
    xor a
    ld [hl], a

    ; Print "Got" line
    ld de, $c020
    call PrintStringGFX

    ; Restore registers
    pop hl
    pop bc
    pop af

    ret

;-------------------------------------------------------------------------
; Loads a string pointed to by DE to memory starting at HL
;-------------------------------------------------------------------------
CopyString:
    ld a, [de]
    and a
    ret z
    ld [hli], a
    inc de
    jr CopyString

;-------------------------------------------------------------------------
; Prints string pointed to by DE to the screen
;-------------------------------------------------------------------------
PrintStringGFX:
    ; Preserve HL
    push hl

    ; Calculate VRAM pointer with offset in $C010
    ld hl, $c010
    ld a, [hl]
    swap a
    and $0F
    jr z, .noOverflow
    ; If overflow to H
    push bc
    ld b, a
    ld a, [hl]
    swap a
    and $F0
    inc [hl]
    inc [hl]
    ld hl, $9801
    add l
    ld l, a
    ld a, b
    add h
    ld h, a
    pop bc
    jr .writeString
.noOverflow
    ld a, [hl]
    swap a
    and $F0
    inc [hl]
    inc [hl]
    ld hl, $9801
    add l
    ld l, a

.writeString
    ld a, [de]
    and a
    jr z, .finishWrite
    ld [hli], a
    inc de
    jr .writeString

.finishWrite
    pop hl
    ret

;-------------------------------------------------------------------------
; Loads font tiles into VRAM
;-------------------------------------------------------------------------
InitFont:
    ld hl, $9000
    ld de, FontTiles
    ld bc, FontTilesEnd - FontTiles
.copyFont
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyFont
    ret

;-------------------------------------------------------------------------
; Prints failure message for interrupt to serial port
;-------------------------------------------------------------------------
PrintFailSerial:
    ; Preserve registers
    push af
    push bc
    push de

    ; Initialize type string offset
    ld a, c
    sub $40
    ld c, a

    ; Print "Expected "
    ld de, strFailExpected
    call PrintStringSerial

    ; Print expected interrupt type
    ld de, strIntTypes
    ld a, e
    add c
    ld e, a
    ld a, d
    adc $00
    ld d, a
    call PrintStringSerial

    ; Print " got "
    ld de, strFailGot
    call PrintStringSerial

    ; Print tested interrupt type
    ld de, strIntTypes
    dec hl
    ld a, [hli]
    sub $40
    add e
    ld e, a
    ld a, d
    adc $00
    ld d, a
    call PrintStringSerial

    ; Print linebreak
    ld a, "\n"
    ld [rSB], a

    ; Restore registers
    pop de
    pop bc
    pop af

    ret

;-------------------------------------------------------------------------
; Prints string pointed to by DE to serial port
;-------------------------------------------------------------------------
PrintStringSerial:
    push de

.writeString
    ld a, [de]
    and a
    jr z, .finishWrite
    ld [rSB], a
    inc de
    jr .writeString

.finishWrite
    pop de
    ret

section "Graphics", rom0
FontTiles:
incbin "src/inc/font.chr"
FontTilesEnd:

section "Strings", rom0
strTitle:
    db "interrupt_priority\n\n", 0
strPass:
    db "Test OK!", 0
strFailExpected:
    db "Expected ", 0
strFailGot:
    db " got ", 0
strIntTypes:
    ; Include padding so each string is 8 bytes
    db "VBlank", 0
    ds 8 - ((@ - strIntTypes) % 8), 0
    db "STAT", 0
    ds 8 - ((@ - strIntTypes) % 8), 0
    db "Timer", 0
    ds 8 - ((@ - strIntTypes) % 8), 0
    db "Serial", 0
    ds 8 - ((@ - strIntTypes) % 8), 0
    db "Joypad", 0
    ds 8 - ((@ - strIntTypes) % 8), 0
    db "None", 0
    ds 8 - ((@ - strIntTypes) % 8), 0