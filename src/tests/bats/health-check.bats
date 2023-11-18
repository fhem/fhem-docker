
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'  
}

teardown() {
    rm -rf /opt/fhem/* 

    # Sometimes perl or grep does not terminate, we will clean up
    pkill perl || true
    pkill grep || true
}



@test "healthcheck without url file" {
    bats_require_minimum_version 1.5.0

    run -1 /health-check.sh
    assert_output --partial "Cannot read url file"
}

@test "healthcheck without running fhem" {
    bats_require_minimum_version 1.5.0

    echo "https://localhost:8083/fhem/" > /tmp/health-check.urls
    run -1 /health-check.sh
    assert_output --partial "https://localhost:8083/fhem/"
    assert_output --partial "FAILED"

    rm -r /tmp/health-check.urls
}

@test "healthcheck with running fhem" {
    bats_require_minimum_version 1.5.0

    run /entry.sh start > /dev/null 2> /dev/null &
    sleep 5
    
    while ! nc -vz localhost 8083 > /dev/null 2>&1 ; do
        # echo sleeping
        sleep 0.5
        ((c++)) && ((c==50)) && echo "#fhem did not start" && break
    done
    sleep 5
    assert_file_contains /tmp/health-check.urls "http://localhost:8083"

    run timeout 15 /health-check.sh
    assert_output --partial "http://localhost:8083/fhem/"
    assert_output --partial "OK"

    pkill entry.sh
}