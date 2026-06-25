#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_SCRIPT="${SCRIPT_DIR}/../iris/python/DGLAB_cli.py"

DEFAULT_SERVER_IP="ec2-63-177-72-122.eu-central-1.compute.amazonaws.com"
SERVER_IP="${DEFAULT_SERVER_IP}"
OUTPUT_FILE="${SCRIPT_DIR}/namespace_test_report_$(date +%Y%m%d_%H%M%S).md"
LOG_FILE="${SCRIPT_DIR}/namespace_test_report_$(date +%Y%m%d_%H%M%S).log"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--server-ip HOST] [--output FILE] [--log FILE]

Tests all namespaces from _NAMESPACE_PORT_MAP by calling DGLAB_cli.py
on both ORU and ADT ports, then generates a markdown report containing
green/red checkbox markers for each namespace.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip)
      shift
      SERVER_IP="${1:-}"
      ;;
    --output)
      shift
      OUTPUT_FILE="${1:-}"
      ;;
    --log)
      shift
      LOG_FILE="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ ! -f "$CLI_SCRIPT" ]]; then
  echo "ERROR: CLI script not found: $CLI_SCRIPT" >&2
  exit 1
fi

declare -a NAMESPACE_ROWS=(
  "Delphine|9101|9121"
  "Danmark|9102|9122"
  "Marck-Augustus|9103|9123"
  "Carl-Jamie|9104|9124"
  "Francois|9105|9125"
  "Rochelle|9106|9126"
  "Neil|9107|9127"
  "Adrian|9108|9128"
  "Philippe|9109|9129"
  "Jean-Michel|9110|9130"
  "Olivier|9111|9131"
  "Michael|9112|9132"
  "Sophie|9113|9133"
  "Frederic|9114|9134"
  "Ronald|9115|9135"
  "DGLAB|9001|9002"
  "UTA|9120|9140"
  "STAGE|9120|9140"
  "QA-TESTING|9120|9140"
  "SYLVAIN|9120|9140"
  "TRAINING|9120|9140"
)

PASS_MARK="🟩"
FAIL_MARK="🟥"

TESTED=0
PASSED=0

run_probe() {
  local namespace="$1"
  local label="$2"
  local port="$3"
  local out

  out="$(python3 "$CLI_SCRIPT" \
    --server-ip "$SERVER_IP" \
    --server-port "$port" \
    --nb-messages 1 \
    --nb-threads 1 \
    --patient-id 24445670 \
    --first-name Anne \
    --last-name VERSAIRE \
    --dob 24/01/1985 \
    --gender F \
    --sodium 140 2>&1)"

  {
    echo "===== ${namespace} / ${label} (${SERVER_IP}:${port}) ====="
    echo "$out"
    echo
  } >> "$LOG_FILE"

  TESTED=$((TESTED + 1))

  if echo "$out" | grep -qi "FAILED"; then
    return 1
  fi

  if echo "$out" | grep -qi "Response:"; then
    PASSED=$((PASSED + 1))
    return 0
  fi

  return 1
}

{
  echo "# Namespace Connectivity Report"
  echo
  echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- CLI: ${CLI_SCRIPT}"
  echo "- Server IP: ${SERVER_IP}"
  echo "- Detail log: ${LOG_FILE}"
  echo
  echo "| # | Namespace | ORU Port | ORU Result | ADT Port | ADT Result | Overall |"
  echo "|---:|---|---:|---|---:|---|---|"
} > "$OUTPUT_FILE"

row_num=0
while IFS='|' read -r namespace oru_port adt_port; do
  row_num=$((row_num + 1))
  oru_result="$FAIL_MARK"
  adt_result="$FAIL_MARK"
  overall="$FAIL_MARK"

  if run_probe "$namespace" "ORU" "$oru_port"; then
    oru_result="$PASS_MARK"
  fi

  if run_probe "$namespace" "ADT" "$adt_port"; then
    adt_result="$PASS_MARK"
  fi

  if [[ "$oru_result" == "$PASS_MARK" && "$adt_result" == "$PASS_MARK" ]]; then
    overall="$PASS_MARK"
  fi

  echo "| ${row_num} | ${namespace} | ${oru_port} | ${oru_result} | ${adt_port} | ${adt_result} | ${overall} |" >> "$OUTPUT_FILE"
done < <(printf '%s\n' "${NAMESPACE_ROWS[@]}")

FAILED=$((TESTED - PASSED))

{
  echo
  echo "## Summary"
  echo
  echo "- Checks passed: ${PASSED}/${TESTED}"
  echo "- Checks failed: ${FAILED}/${TESTED}"
} >> "$OUTPUT_FILE"

echo "Report generated: $OUTPUT_FILE"
echo "Detail log generated: $LOG_FILE"
