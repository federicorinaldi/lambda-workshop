#!/bin/bash
# Source this file to set up environment for LocalStack
# Usage: source scripts/setup-env.sh

export PATH="$HOME/.local/bin:$PATH"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
export ENVIRONMENT=local

echo "✅ Environment configured for LocalStack"
echo "   AWS_ENDPOINT_URL: $AWS_ENDPOINT_URL"
echo "   AWS_REGION: $AWS_DEFAULT_REGION"
echo ""
echo "You can now use:"
echo "  - awslocal <command>"
echo "  - samlocal <command>"
echo "  - make <target>"
