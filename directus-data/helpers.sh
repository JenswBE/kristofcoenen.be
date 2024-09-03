# Bash strict mode based on http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Settings
export BASE_URL=http://localhost:8055
export SCRIPT_DIR="$( dirname -- "$BASH_SOURCE"; )";

# Helpers
dcurl () {
	curl --fail-with-body --silent --show-error -H 'Authorization: Bearer token_admin' $*
}

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

pull_collection () {
	local COLLECTION_NAME="$1"
	local FIELDS_QUERY="$(derive_fields_query "${2:-}")"
	local FILE_PATH="${SCRIPT_DIR}/${COLLECTION_NAME}.json"
	echo "Exporting collection ${COLLECTION_NAME} to file ${FILE_PATH} ..."
	dcurl "$BASE_URL/items/${COLLECTION_NAME}?export=json${FIELDS_QUERY}" > "${FILE_PATH}"
	format_json "${FILE_PATH}"
}

pull_singleton () {
	# Note: import only supports arrays!
	local SINGLETON_NAME="$1"
	local FIELDS_QUERY="$(derive_fields_query "${2:-}")"
	local FILE_PATH="${SCRIPT_DIR}/${SINGLETON_NAME}.json"
	echo "Exporting singleton ${SINGLETON_NAME} to file ${FILE_PATH} ..."
	echo '[' > "${FILE_PATH}"
	dcurl "$BASE_URL/items/${SINGLETON_NAME}?export=json${FIELDS_QUERY}" >> "${FILE_PATH}"
	echo -e '\n]' >> "${FILE_PATH}"
	format_json "${FILE_PATH}"
}

get_folder_id_by_name() {
		dcurl "$BASE_URL/folders" | jq -r ".data[] | select(.name==\"${1:?}\") | .id"
}

push_file () {
	local FILENAME="$1"
	local FILE_PATH="${SCRIPT_DIR}/files/${FILENAME}"
	local FILE_ID="$2"
	local FOLDER_ID="$3"
	echo "Uploading file ${FILE_PATH} with ID ${FILE_ID} to folder ${FOLDER_ID} ..."
	dcurl -X PATCH -o /dev/null -F id=${FILE_ID} -F folder="${FOLDER_ID}" -F file="@${FILE_PATH}" "$BASE_URL/files/${FILE_ID}"
}

push_collection () {
	local COLLECTION_NAME="$1"
	local FILE_PATH="${SCRIPT_DIR}/${COLLECTION_NAME}.json"
	echo "Importing collection ${COLLECTION_NAME} from file ${FILE_PATH} ..."
	dcurl -F file="@${FILE_PATH};type=application/json" "$BASE_URL/utils/import/${COLLECTION_NAME}"
}

push_local_user () {
	USER_ID_LOCAL="21b8c77e-fa3f-4b6e-84c5-6249121422f1"
	ROLES=$(dcurl "$BASE_URL/roles")
	ROLE_GENERATOR=$(jq -r '.data[] | select(.name=="Static site generator") | .id' <(echo "$ROLES"))
	dcurl -X DELETE "$BASE_URL/users/${USER_ID_LOCAL:?}" 2> /dev/null || true
	dcurl -o /dev/null --json @- "$BASE_URL/users" <<-EOF
	{
	"id": "${USER_ID_LOCAL:?}",
	"first_name": "Local",
	"role": "${ROLE_GENERATOR:?}",
	"token": "token_generator"
	}
	EOF
}
