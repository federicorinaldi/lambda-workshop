Workshop Plan: Building & Operating AWS Lambda (Node.js) at AIG

Introduction & Workshop Overview (5 minutes)

This opening section sets the stage for the workshop. Explain the goals: to learn how to build and operate AWS Lambda functions in line with AIG’s Node.js Lambda policy. Emphasize that it’s a presentation and demo-focused session (no hands-on coding required from participants). The presenter will use their local environment (with AWS SAM CLI, Docker, Node.js installed) to demonstrate concepts. Make sure to mention that some attendees might be new to AWS Lambda, so core concepts will be briefly introduced.
	•	Slide: “Workshop Objectives & Agenda.” Outline the topics to be covered: core Lambda design principles, using Lambda layers for shared code, observability (logging & tracing), monitoring with Splunk, local testing with SAM CLI, example Lambda handlers, and a glimpse of CI/CD and IAM best practices. Also highlight the 2-hour duration and that a short Q&A will follow each major section.
	•	Slide: “What is AWS Lambda? (Quick Recap)” – For those without AWS experience, give a 1-minute overview of AWS Lambda. Explain it’s a Function-as-a-Service (FaaS) that runs code in response to events without managing servers. Emphasize the ephemeral nature of Lambda (containers spin up on-demand and may be reused or destroyed), which underpins many best practices (statelessness, etc.). This prepares everyone for the design principles next.

Takeaways: Participants understand the workshop format (interactive demo-driven presentation) and the high-level goals. Even those new to AWS gain a basic understanding of what Lambda is, ensuring everyone is on the same page before diving into best practices.

1. Core Lambda Design Principles (15 minutes)

Introduce the fundamental design principles that guide how we write and architect Lambda functions at AIG. Each principle will be explained with its rationale and examples of how to implement it in practice. This section is theory-focused to establish a mindset for building reliable, maintainable Lambdas.
	•	Slide: “Stateless & Idempotent Functions.” Define stateless: a Lambda should not rely on data from previous invocations – no data should be kept in memory or disk between runs. Define idempotent: the function can run multiple times on the same event without unintended side-effects (safe to re-run). Emphasize that every handler must be idempotent and side-effects (like external writes) should be detectable or guarded (for example, using a unique key in a DynamoDB table so duplicate inserts are rejected) ￼. If the same event is received twice, it should not cause double processing due to these safeguards.
	•	Slide: “Single Responsibility & Least Privilege.” Explain single responsibility principle: each Lambda function should do one thing and do it well. Keep the handler focused and delegate auxiliary tasks to libraries or other services – for instance, parse input, then call a dedicated module for business logic. The AIG policy advises keeping handlers thin and extracting shared logic into libraries (or layers) ￼. Also cover least privilege: each Lambda’s IAM role should allow only the minimum actions necessary (e.g., if a function writes to one DynamoDB table, its policy should only allow PutItem on that specific table) ￼. This limits blast radius and is mandated by AIG standards.
	•	Slide: “Event-Driven & Backpressure-Aware.” Note that Lambdas are often triggered by events (API calls, queue messages, etc.), fitting an event-driven architecture. Emphasize designing with backpressure awareness: protect downstream resources by not overwhelming them. Discuss techniques like using SQS to buffer bursts or limiting concurrency. For example, if a Lambda writes to a database, we might configure a reserved concurrency on that Lambda to avoid infinite scaling or use SQS batch size and throttling to match the DB’s capacity ￼. This ensures stability under load.
	•	Slide: “Observability by Default (Intro).” Preview that observability (logging, tracing, metrics) must be baked in from the start ￼. Mention that every Lambda should produce structured logs and include correlation identifiers. This is just a high-level mention here as a principle (a full observability section comes later). The key point: “If it’s not observable, it’s not operable.” AIG’s policy treats logs, metrics, and traces as non-optional from day one ￼.
Speaker Note: While discussing these principles, reference real scenarios (e.g., “imagine a payment processing Lambda – if it fails mid-way, idempotency ensures a retry won’t double charge the customer”). Encourage questions to check understanding, especially for those new to concepts like idempotency.
	•	Takeaways: Developers grasp the key principles: that Lambdas should be stateless and safe to retry, focused in purpose, running with minimal permissions, and designed with system limits in mind. This mindset will inform all the coding and architectural practices in the rest of the workshop ￼ ￼.

2. Lambda Layers & Shared Code (10 minutes)

This section covers how to handle shared code and common utilities in a multi-Lambda environment using Lambda Layers. It builds on the single-responsibility idea: instead of copying and pasting common code into each function, we package it for reuse. The presenter will explain what layers are and provide examples of what might go into a layer (especially for Node.js lambdas in AIG’s context, e.g., logging utilities, monitoring agents, or business logic libraries).
	•	Slide: “Code Reuse with Lambda Layers.” Define Lambda Layer: a zip package of code/dependencies that can be attached to multiple Lambda functions. According to AWS docs, layers are used to package libraries or configuration that you want to reuse across many functions ￼. For Node.js, a layer typically contains a nodejs/node_modules folder with libraries. Explain that by using layers, we avoid duplicating code (improving maintainability) and can reduce each function’s deployment package size. Common use cases at AIG might include a shared logging library, a set of utility functions (e.g. for input validation or custom error classes), or a monitoring client for metrics. These can be built once and reused.
	•	Slide: “Best Practices for Layers.” Outline best practices and considerations: keep layers lean (only include truly shared code to minimize size and cold start impact) ￼, and version them carefully (so updates don’t break functions expecting an older version). Mention that layers can simplify updates – update the layer once and all functions that reference it can pull the new version on next deploy ￼. Also clarify the 250 MB unzipped code size limit for a Lambda (includes layers), so large dependencies might be put in layers but we must still watch overall size ￼ ￼. Finally, note that AIG’s policy of “extract business logic into shared libs” ￼ can be implemented via layers or as separate NPM packages – but layers are convenient for sharing within the AWS environment without a private package repo.

Takeaways: Attendees learn what Lambda Layers are and how they facilitate code reuse across functions ￼. They understand that common concerns (logging, utilities, SDK wrappers, etc.) can be abstracted into layers, supporting the single-responsibility principle by keeping individual Lambdas lightweight. They also grasp the need to manage layers properly (small size, proper versioning) to avoid pitfalls (e.g., large layers slowing cold starts).

3. Observability & Logging (Structured Logs & Correlation IDs) (15 minutes)

Now we dive deeper into observability, a critical part of AIG’s Lambda policy. This section covers logging, tracing, and correlation IDs in detail. The presenter will show how to implement structured JSON logging in Node.js and explain what correlation IDs are and how they propagate through a serverless system. These practices ensure that when something goes wrong (or right), developers can trace and debug the workflow.
	•	Slide: “Structured Logging in JSON.” Explain why we log in structured JSON format. Instead of plain text, JSON logs have key–value pairs that Splunk or CloudWatch can easily parse. According to the policy, logs should include fields like requestId (correlation ID), service name, version, and important business keys ￼ ￼. Show a brief example of a JSON log entry (for instance, an object with timestamp, level, message, requestId, etc.). Mention that using a logging library like Pino or Winston in JSON mode can simplify this. In Node.js, one approach (demonstrated in the policy) is to create a logger instance and use child loggers to append context ￼ ￼. Emphasize that consistent structured logs are crucial for monitoring and debugging in a microservice environment.
	•	Slide: “Correlation IDs – Tracking a Request.” Define Correlation ID: an identifier (e.g., a UUID) that is passed through every step of a transaction or workflow. In AWS, you might get an initial ID from API Gateway or generate one if not provided. The Lambda should log this ID and also pass it along if it calls other services (e.g., include it in messages sent to SQS or in responses) ￼. Walk through the example from AIG’s Node.js template: the handler checks for an incoming x-correlation-id header, or an AWS request ID if none, and uses that as the requestId for logging ￼. This ensures every log from that function invocation is tagged. If that function puts an event on a queue, it should attach the same ID so that the next Lambda in the chain can continue the trace ￼. This creates an end-to-end trail for a transaction.
	•	Code Snippet (on slide or demo): Show a small excerpt from handler.js demonstrating correlation ID usage. For example:

const requestId = event.headers?.['x-correlation-id'] || context.awsRequestId;
const log = logger.child({ requestId });
log.info("Start processing event");

Point out how the code prefers an existing ID from upstream, or falls back to the Lambda’s own awsRequestId ￼. Also note the log context includes fn: context.functionName in the example ￼, which is useful to know which function generated a log entry.

	•	Slide: “Distributed Tracing (X-Ray) & Metrics.” Briefly touch on other observability facets. AIG mandates enabling AWS X-Ray for tracing requests through services (Lambda, API Gateway, Step Functions) ￼. Explain that X-Ray provides end-to-end trace maps and timing information. Also mention custom metrics: Lambdas can emit business or performance metrics (e.g., via CloudWatch Embedded Metric Format or manually put metrics). However, given time, focus on what’s in policy: e.g., set CloudWatch alarms on error rates, throttles, and latency (p95) by default ￼. In short, logging is step one, but we also ensure metrics and tracing are in place for a complete observability setup.
	•	Slide (Optional Demo): “Logging Demo.” The presenter can run a quick local demo of the logging. For instance, invoke a sample Lambda handler locally (using SAM CLI) and show the console output of a structured log. Show how the log appears as JSON and highlight the correlation ID field in it. This reinforces the concept in a concrete way.

Takeaways: Developers understand that every Lambda function should produce structured JSON logs with key fields (especially a correlation ID) ￼. They learn how correlation IDs are used to tie together logs from different components, making it possible to trace a single transaction across multiple Lambdas or services. They are also aware that AIG’s environment uses X-Ray tracing and CloudWatch metrics/alarms by default for monitoring ￼, ensuring that no Lambda is a “black box” during operations.

4. Monitoring & Splunk Integration (15 minutes)

In this section, we demonstrate how the structured logs and correlation IDs we've implemented become powerful operational tools through Splunk. We'll show the complete pipeline from Lambda to Splunk, demonstrate real queries, and optionally demo Splunk running locally (via docker-compose) to visualize the workshop's Lambda logs.

	•	Slide: "CloudWatch Logs to Splunk Pipeline." Explain the architecture:
		○	Lambda Functions → CloudWatch Logs (automatic, every console.log becomes a CloudWatch entry)
		○	CloudWatch Logs Subscription Filter → Forwarder (Lambda or Firehose) → Splunk HTTP Event Collector (HEC)
		○	All logs arrive in Splunk within seconds, indexed and searchable
		○	Show diagram: [Lambda] → [CW Logs] → [Subscription] → [Forwarder] → [Splunk HEC] → [Splunk Index]
		○	Emphasize: Because we use structured JSON logging, Splunk can parse fields automatically (requestId, level, functionName, etc.)

	•	Slide: "Why Structured Logs Matter in Splunk." Contrast examples:
		○	Bad (unstructured): "Error processing item 12345 in function api-handler"
			▪	Hard to query: full-text search only, can't filter by specific fields
		○	Good (structured JSON): {"level":"ERROR","requestId":"12345","functionName":"api-handler","message":"Error processing item"}
			▪	Easy queries: level=ERROR, requestId=12345, functionName=api-handler
			▪	Can aggregate, trend, and alert on specific fields

	•	Demo (Optional): "Splunk Local Demo with Workshop Logs." If time permits:
		○	CODE DEMO: Start Splunk locally: docker-compose --profile monitoring up -d splunk
		○	Access Splunk Web: http://localhost:8000 (admin / Admin123!)
		○	Configure HEC token and forwarder (pre-configured in workshop)
		○	Run a test workflow on LocalStack: make test-e2e
		○	Show logs appearing in Splunk Search & Reporting app
		○	Run example query: index="lambda" requestId="test-*" | table _time functionName level message
		○	Highlight how all logs from api-service, processor-service, export-service appear together

	•	Slide: "Common Splunk Queries for Lambda Monitoring." Show practical examples:
		1. Find all errors across all Lambdas:
			index="lambda" level="ERROR" | stats count by functionName
		2. Trace a single transaction by correlation ID:
			index="lambda" requestId="abc-123" | sort _time | table _time functionName level message
		3. Monitor SQS processing failures:
			index="lambda" functionName="*processor*" level="ERROR" | stats count by messageId
		4. Alert on high error rates:
			index="lambda" level="ERROR" | timechart span=5m count by functionName
		5. Find slow Lambda invocations (if duration is logged):
			index="lambda" duration>5000 | stats avg(duration) by functionName

	•	Slide: "Splunk Dashboards for Lambda Operations." Explain dashboard use cases:
		○	Lambda Health Dashboard: Shows error rates, invocation counts, duration percentiles per function
		○	Transaction Tracing Dashboard: Input a requestId, see timeline of all related events
		○	SQS Processing Dashboard: Messages processed, DLQ depth, processing errors
		○	Cost Insights: Lambda invocations over time, estimated costs (from CloudWatch metrics)
		○	Example: Show mockup or screenshot of a dashboard with panels for each metric

	•	Slide: "Correlation in Action – Multi-Service Tracing." Walk through a scenario:
		○	User makes POST /enqueue request → API Gateway generates requestId: req-789
		○	API Lambda logs: {"requestId":"req-789","level":"INFO","message":"Enqueued to SQS"}
		○	SQS message includes x-correlation-id: req-789 in message attributes
		○	Processor Lambda logs: {"requestId":"req-789","level":"INFO","message":"Wrote to DynamoDB"}
		○	Export Lambda logs: {"requestId":"req-789","level":"INFO","message":"Exported to S3"}
		○	Splunk query: index="lambda" requestId="req-789"
			▪	Results show complete journey across 3 services, chronologically ordered
			▪	If there's an error, you can immediately see where it occurred and what data was involved

	•	Slide: "Alerting with Splunk." Explain alert setup:
		○	Real-time alerts: Trigger when specific conditions occur (e.g., ERROR level with specific message)
		○	Scheduled searches: Run every N minutes, alert if threshold exceeded (e.g., >10 errors/minute)
		○	Example alert: "Notify on-call engineer if DLQ receives messages"
			▪	Query: index="lambda" source="/aws/lambda/*dlq*" | stats count
			▪	Trigger: count > 0
			▪	Action: Send PagerDuty alert with correlation ID and error details
		○	Integration with incident management: Splunk → PagerDuty/ServiceNow/Slack

	•	Slide: "Best Practices for Splunk with Lambdas." Summarize recommendations:
		○	Always log in JSON format with consistent field names
		○	Include correlation IDs in every log entry
		○	Log important business events (e.g., "payment processed", "export completed")
		○	Avoid logging sensitive data (PII, credentials) – use field masking if needed
		○	Use log levels appropriately: DEBUG, INFO, WARN, ERROR
		○	Set up baseline dashboards and alerts from day one
		○	Regularly review slow query logs and optimize logging volume

Takeaways: Participants understand that Splunk transforms raw Lambda logs into actionable operational intelligence ￼. They've seen practical queries for troubleshooting, tracing transactions, and monitoring health. The correlation ID pattern enables powerful cross-service tracing that would be impossible with unstructured logs. They know how to set up alerts to catch issues proactively. Optional Splunk demo (if shown) makes it tangible by visualizing real workshop logs. The key message: observability isn't just about logging – it's about making logs useful for operations, and Splunk is the enterprise tool that enables this at scale.

5. Local Testing with AWS SAM CLI & LocalStack (20 minutes)

This section demonstrates the complete local development workflow using SAM CLI for individual function testing and LocalStack for end-to-end integration testing. Unlike optional tools, LocalStack is a core part of our development process, allowing us to test the entire serverless architecture locally before deploying to AWS.

	•	Slide: "Why Local Testing + LocalStack?" Motivate the two-tier testing approach:
		○	Tier 1 (SAM Local): Quick iteration on individual Lambda functions using sam local invoke and sam local start-api. Fast feedback loop for unit-style testing.
		○	Tier 2 (LocalStack): Full integration testing with real AWS services (DynamoDB, SQS, S3, API Gateway) running locally. This catches integration issues early and allows testing complete workflows without AWS costs or access requirements.
		○	Emphasize that LocalStack is not "nice to have" – it's essential for validating cross-service interactions, testing IAM policies, and ensuring observability (logs, traces) work end-to-end before deploying.

	•	Slide: "SAM CLI Basics (Tier 1 Testing)." Cover key commands:
		○	sam build – compiles/bundles Lambda code using esbuild for TypeScript ￼
		○	sam local invoke <FunctionLogicalID> -e event.json – test a single function in isolation ￼
		○	sam local start-api – local API Gateway emulator for HTTP endpoints ￼
		○	sam local generate-event – generate sample events for various triggers ￼

	•	Demo: "Quick Local Test (No LocalStack)." Show testing a single service:
		○	CODE DEMO: Navigate to services/api-service/
		○	Run sam build && sam local invoke ApiFunction --event events/test-event.json
		○	Show structured JSON logs appearing in console with correlation ID
		○	Explain this is great for rapid iteration but doesn't test SQS integration

	•	Slide: "Introducing LocalStack – Your Local AWS." Explain LocalStack:
		○	Open-source tool that emulates 80+ AWS services locally via Docker
		○	Accessed at localhost:4566 (single endpoint for all services)
		○	Supports CloudFormation/SAM deployments just like real AWS
		○	Critical for testing: queue processing, database operations, S3 interactions, IAM policies

	•	Slide: "LocalStack Setup." Show the setup (already done in workshop repo):
		○	CODE DEMO: Show docker-compose.yml with LocalStack configuration
		○	Start LocalStack: make localstack-up (or localstack start for CLI-only approach)
		○	Verify health: curl http://localhost:4566/_localstack/health
		○	Introduce awslocal CLI wrapper (same as aws cli but pre-configured for LocalStack)

	•	Demo: "Deploy Full Stack to LocalStack." Walk through real deployment:
		○	CODE DEMO: Show the multi-project structure (infrastructure/, layers/, services/)
		○	Step 1: Deploy infrastructure – make deploy-infrastructure
			▪	Creates DynamoDB table, SQS queue with DLQ, S3 bucket
			▪	Show awslocal cloudformation describe-stacks output
			▪	Show resources: awslocal dynamodb list-tables, awslocal sqs list-queues
		○	Step 2: Deploy layers – make deploy-layers
			▪	Packages shared logger and correlation utilities
			▪	Show layer ARN in output
		○	Step 3: Deploy services – make deploy-services
			▪	Deploys api-service, processor-service, export-service as separate stacks
			▪	Each service references shared infrastructure via parameters
			▪	Show deployed functions: awslocal lambda list-functions

	•	Demo: "End-to-End Test on LocalStack." Show real workflow:
		○	CODE DEMO: Run make test-e2e
		○	Trace a request through the entire system:
			1.	POST to API Lambda (enqueue) → Returns correlation-id: test-12345
			2.	Message appears in SQS → awslocal sqs receive-message
			3.	Processor Lambda triggers → Writes to DynamoDB
			4.	Verify in DDB → awslocal dynamodb get-item --table-name workshop-local-items --key '{"id":{"S":"test-12345"}}'
			5.	Call Export Lambda → Reads from DDB, writes to S3
			6.	Verify S3 object → awslocal s3 ls s3://workshop-local-exports/exports/
		○	Highlight correlation ID preserved throughout entire flow
		○	Show structured logs from CloudWatch: awslocal logs tail /aws/lambda/workshop-api-service-ApiFunction

	•	Slide: "LocalStack Capabilities & Limitations." Set expectations:
		○	Capabilities: Most common services, CloudFormation/SAM support, Lambda execution, event triggers, IAM policy evaluation (basic)
		○	Limitations: Not 100% API-compatible (some advanced features missing), IAM enforcement simpler than AWS, performance differs
		○	Best Practice: Use LocalStack for integration tests, but always validate in real dev AWS account before production

	•	Demo (if time): "Debugging with LocalStack." Show advanced techniques:
		○	Viewing Lambda logs: awslocal logs filter-log-events --log-group-name /aws/lambda/<function>
		○	Inspecting SQS DLQ for failed messages
		○	Testing partial batch failures by sending messages that intentionally fail

Takeaways: Developers master the two-tier local testing approach ￼. Tier 1 (SAM local) provides fast iteration on individual functions. Tier 2 (LocalStack) enables true integration testing with full AWS service emulation locally, catching issues that unit tests miss. They've seen a complete deployment and end-to-end test on LocalStack, understanding that this is the standard workflow before any AWS deployment. The combination of SAM + LocalStack dramatically reduces development cycle time and cloud costs.

6. Common Lambda Patterns & Examples (15 minutes)

In this section, we walk through the actual workshop code, showing three real Lambda services that demonstrate best practices. Each service is a separate SAM project, showcasing how to structure microservices in a realistic way. We'll examine the code patterns, run them locally, and explain how they implement the principles covered earlier.

	•	Slide: "Workshop Architecture Overview." Show the multi-service architecture:
		○	CODE DEMO: Display the project structure:
			```
			services/
			  ├── api-service/        (HTTP API → SQS)
			  ├── processor-service/   (SQS → DynamoDB)
			  └── export-service/      (HTTP API → DynamoDB → S3)
			```
		○	Explain the flow: POST /enqueue → SQS → DynamoDB → GET /export/{id} → S3
		○	Each service is independently deployable, has its own SAM template, and shares the layer
		○	This mimics real microservice architecture, not a monolithic sam template

	•	Demo: "API Service – Enqueue with Correlation ID." Walk through services/api-service/src/handler.ts:
		○	CODE DEMO: Open services/api-service/src/handler.ts in editor
		○	Line 17: const requestId = getRequestId(event, context) – extracts correlation ID from header or generates one
		○	Line 18-23: Creates logger with requestId, service name, function name – structured logging setup
		○	Line 34-42: Sends message to SQS with correlation ID in MessageAttributes
		○	Line 44: Logs success with item ID – enables tracing in Splunk
		○	Line 48-50: Returns correlation ID in response headers – allows client to track request
		○	Error handling (54-60): Logs error with serialized details, returns 500 but doesn't crash
		○	Run demo: sam local invoke ApiFunction --event events/test-event.json
			▪	Show JSON logs in console with requestId field
			▪	Point out how correlation ID would flow to downstream services

	•	Demo: "Processor Service – SQS Batch with Partial Failures." Walk through services/processor-service/src/handler.ts:
		○	CODE DEMO: Open services/processor-service/src/handler.ts
		○	Line 16: const failures: string[] = [] – tracks failed message IDs
		○	Line 18-39: Loop through SQS records, process each individually
		○	Line 19: Creates child logger with messageId – every log entry traceable to specific message
		○	Line 31: ConditionExpression: 'attribute_not_exists(id)' – ensures idempotency (won't insert duplicate)
		○	Line 35-37: Catch errors, log them, add messageId to failures array
		○	Line 41-44: Return { batchItemFailures: [...] } – partial batch response
		○	Explain: Only failed messages return to queue (up to maxReceiveCount), then go to DLQ
		○	Show infrastructure/base-resources.yaml: DLQ configured with maxReceiveCount: 3
		○	Run demo: sam local invoke ProcessorFunction --event events/test-event.json
			▪	Modify event to include a message that will fail
			▪	Show batchItemFailures in response
			▪	Explain in production, this message would retry 3 times, then DLQ

	•	Demo: "Export Service – DynamoDB to S3 with Tracing." Walk through services/export-service/src/handler.ts:
		○	CODE DEMO: Open services/export-service/src/handler.ts
		○	Line 28: Extracts id from path parameters – RESTful API pattern
		○	Line 33: GetItemCommand – reads from DynamoDB
		○	Line 38-44: Builds export object, includes exportedAt timestamp
		○	Line 46-52: PutObjectCommand – writes JSON to S3
		○	Line 55: Logs success with S3 key – enables audit trail
		○	Line 59: Returns correlation ID in response – end-to-end traceability
		○	Run demo: sam local start-api in export-service directory
			▪	In another terminal: curl http://localhost:3000/export/test-123
			▪	Show 404 response (item doesn't exist locally), but logs show correlation ID
			▪	On LocalStack with real data, this would return the exported item

	•	Slide: "Code Patterns Summary." Recap what we saw:
		○	Correlation ID extraction and propagation (every service)
		○	Structured logging with child loggers (per-request, per-message context)
		○	Idempotency via DynamoDB conditional writes
		○	Partial batch failures for SQS processing
		○	Error handling: log, serialize details, fail gracefully
		○	Least privilege IAM: each service's template has minimal permissions
		○	Dead Letter Queues for reliability
		○	All patterns align with AIG policy requirements ￼ ￼
	•	Discussion: While showing these examples, connect them back to principles:
	•	The SQS handler is idempotent (assuming processMessage is written to handle deduplication or is side-effect free on retries) and uses single-responsibility (just orchestrating messages, delegating processing) and shows resilience by handling partial failures gracefully ￼ ￼.
	•	The API handler shows observability by default (logging and correlation) and good error handling (logs the error once with context and rethrows) ￼.
	•	Both examples underscore structured logging and capturing important identifiers (message IDs, correlation IDs) in logs for traceability.

Takeaways: Attendees see concrete code that implements the best practices discussed. The SQS example teaches how to handle batch events safely by only retrying failures (and the importance of DLQs) ￼ ￼. The API example demonstrates injecting and returning correlation IDs and proper structured logging ￼ ￼. These patterns are directly applicable to many real-world scenarios and serve as templates for their own Lambdas.

7. CI/CD Pipeline & IAM Overview (10 minutes)

The final content section provides a high-level overview of how these Lambda functions fit into the bigger picture of deployment and security. It’s not a deep dive, but attendees should know there is an automated pipeline for building/testing/deploying Lambdas and the basics of IAM roles and permissions that apply. This reinforces earlier points about least privilege and testing.
	•	Slide: “CI/CD Pipeline at a Glance.” Describe the typical continuous integration/continuous deployment flow for Lambda projects (for example, using GitHub Actions or Jenkins). AIG’s example pipeline (shown in the policy) involves stages: linting the code, running unit tests, building the SAM package, validating it, optionally running local integration tests (perhaps with LocalStack), then deploying to a dev environment, running integration tests in AWS, and finally promoting to prod upon approval ￼ ￼. Summarize this in simpler terms: “Code → Build/Test → Deploy to Dev → Test → Promote to Prod”. Emphasize that much of this can be automated. Also highlight the AWS authentication aspect: rather than hard-coding credentials, the pipeline uses an OpenID Connect (OIDC) or similar mechanism to assume an AWS IAM role for deployment ￼. For instance, the CI pipeline assumes a role like ci-deployer with rights to deploy Lambdas, avoiding long-lived AWS keys ￼. This is just for awareness so developers trust the delivery process and understand where their code goes after they commit.
	•	Slide: “IAM Roles & Security.” Reiterate the execution role concept for Lambdas: each Lambda function has its own IAM role that dictates what it can access. The policy demands minimal privileges on these roles – e.g., if a function only needs to read one S3 bucket, its policy should allow only s3:GetObject on that bucket ARN and nothing more ￼. This is enforced both for security and to uphold least privilege design ￼. Also mention IAM practices for developers: at AIG, developers have elevated access in non-prod accounts but read-only in prod for safety ￼ (this explains why, for example, one might be able to use AWS console in dev but not modify things in prod without special permission). Additionally, touch on IAM guardrails in place (Service Control Policies) – for instance, blocking any wildcard (*:*) IAM policies or disallowing certain risky configurations in Lambdas ￼. These guardrails ensure compliance (like preventing public S3 or plaintext secrets) and support the security posture. Finally, encourage developers to always think about IAM when building a Lambda: “What AWS resources does this function truly need?” and scope the role accordingly.
Optional: Show a tiny excerpt of an IAM policy JSON for a Lambda role (as given in the policy doc) to illustrate resource scoping – for example, a policy that only allows DynamoDB PutItem on a specific table ARN ￼. This makes the advice concrete.

Takeaways: Participants gain awareness of how their Lambda code goes from source to deployed (CI/CD pipeline) and the rigors of testing/approval in that process ￼. They also internalize the importance of IAM least privilege: every Lambda should have a tailored role, not a broad one ￼ ￼. Even if some attendees won’t set up pipelines themselves, they know such processes exist to catch issues early and enforce quality and security gates before production.

Conclusion & Next Steps (5 minutes)

Wrap up the workshop by recapping the key lessons and providing guidance on what to do next. This section also allows time for any final questions.
	•	Slide: “Key Takeaways Recap.” List the top 3-5 messages from the workshop:
	•	Design Lambdas to be stateless, idempotent, and focused; this makes them robust and easy to maintain ￼.
	•	Employ built-in observability: structured JSON logs with correlation IDs, metrics, and tracing, so you can monitor and troubleshoot effectively from day one ￼.
	•	Use Lambda Layers and shared libraries to avoid code duplication and enforce consistency across functions ￼.
	•	Test locally with SAM for fast feedback, but also trust the CI/CD and guardrails in place for full validation and security ￼.
	•	Follow AIG’s policy and best practices (least privilege IAM, proper error handling, DLQs for async workflows, etc.) to ensure production reliability and compliance ￼ ￼.
	•	Slide: “Next Steps and Resources.” Encourage attendees to apply what they learned in their next Lambda project. Provide links or references for further reading: e.g., the AIG internal documentation or the “AWS Lambda (Node.js) Engineering Policy & Playbook” (the very document we’ve been referencing) for more details ￼ ￼. Also suggest official AWS resources on Lambda best practices and the AWS SAM CLI. If the team has sample code repositories or templates following these guidelines, point those out as starting points.
	•	Mention that the workshop could be followed by a hands-on session in the future if there’s interest, where developers can practice writing a Lambda with these principles under guidance.
	•	Closing: Thank everyone for attending. Remind them that adopting these practices will lead to Lambdas that are easier to manage and less likely to cause production issues. Invite final questions.

Takeaways: The audience leaves with a clear summary of what they learned and resources to explore more. They should feel more confident in designing, coding, and operating Lambda functions “the AIG way,” and understand how all the pieces (design principles, layers, logging, testing, CI/CD, etc.) fit together in the lifecycle of a serverless application.

⸻

Optional: Splitting into Two Sessions – If time is tight or the audience would prefer shorter sessions, this 2-hour workshop can be split into two 1-hour sessions:
	•	Session 1 (1 hour): Cover sections 1–4 (Design Principles, Lambda Layers, Observability, and Splunk). This session focuses on foundational concepts and logging/monitoring. Include the introduction and possibly one code example (the API Gateway correlation ID example) to illustrate concepts.
	•	Session 2 (1 hour): Cover sections 5–7 (Local Testing, Examples, CI/CD & IAM). This session is more hands-on and advanced, with demos of SAM CLI and deeper dive into the SQS example, plus deployment and security considerations.
Each session would recap key points from the previous one to reinforce learning. Splitting the workshop can help accommodate schedules and give participants time to digest the first session before moving to the second.