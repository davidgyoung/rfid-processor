=begin rdoc

=Alien Ruby RFID Library Examples
==ex_command_line_interface.rb

Here we roll our own command-line interface to the reader. 
Similar to what you'd find if you used telnet. 
The sendreceive method may be found in the AlienConnection class AlienReader inherits from.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'

begin
# grab parameters out of a configuration file
	config = AlienConfig.new("config.dat")

# change "reader_ip_address" in the config.dat file to the IP address of your reader.
	ipaddress = config["reader_ip_address"]

# create the new reader
	r = AlienReader.new

	puts "----------------------------------"

# open a connection to the reader and get the reader's name.
	if r.open(ipaddress)
		print "Connected to: #{r.readername}.\r\n"

		while r.connected
			begin	
				print "Ruby CLI >"
				STDOUT.flush				
				instr = gets.strip

			# the false option causes the reader not to raise a runtime error 
			# when it returns "Error:..." but just pass the message along.
				r.raise_errors = false

				s = r.sendreceive(instr).strip 
				print s +"\r\n"	    
			end
		end
	end

	puts "----------------------------------"

# close the connection.
	r.close

rescue
# print out any errors at the top level
	puts $!
end
