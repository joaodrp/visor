# Installing and Configuring VISOR

In this guide we provide a complete quick start guide to install and deploy VISOR. We will describe all the necessary installation and configuration procedures.

## Deployment Environment

We will install VISOR by distributing its subsystems across three independent machines, with two host servers and one client. However, any other subsystems arrangement can be made by administrators (e.g. a subsystem per machine, all subsystems in the same machine). During the installation procedures we will always indicate in which machines a specific procedure should be reproduced. The deployment environment is pictured in following figure:

![VISOR deployment](http://joaodrp.com/img/visor_install.png)

- **Server 1:** This machine will host the VISOR Image System (VIS), which is VISOR’s core and client’s front-end. The VIS server application will create a log file in which it will log operations. This machine will also comprise a VISOR configuration file, which will contain the necessary configuration options for customizing VIS.
<br/>
- **Server 2:** This server will host both VISOR Meta System (VMS) and VISOR Auth System (VAS). Therefore, as they live in the same machine, they will use an underlying database to store both user accounts and image metadata. Both VMS and VAS will log to a local logging file. This server will host another VISOR configuration file which will contain the necessary parameters to configure both VMS and VAS.
<br/>
- **Client:** The Client machine will host the VIS CLI, which will communicate with the VIS server hosted in Server 1. It will also contain a VISOR configuration file, including the necessary parameters to configure the VIS CLI.

## Installing Dependencies

Before starting to install VISOR, we need to ensure that all required dependencies are properly installed and available in the deployment machines.

We will provide instructions tested on Ubuntu Server 12.04 LTS and Mac OSX Server 10.6 64-bit OSs. Instructions for installing these dependencies in other Unix-based OSs can be easily found among Internet resources.

### Ruby
<hr/>
These procedures should be reproduced in all machines (**Server 1**, **Server 2** and **Client**).
<hr/>

VISOR depends on the [Ruby programming language](http://www.ruby-lang.org/en/), thus all machines used to host VISOR need to have the Ruby binaries installed. Since VISOR targets Unix systems, most up-to-date Linux and Mac OSX OSs are equipped with Ruby installed by default. However, VISOR requires Ruby to be at least in version 1.9.2. To ensure that host machines fulfil this requirement, users should open a terminal window and issue the following command (”prompt $>” indicates the terminal prompt position):

	prompt $> ruby -v

If users’ machines have Ruby installed, they should see a message displaying ”ruby” followed by its version number. If receiving a ”command not found” error, that machines do not have Ruby installed. If seeing a Ruby version lower than 1.9.2 or machines do not have Ruby installed at all, it should be installed as follows (depending on the used OS):

#### Ubuntu

	prompt $> sudo apt-get update
	prompt $> sudo apt-get install build-essential ruby1.9.3

#### Mac OSX
In Mac OSX, users should make sure that they have already installed Apple’s Xcode (a developer library which should have come with Mac OSX installation disk) on machines before proceeding.

	# First, install Homebrew, a free Mac OSX package manager
	prompt $> /usr/bin/ruby -e "$(/usr/bin/curl -fsSL https://raw.github.com/mxcl/homebrew/master/Library/Contributions/install_homebrew.rb)"
	# Now install Ruby with Homebrew
	prompt $> brew install ruby

### Database System

<hr/>
These procedures should be reproduced in **Server 2**.
<hr/>

Since both VMS and VAS register data on a database, it is required to install a database system. Both VMS and VAS support MongoDB and MySQL databases, therefore it is user’s responsibility to choose which one to install and use. Users can install either MongoDB or MySQL as follows:

#### Ubuntu
	# Install MongoDB
	prompt> sudo apt-get install mongodb
	# Or install MySQL
	prompt> sudo apt-get install mysql-server mysql-client libmysqlclient-dev

#### Mac OSX
	# Install MongoDB
	prompt $> brew install mongodb 
	# Or install MySQL
	prompt $> brew install mysql

## Configuring the VISOR Database

<hr/>
These procedures should be reproduced in **Server 2**.
<hr/>

ow that all dependencies are satisfied, it is time to configure a database for VISOR. Users should follow these instructions if they have chosen either MongoDB or MySQL:

### MongoDB
We just need to make sure that MongoDB was successfully installed, since MongoDB lets VISOR
create a database automatically. Users should open a terminal window and type `mongo`:

	prompt $> mongo
	MongoDB shell version: 2.0.4
	connecting to: test

If seeing something like the above output, MongoDB was successfully installed. Typing exit quits from the MongoDB shell. By default MongoDB does not have user’s authentication enabled. For the sake of simplicity we will leave it that way. To configure an user account, one should follow the authentication tutorial in the [MongoDB documentation](http://www.mongodb.org/display/DOCS/Security+and+Authentication).

### MySQL

If users have chosen to run VISOR backed by MySQL, they need to create and configure a database and an user account for it. To enter in the MySQL shell, the following command should be issued:

	prompt $> mysql -u root

The following SQL queries should be used to create a database and an user account for VISOR. Users can provide a different database name, username (we will use ”visor” for both) and password (”passwd”), making sure to note those credentials as they will be further required:

	CREATE DATABASE visor;
	CREATE USER 'visor'@'localhost' IDENTIFIED BY 'passwd';
	GRANT ALL PRIVILEGES ON *.* TO 'visor'@'localhost';
	FLUSH PRIVILEGES;

If everything went without errors, we have already completed the database configurations (VISOR will handle tables creation). By typing `exit;` we will quit from the MySQL shell.

## Installing VISOR

<hr/>
From now on, all the presented commands are compatible with all popular Unix-based OSs, such as Ubuntu, Fedora, CentOS, RedHat, Mac OSX and others.
<hr/>

We have already prepared Server 1, Server 2 and Client machines to host VISOR. Thus, we can now download and install it. The VISOR service is currently distributed as a set of subsystems packaged in Ruby libraries, which are commonly known as gems. Therefore we will install each subsystem with a single command, downloading the required gem that will be automatically installed and configured.

### VISOR Auth and Meta Systems

<hr/>
These procedures should be reproduced in **Server 2**.
<hr/>

We will now install VAS and VMS subsystems in Server 2. To install these subsystems, users should issue the following command on a terminal window:

	prompt $> sudo gem install visor-auth visor-meta
	
This command will automatically download, install and configure the last releases of the VAS and VMS from the Ruby gems on-line repository. During VAS and VMS installation, the VISOR Common System (VCS) will be automatically fetched and installed too (being `visor-common` gem), as all VISOR subsystems depend on it. After the installation completes, we will see a similar terminal output as the one below:

	prompt $> sudo gem install visor-auth visor-meta
	Successfully installed visor-common-0.0.2
	****************************** VISOR ******************************
	visor-auth was successfully installed!
	Generate the VISOR configuration file for this machine (if not already done)
	by running the 'visor-config' command.
	*******************************************************************
	Successfully installed visor-auth-0.0.2
	****************************** VISOR ******************************
	visor-meta was successfully installed!
	Generate the VISOR configuration file for this machine (if not already done)
	by running the 'visor-config' command.
	*******************************************************************
	Successfully installed visor-meta-0.0.2
	prompt $>

As can be observed in the above output, both `visor-auth` and `visor-meta` were successfully installed, with `visor-common` being automatically installed prior to them. Both VAS and VMS display an informative message indicating that they were successfully installed, and that now the user should generate the VISOR configuration file for Server 2 machine.


#### Generating Server 2 Configuration File
To generate a template configuration file for the VAS and VMS host machine, the `visor-config` command should be used:

	prompt $> visor-config
	Generating VISOR configuration directories and files:
	creating /Users/joaodrp/.visor...                  [DONE]
	creating /Users/joaodrp/.visor/logs...             [DONE]
	creating /Users/joaodrp/.visor/visor-config.yml... [DONE]
	All configurations were successful. Now open and customize the VISOR
	configuration file at /Users/joaodrp/.visor/visor-config.yml
	prompt $>

As listed in the output above, the VISOR configuration file and directories were success- fully generated. These include the YAML format [YAML format](http://www.yaml.org/spec/1.2/spec.html) VISOR configuration file named `visor-config.yml`, the `logs` directory to where both VAS and VMS servers will log, and the parent `.visor` directory placed in the user's home folder, in this case `/Users/joaodrp/`.

#### Customizing Server 2 Configuration File
The generated configuration file should now be opened and customized. The full generated configuration file template is listed in [VISOR Configuration File](http://www.cvisor.org/file.CONFIGURATION_FILE.html).  Here we will only address the parts of the configuration file that should be customized within the VMS and VAS host machine. The remain parameters can be leaved with their default values.

##### Bind Host

Users should change the host address to bind the VAS and VMS servers through the bind_host parameters (lines 6 and 13) to their Server 2 IP address (which in our case is 10.0.0.2):

	...
	# ================================ VISOR Auth =================================
	visor_auth:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.2
	    bind_port: 4566
	...
	# ================================ VISOR Meta =================================
	visor_meta:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.2
	    bind_port: 4567
	...
	
##### Backend 

Users should also customize the backend option for both VAS and VMS by uncomment and customizing the lines for using either MongoDB or MySQL, depending on the already chosen database system:

If users have chosen to use MongoDB, and considering that it is listening on its default host and port address (127.0.0.1:27017), with no authentication and using _visor_ as the database name, the `backend` option for both VAS and VMS should be set as follows:

	...
	# ============================= VISOR Auth ===============================
	visor_auth:
	...
	    # Backend connection string (backend://user:pass@host:port/database)
	    backend: mongodb://:@127.0.0.1:27017/visor
	...
	# ============================= VISOR Meta ===============================
	visor_meta:
	...
	    # Backend connection string (backend://user:pass@host:port/database)
	    backend: mongodb://:@127.0.0.1:27017/visor
	...
	
If users have chosen MySQL, and considering that it is listening on its default host and port address (127.0.0.1:3306), the `backend` option for both VAS and VMS should be set (with user’s credentials previously obtained) as follows:

	...
	# ============================= VISOR Auth ===============================
	visor_auth:
	...
	    # Backend connection string (backend://user:pass@host:port/database)
	    backend: mysql://visor:passwd@127.0.0.1:3306/visor
	...
	# ============================= VISOR Meta ===============================
	visor_meta:
	...
	    # Backend connection string (backend://user:pass@host:port/database)
	    backend: mysql://visor:passwd@127.0.0.1:3306/visor
	...
	
Users should make sure to provide the username, password and database name previously obtained, then saving the configuration file.


#### Starting VISOR Auth System

After completed all configurations, we can now launch the VAS server. Users should open a new terminal window (**keeping it open during the rest of this guide**) and use the following command:

	prompt $> visor-auth start -d -f
	[2012-06-14 13:04:15] INFO - Starting visor-auth at 10.0.0.2:4566
	[2012-06-14 13:04:15] DEBUG - Configs /Users/joaodrp/.visor/visor-config.yml:
	[2012-06-14 13:04:15] DEBUG - *************************************************
	[2012-06-14 13:04:15] DEBUG - log_datetime_format: %Y-%m-%d %H:%M:%S
	[2012-06-14 13:04:15] DEBUG - log_path: ~/.visor/logs
	[2012-06-14 13:04:15] DEBUG - bind_host: 10.0.0.2
	[2012-06-14 13:04:15] DEBUG - bind_port: 4566
	[2012-06-14 13:04:15] DEBUG - backend: mongodb://:@127.0.0.1:27017/visor
	[2012-06-14 13:04:15] DEBUG - log_file: visor-auth-server.log
	[2012-06-14 13:04:15] DEBUG - log_level: INFO
	[2012-06-14 13:04:15] DEBUG - *************************************************
	[2012-06-14 13:04:15] DEBUG - Configurations passed from visor-auth CLI:
	[2012-06-14 13:04:15] DEBUG - *************************************************
	[2012-06-14 13:04:15] DEBUG - debug: true
	[2012-06-14 13:04:15] DEBUG - foreground: true
	[2012-06-14 13:04:15] DEBUG - *************************************************

In the above output we have started the VAS server in debug mode. We have also started it in foreground, therefore the process will remain yielding logging output to the terminal. If wanting to start it in background (daemon process), it can be done by omitting the `-f` flag:

	prompt $> visor-auth start
	Starting visor-auth at 10.0.0.2:4566
	prompt $>
	
To stop the VAS when it was started as a daemon process, the `stop` command should be used:

	prompt $> visor-auth stop
	Stopping visor-auth with PID: 41466 Signal: INT
	
In this case, the VAS server process was running with the identifier (PID) 41466 and was killed using a system interrupt (INT). Passing the `-h` option to `visor-auth` displays an help message:

	prompt $> visor-auth -h
	Usage: visor-auth [OPTIONS] COMMAND

	Commands:
	     start        start the server
	     stop         stop the server
	     restart      restart the server
	     status       current server status

	Options:
	    -c, --config FILE                Load a custom configuration file
	    -a, --address HOST               Bind to HOST address
	    -p, --port PORT                  Bind to PORT number
	    -e, --env ENV                    Set execution environment
	    -f, --foreground                 Do not daemonize, run in foreground

	Common options:
	    -d, --debug                      Enable debugging
	    -h, --help                       Show this help message
	    -v, --version                    Show version
	prompt $>
	
If users have stopped VAS during the above examples, they should open a terminal window (**keeping it open during the rest of this guide**) and start it again:

	prompt $> visor-auth start -d -f

<hr/>
All the above operations on how to manage the VAS server apply to all VISOR subsystems server’s management. The only difference is the command name. For managing VIS it is `visor-image`, for VMS it is `visor-meta` and for VAS it is the `visor-auth` command.
<hr/>

#### Generating an User Account

In order to authenticate against VISOR, one should first create an user account. This is done in VAS, using the `visor-admin` command. On a new terminal window, users can see an help message on how to use `visor-admin` by calling it with the `-h` parameter:

	prompt $> visor-admin -h
	Usage: visor-admin <command> [options]

	Commands:
	     list           Show all registered users
	     get            Show a specific user
	     add            Register a new user
	     update         Update an user
	     delete         Delete an user
	     clean          Delete all users
	     help <cmd>     Show help message for one of the above commands

	Options:
	    -a, --access KEY                 The user access key (username)
	    -e, --email ADDRESS              The user email address
	    -q, --query QUERY                HTTP query like string to filter results

	Common options:
	    -v, --verbose                    Enable verbose
	    -h, --help                       Show this help message
	    -V, --version                    Show version
	prompt $>

It is also possible to ask for a detailed help message for a given command. For example, to know more about how to add a new user, the following command can be used:

	prompt $> visor-admin help add
	Usage: visor-admin add <ATTRIBUTES> [options]

	Add a new user, providing its attributes.

	The following attributes can be specified as key/value pairs:

	  access_key: The wanted user access key (username)
	       email: The user email address

	Examples:
	  $ visor-admin add access_key=foo email=foo@bar.com
	prompt $>
	
We will follow the above example to add a new user account for user ’foo’:

	prompt $> visor-admin add access_key=foo email=foo@bar.com
	Successfully added new user with access key 'foo'.
	        ID: 8a65ab69-59b3-4efc-859a-200e6341786e
	ACCESS_KEY: foo
	SECRET_KEY: P1qGJkJqWNEwwpSyWbh4cUljxkxbdTwen6m/pwF2
	     EMAIL: foo@bar.com
	CREATED_AT: 2012-06-10 16:31:01 UTC
	prompt $>
	
Users should make sure to note the generated user credential (access key and secret key) somewhere, as they will be further required to configure the Client machine.

#### Starting VISOR Meta System

To start the VMS, user should open a new terminal window (**keeping it open during the rest of this guide**) and use the `visor-meta` command:

	prompt $> visor-meta start -d -f

Now we have finished both VAS and VMS configurations, and their servers are up and running.

### VISOR Image System

<hr/>
These procedures should be reproduced in **Server 1**.
<br/>

We will now install the VIS subsystem. Users should open a terminal window on Server 1 and issue the following command:

	prompt $> sudo gem install visor-image

This command will automatically download, install and configure the last releases of the VIS subsystem from the Ruby gems on-line repository. During VIS installation, and as for VAS and VMS installation, the VCS subsystem will be automatically downloaded and installed.

	prompt $> sudo gem install visor-image
	Successfully installed visor-common-0.0.2
	****************************** VISOR ******************************
	visor-image was successfully installed!

	Generate the VISOR configuration file for this machine (if not already done) 
	by running the 'visor-config' command.
	*******************************************************************
	Successfully installed visor-image-0.0.2
	prompt $>
	
As observed in the above output, `visor-common` and `visor-image` were successfully installed. VIS displays an informative message indicating that it was successfully installed and now the user should generate a VISOR configuration file for the Server 1 machine.

#### Generating Server 1 Configuration File

We need to generate a configuration file for Server 1 machine in order to customize the VIS. To generate a template configuration file (as done previously for Server 2) the `visor-config` command should be used:

	prompt $> visor-config
	
#### Customizing Server 1 Configuration File

The generated configuration file should now be opened and customized. Here we will only address the parts of the configuration file that should be customized within the VIS host machine.

##### Bind Host

Users should change the host address to bind the VIS server (line 6) to their Server 1 IP address, which in our case is 10.0.0.1:

	...
	# ================================ VISOR Image ================================
	visor_image:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.1
	    bind_port: 4568
	...
	
##### VISOR Meta and Auth Systems Location

Since VIS needs to communicate with the VMS and VAS, users should indicate in the Server 1 configuration file what is the Server 2 IP address, and the ports where VMS and VAS servers are listening for incoming requests:

	...
	# ================================ VISOR Auth =================================
	visor_auth:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.2
	    bind_port: 4566
	...
	# ================================ VISOR Meta =================================
	visor_meta:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.2
	    bind_port: 4567
	...
	
In our case, Server 2 (which is the host of VMS and VAS) has the IP address 10.0.0.2. VMS and VAS were started in the default ports (4566 and 4567 respectively). Users should change the above addresses (lines 6 and 13) to their Server 2 real IP address. Equally, if they have deployed VMS and VAS in different ports, they should also change them (lines 7 and 14).

##### Storage Backends

Besides the VIS server, it is also needed to pay attention to the image storage backends configuration. The output below contains the excerpt of the configuration file that should be addressed to customize the storage backends:

	...
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
	
The configuration file contains configurations for all available storage backends, being the local filesystem, Amazon S3, Nimbus Cumulus, Eucalyptus Walrus, Lunacloud LCS and Hadoop HDFS. Users should fill the attributes of a given storage backend in order to be able to store and retrieve images from it. User’s credentials should be obtained within each storage system.

- In line 5 it is defined the storage backend that VIS should use by default to store images. Line 11 describes the path to the folder where images should be saved when using the filesystem backend. This folder will be creation by the VIS server if it do not exists.

- For S3 and LCS, users need to provide the bucket name in which images should be stored, and their access and secret keys used to authenticate against S3 or LCS, respectively.

- Cumulus, Walrus and HDFS configurations are similar. Users should provide the host address and port where these storage services are listening in. For Cumulus and Walrus they should also provide the access and secret key credentials. For HDFS users should provide their username in Hadoop.


#### Starting VISOR Image System

After customizing the VIS configuration file, users should open a new terminal window (**keeping it open during the rest of this guide**) and launch the VIS server with the `visor-image` command:

	prompt $> visor-image start -d -f
	[INFO] 2012-06-14 14:10:57 :: Starting visor-image at 10.0.0.1:4568
	[DEBUG] 2012-06-14 14:10:57 :: Configs /Users/joaodrp/.visor/visor-config.yml:
	[DEBUG] 2012-06-14 14:10:57 :: ***********************************************
	[DEBUG] 2012-06-14 14:10:57 :: log_datetime_format: %Y-%m-%d %H:%M:%S
	[DEBUG] 2012-06-14 14:10:57 :: log_path: ~/.visor/logs
	[DEBUG] 2012-06-14 14:10:57 :: bind_host: 10.0.0.1
	[DEBUG] 2012-06-14 14:10:57 :: bind_port: 4568
	[DEBUG] 2012-06-14 14:10:57 :: log_file: visor-api-server.log
	[DEBUG] 2012-06-14 14:10:57 :: log_level: INFO
	[DEBUG] 2012-06-14 14:10:57 :: ***********************************************
	[DEBUG] 2012-06-14 14:10:57 :: Configurations passed from visor-image CLI:
	[DEBUG] 2012-06-14 14:10:57 :: ***********************************************
	[DEBUG] 2012-06-14 14:10:57 :: debug: true
	[DEBUG] 2012-06-14 14:10:57 :: daemonize: false
	[DEBUG] 2012-06-14 14:10:57 :: ***********************************************
	
Now we have finished the VIS configurations and its server is up and running.

### VISOR Client

<hr/>
These procedures should be reproduced in **Client** machine.
<hr/>

The VIS subsystem contains the VISOR client tools, thus we need to install it on Client machine by simply issuing the following command:

	prompt $> sudo gem install visor-image

#### Generating Client Configuration File

We need to generate a configuration file for Client machine in order to customize the VISOR client tools. To generate a template configuration file (as done previously for Server 2) use the `visor-config` command:

	prompt $> visor-config

#### Customizing Client Configuration File

The generated configuration file should now be opened and customized. Here we will only address the parts of the configuration file that should be customized within the Client machine. The remain parameters can be leaved with their default values.

##### Bind Host 

We need to indicate where does the VIS CLI can find the VIS server. Therefore users should indicate in the configuration file the host address and the port number where the VIS server is listening. In our case it is 10.0.0.1:4568. Users should customize these attributes accordingly to the IP address and port number that they have used to deploy the VIS server:

	...
	# ================================ VISOR Image ================================
	visor_image:
	...
	    # Address and port to bind the server
	    bind_host: 10.0.0.1
	    bind_port: 4568
	...
	
Users should fill the access_key and secret_key parameters with the creden- tials obtained by them previously. In our case, the obtained credentials were the following (make sure to fill the configuration file with your own credentials):

	# ===== Default always loaded configuration throughout VISOR sub-systems ======
	...
	    # VISOR access and secret key credentials (from visor-admin command)
	    access_key: foo
	    secret_key: P1qGJkJqWNEwwpSyWbh4cUljxkxbdTwen6m/pwF2
	...
	
We have finished all VISOR installation procedures. VAS, VMS and VIS servers should now be up and running in order to proceed with the usage examples described in [Using VISOR](http://www.cvisor.org/file.USING_VISOR.html).