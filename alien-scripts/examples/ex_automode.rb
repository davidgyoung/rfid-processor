=begin rdoc

=Alien Ruby RFID Library Examples
==ex_automode.rb

The reader supports a simple state machine to control when it reads tags and 
reports data to hosts. When "automode" is "on", the state machine is active. 
Using Automode is the best way to ensure reliable, low-latency tag reads. 
This example shows how to set up automode for continuous reading for three seconds.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'

begin
# grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")

# change "reader_ip_address" in the config.dat file to the IP address of your reader.
	ipaddress = config["reader_ip_address"]
	puts ipaddress
# create our reader 
	r = AlienReader.new

	if r.open(ipaddress)    
		puts "----------------------------------"
		puts 'Connected to ' + r.readername	
		puts 'Automode is: '+ r.automode
		puts 'Setting up to read Gen2 Tags...'
		r.tagtype ='16'
		r.autoaction = 'acquire'
		r.autostarttrigger='0 0'
		r.automode='on'
		puts 'Reading...'	
		sleep (3)		
		puts "...Done!"
		puts 'Tags Found:'
		puts r.taglist
		r.automode='off'
		puts "----------------------------------"
		
	# be nice. Close the connection to the reader.
		r.close
	end
rescue
	puts $!
end
