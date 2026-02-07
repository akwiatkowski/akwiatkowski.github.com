/**
 * Static pages tests
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');

test.describe('Static pages', () => {

  const staticPages = [
    { url: '/', name: 'Home' },
    { url: '/wiecej.html', name: 'More' },
    { url: '/o-mnie.html', name: 'About' },
    { url: '/en/index.html', name: 'English' },
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

    test('has navigation', async ({ page }) => {
      await page.goto('/');

      // New homepage uses nav.nav or nav.site-nav, old pages use nav.navbar
      const hasNewNav = await page.locator('nav.nav, nav.site-nav').count() > 0;
      const hasOldNav = await page.locator('nav.navbar').count() > 0;
      expect(hasNewNav || hasOldNav, 'Should have navigation').toBeTruthy();
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

});
