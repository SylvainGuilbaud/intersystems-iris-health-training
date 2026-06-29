#!/bin/bash
# Wrapper script to call adm.utils methods from IRIS
# Usage: ./utils.sh list|recover|start|stop|clean

set -e

COMMAND=${1:-list}
IRIS_HOME=${IRIS_HOME:-/opt/irishealth}

# Map command to ObjectScript method name
case "$COMMAND" in
    list)
        METHOD="ListInteropNamespaces"
        ;;
    recover)
        METHOD="RecoverAllProductions"
        ;;
    start)
        METHOD="StartAllProductions"
        ;;
    stop)
        METHOD="StopAllProductions"
        ;;
    clean)
        METHOD="CleanAllProductions"
        ;;
    *)
        echo "Usage: $0 [list|recover|start|stop|clean]"
        echo ""
        echo "Commands:"
        echo "  list    - List all Interop namespaces"
        echo "  recover - Recover all productions that need it"
        echo "  start   - Start all productions"
        echo "  stop    - Stop all productions"
        echo "  clean   - Clean all productions"
        exit 1
        ;;
esac

# Call the ObjectScript method through IRIS
iris session IRIS -U "TRAINING" <<EOF
d ##class(adm.utils).$METHOD()
h
EOF
