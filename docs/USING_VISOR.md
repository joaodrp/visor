# Using VISOR

In this appendix we will present some examples on how to use VISOR to manage VM images, using its main client tool: a CLI named `visor`. This CLI was already installed in the Client machine, previously configured in [Installing and Configuring VISOR](http://www.cvisor.org/file.INSTALLATION.html).

<hr/>
To use VISOR, examples in this chapter should be reproduced in the **Client** machine, previously configured in [Installing and Configuring VISOR](http://www.cvisor.org/file.INSTALLATION.html).
<hr/>

To see an help message about the client CLI, the `visor` command should be used with the `-h` option:

	prompt $> visor -h
	Usage: visor <command> [options]

	Commands:
	     brief      Show brief metadata of all public and user's private images
	     detail     Show detailed metadata of all public and user's private images
	     head       Show an image detailed metadata
	     get        Retrieve an image metadata and file
	     add        Add a new image metadata and optionally upload its file
	     update     Update an image metadata and/or upload its file
	     delete     Delete an image metadata and its file
	     help       Show help message for one of the above commands

	Options:
	    -a, --address HOST      Address of the VISOR Image System server
	    -p, --port PORT         Port where the VISOR Image System server listens
	    -q, --query QUERY       HTTP query like string to filter results
	    -s, --sort ATTRIBUTE    Attribute to sort results (default: _id)
	    -d, --dir DIRECTION     Direction to sort results (asc/desc) (default: asc)
	    -f, --file IMAGE        Image file path to upload
	    -S, --save DIRECTORY    Directory to save downloaded image (default: './')

	Common options:
	    -v, --verbose            Enable verbose
	    -h, --help               Show this help message
	    -V, --version            Show version
	prompt $>
	
## Assumptions

We need some VM images to register in VISOR. Therefore, we assume that users have down- loaded and placed the following sample images inside their home folder in the Client machine:

- [Fedora-17-x86_64-Live-Desktop.iso](http://download.fedoraproject.org/pub/fedora/linux/releases/17/Live/x86_64/Fedora-17-x86_64-Live-Desktop.iso): Fedora Desktop 17 64-bit VM image.

- [CentOS-6.2-i386-LiveCD.iso](http://mirrors.arsc.edu/centos/6.2/isos/i386/CentOS-6.2-i386-LiveCD.iso): CentOS 6.2 32-bit VM image.

## Help Message

For displaying a detailed help message for a specific command, we can use the `help` command, followed by a specific command name for which we want to see a help message:

	prompt $> visor help add
	Usage: visor add <ATTRIBUTES> [options]
	
	Add new metadata and optionally upload the image file.
	The following attributes can be specified as key/value pairs:

	        name: The image name
	architecture: The Image operating system architecture (available: i386 x86_64)
	      access: If the image is public or private (available: public private)
	      format: The image format (available: iso vhd vdi vmdk ami aki ari)
	        type: The image type (available: kernel ramdisk machine)
	       store: The storage backend (s3 lcs walrus cumulus hdfs http file)
	    location: The location URI of the already somewhere stored image

	Any other custom image property can be passed too as additional key/value pairs.

	Provide the --file option with the path to the image to be uploaded and the
	'store' attribute, defining the store where the image should be uploaded to.
	prompt $>
	
## Register an Image

### Metadata Only

For registering only image metadata, without uploading or referencing an image file, users should use the command add, providing to it the image metadata as a set of key/value pairs arguments in any number, separated between them with a single space:

	prompt $> visor add name='CentOS 6.2' architecture='i386' format='iso' access='private'
	Successfully added new metadata with ID 7583d669-8a65-41f1-b8ae-eb34ff6b322f.

	         _ID: 7583d669-8a65-41f1-b8ae-eb34ff6b322f
	         URI: http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f
	        NAME: CentOS 6.2
	ARCHITECTURE: i386
	      ACCESS: private
	      STATUS: locked
	      FORMAT: iso
	  CREATED_AT: 2012-06-15 21:01:21 +0100
	       OWNER: foo
	prompt $>
	
As can be seen in the above example, we have registered the metadata of the CentOS 6.2 VM image. We have set its access permission to ”private”, thus only user ”foo” can see and modify it. Status is automatically set to ”locked”, since we have not uploaded or referenced its image file but only registered its metadata.

### Upload Image

For registering and uploading an image file, users can issue the command add, providing to it the image metadata as a set of key/value pairs arguments, and the `--file` option, followed by the VM image file path:

	prompt $> visor add name='Fedora Desktop 17' architecture='x86_64' \
	format='iso' store='file' --file '~/Fedora-17-x86_64-Live-Desktop.iso'

	Adding new metadata and uploading file...
	Successfully added new image with ID e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.

	         _ID: e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	         URI: http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	        NAME: Fedora Desktop 17
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 676331520
	       STORE: file
	    LOCATION: file:///home/joaodrp/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso
	  CREATED_AT: 2012-06-15 21:03:32 +0100
	    CHECKSUM: 330dcb53f253acdf76431cecca0fefe7
	       OWNER: foo
	 UPLOADED_AT: 2012-06-15 21:03:50 +0100
	prompt $>
	
### Reference Image Location

If users want to reference an already somewhere stored image file, it can be done by including
the store and location attributes, with the latter being set to the VM image file URI:

	prompt $> visor add name='Ubuntu 12.04 Server' architecture='x86_64' format='iso' store='http' location='http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso'

	Adding new metadata and uploading file...
	Successfully added new metadata with ID edfa919a-0415-4d26-b54d-ae78ffc4dc79.

	         _ID: edfa919a-0415-4d26-b54d-ae78ffc4dc79
	         URI: http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79
	        NAME: Ubuntu 12.04 Server
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 732213248
	       STORE: http
	    LOCATION: http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso
	  CREATED_AT: 2012-06-15 21:05:20 +0100
	    CHECKSUM: 140f3-2ba4b000-4be8328106940
	       OWNER: foo
	prompt $>
	
In the above example we have registered an Ubuntu Server 12.04 64-bit VM image, by ref- erencing its location through a HTTP URL. As can be observed, VISOR was able to locate that image file and find its size and checksum through the URL resource HTTP headers.

## Retrieve Image Metadata

### Metadata Only

For retrieving an image metadata only, without the need to also download its file, users can use the head command, providing the image ID as first argument. The produced output is similar to that received when the image was registered.

	prompt $> visor head e5fe8ea5-4704-48f1-905a-f5747cf8ba5e

	         _ID: e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	         URI: http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	        NAME: Fedora Desktop 17
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 676331520
	       STORE: file
	    LOCATION: file:///home/joaodrp/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso
	  CREATED_AT: 2012-06-15 21:03:32 +0100
	    CHECKSUM: 330dcb53f253acdf76431cecca0fefe7
	       OWNER: foo
	 UPLOADED_AT: 2012-06-15 21:03:50 +0100
	
### Brief Metadata

For requesting the brief metadata of all public and user’s private images, one can use the `brief` command:

	prompt $> visor brief
	Found 3 image records...
	ID            NAME                 ARCHITECTURE  TYPE  FORMAT  STORE  SIZE      
	-----------  --------------------  ------------  ----  ------  -----  ---------
	e5fe8ea5...  Fedora Desktop 17     x86_64        -     iso     file   676331520 
	edfa919a...  Ubuntu 12.04 Server   x86_64        -     iso     http   732213248 
	7583d669...  CentOS 6.2            i386          -     iso     -      -
	
### Detailed Metadata

For requesting the detailed metadata of all public and user’s private images, one can use the `detail` command:

	prompt $> visor detail
	Found 3 image records...
	--------------------------------------------------------------------------------
	         _ID: e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	         URI: http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	        NAME: Fedora Desktop 17
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 676331520
	       STORE: file
	    LOCATION: file:///home/joaodrp/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso
	  CREATED_AT: 2012-06-15 21:03:32 +0100
	    CHECKSUM: 330dcb53f253acdf76431cecca0fefe7
	       OWNER: foo
	 UPLOADED_AT: 2012-06-15 21:03:50 +0100
	--------------------------------------------------------------------------------
	         _ID: edfa919a-0415-4d26-b54d-ae78ffc4dc79
	         URI: http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79
	        NAME: Ubuntu 12.04 Server
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 732213248
	       STORE: http
	    LOCATION: http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso
	  CREATED_AT: 2012-06-15 21:05:20 +0100
	    CHECKSUM: 140f3-2ba4b000-4be8328106940
	       OWNER: foo
	--------------------------------------------------------------------------------
	         _ID: 7583d669-8a65-41f1-b8ae-eb34ff6b322f
	         URI: http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f
	        NAME: CentOS 6.2
	ARCHITECTURE: i386
	      ACCESS: private
	      STATUS: locked
	      FORMAT: iso
	  CREATED_AT: 2012-06-15 21:01:21 +0100
	       OWNER: foo
	
### Filtering Results

It is also possible to filter results based in some query string. Such query string should conform to the HTTP query string format. Thus, for example, if we want to get brief metatada of all 64-bit images stored in the HTTP backend only, we would do it as follows:

	prompt $> visor brief --query 'architecture=x86_64&store=http'
	Found 1 image records...
	ID           NAME                  ARCHITECTURE  TYPE  FORMAT  STORE  SIZE      
	-----------  --------------------  ------------  ----  ------  -----  ---------
	edfa919a...  Ubuntu 12.04 Server   x86_64        -     iso     http   732213248
	
	
## Retrieve an Image

The ability to download an image file along with its metadata is exposed through the `get` command, providing to it the image ID string as first argument. If we do not want to save the image in the current directory, it is possible to provide the `--save` option, followed by the path to where we want to download the image.

	prompt $> visor get e5fe8ea5-4704-48f1-905a-f5747cf8ba5e

	         _ID: e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	         URI: http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e
	        NAME: Fedora Desktop 17
	ARCHITECTURE: x86_64
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 676331520
	       STORE: file
	    LOCATION: file:///home/joaodrp/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso
	  CREATED_AT: 2012-06-15 21:03:32 +0100
	  UPDATED_AT: 2012-06-15 21:07:14 +0100
	    CHECKSUM: 330dcb53f253acdf76431cecca0fefe7
	       OWNER: foo
	 UPLOADED_AT: 2012-06-15 21:03:50 +0100

	Downloading image e5fe8ea5-4704-48f1-905a-f5747cf8ba5e...      | ETA:  --:--:--
	Progress:      100% |=========================================| Time:   0:00:16
	
## Update an Image

### Metadata Only

For updating an image metadata, users can issue the command `update`, providing the image ID string as first argument, followed by any number of key/value pairs to update metadata. If wanting to receive the already updated metadata, the `-v` option should be passed:

	prompt $>visor update edfa919a-0415-4d26-b54d-ae78ffc4dc79 name='Ubuntu 12.04' architecture='i386' -v

	Successfully updated image edfa919a-0415-4d26-b54d-ae78ffc4dc79.

	         _ID: edfa919a-0415-4d26-b54d-ae78ffc4dc79
	         URI: http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79
	        NAME: Ubuntu 12.04
	ARCHITECTURE: i386
	      ACCESS: public
	      STATUS: available
	      FORMAT: iso
	        SIZE: 732213248
	       STORE: http
	    LOCATION: http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso
	  CREATED_AT: 2012-06-15 21:05:20 +0100
	  UPDATED_AT: 2012-06-15 21:10:36 +0100
	    CHECKSUM: 140f3-2ba4b000-4be8328106940
	       OWNER: foo
	
### Upload or Reference Image

If users want to upload or reference an image file to a registered metadata, it can be done by providing the `--file` option, or the location attribute, as done for the `add` command.

	prompt $>visor update 7583d669-8a65-41f1-b8ae-eb34ff6b322f store='file' \
	format='iso' --file '~/CentOS-6.2-i386-LiveCD.iso' -v

	Updating metadata and uploading file...
	Successfully updated and uploaded image 7583d669-8a65-41f1-b8ae-eb34ff6b322f.

	         _ID: 7583d669-8a65-41f1-b8ae-eb34ff6b322f
	         URI: http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f
	        NAME: CentOS 6.2
	ARCHITECTURE: i386
	      ACCESS: private
	      STATUS: available
	      FORMAT: iso
	        SIZE: 729808896
	       STORE: file
	    LOCATION: file:///home/joaodrp/VMs/7583d669-8a65-41f1-b8ae-eb34ff6b322f.iso
	  CREATED_AT: 2012-06-15 21:01:21 +0100
	  UPDATED_AT: 2012-06-15 21:12:27 +0100
	    CHECKSUM: 1b8441b6f4556be61c16d9750da42b3f
	       OWNER: foo
	prompt $>
	
## Delete an Image

To receive as response the already deleted image metadata, the `-v` option should be used in the following `delete` command examples.

### Delete a Single Image

To remove an image metadata along with its file (if any), we can use the `delete` command, followed by the image ID provided as its first argument:

	prompt $> visor delete 7583d669-8a65-41f1-b8ae-eb34ff6b322f

	Successfully deleted image 7583d669-8a65-41f1-b8ae-eb34ff6b322f.
	prompt $>

### Delete Multiple Images

It is also possible to remove more than one image at the same time, providing a set of IDs separated by a single space:

	prompt $> visor delete e5fe8ea5-4704-48f1-905a-f5747cf8ba5e edfa919a-0415-4d26-b54d-ae78ffc4dc79

	Successfully deleted image e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.
	Successfully deleted image edfa919a-0415-4d26-b54d-ae78ffc4dc79.
	prompt $>
	
It is also possible to remove images that match a given query with the `--query` option. The images removed in the example above, could have also been removed using a query to match 64-bit (x86_64) images, as they were the only ones in the repository with that architecture:

	prompt $> visor delete --query 'architecture=x86_64'

	Successfully deleted image e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.
	Successfully deleted image edfa919a-0415-4d26-b54d-ae78ffc4dc79.
	prompt $>