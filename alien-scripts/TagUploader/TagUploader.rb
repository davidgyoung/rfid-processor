# Add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'
require 'alientag'
require 'net/http'

@utid_cache ={}

def logfile
  @logfile ||= File.open("./uploader.log", "a")
end

def log(line)
  puts line
  logfile.puts("#{Time.now} #{line}") 
  logfile.flush
end

def post_data(json)
  uri = URI.parse("http://ancient-reaches-8047.herokuapp.com")
  connection = Net::HTTP.new(uri.host, uri.port)
  connection.start do |http|
    request = Net::HTTP::Post.new("/tags")
    request.body = json
    request['Content-Type'] = 'application/json'
    http.request(request)
  end                
end

# rails generate scaffold Tag tag_id:string rssi:integer, antenna:string, last_seen_at:date
def to_json(tag, utid)
  json =  <<JSONEND
  { 
    "tag_id": "#{tag.id}",
    "utid": "#{utid}",
    "rssi": "#{tag.rssi}",
    "antenna": "#{tag.ant}",
    "last_seen_at": "#{tag.last}"
  }
JSONEND
end

def parse_tags(taglist_string)
  tags = []
  if taglist_string != "(No Tags)"
    lines = taglist_string.split("\r\n")
    lines.each do |line|
      log "line is #{line.inspect}"
      tags << AlienTag.new(line)
      log "adding a new tag"
    end
    log "done parsing with tag count: #{tags.size}"
  end
  tags
end

def utid_for_tag(reader, tag)
  return @utid_cache[tag.id] if @utid_cache[tag.id]
  tagbytes=tag.id.gsub(" ","")
  tag_byte_length = tagbytes.length/2
  tag_bit_length = tag_byte_length*8
  tagbytes_comma_separated = tagbytes.gsub(/(.{2})(?=.)/, '\1,\2')
  puts "tag id as bytes is #{tagbytes}"
  mask = "1,32,#{tag_bit_length},#{tagbytes_comma_separated}"
  puts "mask=#{mask}"
  reader.acqg2mask(mask) # Enter mask
  sleep(1)
  begin
    @utid_cache[tag.id] = reader.g2read("1 0 2")  # Read TID data
  rescue
    puts "error: #{$!}"
    retry # I do not know why this fails so often with Error 154: Read error.
  end
end

def scan_init(reader)
  log "initializing aquire parameters"
  
  # Note:  The following both time out
  #reader.taglistcustomformat("Tag:%i, Disc:${DATE1} ${TIME1}, Last:${DATE2} ${TIME2}, Count:${COUNT}, Ant:${TX}, Proto:${PROTO#}, Speed:${SPEED}, rssi:${RSSI}")
  #reader.taglistcustomformat('Tag:%i, Disc:%d %t, Last:%D %T, Count:%r, Ant:%a, Proto:%p, Speed:%s, rssi:%m')
  # So I have to format my own command as if I were telnetted into the box:
  #reader.sendreceive(msg="TagListCustomFormat = Tag:%i, Disc:%d %t, Last:%D %T, Count:%r, Ant:%a, Proto:%p, Speed:%s, rssi:%m", opts={})
  #TODO: This does not seem to be working on the ebay_9900 unit as it still scans as:
  # line is "Tag:C033 1255 1023, Disc:2015/04/25 21:11:26.082, Last:2015/04/25 21:11:26.660, Count:8, Ant:0, Proto:2"
  reader.sendreceive(msg="TagListCustomFormat = Tag:%i, Disc:%d %t, Last:%D %T, Count:%r, Ant:%a, Proto:%p, Speed:%s, rssi:%m", opts={})
  
  # Note: the line below does not work, so I use the command that follows instead
  #reader.acqg2mask("0") # read any tag in the world
  reader.sendreceive(msg="set acqg2mask=0")
  reader.taglistformat("custom")
  reader.tagtype ='16'
  reader.autoaction = 'acquire'
  reader.autostarttrigger='0 0'
  #reader.tagdataformatgroupsize = 2 # report epc as bytes
  log "done initializing aquire parameters"
end

def scan(reader, scan_period_secs=1)
  reader.automode='on'
  log 'Acquiring...'
  sleep scan_period_secs
  log "...Done!"
  reader.automode='off'
  parse_tags(reader.taglist)
end


begin
  # Grab various parameters out of a configuration file
  config = nil
  if ARGV[0] == "local"
    puts "*** RUNNING LOCALLY ***"
    config = AlienConfig.new("config-local.dat")
  else
    config = AlienConfig.new("config.dat")
  end
  r = nil
  loop do  
    begin
      open = true
      if !r
        open = false
        # Create the new reader
        r = AlienReader.new
        open = r.open( config["reader_ip_address"]) # Uses default usr, pwd, port...  
        log "r is #{r}"
      end
      
      if open
        log "r is #{r}"
        #log "Reader name: #{r.readername}"

        available_antennas = r.antennastatus
        log "Connected antenna ports: #{available_antennas}" # returns something like "0 1"

	    old_rf_level = r.rflevel

	    # our reader returns power in dBm *10 
	    log 'Current RF Power: ' + ( old_rf_level.to_f / 10 ).to_s + 'dBm'

	    # grab the current antenna configuration
	    old_antenna_sequence = r.antennasequence	
	    log 'Current Antenna Sequence: ' + old_antenna_sequence 

	    # set the reader to use all the connected antennas
	    log 'Change antenna sequence to all available antennas... ' 
	    r.antennasequence = available_antennas
	    log 'New antenna sequence: ' + r.antennasequence

	    log 'Try to change power to 30.0dBm... ' 
	    r.rflevel='290'
	    log 'RF Level: ' + (r.rflevel.to_f / 10).to_s + 'dBm'

	    log 'Set RF modulation mode to Dense Reader Mode...'
	    r.rfmodulation='drm' 
	    log 'RF Modulation: ' + r.rfmodulation

	    scan_init(r)	
        tags = scan(r) 

        log "visible tags: "
        json = "["
        tags.each do |tag|
          utid = utid_for_tag(r, tag)
          log tag.id 
          if json.length > 1
            json += ","
          end
          json += to_json(tag, utid) 
          log "rssi_survey, #{tag.id}, #{tag.rssi}"
        end
        json += "]"
        log "I will post: #{json}"
        post_data(json)
      else 
        log "Failed opening reader"
      end
    rescue => exception
      log "Error during pass: #{$!}"
      puts exception.backtrace
      # Close the connection.
      r.close if r != nil
      r = nil
    end
    r=nil
    log "rerunning in 1 second"
    sleep 1
  end  
rescue => exception
  # Print out any errors
  log "Fatal error: #{$!}"
  puts exception.backtrace
end

log "exiting"
logfile.close
