package;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesData;
import haxe.io.BytesInput;
import sys.io.File;
import sys.io.FileInput;

/**
 * https://github.com/kunklejr/node-pcap-parser/blob/master/lib/pcap-parser.js
 * @author tecteun
 */
enum Endianness {
	BIG_ENDIAN;
	LITTLE_ENDIAN;
}
 
class PCAPParser
{
	private var GLOBAL_HEADER_LENGTH:Int = 24; //bytes
	private var PACKET_HEADER_LENGTH:Int = 16;
	private var stream:FileInput;
	private var buffer:BytesBuffer = null;
	private var endianness:Endianness = BIG_ENDIAN;
	private var state:Void->Void;
	public function new(input:String) 
	{
		this.buffer = new BytesBuffer();
		this.stream = File.read(input, true);
		this.state = parseGlobalHeader;
		this.endianness = null;
		while (!stream.eof()) {
			var d = stream.readAll(); 
			trace(d.length);
			buffer.add(d);
			//this.state();
		}
		parseGlobalHeader();
	}
	
	private function parseGlobalHeader():Void {
		if (this.buffer.length >= GLOBAL_HEADER_LENGTH) {
			var buffer = new BytesInput(buffer.getBytes());
			buffer.bigEndian = true;
			buffer.position = 0;
			var b:Bytes = Bytes.alloc(4);
			buffer.readBytes(b, 0, 4);
			var magicNumber:String = b.toHex();
			// determine pcap endianness
			if (magicNumber == "a1b2c3d4") {
			  this.endianness = BIG_ENDIAN;
			} else if (magicNumber == "d4c3b2a1") {
			  this.endianness = LITTLE_ENDIAN;
			} else {
			  trace('unknown magic number: 0x$magicNumber');
			  return;
			}
			
			//var msg, magicNumber = buffer.
			var header = {
			  magicNumber: readUint32(buffer, 0),
			  majorVersion:  readUint16(buffer, 4),
			  minorVersion:  readUint16(buffer, 6),
			  gmtOffset: readUint32(buffer, 8),
			  timestampAccuracy: readUint32(buffer, 12),
			  snapshotLength: readUint32(buffer, 16),
			  linkLayerType: readUint32(buffer, 20)
			};
			buffer.position = 8;
			
			trace(header.majorVersion);
		}
	}
	
	public function readUint32(buffer:BytesInput, pos:Int):Int {
		buffer.position = pos;
		var bit0 = buffer.readByte();
		var bit1 = buffer.readByte();
		var bit2 = buffer.readByte();
		var bit3 = buffer.readByte();
		
		bit0 = bit0 << 24; bit1 = bit1 << 16; bit2 = bit2 << 8; 
		return bit0 + bit1 + bit2 + bit3;
	};

	public function readUint16(buffer:BytesInput, pos:Int):Int {
		buffer.position = pos;
		var bit2 = buffer.readByte();
		var bit3 = buffer.readByte();
		
		bit2 = bit2 << 8; 
		return bit2 + bit3;
	};
	
}