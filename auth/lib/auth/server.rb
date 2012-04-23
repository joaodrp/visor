require 'sinatra/base'
require 'json'
require 'uri'

module Visor
  module Auth

    # The VISoR Auth Server class. This class supports all users and groups management
    # operations through the REST API implemented along the following routes.
    #
    class Server < Sinatra::Base
      include Visor::Common::Exception
      include Visor::Common::Config

      # Configuration
      #
      configure do
        backend_map = {'mongodb' => Visor::Auth::Backends::MongoDB,
                       'mysql'   => Visor::Auth::Backends::MySQL}

        conf = Visor::Common::Config.load_config(:visor_account)
        log  = Visor::Common::Config.build_logger(:visor_account)

        DB = backend_map[conf[:backend].split(':').first].connect uri: conf[:backend]

        disable :show_exceptions, :logging #, :protection
        use Rack::CommonLogger, log
      end

      configure :development do
        require 'sinatra/reloader'
        register Sinatra::Reloader
      end

      # Helpers
      #
      helpers do
        def json_error(code, message)
          error code, {code: code, message: message}.to_json
        end
      end

      # Filters
      #
      before do
        @parse_opts = {symbolize_names: true}
        content_type :json
      end

      # Routes
      #

      # @method get_users
      # @overload get '/users'
      #
      # Get information about all registered users.
      #
      #   { "users": [{
      #       "_id":<_id>,
      #       "username":<username>,
      #       "password":<password>,
      #       "email":<email>,
      #       "created_at":<creation timestamp>,
      #       "updated_at":<update timestamp>,
      #       }, ...]}
      #
      # The following options can be passed as query parameters.
      #
      # @param [String] username The user username.
      # @param [String] email The user email address.
      # @param [Date] created_at The image creation timestamp.
      # @param [Date] updated_at The image update timestamp.
      #
      # @return [JSON] The registered users information.
      #
      # @raise [HTTP Error 404] If there is no registered users.
      #
      get '/users' do
        begin
          users = DB.get_users(params)
          {users: users}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

      # @method get_user
      # @overload get '/users/:username'
      #
      # Get information about a specific user.
      #
      #   {"image": {
      #       "_id":<_id>,
      #       "username":<username>,
      #       "password":<password>,
      #       "email":<email>,
      #       "created_at":<creation timestamp>,
      #       "updated_at":<update timestamp>
      #   }}
      #
      # @param [String] username The wanted user username.
      #
      # @return [JSON] The user detailed information.
      #
      # @raise [HTTP Error 404] If user not found.
      #
      get '/users/:username' do |username|
        begin
          user = DB.get_user(username)
          {user: user}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

      # @method post
      # @overload post '/users'
      #
      # Registers a new user and returns its data.
      #
      # @param [JSON] http-body The user information.
      #
      # @return [JSON] The already created user detailed information.
      #
      # @raise [HTTP Error 400] User information validation errors.
      # @raise [HTTP Error 404] User not found after registered.
      # @raise [HTTP Error 409] Username was already taken.
      #
      post '/users' do
        begin
          info = JSON.parse(request.body.read, @parse_opts)
          user = DB.post_user(info[:user])
          {user: user}.to_json
        rescue NotFound => e
          json_error 404, e.message
        rescue ArgumentError => e
          json_error 400, e.message
        rescue ConflictError => e
          json_error 409, e.message
        end
      end

      # @method put
      # @overload put '/users/:username'
      #
      # Update an existing user information and return it.
      #
      # @param [String] username The wanted user username.
      # @param [JSON] http-body The user information.
      #
      # @return [JSON] The already updated user detailed information.
      #
      # @raise [HTTP Error 400] User information validation errors.
      # @raise [HTTP Error 404] User not found.
      #
      put '/users/:username' do |username|
        begin
          info = JSON.parse(request.body.read, @parse_opts)
          user = DB.put_user(username, info[:user])
          {user: user}.to_json
        rescue NotFound => e
          json_error 404, e.message
        rescue ArgumentError => e
          json_error 400, e.message
        end
      end

      # @method delete
      # @overload delete '/users/:username'
      #
      # Delete an user and returns its information.
      #
      # @param [String] username The wanted user username.
      #
      # @return [JSON] The already deleted user detailed information.
      #
      # @raise [HTTP Error 404] User not found.
      #
      delete '/users/:username' do |username|
        begin
          user = DB.delete_user(username)
          {user: user}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

      # misc handlers: error, not_found, etc.
      get "*" do
        json_error 404, 'Invalid operation or path.'
      end

      put "*" do
        json_error 404, 'Invalid operation or path.'
      end

      post "*" do
        json_error 404, 'Invalid operation or path.'
      end

      delete "*" do
        json_error 404, 'Invalid operation or path.'
      end

      error do
        json_error 500, env['sinatra.error'].message
      end

    end
  end
end


