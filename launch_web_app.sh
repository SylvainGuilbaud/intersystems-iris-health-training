#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/iris/angular"

# Install dependencies on first run (node_modules is git-ignored)
if [ ! -d node_modules ]; then
  echo "Installing Angular dependencies (first run)..."
  npm install
fi

npx ng serve