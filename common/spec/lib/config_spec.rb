require 'spec_helper'

module Visor::Common
  describe Config do

    let(:file) { File.join(File.expand_path('~/.visor'), Config::DEFAULT_CONFIG_FILE) }
    let(:some_file) { File.expand_path('~/some_file') }
    let(:invalid_file) { '~/some_invalid_file' }

    let(:sample_conf) { {default:
                             {log_datetime_format: "%Y-%m-%d %H:%M:%S",
                              log_path: "~/.visor/logs"},
                         registry_server:
                             {bind_host: "0.0.0.0", bind_port: 4567,
                              backend: "mongodb://:@127.0.0.1:27017/visor",
                              log: {file: "visor-registry.log", level: "DEBUG"}}} }

    before(:all) do
      unless File.exists?(file)
        File.open(file, 'w') do |f|
          f.write(sample_conf.stringify_keys.to_yaml)
        end
      end

      File.open(some_file, 'w') do |f|
          f.write(sample_conf.stringify_keys.to_yaml)
      end

      File.open(File.expand_path(invalid_file), 'w') do |f|
        f.write('this will break YAML parsing')
      end
    end

    after(:all) do
      #File.delete(some_file, File.expand_path(invalid_file))
    end

    describe "#find_config_file" do
      it "should find a configuration file in default dirs if it exists" do
        Config.find_config_file.should == file
      end

      it "should get an existing config file as option" do
        Config.find_config_file(some_file).should == some_file
      end

      it "should return nil if no configuration file found" do
        Config.find_config_file('fake_file').should be_nil
      end
    end

    describe "#load_config" do
      it "should raise if there is no configuration files" do
        lambda { Config.load_config(nil, invalid_file) }.should raise_exception
      end

      it "should return a valid non-empty hash" do
        conf = Config.load_config
        conf.should be_a Hash
        conf.should_not be_empty
      end

      it "should append the configuration file full path to hash" do
        conf = Config.load_config
        conf[:file].should_not be_nil
        File.exists?(conf[:file]).should be_true
      end

      it "should return scoped configuration" do
        conf = Config.load_config :default
        conf.keys.should == sample_conf[:default].keys << :file
      end

      it "should raise an exception if an error occurs during parsing" do
        lambda { Config.load_config(nil, invalid_file) }.should raise_exception
      end
    end

    describe "#build_logger" do
      it "should return a Logger for a specific app" do
        log = Config.build_logger :registry_server
        log.should be_a Logger
      end

      it "should raise an exception if an error occurs loading the config file" do
        lambda { Config.build_logger :fake_scope }.should raise_exception
      end
      
      it "should set the log level if provided" do
        log = Config.build_logger :registry_server, sample_conf
        log.level.should == Logger::DEBUG
      end

      it "should set the log level to the default if not provided" do
        sample_conf[:registry_server][:log].delete(:level)
        log = Config.build_logger :registry_server, sample_conf
        log.level.should == Config::DEFAULT_LOG_LEVEL
      end
    end

  end
end
