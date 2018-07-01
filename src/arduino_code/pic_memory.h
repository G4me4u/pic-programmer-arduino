#pragma once

#include <Arduino.h>

// ----------------- SERIAL PROTOCOLS ----------------- //

class PicMemory
{

public:

	static unsigned int bytesToUnsignedInt(unsigned char *const data, unsigned int offset, unsigned int numBytes, bool bigEndian) 
	{
		unsigned char b0 = PicMemory::getByte(data, offset, numBytes);
		unsigned char b1 = PicMemory::getByte(data, offset + 1, numBytes);
		
		if (bigEndian)
			return (b0 << 8) | b1;
		return (b1 << 8) | b0;
	}

	static unsigned char getByte(unsigned char *const data, unsigned int offset, unsigned int numBytes) 
	{
		if (offset >= numBytes)
			return (char)0xFF;
		return *(data + offset);
	}

private:
	// PicSerial is a static class.
	PicMemory() { };
};