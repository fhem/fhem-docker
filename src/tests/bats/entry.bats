
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'

    #rm -rf /opt/fhem/* 
    source /entry.sh
}

teardown() {
    rm -rf /opt/fhem/* 
    sleep 0
}


@test "check setGlobal_LOGFILE from default" {
    export -f setGlobal_LOGFILE
    export -f prependFhemDirPath
    export FHEM_DIR="/opt/fhem"
    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE'
    assert_output "/opt/fhem/log/fhem-%Y-%m-%d.log"
}

@test "check setGlobal_LOGFILE from fhem.cfg" {
    declare -r  FHEM_DIR="/opt/fhem"
    run fhemCleanInstall

    assert_file_exists /opt/fhem/fhem.cfg
    export CONFIGTYPE="fhem.cfg"
    export -f setGlobal_LOGFILE
    export -f prependFhemDirPath
    #export FHEM_DIR="/opt/fhem"
    run bash -c 'unset LOGFILE && setGlobal_LOGFILE && echo $LOGFILE'
    assert_output "./log/fhem-%Y-%m.log"
}

@test "printf info tests" { 

    run  printfInfo 'test output'
    assert_output 'INFO: test output'
}

@test "printf debug tests" { 

    declare -i gEnableDebug=1
    run printfDebug 'test output'
    assert_output 'DEBUG: run: test output'
}

#@test "Logfile monitoring" {
##   skip 'Logfile test is not created'
#   
#}


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


