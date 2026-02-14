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

**602 Crystal tests passing, 228 E2E tests passing (16 spec files)**

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
- `specs/picture-elements.spec.js` - AVIF `<picture>` elements, responsive image selection, viewport rendering

**Run E2E tests:**
```bash
make test-e2e          # Run all tests
make test-e2e-smoke    # Run smoke tests only
make test-e2e-headed   # Run with visible browser
```

---

## Recently Completed

### Phase 36: AVIF `<picture>` Elements (2026-02-14)

- Native `<picture>` elements for AVIF format delivery across all image contexts
- AVIF URL fields added to 7 JSON serializers (homepage, portfolio, area show, photos map, map, towns index, POIs)
- Template data: grid/AVIF URLs in post_function_parser.cr, AVIF placeholders for pager/related posts
- HTML templates wrapped in `<picture>`: article photos, pager, related posts, gallery
- JSX components updated: gallery_dynamic, portfolio (LazyImage), POIs
- Responsive srcset preserved: 560w grid + 1000w article with `sizes="(max-width: 576px) 100vw, 100vw"`
- CSS fixes: `width: 100%` on article photos, `box-sizing: border-box` on html, block display for picture/a wrappers
- Strava iframe overflow fixed with max-width wrapper
- E2E tests: 14 tests covering AVIF source selection, responsive image resolution, viewport rendering, no horizontal scroll

**Deferred** (discuss later):
- Lightbox progressive loading (dynamically swaps `img.src`)
- CSS `background-image` contexts (hero photos, card bgs, ambilight, town cards, related area cards)
- Homepage vanilla JS (innerHTML pattern)
- Area show compiled JS (mix of `<img>` and `backgroundImage`)

*Last updated: 2026-02-14*
