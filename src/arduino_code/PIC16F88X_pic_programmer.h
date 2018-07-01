/*
 * The specification for this programming module is a lot
 * like the PIC12F1822 flash programming. The biggest difference
 * is the level of the MCLR pin and the missing command to reset
 * the address counter. All other functionality can be used directly.
 * 
 * Refer to datasheet on Memory Programming:
 *
 * PIC16(L)F88X Memory Programming Specification
 * URL: http://ww1.microchip.com/downloads/en/DeviceDoc/41287D.pdf
 */

#include "./PIC12F1822_pic_programmer.h"

#define PIC16F88X_CONFIG_ADDR 0x2000

class PIC16F88X_PicProgrammer : public PIC12F1822_PicProgrammer 
{

public:
	PIC16F88X_PicProgrammer(unsigned int flags);

	// --------------- PIC PROGRAMMER IMPL ---------------- //

	// MCLR is on rising edge + handle PGM
	virtual bool enterProgrammingMode();
	// Handle PGM pin
	virtual void leaveProgrammingMode();
	
protected:
	// ------------- PROGRAM COUNTER COMMANDS ------------- //

	// Re-implement the reset address function
	virtual void commandResetAddress();
	
	// --------------- PROGRAMMING COMMANDS --------------- //

	// Change the delay of the internal programming
	virtual void commandBeginInternalProgramming() const;

	// -------------- ERASE MEMORY COMMANDS --------------- //

	// Erase cycles take 6 ms instead of 5 and 3
	virtual void commandBulkEraseProgramMemory() const;
	virtual void commandBulkEraseDataMemory() const;
	virtual void commandRowEraseProgramMemory() const;

	// ---------- PROGRAMMING HELPER FUNCTIONS ------------ //

	// The config address is located at 2000h instead of 8000h
	virtual long long getConfigAddress() const;

};