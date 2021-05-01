#ARG BASE_IMAGE="debian"
#ARG BASE_IMAGE_TAG="buster-20210408-slim"
FROM --platform=$TARGETPLATFORM debian:buster-20210408-slim

ARG TARGETPLATFORM

ENV LANG=en_US.UTF-8 \
   LANGUAGE=en_US:en \
   LC_ADDRESS=de_DE.UTF-8 \
   LC_MEASUREMENT=de_DE.UTF-8 \
   LC_MESSAGES=en_DK.UTF-8 \
   LC_MONETARY=de_DE.UTF-8 \
   LC_NAME=de_DE.UTF-8 \
   LC_NUMERIC=de_DE.UTF-8 \
   LC_PAPER=de_DE.UTF-8 \
   LC_TELEPHONE=de_DE.UTF-8 \
   LC_TIME=de_DE.UTF-8 \
   TERM=xterm \
   TZ=Europe/Berlin \
   LOGFILE=./log/fhem-%Y-%m-%d.log \
   TELNETPORT=7072 \
   FHEM_UID=6061 \
   FHEM_GID=6061 \
   FHEM_PERM_DIR=0750 \
   FHEM_PERM_FILE=0640 \
   UMASK=0037 \
   BLUETOOTH_GID=6001 \
   GPIO_GID=6002 \
   I2C_GID=6003 \
   TIMEOUT=10 \
   CONFIGTYPE=fhem.cfg

# Install base environment, cache is invalidated here, because we set a BUILD_DATE Variable which changes every run.
COPY ./src/qemu-* /usr/bin/
COPY src/entry.sh src/health-check.sh src/ssh_known_hosts.txt /
COPY src/find-* /usr/local/bin/

# Custom installation packages
ARG APT_PKGS=""

RUN chmod 755 /*.sh /usr/local/bin/* \
    && sed -i "s/buster main/buster main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/buster-updates main/buster-updates main contrib non-free/g" /etc/apt/sources.list \
    && sed -i "s/buster\/updates main/buster\/updates main contrib non-free/g" /etc/apt/sources.list \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-utils=1.8.2.2 \
        ca-certificates=20200601~deb10u2 \
        gnupg=2.2.12-1+deb10u1 \
        locales=2.28-10 \
    && LC_ALL=C c_rehash \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
    && echo 'de_DE@euro ISO-8859-15\nde_DE ISO-8859-1\nde_DE.UTF-8 UTF-8\nen_DK ISO-8859-1\nen_DK.ISO-8859-15 ISO-8859-15\nen_DK.UTF-8 UTF-8\nen_GB ISO-8859-1\nen_GB.ISO-8859-15 ISO-8859-15\nen_GB.UTF-8 UTF-8\nen_IE ISO-8859-1\nen_IE.ISO-8859-15 ISO-8859-15\nen_IE.UTF-8 UTF-8\nen_US ISO-8859-1\nen_US.ISO-8859-15 ISO-8859-15\nen_US.UTF-8 UTF-8\nes_ES@euro ISO-8859-15\nes_ES ISO-8859-1\nes_ES.UTF-8 UTF-8\nfr_FR@euro ISO-8859-15\nfr_FR ISO-8859-1\nfr_FR.UTF-8 UTF-8\nit_IT@euro ISO-8859-15\nit_IT ISO-8859-1\nit_IT.UTF-8 UTF-8\nnl_NL@euro ISO-8859-15\nnl_NL ISO-8859-1\nnl_NL.UTF-8 UTF-8\npl_PL ISO-8859-2\npl_PL.UTF-8 UTF-8' >/etc/locale.gen \
    && LC_ALL=C locale-gen \
    \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata \
    \
#    && sed -i "s,http://deb.debian.org,https://cdn-aws.deb.debian.org,g" /etc/apt/sources.list \
#    && sed -i "s,http://security.debian.org,https://cdn-aws.deb.debian.org,g" /etc/apt/sources.list \
#    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        adb=1:8.1.0+r23-5 \
        android-libadb=1:8.1.0+r23-5 \
        avahi-daemon=0.7-4+deb10u1 \
        avrdude=6.3-20171130+svn1429-2 \
        bluez=5.50-1.2~deb10u1 \
        curl=7.64.0-4+deb10u2 \   
        dnsutils=1:9.11.5.P4+dfsg-5.1+deb10u3 \
        etherwake=1.09-4+b1 \
        fonts-liberation=1:1.07.4-9 \
        i2c-tools=4.1-1 \
        inetutils-ping=2:1.9.4-7+deb10u1 \
        jq=1.5+dfsg-2+b1 \
        libcap-ng-utils=0.7.9-2 \
        libcap2-bin=1:2.25-2 \
        lsb-release=10.2019051400 \
        mariadb-client=1:10.3.27-0+deb10u1 \
        net-tools=1.60+git20180626.aebd88e-1 \
        netcat=1.10-41.1 \
        openssh-client=1:7.9p1-10+deb10u2 \
        procps=2:3.3.15-2 \
        sendemail=1.56-5 \
        sqlite3=3.27.2-3+deb10u1 \
        subversion=1.10.4-1+deb10u2 \
        sudo=1.8.27-1+deb10u3 \
        telnet=0.17-41.2 \
        unzip=6.0-23+deb10u2 \
        usbutils=1:010-3 \
        wget=1.20.1-1.1 \        
        ${APT_PKGS} \
    && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add Perl basic app layer for pre-compiled packages
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        libarchive-extract-perl=0.80-1 \
        libarchive-zip-perl=1.64-1 \
        libcgi-pm-perl=4.40-1 \
        libcpanel-json-xs-perl \
        libdbd-mariadb-perl=1.11-3 \
        libdbd-mysql-perl=4.050-2 \
        libdbd-pg-perl=3.7.4-3 \
        libdbd-pgsql=0.9.0-6+b1 \
        libdbd-sqlite3=0.9.0-6+b1 \
        libdbd-sqlite3-perl=1.62-3 \
        libdbi-perl=1.642-1+deb10u2 \
        libdevice-serialport-perl=1.04-3+b6 \
        libdevice-usb-perl=0.37-2+b1 \
        libgd-graph-perl=1.54~ds-2 \
        libgd-text-perl=0.86-9 \
        libimage-imlib2-perl=2.03* \
        libimage-info-perl=1.41-1 \
        libimage-librsvg-perl=0.07* \
        libio-all-perl=0.87-1 \
        libio-file-withpath-perl=0.09-1 \
        libio-interface-perl=1.09-1+b5 \
        libio-socket-inet6-perl=2.72-2 \
        libjson-perl=4.02000-1 \
        libjson-pp-perl=4.02000-1 \
        libjson-xs-perl=3.040-1+b1 \
        liblist-moreutils-perl=0.416-1+b4 \
        libmail-gnupg-perl=0.23-2 \
        libmail-imapclient-perl=3.42-1 \
        libmail-sendmail-perl=0.80-1 \
        libmime-base64-perl \
        libmime-lite-perl=3.030-2 \
        libnet-server-perl=2.009-1 \
        libsocket6-perl=0.29-1+b1 \
        libterm-readline-perl-perl=1.0303-2 \
        libtext-csv-perl=1.99-1 \
        libtext-diff-perl=1.45-1 \
        libtext-iconv-perl=1.7* \
        libtimedate-perl=2.3000-2+deb10u1 \
        libutf8-all-perl=0.024-1 \
        libwww-curl-perl=4.17-5* \
        libwww-perl=6.36-2 \
        libxml-libxml-perl=2.0134+dfsg-1 \
        libxml-parser-lite-perl=0.722-1 \
        libxml-parser-perl=2.44-4 \
        libxml-simple-perl=2.25-1 \
        libxml-stream-perl=1.24-3 \
        libxml-treebuilder-perl=5.4-2 \
        libxml-xpath-perl=1.44-1 \
        libxml-xpathengine-perl=0.14-1 \
        libyaml-libyaml-perl=0.76+repack-1 \
        libyaml-perl=1.27-1 \
        perl-base=5.28.1-6+deb10u1 \
    && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Custom image layers options:
ARG IMAGE_LAYER_SYS_EXT="1"

# Add extended system layer
RUN if [ "${IMAGE_LAYER_SYS_EXT}" != "0" ]; then \
      LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
      && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        alsa-utils=1.1.8-2 \
        dfu-programmer=0.6.1-1+b1 \
        espeak=1.48.04+dfsg-7+deb10u1 \
        ffmpeg=7:4.1.6-1~deb10u1 \
        lame=3.100-2+b1 \
        libnmap-parser-perl=1.37-1 \
        libttspico-utils=1.0+git20130326-9 \
        mp3wrap=0.5-4 \
        mpg123=1.25.10-2 \
        mplayer=2:1.3.0-8+b4 \
        nmap=7.70+dfsg1-6+deb10u1 \
        normalize-audio=0.7.7-15 \
        snmp=5.7.3+dfsg-5+deb10u2 \
        snmp-mibs-downloader=1.2 \
        sox=14.4.2+git20190427-1 \
        vorbis-tools=1.4.0-11 \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi


# Custom image layers options:
ARG IMAGE_LAYER_PERL_EXT="1"

# Add Perl extended app layer for pre-compiled packages
RUN if [ "${IMAGE_LAYER_PERL_EXT}" != "0" ]; then \
      LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
      && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        libalgorithm-merge-perl=0.08-3 \
        libauthen-bitcard-perl=0.90-2 \
        libauthen-captcha-perl=1.024-2 \
        libauthen-cas-client-perl=0.07-2 \
        libauthen-dechpwd-perl=2.007-1~1+b1 \
        libauthen-htpasswd-perl=0.171-2 \
        libauthen-krb5-admin-perl=0.17-1* \
        libauthen-krb5-perl=1.9-5+b4 \
        libauthen-krb5-simple-perl=0.43-2* \
        libauthen-libwrap-perl=0.23-1+b3 \
        libauthen-ntlm-perl=1.09-1 \
        libauthen-oath-perl=2.0.1-1 \
        libauthen-pam-perl=0.16-3+b6 \
        libauthen-passphrase-perl=0.008-2 \
        libauthen-radius-perl=0.29-2 \
        libauthen-sasl-cyrus-perl=0.13-server-10* \
        libauthen-sasl-perl=2.1600-1 \
        libauthen-sasl-saslprep-perl=1.100-1 \
        libauthen-scram-perl=0.011-1 \
        libauthen-simple-cdbi-perl=0.2-3 \
        libauthen-simple-dbi-perl=0.2-3 \
        libauthen-simple-dbm-perl=0.2-4 \
        libauthen-simple-http-perl=0.2-5 \
        libauthen-simple-kerberos-perl=0.1-5 \
        libauthen-simple-ldap-perl=0.3-1 \
        libauthen-simple-net-perl=0.2-5 \
        libauthen-simple-pam-perl=0.2-4 \
        libauthen-simple-passwd-perl=0.6-4 \
        libauthen-simple-perl=0.5-1 \
        libauthen-simple-radius-perl=0.1-3 \
        libauthen-simple-smb-perl=0.1-4 \
        libauthen-smb-perl=0.91-6+b6 \
        libauthen-tacacsplus-perl=0.26-1+b5 \
        libauthen-u2f-perl=0.003-1 \
        libauthen-u2f-tester-perl=0.03-1 \          
        libclass-dbi-mysql-perl=1.00-4 \
        libclass-isa-perl=0.36-6 \
        libclass-loader-perl=2.03-2 \
        libcommon-sense-perl=3.74-2+b7 \
        libconvert-base32-perl=0.06-1 \
        libcpan-meta-yaml-perl=0.018-1 \
        libcrypt-blowfish-perl=2.14-1* \
        libcrypt-cast5-perl=0.05-2+b1 \
        libcrypt-cbc-perl=2.33-2 \
        libcrypt-ciphersaber-perl=1.01-2.1 \
        libcrypt-cracklib-perl=1.7-2* \
        libcrypt-des-ede3-perl=0.01-1.1 \
        libcrypt-des-perl=2.07-1* \
        libcrypt-dh-gmp-perl=0.00012-1+b6 \
        libcrypt-dh-perl=0.07-2 \
        libcrypt-dsa-perl=1.17-4 \
        libcrypt-ecb-perl=2.21-1 \
        libcrypt-eksblowfish-perl=0.009-2+b5 \
        libcrypt-format-perl=0.09-1 \
        libcrypt-gcrypt-perl=1.26-5+b3 \
        libcrypt-generatepassword-perl=0.05-1 \
        libcrypt-hcesha-perl=0.75-1 \
        libcrypt-jwt-perl=0.023-1 \
        libcrypt-mysql-perl=0.04-6+b4 \
        libcrypt-openssl-bignum-perl=0.09-1+b1 \
        libcrypt-openssl-dsa-perl=0.19-1+b3 \
        libcrypt-openssl-ec-perl=1.31-1+b1 \
        libcrypt-openssl-pkcs10-perl=0.16-3+b1 \
        libcrypt-openssl-pkcs12-perl=1.2-1 \
        libcrypt-openssl-random-perl=0.15-1+b1 \
        libcrypt-openssl-rsa-perl=0.31-1+b1 \
        libcrypt-openssl-x509-perl=1.8.12-1 \
        libcrypt-passwdmd5-perl=1.40-1 \
        libcrypt-pbkdf2-perl=0.161520-1 \
        libcrypt-random-seed-perl=0.03-1 \
        libcrypt-random-source-perl=0.14-1 \
        libcrypt-rc4-perl=2.02-3 \
        libcrypt-rijndael-perl=1.13-1+b5 \
        libcrypt-rsa-parse-perl=0.044-1 \
        libcrypt-saltedhash-perl=0.09-1 \
        libcrypt-simple-perl=0.06-7 \
        libcrypt-smbhash-perl=0.12-4 \
        libcrypt-smime-perl=0.25-1+b1 \
        libcrypt-ssleay-perl=0.73.06-1+b1 \
        libcrypt-twofish-perl=2.17-2+b1 \
        libcrypt-u2f-server-perl=0.43-1+b1 \
        libcrypt-unixcrypt-perl=1.0-7 \
        libcrypt-unixcrypt-xs-perl=0.11-1+b3 \
        libcrypt-urandom-perl=0.36-1 \
        libcrypt-util-perl=0.11-3 \
        libcrypt-x509-perl=0.51-1 \          
        libcryptx-perl=0.063-1 \
        libdata-dump-perl=1.23-1 \
        libdatetime-format-strptime-perl=1.7600-1 \
        libdatetime-perl=2:1.50-1+b1 \
        libdevel-size-perl=0.82-1+b1 \
        libdigest-bcrypt-perl=1.209-2 \
        libdigest-bubblebabble-perl=0.02-2 \
        libdigest-crc-perl=0.22.2-1+b1 \
        libdigest-elf-perl=1.42-1+b4 \
        libdigest-hmac-perl=1.03+dfsg-2 \
        libdigest-jhash-perl=0.10-1+b3 \
        libdigest-md2-perl=2.04+dfsg-1+b1 \
        libdigest-md4-perl=1.9+dfsg-2+b1 \
        libdigest-md5-file-perl=0.08-1 \
        libdigest-perl-md5-perl=1.9-1 \
        libdigest-sha-perl=6.02-1+b1 \
        libdigest-sha3-perl=1.04-1+b1 \
        libdigest-ssdeep-perl=0.9.3-1 \
        libdigest-whirlpool-perl=1.09-1.1+b1 \          
        libdpkg-perl=1.19.7 \
        libencode-perl=3.00-1 \
        liberror-perl=0.17027-2 \
        libev-perl=4.25-1 \
        libextutils-makemaker-cpanfile-perl=0.09-1 \
        libfile-copy-recursive-perl=0.44-1 \
        libfile-fcntllock-perl=0.22-3+b5 \
        libfinance-quote-perl=1.47-1 \
        libgnupg-interface-perl=0.52-10 \
        libhtml-strip-perl=2.10-1+b3 \
        libhtml-treebuilder-xpath-perl=0.14-1 \
        libio-socket-inet6-perl=2.72-2 \
        libio-socket-ip-perl=0.39-1 \
        libio-socket-multicast-perl=1.12-2* \
        libio-socket-portstate-perl=0.03-1 \
        libio-socket-socks-perl=0.74-1 \
        libio-socket-ssl-perl=2.060-3 \
        libio-socket-timeout-perl=0.32-1 \
        liblinux-inotify2-perl=1:2.1-1 \
        libmath-round-perl=0.07-1 \
        libmodule-pluggable-perl=5.2-1 \
        libmojolicious-perl=8.12+dfsg-1 \
        libmoose-perl=2.2011-1+b1 \
        libmoox-late-perl=0.015-4 \
        libmp3-info-perl=1.24-1.2 \
        libmp3-tag-perl=1.13-1.1 \
        libnet-address-ip-local-perl=0.1.2-3 \
        libnet-bonjour-perl=0.96-2 \
        libnet-jabber-perl=2.0-8 \
        libnet-oauth-perl=0.28-3 \
        libnet-oauth2-perl=0.64-1 \
        libnet-sip-perl=0.820-1 \
        libnet-snmp-perl=6.0.1-5 \
        libnet-ssleay-perl=1.85-2+b1 \
        libnet-telnet-perl=3.04-1 \
        libnet-xmpp-perl=1.05-1 \
        libnmap-parser-perl=1.37-1 \
        librivescript-perl=2.0.3-1 \
        librpc-xml-perl=0.80-2 \
        libsnmp-perl=5.7.3+dfsg-5+deb10u1 \
        libsnmp-session-perl=1.14~git20130523.186a005-4 \
        libsoap-lite-perl=1.27-1 \
        libsocket-perl=2.029-1 \
        libswitch-perl=2.17-2 \
        libsys-hostname-long-perl=1.5-1 \
        libsys-statistics-linux-perl=0.66-3 \
        libterm-readkey-perl=2.38-1 \
        libterm-readline-perl-perl=1.0303-2 \
        libtime-period-perl=1.25-1 \
        libtypes-path-tiny-perl=0.006-1 \
        liburi-escape-xs-perl=0.14-1+b3 \
        perl=5.28.1-6+deb10u1 \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi

# Custom image layers options:
ARG IMAGE_LAYER_DEV="1"

# Add development/compilation layer
RUN if [ "${IMAGE_LAYER_DEV}" != "0" ] || [ "${IMAGE_LAYER_PERL_CPAN}" != "0" ] || [ "${IMAGE_LAYER_PERL_CPAN_EXT}" != "0" ] || [ "${IMAGE_LAYER_PYTHON}" != "0" ] || [ "${IMAGE_LAYER_PYTHON_EXT}" != "0" ] || [ "${IMAGE_LAYER_NODEJS}" != "0" ] || [ "${IMAGE_LAYER_NODEJS_EXT}" != "0" ]; then \
      LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
      && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        autoconf=2.69-11 \
        automake=1:1.16.1-4 \
        build-essential=12.6 \
        libavahi-compat-libdnssd-dev=0.7-4+deb10u1 \
        libdb-dev=5.3.1+nmu1 \
        libsodium-dev=1.0.17-1 \
        libssl-dev=1.1.1d-0+deb10u6 \
        libtool=2.4.6-9 \
        libusb-1.0-0-dev=2:1.0.22-2 \
        patch=2.7.6-3+deb10u1 \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi


# Custom image layers options:
ARG IMAGE_LAYER_PERL_CPAN="1"
ARG IMAGE_LAYER_PERL_CPAN_EXT="1"

# Custom installation packages
ARG CPAN_PKGS=""

# Add Perl app layer for self-compiled modules
#  * exclude any ARM platforms due to long build time
#  * manually pre-compiled ARM packages may be applied here
RUN if [ "${CPAN_PKGS}" != "" ] || [ "${PIP_PKGS}" != "" ] || [ "${IMAGE_LAYER_PERL_CPAN}" != "0" ] || [ "${IMAGE_LAYER_PERL_CPAN_EXT}" != "0" ] || [ "${IMAGE_LAYER_PYTHON}" != "0" ] || [ "${IMAGE_LAYER_PYTHON_EXT}" != "0" ]; then \
      curl --retry 3 --retry-connrefused --retry-delay 2 -fsSL https://git.io/cpanm | perl - App::cpanminus \
      && cpanm --notest \
          App::cpanoutdated \
          CPAN::Plugin::Sysdeps \
          Perl::PrereqScanner::NotQuiteLite \
      && if [ "${CPAN_PKGS}" != "" ]; then \
          cpanm \
           ${CPAN_PKGS} \
         ; fi \
      && if [ "${IMAGE_LAYER_PERL_CPAN_EXT}" != "0" ]; then \
           if [ "${TARGETPLATFORM}" = "linux/amd64" ] || [ "${TARGETPLATFORM}" = "linux/i386" ]; then \
             cpanm --notest \
              Alien::Base::ModuleBuild \
              Alien::Sodium \
              Crypt::Argon2 \
              Crypt::OpenSSL::AES \
              Device::SMBus \
              Net::MQTT::Constants \
              Net::MQTT::Simple \
              Net::WebSocket::Server \
             ; fi \
         ; fi \
      && rm -rf /root/.cpanm \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi

# Custom image layers options:
ARG IMAGE_LAYER_PYTHON="1"
ARG IMAGE_LAYER_PYTHON_EXT="1"

# Custom installation packages
ARG PIP_PKGS=""

# Add Python app layer
RUN if [ "${PIP_PKGS}" != "" ] || [ "${IMAGE_LAYER_PYTHON}" != "0" ] || [ "${IMAGE_LAYER_PYTHON_EXT}" != "0" ]; then \
      LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update \
      && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        python3=3.7.3-1 \
        python3-dev=3.7.3-1 \
        python3-pip=18.1-5 \
        python3-setuptools=40.8.0-1 \
        python3-wheel=0.32.3-2 \
      && if [ "${PIP_PKGS}" != "" ]; then \
           pip3 install \
            ${PIP_PKGS} \
         ; fi \
      && if [ "${IMAGE_LAYER_PYTHON_EXT}" != "0" ]; then \
           LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
                python3-pychromecast=2.4.0-1 \
                speedtest-cli=2.0.2-1+deb10u1 \
                youtube-dl=2019.01.17-1.1 \
             && ln -s ../../bin/speedtest-cli /usr/local/bin/speedtest-cli \
        ; fi \
      && rm -rf /root/.cpanm \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi

# Custom installation packages
ARG NPM_PKGS=""

# Custom image layers options:
ARG IMAGE_LAYER_NODEJS="1"
ARG IMAGE_LAYER_NODEJS_EXT="1"

# Add nodejs app layer
RUN if ( [ "${NPM_PKGS}" != "" ] || [ "${IMAGE_LAYER_NODEJS}" != "0" ] || [ "${IMAGE_LAYER_NODEJS_EXT}" != "0" ] ) ; then \
      LC_ALL=C curl --retry 3 --retry-connrefused --retry-delay 2 -fsSL https://deb.nodesource.com/setup_14.x | LC_ALL=C bash - \
      && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
          nodejs=14.* \
      && if [ ! -e /usr/bin/npm ]; then \
           LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
             npm=5.8.* \
      ; fi \
      && npm install -g --unsafe-perm --production \
          npm \
      && if [ "${NPM_PKGS}" != "" ]; then \
          npm install -g --unsafe-perm --production \
           ${NPM_PKGS} \
         ; fi \
      && if [ "${IMAGE_LAYER_NODEJS_EXT}" != "0" ]; then \
           npm install -g --unsafe-perm --production \
            alexa-cookie2 \
            alexa-fhem \
            gassistant-fhem \
            homebridge \
            homebridge-fhem \
            tradfri-fhem \
        ; fi \
      && LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
    ; fi

# Add FHEM app layer
# Note: Manual checkout is required if build is not run by Github Actions workflow:
#   svn co https://svn.fhem.de/fhem/trunk ./src/fhem/trunk

COPY src/fhem/trunk/fhem/ /fhem/
COPY src/FHEM/ /fhem/FHEM

# Moved AGS to the end, because it changes every run and invalidates the cache for all following steps  https://github.com/moby/moby/issues/20136
# Arguments to instantiate as variables
ARG PLATFORM="linux"
ARG TAG=""
ARG TAG_ROLLING=""
ARG IMAGE_VCS_REF=""
ARG VCS_REF=""
ARG FHEM_VERSION=""
ARG IMAGE_VERSION=""
ARG BUILD_DATE=""

# Re-usable variables during build
ARG L_AUTHORS="Julian Pawlowski (Forum.fhem.de:@loredo, Twitter:@loredo)"
ARG L_URL="https://hub.docker.com/r/fhem/fhem-${TARGETPLATFORM}"
ARG L_USAGE="https://github.com/fhem/fhem-docker/blob/${IMAGE_VCS_REF}/README.md"
ARG L_VCS_URL="https://github.com/fhem/fhem-docker/"
ARG L_VENDOR="Julian Pawlowski"
ARG L_LICENSES="MIT"
ARG L_TITLE="fhem-${TARGETPLATFORM}"
ARG L_DESCR="A basic Docker image for FHEM house automation system, based on Debian Buster."

ARG L_AUTHORS_FHEM="https://fhem.de/MAINTAINER.txt"
ARG L_URL_FHEM="https://fhem.de/"
ARG L_USAGE_FHEM="https://fhem.de/#Documentation"
ARG L_VCS_URL_FHEM="https://svn.fhem.de/"
ARG L_VENDOR_FHEM="FHEM e.V."
ARG L_LICENSES_FHEM="GPL-2.0"
ARG L_DESCR_FHEM="FHEM (TM) is a GPL'd perl server for house automation. It is used to automate some common tasks in the household like switching lamps / shutters / heating / etc. and to log events like temperature / humidity / power consumption."


# non-standard labels
LABEL org.fhem.authors=${L_AUTHORS_FHEM} \
   org.fhem.url=${L_URL_FHEM} \
   org.fhem.documentation=${L_USAGE_FHEM} \
   org.fhem.source=${L_VCS_URL_FHEM} \
   org.fhem.version=${FHEM_VERSION} \
   org.fhem.revision=${VCS_REF} \
   org.fhem.vendor=${L_VENDOR_FHEM} \
   org.fhem.licenses=${L_LICENSES_FHEM} \
   org.fhem.description=${L_DESCR_FHEM}

# annotation labels according to
# https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.created=${BUILD_DATE} \
   org.opencontainers.image.authors=${L_AUTHORS} \
   org.opencontainers.image.url=${L_URL} \
   org.opencontainers.image.documentation=${L_USAGE} \
   org.opencontainers.image.source=${L_VCS_URL} \
   org.opencontainers.image.version=${IMAGE_VERSION} \
   org.opencontainers.image.revision=${IMAGE_VCS_REF} \
   org.opencontainers.image.vendor=${L_VENDOR} \
   org.opencontainers.image.licenses=${L_LICENSES} \
   org.opencontainers.image.title=${L_TITLE} \
   org.opencontainers.image.description=${L_DESCR}

RUN echo "org.opencontainers.image.created=${BUILD_DATE}\norg.opencontainers.image.authors=${L_AUTHORS}\norg.opencontainers.image.url=${L_URL}\norg.opencontainers.image.documentation=${L_USAGE}\norg.opencontainers.image.source=${L_VCS_URL}\norg.opencontainers.image.version=${IMAGE_VERSION}\norg.opencontainers.image.revision=${IMAGE_VCS_REF}\norg.opencontainers.image.vendor=${L_VENDOR}\norg.opencontainers.image.licenses=${L_LICENSES}\norg.opencontainers.image.title=${L_TITLE}\norg.opencontainers.image.description=${L_DESCR}\norg.fhem.authors=${L_AUTHORS_FHEM}\norg.fhem.url=${L_URL_FHEM}\norg.fhem.documentation=${L_USAGE_FHEM}\norg.fhem.source=${L_VCS_URL_FHEM}\norg.fhem.version=${FHEM_VERSION}\norg.fhem.revision=${VCS_REF}\norg.fhem.vendor=${L_VENDOR_FHEM}\norg.fhem.licenses=${L_LICENSES_FHEM}\norg.fhem.description=${L_DESCR_FHEM}" > /image_info \

VOLUME [ "/opt/fhem" ]

EXPOSE 8083

HEALTHCHECK --interval=20s --timeout=10s --start-period=60s --retries=5 CMD /health-check.sh

WORKDIR "/opt/fhem"
ENTRYPOINT [ "/entry.sh" ]
CMD [ "start" ]
