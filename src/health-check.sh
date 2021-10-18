#!/bin/bash

FHEM_DIR="/opt/fhem"
CONFIGTYPE="${CONFIGTYPE:-"fhem.cfg"}"
TELNETPORT="${TELNETPORT:-7072}"
STATE=0

RUNNING_INSTANCES=$(pgrep -f "/bin/sh -c /health-check.sh" | wc -l)

if [ "${RUNNING_INSTANCES}" -gt "1" ]; then
  echo "Instance already running, aborting another one"
  exit 1
fi

if [ "${CONFIGTYPE}" != "configDB" ] && [ -s "${FHEM_DIR}/${CONFIGTYPE}" ] && [ -z "$(cat ${FHEM_DIR}/${CONFIGTYPE} | grep -P "^define .* telnet ${TELNETPORT}")" ]; then
  TELNETPORT="$(cat ${FHEM_DIR}/${CONFIGTYPE} | grep -P '^define .* telnet ' | head -1 | cut -d ' ' -f 4)"

  if [ -z "${TELNETPORT}" ]; then
    echo "Telnet(undefined): FAILED;"
    exit 1
  fi
fi

FHEMWEB=$( cd /opt/fhem; perl fhem.pl ${TELNETPORT} "jsonlist2 TYPE=FHEMWEB:FILTER=TEMPORARY!=1:FILTER=DockerHealthCheck!=0" 2>/dev/null )
if [ $? -ne 0 ] || [ -z "${FHEMWEB}" ]; then
  RETURN="Telnet(${TELNETPORT}): FAILED;"
  STATE=1
else
  RETURN="Telnet(${TELNETPORT}): OK;"

  LEN=$( echo ${FHEMWEB} | jq -r '.Results | length' )
  i=0
  until [ "$i" == "${LEN}" ]; do
    NAME=$( echo ${FHEMWEB} | jq -r ".Results[$i].Internals.NAME" )
    PORT=$( echo ${FHEMWEB} | jq -r ".Results[$i].Internals.PORT" )
    WEBNAME=$( echo ${FHEMWEB} | jq -r ".Results[$i].Attributes.webname" )
    [[ -z "${WEBNAME}" ]] && WEBNAME="fhem"
    HTTPS=$( echo ${FHEMWEB} | jq -r ".Results[$i].Attributes.HTTPS" )
    [[ -n "${HTTPS}" && "${HTTPS}" == "1" ]] && PROTO=https || PROTO=http

    FHEMWEB_STATE=$( curl \
                      --silent \
                      --insecure \
                      --output /dev/null \
                      --write-out "%{http_code}" \
                      --user-agent 'FHEM-Docker/1.0 Health Check' \
                      "${PROTO}://localhost:${PORT}/${WEBNAME}/healthcheck" )
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
    RET=$( cd /opt/fhem; perl fhem.pl ${TELNETPORT} "{ DockerImageInfo_HealthCheck();; }" 2>/dev/null )
    [ -n "${RET}" ] && RETURN="${RETURN} DockerImageInfo:${RET};" || RETURN="${RETURN} DockerImageInfo:OK;"
  fi

fi

echo -n ${RETURN}
exit ${STATE}
