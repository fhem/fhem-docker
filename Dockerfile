ARG BASE_IMAGE="debian"
ARG BASE_IMAGE_TAG="stretch"
FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG}

# Arguments to instantiate as variables
ARG BASE_IMAGE
ARG BASE_IMAGE_TAG
ARG ARCH="amd64"
ARG PLATFORM="linux"
ARG TAG=""
ARG TAG_ROLLING=""
ARG BUILD_DATE=""
ARG IMAGE_VCS_REF=""
ARG VCS_REF=""
ARG FHEM_VERSION=""
ARG IMAGE_VERSION=""

# Re-usable variables during build
ARG L_AUTHORS="Julian Pawlowski (Forum.fhem.de:@loredo, Twitter:@loredo)"
ARG L_URL="https://hub.docker.com/r/fhem/fhem-${ARCH}_${PLATFORM}"
ARG L_USAGE="https://github.com/fhem/fhem-docker/blob/${IMAGE_VCS_REF}/README.md"
ARG L_VCS_URL="https://github.com/fhem/fhem-docker/"
ARG L_VENDOR="FHEM"
ARG L_LICENSES="MIT"
ARG L_TITLE="fhem-${ARCH}_${PLATFORM}"
ARG L_DESCR="A basic Docker image for FHEM house automation system, based on Debian Stretch."

ARG L_AUTHORS_FHEM="https://fhem.de/MAINTAINER.txt"
ARG L_URL_FHEM="https://fhem.de/"
ARG L_USAGE_FHEM="https://fhem.de/#Documentation"
ARG L_VCS_URL_FHEM="https://svn.fhem.de/"
ARG L_VENDOR_FHEM="FHEM"
ARG L_LICENSES_FHEM="GPL-2.0"
ARG L_DESCR_FHEM="FHEM (TM) is a GPL'd perl server for house automation. It is used to automate some common tasks in the household like switching lamps / shutters / heating / etc. and to log events like temperature / humidity / power consumption."

# annotation labels according to
# https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.authors=${L_AUTHORS}
LABEL org.opencontainers.image.url=${L_URL}
LABEL org.opencontainers.image.documentation=${L_USAGE}
LABEL org.opencontainers.image.source=${L_VCS_URL}
LABEL org.opencontainers.image.version=${IMAGE_VERSION}
LABEL org.opencontainers.image.revision=${IMAGE_VCS_REF}
LABEL org.opencontainers.image.vendor=${L_VENDOR}
LABEL org.opencontainers.image.licenses=${L_LICENSES}
LABEL org.opencontainers.image.title=${L_TITLE}
LABEL org.opencontainers.image.description=${L_DESCR}

# non-standard labels
LABEL org.fhem.authors=${L_AUTHORS_FHEM}
LABEL org.fhem.url=${L_URL_FHEM}
LABEL org.fhem.documentation=${L_USAGE_FHEM}
LABEL org.fhem.source=${L_VCS_URL_FHEM}
LABEL org.fhem.version=${FHEM_VERSION}
LABEL org.fhem.revision=${VCS_REF}
LABEL org.fhem.vendor=${L_VENDOR_FHEM}
LABEL org.fhem.licenses=${L_LICENSES_FHEM}
LABEL org.fhem.description=${L_DESCR_FHEM}

ENV TERM xterm
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install base environment
COPY ./src/qemu-* /usr/bin/
COPY src/entry.sh /entry.sh
COPY src/ssh_known_hosts.txt /ssh_known_hosts.txt
COPY src/health-check.sh /health-check.sh
COPY src/find-* /usr/local/bin/
COPY src/99_DockerImageInfo.pm /fhem/FHEM/
RUN chmod 755 /*.sh /usr/local/bin/* \
    && echo "org.opencontainers.image.created=${BUILD_DATE}\norg.opencontainers.image.authors=${L_AUTHORS}\norg.opencontainers.image.url=${L_URL}\norg.opencontainers.image.documentation=${L_USAGE}\norg.opencontainers.image.source=${L_VCS_URL}\norg.opencontainers.image.version=${IMAGE_VERSION}\norg.opencontainers.image.revision=${IMAGE_VCS_REF}\norg.opencontainers.image.vendor=${L_VENDOR}\norg.opencontainers.image.licenses=${L_LICENSES}\norg.opencontainers.image.title=${L_TITLE}\norg.opencontainers.image.description=${L_DESCR}\norg.fhem.authors=${L_AUTHORS_FHEM}\norg.fhem.url=${L_URL_FHEM}\norg.fhem.documentation=${L_USAGE_FHEM}\norg.fhem.source=${L_VCS_URL_FHEM}\norg.fhem.version=${FHEM_VERSION}\norg.fhem.revision=${VCS_REF}\norg.fhem.vendor=${L_VENDOR_FHEM}\norg.fhem.licenses=${L_LICENSES_FHEM}\norg.fhem.description=${L_DESCR_FHEM}" > /image_info \
    && sed -i "s/stretch main/stretch main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/stretch-updates main/stretch-updates main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/stretch\/updates main/stretch\/updates main contrib non-free/g" /etc/apt/sources.list \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        gnupg \
        locales \
    && DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends upgrade \
    \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && /usr/sbin/update-locale LANG=en_US.UTF-8 \
    \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata \
    \
    && sed -i "s,http://deb.debian.org,https://cdn-aws.deb.debian.org,g" /etc/apt/sources.list \
    && sed -i "s,http://security.debian.org,https://cdn-aws.deb.debian.org,g" /etc/apt/sources.list \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        alsa-utils \
        avahi-daemon \
        avrdude \
        bluez \
        curl \
        dfu-programmer \
        dnsutils \
        espeak \
        etherwake \
        git-core \
        i2c-tools \
        inetutils-ping \
        jq \
        lame \
        libav-tools \
        libcap-ng-utils \
        libcap2-bin \
        libttspico-utils \
        lsb-release \
        mariadb-client \
        mp3wrap \
        mpg123 \
        mplayer \
        netcat \
        nmap \
        normalize-audio \
        openssh-client \
        sendemail \
        snmp \
        snmp-mibs-downloader \
        sox \
        sqlite3 \
        subversion \
        sudo \
        telnet \
        telnet-ssl \
        unzip \
        usbutils \
        vorbis-tools \
        wget \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add Perl app layer for pre-compiled packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        perl \
        libalgorithm-merge-perl \
        libauthen-*-perl \
        libcgi-pm-perl \
        libclass-dbi-mysql-perl \
        libclass-isa-perl \
        libclass-loader-perl \
        libcommon-sense-perl \
        libconvert-base32-perl \
        libcpan-meta-yaml-perl \
        libcrypt-*-perl \
        libdata-dump-perl \
        libdatetime-format-strptime-perl \
        libdatetime-perl \
        libdbd-mysql \
        libdbd-mysql-perl \
        libdbd-pg-perl \
        libdbd-sqlite3-perl \
        libdbi-perl \
        libdevel-size-perl \
        libdevice-serialport-perl \
        libdevice-usb-perl \
        libdigest-*-perl \
        libdpkg-perl \
        libencode-perl \
        liberror-perl \
        libev-perl \
        libextutils-makemaker-cpanfile-perl \
        libfile-copy-recursive-perl \
        libfile-fcntllock-perl \
        libfinance-quote-perl \
        libgd-graph-perl \
        libgd-text-perl \
        libgnupg-interface-perl \
        libhtml-strip-perl \
        libhtml-treebuilder-xpath-perl \
        libimage-imlib2-perl \
        libimage-info-perl \
        libimage-librsvg-perl \
        libio-all-perl \
        libio-file-withpath-perl \
        libio-interface-perl \
        libio-socket-*-perl \
        libjson-perl \
        libjson-xs-perl \
        liblinux-inotify2-perl \
        liblist-moreutils-perl \
        libmail-gnupg-perl \
        libmail-imapclient-perl \
        libmail-sendmail-perl \
        libmath-round-perl \
        libmime-base64-perl \
        libmime-lite-perl \
        libmodule-pluggable-perl \
        libmojolicious-perl \
        libmoose-perl \
        libmoox-late-perl \
        libmp3-info-perl \
        libmp3-tag-perl \
        libnet-address-ip-local-perl \
        libnet-bonjour-perl \
        libnet-jabber-perl \
        libnet-oauth-perl \
        libnet-oauth2-perl \
        libnet-server-perl \
        libnet-sip-perl \
        libnet-snmp-perl \
        libnet-ssleay-perl \
        libnet-telnet-perl \
        libnet-xmpp-perl \
        libnmap-parser-perl \
        librivescript-perl \
        librpc-xml-perl \
        libsnmp-perl \
        libsnmp-session-perl \
        libsoap-lite-perl \
        libsocket-perl \
        libsocket6-perl \
        libsox-fmt-mp3 \
        libswitch-perl \
        libsys-hostname-long-perl \
        libsys-statistics-linux-perl \
        libterm-readkey-perl \
        libterm-readline-perl-perl \
        libtext-csv-perl \
        libtext-diff-perl \
        libtime-period-perl \
        libtimedate-perl \
        libtypes-path-tiny-perl \
        liburi-escape-xs-perl \
        libusb-1.0-0-dev \
        libutf8-all-perl \
        libwww-curl-perl \
        libwww-perl \
        libxml-libxml-perl \
        libxml-parser-lite-perl \
        libxml-parser-perl \
        libxml-simple-perl \
        libxml-stream-perl \
        libxml-treebuilder-perl \
        libxml-xpath-perl \
        libxml-xpathengine-perl \
        libyaml-libyaml-perl \
        libyaml-perl \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add development/compilation layer
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        libavahi-compat-libdnssd-dev \
        libdb-dev \
        libssl-dev \
        libtool \
        patch \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add Perl app layer for self-compiled modules
#  * exclude any ARM platforms due too long build time
#  * manually pre-compiled ARM packages may be applied here
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        cpanminus \
    && cpanm \
        App::cpanminus \
        App::cpanoutdated \
        CPAN::Plugin::Sysdeps \
    && if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "i386" ]; then \
        cpanm \
         Crypt::OpenSSL::AES \
         CryptX \
         Device::SMBus \
         Net::MQTT::Constants \
         Net::MQTT::Simple \
         Net::WebSocket::Server \
        && if [ "${ARCH}" = "amd64" ]; then \
            cpanm \
             Crypt::Random \
             Math::Pari \
           ; fi \
        ; fi \
    && rm -rf /root/.cpanm \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add Python app layer
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        libinline-python-perl \
        python3 \
        python3-dev \
        python3-pip \
    && pip3 install \
        setuptools \
        wheel \
    && pip3 install \
        pychromecast \
        speedtest-cli \
        youtube-dl \
    && if [ "${ARCH}" = "arm32v5" ] || [ "${ARCH}" = "arm32v7" ] || [ "${ARCH}" = "arm64v8" ]; then \
        pip3 install \
         rpi.gpio \
       ; fi \
    && mkdir -p /usr/local/speedtest-cli && ln -s ../bin/speedtest-cli /usr/local/speedtest-cli/speedtest-cli \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add nodejs app layer
RUN if [ "${ARCH}" != "arm32v5" ]; then \
      if [ "${ARCH}" = "i386" ]; then \
          curl -sL https://deb.nodesource.com/setup_8.x | bash - \
        ; else \
          curl -sL https://deb.nodesource.com/setup_10.x | bash - \
        ; fi \
      && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
          nodejs \
      && npm update -g --unsafe-perm \
      && npm install -g --unsafe-perm \
          alexa-cookie2 \
          alexa-fhem \
          gassistant-fhem \
          homebridge \
          homebridge-fhem \
          tradfri-fhem \
      && apt-get autoremove -qqy && apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi

# Add FHEM app layer
# Note: Manual checkout is required if build is not run by Travis:
#   svn co https://svn.fhem.de/fhem/trunk ./src/fhem/trunk
COPY src/fhem/trunk/fhem/ /fhem/

VOLUME [ "/opt/fhem" ]

EXPOSE 7072 8083

HEALTHCHECK --interval=20s --timeout=10s --start-period=60s --retries=5 CMD /health-check.sh

WORKDIR "/opt/fhem"
ENTRYPOINT [ "/entry.sh" ]
CMD [ "start" ]
