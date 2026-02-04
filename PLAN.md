# Asset Management & HTML Processing

## Status: MOSTLY COMPLETE (Phases 11-13)

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
   - `GalleryView::AbstractView` - `["gallery"]`

### Phase 12: External JavaScript (Partial) ✅

1. **Directory Structure** - Created `data/assets/js/src/`

2. **Extracted nav_stats.js**
   - From inline script in `navigation/js_overload.html`
   - To `data/assets/js/self/nav_stats.js`
   - Now loaded via `nav-js` bundle (part of `core`)

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

## Remaining Work

### Still TODO

1. **Extract more inline JS** (optional, for performance)
   - `area/show.html` → `js/src/area_show.jsx`
   - `ideas/ideas.html` → `js/src/ideas.jsx`
   - `post_collection/dynamic.html` → `js/self/post_collection.js`
   - `gallery/gallery_dynamic.html` → `js/self/gallery_dynamic.js`

2. **JSX Transpilation** (if extracting React code)
   - Set up `esbuild` or `swc` for JSX → JS
   - Remove Babel runtime dependency

3. **Cleanup**
   - Delete old `head_open.html` (when confident)
   - Update `CLAUDE.md` with new patterns
   - Move completed phases to `PLAN_DONE.md`

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
| `spec/services/html_validators_spec.cr` | Validator tests |
| `spec/services/asset_bundle_loader_spec.cr` | Bundle loader tests |

## Files Modified

| File | Changes |
|------|---------|
| `data/src/blog.cr` | Added requires for new services |
| `data/src/views/base_view.cr` | Include AssetAware, new head_open_html |
| `data/src/views/area_show_view.cr` | Added additional_bundles |
| `data/src/views/static_view/js_ideas_view.cr` | Added additional_bundles |
| `data/src/views/gallery_view/abstract_view.cr` | Added additional_bundles |
| `data/src/views/static_view/map_view.cr` | Added additional_bundles |
| `data/src/render_context.cr` | Added asset_bundle_loader |
| `data/src/validator.cr` | Added validate_html_output |
| `data/layout/include/navigation/js_overload.html` | Replaced with comment |

---

## Success Criteria

- [x] Asset bundle system implemented
- [x] Views declare their bundle requirements
- [x] External JS files load with cache busting
- [x] HTML validation catches errors
- [x] No `{{...}}` placeholders in output (detected)
- [x] All existing tests pass
- [ ] Index page loads only core bundle (~150KB vs ~500KB) - needs runtime test
- [ ] No Babel runtime in browser - still has inline JSX in templates

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

*Last updated: 2026-02-04 - Phases 11-13 mostly complete*
