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

**Remaining late-bound properties:**
Most remaining `.not_nil!` sites use safe fallbacks or guard clauses — see `PLAN_FUTURE.md` for details.

---

## Test Status

**602 Crystal tests passing, 232 E2E tests passing (16 spec files)**

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

### Phase 37: AVIF for background-image Contexts (2026-02-15)

- Shared AVIF detection (`avif_detect.js`) — `window.__avif` boolean + `window.__avifReady` Promise, loaded via core bundle
- Lightbox refactored to use shared detection (removed private `supportsAvif()`), ambilight uses `grid_src_avif`
- Area show: hero bg uses `bestPhotoUrlAvif`, related cards use `best_photo_url_avif`
- Towns index: card bg uses `town.photo_url_avif`
- Portfolio: hero bg uses `photo.src_avif`, grid ambilight CSS var uses `gridSrcAvif`
- Map: popup bg uses `card_image_url_avif`
- Post box template: CSS `image-set()` with AVIF + JPEG fallback
- Post model: `card_image_url_avif` getter added

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

*Last updated: 2026-02-15*
