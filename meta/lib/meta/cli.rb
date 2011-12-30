require 'open-uri'
require 'logger'
require 'optparse'
require 'fileutils'

module Visor
  module Common
    class CLI

      include Visor::Common::Exception
      include Visor::Common::Config

      attr_reader :app, :cli_name, :argv, :options, :rack_handler,
                  :port, :host, :env, :command, :parser

      # Available commands
      COMMANDS = %w[start stop restart status]
      # Commands that wont load options from the config file
      NO_CONF_COMMANDS = %w[stop status]

      DEFAULT_DIR = File.expand_path('~/.visor')
      DEFAULT_HOST = '0.0.0.0'
      DEFAULT_PORT = 4567
      DEFAULT_ENV = :production

      def initialize(app, cli_name, argv=ARGV)
        @app = app
        @cli_name = cli_name
        @argv = argv
        @options = {debug: false,
                    foreground: false,
                    no_proxy: false,
                    environment: DEFAULT_ENV}

        @rack_handler = detect_rack_handler #TODO remove? as sinatra#run! do it
        @parser = parser
        @command = parse!
      end

      def parser
        OptionParser.new do |opts|
          opts.banner = "Usage: #{cli_name} [OPTIONS] COMMAND"

          opts.separator ""
          opts.separator "Commands:"
          opts.separator "     start        start the server"
          opts.separator "     stop         stop the server"
          opts.separator "     restart      restart the server"
          opts.separator "     status       current server status"

          opts.separator ""
          opts.separator "Options:"

          opts.on("-c", "--config FILE", "Load a custom configuration file") do |file|
            options[:config] = File.expand_path(file)
          end
          opts.on("-o", "--host HOST", "listen on HOST (default: #{DEFAULT_HOST})") do |host|
            options[:host] = host.to_s
          end
          opts.on("-p", "--port PORT", "use PORT (default: #{DEFAULT_PORT})") do |port|
            options[:port] = port.to_i
          end
          opts.on("-x", "--no-proxy", "ignore proxy settings if any") do
            options[:no_proxy] = true
          end
          opts.on("-e", "--env ENVIRONMENT", "use ENVIRONMENT for defaults (default: #{DEFAULT_ENV})") do |env|
            options[:environment] = env.to_sym
          end
          opts.on("-F", "--foreground", "don't daemonize, run in the foreground") do
            options[:foreground] = true
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail("-d", "--debug", "Set debugging on (with foreground only)") do
            options[:debug] = true
          end
          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end
          opts.on_tail('-v', '--version', "Show version") do
            puts "VISoR Meta Server v#{Visor::Meta::VERSION}"
            exit
          end
        end
      end

      # Parse the current shell arguments and run the command.
      # Exits on error.
      #
      def run
        if command.nil?
          abort @parser.to_s
        elsif COMMANDS.include?(command)
          run_command
        else
          abort "Unknown command: #{command}. Available commands: #{COMMANDS.join(', ')}"
        end
      end

      # Execute the command
      #
      def run_command
        unless NO_CONF_COMMANDS.include?(command)
          @conf = load_conf_file
          @host = options[:host] || @conf[:bind_host] || DEFAULT_HOST
          @port = options[:port] || @conf[:bind_port] || DEFAULT_PORT
          @env = options[:environment]
        end

        case command
          when 'start' then
            start
          when 'stop' then
            stop
          when 'restart' then
            restart
          else
            status
        end
      end

      def restart
        @restart = true
        stop
        sleep 1
        start
      end

      def status
        if files_exist?(pid_file, url_file)
          STDERR.puts "Running PID: #{File.read(pid_file)} URL: #{File.read(url_file)}"
        else
          STDERR.puts "Not running."
        end
        exit! 0
      end

      def stop
        begin
          pid = File.read(pid_file)
          put_and_log :warn, "Stopping #{cli_name} with PID: #{pid.to_i} Signal: TERM"
          Process.kill(:TERM, pid.to_i)
          exit! 0 unless restarting?
        rescue
          put_and_log :warn, "Cannot stop #{cli_name}, is it running?"
          exit! 1
        end
      end

      def start
        FileUtils.mkpath(DEFAULT_DIR)
        put_and_log :info, "Starting #{cli_name} at #{host}:#{port}"
        set_app_settings
        begin
          already_running?
          find_port
          write_url
          daemonize! unless options[:foreground]
          launch!
        rescue => e
          put_and_log :warn, "ERROR starting #{cli_name}: #{e}"
          exit! 1
        end
      end

      def already_running?
        if files_exist?(pid_file, url_file)
          url = File.read(url_file)
          unless port_open?(url)
            put_and_log :warn, "'#{cli_name}' is already running at #{url}"
            exit! 1
          end
        end
      end

      def find_port
        logger.warn "Trying port #{port}..."
        unless port_open?
          put_and_log :warn, "Port #{port} already in use. Please try other."
          exit! 1
        end
      end

      def port_open?(check_url = url)
        begin
          options[:no_proxy] ? open(check_url, proxy: nil) : open(check_url)
          false
        rescue OpenURI::HTTPError #TODO: quick-fix, try solve this
          false
        rescue Errno::ECONNREFUSED
          true
        end
      end

      def launch!
        app.run!(bind: host, port: port, environment: env) do |server|
          #    @rack_handler.run(app, bind: host, port: port) do |server|
          [:INT, :TERM].each do |flag|
            trap(flag) do
              server.respond_to?(:stop!) ? server.stop! : server.stop
              logger.info "#{cli_name} received #{flag}, stopping ..."
              delete_pid!
            end
          end
        end
      end

      def daemonize!
        Process.daemon(true, true)
        File.umask 0000
        FileUtils.touch log_file
        # as this is going to log_file it does not appear in visor-meta-server.log
        # could be usefull to omit sinatra+thin log messages.
        STDIN.reopen log_file
        STDOUT.reopen log_file, "a"
        STDERR.reopen log_file, "a"

        File.open(pid_file, 'w') { |f| f.write("#{Process.pid}") }
        at_exit { delete_pid! }
      end

      protected

      def logger
        @logger ||= if options[:foreground]
                      log = Logger.new(STDOUT)
                      log.level = options[:debug] ? Logger::DEBUG : Logger::INFO
                      log
                    else
                      Common::Config.build_logger :meta_server
                    end
      end

      def put_and_log(level, msg)
        STDERR.puts msg
        logger.send level, msg
      end

      def parse!
        parser.parse! argv
        argv.shift
      end

      def set_app_settings
        app.set(options.merge(safe_cli_name.to_sym => self)) if app.respond_to?(:set)

        logger.debug "Configurations loaded from #{@conf[:file]}:"
        logger.debug "***************************************************"
        @conf.each { |k, v| logger.info "#{k}: #{v}" } if logger.debug?
        logger.debug "***************************************************"

        logger.debug "Configurations passed from #{cli_name} CLI options:"
        logger.debug "***************************************************"
        options.each { |k, v| logger.info "#{k}: #{v}" } if logger.debug?
        logger.debug "***************************************************"

      end

      def restarting?
        @restart
      end

      def files_exist?(*files)
        files.each { |file| return false unless File.exists?(File.expand_path(file)) }
        true
      end

      def write_url
        File.open(url_file, 'w') { |f| f << url }
      end

      def detect_rack_handler
        servers = %w[thin mongrel webrick]
        servers.each do |server|
          begin
            return Rack::Handler.get(server.to_s)
          rescue LoadError, NameError
            # ignored
          end
        end
        put_and_log :fatal, "Server handler (#{servers.join(',')}) not found."
      end

      def delete_pid!
        File.delete(pid_file) if File.exist?(pid_file)
      end

      def load_conf_file
        Config.load_config(:meta_server, options[:config])
      end

      def safe_cli_name
        cli_name.gsub('-', '_')
      end

      def pid_file
        File.join(DEFAULT_DIR, "#{safe_cli_name}.pid")
      end

      def url_file
        File.join(DEFAULT_DIR, "#{safe_cli_name}.url")
      end

      def log_file
        "/tmp/visor_log"
      end

      def url
        "http://#{host}:#{port}"
      end

    end
  end
end
