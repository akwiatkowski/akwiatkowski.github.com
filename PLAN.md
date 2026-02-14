# Current Work

## Status: All major phases complete

**Related docs:**
- `VIEWS.md` - Registry documentation (7 tasks + 42 views = 49 entries)
- `CLAUDE.md` - Project structure reference
- `PLAN_DONE.md` - Completed phases archive
- `PLAN_FUTURE.md` - Future ideas backlog

---

## Backlog

### Future Ideas

**More Page (`/wiecej.html`) — Consider adding:**
- RSS/Atom feeds (`/feed.xml`, `/feed_atom.xml`)

**Remaining late-bound properties (genuinely need posts):**
Could reduce `.not_nil!` noise with `getter!` macros across remaining call sites.

| Class | Properties | Reason |
|-------|-----------|--------|
| **Renderer** | `all_posts`, `posts_for_resize` | Set after posts are initialized |
| **Validator** | `area_data_loader`, `posts` | Set after posts are initialized |
| **PostCollection** | `photo_tags`, `exif_db`, `markdown_wrapper` | Set before initialize_posts |
| **Post** | `exif_db`, `photo_tags` | Set per-post in initialize_posts loop |

---

## Test Status

**589 Crystal tests passing, ~137 E2E tests passing (15 spec files)**

### E2E Tests (Playwright)

Infrastructure in `tests/e2e/`:
- `specs/smoke.spec.js` - All URLs from e2e.json return 200
- `specs/posts.spec.js` - Post article pages
- `specs/map.spec.js` - Map pages (mapa_tras.html, mapa_zdjec.html)
- `specs/gallery.spec.js` - Gallery pages
- `specs/static.spec.js` - Static pages
- `specs/js-pages.spec.js` - JS-heavy pages
- `specs/homepage.spec.js` - Homepage links, JSON, dynamic content
- `specs/tag-filtering.spec.js` - Tag post list filtering
- `specs/navigation.spec.js` - Navigation styling across pages
- `specs/more-page.spec.js` - More page links
- `specs/towns-index.spec.js` - Towns index search, voivodeships, cards
- `specs/area-filtering.spec.js` - Area post list filtering
- `specs/area-show.spec.js` - Area show pages (photos, JSON, no JS errors)
- `specs/social-meta.spec.js` - Social meta tags (og:type, twitter:card, descriptions)
- `specs/pois.spec.js` - POIs page (map, side panel, markers)

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

*Last updated: 2026-02-14*
