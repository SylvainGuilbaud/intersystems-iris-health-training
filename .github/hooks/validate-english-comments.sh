#!/bin/bash
# Companion script: Validate that code comments are in English
# Detects common French comment patterns in ObjectScript and other code files

FILE_PATH="${1:-}"
NEW_CONTENT="${2:-}"

# Skip if no content provided
if [ -z "$NEW_CONTENT" ]; then
    exit 0
fi

# Patterns for French comments (common abbreviations and keywords)
FRENCH_PATTERNS=(
    "Récupère"
    "Vérif"
    "Exécute"
    "Retour"
    "Connexion"
    "Erreur"
    "Namespace"
    "Statut"
    "Se connecter"
    "Sur ceux"
    "Optionnel"
    "Exclusion"
    "Attention"
)

# Check for French comment patterns
FOUND_FRENCH=0
for pattern in "${FRENCH_PATTERNS[@]}"; do
    if echo "$NEW_CONTENT" | grep -q "//.*$pattern\|///.*$pattern"; then
        echo "⚠️  WARNING: Detected French comment pattern '$pattern' in code comments"
        FOUND_FRENCH=1
    fi
done

if [ $FOUND_FRENCH -eq 1 ]; then
    echo "📝 Policy reminder: All code comments should be in English"
    echo "   This helps ensure consistency across the international team"
    exit 0  # Warn but don't block
fi

exit 0
