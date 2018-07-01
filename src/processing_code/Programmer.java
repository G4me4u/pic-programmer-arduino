import processing.serial.Serial;

public abstract class Programmer {

	/** Command success response sent by the arduino */
	public static final byte COMMAND_SUCCESS_DATA = (byte)'d';
	/** The maximum number of bytes to be loaded into
	  * the write buffer of the arduino programmer. */
	public static final int MAX_WRITE_BUFFER_SIZE = 32;

	private final Serial serialPort;
	
	public Programmer(Serial serialPort) {
		this.serialPort = serialPort;
	}
	
	public abstract void start();
	
	public abstract void stop();

	public void beginReading() {
		doCommand((byte)'n');
	}

	public int readProgramWord() {
		return doReadCommand((byte)'r', 2);
	}
	
	public void endReading() {
		doCommand((byte)'m');
	}
	
	public void beginWriting() {
		doCommand((byte)'j');
	}
	
	public void loadWriteBuffer(int data) {
		doWriteCommand((byte)'l', data);
	}

	public void programWriteBuffer() {
		doCommand((byte)'p');
	}
	
	public void endWriting() {
		doCommand((byte)'k');
	}

	public void setExtendedAddress(int extAddr) {
		doWriteCommand((byte)'x', extAddr);
	}
	
	public void setAddress(int addr) {
		doWriteCommand((byte)'a', addr);
	}

	public int readDeviceId() {
		return doReadCommand((byte)'i', 2);
	}

	public void eraseDevice() {
		doCommand((byte)'e');
	}

	public void doCommand(byte command) {
		serialPort.write(command);
		checkCommand(command);
		checkFeedback(command);
	}
	
	public void doWriteCommand(byte command, int data) {
		doWriteCommand(command, (byte)data, (byte)(data >>> 8L));
	}
	
	public void doWriteCommand(byte command, byte data0, byte data1) {
		serialPort.write(command);
		serialPort.write(data1);
		serialPort.write(data0);
		checkCommand(command);
		checkFeedback(command);
	}
	
	public int doReadCommand(byte command, int numBytes) {
		serialPort.write(command);
		checkCommand(command);		
		int data = receiveBytes(numBytes);
		checkFeedback(command);
		
		return data;
	}

	public int doReadWriteCommand(byte command, int numBytes, int data) {
		return doReadWriteCommand(command, numBytes, (byte)data, (byte)(data >>> 8L));
	}

	public int doReadWriteCommand(byte command, int numBytes, byte data0, byte data1) {
		serialPort.write(command);
		
		// Write Data
		serialPort.write(data1);
		serialPort.write(data0);

		// Wait for feedback from 
		// specific command.
		checkCommand(command);		
		// Receive data.
		int data = receiveBytes(numBytes);
		// Check if command failed 
		// or succeeded.
		checkFeedback(command);
		
		return data;
	}

	public int receiveBytes(int numBytes) {
		// Wait for our bytes of data
		waitForSerial(numBytes);
		
		int data = 0;
		while (numBytes-- != 0) {
			data <<= 8;
			data |= serialPort.read() & 0xFF;
		}

		return data;
	}
	
	public void checkFeedback(byte command) {
		waitForSerial(1);
		
		int code = serialPort.read();
		if ((byte)code != COMMAND_SUCCESS_DATA)
			throw new ProgrammingException("Failed " + (char)command + " command, received code: " + (char)code);
	}
	
	protected void checkCommand(byte command) {
		while (true) {
			waitForSerial(1);

			if ((byte)serialPort.read() == command)
				break;
		}
	}

	protected void waitForSerial(int numBytes) {
		while(serialPort.available() < numBytes) {
			try {
				Thread.sleep(1);
			} catch (InterruptedException e) {
			}
		}
	}
}
