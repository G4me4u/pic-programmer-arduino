;*******************************************************************************
; 
;                                 PIC16F883 
;                                ---------- 
;                       MCLR/RE3 |1     28| RB7/ICSPDAT 
;                            RA0 |2     27| RB6/ICSPCLK 
;                            RA1 |3     26| RB5 
;                            RA2 |4     25| RB4 
;                            RA3 |5     24| RB3/PGM 
;                            RA4 |6     23| RB2 
;                            RA5 |7     22| RB1 
;                            Vss |8     21| RB0 
;                            RA7 |9     20| Vdd 
;                            RA6 |10    19| Vss 
;                            RC0 |11    18| RC7 
;                            RC1 |12    17| RC6 
;                            RC2 |13    16| RC5 
;                            RC3 |14    15| RC4 
;                                ---------- 
; 
;*******************************************************************************

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements
LIST   P=PIC16F883
#include "p16f883.inc"

; CONFIG1
; __config 0xFFF4
 __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_ON
; CONFIG2
; __config 0xFFFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;*******************************************************************************
; Reset Vector
;*******************************************************************************

RES_VECT  CODE    0x0000            ; processor reset vector
    goto    SETUP                   ; go to beginning of program

;*******************************************************************************
; Interrupt Vector
;*******************************************************************************

ISR       CODE    0x0004            ; interrupt vector location
    ; Load WREG with 256
    ; for use with xor
    movlw   0xFF
       
    ; Flip PORTA bits
    BANKSEL PORTA
    xorwf   PORTA, F
    
    ; Flip PORTB bits
    BANKSEL PORTB
    xorwf   PORTB, F
       
    ; Flip PORTC bits
    BANKSEL PORTC
    xorwf   PORTC, F
    
    ; Flip PORTE bits
    BANKSEL PORTE
    xorwf   PORTE, F
    
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
    ;     SCS  bit  <0>   as '0'   (use INTOSC from config)
    ;     LTS  bit  <1>   as '0'   (use LFINTOSC is not stable)
    ;     HTS  bit  <2>   as '0'   (use HFINTOSC is not stable)
    ;     OSTS bit  <3>   as '1'   (device running from the internal oscillator)
    ;     IRCF bits <6:4> as '011' (use 500 KHz internal clock)
    movlw   b'00111000'
    movwf   OSCCON
 
    ; Set PORTA as output
    BANKSEL TRISA
    clrf    TRISA
    BANKSEL PORTA
    clrf    PORTA
    
    ; Set PORTB as output
    BANKSEL TRISB
    clrf    TRISB
    BANKSEL PORTB
    clrf    PORTB
    
    ; Set PORTC as output
    BANKSEL TRISC
    clrf    TRISC
    BANKSEL PORTC
    clrf    PORTC
    
    ; Set PORTE as output
    BANKSEL TRISE
    clrf    TRISE
    BANKSEL PORTE
    clrf    PORTE
    
    BANKSEL OPTION_REG
    ; Select system-clock for
    ; use with Timer0
    bcf     OPTION_REG, T0CS
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