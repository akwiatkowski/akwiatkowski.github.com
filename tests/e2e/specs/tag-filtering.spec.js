/**
 * Tag filtering tests - verify tag post list pages filter correctly
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');

test.describe('Tag post list filtering', () => {

  test.describe('Bicycle tag page (/wpisy-dla/tagu/rowerem.html)', () => {

    test('page loads and shows posts', async ({ page }) => {
      await page.goto('/wpisy-dla/tagu/rowerem.html');
      await page.waitForLoadState('networkidle');

      // Wait for posts to load
      const postsGrid = page.locator('.posts-grid');
      await expect(postsGrid).toBeVisible({ timeout: 10000 });

      // Should have at least one post
      const postCards = postsGrid.locator('.post-card');
      const count = await postCards.count();
      console.log(`Bicycle tag page: ${count} posts found`);
      expect(count, 'Should have at least one bicycle post').toBeGreaterThan(0);
    });

    test('only shows posts with bicycle tag', async ({ page, request }) => {
      // First get the JSON data to know which posts should appear
      const jsonResponse = await request.get('/jsons/homepage.json');
      const json = await jsonResponse.json();

      const bicyclePosts = json.posts.filter(p =>
        p.visible && p.ready && p.tags && p.tags.includes('bicycle')
      );
      console.log(`Expected bicycle posts: ${bicyclePosts.length}`);
      console.log('Bicycle post titles:', bicyclePosts.map(p => p.title));

      // Now check the page
      await page.goto('/wpisy-dla/tagu/rowerem.html');
      await page.waitForLoadState('networkidle');

      // Wait for posts to load
      await page.waitForSelector('.post-card', { timeout: 10000 });

      const postCards = page.locator('.post-card');
      const displayedCount = await postCards.count();

      console.log(`Displayed posts: ${displayedCount}`);

      // The number of displayed posts should match bicycle posts
      expect(displayedCount, `Should show ${bicyclePosts.length} bicycle posts`).toBe(bicyclePosts.length);
    });

    test('has no JS errors', async ({ pageWithErrorTracking }) => {
      await pageWithErrorTracking.goto('/wpisy-dla/tagu/rowerem.html');
      await pageWithErrorTracking.waitForLoadState('networkidle');
      await expectNoJsErrors(pageWithErrorTracking);
    });

  });

  test.describe('Hike tag page (/wpisy-dla/tagu/pieszo.html)', () => {

    test('page loads and shows posts', async ({ page }) => {
      await page.goto('/wpisy-dla/tagu/pieszo.html');
      await page.waitForLoadState('networkidle');

      // Wait for posts to load
      const postsGrid = page.locator('.posts-grid');
      await expect(postsGrid).toBeVisible({ timeout: 10000 });

      // Should have at least one post
      const postCards = postsGrid.locator('.post-card');
      const count = await postCards.count();
      console.log(`Hike tag page: ${count} posts found`);
      expect(count, 'Should have at least one hike post').toBeGreaterThan(0);
    });

    test('only shows posts with hike tag', async ({ page, request }) => {
      // First get the JSON data to know which posts should appear
      const jsonResponse = await request.get('/jsons/homepage.json');
      const json = await jsonResponse.json();

      const hikePosts = json.posts.filter(p =>
        p.visible && p.ready && p.tags && p.tags.includes('hike')
      );
      console.log(`Expected hike posts: ${hikePosts.length}`);
      console.log('Hike post titles:', hikePosts.map(p => p.title));

      // Now check the page
      await page.goto('/wpisy-dla/tagu/pieszo.html');
      await page.waitForLoadState('networkidle');

      // Wait for posts to load
      await page.waitForSelector('.post-card', { timeout: 10000 });

      const postCards = page.locator('.post-card');
      const displayedCount = await postCards.count();

      console.log(`Displayed posts: ${displayedCount}`);

      // The number of displayed posts should match hike posts
      expect(displayedCount, `Should show ${hikePosts.length} hike posts`).toBe(hikePosts.length);
    });

    test('has no JS errors', async ({ pageWithErrorTracking }) => {
      await pageWithErrorTracking.goto('/wpisy-dla/tagu/pieszo.html');
      await pageWithErrorTracking.waitForLoadState('networkidle');
      await expectNoJsErrors(pageWithErrorTracking);
    });

  });

  test.describe('Filter configuration', () => {

    test('bicycle page has correct filter config', async ({ page }) => {
      await page.goto('/wpisy-dla/tagu/rowerem.html');

      // Get the config from the page
      const config = await page.evaluate(() => {
        const el = document.getElementById('post-collection-config');
        return el ? JSON.parse(el.textContent) : null;
      });

      expect(config).not.toBeNull();
      expect(config.filterBy).toBe('tag');
      expect(config.filterValue).toBe('bicycle');
    });

    test('hike page has correct filter config', async ({ page }) => {
      await page.goto('/wpisy-dla/tagu/pieszo.html');

      // Get the config from the page
      const config = await page.evaluate(() => {
        const el = document.getElementById('post-collection-config');
        return el ? JSON.parse(el.textContent) : null;
      });

      expect(config).not.toBeNull();
      expect(config.filterBy).toBe('tag');
      expect(config.filterValue).toBe('hike');
    });

  });

});
