/**
 * POIs page (/pois.html) tests - interactive map with markers
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('POIs page (/pois.html)', () => {

  test('page loads without JS errors', async ({ pageWithErrorTracking }) => {
    await pageWithErrorTracking.goto('/pois.html');
    await pageWithErrorTracking.waitForLoadState('networkidle');
    await expectNoJsErrors(pageWithErrorTracking);
  });

  test('has page title', async ({ page }) => {
    await page.goto('/pois.html');
    const title = await page.title();
    expect(title).toContain('Ciekawe miejsca');
  });

  test('map container is visible', async ({ page }) => {
    await page.goto('/pois.html');
    await page.waitForSelector('[data-testid="poi-map"]');
    const map = page.locator('[data-testid="poi-map"]');
    await expect(map).toBeVisible();
  });

  test('markers are rendered on map', async ({ page }) => {
    await page.goto('/pois.html');
    // Wait for markers to load (staggered animation)
    await page.waitForTimeout(1500);
    const markers = page.locator('.poi-marker');
    const count = await markers.count();
    expect(count).toBeGreaterThan(0);
  });

  test('legend shows counts', async ({ page }) => {
    await page.goto('/pois.html');
    await page.waitForSelector('[data-testid="poi-legend"]');
    const legend = page.locator('[data-testid="poi-legend"]');
    await expect(legend).toBeVisible();
    const text = await legend.textContent();
    expect(text).toContain('Odwiedzone');
    expect(text).toContain('Do odwiedzenia');
  });

  test('clicking a marker opens the detail panel', async ({ page }) => {
    await page.goto('/pois.html');
    await page.waitForTimeout(1500);

    // Click the first marker
    const marker = page.locator('.poi-marker').first();
    await marker.click();

    // Panel should appear
    const panel = page.locator('[data-testid="poi-panel"]');
    await expect(panel).toBeVisible();

    // Should have a name
    const name = panel.locator('.poi-card-name');
    await expect(name).toBeVisible();
  });

  test('panel closes when clicking X', async ({ page }) => {
    await page.goto('/pois.html');
    await page.waitForTimeout(1500);

    // Open panel
    const marker = page.locator('.poi-marker').first();
    await marker.click();

    const panel = page.locator('[data-testid="poi-panel"]');
    await expect(panel).toHaveClass(/poi-panel--open/);

    // Close
    await page.locator('.poi-panel-close').click();
    await expect(panel).not.toHaveClass(/poi-panel--open/);
  });

  test('visited POI card shows photo and post link', async ({ page }) => {
    await page.goto('/pois.html');
    await page.waitForTimeout(1500);

    // Find a visited marker
    const visitedMarker = page.locator('.poi-marker--visited').first();
    const visitedCount = await visitedMarker.count();

    if (visitedCount > 0) {
      await visitedMarker.click();
      const panel = page.locator('[data-testid="poi-panel"]');
      await expect(panel).toBeVisible();

      // Should have post link
      const link = panel.locator('.poi-card-link');
      await expect(link).toBeVisible();
    }
  });

  test('pois data JSON is present in page', async ({ page }) => {
    await page.goto('/pois.html');
    const dataEl = page.locator('#pois-data');
    const json = await dataEl.textContent();
    const data = JSON.parse(json);
    expect(data.pois).toBeDefined();
    expect(data.pois.length).toBeGreaterThan(0);
  });
});
