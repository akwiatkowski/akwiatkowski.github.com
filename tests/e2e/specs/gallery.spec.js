/**
 * Gallery pages tests
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');
const { getReadyPosts, getTags } = require('../helpers/payload');

test.describe('Gallery pages', () => {

  test.describe('Post galleries', () => {

    test('post gallery pages load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // Test sample of post galleries
      const sample = posts.slice(0, 5);
      for (const post of sample) {
        const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';
        await expectPageLoads(page, galleryUrl);
        await expectNoJsErrors(page);
      }
    });

    test('gallery has images', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      await page.goto(galleryUrl);
      await expectNoJsErrors(page);

      // Should have gallery images (rendered by gallery_dynamic.js into .masonry-grid)
      const images = page.locator('.masonry-grid .gallery-item img');
      await expect(images.first()).toBeVisible({ timeout: 10000 });

      const count = await images.count();
      expect(count, 'Gallery should have images').toBeGreaterThan(0);
    });

  });

  test.describe('Tag galleries', () => {

    test('tag gallery pages load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const tags = getTags(payload);
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      // Find tags that have posts with photos (gallery pages only exist for these)
      const tagsWithPhotos = new Set();
      for (const post of posts) {
        for (const tag of (post.tags || [])) {
          tagsWithPhotos.add(tag);
        }
      }

      const tagsToTest = tags.filter(t => tagsWithPhotos.has(t.slug));

      if (tagsToTest.length === 0) {
        test.skip('No tags with photos');
        return;
      }

      // Test sample of tag galleries
      // Derive gallery URL from tag.url (uses Polish slug: /tag/najlepsze.html -> /galeria/tag/najlepsze.html)
      // Not all tags have gallery pages, so check existence first
      let tested = 0;
      for (const tag of tagsToTest) {
        if (tested >= 3) break;
        const galleryUrl = tag.url.replace('/tag/', '/galeria/tag/');
        const response = await page.goto(galleryUrl);
        if (response?.status() === 404) continue;
        expect(response?.status(), `Gallery ${galleryUrl} should return 200`).toBe(200);
        await expectNoJsErrors(page);
        tested++;
      }
    });

  });

  test.describe('Area galleries', () => {

    test('voivodeship gallery pages load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const voivodeships = payload.voivodeships || [];
      const posts = payload.posts || [];

      // Find voivodeships that have posts (gallery pages only exist for these)
      const voivodeshipsWithPosts = new Set();
      for (const post of posts) {
        for (const v of (post.voivodeships || [])) {
          voivodeshipsWithPosts.add(v);
        }
      }

      const voivodeshipsToTest = voivodeships.filter(v => voivodeshipsWithPosts.has(v.slug));

      if (voivodeshipsToTest.length === 0) {
        test.skip('No voivodeships with posts');
        return;
      }

      // Test sample using gallery_url from payload
      const sample = voivodeshipsToTest.slice(0, 2);
      for (const v of sample) {
        await expectPageLoads(page, v.gallery_url);
        await expectNoJsErrors(page);
      }
    });

  });

});
