import processing.serial.*;

import java.io.Reader;
import java.io.FileReader;

import java.util.List;
import java.util.LinkedList;
import java.util.Arrays;

/** File path location */
//private static final String FILE_PATH = "C:/Users/Christian/Documents/Github/pic-programmer-arduino/test/pic12f1822/blink.hex";
private static final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/Neopixel.X/dist/default/production/Neopixel.X.production.hex";

/** Hex file codes */
private static final int EXTENDED_ADDRESS_TYPE = 0x04;
private static final int DATA_TYPE = 0x00;
private static final int END_OF_FILE_TYPE = 0x01;

/** Serial communication baudrate */
private static final int SERIAL_BAUDRATE = 115200;

/** The address offset for the extended address */
private static final int EXTENDED_ADDRESS_OFFSET = 0x8000;
/** The default program memory bits */
private static final int DEF_PROG_M = 0x3FFF;

/** Command success response sent by the arduino */
private static final byte COMMAND_SUCCESS_DATA = (byte)'d';

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
  0x8000, // PIC12F1822
  0x8000  // PIC16F1705
};

private static final char POWER_GOOD_SIG = 'g';

void setup() {
  noLoop();
  
  printArray(Serial.list());
  
  Serial serialPort = new Serial(this, Serial.list()[1], SERIAL_BAUDRATE);
  
  Reader reader = null;
  HexFile hex = null;
  
  try {
    reader = new FileReader(new File(FILE_PATH));
    hex = new HexFile(reader);
    println("Read and parsed hex file successfully (" + hex.parsedLines + " lines, " + hex.numDataBytes + " bytes).");
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
  
  if (hex != null) {
    println("Waiting for programming-device to boot...");

    while(true) {
      while (serialPort.available() == 0)
        delay(1);
      
      int data = serialPort.read();
      // Programmer will send power good signal
      if ((char)data != POWER_GOOD_SIG) {
        // Sometimes it seems like the serial
        // is sending 0xF0 as a leading byte to
        // all communication - ignore it here
        if (data == 0xF0)
          continue;
        
        serialPort.stop();
        println("Unable to connect to programmer...");
        exit();
        return;
      } else break;
    }
    
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
  
  serialPort.clear();
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
    // Program data address is divided by two
    // as it has 2 bytes from hex-file per word.
    programmer.loadAddress(address / 2);
    
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
    // Program data address is divided by two
    // as it has 2 bytes from hex-file per word.
    programmer.loadAddress(address / 2);
  
    for (int i = 0; i < numBytes; i += 2)
      programmer.writeProgramWord(MemoryUtil.bytesToUnsignedShort(data, i, false));
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
    doCommand((byte)'b');
    int dev_id = readDeviceId();
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
    configAddress = CONFIGURATION_ADDRESSES[connectedDevice];
  }
  
  public int readDeviceId() {
    // Go to config address (data is
    // not being programmed).
    loadConfigAddress();
  
    // Actual address is wrong at this
    // point, if it's the first time
    // reading the device id bits...
  
    // Go to address 6h of config
    incrementAddress(); // 01
    incrementAddress(); // 02
    incrementAddress(); // 03
    incrementAddress(); // 04
    incrementAddress(); // 05
    incrementAddress(); // 06
  
    int dev_id = readProgramWord();
    if (dev_id == DEF_PROG_M) // Unable to read device
      return -1;
  
    // Discard revision bits (0:4)
    return dev_id >> 5;
}
  
  public void stop() {
    doCommand((byte)'s');
    connectedDevice = -1;
    
    println("Stopped programming");
  }
  
  public int readProgramWord() {
    return doReadCommand((byte)'r');
  }
  
  public void setExtendedAddress(int extAddr) {
    if (extAddr < 0)
      throw new ProgrammingException("Invalid extended address: " + extAddr);
    
    extendedAddress = extAddr;
    loadAddress(0);
  }
  
  public void loadAddress(int addr) {
    addr += EXTENDED_ADDRESS_OFFSET * extendedAddress;
    
    // If it's possible to load config address, do so.
    if (addr >= configAddress &&  address < configAddress) {
      loadConfigAddress();
    } else if (addr < address) {
      // We have to reset the address
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
    checkCommand(command);
    checkFeedback(command);
  }
  
  public void doWriteCommand(byte command, int data) {
    doWriteCommand(command, (byte)(data >> 8), (byte)data);
  }
  
  public void doWriteCommand(byte command, byte data0, byte data1) {
    serialPort.write(command);
    serialPort.write(data0);
    serialPort.write(data1);
    checkCommand(command);
    checkFeedback(command);
  }
  
  public int doReadCommand(byte command) {
    serialPort.write(command);
    checkCommand(command);
    
    // Wait for our two bytes of data
    while(serialPort.available() < 2)
      delay(1);
    int b0 = serialPort.read();
    int b1 = serialPort.read();
    
    checkFeedback(command);
    
    return (b0 << 8) | b1;
  }
  
  public void checkFeedback(byte command) {
    while(serialPort.available() == 0)
      delay(1);
    int code = serialPort.read();
    if ((byte)code != COMMAND_SUCCESS_DATA)
      throw new ProgrammingException("Failed " + (char)command + " command, received code: " + (char)code);
  }
  
  private void checkCommand(byte command) {
    while (true) {
      while(serialPort.available() == 0)
        delay(1);
      if ((byte)serialPort.read() == command)
        break;
    }
  }
}

private static class HexFile {
  
  public final List<HexFileEntry> entries;
  public int numDataBytes;
  public int parsedLines;
  
  public HexFile(Reader reader) throws IOException {
    entries = new LinkedList<HexFileEntry>();
    readHexFile(reader);
  }
  
  public void readHexFile(Reader reader) throws IOException {
    if (!entries.isEmpty())
      entries.clear();
    // We start at line 1
    parsedLines = 1;
    
    int input;
    while ((input = reader.read()) != -1) {
      switch((char)input) {
      case ':':
        entries.add(readEntry(reader));
        break;
      case '\n':
        parsedLines++;
        break;
      }
    }
  }
  
  private HexFileEntry readEntry(Reader reader) throws IOException {
    int numBytes = readByte(reader);
    int addr0 = readByte(reader);
    int addr1 = readByte(reader);
    int address = (addr0 << 8) | addr1;
    int recordType = readByte(reader);
  
    if (recordType == DATA_TYPE)
      numDataBytes += numBytes;
  
    byte[] data = new byte[numBytes];
    int i = 0;
    while (i != numBytes)
      data[i++] = (byte)readByte(reader);
  
    byte checksum = (byte)readByte(reader);
  
    byte check = 0;
    check += (byte)numBytes;
    check += (byte)addr0;
    check += (byte)addr1;
    check += (byte)recordType;
    i = numBytes;
    while (i-- > 0)
      check += data[i];  
    check = (byte)(~check);
    check++;
    
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