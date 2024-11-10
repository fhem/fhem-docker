[![Main branch - Build and Test](https://github.com/fhem/fhem-docker/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/fhem/fhem-docker/actions/workflows/build.yml)
[![Development branch - Build and Test](https://github.com/fhem/fhem-docker/actions/workflows/build.yml/badge.svg?branch=dev)](https://github.com/fhem/fhem-docker/actions/workflows/build.yml)
___
# Docker image for FHEM

A Docker image for [FHEM](https://fhem.de/) house automation system, based on Debian.




## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/fhem) 
Recommended pulling from [Github Container Registry](https://github.com/orgs/fhem/packages) to allow automatic image for your system.

### From Docker Hub

    docker pull fhem/fhem:latest

### From Github container registry

#### Image with serval services installed

##### Version 5 (beta)

- debian bookworm
- Perl 5.36.3 (optional threaded)
- NodeJS 18.19 LTS
- Python 3.11.2
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64
- NOTE: alexa-fhem, alexa-cookie, gassistant-fhem, homebridge, homebridge-fhem, tradfri-fhem are not installed per default!

        docker pull ghcr.io/fhem/fhem-docker:5-bullseye
        docker pull ghcr.io/fhem/fhem-docker:5-threaded-bullseye

##### Version 4 - EOL Jan 2025

- debian bullseye 
- Perl 5.36.3 (optional threaded)
- NodeJS 18 LTS
- Python 3.9.2
- Python 2.7.18
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64
- NOTE: alexa-fhem, alexa-cookie, gassistant-fhem, homebridge, homebridge-fhem, tradfri-fhem are not installed per default!

        docker pull ghcr.io/fhem/fhem-docker:4-bookworm
        docker pull ghcr.io/fhem/fhem-docker:4-threaded-bookworm

If you are using 3rd Party modules which are not available on the FHEM svn repository, you may need this image, because it has more perl modules preinstalled.

To let this image work correctly, you need as least a FHEM revision 25680 or newer.

##### Version 3 - EOL Jan 2024

- debian buster
- Perl 5.28.1
- NodeJS 16 LTS
- Python 3
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64
- NOTE: alexa-fhem, alexa-cookie, gassistant-fhem, homebridge, homebridge-fhem, tradfri-fhem  are not installed per default!

        docker pull ghcr.io/fhem/fhem-docker:3-buster

 are available.



#### Image with perl core services installed


##### Version 5 (beta)

- debian bookworm
- Perl 5.36.3 (optional threaded)
- Python 3.11.2
- Python 2.7.18
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64, linux/i386, 

        docker pull ghcr.io/fhem/fhem-minimal-docker:5-bookworm
        docker pull ghcr.io/fhem/fhem-minimal-docker:5-threaded-bookworm

If you are using only modules which are provided via FHEM svn repository, you mostly can use this smaller image.

##### Version 4 - EOL Jan 2025

- debian bullseye
- Perl 5.36.3 (optional threaded)
- Python 3.9.2
- Python 2.7.18
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64, linux/i386, 

        docker pull ghcr.io/fhem/fhem-minimal-docker:4-bullseye
        docker pull ghcr.io/fhem/fhem-minimal-docker:4-threaded-bullseye

If you are using only modules which are provided via FHEM svn repository, you mostly can use this smaller image.

##### Version 3 - EOL Jan 2024

- debian buster
- Perl 5.28.1
- Supported Plattforms: linux/amd64, linux/arm/v7, linux/arm64, linux/i386, 

        docker pull ghcr.io/fhem/fhem-minimal-docker:3-buster

 are available.


#### To start your container right away:

        docker run -d --name fhem -p 8083:8083 ghcr.io/fhem/fhem-docker:5-bookworm

#### Storage
Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:


        docker run -d --name fhem -p 8083:8083 -v /some/host/directory:/opt/fhem ghcr.io/fhem/fhem-docker:5-bookworm

You will find more general information about using volumes from the Docker documentation for [Use volumes](https://docs.docker.com/storage/volumes/) and [Bind mounts](https://docs.docker.com/storage/bind-mounts/).

It is also possible to mount CIFS mounts directly.

### Access FHEM

After starting your container, you may now start your favorite browser to open one of FHEM's web interface variants like `http://xxx.xxx.xxx.xxx:8083/`.

You may want to have a look to the [FHEM documentation sources](https://fhem.de/#Documentation) for further information about how to use and configure FHEM.


### Update strategy

Note that any existing FHEM installation you are mounting into the container will _not_ be updated automatically, it is just the container and its system environment that can be updated by pulling a new FHEM Docker image. This is because the existing update philosophy is incompatible with the new and state-of-the-art approach of containerized application updates. That being said, consider the FHEM Docker image as a runtime environment for FHEM which is also capable to install FHEM for any new setup from scratch.


## Customize your container configuration

### Performance implications

The FHEM log file is mirrored to the Docker console output in order to give input for any Docker related tools. However, if the log file becomes too big, this will lead to some performance implications.
For that reason, the default value of the global attribute `logfile` is different from the FHEM default configuration and set to a daily file (`attr global logfile ./log/fhem-%Y-%m-%d.log`).

It is highly recommended to keep this setting. Please note that FileLog are only patched if fhem is fresh installed. 
Devices might still need to be checked and adjusted manually if you would like to properly watch the log file from within FHEM.

### Add custom packages 

#### Since version 4

To extand the image wirh a custom package for example, you have to use standard docker tools.

If you are defining a docker-compose.yml file describing your configuration, then you can add a build definition instead of starting the image from the registry:

With this, you will create a new image, and install any tool which you additional need:

```
    build:
      context: .
      dockerfile_inline: |
        FROM ghcr.io/fhem/fhem-docker:5-bookworm
        RUN <<EOF
          LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update 
          LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends <DEBIAN PACKAGENAME>
          LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean 
        EOF

        RUN <<EOF
          pip install --no-cache-dir <PIP PACKAGENAME>
        EOF
```

See more examples in our docker-compose.yml file.

Important: If you need additional Perl CPAN Modules, you must install them directly from CPAN and not via apt!

#### till version 3 (deprecated)

Don't do this unless you really know what this does!
You may define several different types of packages to be installed automatically during initial start of the container by adding one of the following parameters to your container run command:

* Debian APT packages:

    ```shell
    -e APT_PKGS="package1 package2"
    ```

* Perl CPAN modules:

    ```shell
    -e CPAN_PKGS="App::Name1 App::Name2"
    ```

* Python PIP packages:

    ```shell
    -e PIP_PKGS="package1 package2"
    ```

* Node.js NPM packages:

    ```shell
    -e NPM_PKGS="package1 package2"
    ```

### Directory and file permissions

For security and functional reasons, directory and file permissions for FHEM will be set during every container startup.
That means that directories and files can only be opened by members of the [`$FHEM_GID`](#tweak-container-settings-using-environment-variables) user group or the [`$FHEM_UID`](#tweak-container-settings-using-environment-variables) user itself. Also, the execution bit for files is only kept for a limited set of file names and directories, which are:

* files named `*.pl`, `*.py`, `*.sh`
* every file that is stored in any directory named `bin` or `sbin`
* every file that is stored in any directory containing the string `script` in its name

Should you require any different permissions, you may read the next section to learn more about how to make any changes using custom pre start script `/pre-start.sh` or `/docker/pre-start.sh`.

### Make any other changes during container start

In case you need to perform further changes to the container before it is ready for your FHEM instance to operate, there are a couple of entry points for your own scripts that will be run automatically if they are found at the right place. In order to achieve this, you need to mount the script file itself or a complete folder that contains that script to the respective destination inside your container. See Docker documentation about [Use volumes](https://docs.docker.com/storage/volumes/) and [Bind mounts](https://docs.docker.com/storage/bind-mounts/) to learn how to achieve this in general.

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

### Role of the telnet device in FHEM

#### since version 4 

There is no internal use of the telnet device anymore

#### till version 3 (deprecated)

The Docker container will need to communicate with FHEM to shutdown nicely instead of just killing the process. For this to work properly, a `telnet` device is of paramount importance. Unless you are using configDB, the container will try to automatically detect and adjust your telnet configuration for it to work. If for any reason that fails or you are using configDB, it is your own obligation to configure such `telnet` device (`define telnetPort telnet 7072`). It may listen on the standard port 7072 or can be any other port (see environment variable `TELNETPORT` to re-configure it).

It is enough for the `telnet` device to only listen on the loopback device (aka localhost) but it _cannot_ have any password protection enabled for loopback connections. If you require your `telnet` instance to listen for external connections, it is usually best-practice to set a password for it. In that case, make sure that any `allowed` device you might have configured for this purpose only requires a password for non-loopback connections (e.g. using attribute `globalpassword` instead of `password` - also see [allowed commandref](https://fhem.de/commandref.html#allowed)). The same applies when using the deprecated attribute `password` for the `telnet` device itself (see [telnet commandref](https://fhem.de/commandref.html#telnet)).

### Docker health check control

The image comes with a built-in script to check availability, which communicates with the DockerImageInfo Definition.

If for whatever reason you want to disable checking a specific FHEMWEB instance, you may set the user attribute `DockerHealthCheck` to 0 on that particular FHEMWEB device.

Note that the health check itself cannot be entirely disabled as it will ensure to notify you in case of failures, hindering proper shutdown of FHEM when triggered by Docker or OS shutdown procedure.

### Map USB devices to your container

1. Find out the USB device path/address from your Docker host machine first:

    ```console
    lsusb -v | grep -E '\<(Bus|iProduct|bDeviceClass|bDeviceProtocol)' 2>/dev/null
    ```

2. You may then derive the device path from it and add the following parameter to your container run command:

    ```shell
    --device=/dev/bus/usb/001/002
    ```

### Tweak container settings using environment variables

* Change FHEM logfile format:
    To set a different logfile path and format (default is ./log/fhem-%Y-%m-%d.log):

    ```shell
    -e LOGFILE=./log/fhem-%Y-%m-%d.log
    ```

* Change FHEM local Telnet port for health check and container restart handling: (deprecated since v4)
    To set a different Telnet port for local connection during health check and container restart (default is 7072):

    ```shell
    -e TELNETPORT=7072
    ```

    Note that this is of paramount importance if you are running more than one instance in host network mode on the same server, otherwise the instances will interfere each other with their restart behaviours.

* Change FHEM system user ID:
    To set a different UID for the user `fhem` (default is 6061):

    ```shell
    -e FHEM_UID=6061
    ```

* Change FHEM group ID:
    To set a different GID for the group `fhem` (default is 6061):

    ```shell
    -e FHEM_GID=6061
    ```

* Change FHEM directory permissions:
    To set different directory permissions for `$FHEM_DIR` (default is 0750):

    ```shell
    -e FHEM_PERM_DIR=0750
    ```

* Change FHEM file permissions:
    To set different file permissions for `$FHEM_DIR` (default is 0640):

    ```shell
    -e FHEM_PERM_FILE=0640
    ```

* Change umask:
    To set a different umask for `FHEM_UID` (default is 0037):

    ```shell
        -e UMASK=0037

* Change Bluetooth group ID:
    To set a different GID for the group `bluetooth` (default is 6001):

    ```shell
    -e BLUETOOTH_GID=6001
    ```

* Change GPIO group ID:
    To set a different GID for the group `gpio` (default is 6002):

    ```shell
    -e GPIO_GID=6002
    ```

* Change I2C group ID:
    To set a different GID for the group `i2c` (default is 6003):

    ```shell
    -e I2C_GID=6003
    ```

* Change shutdown timeout:
    To set a different setting for the timer during FHEM shutdown handling, you may add this environment variable:

    ```shell
    -e TIMEOUT=10
    ```

* Set locale:
    For maximum compatibility, standard locale is set to US english with some refinements towards the European standards and German defaults. This may be changed according to your needs (also see [Debian Wiki](https://wiki.debian.org/Locale) for more information):

    ```shell
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
    ```

* Set timezone:
    Set a specific timezone in [POSIX format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):

    ```shell
    -e TZ=Europe/Berlin
    ```

* Using configDB:
    Should you be using FHEM config type [`configDB`](https://fhem.de/commandref.html#configdb), you need to change the FHEM configuration source for correct startup by setting the following environment variable:

    ```shell
    -e CONFIGTYPE=configDB
    ```

    Note that some essential global configuration that is affecting FHEM during startup is being enforced using FHEM\_GLOBALATTR environment variable (nofork=0 and updateInBackground=1; logfile and pidfilename accordingly, based on environment variables LOGFILE and PIDFILE). These settings cannot be changed during runtime in FHEM and any setting that might be in your configDB configuration will be overwritten the next time you save your configuration. It might happen that FHEM will show you some warnings as part of the "message of the day" (motd attribute), stating that an attribute is read-only. That's okay, just clear that message and save your FHEM configuration at least once so the configuration is back in sync.

    Only for v3 and lower: Last but not least you need to make sure the telnet device configuration [described above](#role-of-the-telnet-device-in-fhem) is correct. 

* Starting the demo:
    To start the demo environment:

    ```shell
    -e CONFIGTYPE=fhem.cfg.demo
    ```

* Set Docker host IPv4 address for host.docker.internal:

    ```shell
    -e DOCKER_HOST=172.17.0.1
    ```

    If this variable is not present, host IP will automatically be detected based on the subnet network gateway (also see variable `DOCKER_GW` below).
    In case the container is running in network host network mode, host.docker.internal is set to 127.0.127.2 to allow loopback network connectivity.
    host.docker.internal will also be evaluated automatically for SSH connection on port 22 by adding the servers public key to `/opt/fhem/.ssh/known_hosts` so that unattended connectivity for scripts is available.

* Set Docker gateway IPv4 address for gateway.docker.internal:

    ```shell
    -e DOCKER_GW=172.17.0.1
    ```

    If this variable is not present, the gateway will automatically be detected.


* Set FHEM startup timeout:
    Set a Timeout, how long the docker container waits until the FHEM process will finished starting.
    If the timeout is over, and FHEM is not started, the container is stopped.
    You will see an error like this in the container log, if starting wasn't finished early enough:
    `ERROR: Fatal: No message from FHEM since 60 seconds that server has started.`
        
    If you have a slow system and a module which blocks FHEM to be ready adjust this to a higher value.

    ```shell
    -e TIMEOUT_STARTING=60
    ```

    If this variable is not present, the timeout will be 60 seconds. 

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

If for some reason the host details are not detected correctly, you may overwrite the IP addresses using environment variables (see `DOCKER_HOST` and `DOCKER_GW` above).

## Adding Git for version control of your Home Automation Docker containers

Prerequisites on your Docker host:

1. Ensure docker-compose is installed: See [Install Docker Compose](https://docs.docker.com/compose/install/)
2. Ensure Git command is installed, e.g. run `sudo apt install git`

Follow initial setup steps:

1. Put docker-compose.yml and .gitignore into an empty sub-folder, e.g. /docker/home

    ```console
    sudo mkdir -p /docker/home
    sudo curl -fsSL -o /docker/home/docker-compose.yml https://github.com/fhem/fhem-docker/raw/master/docker-compose.yml
    sudo curl -fsSL -o /docker/home/.gitignore https://github.com/fhem/fhem-docker/raw/master/.gitignore
    ```

    Note that the sub-directory "home" will be the base prefix name for all    your Docker containers (e.g. resulting in home_SERVICE_1). This will also help to run multiple instances of your Stack on the same host, e.g. to separate production environment in /docker/home from development in /docker/home-dev.

2. Being in /docker/home, run command to start your Docker stack:

    ```console
    cd /docker/home; sudo docker-compose up -d
    ```

    All FHEM files including your individual configuration and changes will be stored in ./fhem/ .
    You may also put an existing FHEM installation into ./fhem/ before the initial start, it will be automatically updated for compatibility with fhem-docker.
    Note that if you are using configDB already, you need to ensure Docker compatibility before starting the container for the very first time (see `DOCKER_*` environment variables above).

3. Create a local Git repository and add all files as an initial commit:

    ```console
    cd /docker/home
    sudo git init
    sudo git add -A
    sudo git commit -m "Initial commit"
    ```

    Run the following command whenever you would like to mark changes as permanent:

    ```console
    cd /docker/home; sudo git add -A; sudo git commit -m "FHEM update"
    ```

    Note: This will also add any new files within your whole Docker Stack outside of the ./fhem/ folder.
    Please see Git documentation for details and further commands.

4. Optional - Add remote repository for external backup. It is strongly recommended to have your external repository set to _private_ before doing so:

    ```console
    sudo git remote add origin git@github.com:user/repo.git
    sudo git push --force --set-upstream origin master
    ```

    Note that after updating your local repository as described above, you also    want to push those changes to the remote server:

    ```console
    cd /docker/home; sudo git push
    ```

    To restore your Docker Stack from remote Git backup on a fresh Docker host installation:

    ```console
    sudo mkdir -p /docker
    cd /docker; sudo git clone git@github.com:user/repo.git
    cd /docker/home; sudo docker-compose up -d
    ```


## Testing the Image itself in a container

Basic testing of the image is done in the pipeline. The pipeline will start a container and verify that the health check reports the container is alive.

The bash scripts inside the container, are tested via bats:

To run the test, build the image with the specific target:
 
    docker build --rm --load -f "Dockerfile-bullseye" -t fhemdocker:test --target with-fhem-bats "."

Then this image, can be used to start a new container and running bats inside the container.
    docker run -it --rm -v "${PWD}/src/tests/bats:/code"  fhemdocker:test .

## A needed perl module is missing

If you are running a 3rd party module, advice the maintainer to this description: 
    
    During docker build, repositorys are searched by topics and content in the readme.md file.
    If the build finds your repository, it will check automatically, what perl modules are needed.
    Modules wich are found will be installed via cpan in the resulting docker image.
    This allows users of the docker image to use your module. 

    Add the topic 'fhem' and 'perl' and provide an instruction in your readme.md with 
    instruction how to use update add / update all to install your module.


