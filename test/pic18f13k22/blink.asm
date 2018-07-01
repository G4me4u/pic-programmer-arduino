;*******************************************************************************
; 
;                                PIC18F13K22
;                                ----------
;                            Vdd |1     20| Vss 
;                            RA5 |2     19| RA0/PGD(ICSPDAT) 
;                            RA4 |3     18| RA1/PGC(ICSPCLK) 
;                       MCLR/RA3 |4     17| RA2 
;                            RC5 |5     16| RC0 
;                            RC4 |6     15| RC1 
;                        PGM/RC3 |7     14| RC2 
;                            RC6 |8     13| RB4 
;                            RC7 |9     12| RB5 
;                            RB7 |10    11| RB6 
;                                ---------- 
; 
;*******************************************************************************

; PIC18F13K22 Configuration Bit Settings

; Assembly source line config statements

#include "p18f13k22.inc"

; CONFIG1H
  CONFIG  FOSC = IRC            ; Oscillator Selection bits (Internal RC oscillator)
  CONFIG  PLLEN = ON            ; 4 X PLL Enable bit (Oscillator multiplied by 4)
  CONFIG  PCLKEN = ON           ; Primary Clock Enable bit (Primary clock enabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enable (Fail-Safe Clock Monitor disabled)
  CONFIG  IESO = OFF            ; Internal/External Oscillator Switchover bit (Oscillator Switchover mode disabled)

; CONFIG2L
  CONFIG  PWRTEN = OFF          ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  BOREN = SBORDIS       ; Brown-out Reset Enable bits (Brown-out Reset enabled in hardware only (SBOREN is disabled))
  CONFIG  BORV = 19             ; Brown Out Reset Voltage bits (VBOR set to 1.9 V nominal)

; CONFIG2H
  CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
  CONFIG  WDTPS = 32768         ; Watchdog Timer Postscale Select bits (1:32768)

; CONFIG3H
  CONFIG  HFOFST = ON           ; HFINTOSC Fast Start-up bit (HFINTOSC starts clocking the CPU without waiting for the oscillator to stablize.)
  CONFIG  MCLRE = ON            ; MCLR Pin Enable bit (MCLR pin enabled, RA3 input pin disabled)

; CONFIG4L
  CONFIG  STVREN = ON           ; Stack Full/Underflow Reset Enable bit (Stack full/underflow will cause Reset)
  CONFIG  LVP = ON              ; Single-Supply ICSP Enable bit (Single-Supply ICSP enabled)
  CONFIG  BBSIZ = OFF           ; Boot Block Size Select bit (512W boot block size)
  CONFIG  XINST = OFF           ; Extended Instruction Set Enable bit (Instruction set extension and Indexed Addressing mode disabled (Legacy mode))

; CONFIG5L
  CONFIG  CP0 = OFF             ; Code Protection bit (Block 0 not code-protected)
  CONFIG  CP1 = OFF             ; Code Protection bit (Block 1 not code-protected)

; CONFIG5H
  CONFIG  CPB = OFF             ; Boot Block Code Protection bit (Boot block not code-protected)
  CONFIG  CPD = OFF             ; Data EEPROM Code Protection bit (Data EEPROM not code-protected)

; CONFIG6L
  CONFIG  WRT0 = OFF            ; Write Protection bit (Block 0 not write-protected)
  CONFIG  WRT1 = OFF            ; Write Protection bit (Block 1 not write-protected)

; CONFIG6H
  CONFIG  WRTC = OFF            ; Configuration Register Write Protection bit (Configuration registers not write-protected)
  CONFIG  WRTB = OFF            ; Boot Block Write Protection bit (Boot block not write-protected)
  CONFIG  WRTD = OFF            ; Data EEPROM Write Protection bit (Data EEPROM not write-protected)

; CONFIG7L
  CONFIG  EBTR0 = OFF           ; Table Read Protection bit (Block 0 not protected from table reads executed in other blocks)
  CONFIG  EBTR1 = OFF           ; Table Read Protection bit (Block 1 not protected from table reads executed in other blocks)

; CONFIG7H
  CONFIG  EBTRB = OFF           ; Boot Block Table Read Protection bit (Boot block not protected from table reads executed in other blocks)

;*******************************************************************************
; Reset Vector
;*******************************************************************************

RES_VECT  CODE    0x0000            ; processor reset vector
    goto    SETUP                   ; go to beginning of program

;*******************************************************************************
; Interrupt Vector
;*******************************************************************************

ISR       CODE    0x0008            ; interrupt vector location
    ; Load WREG with 256
    ; for use with xor
    movlw   0xFF
       
    ; Flip PORTA bits
    BANKSEL LATA
    xorwf   LATA, F
    
    ; Flip PORTB bits
    BANKSEL LATB
    xorwf   LATB, F
       
    ; Flip PORTC bits
    BANKSEL LATC
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
    ;     SCS  bits <1:0> as '00'  (use INTOSC from config)
    ;     IRCF bits <6:4> as '010' (use 500 KHz internal clock)
    movlw   b'00100000'
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
    
    BANKSEL T0CON
    ; Select timer0 as 8-bit
    bsf     T0CON, T08BIT
    ; Select internal clock
    bcf     T0CON, T0CS
    ; Assign prescaler to Timer0
    bcf     T0CON, PSA
    ; Select prescaler x256
    bsf     T0CON, T0PS2
    bsf     T0CON, T0PS1
    bsf     T0CON, T0PS0
    
    ; Clear Timer0 for safety
    BANKSEL TMR0
    clrf    TMR0
    
    ; Enable Timer0
    BANKSEL T0CON
    bsf     T0CON, TMR0ON
    
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