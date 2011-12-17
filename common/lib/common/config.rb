require 'yaml'
require 'logger'

module Visor
  module Common
    module Config

      # Default configuration file directories
      CONFIG_FILE_DIRS = [Dir.pwd, File.expand_path(File.join('~', '.visor')), '/etc/visor']
      # Default configuration file name
      CONFIG_FILE_NAME = 'visor-config.yml'

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
          CONFIG_FILE_DIRS.each do |dir|
            file = File.join(dir, CONFIG_FILE_NAME)
            return file if File.exists?(file)
          end
        end
      end

      # Looks for a VISoR configuration file througth {#find_config_file} and returns a hash with
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
          raise "Error while parsing the config file: #{e.message}"
        end
        config = scope ? content[scope] : content
        config.merge(file: file)
      end

      # Build and return a Logger instance for a given VISoR sub-system, based on configuration
      # file options, which are validated througth {#validate_logger}.
      #
      # @param app_name [Symbol] The VISoR sub-system app name to build a log for.
      #
      # @return [Logger] A logger instance already properly configured.
      #
      def self.build_logger(app_name)
        conf = load_config
        validate_logger(conf, app_name)

        log_path = conf[:default][:log_path]
        log_datetime = conf[:default][:log_datetime_format]
        log_file = conf[app_name][:log][:file]
        log_level = conf[app_name][:log][:level]

        file = File.join(File.expand_path(log_path), log_file)
        # Keep 5 old log files which are rotated as the log reaches 1MB
        log = Logger.new(file, 5, 1024*1024)
        log.level = log_level=='DEBUG' ? Logger::DEBUG : Logger::INFO
        log.datetime_format = log_datetime
        log
      end

      # Validates the configuration file options regarding the logging for some VISoR sub-sustem.
      #
      # @param conf [Hash] The configuration file options.
      # @param app_name [Symbol] The VISoR sub-system app name to build a log for.
      #
      # @raise [RuntimeError] If some logging configuration value is not valid.
      #
      def self.validate_logger(conf, app_name)
        log_path = conf[:default][:log_path]
        raise "Unnable to find 'default/log_path' configuration." unless log_path

        unless Dir.exists?(File.expand_path(log_path))
          raise "Unnable to find '#{log_path}' directory for 'default/log_path' configuration."
        end

        log_datetime = conf[:default][:log_datetime_format]
        raise "Unnable to find 'default/log_datetime_format' configuration." unless log_datetime

        log_file = conf[app_name][:log][:file]
        raise "Unnable to find '#{app_name}/log/file' configuration." unless log_file

        log_level = conf[app_name][:log][:level]
        raise "Unnable to find '#{app_name}/log/level' configuration." unless ['INFO', 'DEBUG'].include?(log_level)
      end

    end
  end
end
