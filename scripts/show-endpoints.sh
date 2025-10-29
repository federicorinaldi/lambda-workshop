#!/bin/bash
set -e

ENVIRONMENT="${ENVIRONMENT:-local}"

if [ "$ENVIRONMENT" = "local" ]; then
  CMD="awslocal"
  BASE_URL="http://localhost:4566/restapis"
else
  CMD="aws"
fi

echo "========================================="
echo "  Lambda Workshop - API Endpoints"
echo "========================================="
echo ""

# Get API Gateway endpoint for api-service
API_STACK="workshop-api-service"
API_ENDPOINT=$($CMD cloudformation describe-stacks \
  --stack-name $API_STACK \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text 2>/dev/null || echo "Not deployed")

# Get export endpoint
EXPORT_STACK="workshop-export-service"
EXPORT_ENDPOINT=$($CMD cloudformation describe-stacks \
  --stack-name $EXPORT_STACK \
  --query 'Stacks[0].Outputs[?OutputKey==`ExportEndpoint`].OutputValue' \
  --output text 2>/dev/null || echo "Not deployed")

if [ "$ENVIRONMENT" = "local" ]; then
  echo "📍 LocalStack Environment"
  echo ""
  echo "Enqueue API:"
  echo "  POST http://localhost:4566/restapis/[api-id]/local/_user_request_/enqueue"
  echo "  (Use awslocal apigateway get-rest-apis to find the actual ID)"
  echo ""
  echo "Export API:"
  echo "  GET http://localhost:4566/restapis/[api-id]/local/_user_request_/export/{id}"
  echo ""
  echo "💡 Tip: You can also test directly with Lambda:"
  echo "  awslocal lambda invoke --function-name workshop-api-service-ApiFunction response.json"
else
  echo "☁️  AWS Environment"
  echo ""
  echo "Enqueue API:"
  echo "  POST $API_ENDPOINT"
  echo ""
  echo "Export API:"
  echo "  GET $EXPORT_ENDPOINT"
fi

echo ""
echo "📊 LocalStack Dashboard:"
echo "  http://localhost:4566/_localstack/health"
echo ""

if docker ps | grep -q lambda-workshop-splunk; then
  echo "📈 Splunk (if started with monitoring profile):"
  echo "  http://localhost:8000"
  echo "  Username: admin"
  echo "  Password: Admin123!"
  echo ""
fi

echo "========================================="
