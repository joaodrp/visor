require 'spec_helper'

module Visor::Common
  describe Config do

    let(:file) { File.join(Config::CONFIG_FILE_DIRS[1], Config::CONFIG_FILE_NAME) }
    let(:some_file) { File.expand_path('~/some_example_file') }
    let(:invalid_file) { "fake_file" }

    let(:sample_conf) { {default:
                             {log_datetime_format: "%Y-%m-%d %H:%M:%S",
                              log_path: "~/.visor/logs"},
                         registry:
                             {bind_host: "0.0.0.0", bind_port: 4567,
                              backend: {uri: "mongodb://:@127.0.0.1:27017/visor"},
                              log: {file: "visor-registry.log", level: "DEBUG"}}} }

    before(:all) do
      unless File.exists?(file)
        File.open(file, 'w') do |f|
          f.write(sample_conf.to_yaml.stringify_keys)
        end
      end
      File.open(some_file, 'w')
    end

    after(:all) do
      File.delete(some_file)
    end

    describe "#find_config_file" do
      it "should find a configuration file in default dirs if it exists" do
        Config.find_config_file.should == file
      end

      it "should get an existing config file as option" do
        Config.find_config_file(some_file).should == some_file
      end

      it "should return nil if no configuration file found" do
        Config.find_config_file(invalid_file).should be_nil
      end
    end

    describe "#load_config" do
      it "should raise if there is no configuration files" do
        lambda { Config.load_config(nil, invalid_file) }.should raise_exception
      end

      it "should return a valid hash" do
        conf = Config.load_config
        conf.should be_a Hash
        conf.should_not be_empty
      end

      it "should return scoped configuration" do
        conf = Config.load_config :default
        conf.keys.should == sample_conf[:default].keys << :file
      end
    end

    describe "#build_logger" do
      it "should return a Logger for a specific app" do
        log = Config.build_logger :registry
        log.should be_a Logger
      end
    end

    describe "#validate_logger" do
      it "should pass if all configurations are OK" do
        l = lambda { Config.validate_logger(sample_conf, :registry) }
        l.should_not raise_exception
      end

      it "should raise if any error is found on configuration file options" do
        l = lambda { Config.validate_logger(sample_conf.delete(:default), :registry) }
        l.should raise_exception
      end
    end
  end
end
