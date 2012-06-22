require 'yaml'
require 'logger'

module Visor
  module Common

    # The Config module provides a set of utility functions to manipulate configuration
    # files and Logging.
    #
    module Config

      include Visor::Common::Exception

      # Default possible configuration file directories
      DEFAULT_CONFIG_DIRS = %w{. ~/.visor /etc/visor}
      # Default configuration file name
      DEFAULT_CONFIG_FILE = 'visor-config.yml'
      # Default logs path
      DEFAULT_LOG_PATH = '~/.visor/logs'
      # Default log datetime format
      DEFAULT_LOG_DATETIME = "%Y-%m-%d %H:%M:%S"
      # Default log level
      DEFAULT_LOG_LEVEL = Logger::INFO
      # Configuration file template
      CONFIG_TEMPLATE = %q[
# ===== Default always loaded configuration throughout VISOR sub-systems ======
default: &default
    # Set the default log date time format
    log_datetime_format: "%Y-%m-%d %H:%M:%S"
    # Set the default log files directory path
    log_path: ~/.visor/logs
    # VISOR access and secret key credentials (from visor-admin command)
    access_key:
    secret_key:

# ================================ VISOR Auth =================================
visor_auth:
    # Merge default configurations
    <<: *default
    # Address and port to bind the server
    bind_host: 0.0.0.0
    bind_port: 4566
    # Backend connection string (backend://user:pass@host:port/database)
    #backend: mongodb://<user>:<password>@<host>:27017/visor
    #backend: mysql://<user>:<password>@<host>:3306/visor
    # Log file name (empty for STDOUT)
    log_file: visor-auth-server.log
    # Log level to start logging events (available: DEBUG, INFO)
    log_level: INFO

# ================================ VISOR Meta =================================
visor_meta:
    # Merge default configurations
    <<: *default
    # Address and port to bind the server
    bind_host: 0.0.0.0
    bind_port: 4567
    # Backend connection string (backend://user:pass@host:port/database)
    #backend: mongodb://<user>:<password>@<host>:27017/visor
    #backend: mysql://<user>:<password>@<host>:3306/visor
    # Log file name (empty for STDOUT)
    log_file: visor-meta-server.log
    # Log level to start logging events (available: DEBUG, INFO)
    log_level: INFO

# ================================ VISOR Image ================================
visor_image:
    # Merge default configurations
    <<: *default
    # Address and port to bind the server
    bind_host: 0.0.0.0
    bind_port: 4568
    # Log file name (empty for STDOUT)
    log_file: visor-api-server.log
    # Log level to start logging events (available: DEBUG, INFO)
    log_level: INFO

# =========================== VISOR Image Backends ============================
visor_store:
    # Default store (available: s3, lcs, cumulus, walrus, hdfs, file)
    default: file
    #
    # FileSystem store backend (file) settings
    #
    file:
        # Default directory to store image files in
        directory: ~/VMs/
    #
    # Amazon S3 store backend (s3) settings
    #
    s3:
        # The bucket to store images in, make sure it exists on S3
        bucket:
        # Access and secret key credentials, grab yours on your AWS account
        access_key:
        secret_key:
    #
    # Lunacloud LCS store backend (lcs) settings
    #
    lcs:
        # The bucket to store images in, make sure it exists on LCS
        bucket:
        # Access and secret key credentials, grab yours within Lunacloud
        access_key:
        secret_key:
    #
    # Nimbus Cumulus store backend (cumulus) settings
    #
    cumulus:
        # The Cumulus host address and port number
        host:
        port:
        # The bucket to store images in, make sure it exists on Cumulus
        bucket:
        # Access and secret key credentials, grab yours within Nimbus
        access_key:
        secret_key:
    #
    # Eucalyptus Walrus store backend (walrus) settings
    #
    walrus:
        # The Walrus host address and port number
        host:
        port:
        # The bucket to store images in, make sure it exists on Walrus
        bucket:
        # Access and secret key credentials, grab yours within Eucalyptus
        access_key:
        secret_key:
    #
    # Apache Hadoop HDFS store backend (hdfs) settings
    #
    hdfs:
        # The HDFS host address and port number
        host:
        port:
        # The bucket to store images in
        bucket:
        # Access credentials, grab yours within Hadoop
        username:
]

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
      #TODO: YAML.load_openstruct(File.read(file))
      def self.load_config(scope = nil, other_file = nil)
        file = find_config_file(other_file)
        raise ConfigError, "Could not found any configuration file." unless file
        begin
          content = YAML.load_file(file).symbolize_keys
        rescue => e
          raise ConfigError, "Error while parsing the configuration file: #{e.message}."
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

        raise ConfigError, "Cannot locate 'default' configuration group." unless conf[:default]
        raise ConfigError, "Cannot locate '#{app_name}' configuration group." unless conf[app_name]

        log_path = File.expand_path(conf[:default][:log_path] || DEFAULT_LOG_PATH)
        log_datetime = conf[:default][:log_datetime_format] || DEFAULT_LOG_DATETIME
        log_file = conf[app_name][:log_file] || STDOUT
        log_level = conf[app_name][:log_level] || DEFAULT_LOG_LEVEL

        begin
          Dir.mkdir(log_path) unless Dir.exists?(log_path)
        rescue => e
          raise ConfigError, "Cannot create the 'default/log_path' directory: #{e.message}."
        end

        begin
          output = log_file==STDOUT ? log_file : File.join(log_path, log_file)
          log = Logger.new(output, 5, 1024*1024)
        rescue => e
          raise ConfigError, "Error while create the logger for #{output}: #{e.message}."
        end

        begin
          log.datetime_format = log_datetime
          log.level = get_log_level(log_level)
        rescue => e
          raise ConfigError, "Error while setting logger properties: #{e.message}."
        end
        log
      end

      private

      def self.get_log_level(level)
        case level
          when 'DEBUG' then
            Logger::DEBUG
          when 'INFO' then
            Logger::INFO
          else
            DEFAULT_LOG_LEVEL
        end
      end

    end
  end
end
