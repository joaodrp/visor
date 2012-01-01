require 'open-uri'
require 'logger'
require 'optparse'
require 'fileutils'
require 'rack'

module Visor
  module Common
    class CLI

      include Visor::Common::Exception
      include Visor::Common::Config

      attr_reader :app, :cli_name, :argv, :options,
                  :port, :host, :env, :command, :parser

      # Available commands
      COMMANDS = %w[start stop restart status]
      # Commands that wont load options from the config file
      NO_CONF_COMMANDS = %w[stop status]
      # Default config files directories to look at
      DEFAULT_DIR = '~/.visor'
      # Default host address
      DEFAULT_HOST = '0.0.0.0'
      # Default port
      DEFAULT_PORT = 4567
      # Default application environment
      DEFAULT_ENV = :production

      # Initialize a CLI
      #
      def initialize(app, cli_name, argv=ARGV)
        @app = app
        @cli_name = cli_name
        @argv = argv
        @options = {debug: false,
                    foreground: false,
                    no_proxy: false,
                    environment: DEFAULT_ENV}
        @parser = parser
        @command = parse!
      end

      # OptionParser parser
      #
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
      def run!
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

      # Restart server
      #
      def restart
        @restart = true
        stop
        logger.info "hi"
        start
      end

      # Display current server status
      #
      def status
        if files_exist?(pid_file, url_file)
          STDERR.puts "Running PID: #{File.read(pid_file)} URL: #{File.read(url_file)}"
        else
          STDERR.puts "Not running."
        end
        exit! 0
      end

      # Stop the server
      #
      def stop
        begin
          pid = File.read(pid_file)
          put_and_log :warn, "Stopping #{cli_name} with PID: #{pid.to_i} Signal: INT"
          Process.kill(:INT, pid.to_i)
          File.delete(url_file)
          exit! 0 unless restarting?
        rescue
          put_and_log :warn, "Cannot stop #{cli_name}, is it running?"
          exit! 1
        end
      end

      # Start the server
      #
      def start
        FileUtils.mkpath(File.expand_path(DEFAULT_DIR))
        put_and_log :info, "Starting #{cli_name} at #{host}:#{port}"
        debug_settings
        begin
          already_running?
          find_port unless restarting?
          write_url
          launch!
        rescue => e
          put_and_log :warn, "ERROR starting #{cli_name}: #{e}"
          exit! 1
        end
      end

      # Look if the server is already running?
      #
      def already_running?
        if files_exist?(pid_file, url_file)
          url = File.read(url_file)
          unless port_open?(url)
            put_and_log :warn, "'#{cli_name}' is already running at #{url}"
            exit! 1
          end
        end
      end

      # Find if a port is free to use
      #
      def find_port
        logger.warn "Trying port #{port}..."
        unless port_open?
          put_and_log :warn, "Port #{port} already in use. Please try other."
          exit! 1
        end
      end

      # Tells if a port is open or closed
      #
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

      # Launch the server
      #
      def launch!
          Rack::Server.start(app: app, Host: host, Port: port,
                             environment: get_env, daemonize: daemonize?, pid: pid_file)
      end

      protected

      def daemonize?
        !options[:foreground]
      end

      def get_env
        env == 'development' ? env : 'deployment'
      end

      def logger
        @logger ||= setup_logger
      end

      def setup_logger
        log = options[:foreground] ? Logger.new(STDERR) : Config.build_logger(:meta_server)
        log.level = options[:debug] ? Logger::DEBUG : Logger::INFO
        log
      end

      def put_and_log(level, msg)
        STDERR.puts msg
        logger.send level, msg
      end

      def parse!
        parser.parse! argv
        argv.shift
      end

      def debug_settings
        logger.debug "Configurations loaded from #{@conf[:file]}:"
        logger.debug "***************************************************"
        @conf.each { |k, v| logger.info "#{k}: #{v}" } if logger.debug?
        logger.debug "***************************************************"

        logger.debug "Configurations passed from #{cli_name} CLI:"
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

      def load_conf_file
        Config.load_config(:meta_server, options[:config])
      end

      def safe_cli_name
        cli_name.gsub('-', '_')
      end

      def pid_file
        File.join(File.expand_path(DEFAULT_DIR), "#{safe_cli_name}.pid")
      end

      def url_file
        File.join(File.expand_path(DEFAULT_DIR), "#{safe_cli_name}.url")
      end

      def url
        "http://#{host}:#{port}"
      end

    end
  end
end
