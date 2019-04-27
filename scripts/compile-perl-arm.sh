#!/bin/bash

sudo apt update
sudo apt install -y build-essential devscripts quilt dh-autoreconf dh-systemd ubuntu-dev-tools sbuild debhelper moreutils
sudo adduser $USER sbuild

echo "\$apt_allow_unauthenticated = 1;
\$environment_filter = [
	'^PATH$',
	'^DEB(IAN|SIGN)?_[A-Z_]+$',
	'^(C(PP|XX)?|LD|F)FLAGS(_APPEND)?$',
	'^USER(NAME)?$',
	'^LOGNAME$',
	'^HOME$',
	'^TERM$',
	'^SHELL$',
	'^no_proxy$',
	'^http_proxy$',
	'^https_proxy$',
	'^ftp_proxy$',
];

# Directory for writing build logs to
\$log_dir=\$ENV{HOME}."/ubuntu/logs";

# don't remove this, Perl needs it:
1;" > ~/.sbuildrc
mkdir -p $HOME/ubuntu/{build,logs}

echo "SCHROOT_CONF_SUFFIX=\"source-root-users=root,sbuild,admin
source-root-groups=root,sbuild,admin
preserve-environment=true\"
# you will want to undo the below for stable releases, read \`man mk-sbuild\` for details
# during the development cycle, these pockets are not used, but will contain important
# updates after each release of Ubuntu
# if you have e.g. apt-cacher-ng around
# DEBOOTSTRAP_PROXY=http://127.0.0.1:3142/" > ~/.mk-sbuild.rc

sg sbuild
newgrp sbuild
sudo sbuild-update --keygen
sudo chown -R $USER:sbuild ~/.gnupg/
sudo su -c "grep -q /etc/hosts /etc/schroot/sbuild/copyfiles || echo /etc/hosts >> /etc/schroot/sbuild/copyfiles"

mk-sbuild --target=armel buster
mk-sbuild --target=armhf buster
mk-sbuild --target=arm64 buster

curl -fsSL https://github.com/multiarch/qemu-user-static/releases/download/v4.0.0/x86_64_qemu-arm-static.tar.gz | tar zx -C ~/
curl -fsSL https://github.com/multiarch/qemu-user-static/releases/download/v4.0.0/x86_64_qemu-aarch64-static.tar.gz | tar zx -C ~/
chmod a+x qemu-*-static
sudo cp -f qemu-arm-static /var/lib/schroot/chroots/buster-amd64-armel/usr/bin
sudo cp -f qemu-arm-static /var/lib/schroot/chroots/buster-amd64-armhf/usr/bin
sudo cp -f qemu-aarch64-static /var/lib/schroot/chroots/buster-amd64-arm64/usr/bin

sbuild --chroot buster-amd64-armhf --arch armhf -j8

ARCHLIST="arm32v5 arm32v7 aarch64"
for ARCH in $ARCHLIST; do

  # platforms independent packages
  dh-make-perl make --install --build --cpan Statistics::ChiSquare
  dh-make-perl make --build --cpan Net::MQTT::Constants
  dh-make-perl make --build --cpan Net::MQTT::Simple

  # platform packages
  dh-make-perl make --build --cpan CryptX
  dh-make-perl make --build --cpan Crypt::OpenSSL::AES
  dh-make-perl make --build --cpan Device::SMBus
  dh-make-perl make --install --build --cpan Math::Pari
  dh-make-perl make --bdepends libmath-pari-perl --depends libmath-pari-perl --depends libclass-loader-perl --depends libstatistics-chisquare-perl --build --cpan Crypt::Random

  shopt -s extglob
  rm -rf !(*.deb)
  shopt -u extglob
done
