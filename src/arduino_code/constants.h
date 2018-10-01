#pragma once

// Pins used for programming
// and serial communication.
#define MCLR       2
#define ICSPCLK    3
#define ICSPDAT    4
#define PVCC       5
#define PGM        6

#define TRANSFER_BAUDRATE 115200
// The number of bytes available
// in the write buffer for programming.
#define WRITE_BUFFER_SIZE 32

// Flags sent by the transmitter to 
// the Arduino.
#define LOW_VOLTAGE_PROGRAMMING_MASK  0x80

#define PIC12F1822_SPECIFICATION  0x00
#define PIC18F1XK22_SPECIFICATION 0x01
#define PIC16F88X_SPECIFICATION   0x02
#define PIC16F184XX_SPECIFICATION 0x03

// Flags sent by the Arduino to the
// transmitter.
#define TWO_BYTES_PER_ADDRESS     0x01
