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

      // Should have gallery images
      const images = page.locator('.gallery img, .photo-grid img, article img');
      await expect(images.first()).toBeVisible({ timeout: 10000 });

      const count = await images.count();
      expect(count, 'Gallery should have images').toBeGreaterThan(0);
    });

  });

  test.describe('Tag galleries', () => {

    test('tag gallery pages load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const tags = getTags(payload);

      if (tags.length === 0) {
        test.skip('No tags in payload');
        return;
      }

      // Test sample of tag galleries
      const sample = tags.slice(0, 3);
      for (const tag of sample) {
        const galleryUrl = `/galeria/tag/${tag.slug}.html`;
        await expectPageLoads(page, galleryUrl);
        await expectNoJsErrors(page);
      }
    });

  });

  test.describe('Area galleries', () => {

    test('voivodeship gallery pages load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const voivodeships = payload.voivodeships || [];

      if (voivodeships.length === 0) {
        test.skip('No voivodeships in payload');
        return;
      }

      // Test sample
      const sample = voivodeships.slice(0, 2);
      for (const v of sample) {
        const galleryUrl = `/galeria/wojewodztwa/${v.slug}.html`;
        await expectPageLoads(page, galleryUrl);
        await expectNoJsErrors(page);
      }
    });

  });

});
