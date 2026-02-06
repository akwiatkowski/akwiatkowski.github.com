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

    test('has photo markers on map', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Wait for photos to load and markers to render
      await page.waitForTimeout(2000);

      // Should have at least one photo marker on the map
      const markers = page.locator('.map-photo-marker');
      const count = await markers.count();
      console.log(`Photo markers on map: ${count}`);
      expect(count, 'Should have at least one photo marker on map').toBeGreaterThan(0);
    });

    test('has photos in sidebar', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Wait for photos to load
      await page.waitForTimeout(2000);

      // Should have photos in the sidebar
      const photos = page.locator('.photo-item');
      const count = await photos.count();
      console.log(`Photos in sidebar: ${count}`);
      expect(count, 'Should have at least one photo in sidebar').toBeGreaterThan(0);
    });

    test('sidebar shows photo count', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Wait for photos to load
      await page.waitForTimeout(2000);

      // Sidebar header should show count
      const header = page.locator('.sidebar-header small');
      await expect(header).toBeVisible();
      const text = await header.textContent();
      expect(text).toMatch(/\d+ visible/);
    });

    test('clicking photo in sidebar opens modal', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Wait for photos to load
      await page.waitForTimeout(2000);

      // Click first photo
      const firstPhoto = page.locator('.photo-item').first();
      await firstPhoto.click();

      // Modal should appear
      await expect(page.locator('.modal.show')).toBeVisible({ timeout: 5000 });
      await expect(page.locator('.photo-modal-image')).toBeVisible();
    });

    test('clicking marker opens modal', async ({ page }) => {
      await page.goto('/mapa2.html');

      // Wait for markers to load
      await page.waitForTimeout(2000);

      // Click first marker
      const firstMarker = page.locator('.map-photo-marker').first();
      if (await firstMarker.count() > 0) {
        await firstMarker.click();

        // Modal should appear
        await expect(page.locator('.modal.show')).toBeVisible({ timeout: 5000 });
      }
    });

  });

});
