#!/bin/bash
#
#  Credits for the initial process handling to Joscha Middendorf:
#    https://raw.githubusercontent.com/JoschaMiddendorf/fhem-docker/master/StartAndInitialize.sh
#  Credits for the original entry script to all authors of
#    https://github.com/fhem/fhem-docker/blob/dev/src/entry.sh
#
# TODO / possible improvements:
#   - Make a single, more generic function out of the printf*() ones.
#   - Consider putting all the initial setup into it's own file
#

#--- Global behaviour settings ---------------------------------------------------------------------------------------

set -u            # Make use of unbound variables an error
set -o pipefail   # Distribute an error exit status through the whole pipe


#--- Constants -------------------------------------------------------------------------------------------------------

declare -r  FHEM_DIR="/opt/fhem"
declare -ri gEnableDebug=0


#--- Exported environment settings for all parts of the script -------------------------------------------------------
#--- But see specific exports for FHEM later -------------------------------------------------------------------------

export TZ="${TZ:-Europe/Berlin}"


#--- Environment variables, configurable from outside ----------------------------------------------------------------

declare -ri TIMEOUT_STOPPING=${TIMEOUT_STOPPING:-30}
declare -ri TIMEOUT_STARTING=${TIMEOUT_STARTING:-60}
declare -ri TIMEOUT_REAPPEAR=${TIMEOUT_REAPPEAR:-15}

declare -r  RESTART="${RESTART:-1}"
declare -r  CONFIGTYPE="${CONFIGTYPE:-"fhem.cfg"}"

declare -r  UMASK="${UMASK:-0037}"

declare -ri FHEM_UID="${FHEM_UID:-6061}"
declare -ri FHEM_GID="${FHEM_GID:-6061}"
declare -r  FHEM_PERM_DIR="${FHEM_PERM_DIR:-0750}"
declare -r  FHEM_PERM_FILE="${FHEM_PERM_FILE:-0640}"

declare -ri BLUETOOTH_GID="${BLUETOOTH_GID:-6001}"
declare -ri GPIO_GID="${GPIO_GID:-6002}"
declare -ri I2C_GID="${I2C_GID:-6003}"

declare -r  APT_PKGS="${APT_PKGS:-}"
declare -r  CPAN_PKGS="${CPAN_PKGS:-}"
declare -r  PIP_PKGS="${PIP_PKGS:-}"
declare -r  NPM_PKGS="${NPM_PKGS:-}"


#--- Internal global -------------------------------------------------------------------------------------------------

# we run in standard locale environment to ensure proper behaviour
declare -r gSavedUserLcAll="${LC_ALL:-}"
LC_ALL=C 

declare -i gAptUpdateHasRun
declare    gCurrentTailFile=""
declare -i gCurrentTailPid=0
declare -i gRunMainLoop


#====================================================================================================================-
#--- Generic functions -----------------------------------------------------------------------------------------------

# Wait for a process to end, optionally limited by a timeout.
#
# Usage: waitForPidToTerminate pid [timeout]
# Parameters:  pid          PID to wait for termination
#              timeout      Maximum time to wait for termination, default: indefinetly
# Returns:     0:           Process terminated
#              124:         Timeout occured, process NOT terminated
#              else:        Any other error
#
function waitForPidToTerminate() {
  local -i inPid="$1"
  local -i inTimeout=${2:-0}  # Wait indefinitely is default
  timeout $inTimeout tail --pid=$inPid -f /dev/null 2> /dev/null
}


# Searches for a text being newly appended to a file, optionally limited by a timeout.
# Robust against truncation and (initial) non-existance of the file.
#
# Usage: waitForTextInFile file searchText [timeout]
# Parameters:  file         File to search in
#              searchText   Text to look for
#              timeout      Maximum time to look for text to appear, default: indefinetly
# Returns:     0:     Text found in file
#              124:   Timeout occured
#              else:  Any other error
#
function waitForTextInFile() {
  local    inFile="$1"
  local    inSearchText="$2"
  local -i inTimeout=${3:-0}  # Wait indefinitely is default
  local    bashCmd="tail -n0 --retry -f '$inFile' 2>/dev/null | sed -e '/$inSearchText/ q' > /dev/null"
  timeout $inTimeout bash -c "$bashCmd"
}


# Prints content added to a file to stdout while running in the background.
# Robust against truncation and (initial) non-existance of the file.
#
# Usage: tailFileToConsoleStart file [-b]
# Parameters:  file   File to print
#              -b     Print file from begin, otherwise start at current end
# Global vars: gCurrentTailFile
#              gCurrentTailPid
#
function tailFileToConsoleStart() {
  local inLogFile="$1"
  local inFlag="${2:-}"
  tailFileToConsoleStop
  if [ "$inFlag" == "-b" ]; then
    { tail -n +0 --retry -s 0.1 -f "$inLogFile" 2>/dev/null | grep --line-buffered '^.*$' & } 2>/dev/null # grep is used for line buffering as tail lost this option.
  else
    { tail -n0 --retry -s 0.1 -f "$inLogFile" 2>/dev/null | grep --line-buffered '^.*$' & } 2>/dev/null # grep is used for line buffering as tail lost this option.
  fi
  gCurrentTailFile="$inLogFile"
  gCurrentTailPid=$!
}


# Stop printing content from a file.
#
# Usage: tailFileToConsoleStop
# Global vars: gCurrentTailFile
#              gCurrentTailPid
#
function tailFileToConsoleStop() {
  (( gCurrentTailPid != 0 ))  && kill $gCurrentTailPid 2>/dev/null
  gCurrentTailFile=""
  gCurrentTailPid=0
}


# Wrapper around printf for debug output
#
# Usage: printfDebug ...
# Global vars: gLastPrintfDebugNewline
#
function printfDebug() {
  (( gEnableDebug == 0 )) && return
  local -i retval
  if [ "${gLastPrintfDebugNewline:-1}" != 0 ]; then
    printf "$@" | sed -e 's/^/DEBUG: '${FUNCNAME[1]}': /' >&2
    retval=$?
  else
    printf "$@" | sed -e '1b' -e 's/^/DEBUG: '${FUNCNAME[1]}'/' >&2  # skip prefixing the first line, as the last line before did not end in a newline
    retval=$?
  fi
  if [ "$(printf "$@" 2>/dev/null | tail -c 1)" == "" ]; then gLastPrintfDebugNewline=1; else gLastPrintfDebugNewline=0; fi
  return $retval
}


# Wrapper around printf for information output
#
# Usage: printfInfo ...
# Global vars: gLastPrintfErrNewline
#
function printfInfo() {
  local -i retval
  if [ "${gLastPrintfInfoNewline:-1}" != 0 ]; then
    printf "$@" | sed -e 's/^/INFO: /'
    retval=$?
  else
    printf "$@" | sed -e '1b' -e 's/^/INFO: /'  # skip prefixing the first line, as the last line before did not end in a newline
    retval=$?
  fi
  if [ "$(printf "$@" 2>/dev/null | tail -c 1)" == "" ]; then gLastPrintfInfoNewline=1; else gLastPrintfInfoNewline=0; fi
  return $retval
}


# Wrapper around printf for error output
#
# Usage: printfErr ...
# Global vars: gLastPrintfErrNewline
#
function printfErr() {
  local -i retval
  if [ "${gLastPrintfErrNewline:-1}" != 0 ]; then
    printf "$@" | sed -e 's/^/ERROR: /'
    retval=$?
  else
    printf "$@" | sed -e '1b' -e 's/^/ERROR: /'  # skip prefixing the first line, as the last line before did not end in a newline
    retval=$?
  fi
  if [ "$(printf "$@" 2>/dev/null | tail -c 1)" == "" ]; then gLastPrintfErrNewline=1; else gLastPrintfErrNewline=0; fi
  return $retval
}


#====================================================================================================================-
#--- FHEM utility functions ------------------------------------------------------------------------------------------

# Prepend a relative path with the FHEM_DIR.
# Works correctly still when the given path is already prepended by FHEM_DIR
#
# Usage: prependFhemDirPath path
# Parameters:  path         Path to prepend
# Global vars: FHEM_DIR
#
function prependFhemDirPath() {
  realpath -ms "$(echo "$1" | sed -e 's!^'${FHEM_DIR}/'!!; s!^!'${FHEM_DIR}/'!')"
}


# Get the value of a global attribute from the FHEM config file.
#
# Usage: getGlobalAttr file attribute
# Parameters:  file         File FHEM config file
#              attribute    Attribute to look for
# Returns:     0:     Attribute found and value sent to stdout
#              else:  An error occured, e.g. attribute not in file
#
function getGlobalAttr() {
  local -r inCfgFile="$1"
  local -r inAttr="$2"
  awk 'BEGIN{ retVal=1} /^[[:space:]]*attr[[:space:]]+global[[:space:]]+'$inAttr'[[:space:]]+/{ print $4; retVal=0; } END{ exit retVal}' "$inCfgFile"
}


# Collect information about the docker environment
#
# Usage: collectDockerInfo
# Global vars: DOCKER_PRIVILEGED
#              DOCKER_GW
#              DOCKER_HOST
#              DOCKER_HOSTNETWORK
#
function collectDockerInfo() {
  if ip link add dummy0 type dummy >/dev/null 2>&1 ; then
    ip link delete dummy0 >/dev/null 2>&1
    export DOCKER_PRIVILEGED=1
  else
    export DOCKER_PRIVILEGED=0
  fi
  echo $DOCKER_PRIVILEGED > /docker.privileged

  cat /proc/self/cgroup | grep "memory:" | cut -d "/" -f 3 > /docker.container.id
  captest --text | grep -P "^Effective:" | cut -d " " -f 2- | sed "s/, /\n/g" | sort | sed ':a;N;$!ba;s/\n/,/g' > /docker.container.cap.e
  captest --text | grep -P "^Permitted:" | cut -d " " -f 2- | sed "s/, /\n/g" | sort | sed ':a;N;$!ba;s/\n/,/g' > /docker.container.cap.p
  captest --text | grep -P "^Inheritable:" | cut -d " " -f 2- | sed "s/, /\n/g" | sort | sed ':a;N;$!ba;s/\n/,/g' > /docker.container.cap.i

  export DOCKER_GW="${DOCKER_GW:-$(netstat -r -n | grep ^0.0.0.0 | awk '{print $2}')}"
  export DOCKER_HOST="${DOCKER_HOST:-${DOCKER_GW}}"
  export DOCKER_HOSTNETWORK=0
  if ip -4 addr show docker0 >/dev/null 2>&1 ; then
    export DOCKER_HOSTNETWORK=1
    unset DOCKER_HOST
    unset DOCKER_GW
  fi
  echo $DOCKER_HOSTNETWORK > /docker.hostnetwork
}


# Determine global logfile
#
# Usage: setGlobal_LOGFILE
# Global vars: CONFIGTYPE
#              LOGFILE
#
function setGlobal_LOGFILE() {
  local -r defaultLogfile="./log/fhem-%Y-%m-%d.log"

  [ -n "${LOGFILE+x}" ] &&                            { LOGFILE=$(prependFhemDirPath "$LOGFILE"); return; }          # LOGFILE already set => use this
  [ "${CONFIGTYPE}" == "configDB" ] &&                { LOGFILE=$(prependFhemDirPath "$defaultLogfile"); return; }   # config is done inside DB => default

  local cfgFile="$(prependFhemDirPath "${CONFIGTYPE}")"
  [ -r "$cfgFile" ] ||                                { LOGFILE=$(prependFhemDirPath "$defaultLogfile"); return; }   # configfile not readable => default

  local cfgLogDef="$(getGlobalAttr "$cfgFile" "logfile" )"
  [ -n "$cfgLogDef"] &&                               { LOGFILE=$(prependFhemDirPath "$cfgLogDef"); return; }        # found something in the configfile => use this

  LOGFILE=$(prependFhemDirPath "$defaultLogfile")
}


# Determine PID file
#
# Usage: setGlobal_PIDFILE
# Global vars: CONFIGTYPE
#              PIDFILE
#
function setGlobal_PIDFILE() {
  local -r defaultPidfile="./log/fhem.pid"

  [ -n "${PIDFILE+x}" ] &&                            { PIDFILE=$(prependFhemDirPath "$PIDFILE"); return; }          # PIDFILE already set => use this
  [ "${CONFIGTYPE}" == "configDB" ] &&                { PIDFILE=$(prependFhemDirPath "$defaultPidfile"); return; }   # config is done inside DB => default

  local cfgFile="$(prependFhemDirPath "${CONFIGTYPE}")"
  [ -r "$cfgFile" ] ||                                { PIDFILE=$(prependFhemDirPath "$defaultPidfile"); return; }   # configfile not readable => default

  local cfgPidDef="$(getGlobalAttr "$cfgFile" "pidfilename" )"
  [ -n "$cfgPidDef"] &&                               { PIDFILE=$(prependFhemDirPath "$cfgPidDef"); return; }        # found something in the configfile => use this

  PIDFILE=$(prependFhemDirPath "$defaultPidfile")
}


# Run a container-specific pre/post script
#
# Usage: runScript scriptFile
# Parameters:  scriptFile   The script ro execute
#
function runScript() {
  local inScript="$1"
  [ -s "$inScript" ] || return 1
  printfInfo 'Running "%s" script\n' "$inScript"
  [ -x "$inScript" ] || chmod 755 "$inScript"
  DEBIAN_FRONTEND=noninteractive LC_ALL=C "$inScript"
  local -i retVal=$?
  (( retVal != 0 )) && printfErr 'Script "%s" returned with error code %d\n' "$inScript" $retVal
  return $retVal
}


# Run apt to install packages and log output to a file
# Calls "apt-get update" only the first time or when reset by gAptUpdateHasRun=0
#
# Usage: aptInstall message logfile package(s)
# Parameters:  message       Message on console before calling apt-get
#              logfile       Where to write the apt's output to
#              package(s)    Packages to install
# Global vars: gAptUpdateHasRun
#
function aptInstall() {
  local inMessage="$1" ; shift 1
  local inLogFile="$1" ; shift 1
  [ -n "$@" ] || return
  printfInfo "${inMessage}\n"
  if [ "${gAptUpdateHasRun:-0}" == 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get update >>"$inLogFile" 2>&1
    gAptUpdateHasRun=1
  fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >>"$inLogFile" 2>&1
  hash -r   # make sure that newly installed commands are on our PATH
}


#====================================================================================================================-
#--- FHEM setup functions --------------------------------------------------------------------------------------------

# First time installation of packages requested by environment variables
#
# Usage: initialPackageSetup 
# Global vars: APT_PKGS
#              CPAN_PKGS
#              PIP_PKGS
#              NPM_PKGS
#
function initialPackageSetup() {
  aptInstall "Adding custom APT packages to container" "/pkgs.apt" ${APT_PKGS}

  if [ -n "${CPAN_PKGS}" ]; then
    if [ ! -e /usr/bin/cpanm ] && [ ! -e /usr/local/bin/cpanm ]; then
      aptInstall "Installing cpanminus" "/pkgs.cpanm" cpanminus
    fi
    printfInfo "Adding custom Perl modules to container\n"
    cpanm --notest ${CPAN_PKGS} >>/pkgs.cpanm 2>&1
  fi

  if [ -n "${PIP_PKGS}" ]; then
    if [ ! -e /usr/bin/pip3 ]; then
      aptInstall "Installing pip3" "/pkgs.pip" python3 python3-pip
    fi
    printInfo "Adding custom Python modules to container\n"
    pip3 install ${PIP_PKGS} >>/pkgs.pip 2>&1
  fi

  if [ "${NPM_PKGS}" != '' ]; then
    if [ ! -e /usr/bin/npm ]; then
      local mType="$(uname -m)"
      [ "${mType}" == 'arm32v5' ] && { printfErr "Missing Node.js for ${mType} platform cannot be installed automatically\n"; exit 1; }
      printfInfo "Adding APT sources for Node.js\n"
      if [ "${mType}" == "i386" ]; then
        curl -fsSL https://deb.nodesource.com/setup_8.x | bash - >>/pkgs.npm 2>&1
      else
        curl -fsSL https://deb.nodesource.com/setup_14.x | bash - >>/pkgs.npm 2>&1
      fi
      gAptUpdateHasRun=0  # After calling npm install scripts enfore running apt update
      aptInstall "Installing Node.js" "/pkgs.npm" nodejs 
    fi
    printfInfo "Adding custom Node.js packages to container\n"
    npm install -g --unsafe-perm --production ${NPM_PKGS} >>/pkgs.npm 2>&1
  fi
}


# Do a (initial) clean install of FHEM
#
# Usage: fhemCleanInstall
# Global vars: FHEM_DIR
#
function fhemCleanInstall() {
  local -r fhemCfgFile=${FHEM_DIR}/fhem.cfg

  printfInfo "Installing FHEM to ${FHEM_DIR}\n"

  shopt -s dotglob nullglob 2>&1>/dev/null
  mv -f /fhem/* ${FHEM_DIR}/ 2>&1>/dev/null
  echo 'http://fhem.de/fhemupdate/controls_fhem.txt' > ${FHEM_DIR}/FHEM/controls.txt
  mv ${FHEM_DIR}/controls_fhem.txt ${FHEM_DIR}/FHEM/ 2>&1>/dev/null
  ( cd ${FHEM_DIR} ; perl ./contrib/commandref_modular.pl 2>&1>/dev/null )
  cp -f $fhemCfgFile ${FHEM_DIR}/fhem.cfg.default

  printfInfo "  Patching fhem.cfg default configuration\n"
  local -r  myDns=$( cat /etc/resolv.conf | grep -m1 nameserver | sed -e 's/^nameserver[ \t]*//' )
  getGlobalAttr "${FHEM_DIR}/fhem.cfg" "dnsServer"  >/dev/null || echo "attr global dnsServer ${myDns}" >> ${FHEM_DIR}/fhem.cfg
  getGlobalAttr "${FHEM_DIR}/fhem.cfg" "commandref" >/dev/null || echo "attr global commandref modular" >> ${FHEM_DIR}/fhem.cfg
  getGlobalAttr "${FHEM_DIR}/fhem.cfg" "mseclog"    >/dev/null || echo "attr global mseclog 1"          >> ${FHEM_DIR}/fhem.cfg

  printfInfo  "  Adding pre-defined devices to fhem.cfg\n"

  cat >> $fhemCfgFile <<- END_OF_INLINE

define DockerImageInfo DockerImageInfo
attr DockerImageInfo alias Docker Image Info
attr DockerImageInfo devStateIcon ok:security@green Initialized:system_fhem_reboot@orange .*:message_attention@red
attr DockerImageInfo group System
attr DockerImageInfo icon docker
attr DockerImageInfo room System
define fhemServerApt AptToDate localhost
attr fhemServerApt alias System Update Status
attr fhemServerApt devStateIcon system.updates.available:security@red system.is.up.to.date:security@green:repoSync .*in.progress:system_fhem_reboot@orange errors:message_attention@red
attr fhemServerApt group Update
attr fhemServerApt icon debian
attr fhemServerApt room System
END_OF_INLINE

  if [ -e /usr/bin/npm ]; then
    cat >> $fhemCfgFile <<- END_OF_INLINE

define fhemServerNpm npmjs localhost
attr fhemServerNpm alias Node.js Package Update Status
attr fhemServerNpm devStateIcon npm.updates.available:security@red:outdated npm.is.up.to.date:security@green:outdated .*npm.outdated.*in.progress:system_fhem_reboot@orange .*in.progress:system_fhem_update@orange warning.*:message_attention@orange error.*:message_attention@red
attr fhemServerNpm group Update
attr fhemServerNpm icon npm-old
attr fhemServerNpm room System
END_OF_INLINE
  fi

  if [ -e /usr/bin/cpanm ] || [ -e /usr/local/bin/cpanm ]; then
    cat >> $fhemCfgFile <<- END_OF_INLINE

define fhemInstaller Installer
attr fhemInstaller alias FHEM Installer Status
attr fhemInstaller devStateIcon .*updates.available:security@red:outdated up.to.date:security@green:outdated .*outdated.*in.progress:system_fhem_reboot@orange .*in.progress:system_fhem_update@orange warning.*:message_attention@orange error.*:message_attention@red
attr fhemInstaller group Update
attr fhemInstaller icon system_fhem
attr fhemInstaller room System
END_OF_INLINE
  fi

  printfInfo "Installing FHEM done\n"
}


# Update an existing FHEM installation
#
# Usage: fhemUpdateInstall
# Global vars: FHEM_DIR
#              CONFIGTYPE
#
function fhemUpdateInstall() {
  printfInfo "Updating existing FHEM installation in ${FHEM_DIR}\n"
  [ -s ${FHEM_DIR}/${CONFIGTYPE} ] && cp -f ${FHEM_DIR}/${CONFIGTYPE} ${FHEM_DIR}/${CONFIGTYPE}.bak
  cp -f /fhem/FHEM/99_DockerImageInfo.pm ${FHEM_DIR}/FHEM/
}


# Function collecting all activities for the initial setup, including running pre/post scripts
#
# Usage: initialContainerSetup
# Global vars: FHEM_DIR
#
function initialContainerSetup() {
  [ -d "/fhem" ] || return   # /fhem signals that the container is brand new. It holds the default installation that is moved later.
  local -i isFhemCleanInstall
  [ -s "${FHEM_DIR}/fhem.pl" ] && isFhemCleanInstall=0 || isFhemCleanInstall=1

  printfInfo "Preparing initial container setup\n"

  runScript "/pre-init.sh"
  runScript "/docker/pre-init.sh"

  initialPackageSetup

  if (( isFhemCleanInstall == 0 )); then
    fhemUpdateInstall
  else 
    fhemCleanInstall
  fi

  runScript "/post-init.sh"
  runScript "/docker/post-init.sh"

  rm -rf /fhem/
  printfInfo "Initial container setup done\n"
}


# Function collecting all activities for preparing the fhem user environment
#
# Usage: prepareFhemUser
# Global vars: lots of (tbd)
#
function prepareFhemUser() {
  printfInfo "Preparing user environment\n"

  [ ! -e /etc/passwd.orig ] && cp -f /etc/passwd /etc/passwd.orig
  [ ! -e /etc/shadow.orig ] && cp -f /etc/shadow /etc/shadow.orig
  [ ! -e /etc/group.orig ]  && cp -f /etc/group /etc/group.orig
  cp -f /etc/passwd.orig /etc/passwd
  cp -f /etc/shadow.orig /etc/shadow
  cp -f /etc/group.orig /etc/group

  printfInfo "Creating group 'fhem' with GID ${FHEM_GID}\n"
  groupadd --force --gid ${FHEM_GID} --non-unique fhem 2>&1>/dev/null

  printfInfo "Enforcing GID for group 'bluetooth' to ${BLUETOOTH_GID}\n"
  sed -i "s/^bluetooth\:.*/bluetooth\:x\:${BLUETOOTH_GID}/" /etc/group

  printfInfo "Creating user 'fhem' with UID ${FHEM_UID}\n"
  useradd --home ${FHEM_DIR} --shell /bin/bash --uid ${FHEM_UID} --no-create-home --no-user-group --non-unique fhem 2>&1>/dev/null
  usermod --append --gid ${FHEM_GID} --groups ${FHEM_GID} fhem 2>&1>/dev/null
  adduser --quiet fhem audio 2>&1>/dev/null
  adduser --quiet fhem bluetooth 2>&1>/dev/null
  adduser --quiet fhem dialout 2>&1>/dev/null
  adduser --quiet fhem mail 2>&1>/dev/null
  adduser --quiet fhem tty 2>&1>/dev/null
  adduser --quiet fhem video 2>&1>/dev/null

  printfInfo "Creating log directory %s\n" "${LOGFILE%/*}"
  mkdir -p "${LOGFILE%/*}"

  printfInfo "Creating PID directory %s\n" "${PIDFILE%/*}"
  mkdir -p "${PIDFILE%/*}"

  printfInfo "Enforcing user and group ownership for ${FHEM_DIR} to fhem:fhem\n"
  chown --recursive --quiet --no-dereference ${FHEM_UID}:${FHEM_GID} ${FHEM_DIR}/ 2>&1>/dev/null
  chown --recursive --quiet --no-dereference ${FHEM_UID}:${FHEM_GID} ${LOGFILE%/*}/ 2>&1>/dev/null

  printfInfo "Enforcing file and directory permissions for ${FHEM_DIR} \n"
  find ${FHEM_DIR}/ -type d -exec chmod --quiet ${FHEM_PERM_DIR} {} \;
  chmod --quiet go-w ${FHEM_DIR}
  find ${FHEM_DIR}/ -type f -exec chmod --quiet ${FHEM_PERM_FILE} {} \;
  find ${FHEM_DIR}/ -type f -name '*.pl' -exec chmod --quiet u+x {} \;
  find ${FHEM_DIR}/ -type f -name '*.py' -exec chmod --quiet u+x {} \;
  find ${FHEM_DIR}/ -type f -name '*.sh' -exec chmod --quiet u+x {} \;
  find ${FHEM_DIR}/ -path '*/bin/*' -type f -exec chmod --quiet u+x {} \;
  find ${FHEM_DIR}/ -path '*/sbin/*' -type f -exec chmod --quiet u+x {} \;
  find ${FHEM_DIR}/ -path '*/*script*/*' -type f -exec chmod --quiet u+x {} \;

  printfInfo "Correcting group ownership for /dev/tty* \n"
  find /dev/ -regextype sed -regex ".*/tty[0-9]*" -exec chown --recursive --quiet --no-dereference .tty {} \; 2>/dev/null
  find /dev/ -name "ttyS*" -exec chown --recursive --quiet --no-dereference .dialout {} \; 2>/dev/null
  find /dev/ -name "ttyACM*" -exec chown --recursive --quiet --no-dereference .dialout {} \; 2>/dev/null
  find /dev/ -name "ttyUSB*" -exec chown --recursive --quiet --no-dereference .dialout {} \; 2>/dev/null
  find /dev/ -regextype sed -regex ".*/tty[0-9]*" -exec chmod --recursive --quiet g+w {} \; 2>/dev/null
  find /dev/ -name "ttyS*" -exec chmod --recursive --quiet g+rw {} \; 2>/dev/null
  find /dev/ -name "ttyACM*" -exec chmod --recursive --quiet g+rw {} \; 2>/dev/null
  find /dev/ -name "ttyUSB*" -exec chmod --recursive --quiet g+rw {} \; 2>/dev/null

  if [[ -d /dev/serial/by-id ]]; then
    printfInfo "Correcting group ownership for /dev/serial/* \n"
    find /dev/serial/by-id/ -exec chown --recursive --quiet --no-dereference .dialout {} \; 2>/dev/null
    find /dev/serial/by-id/ -exec chmod --recursive --quiet g+rw {} \; 2>/dev/null
  fi

  if [[ "$(find /dev/ -name "gpio*"|wc -l)" -gt "0" || -d /sys/devices/virtual/gpio || -d /sys/devices/platform/gpio-sunxi/gpio || /sys/class/gpio ]]; then
    printfInfo "Found GPIO: Correcting group permissions in /dev and /sys to 'gpio' with GID ${GPIO_GID} \n"
    if [ -n "$(grep ^gpio: /etc/group)" ]; then
      sed -i "s/^gpio\:.*/gpio\:x\:${GPIO_GID}/" /etc/group
    else
      groupadd --force --gid ${GPIO_GID} --non-unique gpio 2>&1>/dev/null
    fi
    adduser --quiet fhem gpio 2>&1>/dev/null
    find /dev/ -name "gpio*" -exec chown --recursive --quiet --no-dereference .gpio {} \; 2>/dev/null
    find /dev/ -name "gpio*" -exec chmod --recursive --quiet g+rw {} \; 2>/dev/null
    [ -d /sys/devices/virtual/gpio ] && chown --recursive --quiet --no-dereference .gpio /sys/devices/virtual/gpio/* 2>&1>/dev/null && chmod --recursive --quiet g+w /sys/devices/virtual/gpio/*
    [ -d /sys/devices/platform/gpio-sunxi/gpio ] && chown --recursive --quiet --no-dereference .gpio /sys/devices/platform/gpio-sunxi/gpio/* 2>&1>/dev/null && chmod --recursive --quiet g+w /sys/devices/platform/gpio-sunxi/gpio/*
    [ -d /sys/class/gpio ] && chown --recursive --quiet --no-dereference .gpio /sys/class/gpio/* 2>&1>/dev/null && chmod --recursive --quiet g+w /sys/class/gpio/*
  fi

  if [ -n "$(grep ^i2c: /etc/group)" ]; then
    printfInfo "Found I2C: Correcting group permissions in /dev to 'i2c' with GID ${I2C_GID} \n"
    if [ -n "$(grep ^i2c: /etc/group)" ]; then
      sed -i "s/^i2c\:.*/i2c\:x\:${I2C_GID}/" /etc/group
    else
      groupadd --force --gid ${I2C_GID} --non-unique i2c 2>&1>/dev/null
    fi
    adduser --quiet fhem i2c 2>&1>/dev/null
    find /dev/ -name "i2c-*" -exec chown --recursive --quiet --no-dereference .i2c {} \;
  fi

  printfInfo "Updating /etc/sudoers.d/fhem-docker\n"
  cat > /etc/sudoers.d/fhem-docker <<- END_OF_INLINE
# Auto-generated during container start
#
# required by modules
fhem ALL=(ALL) NOPASSWD: /usr/bin/nmap
# Allow updates
fhem ALL=(ALL) NOPASSWD: /usr/bin/apt-get -q update
fhem ALL=(ALL) NOPASSWD: /usr/bin/apt-get -s -q -V upgrade
fhem ALL=(ALL) NOPASSWD: /usr/bin/apt-get -y -q -V upgrade
fhem ALL=(ALL) NOPASSWD: /usr/bin/apt-get -y -q -V dist-upgrade
fhem ALL=(ALL) NOPASSWD:SETENV: /usr/bin/npm update *
# Allow installation of new packages
fhem ALL=(ALL) NOPASSWD:SETENV: /usr/local/bin/cpanm *
fhem ALL=(ALL) NOPASSWD: /usr/bin/apt-get -y install *
fhem ALL=(ALL) NOPASSWD:SETENV: /usr/bin/npm install *
fhem ALL=(ALL) NOPASSWD:SETENV: /usr/bin/npm uninstall *
END_OF_INLINE
  chmod 440 /etc/sudoers.d/fhem*
  chown --quiet --no-dereference root:${FHEM_GID} /etc/sudoers.d/fhem* 2>&1>/dev/null

  # SSH key: Ed25519
  mkdir -p ${FHEM_DIR}/.ssh
  chmod 700 ${FHEM_DIR}/.ssh
  [ -e ${FHEM_DIR}/.ssh/authorized_keys ] && chmod 600 ${FHEM_DIR}/.ssh/authorized_keys
  if [ ! -s ${FHEM_DIR}/.ssh/id_ed25519 ]; then
    printfInfo "Generating SSH Ed25519 client certificate for user 'fhem'\n"
    rm -f ${FHEM_DIR}/.ssh/id_ed25519*
    ssh-keygen -t ed25519 -f ${FHEM_DIR}/.ssh/id_ed25519 -q -N "" -o -a 100
    sed -i "s/root@.*/fhem@fhem-docker/" ${FHEM_DIR}/.ssh/id_ed25519.pub
  fi
  # SSH key: RSA
  if [ ! -s ${FHEM_DIR}/.ssh/id_rsa ]; then
    printfInfo "Generating SSH RSA client certificate for user 'fhem'\n"
    rm -f ${FHEM_DIR}/.ssh/id_rsa*
    ssh-keygen -t rsa -b 4096 -f ${FHEM_DIR}/.ssh/id_rsa -q -N "" -o -a 100
    sed -i "s/root@.*/fhem@fhem-docker/" ${FHEM_DIR}/.ssh/id_rsa.pub
  fi
  # SSH client hardening
  if [ ! -f ${FHEM_DIR}/.ssh/config ]; then
    printfInfo "Generating SSH client configuration for user 'fhem'\n"
    cat > ${FHEM_DIR}/.ssh/config <<- END_OF_INLINE
IdentityFile ~/.ssh/id_ed25519
IdentityFile ~/.ssh/id_rsa
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
HostKeyAlgorithms ssh-ed25519,ssh-rsa
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,umac-128-etm@openssh.com
END_OF_INLINE
  fi

  # Adding to local hosts file
  local -A hostAddr
  hostAddr[gateway.docker.internal]="${DOCKER_GW}"
  hostAddr[host.docker.internal]="${DOCKER_HOST:-127.0.127.2}"
  for theHost in "${!hostAddr[@]}" ; do
    [ -n "$(dig +short -t a ${theHost}.)" ] && continue
    [ -z "${hostAddr[$theHost]}" ] && continue
    grep -q -F "${hostAddr[$theHost]}" /etc/hosts && continue
    printfInfo "Adding ${theHost} to /etc/hosts \n"
    echo -e "${hostAddr[$theHost]}\t${theHost}" >> /etc/hosts
  done

  # Key pinning for Docker host
  printfInfo "Pre-authorizing SSH to Docker host for user 'fhem' \n"
  touch ${FHEM_DIR}/.ssh/known_hosts
  grep -v -E "^host.docker.internal" ${FHEM_DIR}/.ssh/known_hosts | grep -v -E "^gateway.docker.internal" > ${FHEM_DIR}/.ssh/known_hosts.tmp
  ssh-keyscan -t ed25519 host.docker.internal 2>/dev/null >> ${FHEM_DIR}/.ssh/known_hosts.tmp
  ssh-keyscan -t rsa host.docker.internal 2>/dev/null >> ${FHEM_DIR}/.ssh/known_hosts.tmp
  mv -f ${FHEM_DIR}/.ssh/known_hosts.tmp ${FHEM_DIR}/.ssh/known_hosts

  # SSH key pinning
  printfInfo "Updating SSH key pinning and SSH client permissions for user 'fhem' \n"
  cat ${FHEM_DIR}/.ssh/known_hosts /ssh_known_hosts.txt | grep -v ^# | sort -u -k1,2 > ${FHEM_DIR}/.ssh/known_hosts.tmp
  mv -f ${FHEM_DIR}/.ssh/known_hosts.tmp ${FHEM_DIR}/.ssh/known_hosts
  chown -R fhem.fhem ${FHEM_DIR}/.ssh/
  chmod 640 ${FHEM_DIR}/.ssh/known_hosts
  chmod 600 ${FHEM_DIR}/.ssh/id_ed25519 ${FHEM_DIR}/.ssh/id_rsa
  chmod 640 ${FHEM_DIR}/.ssh/id_ed25519.pub ${FHEM_DIR}/.ssh/id_rsa.pub

  printfInfo "Preparing user environment done\n"
}


# Function collecting all activities for preparing shell environment (=exports) for FHEM execution
#
# Usage: prepareFhemShellEnv
# Global vars: lots of (tbd)
#
function prepareFhemShellEnv() {
  [ "${gSavedUserLcAll}" != '' ] && LC_ALL="${gSavedUserLcAll}" || unset LC_ALL
  
  FHEM_GLOBALATTR_DEF="nofork=0 updateInBackground=1 logfile=${LOGFILE#${FHEM_DIR}/} pidfilename=${PIDFILE#${FHEM_DIR}/}"
  export PERL_JSON_BACKEND="${PERL_JSON_BACKEND:-Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP}"
  export FHEM_GLOBALATTR="${FHEM_GLOBALATTR:-${FHEM_GLOBALATTR_DEF}}"

  # Set default language settings, based on https://wiki.debian.org/Locale
  # Also see https://unix.stackexchange.com/questions/62316/why-is-there-no-euro-english-locale
  export LANG="${LANG:-en_US.UTF-8}" # maximum compatibility so we need US English
  export LANGUAGE="${LANGUAGE:-en_US:en}"
  export LC_MEASUREMENT="${LC_MEASUREMENT:-de_DE.UTF-8}" # Measuring units in European standard
  export LC_MESSAGES="${LC_MESSAGES:-en_DK.UTF-8}" # Yes/No messages in english but with more answers
  export LC_MONETARY="${LC_MONETARY:-de_DE.UTF-8}" # Monetary formatting in European standard
  export LC_NUMERIC="${LC_NUMERIC:-de_DE.UTF-8}" # Numeric formatting in (a) European standard
  export LC_PAPER="${LC_PAPER:-de_DE.UTF-8}" # Paper size in European standard
  export LC_TELEPHONE="${LC_TELEPHONE:-de_DE.UTF-8}" # Representation of telephone numbers in German format
  export LC_TIME="${LC_TIME:-en_DK.UTF-8}" # Date and time formats in European standard
  [ -n "${LC_CTYPE+x}" ] && export LC_CTYPE
  [ -n "${LC_COLLATE+x}" ] && export LC_COLLATE
  [ -n "${LC_NAME+x}" ] && export LC_NAME
  [ -n "${LC_ADDRESS+x}" ] && export LC_ADDRESS
  [ -n "${LC_ALL+x}" ] && export LC_ALL

  # Export some variables someone might want to use
  for theVar in $(env | awk -F= '/^NODE|^PERL|^PYTHON/{print $1}'); do export $theVar ; done
}


#====================================================================================================================-
#--- FHEM process functions ------------------------------------------------------------------------------------------

# Read the PID of FHEM from it's PID file and write it to stdout
# ATTENTION: The function returns only the number from the file. 
#            No check is done if there in fact is a process with that number.
#
# Usage: getFhemPidNum
# Global vars: PIDFILE
# Returns:     0:     PID successfully read from file and sent to stdout
#              else:  No PID available
#
function getFhemPidNum() {
  [ -s "$PIDFILE" ] || return 1;
  head -1 "$PIDFILE"
  return 0
}


# Checks if there is a running process with the FHEM PID number.
#
# Usage: checkFhemProcessExists
# Returns:     0:     Process exists
#              else:  No process or any other error
#
function checkFhemProcessExists() {
  local -i pidNum  # DO NOT make the following assignment in the same line! The return value gets lost!
  pidNum=$(getFhemPidNum) || return
  kill -0 $pidNum 2>&1 >/dev/null;
}


# Starts FHEM.
# Main steps in here:
#  - Run pre-start scripts
#  - Start printing the logfile to the console
#  - Launch FHEM process
#  - Run post-start scripts
#
# Usage: startFhemProcess
# Global vars: lots of (tbd)
#
function startFhemProcess() {
  runScript "/pre-start.sh"
  runScript "/docker/pre-start.sh"

  local realLogFile="$( date +"${LOGFILE}")"
  touch "$realLogFile"                     # Make sure logfile exists, so tail stats with delay
  chown ${FHEM_UID}:${FHEM_GID} "$realLogFile"
  tailFileToConsoleStart "$realLogFile"    # Start writing the logfile to the console

  umask ${UMASK}
  printfInfo "Starting FHEM\n"
  su fhem -c "cd ${FHEM_DIR} ; perl fhem.pl $CONFIGTYPE"
  local -i fhemRet=$?

  if (( fhemRet != 0 )); then   # FHEM was unable to start
    printfErr "Fatal: Unable to start FHEM process - errorcode $fhemRet\n"
    exit $fhemRet
  fi

  if ! waitForTextInFile "$gCurrentTailFile" "Server started" $TIMEOUT_STARTING ; then   # Wait for startup message in the logfile
    printfErr "Fatal: No message from FHEM that server has started.\n"
    exit 1
  fi
  printfInfo "FHEM successfully started\n"

  runScript "/post-start.sh"
  runScript "/docker/post-start.sh"
}


# Stops FHEM.
# Main steps in here:
#  - Gracefully stop FHEM 
#  - If unsuccessfull kill it hard
#  - Stop printing the logfile
#
# Usage: stopFhemProcess
# Global vars: TIMEOUT_STOPPING
#
function stopFhemProcess() {
  local -i fhemPID  # DO NOT make the following assignment in the same line! The return value gets lost!
  fhemPID=$(getFhemPidNum) || return
  printfInfo 'Sending SIGTERM (equivalent to "shutdown" command) to FHEM (pid %d).\n' "$fhemPID"
  kill -SIGTERM $fhemPID
  printfInfo 'Waiting up to %ds for FHEM process (pid %d) to terminate.\n' $TIMEOUT_STOPPING $fhemPID
  if ! waitForPidToTerminate $fhemPID $TIMEOUT_STOPPING; then
    printfErr 'SIGTERM ignored. Sending SIGKILL to FHEM!\n'
    kill -9 $fhemPID
  fi
  tailFileToConsoleStop  # Stop writing the logfile to the console
}


# Process monitoring and optional restart
# Runs in an endless loop until either
#  - Externally terminated
#  - FHEM process dies and automatic restart is turned off
#
# Usage: keepFhemRunning
# Global vars: gRunMainLoop
#              LOGFILE
#              TIMEOUT_REAPPEAR
#              RESTART
#
function keepFhemRunning() {
  local -i cycleTime=10
  gRunMainLoop=1
  while (( gRunMainLoop )); do
    printfDebug "Executing main control loop\n"
    local newLogFile="$( date +"${LOGFILE}")"
    [ "$newLogFile" != "$gCurrentTailFile" ] && tailFileToConsoleStart "$newLogFile" -b     # Start writing the new logfile to the console, tail it from the beginning
  
    local -i fhemPid  # DO NOT make the following assignment in the same line! The return value gets lost!
    fhemPid=$(getFhemPidNum)
    waitForPidToTerminate $fhemPid $cycleTime || continue    # if timeout occured (i.e. not terminated) -> continue looping
    (( gRunMainLoop )) || break  # leave the loop if FHEM was stopped by external termination request

    printfErr "Unexpected FHEM termination, waiting to reappear \n"
    for ((a=0; a<TIMEOUT_REAPPEAR; a++)); do
      checkFhemProcessExists && break
      sleep 1
    done
    if ! checkFhemProcessExists ; then   # FHEM didn't reappear
      [ "$RESTART" == "0" ] && { printfErr "Fatal: FHEM did NOT reappear\n" ; exit 1; }    # Restart not enabled
      printfErr "FHEM did NOT reappear, Restarting FHEM\n"
      startFhemProcess
    else
      printfInfo "FHEM reappeared\n"
    fi
  done
}


# Handler function for actually stopping this script. Called either by
#  - "exit" was called somewhere in the script
#  - SIGTERM is received
#
# Usage: trapExitHandler
# Global vars: gRunMainLoop
#
function trapExitHandler() {
  local -i exitVal=$?  # when "exit" was called, this holds the return value
  trap - SIGTERM EXIT  # Avoid multiple calls to handler
  printfDebug "Called\n"
  gRunMainLoop=0
  stopFhemProcess
  tailFileToConsoleStop
  printfInfo "Stopping container. Bye!\n"
  exit $exitVal
}


#====================================================================================================================-
#--- Main script -----------------------------------------------------------------------------------------------------

collectDockerInfo

initialContainerSetup
if [ ! -s "${FHEM_DIR}/fhem.pl" ]; then
  printfErr "Fatal: Unable to find FHEM installation in ${FHEM_DIR}/fhem.pl\n"
  exit 1
fi

# used by other maintenance scripts (can we get rid of that?)
[ ! -f /image_info.EMPTY ] && touch /image_info.EMPTY

setGlobal_LOGFILE
setGlobal_PIDFILE

prepareFhemUser
prepareFhemShellEnv

trap trapExitHandler SIGTERM EXIT

startFhemProcess
keepFhemRunning

