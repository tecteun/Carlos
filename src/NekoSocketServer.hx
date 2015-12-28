// ServerExample.hx
package ;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import neko.Lib;
import neko.net.ThreadServer;
import sys.net.Socket;

#if neko


typedef Client = {
  var id : String;
  var socket:Socket;
  var state:STATE;
  var buffer:BytesOutput;
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
		return { socket: s, id: id, state:STATE.handshake, buffer: new BytesOutput() };
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
		var buf = buffer.sub(pos, len);
		// find out if there's a full message, and if so, how long it is.
		return { msg: { str: buf.toString(), bytes:buf }, bytes: buf.length };
	}

	override function clientMessage( c : Client, msg : Message )
	{
		#if debug
			Lib.println(c.id + " sent: " + msg.str);
		#end
		onMessage(c, msg);
	}

	public dynamic function onMessage( c : Client, msg : Message  ) {
		switch(c.state) {
			case STATE.handshake	:	handleConnection(c, msg);
			case STATE.request		:	handleRequest(c, msg);
			case STATE.forwarding	: null;
			
		}
	}
	
	private function handleRequest(c:Client, msg:Message):Void {
		trace(msg.bytes + " " + msg.bytes.length);
		c.buffer.write(msg.bytes);
		var buffer = c.buffer.getBytes();
		if (buffer.length < 4) { return; };
		
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
			return;
		}
		var addressType:Int = buffer.get(3)
		, host:String
		, port
		, responseBuf;

		if(addressType == 0x01) { // ipv4
			if (buffer.length < 10) { return;} // 4 for host + 2 for port
			host = '${buffer.get(4)}.${buffer.get(5)}.${buffer.get(6)}.${buffer.get(7)}';
			port = buffer.getUInt16(8);
			responseBuf = Bytes.alloc(10);
			responseBuf.blit(0, buffer, 0, 10);
			buffer = buffer.sub(10, buffer.length - 10);
			trace('host $host');
		}
		else if(addressType == 0x03) { // dns

		}
		else if(addressType == 0x04) { // ipv6

		} else {
			trace('unsupported address type: $addressType');
			c.socket.output.writeByte(0x05);
			c.socket.output.writeByte(0x01);
			c.socket.output.flush();
			c.socket.close();
			return;
		}


		//throw "Unhandled data '"+msg+"'";
	}
	
	private function handleConnection(c:Client, msg:Message):Void {
		c.buffer.writeBytes(msg.bytes, 0, msg.bytes.length);

		var buf = c.buffer.getBytes();
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
					trace(newChunk.length);
					//handlemessage
					return null;// { msg: { str: newChunk.toString(), bytes:newChunk }, bytes: newChunk.length };
				}else {
				}
			}
		}
		
	}

	public override function addSocket( s : Socket ) {
		//@see http://code.google.com/p/haxe/source/browse/trunk/std/neko/net/ServerLoop.hx?r=3351
		s.setBlocking(true);
		s.setFastSend(true);
		work(addClient.bind(s));
	}

}

#end
