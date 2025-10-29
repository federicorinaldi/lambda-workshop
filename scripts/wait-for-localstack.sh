#!/bin/bash
set -e

MAX_RETRIES=30
RETRY_DELAY=2

echo "Waiting for LocalStack to be ready..."

for i in $(seq 1 $MAX_RETRIES); do
  if curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "available"'; then
    echo "✅ LocalStack is ready!"
    exit 0
  fi
  echo "Attempt $i/$MAX_RETRIES: LocalStack not ready yet, waiting ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

echo "❌ LocalStack failed to become ready after $MAX_RETRIES attempts"
exit 1
