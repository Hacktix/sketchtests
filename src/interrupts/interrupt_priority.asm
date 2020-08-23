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

    ; Print test title to serial
    ld de, strTitle
    call PrintStringSerial

    ; Initialize RAM (first 256 bytes)
    ld de, $C000
    ld a, $68         ; Not a valid interrupt handler address, for "no interrupt occurred"
.ramInit
    ld [de], a
    inc e
    jr nz, .ramInit

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
.skipPrintSuccess

	jr @

;-------------------------------------------------------------------------
; Prints failure message for interrupt to serial port
;-------------------------------------------------------------------------
PrintFailSerial:
    ; Preserve registers
    push af
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
    pop af

    ret

;-------------------------------------------------------------------------
; Prints string pointed to by DE to serial port
;-------------------------------------------------------------------------
PrintStringSerial:
    ld a, [de]
    and a
    ret z
    ld [rSB], a
    inc de
    jr PrintStringSerial

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