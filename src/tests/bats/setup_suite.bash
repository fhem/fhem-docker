setup_suite() {
    export FHEM_DIR="/opt/fhem"
    export FHEM_CFG_FILE="${FHEM_DIR}/fhem.cfg"
    mkdir -p /tmp/fhem/FHEM
    cp -r /fhem/FHEM/*  /tmp/fhem/FHEM/

}


teardown_suite() {
    sleep 0
    rm -r /tmp/fhem/FHEM
}

