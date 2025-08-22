#!/usr/bin/env bash
set -euo pipefail

AUTH_MODE=""

# List all possible profiles here.
RUN_PROFILES=("forms-designer" "forms-manager" "forms-runner" "forms-submission-api" "forms-entitlement-api" "forms-audit-api")

EXCLUDE_PROFILES=()
if [[ $# -ge 1 ]]; then
  for param in "$@"
  do
    if [[ "$param" == exclude=* ]]; then
      # Any 'exclude's will cause elements to be removed from the runnables array.
      IFS=', ' read -r -a OMIT_PROFILES <<< "${param:8}"
      for profile in ${EXCLUDE_PROFILES[@]}; do
        echo "*** EXCLUDING" $profile
        RUN_PROFILES=("${RUN_PROFILES[@]/$profile}")
      done
    fi

    if [[ "$param" == include=* ]]; then
      # Any 'include's will cause elements to be added (from empty) to the runnables array.
      IFS=', ' read -r -a INCLUDE_PROFILES <<< "${param:8}"
      RUN_PROFILES=()
      for profile in ${INCLUDE_PROFILES[@]}; do
        echo "*** Explictly INCLUDING" $profile
        RUN_PROFILES+=("$profile")
      done
    fi

    if [[ "$param" == auth=* ]]; then
      AUTH_PARAM=${param:5}
      AUTH_PARAM_LOWER=`echo "$AUTH_PARAM" | tr '[:upper:]' '[:lower:]'`
      AUTH_MODE=""
      if [[ "$AUTH_PARAM_LOWER" == "entra" ]]; then
        AUTH_MODE="AAD"
      fi
      if [[ "$AUTH_PARAM_LOWER" == "aad" ]]; then
        AUTH_MODE="AAD"
      fi
      if [[ "$AUTH_PARAM_LOWER" == "mock" ]]; then
        AUTH_MODE="mock"
      fi
      if [[ "$AUTH_PARAM_LOWER" == "oidc" ]]; then
        AUTH_MODE="mock"
      fi
      if [[ "$AUTH_MODE" == "" ]]; then
        echo "ERROR - invalid 'auth' parameter ($AUTH_PARAM)"
        exit 1
      fi
    fi
  done
fi

# Expand the profiles into a CLI clause
PROFILE_PARAM_LIST=""
for profile in ${RUN_PROFILES[@]}; do
  PROFILE_PARAM_LIST=`echo $PROFILE_PARAM_LIST "--profile" $profile`
done

# Mock OIDC auth, so include this service
if [[ "$AUTH_MODE" == "" ]] || [[ "$AUTH_MODE" == "mock" ]]; then
  PROFILE_PARAM_LIST=`echo $PROFILE_PARAM_LIST "--profile oidc"`
  AUTH_MODE="mock"
fi

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

# Mock OIDC auth requires special config
if [[ "$AUTH_MODE" == "mock" ]]; then
  ENV_FILE="$SCRIPT_DIR/oidc-auth.env"
fi

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
  $PROFILE_PARAM_LIST \
  up -d --quiet-pull

./utils/list-versions.sh

echo "[harness] Test harness started."
