#!/bin/bash

STATE=0

FHEMWEB=$( cd /opt/fhem; perl fhem.pl 7072 "jsonlist2 TYPE=FHEMWEB:FILTER=TEMPORARY!=1" 2>/dev/null )
if [ $? -ne 0 ] || [ -z "${FHEMWEB}" ]; then
  RETURN="Telnet(7072): FAILED;"
  STATE=1
else
  RETURN="Telnet(7072): OK;"

  LEN=$( echo ${FHEMWEB} | jq -r '.Results | length' )
  i=0
  until [ "$i" == "${LEN}" ]; do
    NAME=$( echo ${FHEMWEB} | jq -r ".Results[$i].Internals.NAME" )
    PORT=$( echo ${FHEMWEB} | jq -r ".Results[$i].Internals.PORT" )
    HTTPS=$( echo ${FHEMWEB} | jq -r ".Results[$i].Attributes.HTTPS" )
    [[ -n "${HTTPS}" && "${HTTPS}" == "1" ]] && PROTO=https || PROTO=http

    FHEMWEB_STATE=$( curl \
                      --silent \
                      --insecure \
                      --output /dev/null \
                      --write-out "%{http_code}" \
                      --user-agent 'FHEM-Docker/1.0 Health Check' \
                      "${PROTO}://localhost:${PORT}/" )
    if [ $? -ne 0 ] ||
       [ -z "${FHEMWEB_STATE}" ] ||
       [ "${FHEMWEB_STATE}" == "000" ] ||
       [ "${FHEMWEB_STATE:0:1}" == "5" ]; then
      RETURN="${RETURN} ${NAME}(${PORT}): FAILED;"
      STATE=1
    else
      RETURN="${RETURN} ${NAME}(${PORT}): OK;"
    fi
    (( i++ ))
  done

  # Update docker module data
  if [ -s /image_info ]; then
    FHEMCMD="my \$n;;if(defined(\$modules{'DockerImageInfo'}{defptr})){\$n = \$modules{'DockerImageInfo'}{defptr}{NAME}}else{fhem 'define DockerImageInfo DockerImageInfo';;\$n = 'DockerImageInfo';;}\$defs{\$n}{STATE} = 'ok';;readingsBeginUpdate(\$defs{\$n});;"
    touch /image_info.tmp
    for LINE in $( sort -k1,1 -t'=' --stable --unique /image_info.* /image_info ); do
      [ -z "$( echo "$LINE" | grep -P '^org\.opencontainers\..+=.+$' )" ] && continue
      LINE=${LINE#org.opencontainers.}
      NAME=$(echo "${LINE}" | cut -d = -f 1)
      VAL=$(echo "${LINE}" | cut -d = -f 2-)
      [ "${NAME}" == "image.authors" ] && continue
      FHEMCMD="${FHEMCMD}readingsBulkUpdateIfChanged(\$defs{\$n},'${NAME}','${VAL}');;"
    done
    FHEMCMD="${FHEMCMD}readingsEndUpdate(\$defs{\$n},1)"
    RET=$( cd /opt/fhem; perl fhem.pl 7072 "{${FHEMCMD}}" 2>/dev/null )
    [ -n "${RET}" ] && RETURN="${RETURN} DockerImageInfo:FAILED;" || RETURN="${RETURN} DockerImageInfo:OK;"
  fi

fi

echo -n ${RETURN}
exit ${STATE}
