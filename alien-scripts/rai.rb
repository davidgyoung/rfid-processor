=begin rdoc

=Alien Reader Application Interface
==rai.rb	

A utility to facilitate work with Alien on-reader applications.

Copyright 2009, Alien Technology Corporation. All rights reserved.

=end

# MODIFICATIONS BY DAVIDGYOUNG TO GET THIS RUNNING ON 1.8.6
require 'rubygems'
class String
  def start_with?(s)
    self.index(s) == 0
  end
end




require 'optparse'
require 'ostruct'
require 'net/ssh'
require 'net/scp'

APP_VER  = "1.0.0"
APP_NAME = "Alien Reader Application Interface (RAI)"
APP_CONF = File.expand_path(".rai")

DIR_APPS = "/home/alien/apps"
SCRIPT_APPS = "/etc/init.d/alienRAI.sh"
 
CONF_HOST = "hostname"
CONF_USER = "username"
CONF_PASS = "password"
CONF_CLI  = "cli"
CONF_PRIO = "priority"

############################
# config file parser
############################
class AlienConfig < Hash
	def self.load(filename, opts = {})
		new(filename, opts)
	end

	def initialize(filename, opts = {})
		super(nil)
		@file      = filename
		@comment   = opts[:comment]   || '#'
		@separator = opts[:separator] || '='
		@verbose   = opts[:verbose]   || false
		@raise     = opts[:raise]     || false
		parse
	end

	def save(filename = nil)
		::File.open(filename.nil? ? @file : filename, 'w') do |file|
			self.each {|key,value| file.puts "#{key} #{@separator} #{value}" }
		end
	end

	private
	def parse
		return unless ::Kernel.test ?f, @file

		::File.open(@file, 'r').each do |line|
			case line.chomp!
			when /\A\s*\z|\A\s*[#{@comment}]/: next # ignore blank and comment lines
			when /\A([^#{@separator}]+)#{@separator}(.*)\z/: # parse 'key = value'
				self[$1.strip] = $2.strip
			else
				raise "[#{@file}] [#{self.class}] failed to parse line '#{line}' in #{@file}"  if @raise
				puts "#WARNING# [#{self.class}] failed to parse line '#{line}' in #{@file}" if @verbose
				next
			end
		end
	end
end

############################
# list files in a directory
############################
def file_list(dir, opts={})
	opts={:recursive => false, :exclude => []}.merge(opts)
	f = []
	Dir.glob(File.join(dir,"*")).each do | file |
		if File.file?(file) then
			next if opts[:exclude].include? file
			f << file
		else
			f << file_list(file) if opts[:recursive] && File.directory?(file)
		end
	end
	return f
end

############################
# usage
############################
def usage
	puts %{
Alien Reader Application Interface (RAI) ver.1.0.0

Usage: rai.rb [options]

Configure options:
   configure (conf,config)      configure authorization options

Transfer options:
   put [<file1>[ <file2>...]]   put file(s) to the reader
   get [<file1>[ <file2>...]]   retrieve file(s) from the reader

Install options:
   register (rg, reg)           register application on the reader
     -p, --priority <priority>  application startup priority (70-90), default 80
     -c, --cli <cli>            application Command Language Interpreter (ruby, bin)
   unregister (ur, ureg, unreg) unregister application on the reader
   delete (del)                 delete application on the reader

Status options:
   list (l)   [apps|<app>]      list applications installed on the reader
   status (s) [apps|<app>]      display status of application on the reader

Common options:
   help (h)                     display help information
   version (v, ver)             display version information
	}
end

############################
# load and verify configuration
############################
def conf_load(file, opts={})
	opts={:save => true, :set => false}.merge(opts)
	changed = false

	begin
		conf = AlienConfig.load(file)

		[CONF_HOST,CONF_USER,CONF_PASS,CONF_CLI,CONF_PRIO].each do |param|
			not_set = conf[param].nil? || conf[param].empty?
			if not_set || opts[:set]
				while true
					printf "Enter '%8s'%s", param, (not_set ? ": " : " [#{conf[param]}]: ")
					STDOUT.flush
					if (str = STDIN.gets.strip).empty?
						next if not_set
						break
					end
					conf[param] = str
					changed = true
					break
				end
			end
		end
	rescue Exception => e
		puts
		puts "#ERROR# input interrupted"
		return nil
	rescue
		puts
		puts "#ERROR# invalid input"
		return nil
	end
	conf.save if opts[:save] && changed

	return conf
end

############################
# command line options parser
############################
def parse_opts (opts)
	begin
		options = OpenStruct.new	
		options.conf     = false
		options.app      = nil # application name
		options.priority = nil # app priority (70-90)
		options.cli      = nil # app command interpreter (e.g. ruby)
		options.get      = nil 
		options.put      = nil
		options.list     = nil
		options.status   = nil
		options.reg      = nil
		options.ureg     = nil
		options.del      = nil


		raise "No valid options specified" if opts == nil || opts.size < 1 

		options.app  = File.basename(pwd = Dir.pwd)
		raise ArgumentError, "Invalid current working directory (running from '/' root?)" if options.app =~ /\A\//
puts "parsing opts 2" 
		i = 1
		case opts[0]
			when "conf", "config", "configure"
				options.conf = true

			when "put" # put [<file1>[ <file2>...]] - put file(s) to the reader (no files=all files)
				options.put = f = []
				if opts.size == 1 # no args => all files
					f = file_list(Dir.pwd, :recursive=>false, :exclude=>[APP_CONF])
				else # specific files
					opts[i,opts.size-1].each do |file|
#						raise ArgumentError, "File '#{file}' must be in the current folder" if file =~ /[\/\\]/
						file = File.expand_path(file)
						next if file == APP_CONF # skip configuration file
						raise ArgumentError, "'#{file}' was not found" unless File.exist?(file) 
						raise ArgumentError, "'#{file}' is not a file" if File.directory?(file)
						raise ArgumentError, "'#{file}' is not in the current folder" if file =~ /^#{pwd}[\/\\]..*[\/\\]/
						f << file
					end
				end
				raise ArgumentError, "No files to send" if f.empty?
				options.put = f

			when "get" # [<file1>[ <file2>...]] - retrieve file(s) from the reader (no files=all files)
				options.get = f = []
				opts[i,opts.size-1].each do |file|
					raise ArgumentError, "File '#{file}' must be in the application's folder" if file =~ /[\/\\]/
					raise ArgumentError, "Invalid file name '#{file}'" if /^-/ =~ file
					f << file.strip
				end
				options.get = f

			when "del", "delete" # <APP> - remove APP from the reader
				raise ArgumentError, "Invalid application name value" if /^-/ =~ opts[i] # || /^./ =~ opts[i]
				options.del = (opts.size==1) ? options.app : opts[i]

			when "l", "list" # list applications installed on the reader
				raise "Invalid number of options" unless opts.size <= 2
				options.list = (opts.size==1) ? options.app : opts[i]
			when "s", "status" # [APPNAME]", "display status of applications installed on the reader"
				raise "Invalid number of options" unless opts.size <= 2
				options.status = (opts.size==1) ? options.app : opts[i]  

			when "rg", "reg", "register" # "register application on the reader"
				options.reg = true
			# check for optional arguments
				while i < opts.size do 
					case opts[i]
					when "-p", "--priority" # application startup PRIORITY (70-90), default 80
						raise ArgumentError, "Priority value is missing" unless (i+=1) < opts.size
						opt = opts[i].to_i
						raise ArgumentError, "Priority value range must be 70-90" if opt<70 || opt>90
						options.priority = opt
					when "-c", "--cli"  # application command language interpreter (e.g. 'ruby')
						raise ArgumentError, "Command language interpreter value is missing" unless (i+=1) < opts.size
						opt = opts[i]
						raise ArgumentError, "Invalid command language interpreter value" if /^-/ =~ opt
						options.cli = opt
					else
						raise "Invalid option #{opts[i]}"
					end 
					i += 1
				end

			when "ur", "ureg", "unreg", "unregister" # "unregister application on the reader"
				options.ureg = true

			when "help", "h"
				usage
				exit

			when "v", "ver", "version"
				puts "#{__FILE__} #{APP_NAME} ver.#{APP_VER}"
				exit

			else
				raise "Invalid command line option #{opts[0]}"
		end

	rescue ArgumentError
#		puts $!
		raise
	rescue
		usage
		puts
#		puts $!
		raise
	end

puts "done parsing options"
	return options
end

############################
# MAIN
############################
begin
	opts = parse_opts(ARGV)

	exit if (conf = conf_load(APP_CONF, :set => opts.conf)).nil?
	exit if opts.conf
puts "got opts"
	opts.cli      = conf[CONF_CLI]  if opts.cli.nil?
	opts.priority = conf[CONF_PRIO] if opts.priority.nil?
# confirm actions
	if opts.reg || opts.ureg || opts.del
		if opts.reg
			printf "Register '#{opts.app}' %s application as Alien service with PRIORITY=%d?\n", 
				(opts.cli == nil ? "" : opts.cli.upcase), (opts.priority.nil? ? 80 : opts.priority)
		end

		if opts.ureg
			printf "Unregister '#{opts.app}' application from being an Alien service?\n"
		end 

		if opts.del
			printf "Delete '#{opts.del}' application from the reader?\n" 
		end 

		while true
			print "  please type 'yes' or 'no':"
			STDOUT.flush
			exit  if (str = STDIN.gets.strip).empty?
			break if str == 'yes'
			exit  if str == 'no'
		end
	end
puts "starting ssh #{conf[CONF_HOST]},#{conf[CONF_USER]},#{conf[CONF_PASS]}"
  ssh = Net::SSH.start(conf[CONF_HOST], conf[CONF_USER], :password => conf[CONF_PASS])	
puts "got ssh handle"
#---------------------------
# put files to the reader
#---------------------------
	if opts.put != nil
	# create app folder if it does not exist
		dir = "#{DIR_APPS}/#{opts.app}"
		ssh.exec!("test -d #{dir} || mkdir #{dir}")
		opts.put.each do |file|
			printf "uploading '#{file}'..."
			ssh.scp.upload! file, "#{dir}"
			puts "done"
		end
	end

#---------------------------
# get files from the reader
#---------------------------
	if opts.get != nil
	# verify the app folder exists
		dir = "#{DIR_APPS}/#{opts.app}"
		res = ssh.exec!("test -d #{dir} 1>/dev/null 2>&1 ; echo $?")
		raise "application '#{opts.app}' does not exist on the reader" if res.to_i != 0

		if opts.get.empty? # all files
#			ssh.scp.download! "#{dir}/*", "." # using '*' does not work 
			files = ssh.exec!("find #{dir} -type f 2>/dev/null | grep '^#{dir}/[^/][^/]*$'")
			if files.nil? || files.empty?
				puts "no files to fetch for #{opts.app}"
			else
				files.split("\n").each do |file|
					file.strip!
					i = file.rindex('/')
					f = file[i+1,999] if i != nil

#					f = file[/\/[^\/]+\Z/]
#					f = (f != nil ? f[1,999] : file); 

					printf "downloading '#{f}'..."
					ssh.scp.download! "#{file}", "." rescue raise "('#{f}' does not exist?)"
					puts "done"
				end
			end
		else # download specific files
			opts.get.each do |file|
				file.strip!
				printf "downloading '#{file}'..."
				ssh.scp.download! "#{dir}/#{file}", "." rescue raise "('#{file}' does not exist?)"
				puts "done"
			end
		end
	end

#---------------------------
# delete application on the reader
#---------------------------
	if opts.del != nil
		res = ssh.exec!("#{SCRIPT_APPS} -d #{opts.del}")
		puts res if res != nil
	end

#---------------------------
# list applications installed on the reader
#---------------------------
	if opts.list != nil
puts "time to do listing"
		if opts.list == "apps" # list app files
			res = ssh.exec!("#{SCRIPT_APPS} -l")
			puts res if res != nil
		else
			app = opts.list
			dir = "#{DIR_APPS}/#{app}"
#			res = ssh.exec!("ls -1 #{dir} 1>/dev/null 2>&1 ; echo $?")
			res = ssh.exec!("find #{dir} -type d 1>/dev/null 2>&1 ; echo $?")
			raise "application '#{app}' does not exist on the reader" if res.to_i != 0
			puts ssh.exec!("ls -1 #{dir}")
		end
	end

#---------------------------
# status of applications installed on the reader
#---------------------------
	if opts.status != nil
		puts ssh.exec!("export PATH=$PATH:/alien/services ; #{SCRIPT_APPS} -s #{opts.status}")
	end

#---------------------------
# register application on the reader
#---------------------------
	if opts.reg != nil
		cmd = "#{SCRIPT_APPS} -r #{opts.app}" + 
			(opts.priority != nil ? " -p #{opts.priority}" : "") + 
			(opts.cli      != nil ? " -c #{opts.cli}"      : "");
		res = ssh.exec!(cmd)
		puts res if res != nil
	end

#---------------------------
# unregister application on the reader
#---------------------------
	if opts.ureg != nil
		res = ssh.exec!("#{SCRIPT_APPS} -u #{opts.app}")
		puts res if res != nil
	end

rescue Net::SSH::HostKeyMismatch => e
  puts "remembering new key: #{e.fingerprint}"
  e.remember_host!
  retry
rescue
	puts "#ERROR# #{$!}"
ensure
# consume the exception to suppress post SCP notifications
	ssh.close if ssh != nil	rescue nil
end

exit
