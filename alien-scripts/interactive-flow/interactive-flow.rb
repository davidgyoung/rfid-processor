# Add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'
require 'alientag'
require 'net/http'
require 'uri'

@utid_cache ={}

def logfile
  @logfile ||= File.open("/tmp/interactive-flow.log", "w")
end

def restart_log_periodically
  # restart log file every 15 minutes so we don't run out of disk space
  if !@logfile_start_time || Time.now - @logfile_start_time > 15*60
    @logfile_start_time = Time.now
    if @logfile
      @logfile.close
      @logfile = nil  
    end
  end
end

def log(line)
  restart_log_periodically
  puts line
  logfile.puts("#{Time.now} #{line}") 
  logfile.flush
end

SERVER = "http://ancient-reaches-8047.herokuapp.com"

def post_data(json)
  uri = URI.parse(SERVER)
  connection = Net::HTTP.new(uri.host, uri.port)
  connection.start do |http|
    request = Net::HTTP::Post.new("/readers")
    request.body = json
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    response = http.request(request)
    if response.code > "299"
      log "error posting data: #{response.code}"
    else
      log "successful response: #{response.body}"
      # this should return something like:
      # {"id":1,"created_at":"2015-05-03T20:30:00.584Z","updated_at":"2015-05-03T20:30:00.584Z"}
      if response.body =~ /"id":(\d+)/
        return $1.to_i
      else
        puts "Cannot parse id from response: #{response.body}"
      end
    end    
  end   
  return nil             
end

def reader_data_fields_to_json(reader_data) 
  json = <<RJSONEND
    "mac_address":"#{reader_data[:mac_address]}",
    "name":"#{reader_data[:name]}",
    "version":"#{reader_data[:version]}",
    "type":"#{reader_data[:type]}",
RJSONEND
end

def tag_to_json(tag, utid)
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
  tagbytes=tag.id.gsub(" ","")
  tag_byte_length = tagbytes.length/2
  tag_bit_length = tag_byte_length*8
  tagbytes_comma_separated = tagbytes.gsub(/(.{2})(?=.)/, '\1,\2')
  puts "tag id as bytes is #{tagbytes}"
  mask = "1,32,#{tag_bit_length},#{tagbytes_comma_separated}"
  puts "mask=#{mask}"
  reader.acqg2mask(mask) # Enter mask
  tries = 0
  begin
    @utid_cache[tag.id] = reader.g2read("2 2 4")  # Read TID data
  rescue
    puts "error: #{$!}"
    sleep(0.1)
    tries += 1
    retry if tries < 10 # I do not know why this fails so often with Error 154: Read error.
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
  reader.automode='on'
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

def post_tags(r, reader_data, tags)
  json = '{"reader": {'+reader_data_fields_to_json(reader_data)+'"tags":['
  tags.each_with_index do |tag,index|
    utid = utid_for_tag(r, tag)
    log tag.id 
    if index > 0
     json += ","
    end
    json += tag_to_json(tag, utid) 
  end
  json += "]}}"
  log "I will post: #{json}"
  post_data(json)
end

def cloud_read_tag_info(tag_id)
  retries = 0
  begin
    log "Getting tag info: /tags/#{URI::escape(tag_id)}"
    uri = URI.parse(SERVER)  
    connection = Net::HTTP.new(uri.host, uri.port)
    connection.open_timeout = 1
    connection.read_timeout = 1

    connection.start do |http|
      request = Net::HTTP::Get.new("/tags/#{URI::escape(tag_id)}")
      request['Accept'] = 'application/json'
      response = http.request(request)
      if response.code > "299"
        log "error getting tag data: #{response.code}"
      else
        log "success getting tag data: #{response.body}"
        # Ugh.  JSON is not available on Ruby 1.8.7.  And the platform has no
        # rubygems.  So we must parse json in a very ghetto way
        result = {}
        if response.body.match(/"funded":([^,^}]+)/)
          if $1 == "true"
            result[:funded] = true
          elsif $1 == "false"
            result[:funded] = false
          end
        end

        if response.body.match(/"member":([^,^}]+)/)
          if $1 == "true"
            result[:member] = true
          elsif $1 == "false"
            result[:member] = false
          end
        end
        return result

      end    
    end    
  rescue Timeout::Error
    log "timeout talking to server!"
    if retries < 2
      retries += 1
      retry
    end
  end
  return nil
end

def cloud_read_reader_info(reader_id)
  retries = 0
  begin
    log "Getting reader info: /readers/#{URI::escape(reader_id)}"
    uri = URI.parse(SERVER)  
    connection = Net::HTTP.new(uri.host, uri.port)
    connection.open_timeout = 1
    connection.read_timeout = 1

    connection.start do |http|
      request = Net::HTTP::Get.new("/readers/#{URI::escape(reader_id)}")
      request['Accept'] = 'application/json'
      response = http.request(request)
      if response.code > "299"
        log "error getting reader data: #{response.code}"
      else
        log "success getting reader data: #{response.body}"
        # Ugh.  JSON is not available on Ruby 1.8.7.  And the platform has no
        # rubygems.  So we must parse json in a very ghetto way
        result = {}
        if response.body.match(/"action":([^,^}]+)/)
          result[:action] = $1
        end
        return result
      end    
    end    
  rescue Timeout::Error
    log "timeout talking to server!"
    if retries < 2
      retries += 1
      retry
    end
  end
  return nil
end

def cloud_send_event(reader_id, flow_number, event, tag) 
  retries = 0
  begin
    log "Sending event: #{event}" 
    uri = URI.parse(SERVER)
    connection = Net::HTTP.new(uri.host, uri.port)
    connection.open_timeout = 1
    connection.read_timeout = 1
    connection.start do |http|
      request = Net::HTTP::Post.new("/reader_events")
      request.body = <<EVENTJSONEND
      { "reader_event": {
          "reader_id": "#{reader_id}",
          "flow_number": #{flow_number},
          "event": "#{event}",
          "tag_id": "#{tag.id}" }
      }
EVENTJSONEND
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      response = http.request(request)
      if response.code > "299"
        log "error posting data: #{response.code}"
      else
        log "success"
      end    
    end   
  rescue Timeout::Error
    log "timeout talking to server!"
    if retries < 5
      retries += 1
      retry
    end
  end
  return nil
end

def cloud_get_proceed_or_cancel(tag_id, reader_id)
  message = nil
  if tag_id
    tag_info = cloud_read_tag_info(tag_id)
	if(tag_info && (tag_info[:funded] || tag_info[:member]))
	  message = "proceed"
	end
  else
    reader_info = cloud_read_reader_info(reader_id)
    message = reader_info[:action]  
  end
  message
end

def do_red_flow(reader, reader_id, flow_number, tag)
  proceed = false
  # red flow
  cloud_send_event(reader_id, flow_number, "Stop (RED)", tag)
  cloud_send_event(reader_id, flow_number, "external output = 2", tag)            
  r.gpio = "2"
  start_time = Time.now.to_i
  cloud_authorize_timeout = 60 # seconds
  while (Time.now.to_i < start_time+cloud_authorize_timeout)
	sleep(0.500) # pause 500 ms per flowchart
	message = cloud_get_proceed_or_cancel(tag.tag_id, reader_id)
	cloud_send_event(reader_id, flow_number, "Proceed message from cloud = #{message}", tag)            
	if message == "proceed"
	  proceed = true
	  break
    elsif message == "cancel"
      proceed = false
      break
    end
  end
  if proceed
	# green flow
	cloud_send_event(reader_id, flow_number, "Proceed (GREEN)", tag)
	cloud_send_event(reader_id, flow_number, "external output = 5", tag)            
	begin
	  r.gpio = "5"
	rescue
	  log "Cannot set gpio to 5 on this reader"
	end
	sleep(0.050) # pause 50 ms per flowchart
	cloud_send_event(reader_id, flow_number, "external output = 0", tag)
  else
	cloud_send_event(reader_id, flow_number, "timeout", tag)                
	cloud_send_event(reader_id, flow_number, "external output = 0", tag)
	r.gpio = "0"
  end              
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
  # Do this forever, if there are errors, start over
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
        reader_data = {}
        reader_data[:name] = r.readername
        reader_data[:version] = r.readerversion
        reader_data[:type] = type = r.readertype
        reader_data[:mac_address] = r.macaddress
        available_antennas = r.antennastatus
        log "Connected antenna ports: #{available_antennas}" # returns something like "0 1"

        log "GPIO state is #{r.gpio.to_i.to_s(2)}"
        #old_rf_level = r.rflevel

	    # our reader returns power in dBm *10 
	    #log 'Current RF Power: ' + ( old_rf_level.to_f / 10 ).to_s + 'dBm'

	    # grab the current antenna configuration
	    #old_antenna_sequence = r.antennasequence	
	    #log 'Current Antenna Sequence: ' + old_antenna_sequence 

	    # set the reader to use all the connected antennas
	    #log 'Change antenna sequence to all available antennas... ' 
	    #r.antennasequence = available_antennas
	    #log 'New antenna sequence: ' + r.antennasequence

	    #log 'Try to change power to 30.0dBm... ' 
	    #r.rflevel='276'
	    #log 'RF Level: ' + (r.rflevel.to_f / 10).to_s + 'dBm'

	    log 'Set RF modulation mode to Dense Reader Mode...'
	    r.rfmodulation='drm' 
	    log 'RF Modulation: ' + r.rfmodulation

	    scan_init(r)	
        tags = parse_tags(r.taglist)
        reader_id = post_tags(r, reader_data, tags)
        
        # Start of Flowchart
        log "Starting flowchart"
        # flowchart variables
        flow_number = Time.now.to_i
        proceed = false
        timeout = false
        if (tags.size > 0)
          # Question: figure out which tag to process if there are multiple.  
          #  RSSI?  biggest by absolute value?   smallest by absolute value?
          #  For now, always do the first one          
          tag = tags[0]
          cloud_send_event(reader_id, flow_number, "tag found", tag)
          tag_info = cloud_read_tag_info(tag.id)
          if tag_info
            cloud_send_event(reader_id, flow_number, "tag for member under paid contract? #{tag_info[:funded] ? "yes" : "no"}", tag)
            if tag_info[:funded]
              proceed = true
            else
              cloud_send_event(reader_id, flow_number, "tag for member with sufficent funds? #{tag_info[:member] ? "yes" : "no" }", tag)
              if tag_info[:member]
                proceed = true
              end            
            end
          else
            timeout = true
            cloud_send_event(reader_id, flow_number, "Cannot get tag info (timeout)", tag)            
          end
          if (timeout)
              cloud_send_event(reader_id, flow_number, "Cannot get tag info (timeout)", tag)            
            r.gpio = "0"
          else
            if proceed
              # green flow
              cloud_send_event(reader_id, flow_number, "Proceed (GREEN)", tag)
              cloud_send_event(reader_id, flow_number, "external output = 5", tag)            
              begin
                r.gpio = "5"
              rescue
                log "Cannot set gpio to 5 on this reader"
              end
              sleep(0.50) # pause 50 ms per flowchart
              cloud_send_event(reader_id, flow_number, "external output = 0", tag)            
            else
              do_red_flow(r, reader_id, flow_number, tag)
            end            
          end
        else 
          # No tags visible.  Check to see if somebody has been detected without a tag
          vehicle_detected = r.gpio & 0x01 == 0x01 
          if vehicle_detected
            cloud_send_event(reader_id, flow_number, "Vehicle detected.  Input[0]=1" )           
          else
            cloud_send_event(reader_id, flow_number, "Vehicle not detected.  Input[0]=0")
            do_red_flow(r, reader_id, flow_number, nil)
          end          
        end
        cloud_send_event(reader_id, flow_number, "end of flowchart", tag)                																																																		
      else 
        log "Failed opening reader"
      end
    rescue => exception
      log "Error during execution: #{$!}"
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
