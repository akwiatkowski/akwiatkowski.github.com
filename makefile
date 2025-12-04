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
        compile_local run_compiled_local run_compiled_local_check watch_coffee watch_local_mac

# Assets
watch_coffee:
	coffee -bcw data/assets/js/*.coffee

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

render_local:
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
