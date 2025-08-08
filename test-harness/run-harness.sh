#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1) Read image namespace and tag from application.properties
PROPS_FILE="$SCRIPT_DIR/application.properties"
if [[ ! -f "$PROPS_FILE" ]]; then
  echo "[harness] application.properties not found at $PROPS_FILE" >&2
  exit 1
fi

source "$PROPS_FILE"

IMAGE_NAMESPACE="${docker_image_name:-defradigital}"
IMAGE_TAG="${docker_image_version:-latest}"

ENV_FILE="$SCRIPT_DIR/.env"

echo "[harness] Using images: ${IMAGE_NAMESPACE}/*:${IMAGE_TAG}"
if [[ -f "$ENV_FILE" ]]; then
  echo "[harness] Using env file: $ENV_FILE"
else
  echo "[harness] No .env found at $ENV_FILE (using process env only)"
fi

# 2) Start a single merged Docker Compose project (infra + apps)
#    The first -f points at local-development-dependencies so its relative volume paths (e.g. ./compose/start-localstack.sh) resolve correctly.
#    IMAGE_NAMESPACE and IMAGE_TAG are used for image interpolation in the test harness compose file.
echo "[harness] Starting infra and application stack (merged compose files)..."
COMPOSE_PROJECT_NAME="forms-harness" IMAGE_NAMESPACE="$IMAGE_NAMESPACE" IMAGE_TAG="$IMAGE_TAG" \
  docker compose \
  ${ENV_FILE:+--env-file "$ENV_FILE"} \
  -f "$ROOT_DIR/local-development-dependencies/docker-compose.yml" \
  -f "$SCRIPT_DIR/docker-compose.yml" \
  up -d

echo "[harness] Test harness started."
