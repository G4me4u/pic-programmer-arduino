/*
 * Refer to datasheet on Memory Programming:
 *
 * PIC16(L)F184XX Memory Programming Specification
 * URL: http://ww1.microchip.com/downloads/en/DeviceDoc/PIC16(L)F184XX%20Programming_DS40001970A.pdf
 */

#pragma once

#include "./pic_programmer.h"
#include "./pic_memory.h"

// The 32-bit key sequence sent when
// entering low voltage programming mode.
#define PIC16_KEY_SEQ 0x4D434850

// Device config space address
#define PIC16F184XX_CONFIG_ADDR 0x8000
// Device id address
#define PIC16F184XX_DEV_ID_ADDR 0x8006

// Length / size of command ids in bits
#define PIC16_CMD_ID_LEN 8

// Read data, post increment command
#define PIC16_RD_DAT_INC 0xFE
// Load data command
#define PIC16_LD_DAT 0x00

// Load program counter address command
#define PIC16_LD_PC_ADDR 0x80
// Increment address command
#define PIC16_INC_ADDR 0xF8

// Begin internal programming command
#define PIC16_BEG_INT_PRO 0xE0
// Bulk erase device command
#define PIC16_BULK_ERASE 0x18

class PIC16F184XX_PicProgrammer : public PicProgrammer 
{

public:
	PIC16F184XX_PicProgrammer(unsigned int flags);

	// --------------- PIC PROGRAMMER IMPL ---------------- //
	
	// Setup related functions
	virtual bool enterProgrammingMode();
	virtual void leaveProgrammingMode();

	// Read related functions
	virtual void beginReading();
	virtual int readProgramWord();
	virtual void endReading();

	// Write related functions
	virtual void beginWriting();
	virtual void programWriteBuffer(unsigned char *const writeBuffer, unsigned int numBytes);
	virtual void endWriting();

	// Address related functions
	virtual void setExtendedAddress(unsigned int extAddr);
	virtual void setAddress(long long addr);
	
	// Device related functions
	virtual int readDeviceId();
	virtual void eraseDevice();

private:
	// --------------- COMMAND HELPER FUNC ---------------- //
	
	void commandEntry(unsigned int id) const;
	
	// ----------------- READ DATA COMMAND ---------------- //

	int commandReadIncrement();

	// ----------------- LOAD DATA COMMAND ---------------- //

	void commandLoadProgramData(unsigned int data);

	// --------------- LOAD ADDRESS COMMAND --------------- //

	void commandLoadPCAddress(unsigned long addr);

};