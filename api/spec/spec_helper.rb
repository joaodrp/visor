require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test
#SimpleCov.start

require File.expand_path '../../lib/api', __FILE__
require File.expand_path '../../lib/api/server', __FILE__

require 'goliath/test_helper'

Goliath.env = :test

RSpec.configure do |c|
  c.include Goliath::TestHelper, example_group: {file_path: /spec\/lib/}
  c.include Goliath::TestHelper, example_group: {file_path: /spec\/lib\/routes/}
end

conf = Visor::Common::Config.load_config
DB   = Visor::API::Meta.new(host: conf[:visor_meta][:bind_host], port: conf[:visor_meta][:bind_port])

#
# Helper methods
#
def assert_200(c)
  c.response_header.status.should == 200
end


def assert_400(c)
  c.response_header.status.should == 400
  c.response.should =~ /400/
end

def assert_404(c)
  c.response_header.status.should == 404
  c.response.should =~ /404/
  c.response.should =~ /No image found with id/
end

def assert_404_path_or_op(c)
  c.response_header.status.should == 404
  unless c.response.empty?
    c.response.should =~ /404/
    c.response.should =~ /Invalid operation or path/
  end
end

def assert_405(c, allow)
  c.response_header.status.should == 405
  c.response_header['ALLOW'].split(/, /).should == allow
end

def parse_body(c)
  assert_200 c
  body = JSON.parse(c.response, parse_opts)
  body[:image] || body[:images] || body[:message]
end
