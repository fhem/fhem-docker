#!/bin/bash
#
#	Credits for the initial script to Joscha Middendorf:
#    https://raw.githubusercontent.com/JoschaMiddendorf/fhem-docker/master/StartAndInitialize.sh

export FHEM_DIR="/opt/fhem"
export LOGFILE="${FHEM_DIR}/log/${LOGFILE:-fhem-%Y-%m.log}"
export PIDFILE="${FHEM_DIR}/log/${PIDFILE:-fhem.pid}"
export SLEEPINTERVAL=0.5
export TIMEOUT="${TIMEOUT:-10}"
export RESTART="${RESTART:-1}"
export CONFIGTYPE="${CONFIGTYPE:-"fhem.cfg"}"
export DNS=$( cat /etc/resolv.conf | grep -m1 nameserver | cut -d " " -f 2 )
export FHEM_UID="${FHEM_UID:-6061}"
export FHEM_GID="${FHEM_GID:-6061}"
export FHEM_CLEANINSTALL=1

if [ -d "/fhem" ]; then
  echo "Preparing initial start:"
  i=1

  [ -s "${FHEM_DIR}/fhem.pl" ] && FHEM_CLEANINSTALL=0

  if [ -s /pre-init.sh ]; then
    echo "$i. Running pre-init script"
    /pre-init.sh
    (( i++ ))
  fi

  if [ "${FHEM_CLEANINSTALL}" = '1' ]; then
    echo "$i. Installing FHEM to /opt/fhem"
    shopt -s dotglob nullglob 2>&1>/dev/null
    mv -f /fhem/* ${FHEM_DIR}/ 2>&1>/dev/null
    cd ${FHEM_DIR} 2>&1>/dev/null
    mv ./controls_fhem.txt ./FHEM/ 2>&1>/dev/null
    perl ./contrib/commandref_modular.pl 2>&1>/dev/null
    cd - 2>&1>/dev/null
  else
    echo "$i. Updating existing FHEM installation in /opt/fhem"
    cp -f /fhem/FHEM/99_DockerImageInfo.pm /opt/fhem/FHEM/
  fi
  (( i++ ))
  rm -rf /fhem/

  echo "$i. Updating fhem.cfg for Docker container compatibility"
  cp -n ${FHEM_DIR}/fhem.cfg ${FHEM_DIR}/fhem.cfg.default
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep 'attr global nofork 0')" ] && echo "attr global nofork 0" >> ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep 'attr global commandref')" ] && echo "attr global commandref modular" >> ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep 'attr global pidfilename')" ] && echo "attr global pidfilename .${PIDFILE#${FHEM_DIR}}" >> ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep 'attr global dnsServer')" ] && echo "attr global dnsServer ${DNS}" >> ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep 'attr global mseclog')" ] && echo "attr global mseclog 1" >> ${FHEM_DIR}/fhem.cfg
  sed -i "s,attr global updateInBackground.*,attr global updateInBackground 1," ${FHEM_DIR}/fhem.cfg
  (( i++ ))

  if [ -s /post-init.sh ]; then
    echo "$i. Running post-init script"
    /post-init.sh
    (( i++ ))
  fi

elif [ ! -s "${FHEM_DIR}/fhem.pl" ]; then
  echo "- ERROR: Unable to find FHEM installation in ${FHEM_DIR}/fhem.pl"
  exit 1
fi

# creating user environment
echo "Preparing user environment ..."
[ ! -s /etc/passwd.orig ] && cp -f /etc/passwd /etc/passwd.orig
[ ! -s /etc/shadow.orig ] && cp -f /etc/shadow /etc/shadow.orig
[ ! -s /etc/group.orig ] && cp -f /etc/group /etc/group.orig
cp -f /etc/passwd.orig /etc/passwd
cp -f /etc/shadow.orig /etc/shadow
cp -f /etc/group.orig /etc/group
groupadd --force --gid ${FHEM_GID} fhem 2>&1>/dev/null
useradd --home /opt/fhem --shell /bin/bash --uid ${FHEM_UID} --no-create-home --no-user-group --non-unique fhem 2>&1>/dev/null
usermod --append --gid ${FHEM_GID} --groups ${FHEM_GID} fhem 2>&1>/dev/null
adduser --quiet fhem bluetooth 2>&1>/dev/null
adduser --quiet fhem dialout 2>&1>/dev/null
adduser --quiet fhem tty 2>&1>/dev/null
chown --recursive --quiet --no-dereference ${FHEM_UID}:${FHEM_GID} /opt/fhem/ 2>&1>/dev/null

# Function to print FHEM log in incremental steps to the docker log.
[ -s "$( date +"$LOGFILE" )" ] && OLDLINES=$( wc -l < "$( date +"$LOGFILE" )" ) || OLDLINES=0
NEWLINES=$OLDLINES
FOUND=false
function PrintNewLines {
  if [ -s "$( date +"$LOGFILE" )" ]; then
  	NEWLINES=$(wc -l < "$(date +"$LOGFILE")")
  	(( OLDLINES <= NEWLINES )) && LINES=$(( NEWLINES - OLDLINES )) || LINES=$NEWLINES
  	tail -n "$LINES" "$(date +"$LOGFILE")"
  	[ -n "$1" ] && grep -q "$1" <(tail -n "$LINES" "$(date +"$LOGFILE")") && FOUND=true || FOUND=false
  	OLDLINES=$NEWLINES
  fi
}

# Docker stop signal handler
function StopFHEM {
	echo -e '\n\nSIGTERM signal received, sending "shutdown" command to FHEM!\n'
	PID=$(<"$PIDFILE")
  su - fhem -c "cd "${FHEM_DIR}"; perl fhem.pl 7072 shutdown"
	echo -e 'Waiting for FHEM process to terminate before stopping container:\n'

  # Wait for FHEM to complete shutdown
	until $FOUND; do
		sleep $SLEEPINTERVAL
      		PrintNewLines "Server shutdown"
	done

  # Wait for FHEM normal process exit
	while ( kill -0 "$PID" 2> /dev/null ); do
		sleep $SLEEPINTERVAL
	done
	PrintNewLines
	echo 'FHEM process terminated, stopping container. Bye!'
	exit 0
}

# Start FHEM
function StartFHEM {
  echo -e '\n\n'

  if [ -s /pre-start.sh ]; then
    echo "Running pre-start script ..."
    /pre-start.sh
  fi

  # Update system environment
  echo 'Preparing configuration ...'
  sed -i "s,attr global dnsServer.*,attr global dnsServer ${DNS}," ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P 'define .+ DockerImageInfo.*')" ] && echo "define DockerImageInfo DockerImageInfo" >> ${FHEM_DIR}/fhem.cfg

  echo 'Starting FHEM ...'
  trap "StopFHEM" SIGTERM
  su - fhem -c "cd "${FHEM_DIR}"; perl fhem.pl "$CONFIGTYPE""
  RET=$?

  # If process was unable to restart,
  # exit the container with error state
  if [ ${RET} -ne 0 ]; then
    echo "Unable to start FHEM process - errorcode $RET"
    exit ${RET}
  fi

  # Wait for FHEM to start up
  until $FOUND; do
  	sleep $SLEEPINTERVAL
        	PrintNewLines "Server started"
  done

  if [ -s /post-start.sh ]; then
    echo "Running post-start script ..."
    /post-start.sh
  fi

  PrintNewLines
}

StartFHEM

# Monitor FHEM during runtime
while true; do

  # FHEM isn't running
	if [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")" 2>&1 >/dev/null; then
		PrintNewLines
		COUNTDOWN="$TIMEOUT"
		echo -ne "\n\nAbrupt daemon termination, starting $COUNTDOWN""s countdown ..."
		while ( [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")" 2>&1 >/dev/null ) && (( COUNTDOWN > 0 )); do
			echo -n " $COUNTDOWN"
			(( COUNTDOWN-- ))
			sleep 1
		done

    # FHEM didn't reappear
    if [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")" 2>&1 >/dev/null; then

      # Container should be stopped
      if [ "$RESTART" == "0" ]; then
        echo -e ' 0\nStopping Container. Bye!\n'
		    exit 1

      # Automatic restart is enabled
      else
        echo -e ' 0\nAutomatic restart ...\n'

        # Cleanup
        if [ -s "$PIDFILE" ]; then
           kill -9 "$(<"$PIDFILE")" 2>&1>/dev/null
           rm -f "$PIDFILE"
        fi

        StartFHEM
      fi

    # FHEM reappeared
		else
			echo -e '\nFHEM process reappeared ...\n'
		fi
	fi

  # Printing log lines in intervalls
	PrintNewLines
	sleep $SLEEPINTERVAL
done
