# Renderer & Views Refactoring Plan

## Status: VIEW DECOUPLING COMPLETE

All views now use `context: RenderContext` instead of `@blog`.

**Related docs:**
- `VIEWS.md` - Registry documentation
- `CLAUDE.md` - Project structure reference
- `PLAN_FUTURE.md` - Future ideas

---

## Completed Work

### View Decoupling (Steps 1-5)
- [x] RenderContext methods added (55+ views migrated)
- [x] `@blog` made nilable in BaseView with fallback context creation
- [x] PhotoEntity accepts `photo_tags` instead of `blog`
- [x] All photo_map views migrated (Map::Base takes `posts` parameter)
- [x] `IdeaEntity#routes` takes `data_path` instead of `blog`
- [x] DebugView namespace created (moved from DynamicView)

### Output History Comparator (Step 6)
- [x] `OutputHistory` service in `data/src/services/output_history.cr`
- [x] Tracks HTML/SVG changes across render sessions
- [x] Dark pastel theme with diff syntax highlighting
- [x] Console summary at end of render
- [x] Storage: `env/dev/history/<target>/`

---

## Remaining `ctx.blog` Usages

These are infrastructure calls, not view dependencies:

| File | Usage | Reason |
|------|-------|--------|
| `entity_views.cr:108` | `ctx.blog.post_collection.ensure_posts_have_assigned_lands` | Mutates state |
| `setup_tasks.cr:34` | `ctx.blog.renderer.dev_render` | Calls renderer |
| `setup_tasks.cr:52` | `ctx.blog.renderer.copy_assets_and_photos` | Calls renderer |

**External dependency:**
- `SiteMapGenerator` (Tremolite library) still uses `blog`

---

## Future Work

See `PLAN_FUTURE.md` for:
- Image size optimization
- Town/voivodeship show pages
- Testing improvements

---

## Test Status

**146 examples, 0 failures, 0 errors, 2 pending**
