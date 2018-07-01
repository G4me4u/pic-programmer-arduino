;*******************************************************************************
; 
;                                PIC16F1705
;                                ----------
;                            Vdd |1     14| Vss 
;                            RA5 |2     13| RA0/ICSPDAT
;                            RA4 |3     12| RA1/ICSPCLK
;                       MCLR/RA3 |4     11| RA2 
;                            RC5 |5     10| RC0 
;                            RC4 |6      9| RC1 
;                            RC3 |7      8| RC2 
;                                ---------- 
; 
;*******************************************************************************

; PIC16F1705 Configuration Bit Settings

; Assembly source line config statements
LIST   P=PIC16F1705
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
    ; Flip PORTA bits
    BANKSEL LATA
    movlw   b'11111111'
    xorwf   LATA, F
    
    ; Flip PORTC bits
    BANKSEL LATC
    movlw   b'11111111'
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
    ; Set clock-source to internal 500 KHz
    BANKSEL OSCCON
    ; We want to select the following:
    ;     SCS  bits <1:0> as '00'   (use INTOSC from config)
    ;     IRCF bits <6:3> as '0111' (use 500 KHz internal clock)
    ;     SPLL bit  <7>   as '0'    (software 4xPLL disabled)
    movlw   b'00111000'
    movwf   OSCCON
 
    ; Set PORTA as output
    BANKSEL TRISA
    clrf    TRISA
    BANKSEL PORTA
    clrf    PORTA
    
    ; Set PORTC as output
    BANKSEL TRISC
    clrf    TRISC
    BANKSEL PORTC
    clrf    PORTC
    
    BANKSEL OPTION_REG
    ; Select system-clock for
    ; use with Timer0
    bcf     OPTION_REG, TMR0CS
    ; Use prescaler for Timer0
    bcf     OPTION_REG, PSA
    ; Set prescaler to x256
    bsf     OPTION_REG, PS2
    bsf     OPTION_REG, PS1
    bsf     OPTION_REG, PS0

    ; Start Timer0 by clearing it
    BANKSEL TMR0
    clrf    TMR0
    
    BANKSEL INTCON
    ; Clear Timer0 interrupt flag
    bcf     INTCON, TMR0IF
    ; Enable Timer0 interrupt
    bsf     INTCON, TMR0IE
    ; Enable global interrupt
    bsf     INTCON, GIE
    
START
    ; Repeat forever
    goto    START

    END
