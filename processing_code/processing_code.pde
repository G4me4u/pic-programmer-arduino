import processing.serial.*;

import java.io.Reader;
import java.io.FileReader;

import java.util.List;
import java.util.LinkedList;
import java.util.Arrays;

/** File path location */
//private static final String FILE_PATH = "C:/Users/Christian/Documents/Github/pic-programmer-arduino/test/pic16f1705/blink.hex";
private static final String FILE_PATH = "E:/Programming/Git-repos/pic-programmer-arduino/test/pic16f1705/blink.hex";

/** Hex file codes */
private static final int EXTENDED_ADDRESS_TYPE = 0x04;
private static final int DATA_TYPE = 0x00;
private static final int END_OF_FILE_TYPE = 0x01;

/** Serial communication baudrate */
private static final int SERIAL_BAUDRATE = 9600;

/** The address offset for the extended address */
private static final int EXTENDED_ADDRESS_OFFSET = 0x8000;

/** Supported devices' information */
private static final int PIC12F1822_DEV_ID = 0x0138;
private static final int PIC16F1705_DEV_ID = 0x0182;

private static final int[] SUPPORTED_DEVICE_IDS = {
  PIC12F1822_DEV_ID,
  PIC16F1705_DEV_ID
};

private static final String[] SUPPORTED_DEVICE_NAMES = {
  "PIC12F1822",
  "PIC16F1705"
};

private static final int[] CONFIGURATION_ADDRESSES = {
  0x8000,
  0x8000
};

private static final String COMMAND_SUCCESS = "d";
private static final String COMMAND_FAIL_DATA = "FFFF";

void setup() {
  printArray(Serial.list());
  
  Serial serialPort = new Serial(this, Serial.list()[1], SERIAL_BAUDRATE);
  
  Reader reader = null;
  HexFile hex = null;
  
  try {
    reader = new FileReader(new File(FILE_PATH));
    hex = new HexFile(reader);
    println("Read and parsed hex file successfully (" + hex.numDataBytes + " bytes).");
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
  
  // TODO: add ping-pong protocol at boot-up.
  println("Waiting for programming device to boot...");
  delay(2000);
  
  if (hex != null) {
    Programmer programmer = new Programmer(serialPort);
    
    try {
      programmer.start();
      println("Erasing program data...");
      programmer.loadAddress(0);
      programmer.bulkEraseProgramData();
      
      new HexWriteProcessor(programmer, hex).processHexFile();
      new HexReadProcessor(programmer, hex).processHexFile();
      println("Done!");
    } catch (ProgrammingException pe) {
      pe.printStackTrace();
    }
  
    try {
      programmer.stop();
    } catch (ProgrammingException pe) {
      pe.printStackTrace();
    }
  }
  
  serialPort.stop();
  
  exit();
}

private class HexReadProcessor extends HexProcessor {
  
  public HexReadProcessor(Programmer programmer, HexFile hex) {
    super(programmer, hex);
  }
  
  public void processHexFile() {
    println("Beginning program verifying " + hex.numDataBytes + " bytes...");
    super.processHexFile();
  }
  
  protected void extendedAddress(int extendedAddress) {
    programmer.setExtendedAddress(extendedAddress);
  }
  
  protected void programData(int address, byte[] data, int numBytes) {
    programmer.loadAddress(address);
    
    for (int i = 0; i < numBytes; i += 2) {
      int programmedWord = programmer.readProgramWord();
      int hexWord = MemoryUtil.bytesToUnsignedShort(data, i, false);
      if (programmedWord != hexWord)
        throw new ProgrammingException("Program data: " + Integer.toHexString(programmedWord) + " at address: " + 
                                       Integer.toHexString(programmer.address) + " does not match hex: " + Integer.toHexString(hexWord));
      programmer.incrementAddress();
    }
  }
  
  protected void endProcessing() {
    // End of file, stop reading
    println("Finished program verifying...");
  }
}

private class HexWriteProcessor extends HexProcessor {

  public HexWriteProcessor(Programmer programmer, HexFile hex) {
    super(programmer, hex);
  }
  
  public void processHexFile() {
    println("Beginning program writing " + hex.numDataBytes + " bytes...");
    super.processHexFile();
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
    println("Finished program writing...");
  }
}

private abstract class HexProcessor {
  
  protected final Programmer programmer;
  protected final HexFile hex;
  
  public HexProcessor(Programmer programmer, HexFile hex) {
    this.programmer = programmer;
    this.hex = hex;
  }
  
  public void processHexFile() {
      programmer.resetAddress();
      program_loop: for (HexFileEntry entry : hex.entries) {
        switch (entry.recordType) {
        case EXTENDED_ADDRESS_TYPE: // 0x04
          extendedAddress(MemoryUtil.bytesToUnsignedShort(entry.data, 0, true));
          break;
        case DATA_TYPE: // 0x00
          programData(entry.address, entry.data, entry.numBytes);
          break;
        case END_OF_FILE_TYPE: // 0x01
          endProcessing();
          break program_loop;
        }
      }
  }
  
  protected abstract void extendedAddress(int extendedAddress);
  
  protected abstract void programData(int address, byte[] data, int numBytes);
  
  protected abstract void endProcessing();
}

private class Programmer {

  private final Serial serialPort;
  private int address;
  private int extendedAddress;
  
  private int connectedDevice;
  private int configAddress;
  
  public Programmer(Serial serialPort) {
    this.serialPort = serialPort;
    connectedDevice = configAddress = -1;
  }
  
  public void start() {
    int dev_id = doReadCommand((byte)'b');
    if (dev_id == -1)
      throw new ProgrammingException("Unable to connect to device");

    for (int i = 0; i < SUPPORTED_DEVICE_IDS.length; i++) {
      if (SUPPORTED_DEVICE_IDS[i] == dev_id) {
        connectedDevice = i;
        break;
      }
    }
    
    if (connectedDevice == -1)
      throw new ProgrammingException("Unknown device: " + Integer.toHexString(dev_id));
    
    println("Connected to device: " + SUPPORTED_DEVICE_NAMES[connectedDevice]);
    // Program addresses are divided by two
    configAddress = CONFIGURATION_ADDRESSES[connectedDevice] >>> 1;
  }
  
  public void stop() {
    doCommand((byte)'s');
    connectedDevice = -1;
    
    println("Stopped programming");
  }
  
  public int readProgramWord() {
    return doReadCommand((byte)'r');
  }
  
  public void writeProgramData(byte[] data, int numBytes) {
    for (int i = 0; i < numBytes; i += 2)
      writeProgramWord(MemoryUtil.bytesToUnsignedShort(data, i, false));
  }
  
  public void setExtendedAddress(int extAddr) {
    if (extAddr < 0)
      throw new ProgrammingException("Invalid extended address: " + extAddr);
    
    extendedAddress = extAddr;
    loadAddress(0);
  }
  
  public void loadAddress(int addr) {
    // Program addresses are divided by two
    addr = (addr + EXTENDED_ADDRESS_OFFSET * extendedAddress) >>> 1;
    
    // If it's possible to load config address, do so.
    if (addr >= configAddress &&  address < configAddress) {
      loadConfigAddress();
    } else if (addr < address) {
      // We have to reset address
      resetAddress();
    }
    
    // Increment address until we're at the
    // correct program-word.
    while (address != addr)
      incrementAddress();
  }
  
  public void writeProgramWord(int data) {
    doWriteCommand((byte)'p', data);
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
    doWriteCommand((byte)'c', -1);
    address = configAddress;
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
    checkFeedback(command);
  }
  
  public void doWriteCommand(byte command, int data) {
    doWriteCommand(command, (byte)(data >> 8), (byte)data);
  }
  
  public void doWriteCommand(byte command, byte data0, byte data1) {
    serialPort.write(command);
    serialPort.write(data0);
    serialPort.write(data1);
    checkFeedback(command);
  }
  
  public int doReadCommand(byte command) {
    serialPort.write(command);
    String data = getFeedback();
    
    checkFeedback(command);
    if (COMMAND_FAIL_DATA.equals(data))
      return -1;
    
    int len = data.length();
    if (len == 0 || len > 4)
      return -1;
    
    int res = 0;
    for (int i = 0; i < len; i++) {
      res <<= 4;
      res |= MemoryUtil.parseHexChar(data.charAt(i));
    }
    
    return res;
  }
  
  public void checkFeedback(byte command) {
    String fb = getFeedback();
    if (!COMMAND_SUCCESS.equals(fb))
      throw new ProgrammingException("Failed " + (char)command + " command, received code: " + fb);
  }
  
  public String getFeedback() {
    String r = "";
    while (true) {
      while(serialPort.available() == 0)
        delay(1);
      
      int byteIn = serialPort.read();
      char c = (char)byteIn;
      if (c == '\n') // new line
        break;
      if (c != 13) // Carriage return
        r += c;
    }
    return r;
  }
}

private static class HexFile {
  
  public final List<HexFileEntry> entries;
  public int numDataBytes;
  
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
  
  private HexFileEntry readEntry(Reader reader) throws IOException {
    int numBytes = readByte(reader);
    int address = (readByte(reader) << 8) | readByte(reader);
    int recordType = readByte(reader);
  
    if (recordType == DATA_TYPE)
      numDataBytes += numBytes;
  
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
      
    int b0 = MemoryUtil.parseHexChar((char)h0);
    int b1 = MemoryUtil.parseHexChar((char)h1);
  
    if (b0 == -1 || b1 == -1)
      throw new IOException("Invalid hex file");
    
    return (b0 << 4) | b1;
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
  
  public static int bytesToUnsignedShort(byte[] data, int offset, boolean bigEndian) {
    if (bigEndian)
      return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
    return ((data[offset + 1] & 0xFF) << 8) | (data[offset] & 0xFF);
  }
  
  public static int parseHexChar(char c) {
    if (c >= '0' && c <= '9')
      return (int)(c - '0');
    if (c >= 'A' && c <= 'F')
      return (int)(c - 'A') + 10;
    if (c >= 'a' && c <= 'f')
      return (int)(c - 'a') + 10;
    
    throw new RuntimeException("Invalid hex");
  }
}

private static class ProgrammingException extends RuntimeException {

  public ProgrammingException(String msg) {
    super(msg);
  }
}