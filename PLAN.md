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

## Backlog

### Phase 8: External Towns
- Handle towns outside Poland (foreign countries)
- Create `data/config/external_towns.yml`

### Phase 9: Command Registry
- Unified system for periodic/scheduled tasks
- Task types: Manual, Periodic, FileChanged, PostRender
- Task tracking in `cache/command_runs.yml`

---

## Test Status

**220 tests passing** (199 original + 8 AssetBundleLoader + 13 HtmlValidators)

---

*Last updated: 2026-02-04*
