=begin rdoc

=Alien Ruby RFID Library Examples
==ex_get_taglist.rb

An example program to play with taglists. 

* Connect to an Alien RFID reader. Login.
* Grab some tag data.
* Scan the data for interesting tags and display the results.

Copyright 2008, Alien Technology Corporation. All rights reserved.

=end

#Add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alientag'
require 'alienconfig'

# A little regular expression scanner. Looks at a list of tags and returns a message 
# containing those tag IDs that match a particular regular expression filter.
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

# ...and build an array of tag objects
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

# create a reader
	r = AlienReader.new

# create a tag list
	tl = Array.new 

# use your reader's IP address here.
	if r.open(ipaddress)
		puts "----------------------------------"
		puts 'Connected to: ' + r.readername

	# construct a taglist from the reader's tag list string
	# Note: if automode is running this will contain the latest tags. --If not,
	# the reader will read tags and then return the data.

		tl = build_tag_array(r.taglist)

	# how many tags did we find?
		puts "Number of tags found: " + tl.length.to_s

		p tl

	# sort your list to make reading easier. 
	# (The comparison operator <=>, used by sort, is part of the Tag class in alientag.rb)
		tl.sort!

	# did we find a particular tag(s)? You can use a regular expression to check if
	# elements in the list are tags that match what you are interested in.
		puts 'Tag List Matches:'
		puts "Tag #\tTag ID"

		msg = filter_tags(tl, /.*/)#/A5.*2.*1/)

		puts msg
		puts "----------------------------------"

	# be nice. Close the connection.
		r.close
	end
rescue 
	puts $!
end
