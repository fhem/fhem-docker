setup_suite() {
    export FHEM_DIR="/opt/fhem"
    export FHEM_CFG_FILE="${FHEM_DIR}/fhem.cfg"
    export HOSTS_FILE='/etc/hosts'

    cp ${HOSTS_FILE} ${BATS_SUITE_TMPDIR}/hosts 
    mkdir -p /tmp/fhem/FHEM
    cp -r /fhem/FHEM/*  /tmp/fhem/FHEM/

    wget  https://raw.githubusercontent.com/heinz-otto/fhemcl/master/fhemcl.sh -O /usr/local/bin/fhemcl.sh
    chmod +x /usr/local/bin/fhemcl.sh
}


teardown_suite() {
    rm /usr/local/bin/fhemcl.sh
    rm -r /tmp/fhem
}

