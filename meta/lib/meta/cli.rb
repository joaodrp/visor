#TODO tunning options ? https://github.com/macournoyer/thin/blob/master/lib/thin/runner.rb
require 'optparse'
require 'thin'

module Visor
  module Meta

    include Visor::Common::Exception
    include Visor::Common::Config

    # The CLI for the VISoR Meta. This class parses and processes the Command Line Interface <visor-meta> commands.
    #
    # This is used to manage the VISoR Meta server, for start, shutdown, restart and reload it.
    #
    class CLI
      # Available commands
      COMMANDS = %w[start stop restart reload]
      # Commands that wont load options from the config file
      CONFIGLESS_COMMANDS = %w[stop]

      def initialize(argv)
        @argv = argv

        # Default options values
        @options = {:verbose => false,
                    :debug => false,
                    :foreground => false,
                    :config => nil,
                    :dir => Dir.pwd}
        parse!
      end

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "\nUsage: visor-meta [OPTIONS] COMMAND"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "     start        start the server"
          opts.separator "     stop         stop the server"
          opts.separator "     restart      restart the server"
          opts.separator "     reload       reload the server"

          opts.separator ""
          opts.separator "Options:"

          opts.on("-c", "--config FILE", "Load a custom configuration file") do |file|
            @options[:config] = file
          end
          opts.on("-d", "--dir DIR", "Change to dir before starting") do |dir|
            @options[:dir] = File.expand_path(dir)
          end
          #opts.on("-l", "--log FILE", "File to redirect output (default: #{@options[:log]})") do |file|
          #  @options[:log] = file
          #end
          #opts.on("-P", "--pid FILE", "File to store PID (default: #{@options[:pid]})") do |file|
          #  @options[:pid] = file
          #end
          opts.on("-f", "--foreground", "Run in the foreground") do
            @options[:foreground] = true
          end
          opts.on_tail("-d", "--debug", "Set debugging on") do
            @options[:debug] = true
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

      # Parse the options.
      #
      def parse!
        parser.parse! @argv
        @command = @argv.shift
        @arguments = @argv
      end

      def options
        #options = Array.new
        #options << "-a #{self.address}"
        #options << "-p #{self.port}"
        #options << "-S #{self.socket}" if self.socket
        #options << "-e #{self.env}"
        #options << "-d" if self.daemonize
        #options << "-l #{self.log}" if self.log
        ##options << "-P #{self.pid}" if self.pid
        #options << "-u #{self.duser}" if self.duser
        #options << "-g #{self.dgroup}" if self.dgroup
        #options << "-s #{self.servers}"
        #options << "-D" if self.debug
        #options.join(" ")
        options = Array.new
        options << "-a #{@conf[:bind_host]}"
        options << "-p #{@conf[:bind_port]}"
        options << "-d" unless @options[:foreground]
        options << "-D" if @options[:debug]
        options << "-R #{File.expand_path('config.ru', File.dirname(__FILE__))}"

        options.join(" ")
      end

      # Parse the current shell arguments and run the command.
      # Exits on error.
      #
      def run!
        if @command.nil?
          puts "Command required!", @parser
          exit 1
        elsif COMMANDS.include?(@command)
          run_command
        else
          abort "Unknown command: #{@command}. Available commands: #{COMMANDS.join(', ')}"
        end
      end

      # Execute the command
      #
      def run_command
        unless CONFIGLESS_COMMANDS.include?(@command)
          load_options_from_file
          Dir.chdir(@options[:dir])
        end

        case @command
          when 'start'
            start
          when 'stop'
            stop
          when 'restart'
            restart
          else
            reload
        end

        #abort "Invalid options for command: #{@command}"
      end

      def start
        p 'starting...'
        pid = Process.fork do
          #system "thin #{self.options} start"
          Signal.trap("HUP") { puts "done!"; exit }
          Thin::Server.start(@conf[:bind_host], @conf[:bind_port], Visor::Meta::Server)
        end
        #Process.detach(pid)
        p pid
        #p 'killing...'
        #Process.kill('HUP', pid)
        #Thin::Runner.new().run!
        #system "thin #{self.options} start"

      end

      def stop
        p 'killing...'
        Process.kill(9, 16548)
      end

      private

      def load_options_from_file
        file = @options.delete(:config)
        @conf = Visor::Common::Config.load_config(:meta_server, file)
        #@conf[:log_level] = 'DEBUG' if @options[:debug]
      end
    end

  end
end
