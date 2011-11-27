module Cbolt
  module Backends
    class Backend
      # TODO: order fields in hashes

      # Keys validation
      #
      # mandatory attributes
      MANDATORY = [:name, :architecture, :access]
      # read-only attributes
      READONLY = [:_id, :uri, :owner, :status, :size, :uploaded_at, :updated_at, :accessed_at, :access_count, :checksum]
      # brief attributes (used to return only brief information about images)
      BRIEF = [:_id, :name, :architecture, :type, :format, :store, :size]
      # detail attributes to exclude from get detailed public images, this allows to show other custom attributes
      DETAIL_EXC = [:owner, :uploaded_at, :accessed_at, :access_count, :checksum]

      # Values validation
      #
      # architecture options
      ARCHITECTURE = %w[i386 x86_64]
      # access options
      ACCESS = %w[public private]
      # possible disk formats
      FORMAT = %w[none iso vhd vdi vmdk ami aki ari]
      # possible types
      TYPE = %w[none kernel ramdisk amazon eucalyptus openstack opennebula nimbus]
      # possible status
      STATUS = %w[locked uploading error available]
      # possible storages
      STORE = %w[s3 swift cumulus hdfs fs]

      attr_reader :db, :host, :port

      # Initializes a Backend instance.
      #
      # @param db [Object] The database to use.
      # @param host [Object] The host address.
      # @param port [Object] The host port.
      #
      def initialize(db, host, port)
        @db = db
        @host = host
        @port = port
      end

      # Validates the image metadata according to the possible values (constants).
      #
      # @param [Hash] meta The image metadata.
      # @param [Symbol] op The source operations invoking the validation.
      #   If the source operation is a put, then read-only and kernel and ramdisk
      #   fields are validated. if the operation is a post, all fields are validated.
      #
      # @raise[Invalid] If some of the metadata fields do not respect the
      #   possible values, contains any read-only or misses any mandatory field.
      #
      def validate_data (op, meta)
        arch, access, format = meta[:architecture], meta[:access], meta[:format]
        type, store, kernel, ramdisk = meta[:type], meta[:store], meta[:kernel], meta[:ramdisk]
        msg = ''

        meta.each_key do |key|
          msg += "The '#{key}' field is read-only.\n" if READONLY.include?(key)
        end

        if op == :post
          MANDATORY.each do |field|
            msg += "The '#{field}' field is required.\n" unless meta.has_key?(field)
          end
          BRIEF.each do |field|
            meta.merge!(field => '-') unless meta[field] || field == :_id
          end
        end

        unless ARCHITECTURE.include?(arch) || (arch.nil? && op == :put)
          msg += invalid_options_for :architecture, arch
        end
        unless ACCESS.include?(access) || (access.nil? && op == :put)
          msg += invalid_options_for :access, access
        end
        unless FORMAT.include?(format) || format.nil?
          msg += invalid_options_for :format, format
        end
        unless TYPE.include?(type) || type.nil?
          msg += invalid_options_for :type, type
        end
        unless STORE.include?(store) || store.nil?
          msg += invalid_options_for :store, store
        end

        unless kernel.nil?
          type = get_image(kernel)['type']
          if type != 'kernel' && format != 'aki'
            msg += "The image with id #{kernel} is not a kernel image.\n"
          end
        end
        unless ramdisk.nil?
          type = get_image(ramdisk)['type']
          if type != 'ramdisk' && format != 'ari'
            msg += "The image with id #{ramdisk} is not a ramdisk image.\n"
          end
        end

        raise Invalid, msg unless msg.empty?
      end

      # Set protected fields value from all kind of operations.
      # Being them the post, get and put operations.
      #
      # @param [Hash] meta The image metadata.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected(op, meta, opts = {})
        meta.symbolize_keys!
        set_protected_post(meta, opts) if op == :post
        set_protected_put(meta) if op == :put
        set_protected_get(meta) if op == :get
      end

      private

      def invalid_options_for attr, value
        options = self.class.const_get(attr.to_s.upcase).join(', ')
        "Invalid image #{attr.to_s} '#{value}', available options:\n  #{options}\n"
      end

      # Set protected fields value from a post operation.
      # Being them the uri, owner, size, status and updated_at.
      #
      # @param [Hash] meta The image metadata.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :owner (Nil) The image owner.
      # @option opts [String] :size (MONGO_DB) The image file size.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected_post(meta, opts = {})
        # TODO uploaded_at, checksum
        owner = opts[:owner] # TODO validate owner user
        size = opts[:size]
        uri = "http://#{@host}:#{@port}/images/#{meta[:_id]}"

        meta.merge!(:uri => uri, :status => 'locked', :updated_at => Time.now)
        meta.merge!(:owner => owner) unless owner.nil?
        meta.merge!(:size => size) unless size.nil?
      end

      # Set protected fields value from a put operation.
      # Being them just the updated_at.
      #
      # @param [Hash] meta The image metadata.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected_put(meta)
        meta.merge!(:updated_at => Time.now)
      end

      # Set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [Hash] meta The image metadata.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected_get(meta)
        meta.merge!(:accessed_at => Time.now)
        meta.merge!(:access_count => (meta[:access_count] || 0) + 1)
      end
    end
  end
end
