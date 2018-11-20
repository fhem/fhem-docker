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
export TELNETPORT="${TELNETPORT:-7072}"
export CONFIGTYPE="${CONFIGTYPE:-"fhem.cfg"}"
export DNS=$( cat /etc/resolv.conf | grep -m1 nameserver | cut -d " " -f 2 )
export FHEM_UID="${FHEM_UID:-6061}"
export FHEM_GID="${FHEM_GID:-6061}"
export FHEM_CLEANINSTALL=1

[ ! -f /image_info.EMPTY ] && touch /image_info.EMPTY

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
    echo "$i. Installing FHEM to ${FHEM_DIR}"
    shopt -s dotglob nullglob 2>&1>/dev/null
    mv -f /fhem/* ${FHEM_DIR}/ 2>&1>/dev/null
    cd ${FHEM_DIR} 2>&1>/dev/null
    mv ./controls_fhem.txt ./FHEM/ 2>&1>/dev/null
    perl ./contrib/commandref_modular.pl 2>&1>/dev/null
    cp -f ./fhem.cfg ./fhem.cfg.default
    (( i++ ))

    echo "$i. Patching fhem.cfg default configuration"
    [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global dnsServer')" ] && echo "attr global dnsServer ${DNS}" >> ${FHEM_DIR}/fhem.cfg
    [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global commandref')" ] && echo "attr global commandref modular" >> ${FHEM_DIR}/fhem.cfg
    [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global mseclog')" ] && echo "attr global mseclog 1" >> ${FHEM_DIR}/fhem.cfg

    cd - 2>&1>/dev/null
  else
    echo "$i. Updating existing FHEM installation in ${FHEM_DIR}"
    cp -f ${FHEM_DIR}/fhem.cfg ${FHEM_DIR}/fhem.cfg.bak
    cp -f /fhem/FHEM/99_DockerImageInfo.pm ${FHEM_DIR}/FHEM/
  fi
  (( i++ ))

  rm -rf /fhem/

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
useradd --home ${FHEM_DIR} --shell /bin/bash --uid ${FHEM_UID} --no-create-home --no-user-group --non-unique fhem 2>&1>/dev/null
usermod --append --gid ${FHEM_GID} --groups ${FHEM_GID} fhem 2>&1>/dev/null
adduser --quiet fhem bluetooth 2>&1>/dev/null
adduser --quiet fhem dialout 2>&1>/dev/null
adduser --quiet fhem tty 2>&1>/dev/null
chown --recursive --quiet --no-dereference ${FHEM_UID}:${FHEM_GID} ${FHEM_DIR}/ 2>&1>/dev/null

# SSH key: Ed25519
if [ ! -s ${FHEM_DIR}/.ssh/id_ed25519 ]; then
  echo -e "  - Generating SSH Ed25519 client certificate for user 'fhem' ..."
  rm -f ${FHEM_DIR}/.ssh/id_ed25519*
  ssh-keygen -t ed25519 -f ${FHEM_DIR}/.ssh/id_ed25519 -q -N "" -o -a 100
fi
chmod -v 600 ${FHEM_DIR}/.ssh/id_ed25519
chmod -v 644 ${FHEM_DIR}/.ssh/id_ed25519.pub
chown fhem.root ${FHEM_DIR}/.ssh/id_ed25519*

# SSH key: RSA
if [ ! -s ${FHEM_DIR}/.ssh/id_rsa ]; then
  echo -e "  - Generating SSH RSA client certificate for user 'fhem' ..."
  rm -f ${FHEM_DIR}/.ssh/id_rsa*
  ssh-keygen -t rsa -f ${FHEM_DIR}/.ssh/id_rsa -q -N "" -o -a 100
fi
chmod -v 600 ${FHEM_DIR}/.ssh/id_rsa
chmod -v 644 ${FHEM_DIR}/.ssh/id_rsa.pub
chown fhem.root ${FHEM_DIR}/.ssh/id_rsa*

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
  #
  echo 'Preparing configuration ...'

  # Mandatory
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^define .+ DockerImageInfo.*')" ] && echo "define DockerImageInfo DockerImageInfo" >> ${FHEM_DIR}/fhem.cfg
  sed -i "s,attr global nofork.*,attr global nofork 0," ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global nofork')" ] && echo "attr global nofork 0" >> ${FHEM_DIR}/fhem.cfg
  sed -i "s,attr global updateInBackground.*,attr global updateInBackground 1," ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global updateInBackground')" ] && echo "attr global updateInBackground 1" >> ${FHEM_DIR}/fhem.cfg
  sed -i "s,attr global pidfilename.*,attr global pidfilename .${PIDFILE#${FHEM_DIR}}," ${FHEM_DIR}/fhem.cfg
  [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^attr global pidfilename')" ] && echo "attr global pidfilename .${PIDFILE#${FHEM_DIR}}" >> ${FHEM_DIR}/fhem.cfg

  ## Find Telnet access details
  if [ -z "$(cat ${FHEM_DIR}/fhem.cfg | grep -P "^define .* telnet ${TELNETPORT}")" ]; then
    CUSTOMPORT="$(cat ${FHEM_DIR}/fhem.cfg | grep -P '^define telnetPort telnet ' | cut -d ' ' -f 4)"
    if [ -z "${CUSTOMPORT}"]; then
      echo "define telnetPort telnet ${TELNETPORT}" >> ${FHEM_DIR}/fhem.cfg
    else
      TELNETPORT=${CUSTOMPORT}
    fi
  fi
  TELNETDEV="$(cat ${FHEM_DIR}/fhem.cfg | grep -P "^define .* telnet ${TELNETPORT}" | cut -d " " -f 2)"
  TELNETALLOWEDDEV="$(cat ${FHEM_DIR}/fhem.cfg | grep -P "^attr .* validFor .*${TELNETDEV}.*" | cut -d " " -f 2)"

  ## Enforce local telnet access w/o password
  if [ -n "$(cat ${FHEM_DIR}/fhem.cfg | grep -P "^attr ${TELNETALLOWEDDEV} password.*")" ]; then
    if [ -n "$(cat ${FHEM_DIR}/fhem.cfg | grep -P "^attr ${TELNETALLOWEDDEV} globalpassword.*")" ]; then
      echo "  - Removed local password from Telnet allowed device '${TELNETALLOWEDDEV}'"
      sed -i "/attr ${TELNETALLOWEDDEV} password/d" ${FHEM_DIR}/fhem.cfg
    else
      echo "  - Re-defined local password of Telnet allowed device '${TELNETALLOWEDDEV}' to global password"
      sed -i "s,attr ${TELNETALLOWEDDEV} password,attr ${TELNETALLOWEDDEV} globalpassword," ${FHEM_DIR}/fhem.cfg
    fi
  fi

  # Optional
  sed -i "s,attr global dnsServer.*,attr global dnsServer ${DNS}," ${FHEM_DIR}/fhem.cfg

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
