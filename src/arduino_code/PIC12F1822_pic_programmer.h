/*
 * Refer to datasheet on Memory Programming:
 *
 * PIC12(L)F1822/PIC16(L)F182X Memory Programming Specification
 * URL: http://ww1.microchip.com/downloads/en/DeviceDoc/41390D.pdf
 */

#pragma once

#include "./pic_programmer.h"
#include "./pic_memory.h"

// Address of the configuration memory
// loaded when issuing a loadConfig command
#define PIC12F1822_CONFIG_ADDR 0x8000

// Key sequence for low voltage
// programming mode.
#define KEY_SEQ    0x4D434850

// Length of command ids
#define CMD_ID_LEN 6

// Load configuration command
#define LD_CON_CMD 0x00

// Load commands
#define LD_PRO_CMD 0x02
#define LD_DAT_CMD 0x03

// Read command
#define RD_PRO_CMD 0x04
#define RD_DAT_CMD 0x05

// Program counter commands
#define INCR_A_CMD 0x06
#define REST_A_CMD 0x16

// Programming commands
#define BEG_IN_CMD 0x08
#define BEG_EX_CMD 0x18
#define END_EX_CMD 0x0A

// Bulk erase commands
#define ER_PRO_CMD 0x09
#define ER_DAT_CMD 0x0B
#define ER_ROW_CMD 0x11

class PIC12F1822_PicProgrammer : public PicProgrammer
{

public:
	PIC12F1822_PicProgrammer(unsigned int flags);

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

protected:
	// --------------- COMMAND HELPER FUNC ---------------- //

	virtual void commandEntry(unsigned int id) const;

	// --------------- LOAD CONFIG COMMAND ---------------- //

	virtual void commandLoadConfiguration(unsigned int data);

	// ---------------- LOAD DATA COMMANDS ---------------- //

	virtual void commandLoadProgramMemory(unsigned int data) const;
	virtual void commandLoadDataMemory(unsigned int data) const;

	// ---------------- READ DATA COMMANDS ---------------- //

	virtual int commandReadProgramMemory() const;
	virtual int commandReadDataMemory() const;

	// ------------- PROGRAM COUNTER COMMANDS ------------- //

	virtual void commandIncrementAddress();
	virtual void commandResetAddress();

	// --------------- PROGRAMMING COMMANDS --------------- //

	virtual void commandBeginInternalProgramming() const;
	virtual void commandBeginExternalProgramming() const;
	virtual void commandEndExternalProgramming() const;

	// -------------- ERASE MEMORY COMMANDS --------------- //

	virtual void commandBulkEraseProgramMemory() const;
	virtual void commandBulkEraseDataMemory() const;
	virtual void commandRowEraseProgramMemory() const;

	// ---------- PROGRAMMING HELPER FUNCTIONS ------------ //

	virtual long long getConfigAddress() const;

};
