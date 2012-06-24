# VISOR Configuration File Template

This guide lists the [YAML format](http://www.yaml.org/spec/1.2/spec.html) VISOR configuration file template, which is generated at VISOR subsystems installation time, using the `visor-config` command. Fields with empty values are those which should be necessarily set by users when needed.

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