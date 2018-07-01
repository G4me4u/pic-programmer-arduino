
public abstract class HexProcessor {
	
	protected final Programmer programmer;
	protected final boolean twoBytesPerAddress;
	protected final HexFile hex;
	
	public HexProcessor(Programmer programmer, boolean twoBytesPerAddress, HexFile hex) {
		this.programmer = programmer;
		this.twoBytesPerAddress = twoBytesPerAddress;
		this.hex = hex;
	}
	
	public void processHexFile() {
			program_loop: for (HexFileEntry entry : hex.entries) {
				switch (entry.recordType) {
				case HexFile.EXTENDED_ADDRESS_TYPE: // 0x04
					extendedAddress(MemoryUtil.bytesToUnsignedShortSecure(entry.data, 0, true));
					break;
				case HexFile.DATA_TYPE: // 0x00
					programData(entry.address, entry.data, entry.numBytes);
					break;
				case HexFile.END_OF_FILE_TYPE: // 0x01
					endProcessing();
					break program_loop;
				}
			}
	}
	
	protected abstract void extendedAddress(int extendedAddress);
	
	protected abstract void programData(int address, byte[] data, int numBytes);
	
	protected abstract void endProcessing();
}
