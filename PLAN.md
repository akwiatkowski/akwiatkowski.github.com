# Renderer & Views Refactoring Plan

## Project Context

- Crystal static site generator
- ~100 blog posts with routes, photos, EXIF data
- Multiple entity types: towns, tags, voivodeships, lands, meso/macro regions
- Various view types: lists, galleries, maps, feeds
- Incremental rendering with mod_watcher for fast dev cycle
- Full rendering for production deployment

**Related docs:**
- `PLAN_DONE.md` - Completed phases (1, 1.5, 2, 3)
- `PLAN_FUTURE.md` - Future ideas (Phase 5+)

---

## Current Phase: Final Migration Steps

### Remaining Work

1. [ ] Validate `render_with_registry` output matches `render` output
2. [ ] Replace `make_it_so` to use `render_with_registry`
3. [ ] Delete empty mixin files (if any remain)
4. [ ] Auto-generate VIEWS.md from registry

### Still to Review

- [ ] Pages: `pages/todo_notes.md` - check if still used
- [ ] Data files: `todo_routes.yml`, `transport_pois.yml` - can be deleted?

---

## Next Phase: Logging Improvements (Phase 4)

### Problems

1. **Too much noise** - Too many lines on screen, hard to see what's important
2. **Redundant logs** - Example:
   ```
   INFO - render_coordinator: [20/41] [view] Stats: towns timeline - START
   INFO - view_registry: Rendering towns timeline page
   INFO - render_coordinator: [20/41] [view] Stats: towns timeline - DONE (2.59ms)
   ```
   The middle line is redundant when START is already printed.

3. **Diff output not useful** - Shows same difference for every land, town, etc. (duplicated info)

4. **Date in logs unnecessary** - `hh:mm:ss,ms` is enough (no date, no timezone)

### Goals

1. [ ] Show only INFO for time-consuming parts or important milestones (like "all posts rendered")
2. [ ] Remove redundant log lines within view execution
3. [ ] Deduplicate diff output - show summary instead of repeated identical diffs
4. [ ] Add suggestions to warnings/error messages where possible
5. [ ] Consider rendering summary of important info after rendering finishes
6. [ ] Simplify timestamp format to `hh:mm:ss,ms`

### Ideas to Explore

- [ ] Calculate view execution counts and timing - identify slow views
- [ ] Track which views shouldn't run in watch mode (incremental render)
- [ ] Custom logger class for better control over output format
- [ ] Post-render summary showing warnings, timing stats, changes

---

## Success Criteria

### Current Phase
- [ ] `render_with_registry` produces identical output to old `render`
- [ ] Old render path removed, only registry-based rendering
- [ ] No dead code remaining

### Next Phase (Logging)
- [ ] Logs are readable at a glance
- [ ] Important information stands out
- [ ] No redundant or duplicated output
- [ ] Timing info helps identify optimization targets
