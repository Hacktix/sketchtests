include "src/inc/hardware.inc"

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

    ; Relocate SP
    ld sp, $cfff

    ; Initialize VRAM
    call InitFont

    ; Initialize VRAM offset and print title
    ld a, $02
    ld [$c300], a
    ld de, strTitle
    call PrintStringSerial
    call PrintStringGFX

    ; Add 'VRAM linebreak'
    ld hl, $c300
    inc [hl]
    inc [hl]

    ; Load DAA results into RAM ($C000 - $C0FF)
    ld hl, $c000
    xor a
.daaLoop
    ld b, a
    daa 
    ld [hli], a
    ld a, b
    inc a
    jr nz, .daaLoop

    ; Compare results
    ld hl, $c000
    ld de, ComparisonData
.comparisonLoop
    ld a, [de]
    xor [hl]
    jr z, .comparisonMatch
    ; On comparison mismatch
    call PrintFailSerial
    call PrintFailGFX
.comparisonMatch
    inc de
    inc hl
    ld a, l
    and a
    jr nz, .comparisonLoop

    ; Print test pass if OK
    ld a, [$c300]
    cp $06
    jr nz, .notPassed
    ld de, strPass
    call PrintStringSerial
    call PrintStringGFX
.notPassed

    ; Restart LCD
    ld a, %10000001
    ld [rLCDC], a

    jr @

;-------------------------------------------------------------------------
; Prints string pointed to by DE to the screen
;-------------------------------------------------------------------------
PrintStringGFX:
    ; Preserve HL
    push hl

    ; Calculate VRAM pointer with offset in $C300
    ld hl, $c300
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
; Prints a failure state to the screen
;-------------------------------------------------------------------------
PrintFailGFX:
    push bc
    push hl
    push de

    ld hl, $c400

    ; Print failed A value
    ld a, e
    call AtoASCII
    ld a, d
    ld [hli], a
    ld a, e
    ld [hli], a
    ld a, ":"
    ld [hli], a

    ; Print "Expected $"
    ld de, strFailExpected
    call CopyString

    ; Print expected value
    pop de
    ld a, [de]
    push de
    call AtoASCII
    ld a, d
    ld [hli], a
    ld a, e
    ld [hli], a

    ; Print string-ending null char
    xor a
    ld [hli], a

    ; Print to screen
    ld de, $c400
    call PrintStringGFX

    ; Print " got $"
    ld hl, $c400
    ld de, strFailGot
    call CopyString

    ; Print tested value
    ld b, h
    ld c, l
    pop de
    pop hl
    ld a, [hl]
    push hl
    push de
    ld h, b
    ld l, c
    call AtoASCII
    ld a, d
    ld [hli], a
    ld a, e
    ld [hli], a

    ; Print string-ending null char
    xor a
    ld [hli], a

    ; Print to screen
    ld de, $c400
    call PrintStringGFX

    pop de
    pop hl
    pop bc
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
; Prints a failure state to Serial
;-------------------------------------------------------------------------
PrintFailSerial:
    ld a, e
    call PrintStringA
    ld a, ":"
    ld [rSB], a
    push de
    ld de, strFailExpected
    call PrintStringSerial
    pop de
    ld a, [de]
    call PrintStringA
    push de
    ld de, strFailGot
    call PrintStringSerial
    pop de
    ld a, [hl]
    call PrintStringA
    ret

;-------------------------------------------------------------------------
; Converts value in A register to ASCII bytes, writes to RAM and
; loads pointer into DE
;-------------------------------------------------------------------------
PrintStringA:
    push af
    push bc
    push de
    push hl
    call AtoASCII
    ld hl, $c100
    ld a, d
    ld [hli], a
    ld a, e
    ld [hli], a
    xor a
    ld [hli], a
    ld de, $c100
    call PrintStringSerial
    pop hl
    pop de
    pop bc
    pop af
    ret

;-------------------------------------------------------------------------
; Converts value in A register to ASCII bytes, writes to RAM and
; loads pointer into DE
;-------------------------------------------------------------------------
AtoASCII:
    push hl
    push bc
    ld b, a
    call NibbleToASCII
    ld e, a
    ld a, b
    swap a
    call NibbleToASCII
    ld d, a
    pop bc
    pop hl
    ret

;-------------------------------------------------------------------------
; Converts the lower nibble of the value in A to an ASCII hex char
;-------------------------------------------------------------------------
NibbleToASCII:
    and $0f
    cp 10
    jr c, .digit
    add a, "A" - 10 - "0"
.digit
    add a, "0"
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

section "Comparison Data", rom0[$1000]
ComparisonData:
db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15
db $16, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25
db $26, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35
db $36, $31, $32, $33, $34, $35, $36, $37, $38, $39, $40, $41, $42, $43, $44, $45
db $46, $41, $42, $43, $44, $45, $46, $47, $48, $49, $50, $51, $52, $53, $54, $55
db $56, $51, $52, $53, $54, $55, $56, $57, $58, $59, $60, $61, $62, $63, $64, $65
db $66, $61, $62, $63, $64, $65, $66, $67, $68, $69, $70, $71, $72, $73, $74, $75
db $76, $71, $72, $73, $74, $75, $76, $77, $78, $79, $80, $81, $82, $83, $84, $85
db $86, $81, $82, $83, $84, $85, $86, $87, $88, $89, $90, $91, $92, $93, $94, $95
db $96, $91, $92, $93, $94, $95, $96, $97, $98, $99, $00, $01, $02, $03, $04, $05
db $06, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15
db $16, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25
db $26, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35
db $36, $31, $32, $33, $34, $35, $36, $37, $38, $39, $40, $41, $42, $43, $44, $45
db $46, $41, $42, $43, $44, $45, $46, $47, $48, $49, $50, $51, $52, $53, $54, $55
db $56, $51, $52, $53, $54, $55, $56, $57, $58, $59, $60, $61, $62, $63, $64, $65

section "Graphics", rom0
FontTiles:
incbin "src/inc/font.chr"
FontTilesEnd:

section "Strings", rom0
strTitle:
    db "daa.gb\n\n", 0
strPass:
    db "Test OK!", 0
strFailExpected:
    db "Expected $", 0
strFailGot:
    db " got $", 0