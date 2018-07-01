#include "./PIC16F88X_pic_programmer.h"

PIC16F88X_PicProgrammer::PIC16F88X_PicProgrammer(unsigned int flags) 
	: PIC12F1822_PicProgrammer(flags)
{ }

bool PIC16F88X_PicProgrammer::enterProgrammingMode() 
{
	// If we're already programming,
	// return false.
	if (this->programming)
		return false;

	// Set PGM high, if in low voltage mode
	if (lowVoltageMode) {
		digitalWrite(PGM, HIGH);
		delayMicroseconds(2);
	}

	// Set MCLR as output.
	pinMode(MCLR, OUTPUT);
	if (lowVoltageMode) {
		// MCLR is activated on the 
		// falling-edge.
		digitalWrite(MCLR, LOW);
		digitalWrite(MCLR, HIGH);
	} else {
		// Turn on the high voltage
		// on MCLR pin (see schematic).
		// Should be connected to approx.
		// one kilo-ohm pull-down resistor.
		digitalWrite(MCLR, HIGH);
	}
	delayMicroseconds(1);

	digitalWrite(PVCC, HIGH);
	delay(1);

	// We're now ready to program the device.
	this->programming = true;

	// Reset address to zero
	this->address = 0L;
	this->extendedAddress = 0;

	return true;
}

void PIC16F88X_PicProgrammer::leaveProgrammingMode()
{
	// We have to set the PGM pin
	// low (in low voltage mode)
	if (this->lowVoltageMode) {
		digitalWrite(PGM, LOW);
		// Wait for device to leave 
		// programming mode.
		delayMicroseconds(1);

		// If chip is in low voltage
		// programming mode, the MCLR
		// pin is most likely used. We
		// can reset the chip to ensure
		// proper code execution after
		// the programming finishes.
		if (this->programming) {
			digitalWrite(MCLR, LOW);
			digitalWrite(MCLR, HIGH);
		}
	}

	// We can use the same implementation
	// as the PIC12F1822.
	PIC12F1822_PicProgrammer::leaveProgrammingMode();
}

void PIC16F88X_PicProgrammer::commandResetAddress() 
{
	// The PIC16F88X specification does not
	// mention any reset command. To reset
	// the address we have to re-enter the 
	// programming mode instead.
	if (this->programming) {
		this->leaveProgrammingMode();
		this->enterProgrammingMode();
	}
}

// --------------- PROGRAMMING COMMANDS --------------- //

void PIC16F88X_PicProgrammer::commandBeginInternalProgramming() const
{
	this->commandEntry(BEG_IN_CMD);
	// The PIC16F88X specification only
	// takes 3 ms to program it's program-
	// memory. This is probably because
	// the configuration addresses are in
	// the low 2000h and not in the extended
	// range.
	delay(3);
}

// -------------- ERASE MEMORY COMMANDS --------------- //

void PIC16F88X_PicProgrammer::commandBulkEraseProgramMemory() const
{
	// All erase commands in the
	// PIC16F88X programming specification
	// take 6 ms (TERA) to complete.
	this->commandEntry(ER_PRO_CMD);
	delay(6);
}

void PIC16F88X_PicProgrammer::commandBulkEraseDataMemory() const
{
	// All erase commands in the
	// PIC16F88X programming specification
	// take 6 ms (TERA) to complete.
	this->commandEntry(ER_DAT_CMD);
	delay(6);
}

void PIC16F88X_PicProgrammer::commandRowEraseProgramMemory() const
{
	// All erase commands in the
	// PIC16F88X programming specification
	// take 6 ms (TERA) to complete.
	this->commandEntry(ER_ROW_CMD);
	delay(6);
}

// ---------- PROGRAMMING HELPER FUNCTIONS ------------ //

long long PIC16F88X_PicProgrammer::getConfigAddress() const
{
	return PIC16F88X_CONFIG_ADDR;
}
