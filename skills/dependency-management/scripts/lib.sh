#!/usr/bin/env bash
# Sourced by all dependency-management scripts. Requires $FORMAT to be set before sourcing.

err() {
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"status":"error","error":"%s"}\n' "$1" >&2
  else
    echo "Error: $1" >&2
  fi
  exit 1
}
