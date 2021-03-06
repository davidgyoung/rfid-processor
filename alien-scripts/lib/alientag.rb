=begin rdoc
=Alien Ruby RFID Library 
==alientag.rb	

A simple class to hold taglist data elements. Allows construction of Tag objects from taglist entries. (The format of strings handled by the 'create' method is assumed to be compatible with Alien's 'text' taglist format.)

Copyright 2007, Alien Technology Corporation. All rights reserved.
=end

require 'date'

# A storage class for RFID tag data elements.
class AlienTag

	#By mixing in Comparable we can easily sort arrays of tags.
	include Comparable

	attr_accessor :id    # EPC code of the tag that was read
	attr_accessor :ant   # Antenna on which the last read was made
	attr_accessor :count # Number of times the tag has been read since discovery
	attr_accessor :disc  # Time of discovery
	attr_accessor :last  # Time of latest read
	attr_accessor :proto # Protocol used to read the tag. A bit map where Gen2 = 16.
	   
	attr_accessor :rssi
	attr_accessor :speed
	attr_accessor :freq  #:nodoc:

# Populate the instance variables from a taglist entry string.
# The following field separators are supported in the taglist entry string:
#  'tag:', 'disc:', 'last:', 'count:', 'ant:', 'proto:', 'speed:', 'rssi:'
	def initialize(taglist_entry)
		@disc = @last  = @last_last = 0
		@ant  = @count = @proto = @rssi = @speed = @freq = 0
		@speed_smooth  = @speed_last = 0
		@pos_smooth    = @pos_last = @pos_min = 0
		
		create(taglist_entry)
	end

# (*Deprecated*) Returns tag *id*.
#
# This method is for backward compatibility with an earlier version of this API.
# Use _id_ instead.
	def tag
		@id
	end

# (*Deprecated*) Sets tag *id*.
#
# This method is for backward compatibility with an earlier version of this API.
# Use <i>id=</i> instead.
	def tag=(val)
		@id = val
	end

# Return the contents of the tag object as a string (returns tag *id* as a string) 
	def inspect
		@id.to_s
	end

# The 'spaceship' operator allows us to compare tags for sorting, etc.
	def <=>(s)
		@id <=> s.id
	end

# Returns a printable version of the tag object (returns tag *id* as a string) 
	def to_s
		@id.to_s
	end

# Try to parse a taglist entry into a set of Tag object variables.
#
# Uses a simple mapping from Alien 'text' format:
#
#  Tag:0102 0304 0506 0708 0900 0A0B, Disc:2008/10/28 10:49:35, Last:2008/10/28 10:49:35, Count:1, Ant:3, Proto:2
#
# *rssi* and *speed* attributes are not included in the default text format.
# In order to have them parsed correctly the _TagListFormat_ must be set to _custom_ and
# the _TagListCustomFormat_ fields must be separated by the following text tokens:
#
#  'tag:', 'disc:', 'last:', 'count:', 'ant:', 'proto:', 'speed:', 'rssi:'
#
# For example: 
#
#  @rdr.taglistcustomformat("Tag:%i, Disc:${DATE1} ${TIME1}, Last:${DATE2} ${TIME2}, Count:${COUNT}, Ant:${TX}, Proto:${PROTO#}, Speed:${SPEED}, rssi:${RSSI})"
#  @rdr.taglistformat("custom")
	def create(taglist_entry)
		@id = ""    
		return self if (taglist_entry=="(No Tags)")

		tagline = taglist_entry.split("\r\n")[0]
		tagbits = Hash.new("0")

		tagline.split(", ").each do |keyval|
			key, val = keyval.split(":", 2)
			if key.nil? 
				raise "Trouble parsing taglist string. Text format expected. This string was: #{taglist_entry}"
			end
			tagbits[key.downcase] = val
		end

		if (!tagbits.empty?)
			#zero length ids can cause funny behavior
			if tagbits['tag'] != nil
				@id = tagbits['tag']
			end

			@ant       = tagbits['ant']
			@count     = tagbits['count']
			@disc      = tagbits['disc']
			@last      = DateTime.parse(tagbits['last'])
			@last_last = @last
			@proto     = tagbits['proto']
			@rssi      = tagbits['rssi']
			@freq      = tagbits['freq']
			@speed     = tagbits['speed']
		end
		return self
	end

# Updates an existing tag object from the new one by incrementing the *count* and setting the new *last* time
	def update(new_tag)
		# Copy the last timestamp and increment the counts
		@last      = new_tag.last
		@count    += new_tag.count
		@last_last = @last
=begin
		# Update the speed, smooth it, calculate distance
		dt = (@last - @last_last) * 86400.0
		smooth_coef   = 5
		smooth_factor = Math.exp(-smooth_coef*dt)
		thresh_zero1  = -0.01 # Any speeds between these thresholds are considered 0
		thresh_zero2  = +0.01
		puts
		#printf("\ndt=%0.000010f, smooth_factor(init)=%0.00005f\n", dt, smooth_factor)

		# Update the speed, smooth out jitter
		@speed = new_tag.speed
		if @speed.to_f > thresh_zero1 && @speed.to_f < thresh_zero2
		#	@speed = 0
		end

		#printf("speed_smooth(initial)=%+0.003f\n", @speed_smooth)
		@speed_smooth = @speed_smooth*smooth_factor + @speed.to_f*(1 - smooth_factor)
		@pos_last     = @pos_smooth
		@pos_smooth  += @speed_last * dt/1000
		@speed_last   = @speed_smooth

		printf("speed=%+0.003f", @speed.to_s)
		printf(", speed_smooth=%+0.003f", @speed_smooth.to_s)
		printf(", pos=%+0.005f\n", @pos_smooth.to_s)

		# Update new pos_min, if needed
		@pos_min = @pos_smooth if (@pos_smooth < @pos_min)
		printf("pos_last=%+0.5f, pos_min=%0.5f\n", @pos_last.to_s, @pos_min.to_s)
		# If last position was the min and tag is moving away --> TopDeadCenter
		if @pos_last == @pos_min && @pos_smooth > @pos_last
			puts "********************************************"
		end
=end				
	end
end
