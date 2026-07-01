# How Claude Code Helped Me Refactor a 10-Year Travel Blog Engine

## The Project

- **Crystal** static site generator for a Polish travel/photography blog
- ~100 blog posts, ~7000 photos, GPS routes, EXIF data
- Entities: 2477 towns, 380 counties, 16 voivodeships, 400+ geographic regions
- Accumulated ~10 years of technical debt

## What We Built Together (2 weeks, ~38 phases)

### By the Numbers

| Metric | Before | After |
|--------|--------|-------|
| Dead code removed | — | ~1500 lines |
| JS bundle size | 960KB | 25KB (**-97%**) |
| Tests | 0 | 623 Crystal + 232 E2E |
| View architecture | Scattered mixins | Registry + Coordinator pattern |
| Entity types | 5 separate classes | 1 unified AreaEntity |
| Late-bound properties | 13 | 1 |
| JSON payload sizes | 20MB + 836KB | Optimized endpoints (6-16KB each) |

---

## Highlight Features

### 1. Full Architecture Rewrite (Phases 1-3)

**Problem:** Rendering logic was spread across 12 mixin files with no clear execution order or dependency tracking.

**What Claude Code did:**
- Proposed and implemented a **View Registry + Coordinator** pattern
- Migrated all 50+ views from mixins to declarative registry entries with explicit dependencies and priorities
- Deleted all 12 mixin files and the abandoned render pipeline
- Created `RenderContext` (Context Object pattern) to decouple views from Blog
- Added 145 tests from scratch (views + registry)

**Why it was fast:** Claude explored the full codebase, identified all view rendering paths across mixins, and proposed the registry architecture — work that would take days of manual code archaeology.

### 2. Bootstrap 5 + jQuery Removal + Preact Migration (Phases 16-17)

**Problem:** jQuery (88KB), OpenLayers (738KB), React (140KB) — nearly 1MB of JS for a mostly-static blog.

**What Claude Code did:**
- Migrated Bootstrap 4 → 5 data attributes across all templates
- Rewrote `map.js` from jQuery to vanilla JS
- Replaced OpenLayers with Leaflet (already in project for other pages)
- Swapped React for Preact (25KB, API-compatible)
- Updated all JSX components for Preact compatibility

**Result:** From 960KB to ~25KB of framework JS. **97% reduction.**

### 3. Area Entity Unification (Phases 8, 27, 30)

**Problem:** 5 separate entity classes (TownEntity, VoivodeshipEntity, LandEntity + 2 more) with duplicated logic, different APIs, and hard-to-test code.

**What Claude Code did:**
- Designed unified `AreaEntity` with Polish grammatical inflections (nominative/genitive URL forms)
- Built `AreaDataLoader` to handle all 5 area types from a single config system
- Implemented two-pass slug disambiguation (474 towns with duplicate names got unique slugs)
- Deleted 3 deprecated entity classes and migrated all callers
- Added centralized `Router` service for URL generation

**Why it was fast:** Renaming across 30+ files, updating URL patterns in templates/JS/Crystal, and ensuring nothing broke — Claude tracked all references systematically.

### 4. GPS Geotagging Script (Standalone)

**Problem:** ~850 photos across 126 posts had no GPS coordinates despite having GPX tracklogs available.

**What Claude Code did:**
- Built a 1000-line Crystal script that matches EXIF timestamps with GPX trackpoints
- Auto-detects camera timezone offset (bruteforce 5 offsets when unknown)
- Linear interpolation between trackpoints for lat/lon/altitude
- Dry-run by default, idempotent, handles edge cases

**Result:** 637 photos geotagged across 126 posts. Script ran correctly on first real execution.

### 5. AVIF Image Delivery (Phases 36-37)

**Problem:** All images served as JPEG only. AVIF offers 30-50% smaller files.

**What Claude Code did:**
- Added `<picture>` elements with AVIF `<source>` across all image contexts (articles, galleries, pagers, related posts)
- Responsive `srcset` with 560w + 1000w descriptors
- Updated 7 JSON serializers with AVIF URL fields
- Updated 6 JSX components and 5 HTML templates
- Built shared AVIF detection (`window.__avif`) for `background-image` contexts
- Wrote 14 E2E tests verifying browser format selection

**Why it was fast:** Touching 20+ files across Crystal/HTML/JSX/CSS with consistent patterns — Claude applied the same `<picture>` pattern everywhere without drift.

### 6. Interactive Page Redesigns

**Towns Index** — From a plain `<ol>` of 2477 names to a Preact-powered page with photo cards, search, voivodeship grouping. Only towns with posts shown (~500).

**Area Show Pages** — Hero photo+map blend, polygon overlay, compact stats, vertical post cards, fuzzy-scored related areas. 4x render performance (1100ms → 272ms) via memoization.

**Photo Planner** — From broken standalone page to integrated Leaflet grid map with dark mode, 99.9% data reduction (20MB → 14KB JSON endpoint).

**POIs Page** — Interactive Preact map with side panel, category filters, color-coded markers.

**Year Stats** — Sparkline charts, per-month route maps, tag breakdowns, records section, photo of the year.

### 7. Command System + Pipeline Runner (Phase 9)

**Problem:** 7 standalone Crystal scripts, each loading ~90MB of polygon data independently.

**What Claude Code did:**
- Restructured into `data/src/commands/` library with `pipeline/` and `tools/` subdirectories
- Created thin entry-point wrappers in `commands/`
- Built unified `run_all.cr` that shares a single AreaMatcher instance
- Added 28 tests

### 8. Test Infrastructure (from 0 to 855)

**Before:** Zero tests of any kind.

**After:**
- 623 Crystal spec tests (models, views, services, commands, registry)
- 232 Playwright E2E tests across 16 spec files
- MockRenderContext, MockPost, MockHtmlBuffer for unit testing
- E2E tests cover: page loads, link validation, tag filtering, AVIF format selection, responsive images, social meta tags

### 9. HTML Validation Pipeline (Phase 13)

Built into the render process:
- Missing/empty `<title>` detection
- Duplicate ID detection
- Unprocessed `{{placeholder}}` detection
- Missing `alt` attribute warnings
- Invalid `href` warnings

Catches issues at build time, not in production.

### 10. Polish Spellcheck Integration

LanguageTool integration for checking blog post content:
- Strips markdown while preserving character offsets for accurate line:column error reporting
- Configurable rule disabling
- Graceful fallback when LanguageTool is unavailable

---

## What Made Claude Code Effective

### Cross-file refactoring at scale
Renaming a method used in 30 files, updating URL patterns across Crystal + HTML + JS + CSS, migrating callers from deprecated APIs — Claude tracks all references and applies changes consistently.

### Architecture exploration before coding
Before writing code, Claude explored the codebase to understand existing patterns, dependencies, and constraints. This prevented false starts and wasted effort.

### Pattern application across contexts
Once a pattern was established (e.g., `<picture>` for AVIF, `load_html()` for templates, Router for URLs), Claude applied it uniformly across all relevant files without drift or inconsistency.

### Test generation alongside features
Tests were written as part of each feature, not as an afterthought. Claude understood the Crystal spec framework and generated meaningful assertions (not just existence checks).

### Debugging Crystal-specific issues
Crystal has unique gotchas (nested macro `end` consumption, reserved keywords like `out`, no type annotations on constants). Claude encountered these, found workarounds, and documented them for future reference.

### Incremental, verifiable progress
Each phase produced a compilable, testable state. `crystal spec` and `make dev-render-local` verified every change. No "big bang" rewrites that might break everything.

---

## Timeline

| Week | Work |
|------|------|
| Days 1-2 | Architecture rewrite (registry, coordinator, mixin removal) |
| Days 3-4 | Asset bundles, HTML validation, CSS cleanup, Bootstrap 5, Preact |
| Days 5-6 | Homepage, tag filtering, more page, area show redesign |
| Days 7-8 | Towns index, JSON optimization, profiler, command restructure |
| Days 9-10 | Entity unification, slug disambiguation, social meta, portfolio |
| Days 11-12 | GPS geotagging, year stats redesign, POIs page, BuildContext split |
| Days 13-14 | Gallery optimization, AVIF delivery (picture + background-image), final fixes |

All of this on a solo project, with Claude Code as the only collaborator.
