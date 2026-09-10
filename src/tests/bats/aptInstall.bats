
#!/usr/bin/env bats

setup() {
    load '/opt/bats/test_helper/bats-support/load.bash'
    load '/opt/bats/test_helper/bats-assert/load.bash'
    load '/opt/bats/test_helper/bats-file/load.bash'
    load '/opt/bats/test_helper/bats-mock/load.bash'
}


setup_file() {
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::group::aptInstall Tests' >&3

    export BATS_TEST_TIMEOUT=60
    export LOG_FILE="${BATS_SUITE_TMPDIR}/log"

    set -a
    source /entry.sh
    set +a
}

teardown_file() {
    sleep 0
    [ -z ${GITHUB_RUN_ID+x} ] || echo '::endgroup::' >&3    

}



teardown() {
    DEBIAN_FRONTEND=noninteractive apt-get remove dummydroid -y && apt-get autoremove -y     # cleanup
}

# bats test_tags=integrationTest
@test "check aptInstall() new package" {
    bats_require_minimum_version 1.5.0

    gAptUpdateHasRun=0
    local installLog=${BATS_TEST_TMPDIR}/aptInstall.log
    run -0 aptInstall "test message"  ${installLog} dummydroid

    cat ${installLog}
    assert_file_contains ${installLog} "Get:" grep
    assert_file_contains ${installLog} "Fetched " grep
    assert_file_contains ${installLog} "Setting up dummydroid" grep
    assert_output --partial "test message"

}

# bats test_tags=integrationTest
@test "check aptInstall() already installed package" {
    bats_require_minimum_version 1.5.0
    
    gAptUpdateHasRun=0
    local installLog=${BATS_TEST_TMPDIR}/aptInstall.log
    run -0 aptInstall "test message2" ${installLog} grep
    cat ${installLog}
    assert_file_contains  ${installLog} "grep is already the newest version" grep
    assert_output --partial "test message2"
}   

# bats test_tags=integrationTest
@test "check aptInstall() twice executed" {
    bats_require_minimum_version 1.5.0
    
    # remove package lists
    rm -rf /var/lib/apt/lists/*

    # First Update
    gAptUpdateHasRun=0
    export gAptUpdateHasRun
    local installLog=${BATS_TEST_TMPDIR}/aptInstall.log
    run -0 aptInstall "test message2" ${installLog} dummydroid
    cat ${installLog}
    assert_file_contains ${installLog} "Get:" grep              # Packagelist is downloaded
    assert_file_not_contains ${installLog} "Hit:" grep          

    # Second Update
    gAptUpdateHasRun=0
    export gAptUpdateHasRun
    local installLog=${BATS_TEST_TMPDIR}/aptInstall2.log
    run -0 aptInstall "test message3" ${installLog} dummydroid
    assert_file_contains ${installLog} "Hit:" grep              # Packagelist was already there
    assert_file_not_contains ${installLog} "Get:" grep
    assert_output --partial "test message3"

    # Update is skipped
    gAptUpdateHasRun=1
    export gAptUpdateHasRun
    local installLog=${BATS_TEST_TMPDIR}/aptInstall3.log
    run -0 aptInstall "test message4" ${installLog} dummydroid
    assert_file_not_contains ${installLog} "Hit:" grep          # no update command was run
    assert_file_not_contains ${installLog} "Get:" grep          # no update command was run
    assert_output --partial "test message4"
}   