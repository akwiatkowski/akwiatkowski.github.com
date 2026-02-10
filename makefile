PORT := 5001

PUBLIC_PATH_PART := public
DEV_BASE_PATH := env/dev
FULL_BASE_PATH := env/full
DEV_SRC_PATH := $(DEV_BASE_PATH)/src
FULL_SRC_PATH := $(FULL_BASE_PATH)/src

PYTHON_SERVER := python3 -m http.server $(PORT)
CRYSTAL_COMMAND := crystal

RENDER_RELEASE_TARGET_COMMAND_PATH := render_release.cr
RENDER_LOCAL_TARGET_COMMAND_PATH := render_local.cr
RUN_LOCAL_TARGET_COMMAND_PATH := run_local.cr

EXEC_BLOG_LOCAL := blog_local

COMPILE_LOCAL_RELEASE_FLAG := --release

.PHONY: dev_serve_local dev_serve_release dev_render_release dev_render_local \
        serve_local serve_release render_release render_local \
        compile_local run_compiled_local run_compiled_local_check watch_coffee watch_local_mac \
        dev-purge-html-local dev-purge-html-release purge-html-local purge-html-release \
        dev-purge-empty-local dev-purge-empty-release purge-empty-local purge-empty-release \
        test-e2e test-e2e-headed test-e2e-smoke transpile-jsx setup-photo-analysis

# Assets
watch_coffee:
	coffee -bcw data/assets/js/*.coffee

# Transpile all JSX files to JS (Preact-compatible)
transpile-jsx:
	@for f in data/assets/js/src/*.jsx; do \
		out="data/assets/js/self/$$(basename "$${f}" .jsx).js"; \
		echo "$$f -> $$out"; \
		npx esbuild "$$f" --bundle=false --outfile="$$out" --jsx-factory=React.createElement --jsx-fragment=React.Fragment; \
	done

# Dev serve targets (dynamic pattern)
dev-serve-%:
	cd $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/$* && $(PYTHON_SERVER)

dev-render-release:
	$(CRYSTAL_COMMAND) $(DEV_SRC_PATH)/$(RENDER_RELEASE_TARGET_COMMAND_PATH)

dev-render-local:
	$(CRYSTAL_COMMAND) $(DEV_SRC_PATH)/$(RENDER_LOCAL_TARGET_COMMAND_PATH)

# Full env serve targets (dynamic pattern)
serve-%:
	cd $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/$* && $(PYTHON_SERVER)

render-release:
	$(CRYSTAL_COMMAND) $(FULL_SRC_PATH)/$(RENDER_RELEASE_TARGET_COMMAND_PATH)

render-local:
	$(CRYSTAL_COMMAND) $(FULL_SRC_PATH)/$(RENDER_LOCAL_TARGET_COMMAND_PATH)

# Compile local executable
compile_local:
	$(CRYSTAL_COMMAND) build $(FULL_SRC_PATH)/$(RUN_LOCAL_TARGET_COMMAND_PATH) -o $(FULL_BASE_PATH)/$(EXEC_BLOG_LOCAL) $(COMPILE_LOCAL_RELEASE_FLAG)

# Run compiled executable (assumes it's present)
run_compiled_local:
	CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES="*" $(FULL_BASE_PATH)/$(EXEC_BLOG_LOCAL)

# Run compiled executable with check, compile if missing
run_compiled_local_check:
	if [ ! -f $(FULL_BASE_PATH)/$(EXEC_BLOG_LOCAL) ]; then \
		$(MAKE) compile_local; \
	fi; \
	CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES="*" $(FULL_BASE_PATH)/$(EXEC_BLOG_LOCAL)

# File watcher for macOS to compile and run with check
watch_local_mac:
	watchman-make -p '**/*.cr' '**/*.h' 'Makefile*' -t compile_local -p '**/*.md' 'tests/**/*.c' -t run_compiled_local_check

# Purge generated files (HTML, XML, JSON, SVG) from output directories
# Useful for validating that registry covers all views
dev-purge-html-local:
	@echo "Purging generated files from $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/local..."
	find $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/local -type f \( -name "*.html" -o -name "*.xml" -o -name "*.json" -o -name "*.svg" \) -delete -print | wc -l | xargs -I {} echo "Deleted {} files"

dev-purge-html-release:
	@echo "Purging generated files from $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/release..."
	find $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/release -type f \( -name "*.html" -o -name "*.xml" -o -name "*.json" -o -name "*.svg" \) -delete -print | wc -l | xargs -I {} echo "Deleted {} files"

purge-html-local:
	@echo "Purging generated files from $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/local..."
	find $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/local -type f \( -name "*.html" -o -name "*.xml" -o -name "*.json" -o -name "*.svg" \) -delete -print | wc -l | xargs -I {} echo "Deleted {} files"

purge-html-release:
	@echo "Purging generated files from $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/release..."
	find $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/release -type f \( -name "*.html" -o -name "*.xml" -o -name "*.json" -o -name "*.svg" \) -delete -print | wc -l | xargs -I {} echo "Deleted {} files"

# Purge empty directories from output directories
# Run after purge-html-* to clean up leftover empty directories
dev-purge-empty-local:
	@echo "Purging empty directories from $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/local..."
	find $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/local -type d -empty -delete -print 2>/dev/null | wc -l | xargs -I {} echo "Deleted {} directories"

dev-purge-empty-release:
	@echo "Purging empty directories from $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/release..."
	find $(DEV_BASE_PATH)/$(PUBLIC_PATH_PART)/release -type d -empty -delete -print 2>/dev/null | wc -l | xargs -I {} echo "Deleted {} directories"

purge-empty-local:
	@echo "Purging empty directories from $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/local..."
	find $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/local -type d -empty -delete -print 2>/dev/null | wc -l | xargs -I {} echo "Deleted {} directories"

purge-empty-release:
	@echo "Purging empty directories from $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/release..."
	find $(FULL_BASE_PATH)/$(PUBLIC_PATH_PART)/release -type d -empty -delete -print 2>/dev/null | wc -l | xargs -I {} echo "Deleted {} directories"

# E2E Tests (requires: cd tests/e2e && npm install && npx playwright install chromium)
test-e2e:
	cd tests/e2e && npx playwright test

test-e2e-headed:
	cd tests/e2e && npx playwright test --headed

test-e2e-smoke:
	cd tests/e2e && npx playwright test specs/smoke.spec.js

# Photo analysis setup (Python + imagehash)
setup-photo-analysis:
	pip install -q -r requirements.txt
