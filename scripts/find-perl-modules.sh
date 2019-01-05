#!/bin/bash

# Find missing Perl modules that are in use by official modules

# use
for module in `find $1./FHEM -type f -name "*.pm" -print0 | xargs -0 grep -oP "^use .*;" | sed 's|[;"'\'']||g' | sed 's/$attr{global}{modpath}//g' | sed 's/$main::attr{global}{modpath}//g' | sort -u -f -k2,2 | cut -d : -f 2- | cut -d " " -f 2 | grep -v -i -E "^(\$|\@|warnings|vars|feature|inline|strict|constant|(\d\.\d+)|POSIX|utf8)"`; do
  NAME=`echo $module | cut -d " " -f 1 | cut -d ";" -f 1 | cut -d ":" -f 1`
  if [[ -e "$1./$NAME" || -e "$1./FHEM/$NAME" || -e "$1./$NAME.pm" || -e "$1./FHEM/$NAME.pm" ]]; then
    # This is a FHEM internal Perl module
    continue
  fi
  CHK=`perl -e "use $module" 2>1 >/dev/null`
  ret=$?
  
  if [ $ret != "0" ]; then
    echo "Checking external module '$module' ... MISSING"
  fi
done

# require
for module in `find $1./FHEM -type f -name "*.pm" -print0 | xargs -0 grep -oP "^require .*;" | sed 's|[;"'\'']||g' | sed 's/$attr{global}{modpath}//g' | sed 's/$main::attr{global}{modpath}//g' | sort -u -f -k2,2 | cut -d : -f 2- | cut -d " " -f 2 | grep -v -i -E "^(\$|\@|warnings|vars|feature|inline|strict|constant|(\d\.\d+)|POSIX|utf8)"`; do
  NAME=`echo $module | cut -d " " -f 1 | cut -d ";" -f 1 | cut -d ":" -f 1`
  if [[ -e "$1./$NAME" || -e "$1./FHEM/$NAME" || -e "$1./$NAME.pm" || -e "$1./FHEM/$NAME.pm" ]]; then
    # This is a FHEM internal Perl module
    continue
  fi
  CHK=`perl -e "use $module" 2>1 >/dev/null`
  ret=$?
  
  if [ $ret != "0" ]; then
    echo "Checking external module '$module' ... MISSING"
  fi
done
