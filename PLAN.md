# Asset Management & HTML Processing

## Status: COMPLETE (Phases 11-13)

**Goal**: Smart asset loading per view with inheritance, external JS files (no runtime Babel), and HTML validation.

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases (Area Entity refactoring, Renderer refactoring)

---

## Completed Work Summary

### Phase 11: Asset Bundle System ✅

1. **Bundle Configuration** - Created `data/config/asset_bundles.yml`
   - Granular bundles: `bootstrap-css`, `fontawesome`, `leaflet-css`, `leaflet-js`, etc.
   - Composite bundles: `core`, `leaflet`, `openlayers`, `react-runtime`, `gallery`
   - Integrity hash support for SRI

2. **Asset Bundle Loader** - Created `data/src/services/asset_bundle_loader.cr`
   - Loads bundle config from YAML
   - Resolves composites recursively
   - Merges assets with deduplication
   - Tracks integrity hashes

3. **AssetAware Module** - Created `data/src/views/concerns/asset_aware.cr`
   - `asset_bundles` - base bundles (default: `["core"]`)
   - `additional_bundles` - append to parent's bundles
   - `excluded_bundles` - remove from inheritance
   - `page_js` - optional page-specific JS file
   - `resolved_bundles` - compute final bundle list
   - `assets_html` - generate tags with cache busting

4. **Split head_open.html** - Created modular templates
   - `include/head_meta.html` - charset, viewport, msapplication
   - `include/head_icons.html` - favicons, apple-touch-icons
   - `include/head_feeds.html` - RSS, Atom links

5. **Updated BaseView**
   - Included `AssetAware` module
   - New `head_open_html_with_bundles` method
   - Fallback to legacy `head_open_html_legacy` if no bundle loader

6. **Updated RenderContext**
   - Added `asset_bundle_loader` accessor

7. **View Bundle Declarations**
   - `AreaShowView` - `["leaflet", "react-runtime"]`
   - `MapView` - `["openlayers"]`
   - `JsIdeasView` - `["ideas-css", "leaflet", "react-runtime"]`
   - `JsTimelineView` - `["leaflet", "timeline-js"]`
   - `GalleryView::AbstractView` - `["gallery"]`
   - `CollectionDynamicView` - `["post-collection-js"]`

### Phase 12: External JavaScript ✅

1. **Directory Structure** - Created `data/assets/js/src/`

2. **Extracted nav_stats.js** (~30 lines)
   - From inline script in `navigation/js_overload.html`
   - To `data/assets/js/self/nav_stats.js`
   - Loaded via `nav-js` bundle (part of `core`)

3. **Extracted post_collection.js** (~200 lines)
   - From inline script in `post_collection/dynamic.html`
   - To `data/assets/js/self/post_collection.js`
   - Uses JSON config block for template variables
   - Loaded via `post-collection-js` bundle

4. **Extracted timeline.js** (~600 lines)
   - From inline script in `photos/timeline.html`
   - To `data/assets/js/self/timeline.js`
   - Template reduced from 1521 to 663 lines (CSS + HTML only)
   - Loaded via `timeline-js` bundle

### Phase 13: HTML Processing & Validation ✅

1. **HtmlProcessor Service** - Created `data/src/services/html_processor.cr`
   - Removes HTML comments (preserves IE conditionals)
   - Runs validators on output
   - Returns processed HTML with errors/warnings

2. **HTML Validators** - Created `data/src/services/html_validators/`
   - `MissingTitleValidator` - Checks `<title>` exists
   - `EmptyTitleValidator` - Checks `<title>` not empty
   - `DuplicateIdValidator` - Checks no duplicate IDs
   - `UnprocessedPlaceholderValidator` - Checks no `{{...}}` left
   - `MissingAltValidator` - Warns on `<img>` without `alt`
   - `MissingLangValidator` - Warns on `<html>` without `lang`
   - `InvalidHrefValidator` - Warns on `href="#"` or empty

3. **Integration** - Added `validate_html_output` to `validator.cr`

---

## Test Results

**220 tests passing** (199 original + 8 AssetBundleLoader + 13 HtmlValidators)

---

## Remaining Work (Optional)

### React/JSX Extraction (requires transpilation setup)

These templates still have inline React/JSX with Babel runtime:
- `area/show.html` (~500 lines) → would need `js/src/area_show.jsx`
- `ideas/ideas.html` (~650 lines) → would need `js/src/ideas.jsx`
- `gallery/gallery_dynamic.html` (~200 lines) → would need `js/src/gallery_dynamic.jsx`

To extract these:
1. Set up `esbuild` or `swc` for JSX → JS transpilation
2. Remove Babel runtime dependency from head_open.html
3. Extract inline JSX to `js/src/*.jsx` files
4. Add build step to transpile to `js/self/*.js`

### Cleanup
- [ ] Delete old `head_open.html` (when confident)
- [ ] Move completed phases to `PLAN_DONE.md`

---

## Files Created

| File | Purpose |
|------|---------|
| `data/config/asset_bundles.yml` | Bundle definitions |
| `data/src/services/asset_bundle_loader.cr` | Load and resolve bundles |
| `data/src/views/concerns/asset_aware.cr` | Asset mixin with inheritance |
| `data/src/services/html_processor.cr` | Comment removal, validation |
| `data/src/services/html_validators/base.cr` | Validator interface |
| `data/src/services/html_validators/title_validators.cr` | Title checks |
| `data/src/services/html_validators/duplicate_id_validator.cr` | Duplicate ID check |
| `data/src/services/html_validators/placeholder_validator.cr` | Unprocessed `{{}}` check |
| `data/src/services/html_validators/accessibility_validators.cr` | Alt/lang checks |
| `data/src/services/html_validators/link_validators.cr` | Href checks |
| `data/src/services/html_validators/all.cr` | Require all validators |
| `data/layout/include/head_meta.html` | Meta tags only |
| `data/layout/include/head_icons.html` | Favicons only |
| `data/layout/include/head_feeds.html` | RSS/Atom links only |
| `data/assets/js/self/nav_stats.js` | Navigation stats loader |
| `data/assets/js/self/post_collection.js` | Post collection dynamic loader |
| `data/assets/js/self/timeline.js` | Photo timeline viewer |
| `spec/services/html_validators_spec.cr` | Validator tests |
| `spec/services/asset_bundle_loader_spec.cr` | Bundle loader tests |

## Files Modified

| File | Changes |
|------|---------|
| `data/src/blog.cr` | Added requires for new services |
| `data/src/views/base_view.cr` | Include AssetAware, new head_open_html |
| `data/src/views/area_show_view.cr` | Added additional_bundles |
| `data/src/views/static_view/js_ideas_view.cr` | Added additional_bundles |
| `data/src/views/static_view/js_timeline_view.cr` | Added additional_bundles |
| `data/src/views/gallery_view/abstract_view.cr` | Added additional_bundles |
| `data/src/views/static_view/map_view.cr` | Added additional_bundles |
| `data/src/views/post_list_view/collection_dynamic_view.cr` | Added additional_bundles |
| `data/src/render_context.cr` | Added asset_bundle_loader |
| `data/src/validator.cr` | Added validate_html_output |
| `data/layout/include/navigation/js_overload.html` | Replaced inline JS with comment |
| `data/layout/post_collection/dynamic.html` | Replaced inline JS with JSON config |
| `data/layout/photos/timeline.html` | Removed ~860 lines inline JS |

---

## Success Criteria

- [x] Asset bundle system implemented
- [x] Views declare their bundle requirements
- [x] External JS files load with cache busting
- [x] HTML validation catches errors
- [x] No `{{...}}` placeholders in output (detected)
- [x] All existing tests pass
- [x] Vanilla JS extracted to external files
- [ ] No Babel runtime in browser - still has inline JSX in 3 templates (optional)

---

## Backlog (From Previous Plan)

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

---

*Last updated: 2026-02-04 - Phases 11-13 complete, vanilla JS extraction done*
