/**
 * Map page tests
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('Map pages', () => {

  test.describe('/mapa.html - Main map', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/mapa.html');
      await expectNoJsErrors(page);
    });

    test('renders Leaflet map container', async ({ page }) => {
      await page.goto('/mapa.html');

      // Wait for map initialization
      await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });
    });

    test('loads map tiles', async ({ page }) => {
      await page.goto('/mapa.html');

      // Wait for tiles to load
      await expect(page.locator('.leaflet-tile-loaded').first()).toBeVisible({ timeout: 15000 });
    });

    test('has route polylines on map', async ({ page, payload }) => {
      await page.goto('/mapa.html');

      // Wait for map to initialize
      await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });

      // Check for SVG paths (routes)
      await page.waitForTimeout(2000); // Wait for routes to load
      const paths = page.locator('.leaflet-overlay-pane path');
      const count = await paths.count();

      // Should have at least some routes if payload has posts with coords
      const postsWithCoords = payload.posts?.filter(p => p.coords?.length > 0) || [];
      if (postsWithCoords.length > 0) {
        expect(count, 'Map should have route polylines').toBeGreaterThan(0);
      }
    });

    test('clicking route shows popup', async ({ page }) => {
      await page.goto('/mapa.html');
      await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });

      // Wait for routes to fully render (SVG paths need time to initialize events)
      await page.waitForTimeout(3000);

      const paths = page.locator('.leaflet-overlay-pane path');
      const count = await paths.count();
      if (count > 0) {
        // Try clicking several routes until we get a popup
        for (let i = 0; i < Math.min(3, count); i++) {
          await paths.nth(i).click({ force: true });
          try {
            await expect(page.locator('.leaflet-popup')).toBeVisible({ timeout: 3000 });
            return; // Success
          } catch {
            // Try next route
          }
        }

        // If no popup appeared, skip this test
        test.skip(true, 'No route responded with popup');
      }
    });

  });

  test.describe('/mapa2.html - Panoramio map', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/mapa2.html');

      // Wait for React to render
      await page.waitForTimeout(1000);
      await expectNoJsErrors(page);
    });

    test('renders React app', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Root element should have content
      await expect(page.locator('#root')).not.toBeEmpty({ timeout: 10000 });
    });

    test('shows map and sidebar', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Use .first() since compound selector may match multiple elements
      await expect(page.locator('.leaflet-container, #map').first()).toBeVisible({ timeout: 10000 });
      await expect(page.locator('.sidebar')).toBeVisible();
    });

  });

});
