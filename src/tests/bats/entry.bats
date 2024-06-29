
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'

    # Sometimes perl or grep does not terminate, we will clean up
    pkill tail || true
    pkill grep || true
}


setup_file() {
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::function tests' >&3
    export BATS_TEST_TIMEOUT=60
    export LOG_FILE="${BATS_SUITE_TMPDIR}/log"

    set -a
    source /entry.sh
    set +a
}

teardown_file() {
    sleep 0
    rm -f /tmp/log
    rm -rf /opt/fhem/*
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3    
}



teardown() {
    # cat /opt/fhem/fhem.cfg
    rm -rf /opt/fhem/* 
    rm -rf /usr/src/fhem  # why is no cleanup in entry.sh?
        
    mkdir -p /fhem/FHEM
    cp /tmp/fhem/FHEM/* /fhem/FHEM/ 
}


# bats test_tags=unitTest
@test "printf info tests" { 
    run printfInfo 'test output'
    assert_output 'INFO: test output'
}

# bats test_tags=unitTest
@test "printf debug tests" { 
    declare -i gEnableDebug=1
    run printfDebug 'test output'
    assert_output 'DEBUG: bats_merge_stdout_and_stderr: test output'
}

# bats test_tags=unitTest
@test "check prependFhemDirPath()" {

    run bash -c 'OUT=$(prependFhemDirPath "") ; echo $OUT'
    assert_output "/opt/fhem"

    run bash -c 'OUT=$(prependFhemDirPath "./logs/fhem-1-2-3.log") ; echo $OUT'
    assert_output "/opt/fhem/logs/fhem-1-2-3.log"
    run bash -c 'OUT=$(prependFhemDirPath "/opt/fhem/logs/fhem-1-2-3.log") ; echo $OUT'
    assert_output "/opt/fhem/logs/fhem-1-2-3.log"

    run bash -c 'OUT=$(prependFhemDirPath "/run/lock/fhem.pid") ; echo $OUT'
    assert_output "/opt/fhem/run/lock/fhem.pid"

}

# bats test_tags=unitTest
@test "check fhemUpdateInstall()" {
    export FHEM_DIR=${BATS_TEST_TMPDIR}"/fhemUpdateInstall"
    mkdir -p ${FHEM_DIR}/FHEM
    
    run fhemUpdateInstall
    assert_output "INFO: Updating existing FHEM installation in ${FHEM_DIR}"
    assert_file_exists /fhem/FHEM/99_DockerImageInfo.pm
    assert_file_exists ${FHEM_DIR}/FHEM/99_DockerImageInfo.pm    

    #rm -r ${FHEM_DIR}   
}

# bats test_tags=unitTest
@test "ceck tailFileToConsoleStop() Logfile monitoring" {
    # mock some functions
    LOGFILE="fhem-%Y-%m-%d.log"
    realLogFile="/tmp/$( date +"${LOGFILE}")"
    export gCurrentTailPid=0
    function getFhemPidNum() {
      echo "1"
    }

    tailFileToConsoleStart ${realLogFile} -b
    run tailFileToConsoleStop

    echo $gCurrentTailPid | assert_output ""
}

# bats test_tags=unitTest
@test "ceck tailFileToConsoleStart() Logfile monitoring" {
    # mock some functions
    function getFhemPidNum() {
      echo "1"
    }

    export LOGFILE="fhem-%Y-%m-%d.log"
    export realLogFile="${BATS_TEST_TMPDIR}/$( date +"${LOGFILE}")"
    export gCurrentTailPid=0
    export TAIL_PID=

    #touch ${realLogFile}

    run bash -c 'tailFileToConsoleStart ${realLogFile} -b; sleep 1; tailFileToConsoleStop'
    assert_output ""

    echo "hello" > $realLogFile
    run bash -c 'tailFileToConsoleStart ${realLogFile} -b; sleep 1; tailFileToConsoleStop'
    assert_output "hello"


    run bash -c 'tailFileToConsoleStart ${realLogFile}; sleep 1; echo "again" >> $realLogFile; sleep 1; tailFileToConsoleStop'
    assert_output "again"
    refute_output "hello"
}

# bats test_tags=integrationTest
@test "Setup clean install FHEM" {
    
    run fhemCleanInstall
    assert_output --partial "Installing FHEM to ${FHEM_DIR}"
    assert_file_exists ${FHEM_DIR}/fhem.pl
    assert_file_exists ${FHEM_DIR}/fhem.cfg.default
    assert_file_exists ${FHEM_DIR}/FHEM/99_DockerImageInfo.pm
    
    #assert_file_contains /opt/fhem/fhem.cfg attr global mseclog 1 grep

}

# bats test_tags=unitTest
@test "verify is_absolutePath" {
    bats_require_minimum_version 1.5.0
    
    export -f is_absolutePath
  
    run -0 bash -c 'is_absolutePath /opt/fhem'
    run -0 bash -c 'is_absolutePath /run/lock/file'
    run -1 bash -c 'is_absolutePath ./log/'
    run -1 bash -c 'is_absolutePath ../log/'
    run -1 bash -c 'is_absolutePath .'
    run -1 bash -c 'is_absolutePath '
}


# bats test_tags=unitTest
@test "verify getFHEMRevision" {
    bats_require_minimum_version 1.5.0
    
    #export -f getFHEMRevision
    
    run fhemCleanInstall
    assert_file_exists ${FHEM_DIR}/fhem.pl

    assert [ "$(getFHEMRevision)" -gt 0 ]

    # Patch fixed revision id
    sed -i 's/[0-9]\+/20000/1' ${FHEM_DIR}/fhem.pl
    assert [ "$(getFHEMRevision)" -eq 20000 ]

    # Patch wrong revision id 
    sed -i 's/[0-9]\+/ddd/1' ${FHEM_DIR}/fhem.pl
    assert [ "$(getFHEMRevision)" -eq 0 ]
}


# bats test_tags=unitTest
@test "verify initialContainerSetup without error" {
    run initialContainerSetup
    assert_output --partial "Preparing initial container setup"
    assert_output --partial "Initial container setup done"
    refute_output --partial 'ERROR'
}

# bats test_tags=unitTest
@test "verify initialContainerSetup with to old fhem installation" {
    fhemCleanInstall
    sed -i 's/[0-9]\+/20000/1' ${FHEM_DIR}/fhem.pl
    run initialContainerSetup
 
    assert_output --partial "is to old"
    assert_output --partial "Your container will soon be terminated"
    assert_output --partial 'ERROR'
}