#!/usr/bin/env sh
set -euo pipefail

awslocal s3 mb s3://forms-dev-bucket || true
awslocal sqs create-queue --queue-name forms-events-queue || true
awslocal sns create-topic --name forms-events-topic || true
