=begin rdoc

=Alien Ruby RFID Library Examples
==ex_taglist_with_UDP_notify.rb

An example program to play with taglists. 

* Connect to an Alien RFID reader. Login.
* Grab some tag data.
* Scan the data for interesting tags and display the results.
* Send the interesting data to someone else over a UDP socket connection. 
Use ex5d_UDP_listener.rb as the destination. 
(both applicatons should be running on the same machine)

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alientag'
require 'alienconfig'
require 'socket'

# Send a message to a server running at an IP address on a particular port.
def notify(msg)
# grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")

	ipaddress = config["udp_listner_address"]
	port      = config["udp_listner_port"]

	begin
		sock = UDPSocket.open
		sock.connect(ipaddress,port)
		sock.send(msg+"\0",0,ipaddress,port)
		sleep 1
		sock.close
	rescue
		puts $!
	end
end

# Scan an array of tag list entries for matches to a regular expression. Append matching tags to a string.
def filter_tags(tl, filter)
	i=0
	msg = ""
	tl.each do |tag|
		if tag.id =~ filter 
			msg <<( i.to_s + "\t" + tag.id + "\r\n")
		end
		i+=1
	end
	return msg
end

# Takes a string returned from a Taglist function call and builds an array of tags.
def build_tag_array(taglist_string)
	tl = Array.new 

# grab the taglist from the reader, split it into individual line entries...
	lines = taglist_string.split("\r\n")

#...and build an array of tag objects
	lines.each do |line|
		if line =="(No Tags)" 
			tl = []
		else
			tl.push(AlienTag.new(line))
		end    
	end  
	return tl  
end

begin
# grab various parameters out of a configuration file
	config = AlienConfig.new("config.dat")
  
# change "reader_ip_address" in the config.dat file to the IP address of your reader.
	ipaddress = config["reader_ip_address"]

# create a reader. 
	r = AlienReader.new

# our tag list
	tl = Array.new 
  
# use your reader's IP address here.
	if r.open(ipaddress)
		puts "----------------------------------"
		puts 'Connected to: ' + r.readername

	# construct a taglist from the reader's tag list string
		tl = build_tag_array(r.taglist)

	# how many tags did we find?
		puts "Number of tags found: " + tl.length.to_s

	# sort your list to make reading easier. 
	# (the comparison operator <=>, used by sort, is part of the Tag class)
		tl.sort!

	# did we find a particular tag(s)? You can use a regular expression to check if
	# elements in the list are tags that match what you are interested in.
		puts 'Tag List Matches:'
		puts "Tag #\tTag ID"

		msg = filter_tags(tl, /.*/)#/A5.*2.*1/)
		print msg
		
	# tell someone about what we saw! 
		notify(msg)

		puts "----------------------------------"

	#be nice. Close the connection to the reader.
		r.close
	end
rescue 
	puts $!
end
