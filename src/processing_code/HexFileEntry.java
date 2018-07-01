import java.util.Arrays;

public class HexFileEntry {
	
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

	public byte calculateChecksum() {
		byte check = 0;
		
		check += (byte)numBytes;
		// Address is two bytes
		check += (byte)(address >> 0);
		check += (byte)(address >> 8);
		check += (byte)recordType;

		int i = numBytes;
		while (i-- > 0)
			check += data[i];

		// Checksum is two's complement
		return (byte)((byte)(~check) + 1);
	}
	
	@Override
	public String toString() {
		return String.format("\n[%d, %d, %d, %s]", numBytes, address, recordType, Arrays.toString(data));
	}
}
