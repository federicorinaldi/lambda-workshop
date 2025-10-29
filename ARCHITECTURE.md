# Lambda Workshop - Architecture Overview

## Project Structure

```
LambdaWorkshop/
├── infrastructure/          # Shared AWS resources (DynamoDB, SQS, S3)
│   └── base-resources.yaml
├── layers/                  # Example of Lambda Layers (educational reference)
│   ├── README.md           # Explains layers vs bundled utilities
│   └── shared/
│       └── nodejs/shared/
├── services/               # Three microservices
│   ├── api-service/        # HTTP API → SQS
│   ├── processor-service/  # SQS → DynamoDB
│   └── export-service/     # DynamoDB → S3
├── scripts/                # Deployment and testing automation
│   ├── deploy-infrastructure.sh
│   ├── deploy-layers.sh (optional)
│   ├── deploy-services.sh
│   ├── test-e2e.sh
│   └── setup-env.sh
├── docker-compose.yml      # LocalStack + optional Splunk
├── Makefile                # Top-level commands
└── Lambda Workshop.md      # Workshop guide
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Lambda Workshop                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  API Service │─────▶│Processor Svc │─────▶│ Export Svc   │
│              │      │              │      │              │
│  HTTP API    │      │  SQS Queue   │      │  GET /export │
│  POST /enqueue      │              │      │  /{id}       │
└──────┬───────┘      └──────┬───────┘      └──────┬───────┘
       │                     │                     │
       │                     │                     │
       ▼                     ▼                     ▼
   ┌───────┐            ┌─────────┐          ┌─────────┐
   │  SQS  │───────────▶│DynamoDB │─────────▶│   S3    │
   │ Queue │            │  Table  │          │ Bucket  │
   └───────┘            └─────────┘          └─────────┘
       │
       ▼
   ┌───────┐
   │  DLQ  │
   └───────┘
```

## Data Flow

1. **Client** → POST to API Service `/enqueue`
   - Generates correlation ID
   - Logs request with structured JSON
   - Sends message to SQS with correlation ID in attributes

2. **SQS** → Triggers Processor Service
   - Batch of up to 10 messages
   - 5-second batching window
   - Partial batch failure support

3. **Processor Service** → Writes to DynamoDB
   - Extracts correlation ID from message attributes
   - Idempotent writes (condition: attribute_not_exists)
   - Returns failed message IDs for retry

4. **Export Service** → GET `/export/{id}`
   - Reads item from DynamoDB by ID
   - Exports to S3 as JSON
   - Preserves correlation ID in logs

## Shared Utilities

Each service includes `src/shared-utils.ts`:

- **Correlation ID Tracking**: Extract and propagate request IDs
- **Structured Logging**: JSON logs with correlation context
- **TypeScript**: Type-safe utilities

> **Note**: In production, these would typically be in a Lambda Layer or NPM package.
> See `/layers/README.md` for the layer approach.

## Key AWS Patterns Demonstrated

### 1. Correlation ID Propagation
```typescript
// Extract from event/context
const requestId = getRequestId(event, context);

// Add to SQS message
MessageAttributes: {
  'x-correlation-id': { DataType: 'String', StringValue: requestId }
}

// Add to API response
headers: { 'x-correlation-id': requestId }
```

### 2. Structured JSON Logging
```typescript
const log = createLogger({
  service: 'ApiService',
  version: '1.0.0',
  requestId,
  functionName: context.functionName,
});

log.info('Enqueued message', { id: payload.id });
```

### 3. SQS Partial Batch Failures
```typescript
const failures: string[] = [];
for (const record of event.Records) {
  try {
    await processRecord(record);
  } catch (err) {
    failures.push(record.messageId);
  }
}
return {
  batchItemFailures: failures.map(id => ({ itemIdentifier: id }))
};
```

### 4. DynamoDB Idempotency
```typescript
await ddb.send(new PutItemCommand({
  TableName: tableName,
  Item: { id, data, createdAt },
  ConditionExpression: 'attribute_not_exists(id)',  // No duplicates
}));
```

## Testing

### End-to-End Test
```bash
make test-e2e
```

Validates:
- ✅ API Lambda enqueues to SQS
- ✅ Processor Lambda processes SQS messages
- ✅ Items written to DynamoDB
- ✅ Export Lambda reads from DynamoDB
- ✅ Files written to S3
- ✅ Correlation ID preserved throughout

### LocalStack Resources
```bash
# List Lambda functions
awslocal lambda list-functions

# Check SQS messages
awslocal sqs receive-message --queue-url <QUEUE_URL>

# Query DynamoDB
awslocal dynamodb scan --table-name workshop-local-items

# List S3 objects
awslocal s3 ls s3://workshop-local-exports/exports/
```

## Deployment

### Quick Start
```bash
# Start LocalStack
make localstack-up

# Deploy everything
make deploy-all

# Run E2E test
make test-e2e
```

### Manual Steps
```bash
# 1. Deploy infrastructure (DynamoDB, SQS, S3)
make deploy-infrastructure

# 2. Deploy all services
make deploy-services

# 3. Test
make test-e2e
```

## Environment Variables

Each Lambda receives:
- `ENVIRONMENT`: local/dev/prod
- `SERVICE_NAME`: Service identifier
- `SERVICE_VERSION`: For tracking deployments
- Service-specific: `QUEUE_URL`, `TABLE_NAME`, `BUCKET_NAME`

## Monitoring & Observability

### CloudWatch Logs
- JSON-formatted logs
- Correlation IDs in every log line
- Searchable by `requestId` field

### X-Ray Tracing
- Enabled on all functions (`Tracing: Active`)
- Service map shows full flow
- Trace requests end-to-end

### Splunk Integration (Optional)
See **Lambda Workshop.md** Section 4 for:
- CloudWatch → Splunk pipeline
- Example SPL queries
- Dashboard setup
- Alerting configuration

## Production Considerations

### What's Production-Ready
- ✅ Multi-service architecture
- ✅ Infrastructure as Code (SAM/CloudFormation)
- ✅ Structured logging with correlation IDs
- ✅ Idempotent operations
- ✅ Partial batch failure handling
- ✅ Dead Letter Queue for poison messages
- ✅ X-Ray tracing enabled
- ✅ Least privilege IAM policies

### What Would Change for Production
- 🔄 Add API Gateway authentication/authorization
- 🔄 Use Lambda Layers or NPM packages for shared code
- 🔄 Add CloudWatch alarms and dashboards
- 🔄 Implement DynamoDB backups and point-in-time recovery
- 🔄 Add API rate limiting and throttling
- 🔄 Enable SQS message encryption
- 🔄 Add comprehensive error handling and circuit breakers
- 🔄 Implement proper secrets management (Secrets Manager/Parameter Store)
- 🔄 Add CI/CD pipeline (GitHub Actions, CodePipeline, etc.)
- 🔄 Configure VPC for sensitive workloads
- 🔄 Add cost allocation tags
- 🔄 Implement automated testing (unit, integration, E2E)

## Useful Commands

```bash
# Build all services
make build-all

# Clean build artifacts
make clean

# View Lambda logs
make logs SERVICE=api-service

# Invoke Lambda directly
awslocal lambda invoke \
  --function-name workshop-api-service-ApiFunction-* \
  --payload '{"body":"{}"}' \
  output.json

# Redeploy single service
cd services/api-service && sam build && samlocal deploy
```

## Troubleshooting

### Lambda not triggering from SQS
- Check event source mapping: `awslocal lambda list-event-source-mappings`
- Verify queue ARN is correct in template
- Check Lambda execution role has SQS permissions

### Items not in DynamoDB
- Check processor Lambda logs
- Verify table name environment variable
- Check for ConditionalCheckFailedException (duplicate IDs)

### S3 export fails
- Verify bucket exists: `awslocal s3 ls`
- Check Lambda execution role has S3 permissions
- Ensure bucket name matches environment variable

## Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Serverless Patterns Collection](https://serverlessland.com/patterns)
