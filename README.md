# Lambda Workshop

A complete serverless application workshop using AWS Lambda, demonstrating:
- API Gateway integration
- SQS message queuing
- DynamoDB storage
- S3 exports
- Correlation ID tracking
- Local development with LocalStack

## Architecture

```
API Gateway (POST /enqueue)
    ↓
API Lambda → SQS Queue
    ↓
Processor Lambda → DynamoDB
    ↓
API Gateway (GET /export/{id})
    ↓
Export Lambda → DynamoDB → S3
```

## 🚀 Quick Start (One Command Setup)

### Prerequisites

- Docker and Docker Compose
- Node.js 20+
- AWS SAM CLI
- Python 3 with pipx (for samlocal)

### Install Prerequisites (macOS)

```bash
# Install Homebrew packages
brew install docker docker-compose node awscli aws-sam-cli pipx

# Install samlocal wrapper
pipx install aws-sam-cli-local

# Ensure pipx bin directory is in PATH
pipx ensurepath
```

### Run Everything

```bash
# Clone the repository
git clone <your-repo-url>
cd LambdaWorkshop

# ONE COMMAND TO DO EVERYTHING
make setup-and-test
```

This single command will:
1. ✅ Install all dependencies
2. ✅ Start LocalStack in Docker
3. ✅ Deploy infrastructure (SQS, DynamoDB, S3)
4. ✅ Deploy all Lambda services
5. ✅ Run end-to-end tests

## What Gets Tested

The E2E test validates the complete workflow:

1. **API Lambda** receives a request and enqueues a message to SQS
2. **SQS** triggers the Processor Lambda
3. **Processor Lambda** writes the item to DynamoDB
4. **Export Lambda** reads the item from DynamoDB
5. **Export Lambda** writes the item to S3
6. **Correlation ID** is preserved throughout the entire flow

## Manual Commands

If you want more control, you can run commands individually:

```bash
# Install dependencies
make install

# Start LocalStack
make localstack-up

# Deploy infrastructure
make deploy-infrastructure

# Deploy services
make deploy-services

# Run tests
make test-e2e          # End-to-end tests on LocalStack
make test-local        # Local SAM invoke tests
make test-all          # All tests

# Check LocalStack status
make localstack-status

# Stop LocalStack
make localstack-down

# Clean up
make clean             # Clean build artifacts
make clean-all         # Clean everything including LocalStack data
```

## Project Structure

```
LambdaWorkshop/
├── services/
│   ├── api-service/           # API Gateway → SQS
│   ├── processor-service/     # SQS → DynamoDB
│   └── export-service/        # DynamoDB → S3
├── infrastructure/
│   └── base-resources.yaml    # SQS, DynamoDB, S3 tables
├── events/                    # Sample event payloads for testing
├── scripts/                   # Deployment and test scripts
├── docker-compose.yml         # LocalStack configuration
└── Makefile                   # All commands
```

## Services

### API Service
- **Endpoint**: `POST /enqueue`
- **Function**: Accepts requests and enqueues messages to SQS
- **Features**: Correlation ID tracking, structured logging

### Processor Service
- **Trigger**: SQS messages
- **Function**: Processes messages and writes to DynamoDB
- **Features**: Partial batch failure handling, idempotency

### Export Service
- **Endpoint**: `GET /export/{id}`
- **Function**: Reads from DynamoDB and exports to S3
- **Features**: JSON export format, correlation tracking

## Environment Variables

The following environment variables are automatically set by the scripts:

```bash
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_ENDPOINT_URL=http://localhost:4566
```

## Troubleshooting

### LocalStack not starting
```bash
# Check Docker is running
docker ps

# Check LocalStack logs
docker logs lambda-workshop-localstack

# Restart LocalStack
make localstack-down
make localstack-up
```

### Tests failing
```bash
# Ensure LocalStack is running
make localstack-status

# Check infrastructure is deployed
awslocal cloudformation list-stacks

# View Lambda logs
awslocal logs tail /aws/lambda/<function-name> --follow
```

### samlocal not found
```bash
# Install samlocal
pipx install aws-sam-cli-local

# Add pipx bin to PATH
export PATH="$HOME/.local/bin:$PATH"
```

## Development

### Adding a New Service

1. Create service directory under `services/`
2. Add `template.yaml` with SAM configuration
3. Create `src/handler.ts` with Lambda handler
4. Update `scripts/deploy-services.sh` to include new service
5. Run `make deploy-services`

### Running Individual Functions Locally

```bash
# API Service
cd services/api-service
sam build
sam local invoke ApiFunction --event ../../events/api-event.json

# Processor Service
cd services/processor-service
sam build
sam local invoke ProcessorFunction --event ../../events/sqs-event.json

# Export Service
cd services/export-service
sam build
sam local invoke ExportFunction --event ../../events/export-event.json
```

## Clean Setup

To completely reset and start fresh:

```bash
make clean-all
make setup-and-test
```

## Notes on Best Practices

- **Structured Logging**: All services use JSON logging with correlation IDs
- **Error Handling**: Graceful error handling with partial batch failure support
- **Idempotency**: Processor service uses conditional writes to prevent duplicates
- **X-Ray Tracing**: Enabled by default for request tracing
- **Environment Configuration**: Services support both LocalStack and AWS deployments

## License

MIT
