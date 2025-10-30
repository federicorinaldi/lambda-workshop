# LocalStack Setup Requirements for Rootless Podman with SELinux

## Environment Context
This document covers the additional setup steps required to run the Lambda Workshop with LocalStack in an environment using:
- **Podman in rootless mode** (instead of Docker)
- **SELinux enforcing** mode
- **No sudo access** for installing global packages

## Issues Encountered and Solutions

### Issue 1: LocalStack Container Failing to Start

**Problem:**
The LocalStack container would start but immediately exit with error code 1. The container couldn't access the Docker socket to spawn Lambda containers because:
- The system uses podman in rootless mode
- The user's socket is at `/run/user/<UID>/podman/podman.sock`
- The `docker-compose.yml` was mounting `/var/run/docker.sock` (root-owned socket)
- SELinux was blocking container access to the socket

**Solution:**
Created a `docker-compose.override.yml` file in the project root:

```yaml
# docker-compose.override.yml
# Local environment overrides for rootless podman setup with SELinux

services:
  localstack:
    volumes:
      # Override: Use user's podman socket instead of system docker socket
      # Using short syntax with :z for SELinux relabeling
      - "${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock:z"
      - "./localstack-data:/var/lib/localstack:z"
    # Add SELinux label to allow container access
    security_opt:
      - "label=disable"
```

**Why This Works:**
- `${XDG_RUNTIME_DIR}` resolves to the user's runtime directory (e.g., `/run/user/608488395`)
- The `:z` flag enables SELinux relabeling for the volume
- `security_opt: label=disable` disables SELinux isolation for the container
- Docker Compose automatically merges override files with the base configuration

### Issue 2: Missing `awslocal` CLI Tool

**Problem:**
The deployment scripts failed with `awslocal: command not found` when trying to deploy infrastructure.

**Solution:**
Install `awscli-local` using pip3 with the `--user` flag:

```bash
pip3 install --user awscli-local
```

**Verification:**
```bash
which awslocal
awslocal --version
```

The tool is installed to `~/.local/bin/awslocal` which should be in the user's PATH.

### Issue 3: Missing `esbuild` Build Tool

**Problem:**
SAM CLI failed to build Lambda functions with error: `Cannot find esbuild. esbuild must be installed on the host machine to use this feature.`

The `esbuild` package was already in the project dependencies (`services/*/node_modules/.bin/esbuild`), but SAM CLI expected it to be available on the PATH.

**Solution:**
Create a symlink to make esbuild accessible globally:

```bash
ln -s /home/u1566169/lambda-workshop/services/api-service/node_modules/.bin/esbuild ~/.local/bin/esbuild
```

**Verification:**
```bash
which esbuild
esbuild --version
```

## Complete Setup Procedure for New Users

For new users working in a similar environment (rootless podman + SELinux), follow these steps:

### 1. Clone the Repository
```bash
git clone <repository-url>
cd lambda-workshop
```

### 2. Install Dependencies
```bash
# Install Node.js dependencies
npm install

# Install awslocal CLI wrapper
pip3 install --user awscli-local

# Create esbuild symlink (after npm install completes)
ln -s $(pwd)/services/api-service/node_modules/.bin/esbuild ~/.local/bin/esbuild
```

### 3. Create Docker Compose Override
Create `docker-compose.override.yml` in the project root with the following content:

```yaml
# docker-compose.override.yml
# Local environment overrides for rootless podman setup with SELinux

services:
  localstack:
    volumes:
      - "${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock:z"
      - "./localstack-data:/var/lib/localstack:z"
    security_opt:
      - "label=disable"
```

### 4. Run the Workshop
```bash
# This should now work end-to-end
make setup-and-test
```

Or run steps individually:
```bash
make install              # Install dependencies
make localstack-up        # Start LocalStack
make deploy-infrastructure # Deploy base infrastructure
make deploy-services      # Deploy Lambda services
make test-e2e             # Run tests
```

## Verification Steps

After setup, verify everything is working:

1. **LocalStack is running:**
   ```bash
   docker ps | grep localstack
   # Should show: Up X minutes (healthy)
   ```

2. **Health check:**
   ```bash
   curl -s http://localhost:4566/_localstack/health | jq '.services.lambda'
   # Should show: "available"
   ```

3. **Run tests:**
   ```bash
   make test-e2e
   # Should see: ✅ End-to-End Test PASSED!
   ```

## Technical Details

### Why Standard Docker Setup Doesn't Work

In typical Docker installations:
- Docker daemon runs as root
- `/var/run/docker.sock` is owned by root:docker
- Users in the docker group can access the socket
- Containers can mount and use the socket

In rootless Podman setups:
- Each user has their own podman socket
- Socket location: `/run/user/<UID>/podman/podman.sock`
- SELinux enforcing mode adds additional access restrictions
- Standard docker.sock mounts fail due to permission/labeling issues

### Alternative Approaches Considered

1. **Using LAMBDA_EXECUTOR=local**: Would work but doesn't test the full Docker-based Lambda execution environment
2. **Disabling SELinux**: Not permitted in this environment and not recommended for security
3. **Running rootful podman**: Requires sudo access which is not available
4. **Global esbuild installation**: Requires sudo for npm -g, so user-level symlink was chosen

## Files Modified/Created

- `docker-compose.override.yml` - **Created** (not in git, environment-specific)
- `~/.local/bin/esbuild` - **Symlink created**
- No modifications to original codebase required

## Testing Results

After applying all fixes:
- ✅ LocalStack starts successfully and becomes healthy
- ✅ All AWS services (Lambda, API Gateway, DynamoDB, SQS, S3) available
- ✅ Infrastructure deployment succeeds
- ✅ All three Lambda services build and deploy successfully
- ✅ End-to-end tests pass with full correlation ID tracking
- ✅ Complete workflow: API Gateway → Lambda → SQS → Lambda → DynamoDB → Lambda → S3

## Future Considerations

1. **Documentation**: Update README.md with a "Rootless Podman + SELinux" section
2. **Automation**: Create a setup script (`scripts/setup-rootless-podman.sh`) that:
   - Detects rootless podman environment
   - Creates docker-compose.override.yml automatically
   - Installs awslocal and creates esbuild symlink
3. **CI/CD**: If using similar environments in CI, these steps should be added to pipeline setup

## Summary

The Lambda Workshop now works fully in a rootless Podman + SELinux environment. The key insight was that the workshop expected standard Docker socket access, which required:
1. Socket path override for rootless podman
2. SELinux permission adjustments
3. User-level installation of required CLI tools

All changes are environment-specific and don't modify the core codebase, making this solution portable and maintainable.
