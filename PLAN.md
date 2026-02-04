# Current Work

## Status: Phase 15 Complete

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 11-14)

---

## Phase 15: CSS Cleanup ✅ COMPLETE

### What Was Done
1. Deleted unused `css/tmp/` directory (76K, 11 files)
2. Merged `clean-blog.css` into `new.css` (single base CSS file)
3. Removed unused classes: `site-heading`, `page-heading`, `post-todo`
4. Removed duplicate rules and obsolete vendor prefixes
5. Added symbol-based `page_css` support for page-specific CSS

### CSS Structure (After Cleanup)

| File | Size | Loaded By |
|------|------|-----------|
| `new.css` | 17K | All pages (via `core` bundle) |
| `new_gallery.css` | 7K | Gallery pages (via `page_css: ["gallery"]`) |
| `coord_photo.css` | 2K | Gallery pages (via `page_css: ["gallery"]`) |
| `ideas.css` | 6K | Ideas page (via `page_css: ["ideas"]`) |
| `ol-blog.css` | 1K | Map page (via `openlayers` bundle) |

### New Pattern: Symbol-based page_css

Views declare page-specific CSS via symbols:
```crystal
def page_css : Array(String)
  ["gallery"]  # Resolves to new_gallery.css + coord_photo.css
end
```

Symbols defined in `asset_bundles.yml`:
```yaml
page-assets:
  gallery:
    css:
      - /css/self/new_gallery.css
      - /css/self/coord_photo.css
  ideas:
    css:
      - /css/self/ideas.css
```

### Savings
- Deleted 76K unused CSS (`css/tmp/`)
- Reduced clean-blog.css by ~0.5K (duplicates, empty rules)
- Total: **~77K saved**

---

## Phase 14: JSX Extraction ✅ COMPLETE

### What Was Done
1. Set up `esbuild` for JSX → JS transpilation at build time
2. Extracted 3 React templates to external JSX files
3. Deleted legacy `head_open.html`
4. Removed ~1850 lines of inline JSX from templates

### Files Extracted

| Source Template | JSX File | Transpiled JS | Size |
|----------------|----------|---------------|------|
| `area/show.html` (1003→518 lines) | `js/src/area_show.jsx` | `js/self/area_show.js` | 9.8kb |
| `ideas/ideas.html` (648→3 lines) | `js/src/ideas.jsx` | `js/self/ideas.js` | 12.8kb |
| `gallery/gallery_dynamic.html` (199→8 lines) | `js/src/gallery_dynamic.jsx` | `js/self/gallery_dynamic.js` | 3.7kb |

### Build Command
```bash
npm run build:js
```

---

## Current Bundle Sizes

| Bundle | Size | Notes |
|--------|------|-------|
| **Core CSS** | ~210K | bootstrap.min.css (190K) + font-awesome.min.css (31K) + new.css (17K) |
| **Core JS** | ~234K | jquery.min.js (88K) + bootstrap.bundle.min.js (80K) + nav_stats.js |
| **React Runtime** | ~143K | react.production.min.js (6K) + react-dom.production.min.js (137K) |
| **Leaflet** | ~150K | leaflet.js (147K) + leaflet.css (16K) |
| **OpenLayers** | ~738K | ol.js (720K) - only used on map page |

---

## Backlog

### Phase 16: Bootstrap 5 Migration
- Upgrade Bootstrap 4 → 5 (removes jQuery dependency)
- Saves ~88K (jQuery removal)
- Update any Bootstrap 4-specific classes

### Phase 17: Preact Migration (Optional)
- Replace React with Preact (~140K savings)
- Use `preact/compat` for drop-in replacement
- Test all React components (area_show, ideas, gallery_dynamic)

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

---

## Asset Rendering Tests ✅

Added tests to ensure assets are properly rendered:
- `MissingAssetsValidator` - catches broken asset loading, warns on Babel
- 15 `AssetAware` unit tests - bundle resolution, HTML generation, page_css
- 8 validator tests - CSS/JS detection, forbidden assets
- `MockRenderContext` now supports `asset_bundle_loader`

---

## Test Status

**242 tests passing**

---

*Last updated: 2026-02-04*
