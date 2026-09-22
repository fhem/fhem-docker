
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
    declare -g CONTAINER_RUNTIME=
    declare -g CONTAINERIZED=
    unset KUBERNETES_SERVICE_HOST

    export DOCKER_ENV_FILE="${BATS_TEST_TMPDIR}/.dockerenv"
    export KUBERNETES_TOKEN_FILE="${BATS_TEST_TMPDIR}/kubernetes-token"
    export CONTAINER_CGROUP_FILE="${BATS_TEST_TMPDIR}/cgroup"
    export CONTAINER_MOUNTINFO_FILE="${BATS_TEST_TMPDIR}/mountinfo"
    rm -f "${DOCKER_ENV_FILE}" "${KUBERNETES_TOKEN_FILE}" "${CONTAINER_CGROUP_FILE}" "${CONTAINER_MOUNTINFO_FILE}"
    touch "${CONTAINER_CGROUP_FILE}" "${CONTAINER_MOUNTINFO_FILE}"

    # copy default hosts file before every test
    cp  "${BATS_SUITE_TMPDIR}/hosts" "${HOSTS_FILE}"
}


setup_file() {
    export BATS_TEST_TIMEOUT=60
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
    export CONTAINER_RUNTIME_FILE='/container.runtime'
    export CONTAINERIZED_FILE='/containerized'

}

teardown_file() {
    sleep 0

    # Cleanup
    unset DOCKER_GW
    unset DOCKER_HOST
    unset DOCKER_PRIVILEGED
    unset CONTAINER_RUNTIME
    unset CONTAINERIZED
    unset KUBERNETES_SERVICE_HOST
    unset DOCKER_ENV_FILE
    unset KUBERNETES_TOKEN_FILE
    unset CONTAINER_CGROUP_FILE
    unset CONTAINER_MOUNTINFO_FILE
    cp  "${BATS_SUITE_TMPDIR}/hosts" "${HOSTS_FILE}"
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3
}



teardown() {
    rm -f ${CAP_E_FILE} ${CAP_P_FILE} ${CAP_I_FILE} ${HOSTNETWORK_FILE} ${PRIVILEDGED_FILE} ${CONTAINER_RUNTIME_FILE} ${CONTAINERIZED_FILE}
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - kubernetes from env" {
    export KUBERNETES_SERVICE_HOST=10.96.0.1

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'kubernetes'
    assert_equal ${CONTAINERIZED} '1'
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - kubernetes from serviceaccount token" {
    touch "${KUBERNETES_TOKEN_FILE}"

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'kubernetes'
    assert_equal ${CONTAINERIZED} '1'
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - docker from marker file" {
    touch "${DOCKER_ENV_FILE}"

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'docker'
    assert_equal ${CONTAINERIZED} '1'
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - kubernetes from cgroup" {
    echo '0::/kubepods.slice/pod123/cri-containerd-abc.scope' > "${CONTAINER_CGROUP_FILE}"

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'kubernetes'
    assert_equal ${CONTAINERIZED} '1'
}


# bats test_tags=unitTest
@test "check detectContainerRuntime() - containerd from cgroup" {
    echo '0::/system.slice/containerd.service/containerd-abc.scope' > "${CONTAINER_CGROUP_FILE}"

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'containerd'
    assert_equal ${CONTAINERIZED} '1'
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - cri-o from cgroup" {
    echo '0::/system.slice/cri-o-abc.scope' > "${CONTAINER_CGROUP_FILE}"

    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'cri-o'
    assert_equal ${CONTAINERIZED} '1'
}

# bats test_tags=unitTest
@test "check detectContainerRuntime() - host fallback" {
    detectContainerRuntime

    assert_equal ${CONTAINER_RUNTIME} 'host'
    assert_equal ${CONTAINERIZED} '0'
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
    bats_require_minimum_version 1.5.0

    collectDockerInfo
    run -0 addDockerHosts

    assert_equal "${DOCKER_GW}" ""
    refute_output --partial "Adding gateway.docker.internal"

    cat "${HOSTS_FILE}"
    assert_file_not_contains ${HOSTS_FILE} "${DOCKER_GW}.*gateway.docker.internal" grep
}
