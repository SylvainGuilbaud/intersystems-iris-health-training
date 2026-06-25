#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLOUDENV_FILE="${ROOT_DIR}/cloudenv"

DEFAULT_TARGET="dev-aws"
TARGET="$DEFAULT_TARGET"
CONTAINER=""
OUTPUT_MD=""
OUTPUT_CSV=""

EXCLUDED_NAMESPACES=(
  "%ALL"
  "%SYS"
  "COMMON"
  "HSCUSTOM"
  "HSLIB"
  "HSSYS"
  "HSSYSLOCALTEMP"
  "USER"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [--target dev-aws|prod-aws|dev|prod] [--container NAME] [--output-md FILE] [--output-csv FILE]

Discover namespaces from an IRIS instance and extract MLLP business service
(EnsLib.HL7.Service.TCPService) port settings from production configuration.

Options:
  --target NAME      Target instance type (default: ${DEFAULT_TARGET})
                     - dev-aws / prod-aws: query remote AWS instance via SSH
                     - dev / prod: query local Docker instance
  --container NAME   Override container name inferred from target
  --output-md FILE   Markdown report output path
  --output-csv FILE  CSV report output path
  -h, --help         Show this help
EOF
}

resolve_container_from_target() {
  case "$TARGET" in
    dev-aws|dev)
      echo "iris-health-training-dev"
      ;;
    prod-aws|prod)
      echo "iris-health-training-prod"
      ;;
    *)
      echo ""
      ;;
  esac
}

is_excluded_namespace() {
  local ns="$1"
  local x
  for x in "${EXCLUDED_NAMESPACES[@]}"; do
    if [[ "$ns" == "$x" ]]; then
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      shift
      TARGET="${1:-}"
      ;;
    --container)
      shift
      CONTAINER="${1:-}"
      ;;
    --output-md)
      shift
      OUTPUT_MD="${1:-}"
      ;;
    --output-csv)
      shift
      OUTPUT_CSV="${1:-}"
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

if [[ -z "$CONTAINER" ]]; then
  CONTAINER="$(resolve_container_from_target)"
fi

if [[ -z "$CONTAINER" ]]; then
  echo "ERROR: invalid target '$TARGET'. Use dev-aws|prod-aws|dev|prod or set --container." >&2
  exit 1
fi

if [[ "$TARGET" == *"aws" ]]; then
  if [[ ! -f "$CLOUDENV_FILE" ]]; then
    echo "ERROR: cloudenv not found at '$CLOUDENV_FILE'." >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  source "$CLOUDENV_FILE"

  # cloudenv can provide a relative key path (e.g. ./iris/key/...).
  # Resolve it from the repository root so this script works from test/.
  if [[ -n "${ACCESS_KEY_FILENAME:-}" && "${ACCESS_KEY_FILENAME}" != /* ]]; then
    ACCESS_KEY_FILENAME="${ROOT_DIR}/${ACCESS_KEY_FILENAME#./}"
  fi

  if [[ -z "${ACCESS_KEY_FILENAME:-}" || -z "${CLOUD_USERNAME:-}" || -z "${PUBLIC_DNS:-}" ]]; then
    echo "ERROR: cloudenv is missing ACCESS_KEY_FILENAME, CLOUD_USERNAME, or PUBLIC_DNS." >&2
    exit 1
  fi
  if [[ ! -f "$ACCESS_KEY_FILENAME" ]]; then
    echo "ERROR: SSH key not found at '$ACCESS_KEY_FILENAME'." >&2
    exit 1
  fi
else
  if ! docker ps --format "{{.Names}}" | grep -Fxq "$CONTAINER"; then
    echo "ERROR: local container '$CONTAINER' is not running." >&2
    exit 1
  fi
fi

ts="$(date +%Y%m%d_%H%M%S)"
if [[ -z "$OUTPUT_MD" ]]; then
  OUTPUT_MD="${SCRIPT_DIR}/namespace_mllp_service_ports_${ts}.md"
fi
if [[ -z "$OUTPUT_CSV" ]]; then
  OUTPUT_CSV="${SCRIPT_DIR}/namespace_mllp_service_ports_${ts}.csv"
fi

tmp_ns_raw="$(mktemp)"
tmp_ns_filtered="$(mktemp)"
tmp_data="$(mktemp)"

cleanup() {
  rm -f "$tmp_ns_raw" "$tmp_ns_filtered" "$tmp_data"
}
trap cleanup EXIT

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

run_sql_shell() {
  local ns="$1"
  local query="$2"
  if [[ "$TARGET" == *"aws" ]]; then
    printf '%s\nq\n' "$query" | ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "docker exec -i $CONTAINER iris sql iris -U $ns" 2>&1 || true
  else
    printf '%s\nq\n' "$query" | docker exec -i "$CONTAINER" iris sql iris -U "$ns" 2>&1 || true
  fi
}

run_session_script() {
  local ns="$1"
  local script="$2"
  if [[ "$TARGET" == *"aws" ]]; then
    printf '%s\n' "$script" | ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "docker exec -i $CONTAINER iris session iris -U $ns" 2>&1 || true
  else
    printf '%s\n' "$script" | docker exec -i "$CONTAINER" iris session iris -U "$ns" 2>&1 || true
  fi
}

get_port_from_production_item() {
  local ns="$1"
  local item_id="$2"
  local script out
  printf -v script '%s\n' \
    "set obj=##class(Ens.Config.Item).%OpenId(${item_id})" \
    'set port=""' \
    'if $isobject(obj) {' \
    '  set found=obj.GetModifiedSetting("Port",.port)' \
    '  if ('\''found) {' \
    '    set found=obj.GetSetting("Port",.port)' \
    '  }' \
    '}' \
    'write "PORT=",$get(port),!' \
    'halt'
  out="$(run_session_script "$ns" "$script")"
  printf '%s\n' "$out" | awk -F'PORT=' '/PORT=/{print $2; exit}' | sed 's/^ *//; s/ *$//'
}

parse_sql_table_rows() {
  awk -F'|' '
    /^\|/ {
      for (i = 1; i <= NF; i++) {
        gsub(/^ +| +$/, "", $i)
      }
      if ($2 == "" || $2 == "--" || $2 == "PRODUCTION" || $2 == "ID") {
        next
      }
      out = ""
      for (i = 2; i < NF; i++) {
        out = out ((i == 2) ? "" : "|") $i
      }
      print out
    }
  '
}

parse_item_rows() {
  awk -F'|' '
    /^\|/ {
      for (i = 1; i <= NF; i++) {
        gsub(/^ +| +$/, "", $i)
      }
      if ($2 == "" || $2 == "--" || toupper($2) == "ITEM_ID" || toupper($3) == "PRODUCTION") {
        next
      }
      out = ""
      for (i = 2; i < NF; i++) {
        out = out ((i == 2) ? "" : "|") $i
      }
      print out
    }
  '
}

# Step 1: retrieve namespaces from Config.Namespaces in %SYS (same source family as portal configuration).
ns_query="SELECT DISTINCT Name FROM Config.Namespaces WHERE SectionHeader='Namespaces' ORDER BY Name;"
ns_out="$(run_sql_shell "%SYS" "$ns_query")"
printf '%s\n' "$ns_out" \
  | awk -F'|' '/^\|/ { for(i=1;i<=NF;i++){ gsub(/^ +| +$/, "", $i) } h=toupper($2); if($2=="" || $2=="--" || h=="NAME") next; print $2 }' \
  > "$tmp_ns_raw"

if [[ ! -s "$tmp_ns_raw" ]]; then
  if printf '%s\n' "$ns_out" | grep -Eqi 'Permission denied|Identity file .* not accessible|No such file|Connection (timed out|refused)|Could not resolve hostname'; then
    echo "ERROR: namespace query failed before SQL parsing (SSH/auth/connectivity)." >&2
    echo "$ns_out" >&2
    exit 2
  fi
  echo "ERROR: no namespaces found from Config.Namespaces on container '$CONTAINER'." >&2
  exit 2
fi

# Step 2: filter namespaces and query MLLP services from Item.
# Port retrieval priority:
# 1) production item settings (Ens.Config.Item / production config)
# 2) Ens_Config.DefaultSettings fallback when no explicit production value is found
while IFS= read -r ns; do
  [[ "$ns" =~ ^[%A-Za-z][%A-Za-z0-9_-]*$ ]] || continue
  is_excluded_namespace "$ns" && continue
  printf '%s\n' "$ns" >> "$tmp_ns_filtered"
  item_query="SELECT i.ID AS ITEM_ID, i.Production AS PRODUCTION, i.Name AS SERVICE, i.Enabled AS ENABLED FROM Ens_Config.Item i WHERE i.ClassName='EnsLib.HL7.Service.TCPService' ORDER BY i.Name;"
  item_out="$(run_sql_shell "$ns" "$item_query")"
  item_rows="$(printf '%s\n' "$item_out" | parse_item_rows)"

  if [[ -n "$item_rows" ]]; then
    while IFS='|' read -r item_id production service enabled; do
      port=""
      if [[ -n "${item_id:-}" ]]; then
        port="$(get_port_from_production_item "$ns" "$item_id")"
      fi
      service_esc="$(sql_escape "$service")"
      production_esc="$(sql_escape "$production")"

      if [[ -z "$port" ]]; then
        # Fallback source for port settings
        # SELECT ID, Deployable, Description, HostClassName, ItemName, ProductionName, SettingName, SettingValue
        # FROM Ens_Config.DefaultSettings
        default_query="SELECT ID, Deployable, Description, HostClassName, ItemName, ProductionName, SettingName, SettingValue FROM Ens_Config.DefaultSettings WHERE SettingName='Port' AND ItemName='${service_esc}' AND (ProductionName='${production_esc}' OR ProductionName='*') ORDER BY ID;"
        default_out="$(run_sql_shell "$ns" "$default_query")"
        default_rows="$(printf '%s\n' "$default_out" | parse_sql_table_rows)"

        if [[ -n "$default_rows" ]]; then
          # Prefer a production-specific row over wildcard row.
          while IFS= read -r ds_row; do
            prodname="$(printf '%s\n' "$ds_row" | awk -F'|' '{print $(NF-2)}')"
            settingvalue="$(printf '%s\n' "$ds_row" | awk -F'|' '{print $NF}')"
            if [[ "$prodname" == "$production" && -n "${settingvalue:-}" ]]; then
              port="$settingvalue"
              break
            fi
            if [[ -z "$port" && -n "${settingvalue:-}" ]]; then
              port="$settingvalue"
            fi
          done <<< "$default_rows"
        fi
      fi

      if [[ -z "$port" ]]; then
        port="<NO_PORT_IN_DEFAULTSETTINGS>"
      fi
      printf '%s|%s|%s|%s|%s\n' "$ns" "$production" "$service" "$port" "${enabled:-0}" >> "$tmp_data"
    done <<< "$item_rows"
  elif printf '%s\n' "$item_out" | grep -q 'ERROR #'; then
    printf '%s|<SQL_ERROR>|<SQL_ERROR>||0\n' "$ns" >> "$tmp_data"
  else
    printf '%s|%s|%s|%s|0\n' "$ns" "<NO_TCP_SERVICE_ITEMS>" "<NO_MLLP_BUSINESS_SERVICE>" "<NOT_CONFIGURED>" >> "$tmp_data"
  fi
done < "$tmp_ns_raw"

if [[ ! -s "$tmp_data" ]]; then
  echo "ERROR: no namespace/MLLP data could be retrieved from container '$CONTAINER'." >&2
  exit 2
fi

{
  echo "namespace,production,service,port,enabled"
  cat "$tmp_data"
} > "$OUTPUT_CSV"

{
  echo "# Namespace MLLP Business Service Port Report"
  echo
  echo "- Generated: $(date +%Y-%m-%dT%H:%M:%S)"
  echo "- Target: ${TARGET}"
  echo "- Container: ${CONTAINER}"
  if [[ "$TARGET" == *"aws" ]]; then
    echo "- Remote host: ${PUBLIC_DNS}"
  fi
  echo "- Discovered namespaces (raw): $(wc -l < "$tmp_ns_raw" | tr -d ' ')"
  echo "- Discovered namespaces (after exclusion): $(sort -u "$tmp_ns_filtered" | wc -l | tr -d ' ')"
  echo "- Excluded namespaces: %ALL, %SYS, COMMON, HSCUSTOM, HSLIB, HSSYS, HSSYSLOCALTEMP, USER"
  echo
  echo "## Namespaces Queried"
  echo
  while IFS= read -r qns; do
    echo "- $qns"
  done < <(sort -u "$tmp_ns_filtered")
  echo
  echo "| Namespace | Production | MLLP Business Service | Port | Enabled |"
  echo "|---|---|---|---:|---:|"
  while IFS='|' read -r ns prod svc port enabled; do
    printf '| %s | %s | %s | %s | %s |\n' "$ns" "$prod" "$svc" "${port:-}" "${enabled:-0}"
  done < "$tmp_data"
} > "$OUTPUT_MD"

echo "Markdown report: $OUTPUT_MD"
echo "CSV report: $OUTPUT_CSV"
