#!/bin/bash
set -e

# Set required environment variables
export PATH="$HOME/.local/bin:$PATH"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

ENVIRONMENT="${ENVIRONMENT:-local}"

# Source infrastructure outputs
if [ -f .env.infrastructure ]; then
  source .env.infrastructure
  echo "Loaded infrastructure configuration"
else
  echo "⚠️  Warning: .env.infrastructure not found. Run 'make deploy-infrastructure' first."
fi

# Note: Shared utilities are now bundled directly into each Lambda
# No layer deployment needed

# Helper function to deploy a service
deploy_service() {
  local service_name=$1
  local service_path="services/$service_name"
  local stack_name="workshop-$service_name"

  echo ""
  echo "🚀 Deploying $service_name..."
  cd "$service_path"

  # Build
  echo "Building $service_name..."
  sam build

  # Deploy
  if [ "$ENVIRONMENT" = "local" ]; then
    echo "Deploying $service_name to LocalStack..."
    samlocal deploy \
      --stack-name "$stack_name" \
      --parameter-overrides \
        Environment=$ENVIRONMENT \
        QueueUrl="${QUEUE_URL:-}" \
        QueueArn="${QUEUE_ARN:-}" \
        TableName="${TABLE_NAME:-}" \
        BucketName="${BUCKET_NAME:-}" \
      --no-confirm-changeset \
      --no-fail-on-empty-changeset \
      --capabilities CAPABILITY_IAM \
      --resolve-s3
  else
    echo "Deploying $service_name to AWS..."
    sam deploy \
      --stack-name "$stack_name" \
      --parameter-overrides \
        Environment=$ENVIRONMENT \
        QueueUrl="${QUEUE_URL:-}" \
        QueueArn="${QUEUE_ARN:-}" \
        TableName="${TABLE_NAME:-}" \
        BucketName="${BUCKET_NAME:-}" \
      --no-confirm-changeset \
      --no-fail-on-empty-changeset \
      --capabilities CAPABILITY_IAM
  fi

  cd ../..
  echo "✅ $service_name deployed successfully!"
}

# Deploy all services
deploy_service "api-service"
deploy_service "processor-service"
deploy_service "export-service"

echo ""
echo "🎉 All services deployed successfully!"
