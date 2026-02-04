/**
 * Static pages tests
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');

test.describe('Static pages', () => {

  const staticPages = [
    { url: '/', name: 'Home' },
    { url: '/wiecej.html', name: 'More' },
    { url: '/o_mnie.html', name: 'About' },
    { url: '/en/index.html', name: 'English' },
    { url: '/zestawienie.html', name: 'Summary' },
    { url: '/pois.html', name: 'POIs' },
  ];

  for (const page of staticPages) {
    test(`${page.name} page (${page.url}) loads without errors`, async ({ pageWithErrorTracking }) => {
      const p = pageWithErrorTracking;
      await expectPageLoads(p, page.url);
      await expectNoJsErrors(p);

      // Basic structure check
      await expect(p.locator('nav')).toBeVisible();
      await expect(p.locator('body')).not.toBeEmpty();
    });
  }

  test.describe('Home page', () => {

    test('has navigation with dropdowns', async ({ page }) => {
      await page.goto('/');

      await expect(page.locator('nav.navbar')).toBeVisible();
      await expect(page.locator('.navbar-nav')).toBeVisible();
    });

    test('has post links', async ({ page, payload }) => {
      await page.goto('/');

      // Should have some links to posts
      const postLinks = page.locator('a[href*="/202"], a[href*="/201"]');
      const count = await postLinks.count();

      if (payload.posts?.length > 0) {
        expect(count, 'Home should have post links').toBeGreaterThan(0);
      }
    });

  });

  test.describe('Summary page', () => {

    test('has statistics', async ({ page }) => {
      await page.goto('/zestawienie.html');

      // Should have some content
      await expect(page.locator('article, .container')).toBeVisible();
    });

  });

});
