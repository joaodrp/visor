require 'logger'

module Visor
  module Meta

    # The API for the VISoR Meta. This class supports all image metadata manipulation operations.
    #
    # This is the entry-point for the VISoR Server, here are processed and logged all the calls to
    # the meta server comming from it and done through the Client API.
    #
    class Api

      LOG = Visor::Common::Config.build_logger :meta_api

      # Retrieves brief metadata of all public images.
      # Options for filtering the returned results can be passed in. Also, options for
      # initialize the Client connection can be passed too.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @return [Array] All public images brief metadata.
      #   Just {Visor::Meta::Backends::Base::BRIEF BRIEF} fields are returned.
      #
      def self.get_images(query={}, opts={})
        client = self.get_client(opts)
        LOG.info "Get images meta with query #{query}."
        client.get_images(query)
      end

      # Retrieves detailed metadata of all public images.
      # Options for filtering the returned results can be passed in. Also, options for
      # initialize the Client connection can be passed too.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @return [Array] All public images detailed metadata.
      #   The {Visor::Meta::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      def self.get_images_detail(query={}, opts={})
        client = self.get_client(opts)
        LOG.info "Get detailed images meta with query #{query}."
        client.get_images_detail(query)
      end

      # Retrieves detailed image metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @return [Hash] The requested image metadata.
      #
      def self.get_image(id, opts={})
        client = self.get_client(opts)
        LOG.info "Get image meta with _id #{id}..."
        image = client.get_image(id)
        LOG.debug "Returning image meta:\n#{image}."
        image
      end

      # Register a new image on the server with the given metadata and returns its metadata.
      #
      # @param meta [Hash] The image metadata.
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @return [Hash] The already inserted image metadata.
      #
      def self.add_image(meta, opts={})
        client = self.get_client(opts)
        LOG.info "Adding new image meta..."
        image = client.post_image(meta)
        LOG.debug "Image meta added, returning:\n#{image}."
        image
      end

      # Updates an image record with the given metadata and returns its metadata.
      #
      # @param id [String] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @return [Hash] The already updated image metadata.
      #
      def self.update_image(id, meta, opts={})
        client = self.get_client(opts)
        LOG.info "Updating image meta with _id #{id}..."
        image = client.put_image(id, meta)
        LOG.debug "Image meta updated, returning:\n#{image}."
        image
      end

      # Removes an image record based on its _id and returns its metadata.
      #
      # @param id [String] The image's _id which will be deleted.
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @raise [NotFound] If required image was not found.
      #
      def self.delete_image(id, opts={})
        client = self.get_client(opts)
        LOG.info "Deleting image meta with _id #{id}..."
        image = client.delete_image(id)
        LOG.debug "Deleted image meta, returning:\n#{image}"
        image
      end

      private

      # Creates a new new VISoR Meta Client instance.
      #
      # @option opts [String] :host (Visor::Meta::Client::DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (Visor::Meta::Client::DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      def self.get_client(opts)
        Visor::Meta::Client.new(opts)
      end

    end
  end
end
