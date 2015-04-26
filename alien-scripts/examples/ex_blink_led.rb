=begin rdoc

=Alien Ruby RFID Library Examples
==ex_blink_led.rb

The LEDS on the reader may be flashed using the reader.blink_led command. 
This can be useful for diagnostics when a display is not available.

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

# create our reader 
	r = AlienReader.new

  if r.open(ipaddress)
		puts "----------------------------------"
		puts 'Connected to ' + r.readername	

		state1 = 0
		state2 = 1
		duration = 100
		count = 5

		puts 'LED Sweep...'
		while state2 < 255
			r.blinkled(state1,state2,duration,count)
			state2*=2
		end

		puts 'LED Flash...'
		state2 = 255
		r.blinkled(state1,state2,duration,count)

		puts "----------------------------------"

	# be nice. Close the connection to the reader.
		r.close
  end
rescue
	puts $!
end
