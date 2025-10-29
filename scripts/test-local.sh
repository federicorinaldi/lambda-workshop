#!/bin/bash
set -e

echo "========================================="
echo "  Running Local SAM Tests"
echo "========================================="
echo ""
echo "Note: These tests run SAM local invoke without AWS services."
echo "Functions will return error responses when trying to access AWS resources."
echo "For full integration tests, use 'make test-e2e' with LocalStack running."
echo ""

# Test API service locally
echo "🧪 Testing API Service (local SAM invoke)..."
cd services/api-service
sam build
sam local invoke ApiFunction \
  --event ../../events/api-event.json \
  --parameter-overrides "QueueUrl=https://sqs.us-east-1.amazonaws.com/123456789012/test-queue"
cd ../..
echo "✅ API Service test passed"
echo ""

# Test Processor service locally
echo "🧪 Testing Processor Service (local SAM invoke)..."
cd services/processor-service
sam build
sam local invoke ProcessorFunction \
  --event ../../events/sqs-event.json \
  --parameter-overrides "TableName=test-table QueueArn=arn:aws:sqs:us-east-1:123456789012:test-queue"
cd ../..
echo "✅ Processor Service test passed"
echo ""

# Test Export service locally
echo "🧪 Testing Export Service (local SAM invoke)..."
cd services/export-service
sam build
sam local invoke ExportFunction \
  --event ../../events/export-event.json \
  --parameter-overrides "TableName=test-table BucketName=test-bucket"
cd ../..
echo "✅ Export Service test passed"
echo ""

echo "========================================="
echo "✅ All local tests passed!"
echo "========================================="
