require "spec_helper"
require "securerandom"

include Visor::Auth::Backends

describe Visor::Auth::Server do
  let(:parse_opts) { {symbolize_names: true} }

  let(:valid_post) { {user: {access_key: 'foo', email: 'foo@bar.com'}} }
  let(:invalid_post) { {user: {access_key: 'foo'}} }

  let(:valid_update) { {user: {email: 'foobar@bar.com'}} }
  let(:invalid_update) { {user: {secret_key: 'this is not valid'}} }

  inserted = []

  def users_from(last_response)
    response = JSON.parse(last_response.body, parse_opts)
    response[:user] || response[:users]
  end

  def message_from(last_response)
    JSON.parse(last_response.body, parse_opts)[:message]
  end

  def delete_all
    get '/users'
    users = users_from(last_response)
    users.each { |user| delete "/users/#{user[:access_key]}" }
  end

  def generate_user
    {user: {access_key: SecureRandom.hex(10), email: 'foo@bar.com'}}
  end

  before(:each) do
    post '/users', generate_user.to_json
    @valid_access_key = users_from(last_response)[:access_key]
    inserted << @valid_access_key
  end

  after(:all) do
    inserted.each { |access_key| delete "/users/#{access_key}" }
  end

  describe "GET on /users" do
    before(:each) do
      get '/users'
      last_response.should be_ok
    end

    it "should return an array" do
      get '/users'
      users = users_from(last_response)
      users.should be_a Array
    end

    it "should filter results" do
      get '/users'
      users = users_from(last_response)
      get "/users?email=#{users.sample[:email]}"
      users = users_from(last_response)
      users.each { |u| u[:email].should == users.sample[:email] }
    end

    it "should raise an 404 error if no users were found" do
      #delete_all
      #get '/images'
      #last_response.status.should == 404
      #message_from(last_response).should match /no image found/
    end
  end

  describe "GET on /users/:access_key" do
    before(:each) do
      get "/users/#{@valid_access_key}"
      last_response.should be_ok
    end

    it "should return a hash with the user data" do
      user = users_from(last_response)
      user.should be_a Hash
      user[:email].should be_a String
    end

    it "should raise a 404 error if user not found" do
      get "/users/fake_id"
      last_response.status.should == 404
      message_from(last_response).should match /No user found/
    end
  end

  describe "POST on /users" do
    it "should create a new user and return its data" do
      post '/users', generate_user.to_json
      last_response.should be_ok
      user = users_from(last_response)
      user[:access_key].should be_a String
      inserted << user[:access_key]
    end

    it "should raise a 409 error if access_key was already taken" do
      exists = { user: { access_key: @valid_access_key, email:'foo@bar.com' }}
      post '/users', exists.to_json
      last_response.status.should == 409
    end

    it "should raise a 400 error if data validation fails" do
      post '/users', invalid_post.to_json
      last_response.status.should == 400
      message_from(last_response).should match /email/
    end

    it "should raise a 404 error if referenced an invalid kernel/ramdisk image" do
      #post '/images', valid_post.merge(kernel: "fake_id").to_json
      #message_from(last_response).should match /no image found/
    end
  end

  describe "PUT on /users/:access_key" do
    it "should update an existing user data and return it" do
      put "/users/#{@valid_access_key}", valid_update.to_json
      last_response.should be_ok
      user = users_from(last_response)
      user[:email].should == valid_update[:user][:email]
    end

    it "should raise a 409 error if access_key was already taken" do
      exists = { user: { access_key: @valid_access_key, email:'foo@bar.com' }}
      post '/users', exists.to_json
      last_response.status.should == 409
    end

    it "should raise a 400 error if user data validation fails" do
      put "/users/#{@valid_access_key}", invalid_update.to_json
      last_response.status.should == 400
    end

    it "should raise a 404 error if referenced an invalid kernel/ramdisk image" do
      #put "/images/#{@valid_access_key}", valid_update.merge(kernel: "fake_id").to_json
      #message_from(last_response).should match /No image found/
    end
  end

  describe "DELETE on /users/:access_key" do
    it "should delete an user data" do
      delete "/users/#{@valid_access_key}"
      last_response.should be_ok

      user = users_from(last_response)
      user.should be_a Hash
      user[:access_key].should == @valid_access_key

      get "/users/#{@valid_access_key}"
      last_response.status.should == 404
    end

    it "should raise a 404 error if user not found" do
      delete "/users/fake_id"
      last_response.status.should == 404
      message_from(last_response).should match /No user found/
    end
  end

  describe "Operation on a not implemented path" do
    after(:each) do
      last_response.status.should == 404
      message_from(last_response).should match /Invalid operation or path/
    end

    it "should raise a 404 error for a GET request" do
      get "/fake"
    end

    it "should raise a 404 error for a POST request" do
      post "/fake"
    end

    it "should raise a 404 error for a PUT request" do
      put "/fake"
    end

    it "should raise a 404 error for a POST request" do
      delete "/fake"
    end
  end

end

