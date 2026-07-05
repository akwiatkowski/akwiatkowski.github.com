# ==========================================================================
# odkrywajacpolske — unified build over three orthogonal axes
#
#   ENV    = dev | full      how much input content (subset vs all posts)
#   TARGET = local | release draft visibility (release hides not-ready posts)
#   ENGINE = go | crystal     which renderer (output is engine-agnostic)
#
# Output tree (shared by both engines):  env/<ENV>/public/<TARGET>
# Caches are per-engine: env/<ENV>/cache (crystal) vs cache-go (go).
# Serve is engine-agnostic — it just serves the output tree.
#
# Everyday use:   make render          make serve
# Full release:   make render ENV=full TARGET=release ENGINE=go
# Full grammar:   make <target> ENV=.. TARGET=.. ENGINE=..
# Plan: ~/projects/claude/plans/odkrywajacpolske.md
# ==========================================================================

ENV    ?= dev
TARGET ?= local
ENGINE ?= go
PORT   ?= 5001

PUBLIC := env/$(ENV)/public/$(TARGET)

.DEFAULT_GOAL := help

# --------------------------------------------------------------------------
# Render  (ENV x TARGET x ENGINE) — both engines write $(PUBLIC)
# --------------------------------------------------------------------------
.PHONY: render render-go render-crystal
render: render-$(ENGINE)  ## Render with $(ENGINE) into env/$(ENV)/public/$(TARGET)

render-go:
	$(MAKE) -C go build
	go/bin/odkrywajac build --base . --env $(ENV) --target $(TARGET)

render-crystal:
	mise exec -- crystal env/$(ENV)/src/render_$(TARGET).cr
	@echo crystal > $(PUBLIC)/.engine   # so the next Go render forces a full rebuild

# --------------------------------------------------------------------------
# Serve  (engine-agnostic — serves whatever last rendered into $(PUBLIC))
# --------------------------------------------------------------------------
.PHONY: serve
serve:  ## Serve env/$(ENV)/public/$(TARGET) on $(PORT)
	cd $(PUBLIC) && python3 -m http.server $(PORT)

# --------------------------------------------------------------------------
# Test / lint
# --------------------------------------------------------------------------
.PHONY: test test-go test-crystal lint test-e2e test-e2e-headed test-e2e-smoke validate
test: test-$(ENGINE)  ## Unit tests for $(ENGINE)

validate:  ## Sanity-check env/$(ENV)/public/$(TARGET): links, route maps, leaked markdown
	$(MAKE) -C go build
	go/bin/odkrywajac validate --base . --env $(ENV) --target $(TARGET)

test-go:
	$(MAKE) -C go test

test-crystal:
	mise exec -- crystal spec

lint:  ## Lint the Go engine
	$(MAKE) -C go lint

test-e2e:  ## Playwright e2e (needs a server on the test port)
	cd tests/e2e && npx playwright test

test-e2e-headed:
	cd tests/e2e && npx playwright test --headed

test-e2e-smoke:
	cd tests/e2e && npx playwright test specs/smoke.spec.js

# --------------------------------------------------------------------------
# Assets
# --------------------------------------------------------------------------
.PHONY: transpile-jsx setup-photo-analysis
transpile-jsx:  ## Transpile data/assets/js/src/*.jsx -> self/*.js (Preact)
	@for f in data/assets/js/src/*.jsx; do \
		out="data/assets/js/self/$$(basename "$${f}" .jsx).js"; \
		echo "$$f -> $$out"; \
		npx esbuild "$$f" --bundle=false --outfile="$$out" --jsx-factory=React.createElement --jsx-fragment=React.Fragment; \
	done

setup-photo-analysis:  ## Install Python deps for photo analysis
	pip3 install -q -r requirements.txt

# --------------------------------------------------------------------------
# Purge  (surgical: generated markup/data ONLY)
#
# Removes generated html/xml/json/svg from $(PUBLIC). NEVER removes images
# (jpg/png/avif — including processed ones) or tiles. Those are expensive or
# precious and are excluded both by extension and by path. See the plan's
# danger rules — output dirs are never `rm -rf`'d.
# --------------------------------------------------------------------------
.PHONY: purge purge-empty
purge:  ## Delete generated html/xml/json/svg from $(PUBLIC) (keeps images/tiles)
	@echo "Purging generated files from $(PUBLIC) (images & tiles preserved)..."
	@find $(PUBLIC) -type f \
		\( -name '*.html' -o -name '*.xml' -o -name '*.json' -o -name '*.svg' \) \
		-not -path '*/tiles/*' -not -path '*/images/*' \
		-delete -print | wc -l | xargs echo "Deleted files:"

purge-empty:  ## Remove empty directories left under $(PUBLIC) after a purge
	@find $(PUBLIC) -type d -empty -not -path '*/tiles/*' -not -path '*/images/*' \
		-delete -print 2>/dev/null | wc -l | xargs echo "Deleted empty dirs:"

# --------------------------------------------------------------------------
# Generated explicit aliases (discoverability / tab-completion)
#   render-<env>-<target>-<engine>   e.g. make render-full-release-go
#   serve-<env>-<target>            e.g. make serve-dev-local
# --------------------------------------------------------------------------
define RENDER_ALIAS
.PHONY: render-$(1)-$(2)-$(3)
render-$(1)-$(2)-$(3):
	$$(MAKE) render ENV=$(1) TARGET=$(2) ENGINE=$(3)
endef
$(foreach e,dev full,$(foreach t,local release,$(foreach g,go crystal,\
	$(eval $(call RENDER_ALIAS,$(e),$(t),$(g))))))

define SERVE_ALIAS
.PHONY: serve-$(1)-$(2)
serve-$(1)-$(2):
	$$(MAKE) serve ENV=$(1) TARGET=$(2)
endef
$(foreach e,dev full,$(foreach t,local release,\
	$(eval $(call SERVE_ALIAS,$(e),$(t)))))

# --------------------------------------------------------------------------
# Help
# --------------------------------------------------------------------------
.PHONY: help
help:  ## Show this help
	@echo "odkrywajacpolske — ENV=$(ENV) TARGET=$(TARGET) ENGINE=$(ENGINE)  (override on the CLI)"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Generated aliases: render-<env>-<target>-<engine>, serve-<env>-<target>"
