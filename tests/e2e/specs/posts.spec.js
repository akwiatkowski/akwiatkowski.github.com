/**
 * Post pages tests - data-driven from e2e.json
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');
const { getReadyPosts } = require('../helpers/payload');

test.describe('Post pages', () => {

  test('all posts from e2e.json are accessible', async ({ pageWithErrorTracking, payload, baseURL }) => {
    const page = pageWithErrorTracking;
    const posts = getReadyPosts(payload);

    expect(posts.length, 'Should have posts in e2e data').toBeGreaterThan(0);

    // Test a sample of posts (first 10 + random selection for speed)
    const sampleSize = Math.min(20, posts.length);
    const sample = posts.slice(0, 10);

    // Add some random posts
    for (let i = 0; i < sampleSize - 10 && posts.length > 10; i++) {
      const randomIndex = Math.floor(Math.random() * posts.length);
      if (!sample.includes(posts[randomIndex])) {
        sample.push(posts[randomIndex]);
      }
    }

    for (const post of sample) {
      await expectPageLoads(page, post.url);
      await expectNoJsErrors(page);
    }
  });

  test('post article has required elements', async ({ pageWithErrorTracking, payload }) => {
    const page = pageWithErrorTracking;
    const posts = getReadyPosts(payload);
    const post = posts[0];

    await page.goto(post.url);
    await expectNoJsErrors(page);

    // Check article structure
    await expect(page.locator('article')).toBeVisible();
    await expect(page.locator('h1')).toBeVisible();

    // Check navigation exists
    await expect(page.locator('.post-pager-container, .btn-group')).toBeVisible();
  });

  test('post with photos has working gallery link', async ({ pageWithErrorTracking, payload }) => {
    const page = pageWithErrorTracking;
    const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

    if (posts.length === 0) {
      test.skip('No posts with photos');
      return;
    }

    const post = posts[0];
    await page.goto(post.url);

    // Gallery link should exist and work
    const galleryLink = page.locator('a[href*="/galeria/"]').first();
    if (await galleryLink.count() > 0) {
      await galleryLink.click();
      await expect(page).toHaveURL(/\/galeria\//);
      await expectNoJsErrors(page);
    }
  });

  test('related posts section works', async ({ pageWithErrorTracking, payload }) => {
    const page = pageWithErrorTracking;
    const posts = getReadyPosts(payload);
    const post = posts[0];

    await page.goto(post.url);

    // If related posts exist, check they're clickable
    const relatedLinks = page.locator('.related-posts-grid a, .related-post-card');
    const count = await relatedLinks.count();

    if (count > 0) {
      // Click first related post
      await relatedLinks.first().click();
      await expect(page).toHaveURL(/\/\d{4}\/\d{2}\//);
      await expectNoJsErrors(page);
    }
  });

  test('prev/next navigation works', async ({ pageWithErrorTracking, payload }) => {
    const page = pageWithErrorTracking;
    const posts = getReadyPosts(payload);

    // Find a post that's not first or last
    if (posts.length < 3) {
      test.skip('Not enough posts for navigation test');
      return;
    }

    const middlePost = posts[Math.floor(posts.length / 2)];
    await page.goto(middlePost.url);

    // Check prev/next links exist
    const prevLink = page.locator('.post-pager-prev, a:has-text("Poprzedni")').first();
    const nextLink = page.locator('.post-pager-next, a:has-text("Następny")').first();

    if (await prevLink.count() > 0) {
      const href = await prevLink.getAttribute('href');
      expect(href).toBeTruthy();
    }

    if (await nextLink.count() > 0) {
      const href = await nextLink.getAttribute('href');
      expect(href).toBeTruthy();
    }
  });

});
