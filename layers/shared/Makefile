LAYER_DIR=./nodejs/shared

.PHONY: build build-SharedLayer

# Local build target
build:
	# The layer here is plain JS, but we keep a hook for future TS build
	mkdir -p $(LAYER_DIR)
	# Nothing to compile; files are already present
	@echo "Layer build complete"

# SAM calls this target during sam build for layers with BuildMethod: makefile
build-SharedLayer:
	@echo "Building shared layer for SAM..."
	mkdir -p "$(ARTIFACTS_DIR)/nodejs"
	cp -r nodejs/shared "$(ARTIFACTS_DIR)/nodejs/"
	@echo "✅ Shared layer built successfully"
	@echo "Layer contents:"
	@ls -la "$(ARTIFACTS_DIR)/nodejs/shared"


