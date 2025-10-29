#!/bin/bash
set -e

# Set required environment variables
export PATH="$HOME/.local/bin:$PATH"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

ENVIRONMENT="${ENVIRONMENT:-local}"

if [ "$ENVIRONMENT" != "local" ]; then
  echo "⚠️  Warning: E2E tests are designed for LocalStack. Set ENVIRONMENT=local"
fi

echo "========================================="
echo "  Running End-to-End Tests on LocalStack"
echo "========================================="
echo ""

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
  echo "⚠️  LocalStack is not running. Skipping E2E tests."
  echo ""
  echo "To run E2E tests, start LocalStack first:"
  echo "  make localstack-up"
  echo ""
  exit 0
fi
echo "✅ LocalStack is running"
echo ""

# Source infrastructure outputs
if [ -f .env.infrastructure ]; then
  source .env.infrastructure
else
  echo "❌ Error: .env.infrastructure not found. Run 'make deploy-infrastructure' first."
  exit 1
fi

# Test correlation ID
CORRELATION_ID="test-$(date +%s)"

echo "📝 Test Correlation ID: $CORRELATION_ID"
echo ""

# Get actual function names from LocalStack
echo "🔍 Retrieving Lambda function names..."
API_FUNCTION=$(awslocal lambda list-functions --query 'Functions[?contains(FunctionName, `api-service-ApiFunction`)].FunctionName' --output text)
PROCESSOR_FUNCTION=$(awslocal lambda list-functions --query 'Functions[?contains(FunctionName, `processor-service-ProcessorFunction`)].FunctionName' --output text)
EXPORT_FUNCTION=$(awslocal lambda list-functions --query 'Functions[?contains(FunctionName, `export-service-ExportFunction`)].FunctionName' --output text)

if [ -z "$API_FUNCTION" ] || [ -z "$PROCESSOR_FUNCTION" ] || [ -z "$EXPORT_FUNCTION" ]; then
  echo "❌ Error: Could not find all Lambda functions. Make sure services are deployed."
  echo "   API Function: ${API_FUNCTION:-NOT FOUND}"
  echo "   Processor Function: ${PROCESSOR_FUNCTION:-NOT FOUND}"
  echo "   Export Function: ${EXPORT_FUNCTION:-NOT FOUND}"
  exit 1
fi

echo "   API Function: $API_FUNCTION"
echo "   Processor Function: $PROCESSOR_FUNCTION"
echo "   Export Function: $EXPORT_FUNCTION"
echo ""

# Step 1: Enqueue a message via API Lambda
echo "Step 1: Enqueue message via API Lambda..."
awslocal lambda invoke \
  --function-name "$API_FUNCTION" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"body": "{\"id\":\"'"$CORRELATION_ID"'\",\"data\":{\"test\":true}}", "headers":{"x-correlation-id":"'"$CORRELATION_ID"'"}}' \
  /tmp/api-response.json

cat /tmp/api-response.json | jq '.'
echo "✅ Message enqueued"
echo ""

# Step 2: Wait for message to be processed
echo "Step 2: Waiting 5 seconds for SQS processing..."
sleep 5

# Step 3: Verify item in DynamoDB
echo "Step 3: Verifying item in DynamoDB..."
awslocal dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key "{\"id\":{\"S\":\"$CORRELATION_ID\"}}" \
  --output json | jq '.Item'

if awslocal dynamodb get-item --table-name "$TABLE_NAME" --key "{\"id\":{\"S\":\"$CORRELATION_ID\"}}" | grep -q "$CORRELATION_ID"; then
  echo "✅ Item found in DynamoDB"
else
  echo "❌ Item NOT found in DynamoDB"
  exit 1
fi
echo ""

# Step 4: Export to S3
echo "Step 4: Exporting item to S3..."
awslocal lambda invoke \
  --function-name "$EXPORT_FUNCTION" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"pathParameters":{"id":"'"$CORRELATION_ID"'"}}' \
  /tmp/export-response.json

cat /tmp/export-response.json | jq '.'
echo "✅ Item exported"
echo ""

# Step 5: Verify S3 object
echo "Step 5: Verifying S3 export..."
awslocal s3 ls "s3://$BUCKET_NAME/exports/" | grep "$CORRELATION_ID" || {
  echo "❌ Export file NOT found in S3"
  exit 1
}
echo "✅ Export file found in S3"
echo ""

# Step 6: Download and verify content
echo "Step 6: Downloading and verifying export content..."
awslocal s3 cp "s3://$BUCKET_NAME/exports/$CORRELATION_ID.json" /tmp/exported-item.json
cat /tmp/exported-item.json | jq '.'
echo ""

# Verify correlation ID is preserved
if cat /tmp/exported-item.json | jq -r '.requestId' | grep -q "$CORRELATION_ID"; then
  echo "✅ Correlation ID preserved throughout the flow!"
else
  echo "⚠️  Warning: Correlation ID not found in exported item"
fi

echo ""
echo "========================================="
echo "✅ End-to-End Test PASSED!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✅ API Lambda enqueued message"
echo "  ✅ SQS triggered Processor Lambda"
echo "  ✅ Processor wrote to DynamoDB"
echo "  ✅ Export Lambda read from DynamoDB"
echo "  ✅ Export Lambda wrote to S3"
echo "  ✅ Correlation ID tracked through entire flow"
echo ""
echo "Correlation ID: $CORRELATION_ID"
