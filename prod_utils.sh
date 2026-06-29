#!/bin/bash

# Production utilities orchestration script
# Execute adm.utils commands on different environments
#
# Usage: ./prod_utils.sh <environment> <command> [arguments]
#        ./prod_utils.sh <command>          # defaults to local-dev
#
# Environments (platform-stage):
#   local-dev        - Local Docker dev container
#   local-prod       - Local Docker prod container
#   community-dev    - Local community dev container
#   community-prod   - Local community prod container
#   aws-dev          - AWS development instance
#   aws-prod         - AWS production instance
#
# Commands:
#   list    - List all Interop namespaces
#   recover - Recover all productions that need it
#   start   - Start all productions
#   stop    - Stop all productions
#   clean   - Clean all productions
#
# Examples:
#   ./prod_utils.sh list                      # local-dev list
#   ./prod_utils.sh local-dev recover         # local dev recover
#   ./prod_utils.sh community-prod start       # community prod start
#   ./prod_utils.sh aws-dev start             # AWS dev start
#   ./prod_utils.sh aws-prod stop             # AWS prod stop

# Source configuration if exists
if [ -f "./.env" ]; then
    source .env
fi

# Configuration defaults
IRIS_INSTANCE_NAME="${IRIS_INSTANCE_NAME:-iris-health-training}"
AWS_DEV_HOST="${AWS_DEV_HOST:-}"
AWS_DEV_USER="${AWS_DEV_USER:-ubuntu}"
AWS_PROD_HOST="${AWS_PROD_HOST:-}"
AWS_PROD_USER="${AWS_PROD_USER:-ubuntu}"
IRIS_CODE_PATH="${IRIS_CODE_PATH:-/code/adm/utils.py}"

# Container names per stage
LOCAL_DEV_CONTAINER="${LOCAL_DEV_CONTAINER:-${IRIS_INSTANCE_NAME}-dev}"
LOCAL_PROD_CONTAINER="${LOCAL_PROD_CONTAINER:-${IRIS_INSTANCE_NAME}-prod}"
COMMUNITY_DEV_CONTAINER="${COMMUNITY_DEV_CONTAINER:-${IRIS_INSTANCE_NAME}-dev-community}"
COMMUNITY_PROD_CONTAINER="${COMMUNITY_PROD_CONTAINER:-${IRIS_INSTANCE_NAME}-prod-community}"
AWS_DEV_CONTAINER="${AWS_DEV_CONTAINER:-${IRIS_INSTANCE_NAME}-dev}"
AWS_PROD_CONTAINER="${AWS_PROD_CONTAINER:-${IRIS_INSTANCE_NAME}-prod}"

# Report configuration
REPORTS_DIR="./reports"
REPORT_FILE="${REPORTS_DIR}/prod_utils_$(date +%Y%m%d_%H%M%S).md"
HISTORY_FILE="${REPORTS_DIR}/history.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to generate report with namespace details
generate_report() {
    local status=$1
    local elapsed=$2
    local environment=$3
    local command=$4
    local start_time=$5
    local end_time=$6
    local command_output=$7  # JSON output from command
    
    # Ensure reports directory exists
    mkdir -p "${REPORTS_DIR}"
    
    # Determine status string and icon
    local status_icon="❌"
    local status_badge="![Failed](https://img.shields.io/badge/Status-Failed-red)"
    if [ "${status}" -eq 0 ]; then
        status_icon="✅"
        status_badge="![Success](https://img.shields.io/badge/Status-Success-green)"
    fi
    
    # Create report file
    cat > "${REPORT_FILE}" << 'EOF'
# Production Utilities Execution Report

EOF
    
    echo "${status_badge}" >> "${REPORT_FILE}"
    
    cat >> "${REPORT_FILE}" << 'EOF'

## Execution Context

EOF
    
    cat >> "${REPORT_FILE}" << EOF
| Property | Value |
|----------|-------|
| **Timestamp** | $(date '+%Y-%m-%d %H:%M:%S') |
| **Environment** | \`${environment}\` |
| **Command** | \`${command}\` |
| **Start Time** | $(date -r ${start_time} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A") |
| **End Time** | $(date -r ${end_time} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A") |
| **Duration** | ${elapsed} |
| **Status** | ${status_icon} $([ "${status}" -eq 0 ] && echo "Success" || echo "Failed") |

EOF

    # For messages: add target window spec and resolved date range
    if [ "${command}" = "messages" ]; then
        local spec="${COMMAND_ARG:-0}"
        local fmt='+%A, %B %d, %Y'
        local label="" range=""
        if [[ "${spec}" == \** ]]; then
            local n="${spec#\*}"
            local d=$(date -v-${n}d "${fmt}" 2>/dev/null || date -d "-${n} days" "${fmt}" 2>/dev/null || echo "N/A")
            label="${spec} (before ${n} days ago)"
            range="up to ${d}"
        elif [[ "${spec}" == *\* ]]; then
            local n="${spec%\*}"
            local d=$(date -v-${n}d "${fmt}" 2>/dev/null || date -d "-${n} days" "${fmt}" 2>/dev/null || echo "N/A")
            label="${spec} (${n} days ago to today)"
            range="${d} → today"
        elif [[ "${spec}" == *-* ]]; then
            local a="${spec%-*}" b="${spec#*-}"
            local lo=$((a<b?a:b)) hi=$((a>b?a:b))
            local dlo=$(date -v-${hi}d "${fmt}" 2>/dev/null || date -d "-${hi} days" "${fmt}" 2>/dev/null || echo "N/A")
            local dhi=$(date -v-${lo}d "${fmt}" 2>/dev/null || date -d "-${lo} days" "${fmt}" 2>/dev/null || echo "N/A")
            label="${spec} (${hi} to ${lo} days ago)"
            range="${dlo} → ${dhi}"
        else
            local d=$(date -v-${spec}d "${fmt}" 2>/dev/null || date -d "-${spec} days" "${fmt}" 2>/dev/null || echo "N/A")
            label="${spec} (single day)"
            range="${d}"
        fi
        cat >> "${REPORT_FILE}" << EOF
| Property | Value |
|----------|-------|
| **Window Spec** | ${label} |
| **Target Date(s)** | ${range} |

EOF
    fi

    
    cat >> "${REPORT_FILE}" << 'EOF'

## Command Executed

```bash
EOF
    echo "./prod_utils.sh ${environment} ${command} ${COMMAND_ARG}" >> "${REPORT_FILE}"
    echo '```' >> "${REPORT_FILE}"
    
    # Add namespace table if available
    if [ -n "${command_output}" ] && [ -f "${command_output}" ]; then
        generate_namespaces_table "${command_output}" "${command}" >> "${REPORT_FILE}"
    fi
    
    cat >> "${REPORT_FILE}" << 'EOF'

## System Information

EOF
    
    cat >> "${REPORT_FILE}" << EOF
- **OS**: $(uname -s) $(uname -r)
- **Hostname**: $(hostname)
- **User**: $(whoami)
- **Working Directory**: $(pwd)

---
*Generated by prod_utils.sh at $(date '+%Y-%m-%d %H:%M:%S')*
EOF
    
    echo "${REPORT_FILE}"
    
    # Update history file
    local history_entry="| $(date '+%Y-%m-%d %H:%M:%S') | \`${environment}\` | \`${command}\` | ${status_icon} $([ "${status}" -eq 0 ] && echo "Success" || echo "Failed") | ${elapsed} |"
    
    if [ ! -f "${HISTORY_FILE}" ]; then
        cat > "${HISTORY_FILE}" << EOF
# Production Utilities Execution History

| Timestamp | Environment | Command | Status | Duration |
|-----------|-------------|---------|--------|----------|
${history_entry}
EOF
    else
        # Insert new entry at line 4 (after header table)
        awk -v entry="${history_entry}" 'NR==4 {print entry} {print}' "${HISTORY_FILE}" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "${HISTORY_FILE}"
    fi
    
    echo -e "${BLUE}📄 Report: ${REPORT_FILE}${NC}"
}

# Function to generate namespace results table from JSON
generate_namespaces_table() {
    local json_file=$1
    local command=$2
    
    if [ ! -f "${json_file}" ]; then
        return
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "\n> **Note**: jq not installed, detailed namespace results unavailable"
        echo "> Install jq to see namespace results: \`brew install jq\` or \`apt-get install jq\`\n"
        return
    fi
    
    # Validate JSON
    if ! jq empty "${json_file}" 2>/dev/null; then
        echo -e "\n> **Note**: Invalid JSON output - see raw output in reports/output_*.json\n"
        return
    fi
    
    # Check if JSON has namespaces
    local ns_count=$(jq '.namespaces | length' "${json_file}" 2>/dev/null)
    
    if [ -z "${ns_count}" ] || [ "${ns_count}" -eq 0 ]; then
        return
    fi
    
    echo ""
    echo "## Namespace Operation Results"
    echo ""
    
    # Build detailed table with status icons
    jq -r '.namespaces[] | 
        (if .status == "running" then "🟢 Running"
         elif .status == "stopped" then "⚫ Stopped"
         elif .status == "suspended" then "🟡 Suspended"
         elif .status == "need recover" then "🔴 Need Recover"
         elif .status == "error" then "❌ Error"
         else .status end) as $statusIcon |
        (if .result == "success" then "✅"
         elif .result == "failed" then "❌"
         else "⏳" end) as $resultIcon |
        "| \(.namespace) | \(if .production == "" then "—" else .production end) | \($statusIcon) | \($resultIcon) | \(.actions | join("<br>")) |"' \
        "${json_file}" 2>/dev/null | \
    {
        echo "| Namespace | Production | Status | Result | Actions |"
        echo "|-----------|------------|--------|--------|---------|"
        cat
    }
    
    # Add summary
    echo ""
    local summary=$(jq -r '.summary | "**Summary**: \(.total) namespaces · \(.success) ✅ · \(.failed) ❌"' "${json_file}" 2>/dev/null)
    if [ -n "${summary}" ] && [ "${summary}" != "null" ]; then
        echo "${summary}"
    fi

    # For messages: total message count across all namespaces
    if [ "${command}" = "messages" ]; then
        local total_msgs=$(jq -r '[.namespaces[].status | capture("(?<n>[0-9]+) messages") | .n | tonumber] | add // 0' "${json_file}" 2>/dev/null)
        echo ""
        echo "**Total messages (all namespaces)**: ${total_msgs}"
    fi
    echo ""
}

# Function to print help
print_help() {
    echo "Usage: $0 <environment> <command> [arguments]"
    echo "       $0 <command>               # defaults to 'local-dev' environment"
    echo ""
    echo "Environments:"
    echo "  local-dev        - Local Docker dev container"
    echo "  local-prod       - Local Docker prod container"
    echo "  community-dev    - Local community dev container"
    echo "  community-prod   - Local community prod container"
    echo "  aws-dev          - AWS development"
    echo "  aws-prod         - AWS production"
    echo ""
    echo "Commands:"
    echo "  list    - List all Interop namespaces"
    echo "  recover - Recover all troubled productions"
    echo "  start   - Start all productions"
    echo "  stop    - Stop all productions"
    echo "  clean   - Clean all production queues"
    echo "  messages [day] - Count MLLP/HTTP messages for a target day (0=today, 1=yesterday, 7=a week ago; default 0)"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 local-dev recover"
    echo "  $0 community-prod start"
    echo "  $0 aws-dev start"
    echo "  $0 aws-prod stop"
    echo "  $0 aws-dev messages 1"
    exit 0
}

# Validate command
validate_command() {
    case "$1" in
        list|recover|start|stop|clean|messages)
            return 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown command '$1'${NC}"
            echo "Valid commands: list, recover, start, stop, clean, messages"
            return 1
            ;;
    esac
}

# Resolve environment to mode/container/host/user
# Sets globals: ENV_MODE (docker|ssh), ENV_CONTAINER, ENV_HOST, ENV_USER
resolve_environment() {
    local env=$1
    ENV_MODE=""
    ENV_CONTAINER=""
    ENV_HOST=""
    ENV_USER=""
    
    case "${env}" in
        local-dev)
            ENV_MODE="docker"; ENV_CONTAINER="${LOCAL_DEV_CONTAINER}"
            ;;
        local-prod)
            ENV_MODE="docker"; ENV_CONTAINER="${LOCAL_PROD_CONTAINER}"
            ;;
        community-dev)
            ENV_MODE="docker"; ENV_CONTAINER="${COMMUNITY_DEV_CONTAINER}"
            ;;
        community-prod)
            ENV_MODE="docker"; ENV_CONTAINER="${COMMUNITY_PROD_CONTAINER}"
            ;;
        aws-dev)
            ENV_MODE="ssh"; ENV_CONTAINER="${AWS_DEV_CONTAINER}"; ENV_HOST="${AWS_DEV_HOST}"; ENV_USER="${AWS_DEV_USER}"
            ;;
        aws-prod)
            ENV_MODE="ssh"; ENV_CONTAINER="${AWS_PROD_CONTAINER}"; ENV_HOST="${AWS_PROD_HOST}"; ENV_USER="${AWS_PROD_USER}"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# Execute command on a local Docker container
execute_docker() {
    local container=$1
    local command=$2
    local output_file=$3
    echo -e "${BLUE}Executing on ${container} (LOCAL)...${NC}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}ERROR: Docker container '${container}' not found or not running${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Command: python3 ${IRIS_CODE_PATH} ${command} ${COMMAND_ARG}${NC}"
    # Capture output and extract JSON
    docker exec "${container}" python3 "${IRIS_CODE_PATH}" "${command}" "${COMMAND_ARG}" 2>&1 | python3 -c "
import sys
import json
output = sys.stdin.read()
start = output.find('{')
if start >= 0:
    depth = 0
    for i in range(start, len(output)):
        if output[i] == '{':
            depth += 1
        elif output[i] == '}':
            depth -= 1
            if depth == 0:
                print(output[start:i+1])
                break
" > "${output_file}" 2>&1
    return $?
}

# Execute command on a remote AWS container via SSH
execute_ssh() {
    local host=$1
    local user=$2
    local container=$3
    local command=$4
    local output_file=$5
    
    if [ -z "${host}" ]; then
        echo -e "${RED}ERROR: AWS host not configured${NC}"
        echo "Set the corresponding AWS host in .env or environment variables"
        return 1
    fi
    
    echo -e "${BLUE}Executing on ${container} (AWS ${host})...${NC}"
    echo -e "${YELLOW}Command: python3 ${IRIS_CODE_PATH} ${command} ${COMMAND_ARG}${NC}"
    
    local ssh_opts="-o StrictHostKeyChecking=no"
    if [ -n "${SSH_KEY}" ] && [ -f "${SSH_KEY}" ]; then
        ssh_opts="${ssh_opts} -i ${SSH_KEY}"
    fi
    
    ssh ${ssh_opts} "${user}@${host}" \
        "docker exec ${container} python3 ${IRIS_CODE_PATH} ${command} '${COMMAND_ARG}'" 2>&1 | python3 -c "
import sys
import json
output = sys.stdin.read()
start = output.find('{')
if start >= 0:
    depth = 0
    for i in range(start, len(output)):
        if output[i] == '{':
            depth += 1
        elif output[i] == '}':
            depth -= 1
            if depth == 0:
                print(output[start:i+1])
                break
" > "${output_file}" 2>&1
    return $?
}

# Determine environment and command
determine_args() {
    local arg1="${1:-}"
    local arg2="${2:-}"
    local arg3="${3:-}"
    COMMAND_ARG=""
    
    # If only one argument, check if it's a command (default to local-dev) or help
    if [ -z "${arg2}" ]; then
        case "${arg1}" in
            help|--help|-h)
                print_help
                ;;
            list|recover|start|stop|clean|messages)
                ENVIRONMENT="local-dev"
                COMMAND="${arg1}"
                ;;
            local-dev|local-prod|community-dev|community-prod|aws-dev|aws-prod|local|dev|prod)
                echo -e "${RED}ERROR: Environment specified but no command given${NC}"
                echo "Usage: $0 <environment> <command>"
                exit 1
                ;;
            *)
                echo -e "${RED}ERROR: Unknown argument '${arg1}'${NC}"
                print_help
                exit 1
                ;;
        esac
    else
        # If arg1 is a command, treat as: <command> [day] (default local-dev)
        case "${arg1}" in
            list|recover|start|stop|clean|messages)
                ENVIRONMENT="local-dev"
                COMMAND="${arg1}"
                COMMAND_ARG="${arg2}"
                return
                ;;
        esac

        # Two or more arguments: first is environment, second is command, third is optional arg
        ENVIRONMENT="${arg1}"
        COMMAND="${arg2}"
        COMMAND_ARG="${arg3}"
        
        # Backward-compatible aliases
        case "${ENVIRONMENT}" in
            local) ENVIRONMENT="local-dev" ;;
            dev)   ENVIRONMENT="aws-dev" ;;
            prod)  ENVIRONMENT="aws-prod" ;;
        esac
        
        case "${ENVIRONMENT}" in
            local-dev|local-prod|community-dev|community-prod|aws-dev|aws-prod)
                ;;
            *)
                echo -e "${RED}ERROR: Unknown environment '${ENVIRONMENT}'${NC}"
                print_help
                exit 1
                ;;
        esac
    fi
}

# Main execution
main() {
    local START_TIME=$(date +%s)
    
    if [ $# -eq 0 ]; then
        print_help
        exit 0
    fi
    
    determine_args "$@"
    
    if ! validate_command "${COMMAND}"; then
        local END_TIME=$(date +%s)
        local ELAPSED=$((END_TIME - START_TIME))
        local HOURS=$((ELAPSED / 3600))
        local MINUTES=$(((ELAPSED % 3600) / 60))
        local SECONDS=$((ELAPSED % 60))
        local ELAPSED_STR=$(printf "%dh %dm %ds" $HOURS $MINUTES $SECONDS)
        
        echo ""
        echo -e "${RED}✗ Command validation failed${NC}"
        echo -e "${BLUE}Elapsed time: ${ELAPSED_STR}${NC}"
        
        generate_report 1 "${ELAPSED_STR}" "${ENVIRONMENT}" "${COMMAND}" "${START_TIME}" "${END_TIME}" ""
        return 1
    fi
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Production Utilities - $(echo "${ENVIRONMENT}" | tr '[:lower:]' '[:upper:]')${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Ensure reports directory exists for output file
    mkdir -p "${REPORTS_DIR}"
    
    # Create permanent output file in reports directory
    local OUTPUT_FILE="${REPORTS_DIR}/output_$(date +%Y%m%d_%H%M%S).json"
    
    case "${ENVIRONMENT}" in
        local-dev|local-prod|community-dev|community-prod)
            resolve_environment "${ENVIRONMENT}"
            execute_docker "${ENV_CONTAINER}" "${COMMAND}" "${OUTPUT_FILE}"
            ;;
        aws-dev|aws-prod)
            resolve_environment "${ENVIRONMENT}"
            execute_ssh "${ENV_HOST}" "${ENV_USER}" "${ENV_CONTAINER}" "${COMMAND}" "${OUTPUT_FILE}"
            ;;
        *)
            echo -e "${RED}ERROR: Unknown environment${NC}"
            exit 1
            ;;
    esac
    
    local COMMAND_EXIT=$?
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local HOURS=$((ELAPSED / 3600))
    local MINUTES=$(((ELAPSED % 3600) / 60))
    local SECONDS=$((ELAPSED % 60))
    local ELAPSED_STR=$(printf "%dh %dm %ds" $HOURS $MINUTES $SECONDS)
    
    # Display output
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "$(cat ${OUTPUT_FILE})"
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    
    if [ $COMMAND_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ Command completed successfully${NC}"
        echo -e "${BLUE}Elapsed time: ${ELAPSED_STR}${NC}"
    else
        echo -e "${RED}✗ Command failed${NC}"
        echo -e "${BLUE}Elapsed time: ${ELAPSED_STR}${NC}"
    fi
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Generate report with output file reference (file persists)
    generate_report $COMMAND_EXIT "${ELAPSED_STR}" "${ENVIRONMENT}" "${COMMAND}" "${START_TIME}" "${END_TIME}" "${OUTPUT_FILE}"
    
    [ $COMMAND_EXIT -eq 0 ] && return 0 || return 1
}

# Run main
main "$@"
exit $?
