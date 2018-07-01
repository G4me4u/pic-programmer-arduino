import processing.serial.*;

import java.io.Reader;
import java.io.FileReader;

/** File path location */
//private final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink-pic18f13k22.X/dist/default/production/blink-pic18f13k22.X.production.hex";
//private final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink-pic16f883.X/dist/default/production/blink-pic16f883.X.production.hex";
//private final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink-pic16f1705.X/dist/default/production/blink-pic16f1705.X.production.hex";
private final String FILE_PATH = "C:/Users/Christian/MPLABXProjects/blink.X/dist/default/production/blink.X.production.hex";
/** Target device to program */
private final int TARGET_DEVICE_ID = PIC12F1822_DEV_ID;
/** Programming mode specification */
private final boolean FORCE_LOW_VOLTAGE_PROGRAMMING = true;

/** Serial communication baudrate */
private static final int SERIAL_BAUDRATE = 115200;

/** Supported devices' information */
private static final int PIC12F1822_DEV_ID  = 0x0138;
private static final int PIC16F1705_DEV_ID  = 0x0182;
private static final int PIC18F13K22_DEV_ID = 0x027A;
private static final int PIC16F883_DEV_ID   = 0x0101;

private static final int[] SUPPORTED_DEVICE_IDS = {
  PIC12F1822_DEV_ID,
  PIC16F1705_DEV_ID,
  PIC18F13K22_DEV_ID,
  PIC16F883_DEV_ID
};

private static final String[] SUPPORTED_DEVICE_NAMES = {
  "PIC12F1822",
  "PIC16F1705",
  "PIC18F13K22",
  "PIC16F883"
};

private static final int LOW_VOLTAGE_PROGRAMMING_MASK = 0x80;

private static final int PIC12F1822_SPECIFICATION  = 0x00;
private static final int PIC18F1XK22_SPECIFICATION = 0x02;
private static final int PIC16F88X_SPECIFICATION   = 0x03;

// The programming modes that will be 
// used for programming. The 6 low bits 
// are used to determine the programming 
// specification to use when programming 
// the PIC. The 2 MSb are configuration.
private static final int[] PROGRAMMING_MODES = {
  PIC12F1822_SPECIFICATION,  // PIC12F1822
  PIC12F1822_SPECIFICATION,  // PIC16F1705
  PIC18F1XK22_SPECIFICATION, // PIC18F13K22
  PIC16F88X_SPECIFICATION    // PIC16F883
};

private static final char POWER_GOOD_SIG = 'g';

private static final int TWO_BYTES_PER_ADDRESS_FLAG = 0x01;

private int targetDeviceIndex = -1;

void setup() {
  noLoop();
  
  for (int i = 0; i < SUPPORTED_DEVICE_IDS.length; i++) {
    int deviceId = SUPPORTED_DEVICE_IDS[i];
    if (deviceId == TARGET_DEVICE_ID) {
      targetDeviceIndex = i;
      break;
    }
  }
  
  if (targetDeviceIndex == -1) {
    println("Target device doesn't exist: " + Integer.toHexString(TARGET_DEVICE_ID));
    return;
  }
  
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
    
    ProgrammerImpl programmer = new ProgrammerImpl(serialPort);
    
    try {
      programmer.start();

      println("Erasing program data...");
      programmer.eraseDevice();

      new HexWriteProcessor(programmer, programmer.twoBytesPerAddress, hex).processHexFile();
      new HexReadProcessor(programmer, programmer.twoBytesPerAddress, hex).processHexFile();
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

private class ProgrammerImpl extends Programmer {

  public int connectedDevice;
  public boolean twoBytesPerAddress;
  
  public ProgrammerImpl(Serial serialPort) {
    super(serialPort);
    
    connectedDevice = -1;
  }
  
  public void start() {
    byte mode = (byte)PROGRAMMING_MODES[targetDeviceIndex];
    if (FORCE_LOW_VOLTAGE_PROGRAMMING)
      mode |= LOW_VOLTAGE_PROGRAMMING_MASK;
    
    int flags = doReadWriteCommand((byte)'b', 2, mode, (byte)0x00);
    twoBytesPerAddress = (flags & TWO_BYTES_PER_ADDRESS_FLAG) != 0;
    
    int dev_id = readDeviceId();
    if (dev_id == -1)
      throw new ProgrammingException("Unable to connect to device");

    connectedDevice = -1;
    for (int i = 0; i < SUPPORTED_DEVICE_IDS.length; i++) {
      if (SUPPORTED_DEVICE_IDS[i] == dev_id) {
        connectedDevice = i;
        break;
      }
    }
    
    if (connectedDevice == -1)
      throw new ProgrammingException("Unknown device: " + Integer.toHexString(dev_id));
    
    println("Connected to device: " + SUPPORTED_DEVICE_NAMES[connectedDevice]);
    if (connectedDevice != targetDeviceIndex)
      throw new ProgrammingException("Connected device does not match target device: " + SUPPORTED_DEVICE_NAMES[targetDeviceIndex]);
  }
  
  public void stop() {
    doCommand((byte)'s');
    connectedDevice = -1;
    
    println("Stopped programming");
  }
}