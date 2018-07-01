
public final class MemoryUtil {
	
	private MemoryUtil() {
	}
	
	public static int bytesToUnsignedShort(byte[] data, int offset, boolean bigEndian) {
		if (bigEndian)
			return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
		return ((data[offset + 1] & 0xFF) << 8) | (data[offset] & 0xFF);
	}
	
	public static int bytesToUnsignedShortSecure(byte[] data, int offset, boolean bigEndian) {
		if (bigEndian)
			return (getByteSecure(data, offset) << 8) | getByteSecure(data, offset + 1);
		return (getByteSecure(data, offset + 1) << 8) | getByteSecure(data, offset);
	}
	
	public static int getByteSecure(byte[] data, int offset) {
		if (offset < 0)
			return 0xFF;
		if (data == null || offset >= data.length)
			return 0xFF;
		return data[offset] & 0xFF;
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