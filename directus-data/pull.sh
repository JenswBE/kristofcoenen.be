#!/bin/bash

# Download test data

# Bash strict mode based on http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Settings
SCRIPT_DIR="$( dirname -- "$BASH_SOURCE"; )";

# Source helpers
. ${SCRIPT_DIR:?}/helpers.sh

# Pull collections
pull_collection "flow_debounce"
pull_collection "realisations" "id,sort,name,slug,main_image"
pull_collection "realisations_files"

# Pull singletons
pull_singleton "general_settings"
