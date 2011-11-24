module Registry
  module Backends
    class Backend
      # TODO: order fields in hashes
        # {:a => 'x', :b => 'y', :c => 'z'}
        # {:b => 'y', :a => 'x'}
        # =>
        # {:a => 'x', :b => 'y', :c => 'z'}
        # {:a => 'x', :b => 'y', :c => '-'}

      # Keys validation
      #
      # Presentation order and default value:
      # _id
      # uri
      # name
      # architecture
      # access
      # status<locked>
      # kernel<->
      # ramdisk<->
      # type<->
      # format<->
      # size<->
      # owner
      # uploaded_at<->
      # updated_at<->
      # accessed_at<->, access_count<0>, checksum
      # others
      #
      # mandatory attributes
      MANDATORY = [:name, :architecture, :access]
      # read-only attributes
      READONLY = [:_id, :uri, :owner, :status, :size, :uploaded_at, :updated_at, :accessed_at, :access_count, :checksum]

      # Values validation
      #
      # architecture options
      ARCH = %w[i386 x86_64]
      # access options
      ACCESS = %w[public private]
      # possible disk formats
      FORMATS = %w[none iso vhd vdi vmdk ami aki ari]
      # possible types
      TYPES = %w[none kernel ramdisk amazon eucalyptus openstack opennebula nimbus]
      # possible status
      STATUS = %w[locked uploading error available]
      # possible storages
      STORES = %w[s3 swift cumulus hdfs fs]

      attr_reader :db, :host, :port

      # Initializes a Backend instance.
      #
      # @param db [Object] The database to use.
      # @param host [Object] The host address.
      # @param port [Object] The host port.
      #
      def initialize(db, host, port)
        @db   = db
        @host = host
        @port = port
      end

      # Set protected fields value from all kind of operations.
      # Being them the post, get and put operations.
      #
      # @param [Hash] meta The image metadata.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected(meta, op, opts={})
        meta.symbolize_keys!
        case op
          when :post
            set_protected_post(meta, opts)
          when :put
            set_protected_put(meta)
          when :get
            set_protected_get(meta)
          else
            raise "Unhandled operation '#{op}'."
        end
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
      def validate_data(meta, op)
        arch, access = meta[:architecture], meta[:access]
        format, type = meta[:format], meta[:type]
        store, kernel = meta[:store], meta[:kernel]
        ramdisk = meta[:ramdisk]

        # assert that no read-only field is setted
        meta.each_key do |key|
          if READONLY.include?(key)
            raise Invalid, "The '#{key}' field is read-only."
          end
        end

        if op == :post
          # assert mandatory fields
          MANDATORY.each do |field|
            unless meta.has_key?(field)
              raise Invalid, "The '#{field}' field is required."
            end
          end
          # assert architecture
          unless ARCH.include?(arch)
            msg = "Invalid image architecture '#{arch}'.\nAvailable options: #{ARCH.join(', ')}"
            raise Invalid, msg
          end
          # assert access
          unless ACCESS.include?(access)
            msg = "Invalid image access '#{access}'.\nAvailable options: #{ACCESS.join(', ')}"
            raise Invalid, msg
          end
          # assert format
          unless FORMATS.include?(format) || format.nil?
            msg = "Invalid image format '#{format}'.\nAvailable options: #{FORMATS.join(', ')}"
            raise Invalid, msg
          end
          # assert type
          unless TYPES.include?(type) || type.nil?
            msg = "Invalid image type '#{type}'.\nAvailable options: #{TYPES.join(', ')}"
            raise Invalid, msg
          end
          # assert store
          unless STORES.include?(store) || store.nil?
            msg = "Invalid image store '#{store}'.\nAvailable options: #{STORES.join(', ')}"
            raise Invalid, msg
          end
        end

        # assert kernel
        unless kernel.nil?
          type = get_image(kernel)['type']
          if type != 'kernel' && format != 'aki'
            raise Invalid, "The image with id #{kernel} is not a kernel image."
          end
        end
        # assert ramdisk
        unless ramdisk.nil?
          type = get_image(ramdisk)['type']
          if type != 'ramdisk' && format != 'ari'
            raise Invalid, "The image with id #{ramdisk} is not a ramdisk image."
          end
        end
      end

      private
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
        owner = opts[:owner] || nil # TODO validate owner user
        size  = opts[:size]  || nil
        uri   = "http://#{@host}:#{@port}/images/#{meta[:_id]}"

        meta.merge!(:uri => uri)
        meta.merge!(:owner => owner) unless owner.nil?
        meta.merge!(:size => size) unless size.nil?
        meta.merge!(:status => 'locked')
        meta.merge!(:updated_at => Time.now)
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
