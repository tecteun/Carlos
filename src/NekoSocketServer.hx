// ServerExample.hx
package ;
import haxe.io.Bytes;
import neko.Lib;
import neko.net.ThreadServer;
import sys.net.Socket;

#if neko


typedef Client = {
  var id : String;
  var socket:Socket;
}

typedef Message = {
  var str : String;
  var bytes:Bytes;
}

/**
 * html socket server
 * https://github.com/tec27/node-argyle/blob/master/index.js
 * @see http://haxe.org/doc/neko/threadserver
 * @see http://code.google.com/p/haxe/source/browse/trunk/std/neko/net/ServerLoop.hx?r=3351
 */
class NekoSocketServer extends ThreadServer<Client, Message>
{
	
	
	
  // create a Client
  override function clientConnected( s : Socket ) : Client
  {
    var id:String = s.peer().host.toString() + ":" + s.peer().port;
	#if debug
    Lib.println("client " + id + " is " + s.peer());
	#end
    return { socket: s, id: id };
  }

  override function clientDisconnected( c : Client )
  {
	#if debug
    Lib.println("client " + Std.string(c.id) + " disconnected");
	#end
  }

  private var socksVersion:Int = 5;
  override function readClientMessage(c:Client, buf:Bytes, pos:Int, len:Int)
  {
    // find out if there's a full message, and if so, how long it is.
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
        if (buf.length > nMethods + 2) {
          var newChunk = buf.sub(nMethods + 2, buf.length - (nMethods + 2));
		  
          trace(newChunk.toString());
          
        }else {
		
		}
       // return;
      }
    }

			
	
	var complete = false;
    var cpos = pos;
	var eofMsg = Bytes.ofString("\r\n\r\n");
	var eofMsgMatch = 0;
    while (cpos < (pos+len) && !complete)
    {
		if(buf.get(cpos) == eofMsg.get(eofMsgMatch))
		{
			eofMsgMatch++;
		}
		else
		{
			eofMsgMatch = 0;
		}

		if (eofMsgMatch == eofMsg.length)
		{
			complete = true;
		}
		//"\r\n" 14 10
		//trace(buf.compare(eofMsg) + " " + buf.length);
		//complete = buf.compare(eofMsg) > -1;//buf.toString().indexOf("\r\n\r\n") > -1;//(buf.get(cpos) == 46);
		cpos++;
    }

    // no full message
    if ( !complete ) return null;

    // got a full message, return it
    var msg:String = buf.getString(pos, cpos - pos);
	
	var contentlength:Int = 0;
	var hascontentlength = msg.toLowerCase().indexOf("content-length");
	if (hascontentlength > -1)
	{
		var nl:Int = 0;
		while (msg.charAt(hascontentlength + nl) != "\r" && msg.charAt(hascontentlength + nl + 1) != "\n")
		{
			nl < 30 ? nl++ : break;
		}
		contentlength = Std.parseInt(buf.getString(hascontentlength, nl).split(":")[1]);
		
		if (cpos - pos + contentlength > len)
		{	//incomplete message, retry later for it
			return null;
		}
		
		msg = buf.getString(pos, cpos - pos + contentlength);
	}

    return { msg: { str: msg, bytes: buf.sub(pos, cpos - pos + contentlength) }, bytes: cpos - pos + contentlength };
	//return {msg: {str: buf.readString(pos, len)}, bytes: 1};
  }

  override function clientMessage( c : Client, msg : Message )
  {
	#if debug
    Lib.println(c.id + " sent: " + msg.str);
	#end
	onMessage(c, msg);
  }
  
  public dynamic function onMessage( c : Client, msg : Message  ) {
		trace(msg);
	  //throw "Unhandled data '"+msg+"'";
  }

  public override function addSocket( s : Socket ) {
	  //@see http://code.google.com/p/haxe/source/browse/trunk/std/neko/net/ServerLoop.hx?r=3351
		s.setBlocking(true);
		s.setFastSend(true);
		work(addClient.bind(s));
	}

}

#end
