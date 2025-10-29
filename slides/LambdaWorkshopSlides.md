## Workshop: Building & Operating AWS Lambda (Node.js)

### Objectives & Agenda
- Understand core Lambda design principles
- Use Lambda Layers for shared code
- Build observability in (logging, correlation IDs, tracing, metrics)
- Monitor with Splunk (practical queries and dashboards)
- Test locally with SAM CLI **and LocalStack** (end-to-end)
- Walk through real multi-service architecture
- Overview of CI/CD and IAM best practices

**Duration:** 2 hours | **Format:** Demo-driven presentation

---

### What is AWS Lambda? (Quick Recap)
- Function-as-a-Service, event-driven, no server management
- Ephemeral execution environment; design for statelessness
- Scales automatically, pay per invocation
- Triggers: API Gateway, SQS, S3, DynamoDB Streams, EventBridge, etc.

---

## 1) Core Lambda Design Principles

### Stateless & Idempotent
- **Stateless:** No dependency on prior invocation state
- **Idempotent:** Safe to retry; guard side-effects
  - Use unique keys in DynamoDB (ConditionExpression)
  - Check for duplicates before processing
  - Design for "at-least-once" delivery

### Single Responsibility & Least Privilege
- **Single Responsibility:** Keep handlers thin; delegate logic to modules/layers
- **Least Privilege IAM:** Narrow permissions per function
  - ✅ `dynamodb:PutItem` on specific table ARN
  - ❌ `dynamodb:*` on `*`

### Event-Driven & Backpressure-Aware
- Use SQS to buffer bursts; set concurrency limits where needed
- Protect downstream resources from overload
- Configure reserved concurrency for critical functions

### Observability by Default
- Structured JSON logs with correlation IDs
- X-Ray tracing enabled
- CloudWatch metrics and alarms
- *If it's not observable, it's not operable*

---

## 2) Lambda Layers & Shared Code

### What is a Layer?
- A zipped bundle of shared code/dependencies
- Attached to multiple functions
- Node.js layers exposed under `/opt/nodejs`
- Reduces deployment package size
- Enables code reuse across functions

### 🎬 CODE DEMO: Layer Structure
**Project:** `layers/shared/nodejs/shared/`
```
layers/
  ├── template.yaml        ← SAM template for layer
  ├── Makefile
  └── shared/
      └── nodejs/
          └── shared/
              ├── logger.js       ← Structured logger
              └── correlation.js  ← Correlation ID helpers
```

### Layer Code: Minimal JSON Logger
**File:** `layers/shared/nodejs/shared/logger.js`
```javascript
function createLogger(base) {
  const context = { ...base };
  return {
    child(extra) { return createLogger({ ...context, ...extra }); },
    info(msg, extra) { logLine('INFO', msg, context, extra); },
    error(msg, extra) { logLine('ERROR', msg, context, extra); },
  };
}
function logLine(level, message, context, extra) {
  process.stdout.write(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    ...context,
    ...(extra||{})
  }) + '\n');
}
```

### Layer Code: Correlation ID Helper
**File:** `layers/shared/nodejs/shared/correlation.js`
```javascript
function getRequestId(event, context) {
  const headers = event?.headers || event.requestContext?.http?.headers;
  const headerId = headers?.['x-correlation-id'];
  const apiGwId = event?.requestContext?.requestId;
  return headerId || apiGwId || context.awsRequestId || randomId();
}
```

### Best Practices for Layers
- Keep layers **lean** (smaller cold starts)
- **Version** changes carefully (avoid breaking functions)
- Watch total unzipped size (function + layers < 250 MB)
- Share truly common code (logger, utilities, SDK clients)

---

## 3) Observability & Logging

### Why Structured JSON Logs?
**Bad (unstructured):**
```
Error processing item 12345 in api-handler
```
- Hard to query, can't filter by fields

**Good (structured JSON):**
```json
{
  "level": "ERROR",
  "requestId": "12345",
  "functionName": "api-handler",
  "message": "Error processing item",
  "error": {"name": "ValidationError", "stack": "..."}
}
```
- Easy queries: `level=ERROR`, `requestId=12345`
- Splunk can parse and index fields automatically

### Correlation IDs – Tracking Requests
- **Unique ID** that flows through entire transaction
- Extracted from `x-correlation-id` header or generated
- Logged in every function invocation
- Propagated to downstream services (SQS attributes, HTTP headers)
- Enables end-to-end tracing in Splunk

### 🎬 CODE DEMO: Correlation ID in Action
**Project:** `services/api-service/src/handler.ts`
```typescript
const requestId = getRequestId(event, context);
const log = createLogger({
  service: 'ApiService',
  requestId,
  functionName: context.functionName
});
log.info('Processing request', { path: event.path });

// Send to SQS with correlation ID
await sqs.send(new SendMessageCommand({
  QueueUrl: queueUrl,
  MessageBody: JSON.stringify(payload),
  MessageAttributes: {
    'x-correlation-id': { DataType: 'String', StringValue: requestId }
  }
}));

// Return correlation ID to client
return {
  statusCode: 202,
  headers: { 'x-correlation-id': requestId },
  body: JSON.stringify({ accepted: true, requestId })
};
```

### Distributed Tracing with X-Ray
- Enabled by default: `Tracing: Active` in SAM template
- Provides service maps and latency analysis
- Complements correlation ID logging

---

## 4) Monitoring & Splunk Integration

### CloudWatch Logs → Splunk Pipeline
```
[Lambda] → [CloudWatch Logs] → [Subscription Filter]
         ↓
[Forwarder Lambda/Firehose] → [Splunk HEC] → [Splunk Index]
```
- All Lambda logs flow to Splunk in near real-time
- Structured JSON automatically parsed
- Centralized logging across all services

### Common Splunk Queries for Lambdas

**1. Find all errors:**
```spl
index="lambda" level="ERROR"
| stats count by functionName
```

**2. Trace a transaction by correlation ID:**
```spl
index="lambda" requestId="abc-123"
| sort _time
| table _time functionName level message
```

**3. Monitor SQS processing failures:**
```spl
index="lambda" functionName="*processor*" level="ERROR"
| stats count by messageId
```

**4. Alert on high error rates:**
```spl
index="lambda" level="ERROR"
| timechart span=5m count by functionName
```

**5. Find slow invocations:**
```spl
index="lambda" duration>5000
| stats avg(duration) p95(duration) by functionName
```

### Splunk Dashboards

**Lambda Health Dashboard:**
- Error rates per function
- Invocation counts
- Duration percentiles (p50, p95, p99)
- Throttle events

**Transaction Tracing Dashboard:**
- Input: `requestId`
- Output: Timeline of all events across services
- Visualize complete journey of a request

**SQS Processing Dashboard:**
- Messages processed
- DLQ depth
- Processing errors
- Retry counts

### 🎬 OPTIONAL DEMO: Splunk Locally
**Terminal:**
```bash
# Start Splunk container
docker-compose --profile monitoring up -d splunk

# Access Splunk Web
open http://localhost:8000
# Login: admin / Admin123!

# Run end-to-end test to generate logs
make test-e2e

# In Splunk: Search for logs
index="lambda" requestId="test-*"
| table _time functionName level message
```

### Correlation in Action: Multi-Service Tracing

**Scenario:** POST /enqueue → SQS → DynamoDB → GET /export → S3

```
requestId: req-789

api-service:      {"requestId":"req-789","level":"INFO","message":"Enqueued to SQS"}
processor-service: {"requestId":"req-789","level":"INFO","message":"Wrote to DynamoDB"}
export-service:    {"requestId":"req-789","level":"INFO","message":"Exported to S3"}
```

**Splunk Query:**
```spl
index="lambda" requestId="req-789"
```
Shows complete journey across 3 services, chronologically ordered

### Alerting with Splunk

**Example Alert:** DLQ receives messages
```spl
index="lambda" source="/aws/lambda/*dlq*"
| stats count
```
- **Trigger:** count > 0
- **Action:** Send PagerDuty alert with correlation ID and error details

**Integrations:**
- PagerDuty
- ServiceNow
- Slack
- Email

---

## 5) Local Testing: SAM CLI + LocalStack

### Two-Tier Testing Approach

**Tier 1: SAM Local** (fast iteration)
- Test individual functions
- No AWS services needed
- Use `sam local invoke` and `sam local start-api`

**Tier 2: LocalStack** (integration testing)
- Full AWS service emulation locally
- DynamoDB, SQS, S3, API Gateway, Lambda
- Test complete workflows end-to-end
- **Not optional – this is our standard workflow**

### SAM CLI Commands

```bash
sam build                        # Compile/bundle code
sam local invoke Function -e event.json  # Test single function
sam local start-api              # Local API Gateway
sam local generate-event sqs receive-message  # Generate test events
```

### 🎬 CODE DEMO: Quick SAM Local Test
**Terminal:**
```bash
cd services/api-service
sam build
sam local invoke ApiFunction --event events/test-event.json
```

**Output:**
```json
{"timestamp":"2025-10-09T...","level":"INFO","message":"Processing request",...}
{"statusCode":202,"headers":{"x-correlation-id":"..."},"body":"..."}
```

### LocalStack Setup

**What is LocalStack?**
- Open-source AWS cloud emulator
- 80+ services
- Single endpoint: `localhost:4566`
- Supports CloudFormation/SAM deployments

**Start LocalStack:**
```bash
# Option 1: Docker Compose
make localstack-up

# Option 2: LocalStack CLI
localstack start -d

# Verify health
curl http://localhost:4566/_localstack/health
```

**Use `awslocal` CLI:**
- Wrapper around `aws` CLI
- Pre-configured for LocalStack endpoint
- Same commands: `awslocal lambda list-functions`

### 🎬 CODE DEMO: Deploy to LocalStack

**Terminal:**
```bash
# Deploy infrastructure (DynamoDB, SQS, S3)
make deploy-infrastructure

# Deploy shared layers
make deploy-layers

# Deploy all services
make deploy-services

# Verify deployment
awslocal lambda list-functions
awslocal dynamodb list-tables
awslocal sqs list-queues
awslocal s3 ls
```

### 🎬 CODE DEMO: End-to-End Test on LocalStack

**Terminal:**
```bash
make test-e2e
```

**Test Flow:**
1. ✅ Invoke API Lambda → enqueue message to SQS
2. ✅ Check SQS → message present
3. ✅ Processor Lambda triggers → writes to DynamoDB
4. ✅ Verify DynamoDB → item exists
5. ✅ Invoke Export Lambda → reads from DDB, writes to S3
6. ✅ Verify S3 → export file exists
7. ✅ Check correlation ID preserved throughout

**Sample Output:**
```
Step 1: Enqueue message via API Lambda...
✅ Message enqueued (requestId: test-1728468123)

Step 2: Waiting for SQS processing...
✅ Message processed

Step 3: Verifying item in DynamoDB...
✅ Item found

Step 4: Exporting item to S3...
✅ Item exported

Step 5: Verifying S3 export...
✅ Export file found: s3://workshop-local-exports/exports/test-1728468123.json

✅ Correlation ID tracked through entire flow!
```

### LocalStack Capabilities & Limitations

**Capabilities:**
- ✅ Common services (Lambda, API GW, SQS, DynamoDB, S3)
- ✅ CloudFormation/SAM deployments
- ✅ Event triggers (SQS → Lambda, DDB Streams)
- ✅ Basic IAM policy evaluation

**Limitations:**
- ⚠️ Not 100% API-compatible (some advanced features missing)
- ⚠️ IAM enforcement simpler than real AWS
- ⚠️ Performance differs from production

**Best Practice:**
- Use LocalStack for integration tests
- **Always validate in real dev AWS before production**

---

## 6) Common Patterns & Examples

### Workshop Multi-Service Architecture

**🎬 CODE DEMO: Project Structure**
```
LambdaWorkshop/
├── infrastructure/          # Shared resources (DDB, SQS, S3)
│   └── base-resources.yaml
├── layers/                  # Shared utilities layer
│   ├── template.yaml
│   └── shared/
│       └── nodejs/shared/
├── services/
│   ├── api-service/         # HTTP API → SQS
│   │   ├── template.yaml
│   │   ├── src/handler.ts
│   │   └── events/
│   ├── processor-service/   # SQS → DynamoDB
│   │   ├── template.yaml
│   │   ├── src/handler.ts
│   │   └── events/
│   └── export-service/      # DynamoDB → S3
│       ├── template.yaml
│       ├── src/handler.ts
│       └── events/
├── scripts/                 # Deployment & testing
└── Makefile                 # Orchestration
```

**Flow:** POST /enqueue → SQS → DynamoDB → GET /export/{id} → S3

**Each service:** Independently deployable, separate SAM stack

### Pattern 1: API Service (Correlation ID)

**🎬 CODE DEMO: services/api-service/src/handler.ts**

**Key Lines:**
- Line 17: Extract correlation ID from header or generate
- Line 18-23: Create logger with requestId
- Line 34-42: Send to SQS with correlation ID in MessageAttributes
- Line 48-50: Return correlation ID in response headers
- Line 54-60: Error handling (log + return 500)

**Demo:**
```bash
cd services/api-service
sam local invoke ApiFunction --event events/test-event.json
```

**Patterns Demonstrated:**
- ✅ Correlation ID extraction & propagation
- ✅ Structured logging
- ✅ Graceful error handling
- ✅ Least privilege IAM (SQS SendMessage only)

### Pattern 2: Processor Service (SQS Batch + Partial Failures)

**🎬 CODE DEMO: services/processor-service/src/handler.ts**

**Key Lines:**
- Line 16: Track failed message IDs
- Line 19: Child logger per message (traceability)
- Line 31: `ConditionExpression` for idempotency
- Line 35-37: Catch errors, log, add to failures
- Line 41-44: Return `{ batchItemFailures: [...] }`

**Demo:**
```bash
cd services/processor-service
sam local invoke ProcessorFunction --event events/test-event.json
```

**Patterns Demonstrated:**
- ✅ Partial batch failures (only failed messages retry)
- ✅ Idempotency (DynamoDB conditional writes)
- ✅ Per-message logging with messageId
- ✅ Dead Letter Queue configured in infrastructure
- ✅ Least privilege IAM (SQS receive + DynamoDB PutItem)

**DLQ Configuration:**
**🎬 CODE DEMO: infrastructure/base-resources.yaml**
```yaml
WorkshopQueue:
  Type: AWS::SQS::Queue
  Properties:
    VisibilityTimeout: 60
    RedrivePolicy:
      deadLetterTargetArn: !GetAtt WorkshopQueueDLQ.Arn
      maxReceiveCount: 3
```

### Pattern 3: Export Service (DynamoDB → S3)

**🎬 CODE DEMO: services/export-service/src/handler.ts**

**Key Lines:**
- Line 28: Extract path parameter
- Line 33: GetItem from DynamoDB
- Line 38-44: Build export object with timestamp
- Line 46-52: PutObject to S3
- Line 59: Return correlation ID in response

**Demo:**
```bash
cd services/export-service
sam local start-api
# In another terminal:
curl http://localhost:3000/export/test-123
```

**Patterns Demonstrated:**
- ✅ RESTful API pattern
- ✅ Multi-service integration (DDB + S3)
- ✅ Audit trail (exportedAt timestamp)
- ✅ End-to-end correlation ID tracing
- ✅ Least privilege IAM (GetItem + S3 PutObject only)

### Code Patterns Summary

✅ Correlation ID extraction and propagation (all services)
✅ Structured logging with child loggers
✅ Idempotency via DynamoDB conditional writes
✅ Partial batch failures for SQS processing
✅ Error handling: log, serialize, fail gracefully
✅ Least privilege IAM per service
✅ Dead Letter Queues for reliability
✅ Independent deployability (microservices)

---

## 7) CI/CD & IAM Overview

### CI/CD Pipeline Stages

```
[Code Commit] → [Lint & Test] → [Build SAM] → [Deploy Dev]
                                                    ↓
                                            [Integration Tests]
                                                    ↓
                                    [Manual Approval] → [Deploy Prod]
```

**Key Points:**
- Automated testing at every stage
- SAM validates templates before deploy
- Integration tests run on dev AWS (or LocalStack in CI)
- OIDC for AWS authentication (no long-lived keys)
- Assume deployment role with minimal permissions

### IAM Best Practices

**Execution Role (per Lambda):**
- ✅ Specific actions: `dynamodb:PutItem`, `s3:GetObject`
- ✅ Specific resources: `arn:aws:dynamodb:region:account:table/workshop-items`
- ❌ Wildcards: `dynamodb:*`, `Resource: "*"`

**Example (from processor-service template):**
```yaml
Policies:
  - Statement:
      - Effect: Allow
        Action:
          - dynamodb:PutItem
          - dynamodb:GetItem
        Resource: !Sub "arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${TableName}"
```

**Developer Access:**
- Non-prod: Elevated access for development
- Prod: Read-only (deployments via CI/CD only)

**Guardrails:**
- Service Control Policies (SCPs) block risky actions
- Prevent wildcard IAM policies
- Enforce encryption, logging, tagging

---

## Resources & Next Steps

### Workshop Repository Structure
- ✅ Multi-service architecture (api, processor, export)
- ✅ Shared infrastructure (DynamoDB, SQS, S3)
- ✅ Shared layers (logger, correlation)
- ✅ LocalStack deployment scripts
- ✅ End-to-end testing scripts
- ✅ Makefile for orchestration

### Try It Yourself

```bash
# Clone the workshop repo (if provided)
git clone <workshop-repo>
cd LambdaWorkshop

# Start LocalStack
make localstack-up

# Deploy everything
make deploy-all

# Run end-to-end tests
make test-e2e

# Explore the code
code services/api-service/src/handler.ts
```

### Next Steps
1. Experiment with the workshop code
2. Add a new service (e.g., notification service via SNS)
3. Implement your own Lambda following these patterns
4. Set up Splunk dashboards for your functions
5. Integrate LocalStack into your CI/CD pipeline

### Additional Resources
- AWS Lambda Best Practices: https://docs.aws.amazon.com/lambda/
- LocalStack Docs: https://docs.localstack.cloud/
- SAM CLI Reference: https://docs.aws.amazon.com/serverless-application-model/
- Splunk for AWS: https://www.splunk.com/en_us/solutions/aws.html

---

## Questions?

**Key Takeaways:**
1. Design Lambdas to be **stateless, idempotent, and focused**
2. Use **structured logging with correlation IDs** for observability
3. Test with **SAM Local + LocalStack** before deploying
4. Leverage **Splunk** for monitoring and troubleshooting
5. Follow **least privilege IAM** and use Dead Letter Queues
6. Structure as **independent services**, not monoliths

**Thank you for attending!**
