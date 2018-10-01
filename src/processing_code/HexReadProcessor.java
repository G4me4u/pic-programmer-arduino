
public class HexReadProcessor extends HexProcessor {
	
	public HexReadProcessor(Programmer programmer, boolean twoBytesPerAddress, HexFile hex) {
		super(programmer, twoBytesPerAddress, hex);
	}
	
	@Override
	public void processHexFile() {
		System.out.println("Beginning program verifying " + hex.numDataBytes + " bytes...");
		
		programmer.beginReading();
		super.processHexFile();
		programmer.endReading();
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
		
		int incrementer = twoBytesPerAddress ? 2 : 1;
		for (int i = 0; i < numBytes; i += incrementer) {
			int programmedWord = programmer.readProgramWord();
			
			if (twoBytesPerAddress) {
				int hexWord = MemoryUtil.bytesToUnsignedShortSecure(data, i, false);
				
				if (programmedWord != hexWord)
					throw new ProgrammingException("Program data: " + Integer.toHexString(programmedWord) + " at address " + 
					                               Integer.toHexString(address + (i >>> 1)) + " does not match hex: " + Integer.toHexString(hexWord));
			} else {
				programmedWord &= 0xFF;
				int hexWord = data[i] & 0xFF;

				if (programmedWord != hexWord)
					throw new ProgrammingException("Program data: " + Integer.toHexString(programmedWord) + " at address " + 
					                               Integer.toHexString(address + i) + " does not match hex: " + Integer.toHexString(hexWord));

			}
		}
	}
	
	@Override
	protected void endProcessing() {
		// End of file, stop reading
		System.out.println("Finished program verifying...");
	}
}
