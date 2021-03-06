require 'open-uri'
require 'logger'
require 'optparse'
require 'fileutils'

require 'goliath/api'
require 'goliath/runner'

module Visor
  module Image
    class CLI

      attr_reader :argv, :conf_file, :options, :new_opts, :command, :parser

      # Available commands
      COMMANDS     = %w[start stop restart status clean]
      # Commands that wont load options from the config file
      NO_CONF_LOAD = %w[stop status clean]
      # Default files directory
      DEFAULT_DIR  = File.expand_path('~/.visor')

      # Initialize a new CLI
      def initialize(argv=ARGV)
        @argv      = argv
        @options   = {}
        @conf_file = load_conf_file
        @options   = defaults
        @new_opts  = []
        @parser    = parser
        @command   = parse!
      end

      # Generate the default options
      def defaults
        {:config     => ENV['GOLIATH_CONF'],
         :address    => conf_file[:bind_host],
         :port       => conf_file[:bind_port],
         :log_file   => File.join(File.expand_path(conf_file[:log_path]), conf_file[:log_file]),
         :pid_file   => File.join(DEFAULT_DIR, 'visor_api.pid'),
         :env        => :production,
         :daemonize  => true,
         :log_stdout => false}
      end

      # OptionParser parser
      def parser
        OptionParser.new do |opts|
          opts.banner = "Usage: visor-image [OPTIONS] COMMAND"

          opts.separator ""
          opts.separator "Commands:"
          opts.separator "     start        start the server"
          opts.separator "     stop         stop the server"
          opts.separator "     restart      restart the server"
          opts.separator "     status       current server status"

          opts.separator ""
          opts.separator "Options:"

          opts.on("-c", "--config FILE", "Load a custom configuration file") do |file|
            options[:conf_file] = File.expand_path(file)
            new_opts << :config_file
          end
          opts.on("-a", "--address HOST", "Bind to HOST address (default: #{options[:address]})") do |addr|
            options[:address] = addr
            new_opts << :address
          end
          opts.on("-p", "--port PORT", "Bind to PORT number (default: #{options[:port]})") do |port|
            options[:port] = port.to_i
            new_opts << :port
          end
          opts.on("-e", "--env ENV", "Set execution environment (default: #{options[:env]})") do |env|
            options[:env] = env.to_sym
            new_opts << :env
          end
          opts.on("-f", "--foreground", "Do not daemonize, run in foreground") do
            options[:daemonize]  = false
            options[:log_stdout] = true
            new_opts << :daemonize
          end

          #opts.separator ""
          #opts.on('-l', '--log FILE', "Log to file (default: #{@options[:log_file]})") do |file|
          #  @options[:log_file] = file
          #  new_opts << :log_file
          #end
          #opts.on('-u', '--user USER', "Run as specified user") do |v|
          #  @options[:user] = v
          #  new_opts << :user
          #end

          #opts.separator ""
          #opts.separator "SSL options:"
          #opts.on('--ssl', 'Enables SSL (default: off)') {|v| @options[:ssl] = v }
          #opts.on('--ssl-key FILE', 'Path to private key') {|v| @options[:ssl_key] = v }
          #opts.on('--ssl-cert FILE', 'Path to certificate') {|v| @options[:ssl_cert] = v }
          #opts.on('--ssl-verify', 'Enables SSL certificate verification') {|v| @options[:ssl_verify] = v }

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail("-d", "--debug", "Enable debugging") do
            options[:debug] = true
            new_opts << :debug
          end
          #opts.on_tail('-v', '--verbose', "Enable verbose logging") do
          #  options[:verbose] = true
          #  new_opts << :verbose
          #end
          opts.on_tail("-h", "--help", "Show this help message") { show_options(opts) }
          opts.on_tail('-v', '--version', "Show version") { show_version }
        end
      end

      # Parse the current shell arguments and run the command.
      # Exits on error.
      def run!
        if command.nil?
          abort @parser.to_s

        elsif COMMANDS.include?(command)
          unless NO_CONF_LOAD.include?(command)
            @options.merge!({address: options[:address], port: options[:port]})
          end

          case command
          when 'start' then
            start
          when 'stop' then
            stop
          when 'restart' then
            restart
          when 'status' then
            status
          else
            clean
          end
          exit 0
        else
          abort "Unknown command: #{command}. Available commands: #{COMMANDS.join(', ')}"
        end
      end

      # Remove all files created by the daemon.
      def clean
        begin
          FileUtils.rm(pid_file) rescue Errno::ENOENT
          FileUtils.rm(url_file) rescue Errno::ENOENT
        end
        put_and_log :warn, "Removed all tracking files created at server start"
      end

      # Restart server
      def restart
        @restart = true
        stop
        sleep 0.1 while running?
        start
      end

      # Display current server status
      def status
        if running?
          STDERR.puts "visor-image is running PID: #{fetch_pid} URL: #{fetch_url}"
        else
          STDERR.puts "visor-image is not running."
        end
      end

      # Stop the server
      def stop
        begin
          pid = File.read(pid_file)
          put_and_log :warn, "Stopping visor-image with PID: #{pid.to_i} Signal: INT"
          Process.kill(:INT, pid.to_i)
          File.delete(url_file)
        rescue
          put_and_log :warn, "Cannot stop visor-image, is it running?"
          exit! 1
        end
      end

      # Start the server
      def start
        FileUtils.mkpath(DEFAULT_DIR) unless Dir.exists?(DEFAULT_DIR)
        begin
          is_it_running?
          can_use_port?
          write_url
          launch!
        rescue => e
          put_and_log :warn, "Error starting visor-image: #{e.message}\n#{e.backtrace.to_s}"
          exit! 1
        end
      end

      # Launch the server
      def launch!
        put_and_log :info, "Starting visor-image at #{options[:address]}:#{options[:port]}"
        debug_settings

        runner     = Goliath::Runner.new(opts_to_goliath, Visor::Image::Server.new)
        runner.app = Goliath::Rack::Builder.build(Visor::Image::Server, runner.api)
        runner.run
      end


      protected

      # Convert options hash to a compatible Goliath ARGV array
      def opts_to_goliath
        argv_like = []
        @options.each do |k, v|
          case k
          when :config then
            argv_like << '-c' << v.to_s
          when :log_file then
            argv_like << '-l' << v.to_s
          when :pid_file then
            argv_like << '-P' << v.to_s
          when :env then
            argv_like << '-e' << v.to_s
          when :address then
            argv_like << '-a' << v.to_s
          when :port then
            argv_like << '-p' << v.to_s
          when :user then
            argv_like << '-u' << v.to_s
          when :daemonize then
            argv_like << '-d' << v.to_s if v
          when :verbose then
            argv_like << '-v' << v.to_s if v
          when :log_stdout then
            argv_like << '-s' << v.to_s if v
          end
        end
        argv_like
      end

      # Display options
      def show_options(opts)
        puts opts
        exit
      end

      # Show VISOR Image System version
      def show_version
        puts "visor-image #{Visor::Image::VERSION}"
        exit
      end

      # Check if the server is already running
      def is_it_running?
        if files_exist?(pid_file, url_file)
          if running?
            put_and_log :warn, "visor-image is already running at #{fetch_url}"
            exit! 1
          else
            clean
          end
        end
      end

      # Test process pid to access the server status
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

      # Test if port is open
      def can_use_port?
        unless port_open?
          put_and_log :warn, "Port #{options[:port]} already in use. Please try other."
          exit! 1
        end
      end

      # Access that port is open
      def port_open?
        begin
          STDERR.puts url
          options[:no_proxy] ? open(url, proxy: nil) : open(url)
          false
        rescue OpenURI::HTTPError #TODO: quick-fix, try solve this
          false
        rescue Errno::ECONNREFUSED
          true
        end
      end

      # Retrieve a logger instance
      def logger
        @logger ||=
            begin
              log           = options[:daemonize] ? Logger.new(log_file) : Logger.new(STDERR)
              conf_level    = conf_file[:log_level] == 'INFO' ? 1 : 0
              log.level     = options[:debug] ? 0 : conf_level
              log.formatter = proc do |s, t, n, msg|
                #"[#{t.strftime(conf_file[:log_datetime_format])}] #{s} - #{msg}\n"
                "[#{Process.pid}:#{s}] #{t.strftime(conf_file[:log_datetime_format])} :: #{msg}\n"
              end
              log
            end
      end

      # Print to stderr and log message
      def put_and_log(level, msg)
        STDERR.puts msg
        logger.send level, msg
      end

      # Parse argv arguments
      def parse!
        parser.parse! argv
        argv.shift
      end

      # Log debug settings
      def debug_settings
        logger.debug "Configurations loaded from #{conf_file[:file]}:"
        logger.debug "**************************************************************"
        conf_file.each { |k, v| logger.debug "#{k}: #{v}" unless k == :file }
        logger.debug "**************************************************************"

        logger.debug "Configurations passed from visor-image CLI:"
        logger.debug "**************************************************************"
        if new_opts.empty?
          logger.debug "none"
        else
          new_opts.each { |k| logger.debug "#{k}: #{options[k]}" }
        end
        logger.debug "**************************************************************"
      end

      # Check if a set of files exist
      def files_exist?(*files)
        files.each { |file| return false unless File.exists?(File.expand_path(file)) }
        true
      end

      # Generate the listening url
      def url
        "http://#{options[:address]}:#{options[:port]}"
      end

      # Write url to file
      def write_url
        File.open(url_file, 'w') { |f| f << url }
      end

      # Load url from file
      def fetch_url
        IO.read(url_file).split('//').last
      rescue
        nil
      end

      # Load configuration file options
      def load_conf_file
        Visor::Common::Config.load_config(:visor_image, options[:conf_file])
      rescue => e
        raise "There was an error loading the configuration file: #{e.message}"
      end

      # Fetch pid from file
      def fetch_pid
        IO.read(pid_file).to_i
      rescue
        nil
      end

      # Current pid file option
      def pid_file
        options[:pid_file]
      end

      # Current log file option
      def log_file
        options[:log_file]
      end

      # Current url file location
      def url_file
        File.join(DEFAULT_DIR, 'visor_api.url')
      end

    end
  end
end
