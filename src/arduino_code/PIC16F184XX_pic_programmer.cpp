#include "./PIC16F184XX_pic_programmer.h"

PIC16F184XX_PicProgrammer::PIC16F184XX_PicProgrammer(unsigned int flags) 
	: PicProgrammer(flags)
{ }

bool PIC16F184XX_PicProgrammer::enterProgrammingMode()
{
	// Refer to PIC12F1822 pic programmer for more
	// information on entering programming mode.

	pinMode(MCLR, OUTPUT);

	digitalWrite(MCLR, HIGH);
	if (lowVoltageMode)
		digitalWrite(MCLR, LOW);
	delayMicroseconds(1);

	digitalWrite(PVCC, HIGH);
	delay(1);

	if (lowVoltageMode) {
		PicSerial::writeMode();
		
		PicSerial::writeBitsMSBF(PIC16_KEY_SEQ, 32);
		delay(1);
	}

	this->programming = true;

	this->address = 0L;
	this->extendedAddress = 0;

	return true;
}

void PIC16F184XX_PicProgrammer::leaveProgrammingMode()
{
	// Refer to PIC12F1822 pic programmer for more
	// information on leaving programming mode.

	digitalWrite(ICSPCLK, LOW);
	digitalWrite(ICSPDAT, LOW);

	pinMode(MCLR, INPUT);
  
	delay(1);

	digitalWrite(PVCC,    LOW);

	this->programming = false;
}

void PIC16F184XX_PicProgrammer::beginReading() 
{
}

int PIC16F184XX_PicProgrammer::readProgramWord()
{
	// Read word, post increment
	return this->commandReadIncrement();
}

void PIC16F184XX_PicProgrammer::endReading() 
{
}

void PIC16F184XX_PicProgrammer::beginWriting()
{
}

void PIC16F184XX_PicProgrammer::programWriteBuffer(unsigned char *const writeBuffer, unsigned int numBytes) 
{
	unsigned int data;
	unsigned int offset = 0;
	while (offset < numBytes) {
		data = PicMemory::bytesToUnsignedInt(writeBuffer, offset, numBytes, false);
		offset += 2;

		this->commandLoadProgramData(data);
		this->commandEntry(PIC16_BEG_INT_PRO);

		// Refer to datasheet: 2.5 Electrical Specifications
		// Table 2-3. Under row TPINT (Internally Timed 
		// Programming Operation Time) delay is 2.8ms when
		// in program memory space and 5.6ms when in config
		// space (rounded up to 3ms and 6ms).
		if (this->address >= PIC16F184XX_CONFIG_ADDR) {
			delay(6);
		} else {
			delay(3);
		}

		this->commandEntry(PIC16_INC_ADDR);
		this->address++;
	}
}

void PIC16F184XX_PicProgrammer::endWriting()
{
}

void PIC16F184XX_PicProgrammer::setExtendedAddress(unsigned int extAddr)
{
	this->extendedAddress = extAddr;
	this->setAddress(0);
}

void PIC16F184XX_PicProgrammer::setAddress(long long addr)
{
	// Each address is two bytes. Therefore we have
	// to divide byte-offset by two.
	addr += (EXTENDED_ADDRESS_BYTE_OFFSET / 2) * this->extendedAddress;

	// Increment address until we're at the
	// correct program-word.
	if (this->address != addr)
		this->commandLoadPCAddress((unsigned int)addr);
}

int PIC16F184XX_PicProgrammer::readDeviceId()
{
	// Load address 8006h
	this->commandLoadPCAddress(PIC16F184XX_DEV_ID_ADDR);

	// Read device id
	int dev_id = this->commandReadIncrement();
	if (dev_id == -1)
		return -1;

	return dev_id;
}

void PIC16F184XX_PicProgrammer::eraseDevice()
{
	// Issue bulk erase function
	this->commandEntry(PIC16_BULK_ERASE);

	// Refer to datasheet: 2.5 Electrical Specifications
	// Table 2-3. Under row TERAB (Bulk Erase Cycle Time)
	// delay is 8.4ms (rounded up to 9ms)
	delay(9);
}

// --------------- COMMAND HELPER FUNC ---------------- //	

void PIC16F184XX_PicProgrammer::commandEntry(unsigned int id) const
{
	PicSerial::writeMode();

	// All commands are most significant 
	// bit first. Hence we use the MSBF 
	// functions.
	PicSerial::writeBitsMSBF(id, PIC16_CMD_ID_LEN);
}

// ----------------- READ DATA COMMAND ---------------- //

int PIC16F184XX_PicProgrammer::commandReadIncrement()
{
	this->commandEntry(PIC16_RD_DAT_INC);
	
	PicSerial::readMode();

	// Read 24-bit payload (only bits <15:1> are used)
	PicSerial::readBitsMSBF(9);
	int data = PicSerial::readBitsMSBF(14);
	PicSerial::readBit();

	// This command is incrementing the pc
	this->address++;

	return data;
}

// ----------------- LOAD DATA COMMAND ---------------- //

void PIC16F184XX_PicProgrammer::commandLoadProgramData(unsigned int data) 
{
	this->commandEntry(PIC16_LD_DAT);

	// Write 24-bit payload
	PicSerial::writeBitsMSBF(0x00, 9);
	PicSerial::writeBitsMSBF(data, 14);
	PicSerial::writeBit(0);
}

// --------------- LOAD ADDRESS COMMAND --------------- //

void PIC16F184XX_PicProgrammer::commandLoadPCAddress(unsigned int addr) 
{
	this->commandEntry(PIC16_LD_PC_ADDR);

	// Write 24-bit payload
	PicSerial::writeBitsMSBF(0x00, 7);
	PicSerial::writeBitsMSBF(addr, 16);
	PicSerial::writeBit(0);

	this->address = addr;
}
