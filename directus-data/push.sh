#!/bin/bash

# Download test data

# Bash strict mode based on http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Settings
SCRIPT_DIR="$( dirname -- "$BASH_SOURCE"; )";

# Source helpers
. ${SCRIPT_DIR:?}/helpers.sh

# Push files
FOLDER_ID_REALISATIES=$(get_folder_id_by_name 'Realisaties')
push_file 'poorten.jpg' 'faf63493-8440-4be1-9239-d42c8042861a' "${FOLDER_ID_REALISATIES}"
push_file 'verlichting.jpg' 'c1eb4e2d-dcad-4ccf-9172-d372b5a20b6a' "${FOLDER_ID_REALISATIES}"
push_file 'verlichting2.jpg' 'b60fb273-9476-4ea7-8f9d-7085ff587e7a' "${FOLDER_ID_REALISATIES}"

# Push collections
push_collection "flow_debounce"
push_collection "general_settings"
push_collection "realisations"
push_collection "realisations_files"

# Push users
push_local_user
