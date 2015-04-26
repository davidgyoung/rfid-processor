=begin rdoc

=Alien Ruby RFID Library Examples
==ex_hello_world.rb	

A "Hello World" application using the Alien RFID Library for Ruby.
Uses the AlienReader.open command with default values for port, username and password. 

(Change the "reader_ip_address" parameter in your config.dat file to the one appropriate for your reader.)

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'

begin
#grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")

# create the new reader
	r = AlienReader.new

	puts "----------------------------------"

# open a connection to the reader and get the reader's name.
#	if r.open( config["reader_ip_address"]) # will work if you have default settings for un, pw, port...
	if r.open( config["reader_ip_address"], config["port"], config["username"], config["password"] )
		puts "Hello World! I am #{r.readername}."
	end

	puts "----------------------------------"
	
# close the connection.
	r.close

rescue
# print out any errors
	STDERR.puts $!
end
