#!/bin/bash
set -u

TARGET=${1:-dev-community}

case "$TARGET" in
  dev-community)
    CONTAINER="iris-health-training-dev-community"
    NAMESPACE="iris-health-training-dev"
    HOST_PORTS=(39001 39002)
    ;;
  prod-community)
    CONTAINER="iris-health-training-prod-community"
    NAMESPACE="iris-health-training-prod"
    HOST_PORTS=(39501 39502)
    ;;
  *)
    echo "Usage: $0 [dev-community|prod-community]"
    exit 1
    ;;
esac

echo "== IRIS community connectivity diagnostic =="
echo "TARGET=$TARGET"
echo "CONTAINER=$CONTAINER"
echo

FAIL=0

# 0) Running IRIS instances pressure check
RUNNING_IRIS=$(docker ps --format '{{.Names}}' | grep -E '^iris-health-training-(dev|prod)-community?$' | wc -l | tr -d ' ')
echo "[INFO] Running IRIS instances detected: $RUNNING_IRIS"
if [[ "$RUNNING_IRIS" -gt 2 ]]; then
  echo "[WARN] More than 2 IRIS instances are running; Community license/process pressure may cause intermittent resets."
fi

# 1) Container status
if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER"; then
  STATUS=$(docker ps --format '{{.Names}}\t{{.Status}}' | awk -F '\t' -v c="$CONTAINER" '$1==c {print $2}')
  echo "[OK] Container running: $STATUS"
else
  echo "[FAIL] Container '$CONTAINER' is not running"
  FAIL=1
fi

# 2) Host port reachability
for p in "${HOST_PORTS[@]}"; do
  if nc -z localhost "$p" >/dev/null 2>&1; then
    echo "[OK] Host port reachable: localhost:$p"
  else
    echo "[FAIL] Host port NOT reachable: localhost:$p"
    FAIL=1
  fi
done

# 3) Listener inside container
if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER"; then
  LISTEN_OUT=$(docker exec "$CONTAINER" sh -lc "ss -lnt 2>/dev/null || netstat -lnt 2>/dev/null || true")
  for cp in "${HOST_PORTS[@]}"; do
    if printf '%s\n' "$LISTEN_OUT" | grep -q ":$cp\b"; then
      echo "[OK] IRIS listener present in container on :$cp"
    else
      echo "[WARN] No listener found in container on :$cp"
    fi
  done
fi

# 4) Session/license quick check
if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER"; then
  SESSION_OUT=$(docker exec -i "$CONTAINER" iris session IRIS <<'EOF'
write "OK_SESSION",!
halt
EOF
  2>&1 || true)

  if printf '%s\n' "$SESSION_OUT" | grep -q 'LICENSE LIMIT EXCEEDED'; then
    echo "[FAIL] LICENSE LIMIT EXCEEDED detected"
    FAIL=1
  elif printf '%s\n' "$SESSION_OUT" | grep -q 'OK_SESSION'; then
    echo "[OK] IRIS session check passed"
  else
    echo "[WARN] Unable to confirm session check"
    echo "------ session output (tail) ------"
    printf '%s\n' "$SESSION_OUT" | tail -n 20
    echo "-----------------------------------"
    FAIL=1
  fi
fi

# 5) End-to-end MLLP probes (detect intermittent connection resets)
if command -v python3 >/dev/null 2>&1; then
  echo "[INFO] Running MLLP probes (5 attempts per port, timeout=3s) ..."
  PROBE_OUT=$(python3 - "$TARGET" <<'PY'
import socket
import sys
from datetime import datetime

target = sys.argv[1]
ports = {
  "dev-community": [39001, 39002],
  "prod-community": [39501, 39502],
}[target]

def build_msg(kind: str, msg_id: str) -> str:
  ts = datetime.now().strftime("%Y%m%d%H%M%S")
  if kind == "ADT":
    return (
      f"MSH|^~\\&|EMETTEUR|ETABLISSEMENT|DATAMED|LAB|{ts}||ADT^A08^ADT_A08|{msg_id}|P|2.5|||NE|AL|FRA|8859/1\r"
      f"EVN|A08|{ts}\r"
      "PID|1||24445670^^^ETABLISSEMENT&1.2.250.1.99.1&ISO^PI~285031512345678^^^INS-NIR&1.2.250.1.213.1.4.8&ISO^INS-NIR||VERSAIRE^Anne^^^^^D~VERSAIRE^Anne^^^^^L||19850124|F|||15 RUE DE LA PAIX^^PARIS^^75001^FRA^H||||||||||||||||||||75056\r"
      "PV1|1|N\r"
      f"ZBE|MVT-003^ETABLISSEMENT^1.2.250.1.99.1^ISO|{ts}||INSERT|N|A08\r"
    )
  return (
    f"MSH|^~\\&|DGLab|LAB|OpenMedical|KIS|{ts}||ORU^R01|{msg_id}|P|2.3|||||CH|8859/1|de\r"
    "PID|1||18^^^LAB^PI~24445670^^^ASIP-SANTE-INS-NIA&1.2.250.1.213.1.4.9&ISO^INS-NIA||VERSAIRE^Anne^^^^^L||19850124|F|||^^^^^^H||||F|||||||||||||||||VALI\r"
    "PV1|1|I|^^^||||||||||||||||0|||||||||||||||||||||||||202605280000|190001010000|||||17\r"
    f"ORC|SC|||6100130|IP||||{ts}|||3|||{ts}\r"
    f"OBR|1|||296^S-Sodium^L|||{ts}|20260610141505||||||||3|||||||||F\r"
    "OBX|1|TX|296^S-Sodium^L|1|139||||||F||\r"
  )

def probe(port: int, msg: str, timeout: float = 3.0):
  data = b"\x0b" + msg.encode("utf-8") + b"\x1c\x0d"
  with socket.create_connection(("127.0.0.1", port), timeout=timeout) as s:
    s.settimeout(timeout)
    s.sendall(data)
    resp = s.recv(4096)
  text = resp.decode("utf-8", errors="replace")
  ok = ("MSA|CA|" in text) or ("ACK^" in text)
  return ok, text

attempts = 5
overall_ok = True
for port in ports:
  kind = "ORU" if str(port).endswith("01") else "ADT"
  ok_count = 0
  fail_count = 0
  for i in range(1, attempts + 1):
    msg_id = f"DIAG{port}{i:03d}"
    try:
      ok, text = probe(port, build_msg(kind, msg_id))
      if ok:
        ok_count += 1
      else:
        fail_count += 1
        overall_ok = False
        first = text.replace("\r", " ").strip()[:140]
        print(f"[FAIL] MLLP port {port} attempt {i}/{attempts}: no ACK marker. resp={first}")
    except Exception as e:
      fail_count += 1
      overall_ok = False
      print(f"[FAIL] MLLP port {port} attempt {i}/{attempts}: {e}")
  print(f"[INFO] MLLP summary port {port}: ok={ok_count} fail={fail_count} attempts={attempts}")

if overall_ok:
  print("[OK] MLLP probes passed on all target ports")
  sys.exit(0)

print("[FAIL] MLLP probes detected intermittent or persistent send/ACK failures")
sys.exit(3)
PY
  )
  PROBE_CODE=$?
  printf '%s\n' "$PROBE_OUT"
  if [[ "$PROBE_CODE" -ne 0 ]]; then
  FAIL=1
  fi
else
  echo "[WARN] python3 not found; skipping MLLP probes"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT=OK"
  exit 0
fi

echo "RESULT=FAIL"
echo "Hint: if checks pass but DGLAB still fails, keep this script running repeatedly and correlate failure timestamps with DGLAB.log."
exit 2
