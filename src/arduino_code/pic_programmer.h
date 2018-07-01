#pragma once

#include "./pic_serial.h"

// The byte offset specified by 
// the extended address.
#define EXTENDED_ADDRESS_BYTE_OFFSET 0x10000L

class PicProgrammer 
{

public:
	bool programming;
	bool lowVoltageMode;

	long long address;
	unsigned int extendedAddress;

protected:
	PicProgrammer(unsigned int flags);

public:
	virtual ~PicProgrammer();

public:
	// Setup related functions
	virtual bool enterProgrammingMode() = 0;
	virtual void leaveProgrammingMode() = 0;

	// Read related functions
	virtual void beginReading() = 0;
	virtual int readProgramWord() = 0;
	virtual void endReading() = 0;

	// Write related functions
	virtual void beginWriting() = 0;
	virtual void programWriteBuffer(unsigned char *const writeBuffer, unsigned int numBytes) = 0;
	virtual void endWriting() = 0;

	// Address related functions
	virtual void setExtendedAddress(unsigned int extAddr) = 0;
	virtual void setAddress(long long addr) = 0;
	
	// Device related functions
	virtual int readDeviceId() = 0;
	virtual void eraseDevice() = 0;
};
