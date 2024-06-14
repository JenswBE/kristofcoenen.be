# Running locally

```bash
# Start Directus
podman compose pull
podman compose build --pull
podman compose up -d

# Start Directus again
# Podman Compose doesn't consider condition "service_healthy".
# Therefore, Directus tries to start before DB is healthy and fails to start.
# See https://github.com/containers/podman-compose/issues/866 for more info
podman compose restart directus

# Sync collections and data
npx directus-sync push -c directus-sync/local.js
./directus-data/push.sh

# Run static site generator
sudo apt install -y build-essential libssl-dev pkg-config
cargo install cargo-watch
cargo watch -x run

# In another terminal
cd output
python3 -m http.server
```

# Update schema's

```bash
# Pull settings from local
npx directus-sync pull -c directus-sync/local.js

# Setup config for Prod
cp directus-sync/local.js directus-sync/prod.secret.js
editor directus-sync/prod.secret.js

# Compare local with Prod
npx directus-sync diff --debug -c directus-sync/prod.secret.js

# Push state to Prod
npx directus-sync push -c directus-sync/prod.secret.js
```

# Updating GraphQL schema

```bash
cargo install --locked cynic-cli
KRISTOFCOENEN_API_BASE_URL=''
KRISTOFCOENEN_API_KEY=''
cynic introspect -H "Authorization: Bearer ${KRISTOFCOENEN_API_KEY:?}" "${KRISTOFCOENEN_API_BASE_URL:?}/graphql" -o schemas/directus.graphql
```
