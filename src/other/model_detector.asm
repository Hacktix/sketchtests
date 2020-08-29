include "src/inc/hardware.inc"
;-------------------------------------------------------------------------
; NOTE: This ROM must be assembled with CGB and SGB support
;       options enabled!
;-------------------------------------------------------------------------
; # $C000 - Test Result
;  - $00 : Unknown Model
;  - $01 : DMG
;  - $02 : MGB (currently also SGB2)
;  - $03 : SGB
;  - $04 : SGB2
;  - $05 : CGB
;  - $06 : AGB/AGS
;-------------------------------------------------------------------------

section "Header", rom0[$100]
	di
	jp EntryPoint

section "Main Code", rom0[$150]
EntryPoint:
    ; Preserve Flags
    push af

    ; Check for A = $01
    cp $01
    jr nz, .accNot01
    ; If not jumped, can only be DMG or SGB

    ; Check equal values
    ld a, b                ; Check if B = $00
    and a
    jp nz, .unknownModel
    ld a, d                ; Check if D = $00
    and a
    jp nz, .unknownModel

    ; Check for DMG
    ld a, c                ; Check if C = $13
    cp $13
    jr nz, .notDMG
    ld a, e                ; Check if D = $D3
    cp $d8
    jr nz, .notDMG
    ld a, h                ; Check if H = $01
    cp $01
    jr nz, .notDMG
    ld a, l                ; Check if L = $4D
    cp $4d
    jr nz, .notDMG
    pop de                 ; Check initial flags (F = $B0)
    push de
    ld a, e
    cp $b0
    jr nz, .notDMG
    ld a, $01
    ld [$c000], a
    jp DisplayResults

.notDMG
    ; Check for SGB
    ld a, c                ; Check if C = $14
    cp $14
    jp nz, .unknownModel
    ld a, e                ; Check if E = $00
    and a
    jp nz, .unknownModel
    ld a, h                ; Check if H = $C0
    cp $C0
    jp nz, .unknownModel
    ld a, l                ; Check if L = $60
    cp $60
    jp nz, .unknownModel
    pop de                 ; Check initial flags (F = $00)
    push de
    ld a, e
    cp $00
    jr nz, .unknownModel
    ld a, $03
    ld [$c000], a
    jp DisplayResults

.accNot01

    ; Check for A = $FF
    cp $FF
    jr nz, .accNotFF
    ; If not jumped, can only be MGB or SGB2

    ; TODO: Detect difference between SGB2 and MGB
    ld a, $02
    ld [$c000], a
    jp DisplayResults

.accNotFF

    ; Check for A = $11
    cp $11
    jp nz, .unknownModel
    ; If not jumped, can only be CGB, AGB or AGS

    ; Check common values
    ld a, c                ; Check if C = $00
    and a
    jp nz, .unknownModel
    ld a, d                ; Check if D = $FF
    cp $FF
    jp nz, .unknownModel
    ld a, e                ; Check if E = $56
    cp $56
    jp nz, .unknownModel
    ld a, h                ; Check if H = $00
    and a
    jp nz, .unknownModel
    ld a, l                ; Check if L = $0D
    cp $0d
    jp nz, .unknownModel

    ; Check for CGB
    ld a, b                ; Check if B = $00
    and a
    jr nz, .notCGB
    pop de                 ; Check initial flags (F = $80)
    push de
    ld a, e
    cp $80
    jr nz, .notCGB
    ld a, $05
    ld [$c000], a
    jp DisplayResults

.notCGB
    ; Check for AGB/AGS
    ld a, b                ; Check if B = $01
    cp a, $01
    jr nz, .unknownModel
    pop de                 ; Check initial flags (F = $00)
    push de
    ld a, e
    and a
    jr nz, .unknownModel
    ld a, $06
    ld [$c000], a
    jp DisplayResults

.unknownModel
    ld a, $00
    ld [$c000], a
    jp DisplayResults

;-------------------------------------------------------------------------
; Prints string pointed to by DE to the screen
;-------------------------------------------------------------------------
DisplayResults:
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

    ; Initialize VRAM offset and print title
    ld a, $02
    ld [$c100], a
    ld de, strTitle
    call PrintStringSerial
    call PrintStringGFX

    ; Add 'VRAM linebreak'
    ld hl, $c100
    inc [hl]
    inc [hl]

    ; Load model string pointer
    ld de, strModels
    ld a, [$c000]
    and a
    jr z, .skipModelLoop
    ld b, a
.modelLoop
    ld a, 12
    add e
    ld e, a
    ld a, d
    adc $00
    ld d, a
    dec b
    jr nz, .modelLoop
.skipModelLoop

    ; Print model string
    call PrintStringSerial
    call PrintStringGFX

    ; Load DMG-BGP
    ld a, %11100100
    ld [rBGP], a

    ; Load CGB Palettes
    ld a, $80
    ld [rBCPS], a
    ld a, $FF
    ld b, $06
.cgbPaletteLoop
    ld [rBCPD], a
    dec b
    jr nz, .cgbPaletteLoop
    xor a
    ld [rBCPD], a
    ld [rBCPD], a

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

    ; Calculate VRAM pointer with offset in $C100
    ld hl, $c100
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

section "Graphics", rom0
FontTiles:
incbin "src/inc/font.chr"
FontTilesEnd:

section "Strings", rom0[$1000]
strTitle:
    db "model_detector\n\n", 0
strModels:
    ; Include padding so each string is 12 bytes
    db "Unknown", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "DMG", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "MGB/SGB2", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "SGB", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "SGB2", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "CGB", 0
    ds 12 - ((@ - strModels) % 12), 0
    db "AGB/AGS", 0
    ds 12 - ((@ - strModels) % 12), 0