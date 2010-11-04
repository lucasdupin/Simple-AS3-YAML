#Requires
%w(rubygems rake webrick net/http fileutils daemons yaml logger).each {|lib| require lib}

# Setup logging
LOG_PATH = "/tmp/fcshd/"
FileUtils.mkdir_p LOG_PATH unless File.directory? LOG_PATH
task_logger = Logger.new File.join(LOG_PATH, "rake.log")

#Default task
task :default => [ :build ]

desc "Build"
task :build do
	
  # Command we'll send to the server
  what = config["applications"].map do |v|
      get_compile_line(v["class"], v["output"])
  end

  server = FCSHDServer.new
  begin
	task_logger.info "Asking server to build: #{what}"
    server.build what
  rescue Errno::ECONNREFUSED

    task_logger.info "Connection refused, trying to start the server"
	puts "Server is down... starting it up" 
	`rake '#{__FILE__}' start_server`
	sleep 2
	Rake::Task[:build].execute
          
  end
end

desc "Opens default file and tail the flashlog"
task :open do
	
  # get the current 'open' value relative to the Rakefile path
  open = File.join(current_path, config['default'][0]['open'])
  # Checking if there is a  filesystem entry... otherwise, try to open itself
  open = config['default'][0]['open'] unless File.file? open
  # Log
  task_logger.info "Opening target: #{open}"
  # Open it
  system "open '#{open}'"

end

desc "Documentation generator"
task :doc do
	
  require_yaml
  
  doc = config["asdoc"][0]
  sources = config["source-path"].map{|v| "-doc-sources+=" + escape(v)}.join(" ")
  lib_path = config["library-path"].map{|v| escape v}.join(" ")
  exclude = doc["exclude-dirs"].map {|i| Dir[File.join(i, "**", "*.as")].map{|d| "-exclude-classes+=" + d.sub(i, '').gsub(/^\/?/, '').gsub(/\//, '.').gsub(/\.as$/, '')}.join(' ')}.join(' ')
  command = "asdoc -footer #{escape doc['footer']} -main-title #{escape doc['title']} -output #{escape doc['output']} -library-path #{lib_path} #{sources} #{exclude} -warnings=false"
  
  task_logger.info "Generating asdocs: #{command}"
  system command
  
end

desc "Listens to flashlog"
task :log do
  
  # Default flashlog file
  filename = File.expand_path('~/Library/Preferences/Macromedia/Flash Player/Logs/flashlog.txt')
  # Log
  task_logger.info "Tailing file: #{filename}"
  # Tail it
  system("tail -f '#{filename}'")
end

desc "Removes all built files"
task :clean do
	
  require_yaml
  
  what = config["applications"].map do |v|
      puts "cleaning #{v['output']}"
	  task_logger.info "cleaning #{v['output']}"
      FileUtils.rm_rf v['output']
  end
 
end

desc "Check if server is down"
task :status do
	puts FCSHDServer.new.status
end

desc "Stops the FCSH server"
task :stop_server do 
  begin
    FCSHDServer.new.stop
    puts "server has stopped"
	task_logger.info "Server stopped..."
  rescue Errno::ECONNREFUSED => e
    puts "server is down"
	task_logger.info "Server was already down"
  end
end

desc "Starts the FCSH server"
task :start_server do
	task_logger.info "Daemons!"
	FCSHDServer.new.daemon
end

private

def get_compile_line(input, output)

    libs_path    = (config["library-path"] || []).map{ |lib| "-library-path+=#{escape(File.join(current_path, lib))}"}.join(" ")
    sources_path = (config["source-path"] || []).map{ |lib| "-sp+=#{escape(File.join(current_path, lib))}"}.join(" ")

    #Making sure the link report folder exists
    link_report_file = File.join("/tmp", input)
    FileUtils.mkdir_p File.dirname(link_report_file)

    line = "mxmlc #{escape(File.join(current_path, input))} -o=#{escape(File.join(current_path, output))} -debug=#{config['default'][0]['debug']} #{libs_path} #{sources_path} #{config['default'][0]['extras']} -link-report=#{escape(link_report_file)}"

    #Excluding some clases
    config["link_report"].each do |l|
        line += " -load-externs=/tmp/#{l['exclude']}" if l['from'] == input
    end unless config["link_report"].nil?

    line
end

def current_path
  ENV['PROJECT_PATH'] || File.dirname(__FILE__)
end

def escape path
    path.gsub ' ', '\ '
end

def config
	# Loading build file
	@config ||= YAML.load_file(current_path + "/build.yaml")
end






class FCSHDServer
        PORT = 6924
        HOST = "localhost"
        ASSIGNED_REGEXP = /^ fcsh: Assigned (\d+) as the compile target id/

		attr_accessor :commands

        def start
	
			return if status == "up"
			
			fcsh = IO.popen("fcsh  2>&1", "w+")
            read_to_prompt(fcsh)
	
			server_logger.info "\nStarting Webrick at http://#{HOST}:#{PORT}"
        
			#remembering wich swfs we asked for compiling
			@commands ||= Hash.new

			#Creating the HTTP Server  
            s = WEBrick::HTTPServer.new(
                :Port => PORT,
                :Logger => WEBrick::Log.new(nil, WEBrick::BasicLog::WARN),
                :AccessLog => []
            )

            #giving it an action
            s.mount_proc("/build"){|req, res|

                #response variable
                output = ""

                #Searching for an id for this command
                if @commands.has_key?(req.body)
                    # Exists, incremental
					server_logger.info "[Build] Target #{@commands[req.body]} is: #{req.body}"
                    fcsh.puts "compile #{@commands[req.body]}"
                    output = read_to_prompt(fcsh)
                else
                    # Does not exist, compile for the first time
					server_logger.info "[Build] #{req.body}"
                    fcsh.puts req.body
                    output = read_to_prompt(fcsh)
                    @commands[req.body] = $1 if output.match(ASSIGNED_REGEXP)
                end

                res.body = output
                res['Content-Type'] = "text/html"
            }

            s.mount_proc("/stop"){|req, res|
                s.shutdown
                fcsh.close
				server_logger.info "Stopping server"
                exit
            }

			s.mount_proc("/status"){|req, res|
	      	  begin
	      	    fcsh.puts("info 0")
	      	    output = read_to_prompt(fcsh)
	      	    res.body = "up"
	      	  rescue Exception => e
	      	    res.body = "down"
	      	  end

			  server_logger.info("Getting status: #{res.body}")
	      	  exit
	      	}

            trap("INT"){
                s.shutdown 
                fcsh.close
            }

            #Starting webrick
            s.start

			# #Do not show error if we're trying to start the server more than once
            # if e.message =~ /Address already in use/ < 0
            #   puts e.message
            # end

        end
 
        def daemon
			Daemons.daemonize
            start
        end

        def build(what)
            what.each{ |arg|
					#puts arg
                    http = Net::HTTP.new(HOST, PORT)
                    resp, date = http.post('/build', arg)
                    puts resp.body
             }
        end

        def stop
                http = Net::HTTP.new(HOST, PORT)
                resp, date = http.get('/stop')
                puts resp.body
        end

		def status
			begin
				http = Net::HTTP.new(HOST, PORT)
                resp, date = http.get('/status	')
                resp.body
			rescue Exception => e
				"down"
			end
        end

        private
        #Helper method to read the output
        def read_to_prompt(f)
            f.flush
            output = ""
            while chunk = f.read(1)
                STDOUT.write chunk
                output << chunk
                if output =~ /^\(fcsh\)/
                    break
                end
            end
            STDOUT.write ">"
            output
        end

		def server_logger
			@server_logger ||= Logger.new File.join(LOG_PATH, "server.log")
			@server_logger
		end


end