#!/bin/bash

# Find 3rd party modules and their dependencies

FPATH="${1:-/opt/fhem}"
[ ! -d "$FPATH" ] && echo FPATH="."
FTMP="${FPATH}/.depcheck.tmp}"

for repo in $(cat /unofficial_controls.txt unofficial_controls.txt ${FPATH}/FHEM/unofficial_controls.txt ${FPATH}/FHEM/controls.txt 2>/dev/null | grep -v controls_fhem.txt | grep -E -v '^#|^$' | sort -u); do
  lines=$(curl -fsSL ${repo} 2>/dev/null)
  base_url=${repo%/*}
  reponame=${repo##*/}

  echo "Temp. download Perl files from repository ${reponame}:"
  while read -r line; do
    if [[ "${line}" =~ ^UPD.* ]]; then
      filename=$(echo ${line} | cut -d " " -f 4)
      filepath=${filename%/*}
      fileext=${filename##*.}
      mkdir -p ${FTMP}/${filepath}

      if [[ "${fileext}" == "pm" ]]; then
        echo "  ${filename}"
        curl -fsSL -o ${FTMP}/${filename} -C - ${base_url}/${filename} 2>/dev/null
      fi
    fi 
  done <<< "${lines}"
done

echo -e "\n\n-----------------\n"
find-missing-deb-packages.sh $1

echo -e "\n\n"
find-missing-perl-modules.sh $1

echo "Cleaning up ${FTMP}"
rm -rf ${FTMP}
