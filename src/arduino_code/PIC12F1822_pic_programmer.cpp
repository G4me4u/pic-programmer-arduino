#include "./PIC12F1822_pic_programmer.h"

PIC12F1822_PicProgrammer::PIC12F1822_PicProgrammer(unsigned int flags) 
	: PicProgrammer(flags)
{ }

// --------------- PIC PROGRAMMER IMPL ---------------- //

bool PIC12F1822_PicProgrammer::enterProgrammingMode()
{
	// Handled externally
	//
	// // If we're already programming,
	// // return false.
	// if (this->programming)
	//     return false;

	// Set MCLR as output.
	pinMode(MCLR, OUTPUT);

	// Turn on the high voltage
	// on MCLR pin (see schematic).
	// Should be connected to approx.
	// one kilo-ohm pull-down resistor.
	digitalWrite(MCLR, HIGH);
	
	// In the case of low-voltage
	// MCLR is activated on the 
	// falling-edge.
	if (lowVoltageMode)
		digitalWrite(MCLR, LOW);
	
	// Wait for high voltage to charge
	delayMicroseconds(1);

	digitalWrite(PVCC, HIGH);
	delay(1);

	// If we're in low voltage programming
	// mode we have to send sequence key.
	if (lowVoltageMode) {
		PicSerial::writeMode();

		// Send 32-bit key-sequence + 1 extra
		// clock pulse to enter programming mode.
		PicSerial::writeBits(KEY_SEQ, 32 + 1);
		delay(1);
	}

	// We're now ready to program the device.
	this->programming = true;

	// Address is loaded as zero
	this->address = 0L;
	this->extendedAddress = 0;

	return true;
}

void PIC12F1822_PicProgrammer::leaveProgrammingMode()
{
	// Set all serial pins low
	digitalWrite(ICSPCLK, LOW);
	digitalWrite(ICSPDAT, LOW);

	// Set MCLR to a high impedance
	// input.
	pinMode(MCLR, INPUT);
  
	// Wait 1 millisecond for voltage
	// to discharge from circuit.
	delay(1);

	// Turn off V+
	digitalWrite(PVCC,    LOW);

	this->programming = false;
}

void PIC12F1822_PicProgrammer::beginReading() 
{
}

int PIC12F1822_PicProgrammer::readProgramWord()
{
	int data = this->commandReadProgramMemory();
	this->commandIncrementAddress();
	return data;
}

void PIC12F1822_PicProgrammer::endReading() 
{
}

void PIC12F1822_PicProgrammer::beginWriting()
{
}

void PIC12F1822_PicProgrammer::programWriteBuffer(unsigned char *const writeBuffer, unsigned int numBytes) 
{
	unsigned int data;
	unsigned int offset = 0;
	while (offset < numBytes) {
		data = PicMemory::bytesToUnsignedInt(writeBuffer, offset, numBytes, false);
		offset += 2;

		this->commandLoadProgramMemory(data);
		this->commandBeginInternalProgramming();
		this->commandIncrementAddress();
	}
}

void PIC12F1822_PicProgrammer::endWriting()
{
}

void PIC12F1822_PicProgrammer::setExtendedAddress(unsigned int extAddr)
{
	this->extendedAddress = extAddr;
	this->setAddress(0);
}

void PIC12F1822_PicProgrammer::setAddress(long long addr)
{
	// Each address is two bytes. Therefore we have
	// to divide byte-offset by two.
	addr += (EXTENDED_ADDRESS_BYTE_OFFSET / 2) * this->extendedAddress;

	// If it's possible to load config address, do so.
	if (addr >= this->getConfigAddress() && this->address < this->getConfigAddress()) {
		this->commandLoadConfiguration(-1);
	} else if (addr < this->address || this->address == -1L) {
		// We have to reset the address
		this->commandResetAddress();
	}

	// Increment address until we're at the
	// correct program-word.
	while (this->address != addr)
		this->commandIncrementAddress();
}

int PIC12F1822_PicProgrammer::readDeviceId()
{
	// Load address 8000h
	this->commandLoadConfiguration(-1);
	
	// Load device id at address 8006h
	this->commandIncrementAddress();
	this->commandIncrementAddress();
	this->commandIncrementAddress();
	this->commandIncrementAddress();
	this->commandIncrementAddress();
	this->commandIncrementAddress();

	// Read device id
	int dev_id = this->commandReadProgramMemory();
	if (dev_id == -1)
		return -1;

    // Discard revision bits (0:4)
	return dev_id >> 5;
}

void PIC12F1822_PicProgrammer::eraseDevice()
{
	this->commandLoadConfiguration(-1);
	this->commandBulkEraseProgramMemory();
}

// --------------- COMMAND HELPER FUNC ---------------- //

void PIC12F1822_PicProgrammer::commandEntry(unsigned int id) const
{
	PicSerial::writeMode();
	PicSerial::writeBits(id, CMD_ID_LEN);
}

// --------------- LOAD CONFIG COMMAND ---------------- //

void PIC12F1822_PicProgrammer::commandLoadConfiguration(unsigned int data)
{
	this->commandEntry(LD_CON_CMD);
	PicSerial::writeBit(0);
	PicSerial::writeBits(data, 14);
	PicSerial::writeBit(0);

	this->address = this->getConfigAddress();
}

// ---------------- LOAD DATA COMMANDS ---------------- //

void PIC12F1822_PicProgrammer::commandLoadProgramMemory(unsigned int data) const
{
	this->commandEntry(LD_PRO_CMD);
	PicSerial::writeBit(0);
	PicSerial::writeBits(data, 14);
	PicSerial::writeBit(0);
}

void PIC12F1822_PicProgrammer::commandLoadDataMemory(unsigned int data) const
{
	this->commandEntry(LD_DAT_CMD);
	PicSerial::writeBit(0);
	PicSerial::writeBits(data, 8);
	PicSerial::writeBits(0, 7);
}

// ---------------- READ DATA COMMANDS ---------------- //

int PIC12F1822_PicProgrammer::commandReadProgramMemory() const
{
	this->commandEntry(RD_PRO_CMD);

	PicSerial::readMode();

	PicSerial::readBit();
	int data = PicSerial::readBits(14);
	PicSerial::readBit();

	return data;
}

int PIC12F1822_PicProgrammer::commandReadDataMemory() const
{
	this->commandEntry(RD_DAT_CMD);

	PicSerial::readMode();

	PicSerial::readBit();
	int data = PicSerial::readBits(8);
	if (PicSerial::readBits(6))
	return -1;
	PicSerial::readBit();

	return data;
}

// ------------- PROGRAM COUNTER COMMANDS ------------- //

void PIC12F1822_PicProgrammer::commandIncrementAddress()
{
	this->commandEntry(INCR_A_CMD);

	this->address++;
}

void PIC12F1822_PicProgrammer::commandResetAddress()
{
	this->commandEntry(REST_A_CMD);

	this->address = 0;
}

// --------------- PROGRAMMING COMMANDS --------------- //

void PIC12F1822_PicProgrammer::commandBeginInternalProgramming() const
{
	this->commandEntry(BEG_IN_CMD);
	if (this->address >= this->getConfigAddress()) {
		delay(5);
	} else {
		delay(3);
	}
}

void PIC12F1822_PicProgrammer::commandBeginExternalProgramming() const
{
	this->commandEntry(BEG_EX_CMD);
	delay(1);
}

void PIC12F1822_PicProgrammer::commandEndExternalProgramming() const
{
	this->commandEntry(END_EX_CMD);
	delayMicroseconds(100);
}

// -------------- ERASE MEMORY COMMANDS --------------- //

void PIC12F1822_PicProgrammer::commandBulkEraseProgramMemory() const
{
	this->commandEntry(ER_PRO_CMD);
	delay(5);
}

void PIC12F1822_PicProgrammer::commandBulkEraseDataMemory() const
{
	this->commandEntry(ER_DAT_CMD);
	delay(5);
}

void PIC12F1822_PicProgrammer::commandRowEraseProgramMemory() const
{
	this->commandEntry(ER_ROW_CMD);
	delay(3);
}

// ---------- PROGRAMMING HELPER FUNCTIONS ------------ //

long long PIC12F1822_PicProgrammer::getConfigAddress() const 
{
	return PIC12F1822_CONFIG_ADDR;
}
