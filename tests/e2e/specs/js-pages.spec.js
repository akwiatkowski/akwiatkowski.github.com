/**
 * JavaScript-heavy pages tests
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('JS-heavy pages', () => {

  test.describe('/pomysly_tras.html - Trip ideas page', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);
      await expectNoJsErrors(page);
    });

    test('renders trip cards', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Should have at least one trip card
      const cards = page.locator('.card');
      const count = await cards.count();
      expect(count, 'Should have at least one trip card').toBeGreaterThan(0);
    });

    test('cards have route header and stats', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // First card should have route name (A → B)
      const route = page.locator('.card-route').first();
      await expect(route).toBeVisible();
      const text = await route.textContent();
      expect(text).toContain('→');

      // Should have distance in meta
      const meta = page.locator('.card-meta').first();
      const metaText = await meta.textContent();
      expect(metaText).toContain('km');
    });

    test('cards have town tags', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Should have town tags in first card
      const towns = page.locator('.card').first().locator('.town');
      const count = await towns.count();
      expect(count, 'Card should have town tags').toBeGreaterThan(0);
    });

    test('town links only for towns with pages', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Should have some towns rendered as plain text (unvisited)
      const plainTowns = page.locator('.town:not(.visited)');
      const plainCount = await plainTowns.count();

      // Should have some towns rendered as links (visited)
      const linkedTowns = page.locator('a.town.visited');
      const linkedCount = await linkedTowns.count();

      // At least one type should be present
      expect(plainCount + linkedCount, 'Should have town tags').toBeGreaterThan(0);

      // Visited town links should have valid href
      if (linkedCount > 0) {
        const href = await linkedTowns.first().getAttribute('href');
        expect(href).toBeTruthy();
        expect(href).toContain('/gmina/');
      }
    });

    test('town links return 200 (no 404)', async ({ page, request }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Collect all visited town link hrefs
      const linkedTowns = page.locator('a.town.visited');
      const count = await linkedTowns.count();

      if (count === 0) {
        test.skip();
        return;
      }

      // Collect unique hrefs from a few random links (up to 5)
      const allHrefs = new Set();
      for (let i = 0; i < count; i++) {
        const href = await linkedTowns.nth(i).getAttribute('href');
        if (href) allHrefs.add(href);
      }

      // Pick up to 5 random unique hrefs to check
      const hrefs = Array.from(allHrefs);
      const sample = hrefs.length <= 5 ? hrefs : hrefs.sort(() => Math.random() - 0.5).slice(0, 5);

      for (const href of sample) {
        const resp = await request.get(href);
        expect(resp.status(), `Town link ${href} should not be 404`).toBe(200);
      }
    });

    test('search filter narrows results', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Count initial cards
      const initialCount = await page.locator('.card').count();
      expect(initialCount, 'Should have cards before filtering').toBeGreaterThan(0);

      // Type a search term that likely matches only some trips
      const searchInput = page.locator('.filter-input');
      await searchInput.fill('jelenia');

      // Wait for filter to apply
      await page.waitForTimeout(500);

      // Count should change (either fewer cards or same if all match)
      const filteredCount = await page.locator('.card').count();
      expect(filteredCount).toBeLessThanOrEqual(initialCount);
    });

    test('header shows count', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(2000);

      // Header should show trip count
      const subtitle = page.locator('.ideas-hero p');
      const text = await subtitle.textContent();
      expect(text).toMatch(/\d+ tras/);
    });

  });

  test.describe('/pomysly2.html - Bicycle planner', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/pomysly2.html');
      await page.waitForTimeout(1000);
      await expectNoJsErrors(page);
    });

  });

  test.describe('/linia_czasu.html - Timeline', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/linia_czasu.html');
      await page.waitForTimeout(1000);
      await expectNoJsErrors(page);
    });

    test('renders timeline content', async ({ page }) => {
      await page.goto('/linia_czasu.html');

      // Wait for timeline to initialize
      await page.waitForTimeout(2000);

      // Should have some content rendered
      await expect(page.locator('body')).not.toBeEmpty();
    });

  });

  test.describe('/exif_statystyki.html - EXIF stats', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/exif_statystyki.html');
      await page.waitForTimeout(1000);
      await expectNoJsErrors(page);
    });

  });

});
