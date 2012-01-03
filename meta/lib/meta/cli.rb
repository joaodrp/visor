require 'open-uri'
require 'logger'
require 'optparse'
require 'fileutils'
require 'rack'

module Visor
  module Meta
    class CLI

      attr_reader :app, :cli_name, :argv, :options,
                  :port, :host, :env, :command, :parser

      # Available commands
      COMMANDS = %w[start stop restart status clean]
      # Commands that wont load options from the config file
      NO_CONF_COMMANDS = %w[stop status]
      # Default config files directories to look at
      DEFAULT_DIR = File.expand_path('~/.visor')
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
        @options = default_opts
        @parser = parser
        @command = parse!
      end

      def default_opts
        {debug: false,
         foreground: false,
         no_proxy: false,
         environment: DEFAULT_ENV}
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
          when 'start' then start
          when 'stop' then stop
          when 'restart' then restart
          when 'status' then status
          else clean
        end
        exit 0
      end

      # Remove all files created by the daemon.
      #
      def clean
        begin
          FileUtils.rm(pid_file) rescue Errno::ENOENT
        end
        begin
          FileUtils.rm(url_file) rescue Errno::ENOENT
        end
        put_and_log :warn, "Removed all files created by server start"
      end

      # Restart server
      #
      def restart
        @restart = true
        stop
        sleep 0.1 while running?
        start
      end

      # Display current server status
      #
      def status
        if running?
          STDERR.puts "#{cli_name} is running PID: #{fetch_pid} URL: #{fetch_url}"
        else
          STDERR.puts "#{cli_name} is not running."
        end
      end

      # Stop the server
      #
      def stop
        begin
          pid = File.read(pid_file)
          put_and_log :warn, "Stopping #{cli_name} with PID: #{pid.to_i} Signal: INT"
          Process.kill(:INT, pid.to_i)
          File.delete(url_file)
        rescue
          put_and_log :warn, "Cannot stop #{cli_name}, is it running?"
          exit! 1
        end
      end

      # Start the server
      #
      def start
        FileUtils.mkpath(DEFAULT_DIR)
        begin
          is_it_running?
          can_use_port?
          write_url
          launch!
        rescue => e
          put_and_log :warn, "ERROR starting #{cli_name}: #{e}"
          exit! 1
        end
      end

      # Launch the server
      #
      def launch!
        put_and_log :info, "Starting #{cli_name} at #{host}:#{port}"
        debug_settings

        Rack::Server.start(app: app,
                           Host: host,
                           Port: port,
                           environment: get_env,
                           daemonize: daemonize?,
                           pid: pid_file)
      end

      protected

      def is_it_running?
        if files_exist?(pid_file, url_file)
          if running?
            put_and_log :warn, "'#{cli_name}' is already running at #{fetch_url}"
            exit! 1
          else
            clean
          end
        end
      end

      def running?
        begin
          Process.kill 0, fetch_pid
          true
        rescue Errno::ESRCH
          false
        rescue Errno::EPERM
          true
        rescue
          false
        end
      end

      def can_use_port?
        unless port_open?
          put_and_log :warn, "Port #{port} already in use. Please try other."
          exit! 1
        end
      end

      def port_open?
        begin
          options[:no_proxy] ? open(url, proxy: nil) : open(url)
          false
        rescue OpenURI::HTTPError #TODO: quick-fix, try solve this
          false
        rescue Errno::ECONNREFUSED
          true
        end
      end

      def daemonize?
        !options[:foreground]
      end

      def get_env
        env == 'development' ? env : 'deployment'
      end

      def logger
        @conf ||= load_conf_file
        @logger ||=
            begin
              log = options[:foreground] ? Logger.new(STDERR) : Visor::Common::Config.build_logger(:meta_server)
              conf_level = @conf[:log_level] == 'INFO' ? 1 : 0
              log.level = options[:debug] ? 0 : conf_level
              log.formatter = Proc.new {|s, t, n, msg| "[#{t.strftime("%Y-%m-%d %H:%M:%S")}] #{s} - #{msg}\n"}
              log
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

      def debug_settings
        logger.debug "Configurations loaded from #{@conf[:file]}:"
        logger.debug "***************************************************"
        @conf.each { |k, v| logger.debug "#{k}: #{v}" }
        logger.debug "***************************************************"

        logger.debug "Configurations passed from #{cli_name} CLI:"
        logger.debug "***************************************************"
        options.each { |k, v| logger.debug "#{k}: #{v}" if options[k] != default_opts[k] }
        logger.debug "***************************************************"
      end

      def files_exist?(*files)
        files.each { |file| return false unless File.exists?(File.expand_path(file)) }
        true
      end

      def write_url
        File.open(url_file, 'w') { |f| f << url }
      end

      def load_conf_file
        Visor::Common::Config.load_config(:meta_server, options[:config])
      end

      def safe_cli_name
        cli_name.gsub('-', '_')
      end

      def fetch_pid
        IO.read(pid_file).to_i
      rescue
        nil
      end

      def fetch_url
        IO.read(url_file).split('//').last
      rescue
        nil
      end

      def pid_file
        File.join(DEFAULT_DIR, "#{safe_cli_name}.pid")
      end

      def url_file
        File.join(DEFAULT_DIR, "#{safe_cli_name}.url")
      end

      def url
        "http://#{host}:#{port}"
      end

    end
  end
end
