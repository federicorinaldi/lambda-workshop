# Lambda Layers Example

This folder contains an **example** of how to structure shared code as a Lambda Layer in production.

## Current Workshop Implementation

For simplicity and clarity in this workshop, the shared utilities (`correlation.ts` and `logger.ts`) are **duplicated directly** in each service under `src/shared-utils.ts`.

This approach:
- ✅ Simpler for workshop attendees to understand and modify
- ✅ Works reliably with both SAM Local and LocalStack
- ✅ No build/deployment complexity for layers
- ✅ Clear code ownership per service

## Production Recommendation: Lambda Layers

In a real production environment with many Lambda functions, you should consider using Lambda Layers to share common code:

### Benefits of Layers
- **Code Reuse**: Write once, use across many functions
- **Smaller Deployments**: Functions only contain business logic
- **Centralized Updates**: Update layer to fix bugs across all functions
- **Versioning**: Pin functions to specific layer versions

### Structure
```
layers/
  shared/
    nodejs/
      shared/
        correlation.js    # Correlation ID utilities
        logger.js         # Structured logging
    Makefile            # Layer build process
  template.yaml         # SAM template for layer deployment
```

### How to Use Layers (Production)

1. **Deploy the layer:**
   ```bash
   cd layers
   sam build
   sam deploy --guided
   ```

2. **Reference in Lambda function template:**
   ```yaml
   Resources:
     MyFunction:
       Type: AWS::Serverless::Function
       Properties:
         Layers:
           - !Ref SharedUtilitiesLayer
   ```

3. **Import in your code:**
   ```javascript
   const { createLogger } = require('/opt/nodejs/shared/logger');
   const { getRequestId } = require('/opt/nodejs/shared/correlation');
   ```

### When to Use Layers

**Use Layers when:**
- You have 3+ Lambda functions sharing the same code
- The shared code changes infrequently
- You want centralized version control of dependencies
- Bundle size is a concern (50MB limit per function)

**Skip Layers when:**
- You have only 1-2 functions
- Shared code changes frequently
- You want simpler deployment (like this workshop!)
- Each team owns their own functions independently

## Alternative: NPM Packages

Another production approach is publishing shared utilities as internal NPM packages:

```bash
# Publish to private npm registry
npm publish @company/lambda-utils

# Install in each service
npm install @company/lambda-utils
```

This gives you:
- Standard Node.js dependency management
- Semantic versioning
- Easy testing and local development
- Works with any bundler (webpack, esbuild, etc.)

## Resources

- [AWS Lambda Layers Documentation](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
- [SAM Layers Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/building-layers.html)
