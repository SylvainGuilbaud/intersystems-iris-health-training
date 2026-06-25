#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
DISCOVER_SCRIPT="${ROOT_DIR}/discover_namespace_mllp_ports.sh"
CLI_SCRIPT="${ROOT_DIR}/../iris/python/DGLAB_cli.py"
DEFAULT_ADT_FILE="${ROOT_DIR}/../docs/1-ADT.hl7"
  
TS="$(date +%Y%m%d_%H%M%S)"
TMP_DISCOVER_MD="${ROOT_DIR}/namespace_mllp_service_ports_${TS}.md"
TMP_DISCOVER_CSV="${ROOT_DIR}/namespace_mllp_service_ports_${TS}.csv"

OUTPUT_FILE="${ROOT_DIR}/testing_ADT_ORU_MLLP_all_namespaces_${TS}.md"
LOG_FILE="${ROOT_DIR}/testing_ADT_ORU_MLLP_all_namespaces_${TS}.log"

DISCOVER_TARGET="dev-aws"
DISCOVER_CONTAINER=""
SERVER_IP=""
ADT_FILE="${DEFAULT_ADT_FILE}"

PASS_MARK="🟩"
FAIL_MARK="🟥"

TESTED=0
PASSED=0

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Run namespace MLLP discovery first, then test ORU + ADT ports for each namespace.
- ORU probe uses DGLAB_cli.py
- ADT probe sends a raw HL7 file over MLLP framing

Options:
  --target NAME      Discovery target passed to discover_namespace_mllp_ports.sh
                     (default: ${DISCOVER_TARGET})
  --container NAME   Optional discovery container override
  --server-ip HOST   Hostname/IP to send HL7 messages to
                     (default: PUBLIC_DNS from cloudenv if present, else localhost)
  --adt-file FILE    HL7 ADT message file (default: ${DEFAULT_ADT_FILE})
  --output FILE      Markdown report output path
  --log FILE         Detail log output path
  -h, --help         Show this help
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      shift
      DISCOVER_TARGET="${1:-}"
      ;;
    --container)
      shift
      DISCOVER_CONTAINER="${1:-}"
      ;;
    --server-ip)
      shift
      SERVER_IP="${1:-}"
      ;;
    --adt-file)
      shift
      ADT_FILE="${1:-}"
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

if [[ ! -f "$DISCOVER_SCRIPT" ]]; then
  echo "ERROR: discovery script not found: $DISCOVER_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$CLI_SCRIPT" ]]; then
  echo "ERROR: CLI script not found: $CLI_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$ADT_FILE" ]]; then
  echo "ERROR: ADT HL7 file not found: $ADT_FILE" >&2
  exit 1
fi

if [[ -z "$SERVER_IP" ]]; then
  if [[ -f "${REPO_ROOT}/cloudenv" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/cloudenv"
    SERVER_IP="${PUBLIC_DNS:-}"
  fi
fi

if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="localhost"
fi

probe_oru() {
  local namespace="$1"
  local port="$2"
  local out

  if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
    {
      echo "===== ${namespace} / ORU (${SERVER_IP}:${port}) ====="
      echo "SKIPPED: Missing/invalid ORU port"
      echo
    } >> "$LOG_FILE"
    TESTED=$((TESTED + 1))
    return 1
  fi

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
    echo "===== ${namespace} / ORU (${SERVER_IP}:${port}) ====="
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

probe_adt() {
  local namespace="$1"
  local port="$2"
  local out

  if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
    {
      echo "===== ${namespace} / ADT (${SERVER_IP}:${port}) ====="
      echo "SKIPPED: Missing/invalid ADT port"
      echo
    } >> "$LOG_FILE"
    TESTED=$((TESTED + 1))
    return 1
  fi

  out="$(python3 - "$SERVER_IP" "$port" "$ADT_FILE" <<'PY'
import pathlib
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
msg_path = pathlib.Path(sys.argv[3])

start_block = b"\x0b"
end_block = b"\x1c"
cr = b"\x0d"

try:
    raw = msg_path.read_bytes()
except Exception as exc:
    print(f"FAILED: unable to read HL7 file: {exc}")
    sys.exit(1)

text = raw.decode("utf-8", errors="ignore")
text = text.replace("\r\n", "\n").replace("\r", "\n")
text = "\r".join(line for line in text.split("\n") if line.strip())
payload = start_block + text.encode("utf-8") + end_block + cr

try:
    with socket.create_connection((host, port), timeout=5) as sock:
        sock.sendall(payload)
        sock.settimeout(8)
        data = sock.recv(4096)
except Exception as exc:
    print(f"FAILED: {exc}")
    sys.exit(1)

if not data:
    print("FAILED: empty response")
    sys.exit(1)

print("Response:", data.decode("utf-8", errors="replace").replace("\r", "\\r").replace("\n", "\\n"))
PY
  )"

  {
    echo "===== ${namespace} / ADT (${SERVER_IP}:${port}) ====="
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

echo "Running discovery: ${DISCOVER_SCRIPT}"

latest_csv="$(ls -1t "${ROOT_DIR}"/namespace_mllp_service_ports_*.csv 2>/dev/null | head -n 1 || true)"
if [[ -n "$latest_csv" && -s "$latest_csv" ]]; then
  TMP_DISCOVER_CSV="$latest_csv"
  latest_md="${latest_csv%.csv}.md"
  if [[ -f "$latest_md" ]]; then
    TMP_DISCOVER_MD="$latest_md"
  else
    TMP_DISCOVER_MD=""
  fi
  echo "Using latest discovery CSV: ${TMP_DISCOVER_CSV}" | tee -a "$LOG_FILE"
else
  discover_args=(
    --target "$DISCOVER_TARGET"
    --output-md "$TMP_DISCOVER_MD"
    --output-csv "$TMP_DISCOVER_CSV"
  )

  if [[ -n "$DISCOVER_CONTAINER" ]]; then
    discover_args+=(--container "$DISCOVER_CONTAINER")
  fi

  if ! "$DISCOVER_SCRIPT" "${discover_args[@]}" >> "$LOG_FILE" 2>&1; then
    echo "ERROR: discovery failed. See log: $LOG_FILE" >&2
    exit 2
  fi
fi

if [[ ! -s "$TMP_DISCOVER_CSV" ]]; then
  echo "ERROR: discovery CSV missing or empty: $TMP_DISCOVER_CSV" >&2
  exit 2
fi

tmp_ns_map="$(mktemp)"
cleanup() {
  rm -f "$tmp_ns_map"
}
trap cleanup EXIT

# Build one row per namespace: namespace|oru_port|adt_port
# Supports both current pipe-delimited rows and comma-delimited rows.
awk '
  function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
  NR == 1 {
    hdr = tolower($0)
    if (hdr ~ /^namespace[|,]/) {
      next
    }
  }
  {
    line = $0
    if (line ~ /^[[:space:]]*$/) {
      next
    }

    # Discover script writes a comma header but pipe-delimited data rows.
    if (index(line, "|") > 0) {
      n = split(line, f, "|")
    } else {
      n = split(line, f, ",")
    }

    if (n < 5) {
      next
    }

    ns = trim(f[1])
    svc = tolower(trim(f[3]))
    port = trim(f[4])

    if (ns == "" || ns == "namespace") {
      next
    }

    if (!(ns in seen)) {
      seen[ns] = 1
      order[++count] = ns
    }

    if (port !~ /^[0-9]+$/) {
      next
    }

    if (svc ~ /lab result/ || svc ~ /oru/) {
      if (!(ns in oru)) {
        oru[ns] = port
      }
      next
    }

    if (svc ~ /patient information/ || svc ~ /adt/ || svc ~ /pam/) {
      if (!(ns in adt)) {
        adt[ns] = port
      }
      next
    }

    if (!(ns in first)) {
      first[ns] = port
    } else if (!(ns in second) && port != first[ns]) {
      second[ns] = port
    }
  }
  END {
    for (i = 1; i <= count; i++) {
      ns = order[i]
      op = (ns in oru) ? oru[ns] : ((ns in first) ? first[ns] : "")
      ap = (ns in adt) ? adt[ns] : ((ns in second) ? second[ns] : ((ns in first) ? first[ns] : ""))
      print ns "|" op "|" ap
    }
  }
' "$TMP_DISCOVER_CSV" > "$tmp_ns_map"

if [[ ! -s "$tmp_ns_map" ]]; then
  echo "ERROR: no namespaces discovered from $TMP_DISCOVER_CSV" >&2
  exit 2
fi

{
  echo "# Namespace Connectivity Report"
  echo
  echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- CLI: ${CLI_SCRIPT}"
  echo "- ADT file: ${ADT_FILE}"
  echo "- Discovery CSV: ${TMP_DISCOVER_CSV}"
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

  if probe_oru "$namespace" "$oru_port"; then
    oru_result="$PASS_MARK"
  fi

  if probe_adt "$namespace" "$adt_port"; then
    adt_result="$PASS_MARK"
  fi

  if [[ "$oru_result" == "$PASS_MARK" && "$adt_result" == "$PASS_MARK" ]]; then
    overall="$PASS_MARK"
  fi

  echo "| ${row_num} | ${namespace} | ${oru_port:-N/A} | ${oru_result} | ${adt_port:-N/A} | ${adt_result} | ${overall} |" >> "$OUTPUT_FILE"
done < "$tmp_ns_map"

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
if [[ -n "$TMP_DISCOVER_MD" ]]; then
  echo "Discovery markdown: $TMP_DISCOVER_MD"
fi
echo "Discovery CSV: $TMP_DISCOVER_CSV"
