/*
 * Refer to datasheet on Flash Memory Programming:
 *
 * PIC18F1XK22/LF1XK22 Flash Memory Programming Specification
 * URL: http://ww1.microchip.com/downloads/en/DeviceDoc/41357B.pdf
 */

#pragma once

#include "pic_programmer.h"
#include "./pic_memory.h"

// Address of the configuration memory
#define PIC18F1XK22_CONFIG_ADDR 0x200000

// Length of instructions
#define INSTR_ID_LEN  4
#define OPERAND_LEN  16

// Core instruction
#define CORE_INSTR   0x00

// Shift out TABLAT register
#define SHIFT_TABLAT 0x02

// Table Read
#define TAB_RD       0x08
// Table Read, post-increment
#define TAB_RD_POI   0x09
// Table Read, post-decrement
#define TAB_RD_POD   0x0A
// Table Read, pre-increment
#define TAB_RD_PRI   0x0B

// Table Write
#define TAB_WR       0x0C
// Table Write, post-increment by 2
#define TAB_WR_PI    0x0D
// Table Write, start programming, post-increment by 2
#define TAB_WR_SP_PI 0x0E
// Table Write, start programming
#define TAB_WR_SP    0x0F

class PIC18F1XK22_PicProgrammer : public PicProgrammer
{
public:
	bool writing;

public:
	PIC18F1XK22_PicProgrammer(unsigned int flags);

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

	// ------------- INSTRUCTION HELPER FUNC -------------- //

	virtual void instructionEntry(unsigned int id, unsigned int operand) const;
	virtual int instructionReadEntry(unsigned int id) const;

	// ----------------- CORE INSTRUCTION ----------------- //

	virtual void instructionCore(unsigned int operand) const;

	// ------ SHIFT OUT TABLAT REGISTER INSTRUCTION ------- //

	virtual int instructionShiftTablat() const;

	// ------------- TABLE READ INSTRUCTIONS -------------- //

	virtual int instructionTableRead() const;
	virtual int instructionTableReadPostIncrement() const;
	virtual int instructionTableReadPostDecrement() const;
	virtual int instructionTableReadPreIncrement() const;

	// ------------ TABLE WRITE INSTRUCTIONS -------------- //

	virtual void instructionTableWrite(unsigned int data) const;
	virtual void instructionTableWritePostInc(unsigned int data) const;
	virtual void instructionTableWriteStartProgPostInc(unsigned int data) const;
	virtual void instructionTableWriteStartProg(unsigned int data) const;

	// ----------------- HELPER FUNCTIONS ----------------- //

	virtual void setDeviceAddress(long long addr);
	virtual void setWriteAccessAccordingly(long long address);
	virtual long long getConfigAddress() const;

};
