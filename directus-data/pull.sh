#!/bin/bash

# Download test data

# Bash strict mode based on http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Start a session
BASE_URL=http://localhost:8055
CURL_OPTS="--fail-with-body --silent --show-error"
SESSION_COOKIE=$(curl $CURL_OPTS -H "Content-Type: application/json" -c - -d '{"email":"admin@example.com", "password": "admin", "mode": "session"}' "$BASE_URL/auth/login")
SCRIPT_DIR="$( dirname -- "$BASH_SOURCE"; )";

# Helpers
derive_fields_query() {
  local FIELDS="${1}"
  local IFS=","
  local FIELDS_QUERY=""
  for field in $FIELDS; do
    FIELDS_QUERY+="&fields[]="
    FIELDS_QUERY+="${field}"
  done
  unset IFS
  echo "${FIELDS_QUERY}"
}

format_json() {
  local FILE_PATH="${1}"
  jq . "${FILE_PATH}" > "${FILE_PATH}.tmp"
  mv "${FILE_PATH}.tmp" "${FILE_PATH}"
}

# Fetch collections
pull_collection () {
  local COLLECTION_NAME="$1"
  local FIELDS_QUERY="$(derive_fields_query "${2:-}")"
  local FILE_PATH="${SCRIPT_DIR}/${COLLECTION_NAME}.json"
  echo "Exporting collection ${COLLECTION_NAME} to file ${FILE_PATH} ..."
  curl $CURL_OPTS -b <(echo "$SESSION_COOKIE") "$BASE_URL/items/${COLLECTION_NAME}?export=json${FIELDS_QUERY}" > "${FILE_PATH}"
  format_json "${FILE_PATH}"
}
pull_collection "flow_debounce"
pull_collection "realisations" "id,sort,name,slug,main_image"
pull_collection "realisations_files"

# Fetch singletons (import only supports arrays)
pull_singleton () {
  local SINGLETON_NAME="$1"
  local FIELDS_QUERY="$(derive_fields_query "${2:-}")"
  local FILE_PATH="${SCRIPT_DIR}/${SINGLETON_NAME}.json"
  echo "Exporting singleton ${SINGLETON_NAME} to file ${FILE_PATH} ..."
  echo '[' > "${FILE_PATH}"
  curl $CURL_OPTS -b <(echo "$SESSION_COOKIE") "$BASE_URL/items/${SINGLETON_NAME}?export=json${FIELDS_QUERY}" >> "${FILE_PATH}"
  echo -e '\n]' >> "${FILE_PATH}"
  format_json "${FILE_PATH}"
}
pull_singleton "general_settings"
