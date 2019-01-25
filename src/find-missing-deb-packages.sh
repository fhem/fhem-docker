#!/bin/bash

# Find missing Debian packages that are in use by official modules

FPATH="${1:-/opt/fhem}"
[ ! -d "$FPATH" ] && echo FPATH="."

echo -e "The following Debian packages might be missing:\n\n"

find $FPATH/FHEM -type f -name "*.pm" -print0 | xargs -0 grep -oP "(?:(?:apt(?:-get)? install )[^\\\\\n<()\"\'&;]+)" | cut -d : -f 2- | sed "s/\[//g" | sed "s/\]//g" | sed "s/apt install //g" | sed "s/apt-get install install //g" | sed "s/apt-get install //g" | sed "s/on Debian and derivatives//g" | sed "s/und noch die mp3 Unterst//g" | sed "s/ /\n/g" | grep -v '^$\|^\s*\#' | sort -u -f > /tmp/missing.apt

for package in `cat /tmp/missing.apt`; do

  CHK=`dpkg -s $package 2>&1 >/dev/null`
  ret=$?

  if [ $ret != "0" ]; then
    echo $package
  fi
done

rm -f /tmp/missing.apt
