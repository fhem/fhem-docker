[![Main branch - Build and Test](https://github.com/fhem/fhem-docker/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/fhem/fhem-docker/actions/workflows/build.yml)
[![Development branch - Build and Test](https://github.com/fhem/fhem-docker/actions/workflows/build.yml/badge.svg?branch=dev)](https://github.com/fhem/fhem-docker/actions/workflows/build.yml)
___
# Docker image for FHEM

A Docker image for [FHEM](https://fhem.de/) house automation system, based on Debian.




## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/fhem) 
Recommended pulling from [Github Container Registry](https://github.com/orgs/fhem/packages) to allow automatic image for your system.
Use fixed tags instead of `latest`. Update image tags explicitly in Compose or in `FROM` lines so Renovate can track and review the change.
For normal FHEM-SVN-based setups, the minimal image is the recommended default and already contains the required Perl/FHEM runtime environment, but not Python or NodeJS. The regular `fhem-docker` image bundles several runtime environments in one container and should be treated as a compatibility option rather than the preferred pattern for new setups.

### From Github container registry

#### Minimal image (recommended)

For normal FHEM-SVN setups and slim, controlled deployments, use the minimal image:

    docker pull ghcr.io/fhem/fhem-minimal-docker:5-bookworm
    docker pull ghcr.io/fhem/fhem-minimal-docker:5-threaded-bookworm

This is the recommended default for new setups. It contains the required FHEM Perl runtime environment; install only the additional dependencies your own setup actually needs. It is based on Debian bookworm and Perl 5.38.5. Python and NodeJS are not part of the minimal image; add them explicitly when your setup needs them. Supported platforms are `linux/amd64`, `linux/arm/v7`, `linux/arm64` and `linux/i386`.

#### Standard image

Use the regular image only when you intentionally need the compatibility image with multiple bundled runtime environments:

    docker pull ghcr.io/fhem/fhem-docker:5-bookworm
    docker pull ghcr.io/fhem/fhem-docker:5-threaded-bookworm

This image bundles additional runtime environments in the FHEM container. That is useful for compatibility with existing deployments, but it is an anti-pattern for new setups when the same functionality can run as sidecars or explicit image extensions. Some bundled runtime versions can also age independently of the FHEM runtime.

### From Docker Hub

You can pull the same standard image from Docker Hub:

    docker pull fhem/fhem:5-bookworm

Legacy v3/v4 tags and details are documented in [docs/legacy-images.md](docs/legacy-images.md).

#### To start your container right away:

        docker run -d --name fhem -p 8083:8083 ghcr.io/fhem/fhem-minimal-docker:5-bookworm

#### Storage
Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:


        docker run -d --name fhem -p 8083:8083 -v /some/host/directory:/opt/fhem ghcr.io/fhem/fhem-minimal-docker:5-bookworm

You will find more general information about using volumes from the Docker documentation for [Use volumes](https://docs.docker.com/storage/volumes/) and [Bind mounts](https://docs.docker.com/storage/bind-mounts/).

It is also possible to mount CIFS mounts directly.

### Access FHEM

After starting your container, you may now start your favorite browser to open one of FHEM's web interface variants like `http://xxx.xxx.xxx.xxx:8083/`.

You may want to have a look to the [FHEM documentation sources](https://fhem.de/#Documentation) for further information about how to use and configure FHEM.


### Update strategy

Note that any existing FHEM installation you are mounting into the container will _not_ be updated automatically, it is just the container and its system environment that can be updated by pulling a new FHEM Docker image. This is because the existing update philosophy is incompatible with the new and state-of-the-art approach of containerized application updates. That being said, consider the FHEM Docker image as a runtime environment for FHEM which is also capable to install FHEM for any new setup from scratch.

### Developer information

Build, CI and CPAN inventory details for contributors are documented in [docs/developer-notes.md](docs/developer-notes.md).

### Tag strategy

Use fixed image tags such as `5-bookworm` or `5-threaded-bookworm` in Compose files and `FROM` statements. Avoid `latest`, because it hides version drift and makes updates harder to review. Renovate-friendly updates should happen by changing the tag in the Compose file or the Dockerfile, not by relying on mutable tags.

## Customize your container configuration

### Performance implications

The FHEM log file is mirrored to the Docker console output in order to give input for any Docker related tools. However, if the log file becomes too big, this will lead to some performance implications.
For that reason, the default value of the global attribute `logfile` is different from the FHEM default configuration and set to a daily file (`attr global logfile ./log/fhem-%Y-%m-%d.log`).

It is highly recommended to keep this setting. Please note that FileLog are only patched if fhem is fresh installed. 
Devices might still need to be checked and adjusted manually if you would like to properly watch the log file from within FHEM.

### Extending the image

Build your own image when you need extra packages. Keep the base image pinned to a fixed tag. The minimal image does not include Python or NodeJS, so install those runtimes explicitly before using `pip` or `npm`.

Debian packages:

```dockerfile
FROM ghcr.io/fhem/fhem-minimal-docker:5-bookworm
RUN apt-get update \
    && apt-get install -qqy --no-install-recommends <DEBIAN PACKAGENAME> \
    && apt-get autoremove -qqy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Perl CPAN modules:

```dockerfile
FROM ghcr.io/fhem/fhem-minimal-docker:5-bookworm
# renovate: datasource=github-releases depName=cpm packageName=skaji/cpm
ARG CPAN_CPM_VERSION=v1.1.4
RUN cpanm --notest "https://cpan.metacpan.org/authors/id/S/SK/SKAJI/App-cpm-${CPAN_CPM_VERSION}.tar.gz" \
    && cpm install --show-build-log-on-failure --configure-timeout=360 --workers=$(nproc) --local-lib-contained /usr/src/app/3rdparty/ <CPAN PACKAGE>
```

Python packages:

```dockerfile
FROM ghcr.io/fhem/fhem-minimal-docker:5-bookworm
RUN apt-get update \
    && apt-get install -qqy --no-install-recommends python3 python3-pip \
    && pip install --no-cache-dir <PIP PACKAGE> \
    && apt-get autoremove -qqy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Node.js packages:

```dockerfile
FROM ghcr.io/fhem/fhem-minimal-docker:5-bookworm
RUN apt-get update \
    && apt-get install -qqy --no-install-recommends nodejs \
    && npm install -g --unsafe-perm --production <NPM PACKAGE> \
    && npm cache clean --force \
    && apt-get autoremove -qqy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Use `ghcr.io/fhem/fhem-docker:5-bookworm` as the base image only when you intentionally need the compatibility image with multiple bundled runtime environments.

Important: If you need additional Perl CPAN modules, install them directly from CPAN and not via apt.

For Alexa integrations, prefer sidecar containers instead of adding the helpers to the FHEM image:

* `alexa-fhem` Docker: https://github.com/fhem/alexa-fhem-docker, image `ghcr.io/fhem/alexa-fhem:5.1.6`
* `alexa-cookie-service`: https://github.com/fhem/alexa-cookie-service, image `ghcr.io/fhem/alexa-cookie-service:0.3.1`

Keep those services separate from the FHEM image and add the local configuration, credentials and FHEM definitions that your setup needs.

Legacy package-installation variables from image versions 3 and older are documented in [docs/legacy-images.md](docs/legacy-images.md). Prefer extending the image as shown above.

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

DockerImageInfo also reports the detected runtime in `container.runtime` and combines runtime and image metadata in the `model` reading, for example `runtime=kubernetes; image.version=5-bookworm; image.revision=...`. Runtime detection supports Kubernetes, Docker, container runtimes such as containerd, CRI-O and Podman, and `host` as fallback.

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

The container entrypoint supports the following environment variables. Values that are shown as paths may be absolute paths or paths relative to `/opt/fhem` unless stated otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone. |
| `CONFIGTYPE` | `fhem.cfg` | FHEM configuration source, for example `fhem.cfg`, `fhem.cfg.demo`, or `configDB`. |
| `LOGFILE` | `./log/fhem-%Y-%m-%d.log` | FHEM logfile path and date format. |
| `PIDFILE` | `./log/fhem.pid` | FHEM PID file path. |
| `TELNETPORT` | `7072` | Local FHEM Telnet port. Deprecated since v4. |
| `RESTART` | `1` | Restart FHEM after unexpected termination. Set to `0` to disable automatic restart. |
| `UMASK` | `0037` | Umask used when FHEM is started. |
| `FHEM_UID` | `6061` | UID for the `fhem` user. |
| `FHEM_GID` | `6061` | GID for the `fhem` group. |
| `FHEM_PERM_DIR` | `0750` | Permissions enforced for directories below `/opt/fhem`. |
| `FHEM_PERM_FILE` | `0640` | Permissions enforced for files below `/opt/fhem`. |
| `BLUETOOTH_GID` | `6001` | GID for the `bluetooth` group. |
| `GPIO_GID` | `6002` | GID for the `gpio` group. |
| `I2C_GID` | `6003` | GID for the `i2c` group. |
| `TIMEOUT_STOPPING` | `30` | Seconds to wait for FHEM to stop gracefully before sending `SIGKILL`. |
| `TIMEOUT_STARTING` | `60` | Seconds to wait for FHEM to report that the server has started. |
| `TIMEOUT_REAPPEAR` | `15` | Seconds to wait for a terminated FHEM process to reappear before handling it as failed. |
| `APT_PKGS` | empty | Deprecated: Debian packages to install during initial container setup. Prefer extending the image instead. |
| `CPAN_PKGS` | empty | Deprecated: CPAN modules to install during initial container setup. Prefer extending the image instead. |
| `PIP_PKGS` | empty | Deprecated: Python packages to install during initial container setup. Prefer extending the image instead. |
| `NPM_PKGS` | empty | Deprecated: Node.js packages to install during initial container setup. Prefer extending the image instead. |
| `FHEM_GLOBALATTR` | generated from `LOGFILE` and `PIDFILE` | Global attributes passed to FHEM at startup. Overrides the generated value when set. |
| `PERL_JSON_BACKEND` | `Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP` | Perl JSON backend preference order. |
| `LANG` | `en_US.UTF-8` | Locale setting. |
| `LANGUAGE` | `en_US:en` | Locale language preference. |
| `LC_ADDRESS` | `de_DE.UTF-8` | Locale setting. |
| `LC_MEASUREMENT` | `de_DE.UTF-8` | Locale setting. |
| `LC_MESSAGES` | `en_DK.UTF-8` | Locale setting. |
| `LC_MONETARY` | `de_DE.UTF-8` | Locale setting. |
| `LC_NAME` | `de_DE.UTF-8` | Locale setting. |
| `LC_NUMERIC` | `de_DE.UTF-8` | Locale setting. |
| `LC_PAPER` | `de_DE.UTF-8` | Locale setting. |
| `LC_TELEPHONE` | `de_DE.UTF-8` | Locale setting. |
| `LC_TIME` | `en_DK.UTF-8` | Locale setting. |
| `LC_CTYPE` | unset | Passed through to FHEM when set. |
| `LC_COLLATE` | unset | Passed through to FHEM when set. |
| `LC_ALL` | unset | Passed through to FHEM when set. |
| `DOCKER_HOST` | auto-detected | IPv4 address for `host.docker.internal`. |
| `DOCKER_GW` | auto-detected | IPv4 address for `gateway.docker.internal`. |
| `DOCKER_ENV_FILE` | `/.dockerenv` | Override path used for Docker runtime detection. |
| `KUBERNETES_TOKEN_FILE` | `/var/run/secrets/kubernetes.io/serviceaccount/token` | Override path used for Kubernetes runtime detection. |
| `KUBERNETES_SERVICE_HOST` | unset | Kubernetes runtime detection hint. Usually provided by Kubernetes. |
| `CONTAINER_CGROUP_FILE` | `/proc/1/cgroup` | Override path used for container runtime detection. |
| `CONTAINER_MOUNTINFO_FILE` | `/proc/self/mountinfo` | Override path used for container runtime detection. |

In addition, environment variables whose names start with `PERL`, `NODE`, or `PYTHON` are exported to the FHEM user environment so they are available to `fhem.pl` and its child processes.

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
    ```

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
    -e TIMEOUT_STOPPING=30
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
    -e LC_TIME=en_DK.UTF-8
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

## Using Docker Compose

Prerequisites on your Docker host:

1. Ensure the Docker Compose plugin is installed: See [Install Docker Compose](https://docs.docker.com/compose/install/)
2. Ensure Git command is installed, e.g. run `sudo apt install git`

Follow initial setup steps:

1. Put `docker-compose.yml` and `.gitignore` into an empty sub-folder, e.g. `/docker/home`

    ```console
    sudo mkdir -p /docker/home
    sudo curl -fsSL -o /docker/home/docker-compose.yml https://github.com/fhem/fhem-docker/raw/master/docker-compose.yml
    sudo curl -fsSL -o /docker/home/.gitignore https://github.com/fhem/fhem-docker/raw/master/.gitignore
    ```

    `docker-compose.yml` is intended to be used directly, not as a sample catalog. The sub-directory name becomes the project prefix for your containers, which helps when you run multiple stacks on the same host.
    The Compose file already ships with a few important FHEM environment variables and defaults; override them locally through `.env` when needed.

2. Start the stack with `docker compose`:

    ```console
    cd /docker/home
    sudo docker compose up -d
    ```

    All FHEM files including your individual configuration and changes will be stored in ./fhem/ .
    You may also put an existing FHEM installation into ./fhem/ before the initial start, it will be automatically updated for compatibility with fhem-docker.
    Note that if you are using configDB already, you need to ensure Docker compatibility before starting the container for the very first time (see `DOCKER_*` environment variables above).

    Optional services in the provided Compose file are enabled through profiles:

    * `db` starts a PostgreSQL container that can be used for configDB or other database-backed FHEM modules.
    * `mail` starts a Postfix relay based on `boky/postfix`.

    ```console
    sudo docker compose --profile db up -d
    sudo docker compose --profile mail up -d
    ```

    Alexa helpers, USB devices, host networking and privileged mode need local configuration, secrets, device paths or start commands. Keep those as local Compose changes or sidecars instead of enabling them in the default stack.

    For local additions, create a `compose.override.yml` next to `docker-compose.yml`. Docker Compose reads that file automatically:

    ```yaml
    services:
      fhem:
        devices:
          - "/dev/ttyUSB0:/dev/ttyUSB0"
        # Use only when a device really needs broad host access.
        # privileged: true

      alexa-fhem:
        image: ghcr.io/fhem/alexa-fhem:5.1.6
        restart: unless-stopped
        volumes:
          - ./alexa-fhem/:/alexa-fhem/
        environment:
          TZ: ${TZ:-Europe/Berlin}

      alexa-cookie-service:
        image: ghcr.io/fhem/alexa-cookie-service:0.3.1
        restart: unless-stopped
        volumes:
          - ./alexa-cookie-service/:/data/
        environment:
          AUTH_TOKEN: ${ALEXA_COOKIE_SERVICE_TOKEN:-change-me}
          PROXY_PUBLIC_HOST: ${ALEXA_COOKIE_SERVICE_HOST:-127.0.0.1}
          TZ: ${TZ:-Europe/Berlin}
        ports:
          - "58090:58090"
    ```

    Host networking is a separate local variant because it conflicts with the default `ports` mapping. Use an explicit override file when you need it:

    ```yaml
    services:
      fhem:
        network_mode: host
        ports: !reset []
    ```

    Start it with:

    ```console
    sudo docker compose -f docker-compose.yml -f compose.host.yml up -d
    ```

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
    cd /docker/home; sudo docker compose up -d
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
