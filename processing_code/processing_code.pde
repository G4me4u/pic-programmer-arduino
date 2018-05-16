import processing.serial.*;

import java.io.Reader;
import java.io.FileReader;

import java.util.List;
import java.util.LinkedList;
import java.util.Arrays;

//private static final String FILE_PATH = "C:/Users/Christian/Documents/Github/pic-programmer-arduino/test/pic12f1822/blink.hex";
//private static final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/Klokgenerator.X/dist/default/production/Klokgenerator.X.production.hex";
private static final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink.X/dist/default/production/blink.X.production.hex";
//private static final String FILE_PATH = "C:/Users/Christian/Desktop/MyProject.hex";
private static final int EXTENDED_ADDRESS_TYPE = 0x04;
private static final int DATA_TYPE = 0x00;
private static final int END_OF_FILE_TYPE = 0x01;
private static final int SERIAL_BAUDRATE = 9600;

void setup() {
  printArray(Serial.list());
  
  Serial serialPort = new Serial(this, Serial.list()[1], SERIAL_BAUDRATE);
  
  Reader reader = null;
  HexFile hex = null;
  
  try {
    reader = new FileReader(new File(FILE_PATH));
    hex = new HexFile(reader);
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
  
  if (hex != null) {
    Programmer programmer = new Programmer(serialPort);
    programmer.start();
    HexWriteProcessor hexWriter = new HexWriteProcessor(programmer, hex);
    HexReadProcessor hexReader = new HexReadProcessor(programmer, hex);
    if (hexWriter.processHexFile())
      hexReader.processHexFile();
    programmer.stop();
  }
  
  serialPort.stop();
}

private class HexReadProcessor extends HexProcessor {
  
  public HexReadProcessor(Programmer programmer, HexFile hex) {
    super(programmer, hex);
  }
  
  protected void extendedAddress(int extendedAddress) {
    programmer.setExtendedAddress(extendedAddress);
  }
  
  protected void programData(int address, byte[] data, int numBytes) {
    programmer.loadAddress(address);
    
    for (int i = 0; i < numBytes; i += 2) {
      int addr = address + i;
      
      programmer.loadAddress(addr);
      int programmedWord = programmer.readProgramWord();
      int hexWord = MemoryUtil.bytesToUnsignedShort(data, i);
      if (programmedWord != hexWord)
        throw new ProgrammingException("Program data: " + Integer.toHexString(programmedWord) + " at address: " + 
                                       Integer.toHexString(addr) + " does not match hex: " + Integer.toHexString(hexWord));
    }  
}
  
  protected void endProcessing() {
    // End of file, stop programming
  }
}

private class HexWriteProcessor extends HexProcessor {

  public HexWriteProcessor(Programmer programmer, HexFile hex) {
    super(programmer, hex);
  }
  
  protected void extendedAddress(int extendedAddress) {
    programmer.setExtendedAddress(extendedAddress);
  }
  
  protected void programData(int address, byte[] data, int numBytes) {
    programmer.loadAddress(address);
    programmer.writeProgramData(data, numBytes);
  }
  
  protected void endProcessing() {
    // End of file, stop programming
  }
}

private abstract class HexProcessor {
  
  protected final Programmer programmer;
  protected final HexFile hex;
  
  public HexProcessor(Programmer programmer, HexFile hex) {
    this.programmer = programmer;
    this.hex = hex;
  }
  
  public boolean processHexFile() {
    try {
      program_loop: for (HexFileEntry entry : hex.entries) {
        switch (entry.recordType) {
        case EXTENDED_ADDRESS_TYPE: // 0x04
          extendedAddress(MemoryUtil.bytesToUnsignedShort(entry.data, 0));
          break;
        case DATA_TYPE: // 0x00
          programData(entry.address, entry.data, entry.numBytes);
          break;
        case END_OF_FILE_TYPE: // 0x01
          endProcessing();
          break program_loop;
        }
      }
    } catch (ProgrammingException pe) {
      pe.printStackTrace();
      return false;
    }
    
    return true;
  }
  
  protected abstract void extendedAddress(int extendedAddress);
  
  protected abstract void programData(int address, byte[] data, int numBytes);
  
  protected abstract void endProcessing();
}

private class Programmer {
  
  private static final int EXTENDED_ADDRESS_OFFSET = 0x2000;
  
  private final Serial serialPort;
  private int address;
  private int extendedAddress;
  
  public Programmer(Serial serialPort) {
    this.serialPort = serialPort;
  }
  
  public void start() {
    doCommand((byte)'b');
    printFeedback();
    printFeedback();
    
    resetAddress();
    bulkEraseProgramData();
  }
  
  public void stop() {
    doCommand((byte)'s');
    printFeedback();
  }
  
  public int readProgramWord() {
    // Not implemented
    return -1;
  }
  
  public void writeProgramData(byte[] data, int numBytes) {
    for (int i = 0; i < numBytes; i += 2)
      writeProgramWord(MemoryUtil.bytesToUnsignedShort(data, i));
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
      
      if (addr < address || address < EXTENDED_ADDRESS_OFFSET)
        loadConfigAddress();
    } else {
      if (addr < address) 
        resetAddress();
    }
    
    while (address != addr)
      incrementAddress();
  }
  
  public void writeProgramWord(int data) {
    doDataCommand((byte)'p', data);
    beginInternalProgramming();
    incrementAddress();
  }
  
  public void beginInternalProgramming() {
    doCommand((byte)'w');
  }
  
  public void incrementAddress() {
    doCommand((byte)'i');
    address++;
  }
  
  public void loadConfigAddress() {
    doDataCommand((byte)'c', -1);
    address = EXTENDED_ADDRESS_OFFSET;
  }
  
  public void resetAddress() {
    doCommand((byte)'z');
    address = 0;
  }
  
  public void bulkEraseProgramData() {
    doCommand((byte)'e');
  }
  
  public void doCommand(byte command) {
    serialPort.write(command);
    printFeedback();
  }
  
  public void doDataCommand(byte command, int data) {
    doDataCommand(command, (byte)data, (byte)(data >> 8));
  }
  
  public void doDataCommand(byte command, byte data0, byte data1) {
    serialPort.write(command);
    serialPort.write(data0);
    serialPort.write(data1);
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

private static class HexFile {
  
  public final List<HexFileEntry> entries;
  
  public HexFile(Reader reader) throws IOException {
    entries = new LinkedList<HexFileEntry>();
    readHexFile(reader);
  }
  
  public void readHexFile(Reader reader) throws IOException {
    int input;
    while ((input = reader.read()) != -1) {
      if ((char)input == ':')
        entries.add(readEntry(reader));
    }
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
      check += data[i] & 0xFF;
    check = (~check) & 0xFF;
    check = (check + 1) & 0xFF;
    
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
    println("Invalid hex");
    return -1;
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

private static final class MemoryUtil {
  
  private MemoryUtil() {
  }
  
  public static int bytesToUnsignedShort(byte[] data, int offset) {
    return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
  }
}

private static class ProgrammingException extends RuntimeException {

  public ProgrammingException(String msg) {
    super(msg);
  }
}