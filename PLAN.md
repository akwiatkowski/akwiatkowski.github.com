# Current Work

## Status: Phase 14 Complete

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Phases 1-3, 11-14)

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

### Pattern Used
JSON config blocks for template variable injection:

```html
<script id="page-config" type="application/json">
{
  "slug": "{{ slug }}",
  "name": "{{ name }}"
}
</script>
<div id="root"></div>
<script src="/js/self/area_show.js"></script>
```

---

## CSS/JS Analysis (2026-02-04)

### Current Bundle Sizes

| Bundle | Size | Notes |
|--------|------|-------|
| **Core CSS** | ~210K | bootstrap.min.css (190K) + font-awesome.min.css (31K) + clean-blog.css + new.css |
| **Core JS** | ~234K | jquery.min.js (88K) + bootstrap.bundle.min.js (80K) + nav_stats.js |
| **React Runtime** | ~143K | react.production.min.js (6K) + react-dom.production.min.js (137K) |
| **Leaflet** | ~150K | leaflet.js (147K) + leaflet.css (16K) |
| **OpenLayers** | ~738K | ol.js (720K) - only used on map page |

### Unused CSS (Deletable)

The `css/tmp/` directory contains ~80K of unused CSS:
- `gallery_justified.css` (6K) - not referenced
- `gallery_v1.css` (4K) - not referenced
- `gallery_v2.css` (4K) - not referenced
- `gallery_v3.css` (2K) - not referenced
- `map_slider.css` (1K) - not referenced
- `masonry.css` (4K) - not referenced
- `photo_gallery.css` (6K) - not referenced
- `trip_post.css` (3K) - not referenced
- `zoom_gallery.css` (3K) - not referenced

### Optimization Opportunities

| Change | Savings | Effort | Breaking |
|--------|---------|--------|----------|
| Delete `css/tmp/` | ~80K | Low | No |
| Bootstrap 5 (remove jQuery) | ~88K | Medium | Maybe |
| Preact instead of React | ~140K | Medium | No |
| Drop OpenLayers (Leaflet only) | ~738K | High | Yes (map page) |

---

## Backlog

### Phase 15: CSS Cleanup
- Delete unused `css/tmp/` directory (~80K)
- Audit `clean-blog.css` for dead rules
- Consider merging `new.css` into `clean-blog.css`

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
- 13 `AssetAware` unit tests - bundle resolution, HTML generation
- 8 validator tests - CSS/JS detection, forbidden assets
- `MockRenderContext` now supports `asset_bundle_loader`

---

## Test Status

**241 tests passing** (199 original + 21 AssetBundleLoader/Validators + 21 AssetAware)

---

*Last updated: 2026-02-04*
