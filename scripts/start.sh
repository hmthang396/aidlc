#!/usr/bin/env bash
set -euo pipefail

# Must run from workspace root (where .env and docker-compose.yml live)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ "$(pwd)" != "${WORKSPACE_ROOT}" ]; then
  echo "ERROR: Run this script from the workspace root: ${WORKSPACE_ROOT}"
  echo "  cd ${WORKSPACE_ROOT} && bash scripts/start.sh"
  exit 1
fi

# Safe env var loading — avoids xargs word-splitting on values with spaces/special chars
if [ -f .env ]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    key="${line%%=*}"
    [[ "$key" =~ ^(PROJECT_NAME|PORT_MCP|NEO4J_HTTP_PORT|NEO4J_BOLT_PORT|HOST_BIND)$ ]] || continue
    export "$line"
  done < .env
fi

PROJECT_NAME="${PROJECT_NAME:-workspace}"
NETWORK_NAME="${PROJECT_NAME}-network"
PORT_MCP="${PORT_MCP:-8001}"
NEO4J_HTTP_PORT="${NEO4J_HTTP_PORT:-7474}"
HOST_BIND="${HOST_BIND:-127.0.0.1}"

# Create network if absent
if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
  echo "Creating network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
fi

docker compose --project-name "${PROJECT_NAME}" --profile default up -d "$@"
echo ""
echo "Services started. Check health:"
echo "  Graphiti MCP : curl http://${HOST_BIND}:${PORT_MCP}/health"
echo "  Neo4j Browser: http://${HOST_BIND}:${NEO4J_HTTP_PORT}"
echo ""
echo "NOTE: Ports are bound to ${HOST_BIND}. Set HOST_BIND=0.0.0.0 in .env for team/remote access."
