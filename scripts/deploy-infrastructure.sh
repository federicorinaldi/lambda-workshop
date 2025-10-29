#!/bin/bash
set -e

STACK_NAME="workshop-infrastructure"
TEMPLATE_FILE="infrastructure/base-resources.yaml"
ENVIRONMENT="${ENVIRONMENT:-local}"

echo "🚀 Deploying base infrastructure stack: $STACK_NAME"
echo "Environment: $ENVIRONMENT"

# Deploy with awslocal or aws CLI based on environment
if [ "$ENVIRONMENT" = "local" ]; then
  CMD="awslocal"
else
  CMD="aws"
fi

$CMD cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --parameter-overrides Environment=$ENVIRONMENT \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✅ Infrastructure stack deployed successfully!"

# Export outputs to .env file for local development
echo ""
echo "📝 Fetching stack outputs..."

QUEUE_URL=$($CMD cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`QueueUrl`].OutputValue' \
  --output text)

QUEUE_ARN=$($CMD cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`QueueArn`].OutputValue' \
  --output text)

TABLE_NAME=$($CMD cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`TableName`].OutputValue' \
  --output text)

BUCKET_NAME=$($CMD cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
  --output text)

# Write to .env file
cat > .env.infrastructure << EOF
# Auto-generated from infrastructure stack
QUEUE_URL=${QUEUE_URL}
QUEUE_ARN=${QUEUE_ARN}
TABLE_NAME=${TABLE_NAME}
BUCKET_NAME=${BUCKET_NAME}
STACK_NAME=${STACK_NAME}
ENVIRONMENT=${ENVIRONMENT}
EOF

echo "✅ Infrastructure details saved to .env.infrastructure"
echo ""
echo "Resources created:"
echo "  Queue URL: $QUEUE_URL"
echo "  Queue ARN: $QUEUE_ARN"
echo "  Table Name: $TABLE_NAME"
echo "  Bucket Name: $BUCKET_NAME"
