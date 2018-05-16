;*******************************************************************************
; 
;                                ----------
;                            Vdd |1     14| Vss 
;                            RA5 |2     13| RA0 
;                            RA4 |3     12| RA1 
;                            RA3 |4     11| RA2 
;                            RC5 |5     10| RC0 
;                            RC4 |6      9| RC1 
;                            RC3 |7      8| RC2 
;                                ---------- 
; 
;*******************************************************************************

; PIC16F1705 Configuration Bit Settings

; Assembly source line config statements

#include "p16f1705.inc"

; CONFIG1
; __config 0xFFE4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_ON & _FCMEN_ON
; CONFIG2
; __config 0xFFFF
 __CONFIG _CONFIG2, _WRT_OFF & _PPS1WAY_ON & _ZCDDIS_ON & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON
    
;*******************************************************************************
; Reset Vector
;*******************************************************************************

RES_VECT  CODE    0x0000            ; processor reset vector
    goto    SETUP                   ; go to beginning of program

;*******************************************************************************
; Interrupt Vector
;*******************************************************************************

ISR       CODE    0x0004            ; interrupt vector location
    ; Set RC2 high
    BANKSEL LATC
    movlw   b'00000100'
    xorwf   LATC, F
    
    ; Clear interrupt flag
    BANKSEL INTCON
    bcf     INTCON, TMR0IF
    
    retfie

;*******************************************************************************
; MAIN PROGRAM
;*******************************************************************************

MAIN_PROG CODE                      ; let linker place main program

SETUP
    ; Set RC2 as output
    BANKSEL TRISC
    bcf     TRISC, RC2
    
    BANKSEL OPTION_REG
    bcf     OPTION_REG, TMR0CS
    bcf     OPTION_REG, PSA
    bsf     OPTION_REG, PS2
    bsf     OPTION_REG, PS1
    bsf     OPTION_REG, PS0

    BANKSEL TMR0
    clrf    TMR0
    
    BANKSEL INTCON
    bcf     INTCON, TMR0IF
    bsf     INTCON, TMR0IE
    bsf     INTCON, GIE
    
START
    ; Repeat forever
    goto    START

    END