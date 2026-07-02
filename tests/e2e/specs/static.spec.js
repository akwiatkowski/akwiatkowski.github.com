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
    { url: '/portfolio.html', name: 'Portfolio' },
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

  test.describe('Portfolio page', () => {

    test('has dark background', async ({ page }) => {
      await page.goto('/portfolio.html');
      const bgColor = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      // Should be very dark (rgb(10, 10, 10) or similar)
      expect(bgColor).toMatch(/rgb\(\s*10,\s*10,\s*10\s*\)/);
    });

    test('has hero section', async ({ page }) => {
      await page.goto('/portfolio.html');
      await expect(page.locator('.portfolio-hero')).toBeVisible();
      await expect(page.locator('.portfolio-hero-name')).toHaveText('Aleksander Kwiatkowski');
    });

    test('has grid with photos', async ({ page }) => {
      await page.goto('/portfolio.html');
      const items = page.locator('.portfolio-grid-item');
      const count = await items.count();
      expect(count, 'Should have portfolio photos').toBeGreaterThan(0);
    });

    test('lightbox opens and closes', async ({ page }) => {
      await page.goto('/portfolio.html');
      // Wait for at least one image to load
      await page.locator('.portfolio-grid-item img.visible').first().waitFor({ timeout: 10000 });

      // Click first photo
      await page.locator('.portfolio-grid-item').first().click();
      await expect(page.locator('.photo-lightbox')).toBeVisible();
      await expect(page.locator('.photo-lightbox-counter')).toContainText('1 /');

      // Close with Escape. The keydown listener is registered in a React
      // useEffect that runs after paint, so under parallel CPU load the first
      // keypress can land before the listener attaches. Retry the press until
      // the lightbox actually closes rather than asserting on a single keypress.
      await expect(async () => {
        await page.keyboard.press('Escape');
        await expect(page.locator('.photo-lightbox')).not.toBeVisible({ timeout: 500 });
      }).toPass({ timeout: 5000 });
    });

  });

});
