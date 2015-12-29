// ServerExample.hx
package ;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.Utf8;
import neko.Lib;
import neko.net.ThreadServer;
import sys.net.Socket;

#if neko


typedef Client = {
  var id : String;
  var socket:Socket;
  var state:STATE;
  var buffer:BytesBuffer;
}

typedef Message = {
  var str : String;
  var bytes:Bytes;
}

private enum STATE {
	handshake;
	request;
    forwarding;
}

/**
 * html socket server
 * https://github.com/tec27/node-argyle/blob/master/index.js
 * @see http://haxe.org/doc/neko/threadserver
 * @see http://code.google.com/p/haxe/source/browse/trunk/std/neko/net/ServerLoop.hx?r=3351
 */
class NekoSocketServer extends ThreadServer<Client, Message>
{
	private function handleSocksMessage(buffer:Bytes):Void {
		
	}
	
	
	// create a Client
	override function clientConnected( s : Socket ) : Client
	{
		var id:String = s.peer().host.toString() + ":" + s.peer().port;
		#if debug
			Lib.println("client " + id + " is " + s.peer());
		#end
		return { socket: s, id: id, state:STATE.handshake, buffer: new BytesBuffer() };
	}

	override function clientDisconnected( c : Client )
	{
		#if debug
			Lib.println("client " + Std.string(c.id) + " disconnected");
		#end
	}

	private var socksVersion:Int = 5;
	override function readClientMessage(c:Client, buffer:Bytes, pos:Int, len:Int)
	{
		c.buffer.add(buffer.sub(pos, len));
		Lib.println("buf " + c.buffer.length);
		Lib.println(pos);
		Lib.println(len);
		Lib.println(c.buffer);
		
		var retval:Message = null;
		switch(c.state) {
			case STATE.handshake	:	retval = handleConnection(c);
			case STATE.request		:	retval = handleRequest(c);
			case STATE.forwarding	: null;
			
		}
		if (retval != null) {
			c.buffer = new BytesBuffer();
			trace("full message");
			return { msg: retval, bytes: retval.bytes.length };
		}
		return null;
	}

	override function clientMessage( c : Client, msg : Message )
	{
		#if debug
			Lib.println(c.id + " sent: " + msg.str);
		#end
		onMessage(c, msg);
	}

	public dynamic function onMessage( c : Client, msg : Message  ) {
		
	}
	
	private function expandAndCopy(c:Client, ?buffer:Bytes = null):Bytes {
		var retval = buffer != null ? buffer : c.buffer.getBytes();
		c.buffer = new BytesBuffer();
		c.buffer.add(retval);
		return retval;
	}
	
	private function handleRequest(c:Client):Message {
		
		var buffer = expandAndCopy(c);
		if (buffer.length < 4) { return null; };
		
		var protocol:Int =  buffer.get(0);

		if (protocol != socksVersion) {
			c.socket.close();
		}

		var cmd = buffer.get(1);
		if(cmd != 0x01) {
			trace('unsupported command: $cmd');
			trace(buffer.toString());
			
			c.socket.output.writeByte(0x05);
			c.socket.output.writeByte(0x01);
			c.socket.output.flush();
			c.socket.close();
			return null;
		}
		var addressType:Int = buffer.get(3)
		, host:String = "undefined"
		, port:Int = -1
		, responseBuf;

		if(addressType == 0x01) { // ipv4
			if (buffer.length < 10) { return null; }; // 4 for host + 2 for port
			host = '${buffer.get(4)}.${buffer.get(5)}.${buffer.get(6)}.${buffer.get(7)}';
			port = buffer.getUInt16(8);
			responseBuf = Bytes.alloc(10);
			responseBuf.blit(0, buffer, 0, 10);
			buffer = buffer.sub(10, buffer.length - 10);
			trace('host $host');
		}
		else if (addressType == 0x03) { // dns
			if (buffer.length < 5) { trace("no length ");  return null; };// if no length present yet
			var addrLength = buffer.get(4);
			if (buffer.length < 5 + addrLength + 2) { trace("no hostprt");  return null; };// host + port
			host = Utf8.decode(buffer.getString(5, addrLength));
			var bi = new BytesInput(buffer, 5 + addrLength, 2);
			bi.bigEndian = true;			
			port = bi.readUInt16();
			responseBuf = Bytes.alloc(5 + addrLength + 2);
			responseBuf.blit(0, buffer, 0, 5 + addrLength + 2);

			buffer = buffer.sub(responseBuf.length, buffer.length - responseBuf.length );
			
		}
		else if(addressType == 0x04) { // ipv6

		} else {
			trace('unsupported address type: $addressType');
			c.socket.output.writeByte(0x05);
			c.socket.output.writeByte(0x01);
			//c.socket.output.flush();
			//c.socket.close();
			return null;
		}
trace('Request to $host $port');
		return  { str: buffer.toString(), bytes:buffer };
		//throw "Unhandled data '"+msg+"'";
	}
	
	private function handleConnection(c:Client):Message {
		var buf = expandAndCopy(c);
		var protocol:Int = buf.get(0);

		trace('Client Connect - Socks protocol v$protocol');
		if (protocol != socksVersion) {
			c.socket.close();
		}
		var nMethods = buf.get(1);
		trace('$nMethods encryption method');
		if (buf.length < nMethods + 2) { };//return;
		for(i in 0...nMethods) {
			// try to find the no-auth method type, and if found, choose it
			trace(buf.get(i + 2) == 0);
			if(buf.get(i+2) == 0) {
				c.socket.output.writeByte(0x05);
				c.socket.output.writeByte(0x00);
				c.socket.output.flush();
				c.state = STATE.request;
				if (buf.length > nMethods + 2) {
					
					var newChunk = buf.sub(nMethods + 2, buf.length - (nMethods + 2));
				
					expandAndCopy(c, newChunk);
					//handlemessage
					return handleRequest(c);
				}
				return { str: buf.toString(), bytes:buf };
			}
		}
		return null;
		
	}
	
	public function readUint16(buffer:Bytes, pos:Int):Int {
		var bit3 = buffer.get(pos);
		var bit2 = buffer.get(pos++);
		
		bit3 = bit3 << 8; 
		return bit2 + bit3;
	};

	public override function addSocket( s : Socket ) {
		//@see http://code.google.com/p/haxe/source/browse/trunk/std/neko/net/ServerLoop.hx?r=3351
		s.setBlocking(true);
		s.setFastSend(true);
		work(addClient.bind(s));
	}

}

#end
