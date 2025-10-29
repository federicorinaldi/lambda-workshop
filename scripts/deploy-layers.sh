#!/bin/bash
set -e

STACK_NAME="workshop-layers"
ENVIRONMENT="${ENVIRONMENT:-local}"

echo "🚀 Deploying shared layers stack: $STACK_NAME"

cd layers

# Build the layer
echo "Building layer..."
make build

# Deploy with SAM
if [ "$ENVIRONMENT" = "local" ]; then
  echo "Deploying to LocalStack..."
  samlocal deploy \
    --stack-name $STACK_NAME \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_IAM \
    --resolve-s3
else
  echo "Deploying to AWS..."
  sam deploy \
    --stack-name $STACK_NAME \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_IAM
fi

cd ..

echo "✅ Layers stack deployed successfully!"
