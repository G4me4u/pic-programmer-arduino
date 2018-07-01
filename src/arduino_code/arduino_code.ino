#include "./constants.h"
#include "./pic_programmer.h"

// Different programming specifications
#include "./PIC12F1822_pic_programmer.h"
#include "./PIC16F182X_pic_programmer.h"
#include "./PIC18F1XK22_pic_programmer.h"
#include "./PIC16F88X_pic_programmer.h"

PicProgrammer *programmer = nullptr;

unsigned int writeBufferSize = 0;
unsigned char writeBuffer[WRITE_BUFFER_SIZE];

void setup() {
  // Set MCLR to input
  // when not programming.
  pinMode(MCLR,    INPUT);

  // The rest are outputs
  pinMode(PVCC,    OUTPUT);
  pinMode(ICSPCLK, OUTPUT);
  pinMode(PGM,     OUTPUT);

  digitalWrite(PVCC,    LOW);
  digitalWrite(ICSPCLK, LOW);
  digitalWrite(PGM,     LOW);

  Serial.begin(TRANSFER_BAUDRATE);

  // Send power good signal
  Serial.print('g');
}

void loop() {
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
    unsigned int mode = readArgument(2);
    
    if (programmer != nullptr) {
      if (programmer->programming) {
        Serial.write(0x00);
        Serial.write(0x00);
        return false;
      }

      // We have to delete the programmer.
      // For some reason it never started
      // programming.
      delete programmer;
      programmer = nullptr;
    }

    // We send back flags depending
    // on the chosen specification.
    // If we're using single-byte
    // per address specification, the
    // flag should be changed. Default
    // is two bytes per address.
    unsigned int flags = TWO_BYTES_PER_ADDRESS;

    // The low 6 bits of the mode
    // is dedicated to programming
    // specification.
    switch (mode & 0x3F) {
    case PIC12F1822_SPECIFICATION:
      programmer = new PIC12F1822_PicProgrammer(mode);
      break;
    case PIC16F182X_SPECIFICATION:
      programmer = new PIC16F182X_PicProgrammer(mode);
      break;
    case PIC18F1XK22_SPECIFICATION:
      programmer = new PIC18F1XK22_PicProgrammer(mode);

      // Use single byte per address
      flags     -= TWO_BYTES_PER_ADDRESS;
      break;
    case PIC16F88X_SPECIFICATION:
      programmer = new PIC16F88X_PicProgrammer(mode);
      break;
    default:
      return false;
    }

    // Clear write-buffer
    writeBufferSize = 0;

    // Send flags to transmitter
    Serial.write((char)(flags >> 8));
    Serial.write((char)(flags >> 0));

    return programmer->enterProgrammingMode();
  }
  
  if (programmer == nullptr || !programmer->programming)
    return false;
  
  unsigned long tmp;
  switch(command) {
  case 's':
    programmer->leaveProgrammingMode();
    
    // Delete the programmer
    delete programmer;
    programmer = nullptr;

    return true;
  
  case 'n':
    programmer->beginReading();
    return true;
  case 'r':
    tmp = programmer->readProgramWord();
    Serial.write((char)(tmp >> 8));
    Serial.write((char)(tmp >> 0));
    return true;
  case 'm':
    programmer->endReading();
    return true;

  case 'j':
    programmer->beginWriting();
    return true;
  case 'l':
    // Data should be located in the
    // LSB of the argument.
    tmp = readArgument(2);
    // No more space in write-buffer
    if (writeBufferSize >= WRITE_BUFFER_SIZE)
      return false;
    
    writeBuffer[writeBufferSize++] = (char)(tmp & 0xFF);
    return true;
  case 'p':
    programmer->programWriteBuffer(writeBuffer, writeBufferSize);
    // Clear write-buffer
    writeBufferSize = 0;

    return true;
  case 'k':
    programmer->endWriting();
    // Clear write-buffer
    writeBufferSize = 0;
    return true;
  
  case 'x':
    programmer->setExtendedAddress(readArgument(2));
    return true;
  case 'a':
    programmer->setAddress(readArgument(2));
    return true;

  case 'i':
    tmp = programmer->readDeviceId();
    Serial.write((char)(tmp >> 8));
    Serial.write((char)(tmp >> 0));
    return true;
  case 'e': 
    programmer->eraseDevice();
    return true;
  }

  return false;
}

unsigned long readArgument(unsigned int num) {
  unsigned long r = 0;
  while (num--) {
    while (Serial.available() == 0)
      continue;
    r <<= 8;
    r |= Serial.read() & 0xFF;
  }
  return r;
}
