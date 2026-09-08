
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

# bats test_tags=integrationTest
@test "healthcheck with running fhem" {
    bats_require_minimum_version 1.5.0

    cd ${FHEM_DIR} && /entry.sh start &> ${LOG_FILE} &
    export ENTRY_PID=$!
    sleep 6
    
   
    while ! nc -vz localhost 8083 > /dev/null 2>&1 ; do
        # echo sleeping
        sleep 0.5
        ((c++)) && ((c==50)) && echo "# fhem did not start" && break
    done
    sleep 5
    #cat $FHEM_CFG_FILE
    cat ${LOG_FILE}
    assert_file_contains /tmp/health-check.urls "http://localhost:8083"

    run timeout 15 /health-check.sh
    assert_output --partial "http://localhost:8083/fhem/"
    assert_output --partial "OK"

    kill $ENTRY_PID # fail it the process already finished due to error!
}