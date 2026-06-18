#!/bin/bash

NB_MESSAGES=${1:-1}

run_test() {
    echo "$1"
    local start=$SECONDS
    shift
    python3 send_hl7_tcp_ORU_cli.py --silent "$@"
    echo "Elapsed: $((SECONDS - start))s"
    echo "---"
}

run_test "Sending ${NB_MESSAGES} HL7 message(s) to remote server" \
    --nb-messages "${NB_MESSAGES}" --nb-threads 20

run_test "Sending ${NB_MESSAGES} HL7 message(s) with embedded PDF to remote server" \
    --nb-messages "${NB_MESSAGES}" --nb-threads 20 --include-pdf

run_test "Sending ${NB_MESSAGES} HL7 message(s) to localhost:39001" \
    --server-ip localhost --server-port 39001 --nb-messages "${NB_MESSAGES}" --nb-threads 20

run_test "Sending ${NB_MESSAGES} HL7 message(s) with embedded PDF to localhost:39001" \
    --server-ip localhost --server-port 39001 --nb-messages "${NB_MESSAGES}" --nb-threads 20 --include-pdf

