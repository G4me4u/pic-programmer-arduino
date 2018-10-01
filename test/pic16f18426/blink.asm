;*******************************************************************************
; 
;                                PIC16F18426
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

; PIC16F18426 Configuration Bit Settings

; Assembly source line config statements
LIST   P=PIC16F18426
#include "p16f18426.inc"

; CONFIG1
; __config 0x3FEC
 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINT1 & _CLKOUTEN_OFF & _CSWEN_ON & _FCMEN_ON
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _MCLRE_ON & _PWRTS_OFF & _LPBOREN_OFF & _BOREN_ON & _BORV_LO & _ZCDDIS_OFF & _PPS1WAY_ON & _STVREN_ON
; CONFIG3
; __config 0x3F9F
 __CONFIG _CONFIG3, _WDTCPS_WDTCPS_31 & _WDTE_OFF & _WDTCWS_WDTCWS_7 & _WDTCCS_SC
; CONFIG4
; __config 0x3FFF
 __CONFIG _CONFIG4, _BBSIZE_BB512 & _BBEN_OFF & _SAFEN_OFF & _WRTAPP_OFF & _WRTB_OFF & _WRTC_OFF & _WRTD_OFF & _WRTSAF_OFF & _LVP_ON
; CONFIG5
; __config 0x3FFF
 __CONFIG _CONFIG5, _CP_OFF



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
    BANKSEL PIR0
    bcf     PIR0, TMR0IF
    
    retfie

;*******************************************************************************
; MAIN PROGRAM
;*******************************************************************************

MAIN_PROG CODE                      ; let linker place main program

SETUP
    ; Set clock-source to internal 500 KHz
    BANKSEL OSCCON1
    ; We want to select the following:
    ;     NDIV bits <3:0>  as '0001' (set clock postscaler divider to 2)
    ;     NOSC bits <6:4>  as '110'  (use HFINTOSC 1 MHz from config)
    movlw   b'01100001'
    movwf   OSCCON1
    
    ; Set HTINTOSC to 1MHz
    BANKSEL OSCFRQ
    ; We want to select the following:
    ;     HFFRQ bits <2:0> as '000'  (set nominal frequency to 1MHz)
    movlw   b'00000000'
    movwf   OSCFRQ
 
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
    
    BANKSEL T0CON0
    ; Set TMR0 as an 8-bit timer
    bcf     T0CON0, T016BIT
    
    BANKSEL T0CON1
    ; Set source Fosc/4 (125 kHz)
    bsf     T0CON1, T0CS1
    ; Disable sync
    bsf     T0CON1, T0ASYNC
    ; Set prescaler to 256
    bsf     T0CON1, T0CKPS3

    BANKSEL T0CON0
    ; Enable Timer0
    bsf     T0CON0, T0EN
    
    ; Clear Timer0 interrupt flag
    BANKSEL PIR0
    bcf     PIR0, TMR0IF
    ; Enable Timer0 interrupt
    BANKSEL PIE0
    bsf     PIE0, TMR0IE
    
    BANKSEL INTCON
    ; Enable global interrupt
    bsf     INTCON, GIE
    
START
    ; Repeat forever
    goto    START

    END