#!/bin/bash

# Find missing Perl modules that are in use by official modules

FPATH="${1:-/opt/fhem}"
[ ! -d "$FPATH" ] && echo FPATH="."

for module in `find $FPATH/FHEM -type f -name "*.pm" -print0 | xargs -0 grep -oP "[^\w#](?:(?:use|require) (?:[A-Z\'\"$][\w:./{}()$\->\"\']+))" | sed 's|[;"'\'']||g' | sed 's/FHEM\///g' | sed 's/.*\///g' | sed 's/$attr{global}{modpath}//g' | sed 's/$main::attr{global}{modpath}//g' | sort -u -f -k2,2 | cut -d : -f 2- | cut -d " " -f 2 | grep -v -i -E "^(use|require|warnings|vars|feature|inline|strict|constant|POSIX|utf8)" | grep -v "[(){}$]" | grep -v "[.:]$"`; do
  NAME=`echo $module | cut -d " " -f 1 | cut -d ";" -f 1 | cut -d ":" -f 1`
  if [[ -e "$FPATH/$NAME" || -e "$FPATH/FHEM/$NAME" || -f "$FPATH/FHEM/lib/$NAME" || -e "$FPATH/$NAME.pm" || -e "$FPATH/FHEM/$NAME.pm" || -f "$FPATH/FHEM/lib/$NAME.pm" ]]; then
    continue
  fi
  if [[ "x`find $FPATH/FHEM -type f -name "*_$NAME.pm"`" != "x" ]]; then
    continue
  fi
  if [[ "x`find $FPATH/FHEM -type f -name "*_$NAME"`" != "x" ]]; then
    continue
  fi
  if [ -d "$FPATH/FHEM/lib/$NAME" ]; then
    NAME2=`echo $module | cut -d " " -f 1 | cut -d ";" -f 1 | cut -d ":" -f 2`
    if [[ -f "$FPATH/FHEM/lib/$NAME/$NAME2" || -f "$FPATH/FHEM/lib/$NAME/$NAME2.pm" ]]; then
      continue
    fi
    NAME3=`echo $module | cut -d " " -f 1 | cut -d ";" -f 1 | cut -d ":" -f 3`
    if [[ -f "$FPATH/FHEM/lib/$NAME/$NAME2/$NAME3" || -f "$FPATH/FHEM/lib/$NAME/$NAME2/$NAME3.pm" ]]; then
      continue
    fi
  fi
  

  CHK=`perl -e "use $module" 2>1 >/dev/null`
  ret=$?

  if [ $ret != "0" ]; then
    echo $module
  fi
done
