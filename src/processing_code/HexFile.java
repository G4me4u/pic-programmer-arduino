import java.io.Reader;
import java.io.IOException;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.LinkedList;

public class HexFile {

	/** Hex file codes */
	public static final char HEX_ENTRY_CHARACTER = ':';

	public static final int EXTENDED_ADDRESS_TYPE = 0x04;
	public static final int DATA_TYPE = 0x00;
	public static final int END_OF_FILE_TYPE = 0x01;
	
	public final List<HexFileEntry> entries;
	public int numDataBytes;
	public int parsedLines;
	
	public HexFile(Reader reader) throws IOException {
		entries = new LinkedList<HexFileEntry>();
		readHexFile(reader);
		packHexFile();
	}

	public void packHexFile() {
		List<HexFileEntry> packedEntries = new LinkedList<HexFileEntry>();
		// Used to temp store data-entries
		List<HexFileEntry> dataEntries = new LinkedList<HexFileEntry>();

		int address = -1;
		int numDataBytes = 0;
		
		Iterator<HexFileEntry> iterator = entries.iterator();
		while (iterator.hasNext()) {
			// Count the number of bytes
			// of data we have in a row.
			HexFileEntry entry;
			while ((entry = iterator.next()).recordType == DATA_TYPE) {
				if (address == -1 || address == entry.address) {
					// Add entry to temp data-row
					dataEntries.add(entry);
					numDataBytes += entry.numBytes;
					// The address will be 
					// incremented by one each
					// time we have a byte.
					address = entry.address + entry.numBytes;
				} else {
					// The two data-entries are
					// not in line. The address
					// of the last byte in the
					// first entry does not match
					// the address of the first
					// byte in the second entry.
					break;
				}
			}

			// Pack the actual data in the
			// row that was counted.
			if (!dataEntries.isEmpty()) {
				// Copy the data-entry data into
				// a single array.
				byte[] packedData;
				if (dataEntries.size() > 1) {
					// We have more than a single
					// entry. We can't just reuse
					// The same entry.
					packedData = new byte[numDataBytes];
					int bc = 0;
					for (HexFileEntry dataEntry : dataEntries) {
						System.arraycopy(dataEntry.data, 0, packedData, bc, dataEntry.numBytes);
						bc += dataEntry.numBytes;
					}
					int addr = dataEntries.get(0).address;
					packedEntries.add(new HexFileEntry(numDataBytes, addr, DATA_TYPE, packedData));
				} else {
					packedEntries.add(dataEntries.get(0));
				}

				// Invalidate temp data-row
				dataEntries.clear();
				numDataBytes = 0;
				address = -1;
			}

			// Check out left-over entry
			if (entry.recordType != DATA_TYPE) {
				// We are working with a non-data
				// entry. We can't pack it.
				packedEntries.add(entry);
				continue;
			}

			// We have more data to pack
			
			// The data is the last entry
			// in this hex-file. Reuse it.
			if (!iterator.hasNext()) {
				packedEntries.add(entry);
				break;
			}

			// We have to pack more data
			// which may be in a row. Add
			// the entry to the temp list.
			dataEntries.add(entry);
			numDataBytes = entry.numBytes;
			address = entry.address + entry.numBytes;
		}

		// Replace all entries with
		// the new ones.
		entries.clear();
		entries.addAll(packedEntries);
	}
	
	public void readHexFile(Reader reader) throws IOException {
		if (!entries.isEmpty())
			entries.clear();
		// We start at line 1
		parsedLines = 1;
		
		int input;
		boolean wasNewline = false;
		while ((input = reader.read()) != -1) {
			switch((char)input) {
			case HEX_ENTRY_CHARACTER:
				wasNewline = false;
				entries.add(readEntry(reader));
				break;
			
			case '\n':
			case '\r':
				if (!wasNewline) {
					wasNewline = true;
					parsedLines++;
				}
				break;
			
			default:
				wasNewline = false;
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
		
		HexFileEntry entry = new HexFileEntry(numBytes, address, recordType, data);

		if (entry.calculateChecksum() != checksum)
			throw new IOException("Invalid hex file");
		
		return entry;
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
