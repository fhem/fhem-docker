#!/bin/bash


#--- Constants -------------------------------------------------------------------------------------------------------

declare -r PID_FILE="/var/run/health-check.pid"
declare -r URL_FILE="/tmp/health-check.urls"
declare -r RESULT_FILE="/tmp/health-check.result"


#--- Internal global -------------------------------------------------------------------------------------------------

declare -i gRetVal=0;
declare    gRetMessage="";
declare -i gSuccessCnt=0;
declare -i gFailedCnt=0;


#====================================================================================================================-
#--- Functions -------------------------------------------------------------------------------------------------------

# Handler function for actually stopping this script. Called either by
#  - "exit" was called somewhere in the script
#  - SIGTERM is received
#
# Usage: trapExitHandler
# Global vars: gRetMessage
#              gSuccessCnt
#              gFailedCnt
#              RESULT_FILE
#              PID_FILE
#
function trapExitHandler() {
  local -i exitVal=$?  # when "exit" was called, this holds the return value
  trap - SIGTERM EXIT  # Avoid multiple calls to handler
  echo "$gRetMessage"
  if (($exitVal == 0)) ; then
    echo -n "ok ($gSuccessCnt successful,  $gFailedCnt failed)" > $RESULT_FILE
  else
    echo -n "ERROR ($gSuccessCnt successful,  $gFailedCnt failed)" > $RESULT_FILE
  fi
  exit $exitVal
}


#====================================================================================================================-
#--- Main script -----------------------------------------------------------------------------------------------------


(
  trap trapExitHandler SIGTERM EXIT
  
  # Wait 3 seconds for lock on $PID_FILE (fd 212), exit on failure
  flock -x -w 3 212 || { echo "Instance already running, aborting another one" ; exit 1; } 

  [ -e $URL_FILE ] || { gRetMessage="Cannot read url file $URL_FILE" ; exit 1; }
  while IFS= read -r fhemUrl; do
    fhemwebState=$( curl \
                      --connect-timeout 5 \
                      --max-time 8 \
                      --silent \
                      --insecure \
                      --output /dev/null \
                      --write-out "%{http_code}" \
                      --user-agent 'FHEM-Docker/1.0 Health Check' \
                      "${fhemUrl}" )
    if [ $? -ne 0 ] ||
      [ -z "${fhemwebState}" ] ||
      [ "${fhemwebState}" == "000" ] ||
      [ "${fhemwebState:0:1}" == "5" ]; then
      gRetMessage="$gRetMessage $fhemUrl: FAILED ($fhemwebState);"
      gRetVal=1
      ((gFailedCnt++))
    else
      gRetMessage="$gRetMessage $fhemUrl: OK;"
      ((gSuccessCnt++))
    fi
  done < $URL_FILE

  exit $gRetVal
) 212>${PID_FILE}

