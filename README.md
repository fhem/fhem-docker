# Basic Docker image for FHEM
A basic Docker image for [FHEM](https://fhem.de/) house automation system, based on Debian Buster.


## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/).
We recommend pulling from the [main repository](https://hub.docker.com/r/fhem/fhem/) to allow automatic download of the correct image for your system platform:

	docker pull fhem/fhem

To start your container right away:

    docker run -d --name fhem -p 8083:8083 fhem/fhem

Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name fhem -p 8083:8083 -v /some/host/directory:/opt/fhem fhem/fhem

After starting your container, you may now start your favorite browser to open one of FHEM's web interface variants:

	http://xxx.xxx.xxx.xxx:8083/

You may want to have a look to the [FHEM documentation sources](https://fhem.de/#Documentation) for further information.


### Image flavors
This image provides 2 different variants:

- `latest` (default)
- `dev`

You can use one of those variants by adding them to the docker image name like this:

	docker pull fhem/fhem:latest

If you do not specify any variant, `latest` will always be the default.

`latest` will give you the current stable Docker image, including up-to-date FHEM.
`dev` will give you the latest development Docker image, including up-to-date FHEM.


### Supported platforms
This is a multi-platform image, providing support for the following platforms:


Linux:

- `x86-64/AMD64` [Link](https://hub.docker.com/r/fhem/fhem-amd64_linux/)
- `i386` [Link](https://hub.docker.com/r/fhem/fhem-i386_linux/)
- `ARM32v5, armel` [Link](https://hub.docker.com/r/fhem/fhem-arm32v5_linux/)
- `ARM32v7, armhf` [Link](https://hub.docker.com/r/fhem/fhem-arm32v7_linux/)
- `ARM64v8, arm64` [Link](https://hub.docker.com/r/fhem/fhem-arm64v8_linux/)


Windows:

- currently not supported


The main repository will allow you to install on any of these platforms.
In case you would like to specifically choose your platform, go to the platform-related repository by clicking on the respective link above.

The platform repositories will also allow you to choose more specific build tags beside the rolling tags latest or dev.


## Customize your container configuration

### Add custom packages

You may define several different types of packages to be installed automatically during initial start of the container by adding one of the following parameters to your container run command:

* Debian APT packages:

		-e APT_PKGS="package1 package2"

* Perl CPAN modules:

		-e CPAN_PKGS="App::Name1 App::Name2"

* Python PIP packages:

		-e PIP_PKGS="package1 package2"

* Node.js NPM packages:

		-e NPM_PKGS="package1 package2"


### Make any other changes during container start
In case you need to perform further changes to the container before it is ready for your FHEM instance to operate, there are a couple of entry points for your own scripts that will be run automatically if they are found at the right place.

If something needs to be done only once during the first start of a fresh container you just created, like after upgrading to a new version of the FHEM Docker Image, the `*-init.sh` scripts are the right place:

* `/pre-init.sh`, `/docker/pre-init.sh`

	This script will be run at the very beginning of the initialization of the new container, even before any custom packages will be installed.

* `/post-init.sh`, `/docker/post-init.sh`

	This script will be run at the very end of the initialization of the new container, also after your local FHEM configuration was checked and adjusted for compatibility with the container. Custom packages you defined using the environment variables mentioned above will be installed already at this point in time. This is likely the best place for you to do any final changes to the environment that need to be done only once for the lifetime of that container.

If something needs to be done every time you (re)start your container, the `*-start.sh` scripts are the right place:

* `/pre-start.sh`, `/docker/pre-start.sh`

	This script will be run every time the container starts, even before the FHEM Docker Image's own startup preparations. FHEM will not yet be running at this point in time.

* `/post-start.sh`, `/docker/post-start.sh`

	This script will be run every time the container starts and after the FHEM process was already started.


### Map USB devices to your container
1. Find out the USB device path/address from your Docker host machine first:

		lsusb -v | grep -E '\<(Bus|iProduct|bDeviceClass|bDeviceProtocol)' 2>/dev/null

2. You may then derive the device path from it and add the following parameter to your container run command:

		--device=/dev/bus/usb/001/002


### Tweak container settings using environment variables

* Change FHEM logfile format:
	To set a different logfile path and format (default is ./log/fhem-%Y-%m.log):

		-e LOGFILE=./log/fhem-%Y-%m.log

* Change FHEM local Telnet port for health check and container restart handling:
	To set a different Telnet port for local connection during health check and container restart (default is 7072):

		-e TELNETPORT=7072
	
	Note that this is of paramount importance if you are running more than one instance in host network mode on the same server, otherwise the instances will interfere each other with their restart behaviours.

* Change FHEM system user ID:
	To set a different UID for the user 'fhem' (default is 6061):

		-e FHEM_UID=6061

* Change FHEM group ID:
	To set a different GID for the group 'fhem' (default is 6061):

    	-e FHEM_GID=6061

* Change Bluetooth group ID:
	To set a different GID for the group 'bluetooth' (default is 6001):

    	-e BLUETOOTH_GID=6001

* Change GPIO group ID:
	To set a different GID for the group 'gpio' (default is 6002):

    	-e GPIO_GID=6002

* Change I2C group ID:
	To set a different GID for the group 'i2c' (default is 6003):

    	-e I2C_GID=6003

* Change shutdown timeout:
	To set a different setting for the timer during FHEM shutdown handling, you may add this environment variable:

    	-e TIMEOUT=10

* Set locale:
	For maximum compatibility, standard locale is set to US english with some refinements towards the European standards and German defaults. This may be changed according to your needs (also see [Debian Wiki](https://wiki.debian.org/Locale) for more information):

		-e LANG=en_US.UTF-8
		-e LANGUAGE=en_US:en
		-e LC_ADDRESS=de_DE.UTF-8
		-e LC_MEASUREMENT=de_DE.UTF-8
		-e LC_MESSAGES=en_DK.UTF-8
		-e LC_MONETARY=de_DE.UTF-8
		-e LC_NAME=de_DE.UTF-8
		-e LC_NUMERIC=de_DE.UTF-8
		-e LC_PAPER=de_DE.UTF-8
		-e LC_TELEPHONE=de_DE.UTF-8
		-e LC_TIME=de_DE.UTF-8

* Set timezone:
	Set a specific timezone in [POSIX format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):

    	-e TZ=Europe/Berlin

* Using configDB:
	Should you be using FHEM config type [`configDB`](https://fhem.de/commandref.html#configdb), you need to change the FHEM configuration source for correct startup by setting the following environment variable:

    	-e CONFIGTYPE=configDB
	
	Note that some essential global configuration that is affecting FHEM during startup is being enforced using FHEM\_GLOBALATTR environment variable (nofork=0 and updateInBackground=1; logfile and pidfilename according, based on environment variables LOGFILE and PIDFILE). These settings cannot be changed during runtime in FHEM and any setting that might be in your configDB configuration will be overwritten the next time you save your configuration.

	Last but not least you need to  make sure that there is an existing telnet device defined (`define telnetPort telnet 7072`) so that health check can be performed properly and DockerImageInfo can be updated. Global listening for external requests is not needed, localhost is sufficient. Note to make use of the environment variable TELNETPORT mentioned above if you wish to use a different port. Note that restrictions using the 'allowed' module is usually not necessary. Should you set any restrictions, make sure that there is no password for localhost connections (e.g. use attribue 'globalpassword=1' instead of 'password=1').

* Starting the demo:
	To start the demo environment:

    	-e CONFIGTYPE=fhem.cfg.demo

* Set Docker host IPv4 address for host.docker.internal:

    	-e DOCKER_HOST=172.17.0.1

	If this variable is not present, host IP will automatically be detected based on the subnet network gateway (also see variable `DOCKER_GW` below).
	In case the container is running in network host network mode, host.docker.internal is set to 127.0.127.2 to allow loopback network connectivity.
	host.docker.internal will also be evaluated automatically for SSH connection on port 22 by adding the servers public key to `/opt/fhem/.ssh/known_hosts` so that unattended connectivity for scripts is available.

* Set Docker gateway IPv4 address for gateway.docker.internal:

    	-e DOCKER_GW=172.17.0.1
	
	If this variable is not present, the gateway will automatically be detected.

* Manipulating software in the container using their own environment variables:
	For security reasons, only allowed environment variables are passed to the FHEM user environment. To control certain behaviours of Perl, Node.js and Python, those language interpreters come with their own environment variables. Any variable that was set for the container and with a prefix of either PERL, NODE or PYTHON is exported to the FHEM user environment so it is available there during runtime of the fhem.pl main process and subsequently all its child processes.


## Further tweaks for your FHEM configuration

### Connect to Docker host from within container
If you would like to connect to a service that is running on your Docker host itself or to a container that is running in host network mode, you may use the following DNS alias names that are automatically being added to /etc/hosts during container bootup:

* gateway.docker.internal
* host.docker.internal

That is, if you did not configure those in your local DNS, of course.

In case the container is running in host network mode, the host IP address will be set to 127.0.127.2 as an alias for 'localhost'. That means a service you would like to reach needs to listen on the loopback interface as well. If a service you would like to reach is only listening on a particular IP address or interface instead, you need to set the environment variable `DOCKER_HOST` to the respective IP address as there is no way for the FHEM Docker Image to automatically detect what you need.
When running in host network mode, the gateway will reflect your actual network segment gateway IP address.

Also, for host.docker.internal, the SSH host key will automatically be added and updated in `/opt/fhem/.ssh/known_hosts` so that FHEM modules and other scripts can automatically connect without any further configuration effort. Note that the SSH client keys that FHEM will use to authenticate itself are shown as readings in the DockerImageInfo device in FHEM. You may copy & paste those to the destination host into the respective destination user home directory with filename `~/.ssh/authorized_keys`.

If for some reason the host details are not detected correctly, you may overwrite the IP addresses using environment variables (see `DOCKER_HOST` and `DOCKER_GW` below).


## Adding Git for version control of your Home Automation Docker containers

Prerequisites on your Docker host:

1. Ensure docker-compose is installed: See [Install Docker Compose](https://docs.docker.com/compose/install/)
2. Ensure Git command is installed, e.g. run `sudo apt install git`

Follow initial setup steps:

1. Put docker-compose.yml and .gitignore into an empty sub-folder, e.g. /docker/home

		sudo mkdir -p /docker/home
		sudo curl -fsSL -o /docker/home/docker-compose.yml https://github.com/fhem/fhem-docker/raw/master/docker-compose.yml
		sudo curl -fsSL -o /docker/home/.gitignore https://github.com/fhem/fhem-docker/raw/master/.gitignore

	Note that the sub-directory "home" will be the base prefix name for all	your Docker containers (e.g. resulting in home_SERVICE_1). This will also help to run multiple instances of your Stack on the same host, e.g. to separate production environment in /docker/home from development in /docker/home-dev.

2. Being in /docker/home, run command to start your Docker stack:

		cd /docker/home; sudo docker-compose up -d

	All FHEM files including your individual configuration and changes will be stored in ./fhem/ .
	You may also put an existing FHEM installation into ./fhem/ before the initial start, it will be automatically updated for compatibility with fhem-docker.
	Note that if you are using configDB already, you need to ensure Docker compatibility before starting the container for the very first time (see `DOCKER_*` environment variables below).

3. Create a local Git repository and add all files as an initial commit:

		cd /docker/home
		sudo git init
		sudo git add -A
		sudo git commit -m "Initial commit"

	Run the following command whenever you would like to mark changes as permanent:

		cd /docker/home; sudo git add -A; sudo git commit -m "FHEM update"
	
	Note: This will also add any new files within your whole Docker Stack outside of the ./fhem/ folder.
	Please see Git documentation for details and further commands.

4. Optional - Add remote repository for external backup. It is strongly recommended to have your external repository set to _private_ before doing so:

		sudo git remote add origin git@github.com:user/repo.git
		sudo git push --force --set-upstream origin master

	Note that after updating your local repository as described above, you also	want to push those changes to the remote server:

		cd /docker/home; sudo git push

	To restore your Docker Stack from remote Git backup on a fresh Docker host installation:

		sudo mkdir -p /docker
		cd /docker; sudo git clone git@github.com:user/repo.git
		cd /docker/home; sudo docker-compose up -d


___
[Production ![Build Status](https://travis-ci.com/fhem/fhem-docker.svg?branch=master)](https://travis-ci.com/fhem/fhem-docker)

[Development ![Build Status](https://travis-ci.com/fhem/fhem-docker.svg?branch=dev)](https://travis-ci.com/fhem/fhem-docker)
