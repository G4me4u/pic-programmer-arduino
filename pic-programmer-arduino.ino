// Pins used for programming
// and serial communication.
#define MCLR       2
#define ICSPCLK    3
#define ICSPDAT    4
#define PVCC       5

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

// Supported devices
#define PIC12F1822 0x0138

void setup() {
  pinMode(MCLR,    OUTPUT);
  pinMode(PVCC,    OUTPUT);
  pinMode(ICSPCLK, OUTPUT);

  digitalWrite(MCLR,    HIGH);
  digitalWrite(PVCC,    LOW);
  digitalWrite(ICSPCLK, LOW);

  Serial.begin(9600);
}

void loop() {  
  // Commands:
  //  
  // Address related commands:
  // b - begin programming
  // s - stop programming
  
  // i - increment address
  // z - reset addres to zero

  // e - erase program memory

  // l - load program memory
  // r - read program memory
  // w - write program memory

  if (Serial.available() > 0) {
    if (doCommand(Serial.read())) {
      Serial.println("d");
    } else {
      Serial.println("f");
    }
  }
}

bool doCommand(char command) {
  int dev_id;
  
  switch(command) {
  case 'b':
    enterProgrammingMode();
    dev_id = readDeviceId();
    if (dev_id == -1)
      Serial.println("Unable to connect to device!");
  
    switch (dev_id) {
    case PIC12F1822:
      Serial.println("Connected to device: PIC12F1822");
      return true;
    default:
      Serial.println("Unexpected device id: " + String(dev_id, HEX));
      return false;
    }
  case 's':
    leaveProgrammingMode();
    return true;
  
  case 'e':
    commandBulkEraseProgramMemory();
    return true;
  case 't':
    commandBulkEraseDataMemory();
    return true;
    
  case 'i':
    commandIncrementAddress();
    return true;
  case 'z':
    commandResetAddress();
    return true;

  case 'w':
    commandBeginInternalProgramming();
    return true;
  case 'p':
    commandLoadProgramMemory(readArgument(2));
    return true;
  case 'd':
    commandLoadDataMemory(readArgument(2));
    return true;

  case 'c':
    commandLoadConfiguration(readArgument(2));
    return true;
    
  case 'r':
    Serial.println(String(commandReadProgramMemory(), HEX));
    return true;
  }

  return false;
}

unsigned int readArgument(unsigned int num) {
  unsigned int r = 0;
  while (num > 0) {
    while (Serial.available() == 0);
    r |= Serial.read() << (--num << 3);
  }
  return r;
}

int readDeviceId() 
{
  // Go to address 8000h (data is
  // not being programmed).
  commandLoadConfiguration(-1);

  // Go to address 8006h
  commandIncrementAddress(); // 01
  commandIncrementAddress(); // 02
  commandIncrementAddress(); // 03
  commandIncrementAddress(); // 04
  commandIncrementAddress(); // 05
  commandIncrementAddress(); // 06

  int dev_id = commandReadProgramMemory();
  if (dev_id == -1) // Unable to read device
    return -1;

  // Discard revision bits (0:4)
  return dev_id >> 5;
}

void commandEntry(unsigned int id) {
  writeMode();
  writeBits(id, CMD_ID_LEN);
}

// --------------- LOAD CONFIG COMMAND ---------------- //

void commandLoadConfiguration(unsigned int data) 
{
  commandEntry(LD_CON_CMD);
  writeBit(0);
  writeBits(data, 14);
  writeBit(0);
}

// ---------------- LOAD DATA COMMANDS ---------------- //

void commandLoadProgramMemory(unsigned int data) 
{
  commandEntry(LD_PRO_CMD);
  writeBit(0);
  writeBits(data, 14);
  writeBit(0);
}

void commandLoadDataMemory(unsigned int data) 
{
  commandEntry(LD_DAT_CMD);
  writeBit(0);
  writeBits(data, 8);
  writeBits(0, 7);
}

// ---------------- READ DATA COMMANDS ---------------- //

int commandReadProgramMemory() 
{
  commandEntry(RD_PRO_CMD);
  
  readMode();

  readBit();
  int data = readBits(14);
  readBit();
  
  return data;
}

int commandReadDataMemory() 
{
  commandEntry(RD_DAT_CMD);
  
  readMode();
  
  readBit();
  int data = readBits(8);
  if (readBits(6))
    return -1;
  readBit();
  
  return data;
}

// ------------- PROGRAM COUNTER COMMANDS ------------- //

void commandIncrementAddress() 
{
  commandEntry(INCR_A_CMD);
}

void commandResetAddress() 
{
  commandEntry(REST_A_CMD);
}

// --------------- PROGRAMMING COMMANDS --------------- //

void commandBeginInternalProgramming() 
{
  commandEntry(BEG_IN_CMD);
  delay(5);
}

void commandBeginExternalProgramming() 
{
  commandEntry(BEG_EX_CMD);
  delay(1);
}

void commandEndExternalProgramming() 
{
  commandEntry(END_EX_CMD);
  delayMicroseconds(100);
}

// -------------- ERASE MEMORY COMMANDS --------------- //

void commandBulkEraseProgramMemory()
{
  commandEntry(ER_PRO_CMD);
  delay(5);
}

void commandBulkEraseDataMemory()
{
  commandEntry(ER_DAT_CMD);
  delay(5);
}

void commandRowEraseProgramMemory() 
{
  commandEntry(ER_ROW_CMD);
  delay(3);
}

// ----------------- SERIAL PROTOCOLS ----------------- //

void enterProgrammingMode() 
{
  digitalWrite(MCLR,  LOW);
  delayMicroseconds(1);
  digitalWrite(PVCC, HIGH);
  delay(1);
  
  // We're in low voltage programming
  // mode. We have to send sequence key
  writeMode();
  writeBits(KEY_SEQ, 32);

  // Send last clock pulse to enter
  // programming mode.
  digitalWrite(ICSPCLK, HIGH);
  delayMicroseconds(1);
  digitalWrite(ICSPCLK,  LOW);
  delay(1);

  Serial.println("Beginning programming...");
}

void leaveProgrammingMode() 
{ 
  digitalWrite(PVCC,    LOW);
  digitalWrite(ICSPCLK, LOW);
  digitalWrite(ICSPDAT, LOW);
  
  delay(1);
  digitalWrite(MCLR,   HIGH);

  Serial.println("Stopping programming...");
}

inline void readMode() 
{
  pinMode(ICSPDAT, INPUT);
}

inline void writeMode() 
{
  pinMode(ICSPDAT, OUTPUT);
  digitalWrite(ICSPDAT, LOW);
}

inline void writeBits(unsigned long data, unsigned int n) {
  // Write bits in Little Endian
  while (n--) {
    writeBit(data & 0x1);
    data >>= 1;
  }
}

inline void writeBit(bool data) 
{
  digitalWrite(ICSPDAT, data ? HIGH : LOW);
  delayMicroseconds(1);
  digitalWrite(ICSPCLK, HIGH);
  delayMicroseconds(1);
  digitalWrite(ICSPCLK,  LOW);
  delayMicroseconds(1);
  digitalWrite(ICSPDAT, LOW);
}

inline int readBits(unsigned int n) 
{
  int data = 0;
  
  unsigned int i = 0;
  while (i < n)
    data |= readBit() << i++;
  
  return data;
}

inline int readBit() 
{
  digitalWrite(ICSPCLK, HIGH);
  delayMicroseconds(1);
  int data = digitalRead(ICSPDAT);
  delayMicroseconds(1);
  digitalWrite(ICSPCLK, LOW);
  delayMicroseconds(1);
  return data ? 1 : 0;
}

