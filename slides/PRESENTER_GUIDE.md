# Workshop Presenter's Guide

## Workshop Flow & Demo Roadmap

This guide tells you **exactly what to show and when** during the 2-hour workshop.

---

## Setup Before Workshop Starts

```bash
# 1. Start LocalStack
make localstack-up

# 2. Deploy everything (do this before attendees arrive)
make install
make deploy-all

# 3. Verify deployment worked
make localstack-status
awslocal lambda list-functions
```

---

## Section 1: Core Lambda Design Principles (15 min)
**Mode:** Slides only, no code

**Slides to show:**
- `slides/LambdaWorkshopSlides.md` lines 24-49
- Talk through: Stateless, Idempotent, Single Responsibility, Least Privilege, Event-Driven, Observability

**No demo needed** - Pure concepts

---

## Section 2: Lambda Layers & Shared Code (10 min)
**Mode:** Slides + Code Demo

### 🎬 Demo 1: Layer Structure

**File to show:** Project root in file explorer
```
LambdaWorkshop/
├── layers/
│   ├── template.yaml        ← SAM template for layer
│   ├── Makefile
│   └── shared/
│       └── nodejs/
│           └── shared/
│               ├── logger.js       ← Show this
│               └── correlation.js  ← Show this
```

**What to say:** "This is how we structure layers. The `nodejs/shared` path becomes `/opt/nodejs/shared` in the Lambda runtime."

### 🎬 Demo 2: Logger Code

**File:** `layers/shared/nodejs/shared/logger.js`
**Lines to highlight:**
- Line 5-11: `createLogger` function - show the child logger pattern
- Line 27-36: `logLine` function - show JSON serialization

**Terminal command:**
```bash
cat layers/shared/nodejs/shared/logger.js
```

**What to say:** "This creates structured JSON logs. The `child()` method lets us add context like requestId or messageId without repeating it."

### 🎬 Demo 3: Correlation Helper

**File:** `layers/shared/nodejs/shared/correlation.js`
**Lines to highlight:**
- Line 3-9: `getRequestId` function - show the fallback chain

**What to say:** "This extracts correlation IDs from headers, API Gateway context, or generates a new one. This ID flows through the entire transaction."

---

## Section 3: Observability & Logging (15 min)
**Mode:** Slides + Code Demo

### 🎬 Demo 4: Correlation ID in Action

**File:** `services/api-service/src/handler.ts`
**Lines to highlight:**
- Line 6-8: Layer imports (show the `/opt/nodejs/shared` path)
- Line 17: `getRequestId(event, context)` - extracting correlation ID
- Line 18-23: Creating logger with context
- Line 38-40: SQS MessageAttributes with correlation ID
- Line 48-50: Returning correlation ID in response headers

**Terminal command:**
```bash
# Show the code
code services/api-service/src/handler.ts

# Run locally to show JSON logs
cd services/api-service
sam build
sam local invoke ApiFunction --event events/test-event.json
```

**What to say:**
1. "Notice we extract the correlation ID first"
2. "Create a logger with that ID"
3. "When we send to SQS, we include it in MessageAttributes"
4. "And return it to the client in headers"
5. "Let's see what the logs look like..." (run sam local invoke)
6. "See the JSON structure? Every field is searchable in Splunk."

---

## Section 4: Monitoring & Splunk Integration (15 min)
**Mode:** Slides + Optional Splunk Demo

### Slides: Splunk Queries

**Show:** `slides/LambdaWorkshopSlides.md` lines 179-293
Walk through the 5 example queries on slides

### 🎬 Optional Demo 5: Splunk Locally

**Only do this if time permits and Splunk is running**

**Terminal:**
```bash
# Start Splunk (if not already running)
docker-compose --profile monitoring up -d splunk

# Wait ~60 seconds for Splunk to start
open http://localhost:8000
# Login: admin / Admin123!

# Run a test to generate logs
make test-e2e
```

**In Splunk UI:**
```spl
index="lambda" requestId="test-*"
| table _time functionName level message
```

**What to say:** "This shows all logs from our test with the same correlation ID across all three services."

**If Splunk not running:** Skip this demo, just show the queries on slides

---

## Section 5: Local Testing with SAM CLI & LocalStack (20 min)
**Mode:** Terminal Heavy - Multiple Demos

### 🎬 Demo 6: Quick SAM Local Test

**Terminal:**
```bash
cd services/api-service
sam build
sam local invoke ApiFunction --event events/test-event.json
```

**What to say:**
- "This tests just the function, no AWS services needed"
- "See the JSON logs? That's our structured logging"
- "Notice the correlation ID in the output"

### 🎬 Demo 7: Show LocalStack Setup

**File:** `docker-compose.yml`
**Lines to highlight:**
- Line 3-26: LocalStack service configuration

**Terminal:**
```bash
# Show LocalStack is running
docker ps | grep localstack

# Show health
curl http://localhost:4566/_localstack/health | jq
```

**What to say:** "LocalStack emulates AWS services locally. One endpoint, all services."

### 🎬 Demo 8: Show Multi-Project Structure

**File Explorer - show this hierarchy:**
```
LambdaWorkshop/
├── infrastructure/          ← Base resources
│   └── base-resources.yaml
├── layers/                  ← Shared code
│   └── template.yaml
└── services/                ← Three independent services
    ├── api-service/
    ├── processor-service/
    └── export-service/
```

**What to say:** "This mirrors real microservice architecture. Each service is independently deployable."

### 🎬 Demo 9: Deploy to LocalStack

**Terminal:**
```bash
# If not already deployed, show the process:
make deploy-infrastructure

# Show resources created
awslocal dynamodb list-tables
awslocal sqs list-queues
awslocal s3 ls

# Show deployed functions
awslocal lambda list-functions | jq '.Functions[].FunctionName'
```

**What to say:** "We've deployed DynamoDB, SQS, S3, and 3 Lambda functions to LocalStack. This is our local AWS."

### 🎬 Demo 10: End-to-End Test

**Terminal:**
```bash
make test-e2e
```

**Watch for in output:**
- ✅ Message enqueued (requestId: test-XXXXX)
- ✅ Item found in DynamoDB
- ✅ Export file found in S3
- ✅ Correlation ID tracked through entire flow!

**What to say:**
"This test proves our entire workflow works:
1. API Lambda enqueues to SQS
2. Processor Lambda writes to DynamoDB
3. Export Lambda reads from DDB and writes to S3
4. The same correlation ID appears in all logs"

---

## Section 6: Common Lambda Patterns & Examples (15 min)
**Mode:** Code Walkthrough - Three Files

### 🎬 Demo 11: API Service Pattern

**File:** `services/api-service/src/handler.ts`

**Lines to walk through:**
- Line 17: Correlation ID extraction
- Line 18-23: Logger setup
- Line 26-32: Build payload with correlation ID
- Line 34-42: Send to SQS with MessageAttributes
- Line 54-60: Error handling

**What to say for each section:**
1. "First, we extract the correlation ID"
2. "Set up structured logging with context"
3. "Build our payload and include the correlation ID"
4. "When sending to SQS, we pass it via MessageAttributes"
5. "Error handling: log the error with details, return 500, but don't crash"

### 🎬 Demo 12: Processor Service Pattern

**File:** `services/processor-service/src/handler.ts`

**Lines to walk through:**
- Line 16: `const failures: string[] = []` - tracking failures
- Line 18-39: Loop through records
- Line 19: `const log = baseLog.child({ messageId })` - per-message logging
- Line 31: `ConditionExpression: 'attribute_not_exists(id)'` - idempotency
- Line 35-37: Catch errors, add to failures
- Line 41-44: Return batchItemFailures

**Show infrastructure too:**
**File:** `infrastructure/base-resources.yaml`
**Lines:** 72-78 - DLQ configuration with maxReceiveCount: 3

**What to say:**
1. "We track failed message IDs separately"
2. "Each message gets its own logger with messageId"
3. "This conditional expression prevents duplicate inserts - idempotency"
4. "If a message fails, we catch it and track the ID"
5. "Return only the failed IDs - SQS will retry just those"
6. "After 3 retries, messages go to the DLQ"

### 🎬 Demo 13: Export Service Pattern

**File:** `services/export-service/src/handler.ts`

**Lines to walk through:**
- Line 28-30: Path parameter extraction
- Line 33-36: GetItem from DynamoDB
- Line 38-44: Build export object with timestamp
- Line 46-52: PutObject to S3
- Line 59: Return correlation ID

**What to say:**
1. "RESTful pattern: extract ID from path"
2. "Read from DynamoDB"
3. "Add audit fields like exportedAt timestamp"
4. "Write to S3 as JSON"
5. "Return the correlation ID so client can track"

### 🎬 Demo 14: IAM Least Privilege

**File:** `services/processor-service/template.yaml`
**Lines:** 87-103 - IAM policies

**What to highlight:**
```yaml
- Statement:
    - Effect: Allow
      Action:
        - dynamodb:PutItem    # ← Specific action
        - dynamodb:GetItem
      Resource: !Sub "arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${TableName}"  # ← Specific resource
```

**What to say:** "Notice: specific actions on specific resources. Not `dynamodb:*` on `*`. This is least privilege."

---

## Section 7: CI/CD & IAM Overview (10 min)
**Mode:** Slides only

**Slides to show:** `slides/LambdaWorkshopSlides.md` lines 567-612

**No demo** - Just walk through the CI/CD flow diagram and IAM best practices

---

## Closing (5 min)

### Quick Recap Demo

**Terminal:**
```bash
# Show the whole structure
tree -L 2 -I 'node_modules|.aws-sam'

# Show available commands
make help
```

**What to say:**
"Everything we've shown is in this repo:
- Multi-service architecture
- LocalStack for local testing
- End-to-end tests with correlation tracking
- Production patterns: idempotency, partial failures, DLQs
- All the Make commands to run it yourself"

---

## Timing Breakdown

| Section | Time | Demo? | Key Files |
|---------|------|-------|-----------|
| 1. Design Principles | 15 min | No | Slides only |
| 2. Layers | 10 min | Yes | `layers/shared/nodejs/shared/*.js` |
| 3. Observability | 15 min | Yes | `services/api-service/src/handler.ts` |
| 4. Splunk | 15 min | Optional | Splunk UI or slides |
| 5. LocalStack | 20 min | **Heavy** | Terminal + `docker-compose.yml` |
| 6. Patterns | 15 min | Yes | All 3 service handlers |
| 7. CI/CD | 10 min | No | Slides only |
| 8. Closing | 5 min | Quick | Terminal commands |
| **Total** | **105 min** | | (15 min buffer for Q&A) |

---

## Quick Reference: Files to Have Open

**In your editor (VS Code recommended):**
1. `layers/shared/nodejs/shared/logger.js`
2. `layers/shared/nodejs/shared/correlation.js`
3. `services/api-service/src/handler.ts`
4. `services/processor-service/src/handler.ts`
5. `services/export-service/src/handler.ts`
6. `infrastructure/base-resources.yaml`

**In terminal tabs:**
1. Tab 1: Root directory for `make` commands
2. Tab 2: `services/api-service` for SAM local demos
3. Tab 3: Watch `docker logs -f lambda-workshop-localstack` (optional)

**In browser:**
1. http://localhost:4566/_localstack/health (LocalStack)
2. http://localhost:8000 (Splunk - if using)
3. `slides/LambdaWorkshopSlides.md` in preview mode

---

## Troubleshooting During Demo

### If LocalStack isn't responding:
```bash
make localstack-status
# If down, restart:
make localstack-down
make localstack-up
```

### If `make test-e2e` fails:
```bash
# Check deployments
awslocal cloudformation describe-stacks

# Redeploy if needed
make deploy-all
```

### If attendees ask to see Splunk but it's not running:
"We have Splunk available in docker-compose for those interested in trying it after the workshop. The queries I'm showing on slides work the same way."

### If SAM local invoke is slow:
"SAM local uses Docker containers, so first invocation is slower. In production, Lambda reuses containers for better performance."

---

## Pro Tips

1. **Pre-deploy everything** before workshop starts - deployments take 2-3 minutes each
2. **Have test-e2e output pre-recorded** as backup in case live demo fails
3. **Use split screen**: Slides on one side, terminal on the other
4. **Zoom in terminal**: Make font size large enough for remote attendees
5. **Copy-paste commands**: Don't type live, have commands ready in a notes file
6. **Pause for questions** after sections 3, 5, and 6 - these are dense

---

## What to Skip if Running Short on Time

**Priority order (skip from bottom up):**
1. ✂️ Splunk local demo (just show queries on slides)
2. ✂️ Section 7 CI/CD (provide slides for later reading)
3. ✂️ Export Service code walkthrough (briefly mention it exists)
4. ✂️ Layer code deep dive (show files but don't explain every line)

**Never skip:**
- ✅ LocalStack deployment and test-e2e (core demo)
- ✅ API Service correlation ID walkthrough
- ✅ Processor Service partial failures pattern
- ✅ Structured logging demo

---

## Post-Workshop

Share with attendees:
- This repository (if public/internal)
- `Lambda Workshop.md` - detailed guide with speaker notes
- `README.md` - how to run everything themselves
- Slides in markdown format

Encourage them to:
```bash
git clone <repo>
cd LambdaWorkshop
make localstack-up
make deploy-all
make test-e2e
```

Then explore and modify the code!
