/**
 * JavaScript-heavy pages tests
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('JS-heavy pages', () => {

  test.describe('/pomysly_tras.html - Trip ideas page', () => {

    test('loads without JS errors', async ({ pageWithErrorTracking }) => {
      const page = pageWithErrorTracking;
      await page.goto('/pomysly_tras.html');
      await page.waitForTimeout(1000);
      await expectNoJsErrors(page);
    });

    test('renders content', async ({ page }) => {
      await page.goto('/pomysly_tras.html');
      await expect(page.locator('body')).not.toBeEmpty();
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
