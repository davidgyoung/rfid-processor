=begin rdoc

=Alien Ruby RFID Library Examples
==ex_udp_listener.rb	

This is a simple server that accepts connections on a UDP socket and prints out 
data that comes in on the connection.

An entire packet of data, upto 4096 bytes is received and then printed to the screen.

Use this example in conjunction with ex_taglist_with_UDP_notify.rb. 
First run this program on your local machine and then 
run ex_taglist_with_udp_notify on the same machine to see notification messages.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienconfig'
require 'socket'

begin
# grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")

	port = config["udp_listner_port"]

	puts "----------------------------------"
	puts 'UDP Listener Active (ctl-c = exit)'
	puts "----------------------------------"

	server = UDPSocket.open
	server.bind('', port) #first param is hostname, second is port.

# spin forever...
	loop {
	# wait for data...
		puts server.recvfrom(4096)
		puts "----------------------------------"
	}

rescue 
  puts $!
end
