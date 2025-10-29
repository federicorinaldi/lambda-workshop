.PHONY: help localstack-up localstack-down localstack-status install build-all deploy-all test-all clean

# Default AWS endpoint for LocalStack
export AWS_ENDPOINT_URL ?= http://localhost:4566
export AWS_REGION ?= us-east-1
export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test

help:
	@echo "Lambda Workshop - Make Commands"
	@echo "================================"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  make setup-and-test       - ONE COMMAND to do everything (recommended for new setup)"
	@echo ""
	@echo "LocalStack Management:"
	@echo "  make localstack-up        - Start LocalStack (docker-compose)"
	@echo "  make localstack-start     - Start LocalStack (CLI only)"
	@echo "  make localstack-down      - Stop LocalStack"
	@echo "  make localstack-status    - Check LocalStack health"
	@echo ""
	@echo "Build & Deploy:"
	@echo "  make install              - Install dependencies for all services"
	@echo "  make build-all            - Build all services and layers"
	@echo "  make deploy-infrastructure - Deploy base infrastructure (DynamoDB, SQS, S3)"
	@echo "  make deploy-layers        - Deploy shared Lambda layers"
	@echo "  make deploy-services      - Deploy all Lambda services"
	@echo "  make deploy-all           - Deploy everything (infra + layers + services)"
	@echo ""
	@echo "Testing:"
	@echo "  make test-local           - Test with SAM local (no LocalStack)"
	@echo "  make test-e2e             - Run end-to-end tests on LocalStack"
	@echo "  make test-all             - Run all tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean                - Clean build artifacts"
	@echo "  make clean-all            - Clean everything including LocalStack data"

# 🚀 One command to rule them all
setup-and-test:
	@echo "========================================="
	@echo "🚀 Lambda Workshop - Complete Setup"
	@echo "========================================="
	@echo ""
	@echo "This will:"
	@echo "  1. Install dependencies"
	@echo "  2. Start LocalStack"
	@echo "  3. Deploy infrastructure"
	@echo "  4. Deploy all services"
	@echo "  5. Run end-to-end tests"
	@echo ""
	@$(MAKE) install
	@$(MAKE) localstack-up
	@$(MAKE) deploy-infrastructure
	@$(MAKE) deploy-services
	@$(MAKE) test-e2e
	@echo ""
	@echo "========================================="
	@echo "✅ Setup Complete!"
	@echo "========================================="
	@echo ""
	@echo "Your Lambda Workshop is ready to use!"
	@echo "Run 'make help' to see all available commands."
	@echo ""

# LocalStack with docker-compose (recommended for workshop)
localstack-up:
	@echo "Starting LocalStack with docker-compose..."
	docker-compose up -d localstack
	@echo "Waiting for LocalStack to be ready..."
	@bash scripts/wait-for-localstack.sh

# Alternative: Start LocalStack with CLI only
localstack-start:
	@echo "Starting LocalStack with CLI..."
	@echo "Note: Make sure LocalStack CLI is installed (pip install localstack)"
	localstack start -d
	@bash scripts/wait-for-localstack.sh

localstack-down:
	docker-compose down

localstack-status:
	@echo "Checking LocalStack health..."
	@curl -s http://localhost:4566/_localstack/health | jq '.' || echo "LocalStack not responding"

# Install dependencies
install:
	@echo "Installing dependencies..."
	npm install
	cd services/api-service && npm install
	cd services/processor-service && npm install
	cd services/export-service && npm install

# Build all projects
build-all:
	@echo "Building shared layers..."
	cd layers && $(MAKE) build
	@echo "Building API service..."
	cd services/api-service && sam build
	@echo "Building Processor service..."
	cd services/processor-service && sam build
	@echo "Building Export service..."
	cd services/export-service && sam build

# Deploy to LocalStack
deploy-infrastructure:
	@echo "Deploying base infrastructure..."
	bash scripts/deploy-infrastructure.sh

deploy-layers:
	@echo "Deploying shared layers..."
	bash scripts/deploy-layers.sh

deploy-services:
	@echo "Deploying all services..."
	bash scripts/deploy-services.sh

deploy-all: build-all deploy-infrastructure deploy-layers deploy-services
	@echo "✅ All services deployed to LocalStack!"
	@bash scripts/show-endpoints.sh

# Testing
test-local:
	@echo "Running local SAM tests (no LocalStack required)..."
	bash scripts/test-local.sh

test-e2e:
	@echo "Running end-to-end tests on LocalStack..."
	bash scripts/test-e2e.sh

test-all: test-local test-e2e

# Cleanup
clean:
	rm -rf services/*/\.aws-sam
	rm -rf layers/.aws-sam
	rm -rf services/*/node_modules
	find . -name "*.log" -delete

clean-all: clean
	docker-compose down -v
	rm -rf localstack-data
