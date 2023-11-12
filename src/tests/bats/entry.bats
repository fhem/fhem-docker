
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'

    #rm -rf /opt/fhem/* 
    source /entry.sh
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
    assert_output 'DEBUG: run: test output'
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

    export CONFIGTYPE="fhem.cfg"
    export -f setGlobal_LOGFILE
    export -f prependFhemDirPath
    export -f getGlobalAttr
    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE'
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

@test "ceck tailFileToConsoleStart() Logfile monitoring" {
    export LOGFILE="fhem-%Y-%m-%d.log"
    realLogFile="$( date +"${LOGFILE}")"
    declare -i gCurrentTailPid=0
    export -f tailFileToConsoleStart


    # mock some functions
    function getFhemPidNum() {
      echo "1"
    }

    function tailFileToConsoleStop() { 
        gCurrentTailFile=""
        gCurrentTailPid=0
    }

    
    #skip 'Logfile test is endless running'
    #run tailFileToConsoleStart "${realLogFile} -b"
    #assert_output "1"
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


