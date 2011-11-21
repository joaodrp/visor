module Registry

  # MONGODB
  #
  MONGO_DB = 'cbolt'
  MONGO_IP = '127.0.0.1'
  MONGO_PORT = 27017

  # FIELDS VALIDATION
  #
  # mandatory attributes
  MANDATORY = [:name, :architecture, :access]
  # read-only attributes
  READONLY = [:_id, :uri, :status, :size, :uploaded_at, :updated_at, :accessed_at, :access_count, :owner, :checksum]
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
end
# JSON.parse(s, symbolize_names => true)
