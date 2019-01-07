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

# Configure environment
COPY ./src/qemu-* /usr/bin/

RUN echo "org.opencontainers.image.created=${BUILD_DATE}\norg.opencontainers.image.authors=${L_AUTHORS}\norg.opencontainers.image.url=${L_URL}\norg.opencontainers.image.documentation=${L_USAGE}\norg.opencontainers.image.source=${L_VCS_URL}\norg.opencontainers.image.version=${IMAGE_VERSION}\norg.opencontainers.image.revision=${IMAGE_VCS_REF}\norg.opencontainers.image.vendor=${L_VENDOR}\norg.opencontainers.image.licenses=${L_LICENSES}\norg.opencontainers.image.title=${L_TITLE}\norg.opencontainers.image.description=${L_DESCR}\norg.fhem.authors=${L_AUTHORS_FHEM}\norg.fhem.url=${L_URL_FHEM}\norg.fhem.documentation=${L_USAGE_FHEM}\norg.fhem.source=${L_VCS_URL_FHEM}\norg.fhem.version=${FHEM_VERSION}\norg.fhem.revision=${VCS_REF}\norg.fhem.vendor=${L_VENDOR_FHEM}\norg.fhem.licenses=${L_LICENSES_FHEM}\norg.fhem.description=${L_DESCR_FHEM}" > /image_info

# Install base environment
RUN sed -i "s/stretch main/stretch main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/stretch-updates main/stretch-updates main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/stretch\/updates main/stretch\/updates main contrib non-free/g" /etc/apt/sources.list \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-transport-https \
        apt-utils \
        locales \
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
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        avahi-daemon \
        avrdude \
        bluez \
        build-essential \
        cpanminus \
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
        libpopt-dev \
        libssl-dev \
        libttspico-utils \
        mp3wrap \
        mplayer \
        mysql-client \
        netcat \
        nmap \
        openssh-client \
        perl \
        python \
        python-dev \
        python-enum34 \
        python-pip \
        python-setuptools \
        sendemail \
        snmp \
        sox \
        sqlite3 \
        subversion \
        sudo \
        telnet \
        telnet-ssl \
        unzip \
        usbutils \
        youtube-dl \
        wget \
        \
        libalgorithm-merge-perl \
        libauthen-*-perl \
        libavahi-compat-libdnssd-dev \
        libcgi-pm-perl \
        libclass-dbi-mysql-perl \
        libclass-isa-perl \
        libclass-loader-perl \
        libcommon-sense-perl \
        libconvert-base32-perl \
        libcrypt-*-perl \
        libdata-dump-perl \
        libdatetime-format-strptime-perl \
        libdbd-mysql \
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
        libfile-copy-recursive-perl \
        libfile-fcntllock-perl \
        libfinance-quote-perl \
        libgd-graph-perl \
        libgd-text-perl \
        libgnupg-interface-perl \
        libhtml-strip-perl \
        libhtml-treebuilder-xpath-perl \
        libimage-info-perl \
        libimage-librsvg-perl \
        libinline-python-perl \
        libio-file-withpath-perl \
        libio-socket-*-perl \
        libjson-perl \
        libjson-xs-perl \
        liblist-moreutils-perl \
        libmail-gnupg-perl \
        libmail-imapclient-perl \
        libmail-sendmail-perl \
        libmime-base64-perl \
        libmime-lite-perl \
        libmodule-pluggable-perl \
        libmojolicious-perl \
        libmoox-late-perl \
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
        liburi-escape-xs-perl \
        libusb-1.0-0-dev \
        libwww-curl-perl \
        libwww-perl \
        libxml-parser-lite-perl \
        libxml-parser-perl \
        libxml-simple-perl \
        libxml-stream-perl \
        libxml-treebuilder-perl \
        libxml-xpath-perl \
        libxml-xpathengine-perl \
        libyaml-libyaml-perl \
        libyaml-perl \
    && pip install \
        pychromecast \
    && cpanm \
        Crypt::Mode \
        Crypt::OpenSSL::AES \
        Device::SMBus \
        Net::MQTT::Constants \
        Net::MQTT::Simple \
    && if [ "${ARCH}" != "i386" ]; then \
         cpanm \
           Crypt::Random \
       ; fi \
    && if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "i386" ]; then \
         cpanm \
           Crypt::Cipher::AES \
       ; fi \
    && if [ "${ARCH}" = "arm32v5" ] || [ "${ARCH}" = "arm32v7" ] || [ "${ARCH}" = "arm64v8" ]; then \
         cpanm \
           HiPi \
           RPi::WiringPi \
         && git clone git://git.drogon.net/wiringPi \
           && cd ./wiringPi \
           && ./build \
           && cd .. \
           && rm -rf ./wiringPi \
       ; fi \
    && rm -rf /root/.cpanm \
    && if [ -d ./src/fhem/ ]; then \
         svn up ./src/fhem >/dev/null \
       ; else \
         svn co https://svn.fhem.de/fhem/trunk ./src/fhem/trunk \
       ; fi \
    && apt-get purge -qqy \
        build-essential \
        cpanminus \
        libpopt-dev \
        libssl-dev \
        python-dev \
        python-setuptools \
        unzip \
        subversion \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY src/entry.sh /entry.sh
COPY src/health-check.sh /health-check.sh
COPY src/find-missing-deb-packages.sh /usr/local/bin/find-missing-deb-packages.sh
COPY src/find-missing-perl-modules.sh /usr/local/bin/find-missing-perl-modules.sh
COPY src/fhem/trunk/fhem/ /fhem/
COPY src/99_DockerImageInfo.pm /fhem/FHEM/
ADD https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py /usr/local/bin/speedtest-cli
RUN chmod 755 /*.sh /usr/local/bin/speedtest-cli

VOLUME [ "/opt/fhem" ]

EXPOSE 7072 8083

HEALTHCHECK --interval=20s --timeout=10s --start-period=60s --retries=5 CMD /health-check.sh

WORKDIR "/opt/fhem"
ENTRYPOINT [ "/entry.sh" ]
CMD [ "start" ]
