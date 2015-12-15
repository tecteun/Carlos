package;

import neko.Lib;
import sys.net.Host;
import sys.net.Socket;

/**
 * ...
 * @author tecteun
 */
class Main 
{
	
	static function main() 
	{
		new PCAPParser("mycap.pcap");
		/*
		var s = new sys.net.Socket();
        s.bind(new sys.net.Host(Host.localhost()),5000);
        s.listen(1);
        trace("Starting server...");
        while( true ) {
            var c : sys.net.Socket = s.accept();
			
            var l = c.input.readAll();
            
            if( l.toString().length > 0 ) {
                trace(l.toString());
            }
        
            trace("Client connected...");
        
            c.close();
        }
		*/
    }
	
}