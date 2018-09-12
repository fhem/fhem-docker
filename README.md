# Basic Docker image for FHEM
A basic Docker image for [FHEM](https://fhem.de/) house automation system, based on Debian Stretch.


## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/).
We recommend pulling from the [main repository](https://hub.docker.com/r/fhem/fhem/) to allow automatic download of the correct image for your system platform:

	docker pull fhem/fhem

To start your container right away:

    docker run -d --name fhem -p 7072:7072 -p 8083:8083 -p 8084:8084 -p 8085:8085 fhem/fhem

Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name fhem -p 7072:7072 -p 8083:8083 -p 8084:8084 -p 8085:8085 fhem/fhem -v /some/host/directory:/opt/fhem

After starting your container, you may now start your favorite browser to open one of FHEM's web interface variants:

	http://xxx.xxx.xxx.xxx:8083/
	http://xxx.xxx.xxx.xxx:8084/
	http://xxx.xxx.xxx.xxx:8085/

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


#### Map USB devices to your container
1. Find out the USB device path/address from your Docker host machine first:

		lsusb -v | grep -E '\<(Bus|iProduct|bDeviceClass|bDeviceProtocol)' 2>/dev/null

2. You may then derive the device path from it and add the following parameter to your container run command:

		--device=/dev/bus/usb/001/002


#### Tweak container settings using environment variables

* Change FHEM logfile format:
	To set a different logfile path and format (default is fhem-%Y-%m.log):

		-e LOGFILE=fhem-%Y-%m.log

* Change FHEM system user ID:
	To set a different UID for the user 'fhem' (default is 6061):

		-e FHEM_UID=6061

* Change FHEM group ID:
	To set a different GID for the group 'fhem' (default is 6061):

    	-e FHEM_GID=6061

* Change shutdown timeout:
	To set a different setting for the timer during FHEM shutdown handling, you may add this environment variable:

    	-e TIMEOUT=10

* Set timezone:
	Set a specific timezone in [POSIX format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):

    	-e TZ=Europe/Berlin

* Using configDB:
	Should you be using FHEM config type [`configDB`](https://fhem.de/commandref.html#configdb), you need to change the FHEM configuration source for correct startup by setting the following environment variable:

    	-e CONFIGTYPE=configDB

* Starting the demo:
	To start the demo environment:

    	-e CONFIGTYPE=fhem.cfg.demo


## Adding Git for version control of your Home Automation Docker containers

Prerequisites on your Docker host:

1. Ensure docker-compose is installed: See [Install Docker Compose](https://docs.docker.com/compose/install/)
2. Ensure Git command is installed, e.g. run `sudo apt install git`

Follow initial setup steps:

1. Put docker-compose.yml and .gitignore into an empty sub-folder, e.g. /docker/home

		sudo mkdir -p /docker/home
		sudo curl -o /docker/home/docker-compose.yml https://raw.githubusercontent.com/docker-home-automation-stack/fhem-docker/master/docker-compose.yml
		sudo curl -o /docker/home/.gitignore https://raw.githubusercontent.com/docker-home-automation-stack/fhem-docker/master/.gitignore

	Note that the sub-directory "home" will be the base prefix name for all	your Docker containers (e.g. resulting in home_SERVICE_1). This will also help to run multiple instances of your Stack on the same host, e.g. to separate production environment in /docker/home from development in /docker/home-dev.

2. Being in /docker/home, run command to start your Docker stack:

		cd /docker/home; sudo docker-compose up -d

	All FHEM files including your individual configuration and changes will be stored in ./fhem/ .
	You may also put an existing FHEM installation into ./fhem/ before the initial start, it will be automatically updated for compatibility with fhem-docker.

3. Create a local Git repository and add all files as an initial commit:

		cd /docker/home
		sudo git init
		sudo git add -A
		sudo git commit -m "Initial commit"

	Run the following command whenever you would like to mark changes as permanent:

		cd /docker/home; sudo git add -A; sudo git commit -m "FHEM update"
	
	Note: This will also add any new files within your whole Docker Stack outside of the ./fhem/ folder.
	Please see Git documentation for details and further commands.

4. Optional - Add remote repository for external backup. Using BitBucket is recommended because it supports private repositories:

		sudo git remote add origin git@bitbucket.org:user/repo.git
		sudo git push --force --set-upstream origin master

	Note that after updating your local repository as described above, you also	want to push those changes to the remote server:

		cd /docker/home; sudo git push

	To restore your Docker Stack from remote Git backup on a fresh Docker host installation:

		sudo mkdir -p /docker
		cd /docker; sudo git clone git@bitbucket.org:user/repo.git
		cd /docker/home; sudo docker-compose up -d


___
[Production ![Build Status](https://travis-ci.com/docker-home-automation-stack/fhem-docker.svg?branch=master)](https://travis-ci.com/docker-home-automation-stack/fhem-docker)

[Development ![Build Status](https://travis-ci.com/docker-home-automation-stack/fhem-docker.svg?branch=dev)](https://travis-ci.com/docker-home-automation-stack/fhem-docker)
