import processing.serial.*;

import java.io.Reader;
import java.io.FileReader;

import java.util.List;
import java.util.LinkedList;
import java.util.Arrays;

private static final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink.X/dist/default/production/blink.X.production.hex";
//private static final String FILE_PATH = "C:/Users/Christian/Desktop/MyProject.hex";
private static final int EXTENDED_ADDRESS_TYPE = 0x04;
private static final int DATA_TYPE = 0x00;
private static final int END_OF_FILE_TYPE = 0x01;

void setup() {
  printArray(Serial.list());
  
  Serial serialPort = new Serial(this, Serial.list()[1], 9600);
  
  Reader reader = null;
  HexFile hex = null;
  
  try {
    reader = new FileReader(new File(FILE_PATH));
    hex = readHexFile(reader);
  } catch (IOException e) {
    e.printStackTrace();
  } finally {
    if (reader != null) {
        try {
          reader.close();
        } catch (IOException e2) {
          // Nothing can be done if
          // this happened.
        }
     }
  }
  
  // Wait for serial device to boot
  delay(2000);
  
  if (hex != null)
    programDevice(hex, new Programmer(serialPort));
  
  serialPort.stop();
}

void programDevice(HexFile hex, Programmer programmer) {
  programmer.start();
  
  program_loop: for (HexFileEntry entry : hex.entries) {
    switch (entry.recordType) {
    case EXTENDED_ADDRESS_TYPE: // 0x04
      programmer.setExtendedAddress(((entry.data[0] & 0xFF) << 8) | (entry.data[1] & 0xFF));
      break;
    case DATA_TYPE: // 0x00
      programmer.loadAddress(entry.address);
      programmer.writeProgramData(entry.data, entry.numBytes);
      break;
    case END_OF_FILE_TYPE: // 0x01
      // End of file, stop programming
      break program_loop;
    }
  }
  
  programmer.stop();
}

private class Programmer {
  
  private static final int EXTENDED_ADDRESS_OFFSET = 0x2000;
  
  private final Serial serialPort;
  private int address;
  private int extendedAddress;
  
  public Programmer(Serial serialPort) {
    this.serialPort = serialPort;
    address = 0;
    extendedAddress = 0;
  }
  
  public void start() {
    doCommand((byte)'b');
    printFeedback();
    printFeedback();
    doCommand((byte)'z');
    doCommand((byte)'e');
  }
  
  public void stop() {
    doCommand((byte)'s');
    printFeedback();
  }
  
  public void writeProgramData(byte[] data, int numBytes) {
    for (int i = 0; i < numBytes; i += 2) {
      int dat = ((data[i] & 0xFF) << 8) | (data[i + 1] & 0xFF);
      writeProgramWord(dat);  
      address++;
    }
  }
  
  public void setExtendedAddress(int extAddr) {
    extendedAddress = extAddr;
    loadAddress(0);
  }
  
  public void loadAddress(int addr) {
    // Program addresses are divided by two
    addr >>>= 1;
    if (extendedAddress != 0) {
      addr += EXTENDED_ADDRESS_OFFSET;
      
      if (addr < address || address < EXTENDED_ADDRESS_OFFSET) {
        address = EXTENDED_ADDRESS_OFFSET;
        doDataCommand((byte)'c', -1);
      }
    } else {
      if (addr < address) {
        address = 0;
        doCommand((byte)'z');
      }
    }
    
    while (address != addr) {
      address++;
      doCommand((byte)'i');
    }
  }
  
  public void writeProgramWord(int data) {
    doDataCommand((byte)'p', data);
    doCommand((byte)'w');
    doCommand((byte)'i');
  }
  
  public void doCommand(byte command) {
    serialPort.write(command);
    printFeedback();
  }
  
  public void doDataCommand(byte command, int data) {
    serialPort.write(command);
    serialPort.write((data >> 0) & 0xFF);
    serialPort.write((data >> 8) & 0xFF);
    printFeedback();
  }
  
  public void printFeedback() {
    String r = "";
    while (true) {
      while(serialPort.available() == 0)
        delay(1);
      
      int byteIn = serialPort.read();
      char c = (char)byteIn;
      if (c == '\n') // new line
        break;
      r += c;
    }
    println(r);
  }
}

public static HexFile readHexFile(Reader reader) throws IOException {
  HexFile hex = new HexFile();
  int input;
  while ((input = reader.read()) != -1) {
    if ((char)input == ':')
      hex.entries.add(readEntry(reader));
  }
  return hex;
}

private static HexFileEntry readEntry(Reader reader) throws IOException {
  int numBytes = readByte(reader);
  int address = (readByte(reader) << 8) | readByte(reader);
  int recordType = readByte(reader);

  byte[] data = new byte[numBytes];
  int i = 0;
  while (i != numBytes)
    data[i++] = (byte)readByte(reader);

  int checksum = readByte(reader);

  int check = numBytes + address + recordType;
  i = numBytes;
  while (i-- > 0)
    check += (int)data[i] & 0xFF;
  check = ((~check) + 1) & 0xFF;
  
  if (check != checksum)
    throw new IOException("Invalid hex file");
  
  return new HexFileEntry(numBytes, address, recordType, data);
}

private static int readByte(Reader reader) throws IOException {
  int h0 = reader.read();
  int h1 = reader.read();
  
  if (h0 == -1 || h1 == -1)
    throw new IOException("Invalid hex file");
    
  int b0 = parseHexChar((char)h0);
  int b1 = parseHexChar((char)h1);

  if (b0 == -1 || b1 == -1)
    throw new IOException("Invalid hex file");
  
  return ((b0 << 4) | b1) & 0xFF;
}

private static int parseHexChar(char c) {
  if (c >= '0' && c <= '9')
    return (int)(c - '0');
  if (c >= 'a' && c <= 'f')
    return (int)(c - 'a') + 10;
  if (c >= 'A' && c <= 'F')
    return (int)(c - 'A') + 10;
  return -1;
}

private static class HexFile {
  
  public final List<HexFileEntry> entries;
  
  public HexFile() {
    entries = new LinkedList<HexFileEntry>();
  }
}

private static class HexFileEntry {
  
  public final int numBytes;
  public final int address;
  public final int recordType;
  public final byte[] data;
  
  public HexFileEntry(int numBytes, int address, int recordType, byte[] data) {
    this.numBytes = numBytes;
    this.address = address;
    this.recordType = recordType;
    this.data = data;
  }
  
  @Override
  public String toString() {
    return String.format("\n[%d, %d, %d, %s]", numBytes, address, recordType, Arrays.toString(data));
  }
}