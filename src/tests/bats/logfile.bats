#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'
}

setup_file() {
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::Logfile Tests' >&3

    export BATS_TEST_TIMEOUT=60
    export LOG_FILE="${BATS_SUITE_TMPDIR}/log"
    export CONFIGTYPE="fhem.cfg"
    
    set -a
    source /entry.sh
    set +a
}

teardown_file() {
    sleep 0
    rm -f /tmp/log
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3 
}

teardown() {
    # cat /opt/fhem/fhem.cfg
    rm -rf ${FHEM_DIR}/* 
    rm -rf /usr/src/fhem  # why is no cleanup in entry.sh?
        
    # Sometimes perl or grep does not terminate, we will clean up
    pkill entry.sh || true
    pkill perl || true

    mkdir -p /fhem/FHEM
    cp /tmp/fhem/FHEM/* /fhem/FHEM/ 
}


# bats test_tags=unitTest
@test "check getGlobalAttr()" {
    bats_require_minimum_version 1.5.0
      
    run ! getGlobalAttr /tmp/test.cfg "logfile"
    assert_file_not_exists ${FHEM_DIR}/fhem.cfg

    run fhemCleanInstall

    assert_file_exists ${FHEM_DIR}/fhem.cfg
    run ! getGlobalAttr ${FHEM_DIR}/fhem.cfg "some"
    cat ${FHEM_DIR}/fhem.cfg > ${LOG_FILE}
    run -0  getGlobalAttr ${FHEM_DIR}/fhem.cfg "logfile"

    assert_file_contains ${FHEM_DIR}/fhem.cfg "attr global logfile"
    run -0 getGlobalAttr ${FHEM_DIR}/fhem.cfg "logfile"
}

# bats test_tags=unitTest
@test "check setGlobal_LOGFILE from default" {
    
    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE'
    assert_output "${FHEM_DIR}/log/fhem-%Y-%m-%d.log"
}


# bats test_tags=unitTest
@test "check setGlobal_LOGFILE from fhem.cfg" {
    export LOGFILE=

    fhemCleanInstall
    assert_file_exists ${FHEM_DIR}/fhem.cfg
    assert_file_contains ${FHEM_DIR}/fhem.cfg "attr global logfile ./log/fhem-%Y-%m.log"

    unset LOGFILE
    setGlobal_LOGFILE
    run echo $LOGFILE
    assert_output "${FHEM_DIR}/log/fhem-%Y-%m.log"

    mkdir -p "/fhem"
    run bash -c 'initialContainerSetup && echo $LOGFILE'
    assert_output --partial "${FHEM_DIR}/log/fhem-%Y-%m.log"

    assert_file_exists ${FHEM_DIR}/fhem.cfg
    cat ${FHEM_DIR}/fhem.cfg
    assert_file_contains ${FHEM_DIR}/fhem.cfg "define Logfile FileLog ./log/fhem-%Y-%m.log Logfile" grep
}


# bats test_tags=unitTest
@test "check setGlobal_LOGFILE from environment" {
    export LOGFILE="/opt/log/fhem-%Y-%m-%d.log"

    run bash -c 'setGlobal_LOGFILE && echo $LOGFILE'
    assert_output "/opt/log/fhem-%Y-%m-%d.log"
}


# bats test_tags=unitTest
@test "check Logfile definition from fhem.cfg" {
    run setGlobal_LOGFILE
    run fhemCleanInstall

    assert_file_exists ${FHEM_DIR}/fhem.cfg
    assert_file_contains ${FHEM_DIR}/fhem.cfg "define Logfile FileLog ./log/fhem-%Y-%m.log Logfile"
}


# bats test_tags=integrationTest
@test "integration: default LOGFILE" {
    unset LOGFILE 
    local logfile_FMT="./log/fhem-%Y-%m.log"

    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    assert_file_exists ${FHEM_CFG_FILE}

    # Prüfen ob LOGFILE korrekt angelegt wird
    /entry.sh start &>> ${LOG_FILE} &
    export ENTRY_PID=$!
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    local realLogFile="$( date +"$logfile_FMT")"
    
    #cat ${LOG_FILE}
    assert_file_contains ${LOG_FILE} "From the FHEM_GLOBALATTR environment: attr global logfile ${logfile_FMT#./}" grep
    assert_file_exists "${FHEM_DIR}/$realLogFile"
    assert_file_contains ${FHEM_CFG_FILE}  "$logfile_FMT" grep   # logfile should  be set in configfile because it's per default

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "integration: environment set LOGFILE relative" {
    export LOGFILE="log/fhem-%Y-%m-%d.log"
    local logfile_FMT="log/fhem-%Y-%m-%d.log"
    LOG_FILE="/tmp/log"
    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    cat ${LOG_FILE}

    assert_file_exists ${FHEM_CFG_FILE}
    
    # Prüfen ob LOGFILE korrekt angelegt wird
    /entry.sh start &>> ${LOG_FILE} &
    export ENTRY_PID=$!
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    local realLogFile="$( date +"$logfile_FMT")"
    
    assert_file_contains ${LOG_FILE} "From the FHEM_GLOBALATTR environment: attr global logfile $logfile_FMT" grep
    assert_file_exists "${FHEM_DIR}/$realLogFile"
    assert_file_not_contains ${FHEM_CFG_FILE}  "attr global logfile ./$logfile_FMT" grep   # attr logfile should not be updated in configfile
    assert_file_contains ${FHEM_CFG_FILE}  "define Logfile FileLog ./$logfile_FMT" grep    # FileLog should be set by ENV Variable
    #cat ${FHEM_CFG_FILE} 3>&
    # Execute save via http and check confgfile
    echo -e "save" | fhemcl.sh 
    cat ${FHEM_CFG_FILE} 

    assert_file_contains ${FHEM_CFG_FILE}  "attr global logfile $logfile_FMT" grep  # save is executed!
    assert_file_contains ${FHEM_CFG_FILE}  "define Logfile FileLog ./$logfile_FMT" grep   # save is executed!

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "integration: environment set LOGFILE absolute" {
    export LOGFILE="/opt/log/fhem-%Y-%m-%d.log"
    local logfile_FMT="/opt/log/fhem-%Y-%m-%d.log"
    export LOG_FILE=${LOG_FILE:-/tmp/log}   
    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    assert_file_exists ${FHEM_CFG_FILE}
    
    # Prüfen ob LOGFILE korrekt angelegt wird
    /entry.sh start &>> ${LOG_FILE} &
    export ENTRY_PID=$!
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    local realLogFile="$( date +"$logfile_FMT")"
    
    assert_file_contains ${LOG_FILE} "From the FHEM_GLOBALATTR environment: attr global logfile $logfile_FMT" grep 
    assert_file_exists "$realLogFile"
    assert_file_not_contains ${FHEM_CFG_FILE}  "attr global logfile $logfile_FMT" grep   # attr logfile should not be updated in configfile
    assert_file_contains ${FHEM_CFG_FILE}  "define Logfile FileLog $logfile_FMT" grep    # FileLog should be set by ENV Variable
    #cat ${FHEM_CFG_FILE} 3>&
    # Execute save via http and check confgfile
    echo -e "save" | fhemcl.sh 
    cat ${FHEM_CFG_FILE} 
    assert_file_contains ${FHEM_CFG_FILE}  "attr global logfile $logfile_FMT" grep  # save is executed!
    assert_file_contains ${FHEM_CFG_FILE}  "define Logfile FileLog $logfile_FMT" grep   # save is executed!

    kill $ENTRY_PID # fail it the process already finished due to error!
}
