
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'  
}

setup_file() {
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::Healtcheck Tests' >&3
    export LOG_FILE="${BATS_SUITE_TMPDIR}/log"
}

teardown_file() {
    mkdir -p /fhem/FHEM
    cp /tmp/fhem/FHEM/* /fhem/FHEM/ 
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3    
}

teardown() {
    rm -rf ${FHEM_DIR}/* 
    rm -rf /usr/src/fhem  # why is no cleanup in entry.sh?

    # Sometimes perl or grep does not terminate, we will clean up
    pkill entry.sh || true
    pkill perl || true
}

# bats test_tags=unitTest
@test "healthcheck without url file" {
    bats_require_minimum_version 1.5.0

    run -1 /health-check.sh
    assert_output --partial "Cannot read url file"
}

# bats test_tags=unitTest
@test "healthcheck without running fhem" {
    bats_require_minimum_version 1.5.0

    echo "https://localhost:8083/fhem/" > /tmp/health-check.urls
    run -1 /health-check.sh
    assert_output --partial "https://localhost:8083/fhem/"
    assert_output --partial "FAILED"

    rm -r /tmp/health-check.urls
}

# Restore the initial container state (/fhem signals a brand new container), a previous test may have consumed it
restoreInitialContainer() {
    mkdir -p /fhem/FHEM
    cp /tmp/fhem/FHEM/* /fhem/FHEM/
    rm -f /tmp/health-check.urls
}

# Wait until a text shows up in a file
#
# Usage: waitForLogText file text [seconds]
waitForLogText() {
    local -i i
    for (( i=0; i < ${3:-60}*2; i++ )); do
        grep -q "$2" "$1" 2>/dev/null && return 0
        sleep 0.5
    done
    echo "'$2' not found in $1 within ${3:-60}s"
    return 1
}

# Print the DockerImageInfo definitions of the running FHEM, one "<name> DockerImageInfo" per line
listDockerImageInfo() {
    echo "list TYPE=DockerImageInfo TYPE" | fhemcl.sh | grep -E '^\S+\s+DockerImageInfo\s*$'
}

# bats test_tags=integrationTest
@test "healthcheck with running fhem" {
    bats_require_minimum_version 1.5.0

    restoreInitialContainer
    cd ${FHEM_DIR}
    /entry.sh start &> ${LOG_FILE} &
    export ENTRY_PID=$!

    run waitForLogText ${LOG_FILE} "Server started" 120
    assert_success
    run waitForLogText ${LOG_FILE} "creating DockerImageInfo" 15
    assert_success

    # fhem.cfg has no DockerImageInfo definition, the module defined it at runtime
    assert_file_not_contains ${FHEM_CFG_FILE} "DockerImageInfo"
    run listDockerImageInfo
    assert_success
    assert_equal "${#lines[@]}" 1
    assert_line --regexp '^DockerImageInfo\s+DockerImageInfo'
    assert_file_contains /tmp/health-check.urls "http://localhost:8083"

    run timeout 15 /health-check.sh
    assert_success
    assert_output --partial "http://localhost:8083/fhem/"
    assert_output --partial "OK"

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "healthcheck with running fhem and disabled DockerImageInfo autodefine" {
    bats_require_minimum_version 1.5.0

    restoreInitialContainer
    cd ${FHEM_DIR}
    DOCKER_IMAGEINFO_AUTODEFINE=0 /entry.sh start &> ${LOG_FILE} &
    export ENTRY_PID=$!

    # FHEM must be up and answering, otherwise the negative checks below prove nothing
    run waitForLogText ${LOG_FILE} "Server started" 120
    assert_success
    run bash -c 'echo "list TYPE=Global TYPE" | fhemcl.sh'
    assert_output --partial "Global"
    sleep 3   # give the module time to (not) create the definition

    assert_file_not_contains ${LOG_FILE} "creating DockerImageInfo"
    run listDockerImageInfo
    assert_output ""
    assert_file_not_exists /tmp/health-check.urls

    run -1 timeout 15 /health-check.sh
    assert_output --partial "Cannot read url file"

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "healthcheck with existing DockerImageInfo definition using another name" {
    bats_require_minimum_version 1.5.0

    restoreInitialContainer
    run bash -c 'set -a; source /entry.sh; set +a; cd ${FHEM_DIR} && initialContainerSetup'
    assert_success
    assert_file_not_contains ${FHEM_CFG_FILE} "DockerImageInfo"
    echo "define myInfo DockerImageInfo" >> ${FHEM_CFG_FILE}

    cd ${FHEM_DIR}
    /entry.sh start &> ${LOG_FILE} &
    export ENTRY_PID=$!

    run waitForLogText ${LOG_FILE} "Server started" 120
    assert_success
    sleep 3   # give the module time to (not) create the definition

    assert_file_not_contains ${LOG_FILE} "creating DockerImageInfo"
    run listDockerImageInfo
    assert_success
    assert_equal "${#lines[@]}" 1
    assert_line --regexp '^myInfo\s+DockerImageInfo'
    assert_file_contains /tmp/health-check.urls "http://localhost:8083"

    run timeout 15 /health-check.sh
    assert_success
    assert_output --partial "OK"

    kill $ENTRY_PID # fail it the process already finished due to error!
}

# bats test_tags=integrationTest
@test "healthcheck with saved DockerImageInfo definition after restart" {
    bats_require_minimum_version 1.5.0

    restoreInitialContainer
    cd ${FHEM_DIR}
    /entry.sh start &> ${LOG_FILE} &
    export ENTRY_PID=$!

    run waitForLogText ${LOG_FILE} "creating DockerImageInfo" 120
    assert_success

    # save keeps the automatically created definition in fhem.cfg
    echo -e "save" | fhemcl.sh
    run grep -cP '^define\s+\S+\s+DockerImageInfo\b' ${FHEM_CFG_FILE}
    assert_output "1"

    # restart FHEM, the saved definition is used and nothing is created again
    kill $ENTRY_PID
    wait $ENTRY_PID || true
    local logFile2="${BATS_SUITE_TMPDIR}/log2"
    /entry.sh start &> ${logFile2} &
    export ENTRY_PID=$!

    run waitForLogText ${logFile2} "Server started" 120
    assert_success
    sleep 3   # give the module time to (not) create the definition

    assert_file_not_contains ${logFile2} "creating DockerImageInfo"
    run listDockerImageInfo
    assert_success
    assert_equal "${#lines[@]}" 1
    run grep -cP '^define\s+\S+\s+DockerImageInfo\b' ${FHEM_CFG_FILE}
    assert_output "1"

    run timeout 15 /health-check.sh
    assert_success
    assert_output --partial "OK"

    kill $ENTRY_PID # fail it the process already finished due to error!
}