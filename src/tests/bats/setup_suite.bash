setup_suite() {
    export FHEM_CFG_FILE="${FHEM_DIR}/fhem.cfg"
    export FHEM_DIR="/opt/fhem"
    mkdir -p /tmp/fhem/FHEM
    cp -r /fhem/FHEM/*  /tmp/fhem/FHEM/

}


teardown_suite() {
    sleep 0
    rm -r /tmp/fhem/FHEM
}

