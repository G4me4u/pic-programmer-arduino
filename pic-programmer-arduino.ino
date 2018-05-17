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

#define TRANSFER_BAUDRATE 115200

boolean programming = false;

void setup() {
  pinMode(MCLR,    OUTPUT);
  pinMode(PVCC,    OUTPUT);
  pinMode(ICSPCLK, OUTPUT);

  digitalWrite(MCLR,    HIGH);
  digitalWrite(PVCC,    LOW);
  digitalWrite(ICSPCLK, LOW);

  Serial.begin(TRANSFER_BAUDRATE);

  // Send power good signal
  Serial.print('g');
}

void loop() {  
  /* Commands:
   *  
   * Programming related commands:
   *   b - begin programming
   *   s - stop programming
   *
   * Address related commands:
   *   i - increment address
   *   z - reset address to zero
   *   c - load configuration
   *
   * Erase related commands:
   *   e - bulk erase program memory
   *   t - bulk erase data memory
   *
   * Write related commands:
   *   p - load program memory
   *   d - load data memory
   *   w - start internal programming
   *
   * Read related commands:
   *   r - read program memory
   *
   * Commands that return data (2 bytes):
   *   r - program memory at address
   * 
   * Data commands are most significant
   * byte first.
   */
  if (Serial.available() > 0) {
    char command = Serial.read();
    
    // Sometimes it seems like the serial
    // is sending 0xF0 as a leading byte to
    // all communication - ignore it here
    if (command == (char)0xF0)
      return;
    
    // Print back received command
    Serial.print(command);
    // Print command status, when done
    Serial.print(doCommand(command) ? 'd' : 'f');
  }
}

bool doCommand(char command) {
  if (command == 'b') {
    if (programming)
      return false;
    
    enterProgrammingMode();
    programming = true;
    return true;
  }

  int tmp;
  
  if (!programming)
    return false;
  
  switch(command) {
  case 's':
    leaveProgrammingMode();
    programming = false;
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
  case 'c':
    commandLoadConfiguration(readArgument(2));
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
    
  case 'r':
    tmp = commandReadProgramMemory();
    Serial.print((char)(tmp >> 8));
    Serial.print((char)(tmp >> 0));
    return true;
  }

  return false;
}

unsigned int readArgument(unsigned int num) {
  unsigned int r = 0;
  while (num--) {
    while (Serial.available() == 0);
    r <<= 8;
    r |= Serial.read() & 0xFF;
  }
  return r;
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
}

void leaveProgrammingMode() 
{ 
  digitalWrite(PVCC,    LOW);
  digitalWrite(ICSPCLK, LOW);
  digitalWrite(ICSPDAT, LOW);
  
  delay(1);
  digitalWrite(MCLR,   HIGH);
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

