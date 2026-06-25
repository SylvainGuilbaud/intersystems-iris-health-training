#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_SCRIPT="${SCRIPT_DIR}/../iris/python/DGLAB_cli.py"
LOG_FILE="${SCRIPT_DIR}/run_test_$(date +%Y%m%d_%H%M%S).log"

if [[ ! -f "$CLI_SCRIPT" ]]; then
    echo "ERROR: DGLAB_cli.py not found at $CLI_SCRIPT" >&2
    exit 1
fi

NB_MESSAGES=${1:-1}

run_test() {
    local label="$1"
    local out
    local exit_code
    local elapsed

    echo "$label"
    local start=$SECONDS
    shift
    out="$(python3 "$CLI_SCRIPT" "$@" 2>&1)"
    exit_code=$?
    elapsed=$((SECONDS - start))

    if [[ -z "$out" ]]; then
        out="(no stdout/stderr output)"
    fi

    echo "$out"
    {
        echo "===== ${label} ====="
        echo "Command: python3 $CLI_SCRIPT $*"
        echo "Exit code: ${exit_code}"
        echo "Elapsed: ${elapsed}s"
        echo "$out"
        echo
    } >> "$LOG_FILE"
    echo "Elapsed: ${elapsed}s"
    echo "---"
}

run_test "Sending ${NB_MESSAGES} HL7 message(s) to remote server" \
    --nb-messages "${NB_MESSAGES}" --nb-threads 20

run_test "Sending ${NB_MESSAGES} HL7 message(s) with embedded PDF to remote server" \
    --nb-messages "${NB_MESSAGES}" --nb-threads 20 --include-pdf

run_test "Sending ${NB_MESSAGES} HL7 message(s) to localhost:9001" \
    --server-ip localhost --server-port 9001 --nb-messages "${NB_MESSAGES}" --nb-threads 20

run_test "Sending ${NB_MESSAGES} HL7 message(s) with embedded PDF to localhost:9001" \
    --server-ip localhost --server-port 9001 --nb-messages "${NB_MESSAGES}" --nb-threads 20 --include-pdf

echo "Detail log generated: $LOG_FILE"

