=begin rdoc

=Alien Ruby RFID Library Examples
==ex_io.rb

The Alien RFID reader has two GPIO ports -- one for input and the other for output. 
This example shows how to read data from and write data to the ports.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

#Add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'

begin
# grab parameters out of a configuration file
	config = AlienConfig.new("config.dat")

# change "reader_ip_address" in the config.dat file to the IP address of your reader.
	ipaddress = config["reader_ip_address"]

# create our reader 
	r = AlienReader.new

# connect to the reader
	if r.open(ipaddress)
		puts "----------------------------------"
		puts 'Connected to ' + r.readername	

	#read input and init variables
		dig_in     = r.gpio.to_i
		old_dig_in = dig_in

		puts 'Initial input state: ' + dig_in.to_s

		done = false

	# spin here until the input changes to zero.	
		until done		
		  dig_in = r.gpio.to_i

			if dig_in != old_dig_in
				puts "Digital input Changed to: " + dig_in.to_s
				if dig_in == 0
					done = true
				else
					dig_out = dig_in

			# set the output to match the input...
					r.gpio = dig_out.to_s
				end		
			end

			old_dig_in = dig_in

		# wait a bit before going around again...
			sleep 0.25
		end

		puts "----------------------------------"	

	# be nice. Close the connection to the reader.
		r.close

		puts 'Dig in changed to zero! We\'re done'
	end

rescue
	puts $!
end
