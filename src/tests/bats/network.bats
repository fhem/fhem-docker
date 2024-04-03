
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'

    # Clean bevore every run
    declare -g DOCKER_GW=
    declare -g DOCKER_HOST=
    declare -g DOCKER_PRIVILEGED=

    # copy default hosts file before every test
    cp  "${BATS_SUITE_TMPDIR}/hosts" "${HOSTS_FILE}"
}


setup_file() {    
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::Network Tests' >&3
    export LOG_FILE="${BATS_SUITE_TMPDIR}/log"

    set -a
    source /entry.sh
    set +a

    export CAP_E_FILE='/docker.container.cap.e'   
    export CAP_P_FILE='/docker.container.cap.p'
    export CAP_I_FILE='/docker.container.cap.i'
    export HOSTNETWORK_FILE='/docker.hostnetwork'
    export PRIVILEDGED_FILE='/docker.privileged'
    
}

teardown_file() {
    sleep 0

    # Cleanup 
    unset DOCKER_GW
    unset DOCKER_HOST
    unset DOCKER_PRIVILEGED
    cp  "${BATS_SUITE_TMPDIR}/hosts" "${HOSTS_FILE}"
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3
}



teardown() {
    rm -f ${CAP_E_FILE} ${CAP_P_FILE} ${CAP_I_FILE} ${HOSTNETWORK_FILE} ${PRIVILEDGED_FILE}
}

# bats test_tags=unitTest
@test "check collectDockerInfo() - check cap files" {
    bats_require_minimum_version 1.5.0
    collectDockerInfo
    
    assert_file_exists ${CAP_E_FILE}
    assert_file_exists ${CAP_P_FILE}
    assert_file_exists ${CAP_I_FILE}
}

# bats test_tags=unitTest
@test "check collectDockerInfo() - HOSTNETWORK File in bridgeMode (default)" {
    collectDockerInfo

    assert_file_exists ${HOSTNETWORK_FILE}
    assert_file_contains ${HOSTNETWORK_FILE} "0" grep
    assert_file_not_contains ${HOSTNETWORK_FILE} "1" grep
    assert_equal ${DOCKER_HOSTNETWORK} '0'
}

# bats test_tags=hostMode,unitTest
@test "check collectDockerInfo() - HOSTNETWORK File in hostMode" {
    collectDockerInfo

    assert_file_exists ${HOSTNETWORK_FILE}
    assert_file_contains ${HOSTNETWORK_FILE} "1" grep
    assert_file_not_contains ${HOSTNETWORK_FILE} "0" grep
    assert_equal ${DOCKER_HOSTNETWORK} '1'

}


# bats test_tags=unitTest
@test "check collectDockerInfo() - PRIVILEDGED file " {
    collectDockerInfo
    
    assert_file_contains ${PRIVILEDGED_FILE} '0' grep
    assert_file_not_contains ${PRIVILEDGED_FILE} '1' grep
    assert_equal ${DOCKER_PRIVILEGED} '0'

}

# bats test_tags=hostMode,unitTest
@test "check collectDockerInfo() - DOCKER_GW" {
    collectDockerInfo

    assert_equal ${DOCKER_GW} ''
}

# bats test_tags=hostMode,unitTest
@test "check collectDockerInfo() - DOCKER_HOST" {
    collectDockerInfo

    assert_equal ${DOCKER_HOST} '127.0.0.1'
}

# bats test_tags=unitTest
@test "check DOCKER_HOST in ${HOSTS_FILE}" {
    collectDockerInfo 

    run addDockerHosts
    assert_output --partial "Adding"
    assert_file_contains ${HOSTS_FILE} "${DOCKER_HOST}" grep
    assert_file_contains ${HOSTS_FILE} "host.docker.internal" grep

}


# bats test_tags=unitTest
@test "check DOCKER_GW in ${HOSTS_FILE}" {
    collectDockerInfo
    
    run addDockerHosts
    
    assert_file_contains ${HOSTS_FILE} "${DOCKER_GW}.*gateway.docker.internal" grep
}

# bats test_tags=hostMode,unitTest
@test "check DOCKER_HOST in ${HOSTS_FILE} with hostMode" {
    collectDockerInfo

    run addDockerHosts
    assert_output --partial "Adding "
    cat ${HOSTS_FILE}
    assert_file_contains ${HOSTS_FILE} "${DOCKER_HOST}.*host.docker.internal" grep
}


# bats test_tags=hostMode,unitTest
@test "check DOCKER_GW in ${HOSTS_FILE} with hostMode" {
    collectDockerInfo
    
    assert_equal "${DOCKER_GW}" ""

    run addDockerHosts
    
    cat "${HOSTS_FILE}" 
    refute_output --partial "Adding gateway.docker.internal"
    assert_file_not_contains ${HOSTS_FILE} "${DOCKER_GW}.*gateway.docker.internal" grep
}