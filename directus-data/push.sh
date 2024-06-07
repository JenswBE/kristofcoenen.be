#!/bin/bash

# Download test data

# Bash strict mode based on http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Start a session
BASE_URL=http://localhost:8055
CURL_OPTS="--fail-with-body --silent --show-error"
SESSION_COOKIE=$(curl $CURL_OPTS -H "Content-Type: application/json" -c - -d '{"email":"admin@example.com", "password": "admin", "mode": "session"}' "$BASE_URL/auth/login")
SCRIPT_DIR="$( dirname -- "$BASH_SOURCE"; )";

# Push files
FOLDERS=$(curl $CURL_OPTS -b <(echo "$SESSION_COOKIE") "$BASE_URL/folders")
FOLDER_ID_REALISATIES=$(jq -r '.data[] | select(.name=="Realisaties") | .id' <(echo "$FOLDERS"))
push_file () {
  local FILENAME="$1"
  local FILE_PATH="${SCRIPT_DIR}/files/${FILENAME}"
  local FILE_ID="$2"
  local FOLDER_ID="$3"
  echo "Uploading file ${FILE_PATH} with ID ${FILE_ID} to folder ${FOLDER_ID} ..."
  curl $CURL_OPTS -X PATCH -b <(echo "$SESSION_COOKIE") -o /dev/null -F id=${FILE_ID} -F folder="${FOLDER_ID}" -F file="@${FILE_PATH}" "$BASE_URL/files/${FILE_ID}"
}
push_file 'poorten.jpg' 'faf63493-8440-4be1-9239-d42c8042861a' "${FOLDER_ID_REALISATIES}"
push_file 'verlichting.jpg' 'c1eb4e2d-dcad-4ccf-9172-d372b5a20b6a' "${FOLDER_ID_REALISATIES}"
push_file 'verlichting2.jpg' 'b60fb273-9476-4ea7-8f9d-7085ff587e7a' "${FOLDER_ID_REALISATIES}"

# Push collections
push_collection () {
  local COLLECTION_NAME="$1"
  local FILE_PATH="${SCRIPT_DIR}/${COLLECTION_NAME}.json"
  echo "Importing collection ${COLLECTION_NAME} from file ${FILE_PATH} ..."
  curl $CURL_OPTS -b <(echo "$SESSION_COOKIE") -F file="@${FILE_PATH};type=application/json" "$BASE_URL/utils/import/${COLLECTION_NAME}"
}
push_collection "flow_debounce"
push_collection "general_settings"
push_collection "realisations"
push_collection "realisations_files"
