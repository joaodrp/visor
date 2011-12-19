require 'yaml'
require 'logger'

module Visor
  module Common

    # The Config module provides a set of utility functions to manipulate configuration
    # files and Logging.
    #
    module Config

      # Default possible configuration file directories
      DEFAULT_CONFIG_DIRS  = ['.', '~/.visor', '/etc/visor']
      # Default configuration file name
      DEFAULT_CONFIG_FILE  = 'visor-config.yml'
      # Default logs path
      DEFAULT_LOG_PATH     = '~/.visor/logs'
      # Default log datetime format
      DEFAULT_LOG_DATETIME = "%Y-%m-%d %H:%M:%S"
      # Default log level
      DEFAULT_LOG_LEVEL    = Logger::INFO

      # Ordered search for a VISoR configuration file on default locations and return the first matched.
      #
      # @param other_file [String] Other file to use instead of default config files.
      #
      # @return [nil, String] Returns nil if no valid config file was found or a string with the
      #   absolute path to the found configuration file.
      #
      def self.find_config_file(other_file = nil)
        if other_file
          file = File.expand_path(other_file)
          File.exists?(file) ? file : nil
        else
          DEFAULT_CONFIG_DIRS.each do |dir|
            file = File.join(File.expand_path(dir), DEFAULT_CONFIG_FILE)
            return file if File.exists?(file)
          end
        end
      end

      # Looks for a VISoR configuration file througth {#self.find_config_file} and returns a hash with
      # all configuration settings or just a sub-system scoped settings.
      #
      # @param scope [String] Used to return just the settings about a specific sub-system.
      # @param other_file [String] Other file to use instead of default config files.
      #
      # @return [Hash] Global or scoped settings.
      #
      # @raise [RuntimeError] If there is no configuration files or if errors occur during parsing.
      #
      def self.load_config(scope = nil, other_file = nil)
        file = find_config_file(other_file)
        raise "Could not found any configuration file." unless file
        begin
          content = YAML.load_file(file).symbolize_keys
        rescue Exception => e
          raise "Error while parsing the configuration file #{file}: #{e.message}"
        end
        config = scope ? content[scope] : content
        config.merge(file: file)
      end

      # Build and return a Logger instance for a given VISoR sub-system, based on configuration
      # file options, which are validated througth {#self.validate_logger}.
      #
      # @param app_name [Symbol] The VISoR sub-system app name to build a log for.
      # @option configs [Hash] Optional configuration options to override config file ones.
      #
      # @return [Logger] A logger instance already properly configured.
      #
      def self.build_logger(app_name, configs = nil)
        conf = configs || load_config
        begin
          log_path     = conf[:default][:log_path] || DEFAULT_LOG_PATH
          log_datetime = conf[:default][:log_datetime_format] || DEFAULT_LOG_DATETIME
          log_file     = conf[app_name][:log][:file] || STDOUT
          log_level    = conf[app_name][:log][:level] || DEFAULT_LOG_LEVEL
        rescue Exception => e
          raise "Error while loading configuration file #{conf[:file]}: #{e.message}"
        end

        path = File.expand_path(log_path)
        Dir.mkdir(path) unless Dir.exists?(path)
        output = log_file == STDOUT ? STDOUT : File.join(path, log_file)
        log    = Logger.new(output, 5, 1024*1024)

        log.datetime_format = log_datetime
        set_log_level(log, log_level)
        log
      end

      private

      def self.set_log_level(log, level)
        log.level =
            if level == 'DEBUG'
              Logger::DEBUG
            elsif level == 'INFO'
              Logger::INFO
            else
              DEFAULT_LOG_LEVEL
            end
      end
    end
  end
end
