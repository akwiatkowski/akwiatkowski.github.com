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

    test('lightbox opens, navigates, and closes', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 3);

      if (posts.length === 0) {
        test.skip('No posts with enough photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      await page.goto(galleryUrl);

      // Wait for gallery images to render
      const items = page.locator('.masonry-grid .gallery-item');
      await expect(items.first()).toBeVisible({ timeout: 10000 });

      // Click first photo — lightbox should open
      await items.first().click();
      await expect(page.locator('.photo-lightbox')).toBeVisible();
      await expect(page.locator('.photo-lightbox-counter')).toContainText('1 /');

      // Navigate forward with ArrowRight
      await page.keyboard.press('ArrowRight');
      await expect(page.locator('.photo-lightbox-counter')).toContainText('2 /');

      // Navigate back with ArrowLeft
      await page.keyboard.press('ArrowLeft');
      await expect(page.locator('.photo-lightbox-counter')).toContainText('1 /');

      // Close with Escape
      await page.keyboard.press('Escape');
      await expect(page.locator('.photo-lightbox')).not.toBeVisible();
    });

  });

  test.describe('Gallery image optimization', () => {

    test('gallery grid uses grid-size images, not article-size', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      await page.goto(galleryUrl);

      // Wait for gallery to render
      const images = page.locator('.masonry-grid .gallery-item img');
      await expect(images.first()).toBeVisible({ timeout: 10000 });

      // Check that grid images use grid size, not article size
      // With <picture>, browser may select AVIF source — check currentSrc and src
      const srcs = await images.evaluateAll(imgs => imgs.map(img => img.currentSrc || img.src));
      const gridImages = srcs.filter(s => s.includes('_grid.'));
      const articleImages = srcs.filter(s => s.includes('_article.'));

      expect(gridImages.length, 'Grid should use grid-size images').toBeGreaterThan(0);
      expect(articleImages.length, 'Grid should not use article-size images').toBe(0);
    });

    test('lightbox shows progressive loading (article then full-res)', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      await page.goto(galleryUrl);

      // Wait for gallery to render and click first photo
      const items = page.locator('.masonry-grid .gallery-item');
      await expect(items.first()).toBeVisible({ timeout: 10000 });
      await items.first().click();

      // Lightbox should open
      await expect(page.locator('.photo-lightbox')).toBeVisible();

      // The lightbox image should initially show article-size (progressive fallback)
      const lightboxImg = page.locator('.photo-lightbox-img-wrap img');
      const src = await lightboxImg.getAttribute('src');
      // Should be article (initial) or full-res (if already loaded) — not grid
      expect(src).not.toContain('/grid_');

      await page.keyboard.press('Escape');
    });

    test('no bulk preloading of all images on page load', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 10);

      if (posts.length === 0) {
        test.skip('No posts with enough photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      // Track all image requests to full-res (original) images
      const fullResRequests = [];
      page.on('request', request => {
        const url = request.url();
        if (url.includes('/images/') && !url.includes('/article_') && !url.includes('/grid_')
            && !url.includes('/card_') && !url.includes('/thumbnail_')
            && url.match(/\.(jpg|jpeg|png|webp)$/i)) {
          fullResRequests.push(url);
        }
      });

      await page.goto(galleryUrl);

      // Wait for gallery to fully render
      const images = page.locator('.masonry-grid .gallery-item img');
      await expect(images.first()).toBeVisible({ timeout: 10000 });

      // Wait a bit for any eager preloading to happen
      await page.waitForTimeout(2000);

      // Should NOT have preloaded all full-res images
      // (before the fix, all 70+ images would start downloading)
      expect(fullResRequests.length, 'Should not bulk-preload full-res images').toBeLessThan(5);
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
