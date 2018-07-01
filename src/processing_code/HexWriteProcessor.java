
public class HexWriteProcessor extends HexProcessor {

	public HexWriteProcessor(Programmer programmer, boolean twoBytesPerAddress, HexFile hex) {
		super(programmer, twoBytesPerAddress, hex);
	}
	
	@Override
	public void processHexFile() {
		System.out.println("Beginning program writing " + hex.numDataBytes + " bytes...");
		
		programmer.beginWriting();
		super.processHexFile();
		programmer.endWriting();
	}
	
	@Override
	protected void extendedAddress(int extendedAddress) {
		programmer.setExtendedAddress(extendedAddress);
	}
	
	@Override
	protected void programData(int address, byte[] data, int numBytes) {
		// If we have 2 bytes per address,
		// divide it by two.
		if (twoBytesPerAddress)
			address >>>= 1;
		programmer.setAddress(address);
		
		int writeBufferSize = 0;
		for (int i = 0; i < numBytes; i++) {
			// Load another byte into write-buffer.
			programmer.loadWriteBuffer(data[i] & 0xFF);
			writeBufferSize++;

			// If we've filled up the write buffer
			// we have to program the contents and
			// empty it, so we can stream more data.
			if (writeBufferSize >= Programmer.MAX_WRITE_BUFFER_SIZE) {
				programmer.programWriteBuffer();
				writeBufferSize = 0;
			}
		}

		// We have some left-over bytes
		// to program in the write-buffer.
		if (writeBufferSize > 0)
			programmer.programWriteBuffer();
	}
	
	@Override
	protected void endProcessing() {
		// End of file, stop programming
		System.out.println("Finished program writing...");
	}
}
