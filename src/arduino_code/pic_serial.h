#pragma once

#include <Arduino.h>

#include "./constants.h"

// ----------------- SERIAL PROTOCOLS ----------------- //

class PicSerial 
{

public:

	static void readMode() 
	{
		// Changed the data-pin to an
		// input.
		pinMode(ICSPDAT, INPUT);
	}

	static void writeMode() 
	{
		// Changes the data-pin to an
		// output. Default LOW.
		pinMode(ICSPDAT, OUTPUT);
		digitalWrite(ICSPDAT, LOW);
	}

	static void writeBits(unsigned long data, unsigned int n) 
	{
		// Write bits in LSb first
		while (n--) {
			writeBit(data & 0x1);
			data >>= 1;
		}
	}

	static void writeBitsMSBF(unsigned long data, unsigned int n) 
	{
		while (n--)
			writeBit((data >> n) & 0x1);
	}

	static void writeBit(bool data) 
	{
		// A bit is written by first
		// setting the data pin high or low
		// and sending a pulse on the clk
		// pin. data-pin is set low after
		// to make sure it's low by default.

		digitalWrite(ICSPDAT, data ? HIGH : LOW);
		delayMicroseconds(1);
		digitalWrite(ICSPCLK, HIGH);
		delayMicroseconds(1);
		digitalWrite(ICSPCLK,  LOW);
		delayMicroseconds(1);
		digitalWrite(ICSPDAT, LOW);
	}

	static unsigned int readBits(unsigned int n) 
	{
		// Read all bits. The number of
		// bits to read is specified by
		// the n argument. All bits are
		// read with the LSb first. the
		// maximum number of bits this
		// function can read is 16 bits.

		// To change the number of bits
		// that can be read change data
		// to an unsigned long as well
		// as the return type.
		unsigned int data = 0;
		
		unsigned int i = 0;
		while (i < n)
			data |= readBit() << i++;
		
		return data;
	}

	static unsigned int readBitsMSBF(unsigned int n) 
	{
		unsigned int data = 0;

		while (n--) {
			data <<= 1;
			data |= readBit();
		}

		return data;
	}

	static unsigned int readBit() 
	{
		// Reading a bit is a lot like
		// writing a bit, except the data
		// pin is now an input. The clk
		// pin is still timed externally.
		digitalWrite(ICSPCLK, HIGH);
		delayMicroseconds(1);
		unsigned int data = digitalRead(ICSPDAT);
		delayMicroseconds(1);
		digitalWrite(ICSPCLK, LOW);
		delayMicroseconds(1);
		return data ? 1 : 0;
	}

	private:
		// PicSerial is a static class.
		PicSerial() { };
};
