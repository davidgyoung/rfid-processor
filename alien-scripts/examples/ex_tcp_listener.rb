=begin rdoc

=Alien Ruby RFID Library Examples
==ex_tcp_listener.rb	

This is a simple server that accepts connections on a socket and prints out 
data that comes in on the connection.

Messages are assumed to be null-terminated strings. On receiving a null, 
the server shuts down the connection and goes back to listening on 
the port defined in config.dat.

Use this example in conjunction with ex5b_taglist_with_notify.rb. 
First run this program on your local machine and then run ex5b on 
the same machine to see notification messages.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib") 

require 'socket'
require 'alienconfig'

begin
# grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")

	tcp_listner_address = "localhost"
	tcp_listner_port    = config["tcp_listner_port"].to_i

	server = TCPServer.new(tcp_listner_address, tcp_listner_port)

	while (session = server.accept)
		puts '---------------------------------------'
		data =""
		until (data.include? "\0") 
			data<< session.recv(100)
		end
		puts data.strip
		puts '---------------------------------------'
		session.close
	end

rescue 
	puts $!
end
