#!/bin/bash
#
#	Credits for the initial script to Joscha Middendorf:
#    https://raw.githubusercontent.com/JoschaMiddendorf/fhem-docker/master/StartAndInitialize.sh

FHEM_DIR="/opt/fhem"
LOGFILE="${FHEM_DIR}/log/fhem-%Y-%m.log"
PIDFILE="${FHEM_DIR}/log/fhem.pid"
SLEEPINTERVAL=0.5
TIMEOUT="${TIMEOUT:-10}"
RESTART="${RESTART:-1}"
CONFIGTYPE="${CONFIGTYPE:-"fhem.cfg"}"
DNS=$( cat /etc/resolv.conf | grep -m1 nameserver | cut -d " " -f 2 )
FHEM_UID="${FHEM_UID:-6061}"
FHEM_GID="${FHEM_GID:-6061}"

if [ -d "/fhem" ]; then
  echo "Preparing initial start:"
  i=1

  if [ -s /pre-init.sh ]; then
    echo "$i. Running pre-init script"
    /pre-init.sh
    (( i++ ))
  fi

  if [ ! -s "${FHEM_DIR}/fhem.pl" ]; then
    echo "$i. Installing FHEM to /opt/fhem"
    shopt -s dotglob nullglob
    mv -f /fhem/* ${FHEM_DIR}/
    cd ${FHEM_DIR}
    mv ./controls_fhem.txt ./FHEM/
    perl ./contrib/commandref_modular.pl
    cd -
  else
    echo "$i. Updating existing FHEM installation in /opt/fhem"
    cp -f /fhem/FHEM/99_DockerImageInfo.pm /opt/fhem/FHEM/
  fi
  (( i++ ))
  rm -rf /fhem/

  echo "$i. Updating fhem.cfg for Docker container compatibility"
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
groupadd --force --gid ${FHEM_GID} fhem
useradd --home /opt/fhem --shell /bin/bash --uid ${FHEM_UID} --no-create-home --no-user-group --non-unique fhem
usermod --append --gid ${FHEM_GID} --groups ${FHEM_GID} fhem
adduser --quiet fhem bluetooth
adduser --quiet fhem dialout
adduser --quiet fhem tty
chown --recursive --quiet --no-dereference ${FHEM_UID}:${FHEM_GID} /opt/fhem/

# Function to print FHEM log in incremental steps to the docker log.
[ -s "$( date +"$LOGFILE" )" ] && OLDLINES=$( wc -l < "$( date +"$LOGFILE" )" ) || OLDLINES=0
NEWLINES=$OLDLINES
FOUND=false
function PrintNewLines {
      	NEWLINES=$(wc -l < "$(date +"$LOGFILE")")
      	(( OLDLINES <= NEWLINES )) && LINES=$(( NEWLINES - OLDLINES )) || LINES=$NEWLINES
      	tail -n "$LINES" "$(date +"$LOGFILE")"
      	[ -n "$1" ] && grep -q "$1" <(tail -n "$LINES" "$(date +"$LOGFILE")") && FOUND=true || FOUND=false
      	OLDLINES=$NEWLINES
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
	if [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")"; then
		PrintNewLines
		COUNTDOWN="$TIMEOUT"
		echo -ne "\n\nAbrupt daemon termination, starting $COUNTDOWN""s countdown ..."
		while ( [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")" ) && (( COUNTDOWN > 0 )); do
			echo -n " $COUNTDOWN"
			(( COUNTDOWN-- ))
			sleep 1
		done

    # FHEM didn't reappear
    if [ ! -s "$PIDFILE" ] || ! kill -0 "$(<"$PIDFILE")"; then

      # Container should be stopped
      if [ "$RESTART" == "0" ]; then
        echo -e ' 0\n\nStopping Container. Bye!'
		    exit 1

      # Automatic restart is enabled
      else
        echo -e ' 0\n\nAutomatic restart ...\n'

        # Cleanup
        if [ -s "$PIDFILE" ]; then
           kill -9 "$(<"$PIDFILE")"
           rm -f "$PIDFILE"
        fi

        StartFHEM
      fi

    # FHEM reappeared
		else
			echo 'FHEM process reappeared ...'
		fi
	fi

  # Printing log lines in intervalls
	PrintNewLines
	sleep $SLEEPINTERVAL
done
