#include "./PIC18F1XK22_pic_programmer.h"

PIC18F1XK22_PicProgrammer::PIC18F1XK22_PicProgrammer(unsigned int flags) 
	: PicProgrammer(flags)
{ }

bool PIC18F1XK22_PicProgrammer::enterProgrammingMode()
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
		// rising-edge.
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

	return true;
}

void PIC18F1XK22_PicProgrammer::leaveProgrammingMode()
{
	// Set all serial pins low
	digitalWrite(ICSPCLK, LOW);
	digitalWrite(ICSPDAT, LOW);

	// Set MCLR to a high impedance
	// input.
	pinMode(MCLR, INPUT);
	// Set PGM low (low voltage mode only)
	if (lowVoltageMode)
		digitalWrite(PGM, LOW);
  
	// Wait 1 millisecond for voltage
	// to discharge from circuit.
	delay(1);
	
	// Turn off V+
	digitalWrite(PVCC,    LOW);
	
	this->programming = false;
}

void PIC18F1XK22_PicProgrammer::beginReading()
{
}

int PIC18F1XK22_PicProgrammer::readProgramWord()
{
	// Address will be incremented when
	// reading.
	this->address++;
	return this->instructionTableReadPostIncrement();
}

void PIC18F1XK22_PicProgrammer::endReading()
{
}

void PIC18F1XK22_PicProgrammer::beginWriting()
{
	if (this->writing)
		return;
	
	this->writing = true;

	// Set write access (EEPGD, CFGS bits of EECON1)
	this->setWriteAccessAccordingly(this->address);
	
	// Enable writes
	this->instructionCore(0x84A6); // BSF EECON1, WREN
}

void PIC18F1XK22_PicProgrammer::programWriteBuffer(unsigned char *const writeBuffer, unsigned int numBytes)
{
	unsigned int data;
	unsigned int offset = 0;
	while (offset < numBytes) {
		bool configSpace = this->address >= this->getConfigAddress();
		if (configSpace) {
			// Write a single byte at a time.
			// Douplicate byte to MSB in operand.
			data = *(writeBuffer + offset);
			this->instructionTableWriteStartProg((data << 8) | data);
			offset++;
		} else {
			// Program two bytes at a time, little endian
			data = PicMemory::bytesToUnsignedInt(writeBuffer, offset, numBytes, false);
			this->instructionTableWriteStartProg(data);
			offset += 2;
		}
		
		// Refer to: 4.2 Flash Programming

		// Do 4 clock-pulses to start core 
		// instruction
		PicSerial::writeMode();
		PicSerial::writeBits(0x00, 3);

		// Refer to: 8.0 AC/DC Characteristics
	
		// Do last clock-pulse (hold 4th pulse 
		// high for time P9 and low for time P10).
		digitalWrite(ICSPDAT, LOW);
		digitalWrite(ICSPCLK, HIGH);
		// If we're in program-flash-space, 
		// we should sleep P9 or 1ms. If we're 
		// in config-space we should sleep P9A
		// or 5ms.
		if (this->address < this->getConfigAddress()) {
			delay(1);
		} else {
			delay(5);
		}
		digitalWrite(ICSPCLK, LOW);
		delayMicroseconds(100);

		// Finish NOP command with 16-bit 
		// operand. Refer to: Figure 4-5.
		PicSerial::writeMode();
		PicSerial::writeBits(0x0000, 16);

		// Increment address
		this->setDeviceAddress(configSpace ? (this->address + 1) : (this->address + 2));
	}
}

void PIC18F1XK22_PicProgrammer::endWriting()
{
	// Disable access to program flash
	this->instructionCore(0x9EA6); // BCF EECON1, EEPGD
	// Disable address to config bits
	this->instructionCore(0x9CA6); // BCF EECON1, CFGS
	// Disable writes
	this->instructionCore(0x94A6); // BCF EECON1, WREN
	
	this->writing = false;
}

void PIC18F1XK22_PicProgrammer::setExtendedAddress(unsigned int extAddr)
{
	this->extendedAddress = extAddr;
	this->setAddress(0);
}

void PIC18F1XK22_PicProgrammer::setAddress(long long addr)
{
	// Add extended address to addr
	addr += EXTENDED_ADDRESS_BYTE_OFFSET * this->extendedAddress;

	// Only change, if address isn't
	// already set to the specified.
	if (this->address != addr) {
		// If we're currently writing,
		// the access may have changed.
		if (this->writing) 
			this->setWriteAccessAccordingly(addr);

		this->setDeviceAddress(addr);
	}
}

int PIC18F1XK22_PicProgrammer::readDeviceId()
{
	// Refer to: Figure 3-3.

	// The Device ID bits of the 
	// PIC18F1XK22 devices are
	// located at the addresses: 
	//     3FFFFFh:3FFFFEh

	// Load address 3FFFFEh
	this->setDeviceAddress(0x3FFFFE);

	// Read low bits (without changing table pointer).
	int dev_id = this->instructionTableReadPostIncrement();
	// Read high bits (post decrement to restore table pointer).
	dev_id |= this->instructionTableReadPostDecrement() << 8;
	if (dev_id == -1)
		return -1;

	// Discard revision bits <0:4>
	return dev_id >> 5;
}

void PIC18F1XK22_PicProgrammer::eraseDevice()
{
	// Refer to: 4.1 ICSP Erase.

	// To do a Bulk Erase we have to
	// consider the voltage supplied
	// at VCC. When in Low voltage ICSP 
	// the device must be supplied
	// by a voltage greater than D111.
	// We're operating with a +5V 
	// supply. which falls within the 
	// D111 parameter.

	// For this reason we can do a
	// Bulk Erase. This will make it
	// possible to erase the entire
	// device by a single operation.

	// A Bulk Erase is controlled by
	// the two control registers:
	//     3C0005h:3C0004h
	// By setting these two control
	// registers to 0F8Fh, we can
	// erase the entire device.

	// First we must load the Bulk
	// Erase control registers.

	// Set Table Pointer to 3C0005.
	this->setDeviceAddress(0x3C0005);
	// Write to first register: 0F
	this->instructionTableWrite(0x0F0F);

	// Set Table Pointer to 3C0004.
	this->setDeviceAddress(0x3C0004);
	// Write to second register: 8F
	this->instructionTableWrite(0x8F8F);

	// Do two NOPS to start execution:
	this->instructionCore(0x0000); // NOP
	// The bulk erase function is
	// executed on the 4th clock:
	PicSerial::writeMode();
	PicSerial::writeBits(0x00, 4);

	// Refer to: 8.0 AC/DC Characteristics

	// Hold ICSPDAT low whilst erasing
	// (specified by P11, at least 5 ms)
	delay(5);

	// High voltage discharge time
	// (specified by P10, at least 100 us)
	delayMicroseconds(100);

	// Write the 16-bit operand to finish
	// the NOP core instruction.
	PicSerial::writeMode();
	PicSerial::writeBits(0x0000, 16);
}

// ------------- INSTRUCTION HELPER FUNC -------------- //

void PIC18F1XK22_PicProgrammer::instructionEntry(unsigned int id, unsigned int operand) const
{
  PicSerial::writeMode();
  PicSerial::writeBits(id, INSTR_ID_LEN);
  PicSerial::writeBits(operand, OPERAND_LEN);
}

int PIC18F1XK22_PicProgrammer::instructionReadEntry(unsigned int id) const
{
  PicSerial::writeMode();
  PicSerial::writeBits(id, INSTR_ID_LEN);
  PicSerial::writeBits(0x00, 8);
  PicSerial::readMode();
  return PicSerial::readBits(8);
}

// ----------------- CORE INSTRUCTION ----------------- //

void PIC18F1XK22_PicProgrammer::instructionCore(unsigned int operand) const
{
  this->instructionEntry(CORE_INSTR, operand);
}

// ------ SHIFT OUT TABLAT REGISTER INSTRUCTION ------- //

int PIC18F1XK22_PicProgrammer::instructionShiftTablat() const
{
  return this->instructionReadEntry(SHIFT_TABLAT);
}

// ------------- TABLE READ INSTRUCTIONS -------------- //

int PIC18F1XK22_PicProgrammer::instructionTableRead() const
{
  return this->instructionReadEntry(TAB_RD);
}

int PIC18F1XK22_PicProgrammer::instructionTableReadPostIncrement() const
{
  return this->instructionReadEntry(TAB_RD_POI);
}

int PIC18F1XK22_PicProgrammer::instructionTableReadPostDecrement() const
{
	return this->instructionReadEntry(TAB_RD_POD);
}

int PIC18F1XK22_PicProgrammer::instructionTableReadPreIncrement() const
{
	return this->instructionReadEntry(TAB_RD_PRI);
}

// ------------ TABLE WRITE INSTRUCTIONS -------------- //

void PIC18F1XK22_PicProgrammer::instructionTableWrite(unsigned int data) const
{
	this->instructionEntry(TAB_WR, data);
}

void PIC18F1XK22_PicProgrammer::instructionTableWritePostInc(unsigned int data) const
{
	this->instructionEntry(TAB_WR_PI, data);
}

void PIC18F1XK22_PicProgrammer::instructionTableWriteStartProgPostInc(unsigned int data) const
{
	this->instructionEntry(TAB_WR_SP_PI, data);
}

void PIC18F1XK22_PicProgrammer::instructionTableWriteStartProg(unsigned int data) const
{
	this->instructionEntry(TAB_WR_SP, data);
}

// ----------------- HELPER FUNCTIONS ----------------- //

void PIC18F1XK22_PicProgrammer::setDeviceAddress(long long addr) 
{
	// Dis-assemble the address parameter
	unsigned int addrU = (unsigned int)(addr >> 16) & 0xFF;
	unsigned int addrH = (unsigned int)(addr >>  8) & 0xFF;
	unsigned int addrL = (unsigned int)(addr >>  0) & 0xFF;

	// Load highest bits (addrU)
	this->instructionCore(0x0E00 | addrU); // MOVLW addrU
	this->instructionCore(0x6EF8);         // MOVWF TBLPTRU
	
	// Load middle bits (addrH)
	this->instructionCore(0x0E00 | addrH); // MOVLW addrH
	this->instructionCore(0x6EF7);         // MOVWF TBLPTRH

	// Load lowest bits (addrL)
	this->instructionCore(0x0E00 | addrL); // MOVLW addrL
	this->instructionCore(0x6EF6);         // MOVWF TBLPTRL

	// The address has been changed.
	this->address = addr;
}

void PIC18F1XK22_PicProgrammer::setWriteAccessAccordingly(long long address) 
{
	// Enable access to program flash
	this->instructionCore(0x8EA6); // BSF EECON1, EEPGD

	// Test if we're in config space
	if (address >= this->getConfigAddress()) {
		// Enable access to config bits
		this->instructionCore(0x8CA6); // BSF EECON1, CFGS
	} else {
		// Disable access to config bits
		this->instructionCore(0x9CA6); // BCF EECON1, CFGS
	}
}

long long PIC18F1XK22_PicProgrammer::getConfigAddress() const 
{
	// Refer to: Figure 3-3.
	return PIC18F1XK22_CONFIG_ADDR;
}
