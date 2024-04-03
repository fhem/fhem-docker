#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'

    #export -f printfDebug
    #export -f printfInfo
    
    # Sometimes perl or grep does not terminate, we will clean up
    #pkill tail || true
    #pkill grep || true   
}

setup_file() {
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::aptInstall Tests' >&3
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
    rm -rf /opt/fhem/* 
    rm -rf /usr/src/fhem  # why is no cleanup in entry.sh?
        
    # Sometimes perl or grep does not terminate, we will clean up
    pkill entry.sh || true
    pkill perl || true
    #pkill grep || true

    mkdir -p /fhem/FHEM
    cp /tmp/fhem/FHEM/* /fhem/FHEM/ 
}


# bats test_tags=unitTest
@test "verify setGlobal_PIDFILE default pidfile" {
    
    run bash -c 'unset PIDFILE; setGlobal_PIDFILE ; echo $PIDFILE'
    assert_output "/opt/fhem/log/fhem.pid"
}

# bats test_tags=unitTest
@test "verify setGlobal_PIDFILE absolut pidfile" {
    export PIDFILE="/run/lock/fhem.pid"
    
    run bash -c 'setGlobal_PIDFILE ; echo $PIDFILE'
    assert_output "/run/lock/fhem.pid"
}

# bats test_tags=unitTest
@test "verify setGlobal_PIDFILE relative pidfile" {
    export PIDFILE="./run/fhem.pid"
    
    run bash -c 'setGlobal_PIDFILE ; echo $PIDFILE'
    assert_output "/opt/fhem/run/fhem.pid"
}


# bats test_tags=integrationTest
@test "integration: absoulte pidfile set in fhem.cfg" {
    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    assert_file_exists ${FHEM_DIR}/fhem.cfg
    
    # Pidfile in config schreiben!
    echo "attr global pidfilename /run/lock/fhem.pid" >> ${FHEM_CFG_FILE} 
    
    # Prüfen ob PIDFILE korrekt angelegt wird
    /entry.sh start &>> ${LOG_FILE} &
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    export ENTRY_PID=$!
    assert_file_contains ${FHEM_CFG_FILE}   '/run/lock/fhem.pid' grep
    assert_file_exists /run/lock/fhem.pid

    # Execute save via http and check confgfile
    echo -e "save" | fhemcl.sh 
    assert_file_contains ${FHEM_CFG_FILE}  '/run/lock/fhem.pid' grep  # No save is executed!

    kill $ENTRY_PID # fail it the process already finished due to error!
    assert_file_contains ${LOG_FILE} 'From the FHEM_GLOBALATTR environment: attr global pidfilename /run/lock/fhem.pid' grep
}

# bats test_tags=integrationTest
@test "integration: absoulte pidfile set in environment" {
    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    assert_file_exists ${FHEM_CFG_FILE}

    # Pidfile in ENV schreiben!
    export PIDFILE=/var/run/lock/fhem.pid
    
    # Prüfen ob PIDFILE korrekt angelegt wird
    /entry.sh start &>> ${LOG_FILE} &
    export ENTRY_PID=$!
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    
    assert_file_contains ${LOG_FILE} 'From the FHEM_GLOBALATTR environment: attr global pidfilename /var/run/lock/fhem.pid' grep
    assert_file_not_contains ${FHEM_CFG_FILE} 'attr global pidfilename /var/run/lock/fhem.pid' grep   # pidfile should not be set in configfile
    assert_file_exists /var/run/lock/fhem.pid

    # Execute save via http and check confgfile
    echo -e "save" | fhemcl.sh 
    assert_file_contains ${FHEM_CFG_FILE}  '/var/run/lock/fhem.pid' grep  # save is executed!

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "integration: default pidfile" {
    # Container setup
    run bash -c 'cd $FHEM_DIR && initialContainerSetup > ${LOG_FILE}'
    assert_file_exists ${FHEM_CFG_FILE}

    unset PIDFILE

    # Prüfen ob PIDFILE korrekt angelegt ist
    /entry.sh start &>> ${LOG_FILE} &
    waitForTextInFile ${LOG_FILE} "Server started" 15                   # wait max 15 seconds
    export ENTRY_PID=$!

    assert_file_contains ${LOG_FILE} 'From the FHEM_GLOBALATTR environment: attr global pidfilename log/fhem.pid'
    assert_file_not_contains ${FHEM_CFG_FILE}  'fhem.pid' grep   # pidfile should not be set in configfile
    assert_file_exists ${FHEM_DIR}/log/fhem.pid

    kill $ENTRY_PID # fail it the process already finished due to error!
}

