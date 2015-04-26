# Add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'alienreader'
require 'alienconfig'
require 'alientag'
require 'net/http'

def logfile
  @logfile ||= File.open("./uploader.log", "a")
end

def log(line)
  puts line
  logfile.puts("#{Time.now} #{line}") 
  logfile.flush
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

begin
  # Grab various parameters out of a configuration file
  config = AlienConfig.new("config.dat")

  if true  
    r = nil
    begin
      # Create the new reader
      r = AlienReader.new
      if r.open( config["reader_ip_address"]) # Uses default usr, pwd, port...  
        log "Reader name: #{r.readername}"

        available_antennas = r.antennastatus
        log 'Connected antenna ports: ' + available_antennas 

        old_rf_level = r.rflevel

        # our reader returns power in dBm *10 
        log 'Current RF Power: ' + ( old_rf_level.to_f / 10 ).to_s + 'dBm'

        # grab the current antenna configuration
        old_antenna_sequence = r.antennasequence	
        log 'Current Antenna Sequence: ' + old_antenna_sequence 
      end
    rescue
      log "error: #{$!}"
    end
    r.close if r != nil
    r=nil
    log "rerunning in 10 minutes"
    sleep 600
  end  
rescue
  # Print out any errors
  log "Fatal error: " +$!
end

log "exiting"
logfile.close
