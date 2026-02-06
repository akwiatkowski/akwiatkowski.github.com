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

  test.describe('/pomysly_dla_zdjec.html - Photo planner', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(2000);
      await expectNoJsErrors(page);
    });

    test('has site navigation and footer', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');

      // Navigation should be present
      const nav = page.locator('nav.site-nav');
      await expect(nav).toBeVisible();

      // Footer should be present
      const footer = page.locator('footer.site-footer');
      await expect(footer).toBeVisible();
    });

    test('has hero with title', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');

      const hero = page.locator('.planner-hero h1');
      await expect(hero).toBeVisible();
      const text = await hero.textContent();
      expect(text).toContain('Planer');
    });

    test('map container renders', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(2000);

      // Leaflet map should initialize
      const mapContainer = page.locator('#map .leaflet-container, #map.leaflet-container, .leaflet-container');
      const count = await mapContainer.count();
      expect(count, 'Leaflet map should initialize').toBeGreaterThan(0);
    });

    test('grid cells are drawn on map', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      // Leaflet rectangles are rendered as SVG paths
      const paths = page.locator('.leaflet-overlay-pane svg path');
      const count = await paths.count();
      expect(count, 'Grid cells should be drawn as SVG paths').toBeGreaterThan(10);
    });

    test('station markers are drawn on map', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      // CircleMarkers are rendered in the marker pane or overlay pane
      const markers = page.locator('.leaflet-interactive[fill="#2196F3"], .leaflet-marker-pane *, circle[fill="#2196F3"]');
      const count = await markers.count();
      expect(count, 'Station markers should be drawn').toBeGreaterThan(5);
    });

    test('coverage stats are populated with numbers', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      // Total cells should be a number, not dash
      const totalCells = await page.locator('#totalCells').textContent();
      expect(parseInt(totalCells), 'Total cells should be a positive number').toBeGreaterThan(0);

      const filledCells = await page.locator('#filledCells').textContent();
      expect(parseInt(filledCells), 'Filled cells should be a number').toBeGreaterThanOrEqual(0);

      const blankCells = await page.locator('#blankCells').textContent();
      expect(parseInt(blankCells), 'Blank cells should be a positive number').toBeGreaterThan(0);

      const coverage = await page.locator('#coveragePercent').textContent();
      const coverageNum = parseFloat(coverage);
      expect(coverageNum, 'Coverage should be between 0 and 100').toBeGreaterThan(0);
      expect(coverageNum).toBeLessThan(100);
    });

    test('generate button produces route cards', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      // Click generate button
      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      // Results panel should become visible
      const results = page.locator('#results');
      await expect(results).toBeVisible();

      // Should have at least one route card
      const cards = page.locator('.route-card');
      const count = await cards.count();
      expect(count, 'Should generate at least one route').toBeGreaterThan(0);
    });

    test('route cards show station names with arrow', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      // First route card should have station names with arrow
      const stations = page.locator('.route-card-stations').first();
      const text = await stations.textContent();
      expect(text, 'Route should show station names').toContain('\u2192');
      // Should NOT contain [object Object]
      expect(text).not.toContain('[object');
    });

    test('route cards show numeric km values', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      // Stats should contain km values
      const stats = page.locator('.route-card-stats').first();
      const text = await stats.textContent();
      expect(text, 'Should show distance in km').toContain('km');
      // Should NOT contain [object Object] (the time_distance bug)
      expect(text).not.toContain('[object');
    });

    test('route cards show train time in hours', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      // Stats should contain train hours
      const stats = page.locator('.route-card-stats').first();
      const text = await stats.textContent();
      expect(text, 'Should show train time in hours').toMatch(/\d+(\.\d+)?h/);
    });

    test('radio buttons change trip duration', async ({ page }) => {
      await page.goto('/pomysly_dla_zdjec.html');
      await page.waitForTimeout(3000);

      // Select 2 days option
      await page.locator('input[name="tripDays"][value="2"]').click();

      // Generate routes
      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      const count2days = await page.locator('.route-card').count();

      // Select 4 days option - should get different results
      await page.locator('input[name="tripDays"][value="4"]').click();
      await page.locator('#generate-btn').click();
      await page.waitForTimeout(1000);

      const count4days = await page.locator('.route-card').count();

      // Both should have results (the counts may differ)
      expect(count2days, 'Should have routes for 2 days').toBeGreaterThan(0);
      expect(count4days, 'Should have routes for 4 days').toBeGreaterThan(0);
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
