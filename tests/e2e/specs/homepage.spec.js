/**
 * Homepage tests - verify all links work
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('Homepage', () => {

  test.describe('All visible links work', () => {

    test('every link on homepage points to existing page', async ({ page, pageWithErrorTracking, request }) => {
      // Go to homepage
      await page.goto('/');

      // Wait for JS to load content
      await page.waitForLoadState('networkidle');

      // Get all visible links (excluding external links)
      const links = await page.locator('a[href^="/"]').all();

      const errors = [];
      const checkedUrls = new Set();

      for (const link of links) {
        // Only check visible links
        const isVisible = await link.isVisible();
        if (!isVisible) continue;

        const href = await link.getAttribute('href');
        if (!href) continue;

        // Skip already checked URLs
        if (checkedUrls.has(href)) continue;
        checkedUrls.add(href);

        // Skip anchor links and javascript:
        if (href.startsWith('#') || href.startsWith('javascript:')) continue;

        // Check if page exists
        const response = await request.get(href);
        if (response.status() !== 200) {
          const linkText = await link.textContent();
          errors.push({
            url: href,
            status: response.status(),
            linkText: linkText?.trim() || '(no text)'
          });
        }
      }

      if (errors.length > 0) {
        console.error('Broken links on homepage:', errors);
      }
      expect(errors, `${errors.length} links returned non-200 status`).toHaveLength(0);
    });

    test('navigation links work', async ({ page, request }) => {
      await page.goto('/');

      // Get nav links specifically
      const navLinks = await page.locator('.nav-links a').all();

      const errors = [];

      for (const link of navLinks) {
        const href = await link.getAttribute('href');
        const text = await link.textContent();

        if (!href) continue;

        const response = await request.get(href);
        if (response.status() !== 200) {
          errors.push({
            url: href,
            status: response.status(),
            linkText: text?.trim()
          });
        }
      }

      if (errors.length > 0) {
        console.error('Broken nav links:', errors);
      }
      expect(errors, `${errors.length} nav links returned non-200 status`).toHaveLength(0);
    });

  });

  test.describe('Homepage loads correctly', () => {

    test('homepage returns 200', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(200);
    });

    test('homepage has no JS errors', async ({ pageWithErrorTracking }) => {
      await pageWithErrorTracking.goto('/');
      await pageWithErrorTracking.waitForLoadState('networkidle');
      await expectNoJsErrors(pageWithErrorTracking);
    });

    test('homepage JSON loads', async ({ request }) => {
      const response = await request.get('/jsons/homepage.json');
      expect(response.status()).toBe(200);

      const json = await response.json();
      expect(json.posts).toBeDefined();
      expect(json.tags).toBeDefined();
      expect(Array.isArray(json.posts)).toBe(true);
      expect(Array.isArray(json.tags)).toBe(true);
    });

    test('stats are not zero', async ({ page }) => {
      await page.goto('/');

      // Get stat values from the page
      const bikeDistance = await page.locator('.stat-value').first().textContent();
      const hikeDistance = await page.locator('.stat-value').nth(1).textContent();
      const timeSpent = await page.locator('.stat-value').nth(2).textContent();

      // Parse as numbers
      const bikeKm = parseInt(bikeDistance || '0', 10);
      const hikeKm = parseInt(hikeDistance || '0', 10);
      const hours = parseInt(timeSpent || '0', 10);

      // At least one of bike/hike should be non-zero (depends on data)
      // Time spent should definitely be non-zero if there are any ready posts
      expect(bikeKm + hikeKm, 'Total distance (bike + hike) should be greater than 0').toBeGreaterThan(0);
      expect(hours, 'Time spent should be greater than 0').toBeGreaterThan(0);

      // Log actual values for debugging
      console.log(`Stats: bike=${bikeKm}km, hike=${hikeKm}km, time=${hours}h`);
    });

  });

  test.describe('Dynamic content loads', () => {

    test('hero image loads after JS execution', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      // Wait for hero to load (loading class should be removed)
      const heroImage = page.locator('.hero-image');
      await expect(heroImage).not.toHaveClass(/hero-loading/, { timeout: 5000 });

      // Check image is visible
      const img = heroImage.locator('img');
      await expect(img).toBeVisible();

      // Check image has src
      const src = await img.getAttribute('src');
      expect(src).toBeTruthy();
      expect(src).not.toBe('');
    });

    test('posts grid loads after JS execution', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      // Wait for posts to load
      const postsGrid = page.locator('.posts-grid');
      await expect(postsGrid).toBeVisible();

      // Should have at least one post card
      const postCards = postsGrid.locator('.post-card');
      await expect(postCards.first()).toBeVisible({ timeout: 5000 });
    });

    test('category chips load after JS execution', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      // Wait for chips to load
      const categories = page.locator('.categories');
      await expect(categories).toBeVisible();

      // Should have at least one chip
      const chips = categories.locator('.category-chip');
      await expect(chips.first()).toBeVisible({ timeout: 5000 });
    });

    test('category chips include at least one meso region link', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      await page.waitForSelector('.category-chip', { timeout: 10000 });

      const chipHrefs = await page.$$eval('.category-chip', els =>
        els.map(el => el.getAttribute('href'))
      );
      const regionChips = chipHrefs.filter(href => href && href.includes('/wpisy-dla/regionu/'));
      console.log(`Region chips: ${regionChips.length} (${regionChips.join(', ')})`);
      expect(regionChips.length, 'Should have at least one meso region chip').toBeGreaterThan(0);
    });

  });

});
