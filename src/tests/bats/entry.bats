
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'

    source /entry.sh
    export -f printfDebug
    export -f printfInfo

    # Sometimes perl or grep does not terminate, we will clean up
    pkill tail || true
    pkill grep || true
    
}

teardown() {
    rm -rf /opt/fhem/* 
    
}

@test "printf info tests" { 
    run printfInfo 'test output'
    assert_output 'INFO: test output'
}

@test "printf debug tests" { 
    declare -i gEnableDebug=1
    run printfDebug 'test output'
    assert_output 'DEBUG: bats_merge_stdout_and_stderr: test output'
}

@test "check prependFhemDirPath()" {
    export FHEM_DIR="/opt/fhem"
    export -f prependFhemDirPath

    run bash -c 'OUT=$(prependFhemDirPath "") ; echo $OUT'
    assert_output "/opt/fhem"

    run bash -c 'OUT=$(prependFhemDirPath "./logs/fhem-1-2-3.log") ; echo $OUT'
    assert_output "/opt/fhem/logs/fhem-1-2-3.log"
    run bash -c 'OUT=$(prependFhemDirPath "/opt/fhem/logs/fhem-1-2-3.log") ; echo $OUT'
    assert_output "/opt/fhem/logs/fhem-1-2-3.log"
}

@test "check getGlobalAttr()" {
    bats_require_minimum_version 1.5.0

    export FHEM_DIR="/opt/fhem"
    export -f getGlobalAttr
    
    run ! getGlobalAttr /tmp/test.cfg "logfile"
    run fhemCleanInstall

    assert_file_exists /opt/fhem/fhem.cfg
    run ! getGlobalAttr /opt/fhem/fhem.cfg "some"
    run -0  getGlobalAttr /opt/fhem/fhem.cfg "logfile"

    assert_file_contains /opt/fhem/fhem.cfg "attr global logfile"
    run -0 getGlobalAttr /opt/fhem/fhem.cfg "logfile"

}

@test "check setGlobal_LOGFILE from default" {
    
    export -f setGlobal_LOGFILE
    export -f prependFhemDirPath
    export FHEM_DIR="/opt/fhem"
    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE'
    assert_output "/opt/fhem/log/fhem-%Y-%m-%d.log"
}

@test "check setGlobal_LOGFILE from fhem.cfg" {
    export FHEM_DIR="/opt/fhem"
    run fhemCleanInstall

    assert_file_exists /opt/fhem/fhem.cfg
    assert_file_contains /opt/fhem/fhem.cfg "define Logfile FileLog ./log/fhem-%Y-%m.log Logfile"
    assert_file_contains /opt/fhem/fhem.cfg "define DockerImageInfo DockerImageInfo"
    assert_file_contains /opt/fhem/fhem.cfg "attr global logfile ./log/fhem-%Y-%m.log"

    export CONFIGTYPE="fhem.cfg"
    export -f setGlobal_LOGFILE
    export -f prependFhemDirPath
    export -f getGlobalAttr

    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE;'
    assert_output "${FHEM_DIR}/log/fhem-%Y-%m.log"
}


@test "check fhemUpdateInstall()" {
    export FHEM_DIR="/tmp/fhem"
    mkdir -p ${FHEM_DIR}/FHEM
    
    run fhemUpdateInstall
    assert_output "INFO: Updating existing FHEM installation in ${FHEM_DIR}"
    assert_file_exists /fhem/FHEM/99_DockerImageInfo.pm
    assert_file_exists ${FHEM_DIR}/FHEM/99_DockerImageInfo.pm    

    rm -r ${FHEM_DIR}   
}

@test "ceck tailFileToConsoleStop() Logfile monitoring" {
    # mock some functions
    LOGFILE="fhem-%Y-%m-%d.log"
    realLogFile="/tmp/$( date +"${LOGFILE}")"
    export gCurrentTailPid=0
    function getFhemPidNum() {
      echo "1"
    }

    export -f tailFileToConsoleStart
    export -f tailFileToConsoleStop
    export -f getFhemPidNum

    tailFileToConsoleStart ${realLogFile} -b
    run tailFileToConsoleStop

    echo $gCurrentTailPid | assert_output ""
}

@test "ceck tailFileToConsoleStart() Logfile monitoring" {
    # mock some functions
    function getFhemPidNum() {
      echo "1"
    }

    export LOGFILE="fhem-%Y-%m-%d.log"
    export realLogFile="/tmp/$( date +"${LOGFILE}")"
    export gCurrentTailPid=0
    export -f tailFileToConsoleStart
    export -f tailFileToConsoleStop
    export -f getFhemPidNum

    run bash -c 'tailFileToConsoleStart ${realLogFile} -b; sleep 1; tailFileToConsoleStop'
    assert_output ""

    echo "hello" > $realLogFile
    run bash -c 'tailFileToConsoleStart ${realLogFile} -b; sleep 1; tailFileToConsoleStop'
    assert_output "hello"


    run bash -c 'tailFileToConsoleStart ${realLogFile}; sleep 1; echo "again" >> $realLogFile; sleep 1; tailFileToConsoleStop'
    assert_output "again"
    refute_output "hello"
}


@test "verify before clean install FHEM" {

    assert_file_exists /fhem/FHEM/99_DockerImageInfo.pm
    assert_not_exists /opt/fhem/fhem.pl

}

@test "Setup clean install FHEM" {
    declare -r  FHEM_DIR="/opt/fhem"
    run fhemCleanInstall
    assert_output --partial 'Installing FHEM to /opt/fhem'
    assert_file_exists /opt/fhem/fhem.pl
    assert_file_exists /opt/fhem/fhem.cfg.default
    assert_file_exists /opt/fhem/FHEM/99_DockerImageInfo.pm
    
    #assert_file_contains /opt/fhem/fhem.cfg attr global mseclog 1 grep

}

@test "check aptInstall()" {
    bats_require_minimum_version 1.5.0

    export -f aptInstall 
    export gAptUpdateHasRun=0

    run -0 aptInstall "test message" /tmp/aptInstall.log grep

    assert_file_contains /tmp/aptInstall.log Get:
    assert_file_contains /tmp/aptInstall.log update
    assert_file_contains /tmp/aptInstall.log grep
    assert_output --partial "test message"
    
    run -0 aptInstall "test message2" /tmp/aptInstall2.log grep
    assert_file_not_contains  /tmp/aptInstall2.log Get:
    assert_output --partial "test message2"
}   
  
 