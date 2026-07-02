/**
 * Picture element tests — verify AVIF <picture> wrappers
 */
const { test, expect, expectNoJsErrors, expectPageLoads } = require('../fixtures/base');
const { getReadyPosts, getTags } = require('../helpers/payload');

test.describe('Picture elements (AVIF)', () => {

  test.describe('Post article pages', () => {

    test('article inline photos use <picture> with AVIF source', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      await page.goto(posts[0].url);

      // Article photos should be wrapped in <picture>
      const pictures = page.locator('.post-article-photo picture');
      await expect(pictures.first()).toBeVisible({ timeout: 10000 });

      const count = await pictures.count();
      expect(count, 'Should have picture elements for article photos').toBeGreaterThan(0);

      // Each picture should have an AVIF source
      const avifSources = page.locator('.post-article-photo picture source[type="image/avif"]');
      const avifCount = await avifSources.count();
      expect(avifCount, 'Each picture should have an AVIF source').toBe(count);
    });

    test('article photos have responsive srcset with AVIF', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      await page.goto(posts[0].url);

      const img = page.locator('.post-article-photo picture img').first();
      await expect(img).toBeVisible({ timeout: 10000 });

      const srcset = await img.getAttribute('srcset');
      expect(srcset, 'img should have srcset').toBeTruthy();
      expect(srcset).toContain('560w');
      expect(srcset).toContain('1000w');

      const avifSource = page.locator('.post-article-photo picture source[type="image/avif"]').first();
      const avifSrcset = await avifSource.getAttribute('srcset');
      expect(avifSrcset, 'AVIF source should have srcset').toBeTruthy();
      expect(avifSrcset).toContain('.avif');
      expect(avifSrcset).toContain('560w');
      expect(avifSrcset).toContain('1000w');
    });

    test('prev/next pager has <picture> with AVIF', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length < 2) {
        test.skip('Need at least 2 posts for pager');
        return;
      }

      // Go to a middle post so both pagers exist
      await page.goto(posts[1].url);

      const pagerPictures = page.locator('.post-pager picture');
      const pagerCount = await pagerPictures.count();
      expect(pagerCount, 'Pagers should have picture elements').toBeGreaterThan(0);

      const avifSources = page.locator('.post-pager picture source[type="image/avif"]');
      const avifCount = await avifSources.count();
      expect(avifCount).toBe(pagerCount);
    });

    test('article photo is at least as wide as text content', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // Use a wide viewport to test desktop layout
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(posts[0].url);

      const img = page.locator('.post-article-photo picture img').first();
      await expect(img).toBeVisible({ timeout: 10000 });

      // Wait for the image to fully load (naturalWidth populated)
      await page.waitForFunction(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img && img.complete && img.naturalWidth > 0;
      }, { timeout: 10000 });

      // Get the article text container width and the rendered image width
      const { containerWidth, imgWidth } = await page.evaluate(() => {
        // Text column selector differs by layout: Crystal uses a Bootstrap
        // grid (.col-lg-8), the Go rewrite uses a centered .post-content column.
        const container = document.querySelector('.col-lg-8') || document.querySelector('.post-content');
        const img = document.querySelector('.post-article-photo picture img');
        return {
          containerWidth: container ? container.getBoundingClientRect().width : 0,
          imgWidth: img ? img.getBoundingClientRect().width : 0
        };
      });

      // Image should fill at least 90% of the text column width
      expect(containerWidth, 'Container should have width').toBeGreaterThan(0);
      expect(imgWidth, 'Image should have width').toBeGreaterThan(0);
      expect(imgWidth, 'Image width should be at least 90% of container').toBeGreaterThanOrEqual(containerWidth * 0.9);
    });

    test('related posts have <picture> with AVIF', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      await page.goto(posts[0].url);

      // Related posts may or may not be present
      const relatedCards = page.locator('.related-post-card');
      const relatedCount = await relatedCards.count();

      if (relatedCount === 0) {
        test.skip('Post has no related posts');
        return;
      }

      const relatedPictures = page.locator('.related-post-card picture');
      const pictureCount = await relatedPictures.count();
      expect(pictureCount, 'Related posts should have picture elements').toBe(relatedCount);

      const avifSources = page.locator('.related-post-card picture source[type="image/avif"]');
      expect(await avifSources.count()).toBe(relatedCount);
    });

  });

  test.describe('Responsive layout', () => {

    test('no horizontal scroll on mobile viewport', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // iPhone SE viewport
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto(posts[0].url);

      // Wait for images to start rendering
      await page.locator('.post-article-photo').first().waitFor({ timeout: 10000 });

      // Check that page content doesn't overflow the viewport
      const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
      const clientWidth = await page.evaluate(() => document.documentElement.clientWidth);
      expect(scrollWidth, 'Page should not have horizontal scroll').toBeLessThanOrEqual(clientWidth);
    });

    test('article photos fill container on multiple viewports', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const viewports = [
        { width: 375, height: 667, name: 'mobile' },
        { width: 768, height: 1024, name: 'tablet' },
        { width: 1280, height: 800, name: 'desktop' },
      ];

      for (const vp of viewports) {
        await page.setViewportSize({ width: vp.width, height: vp.height });
        await page.goto(posts[0].url);

        const img = page.locator('.post-article-photo picture img').first();
        await expect(img).toBeVisible({ timeout: 10000 });

        // Wait for the image to fully load
        await page.waitForFunction(() => {
          const img = document.querySelector('.post-article-photo picture img');
          return img && img.complete && img.naturalWidth > 0;
        }, { timeout: 10000 });

        const { containerWidth, imgWidth } = await page.evaluate(() => {
          const container = document.querySelector('.col-lg-8, .col-md-10') || document.querySelector('article .container .row > div');
          const img = document.querySelector('.post-article-photo picture img');
          return {
            containerWidth: container ? container.getBoundingClientRect().width : 0,
            imgWidth: img ? img.getBoundingClientRect().width : 0
          };
        });

        expect(imgWidth, `Image should fill container on ${vp.name} (${vp.width}px)`).toBeGreaterThanOrEqual(containerWidth * 0.9);
      }
    });

  });

  test.describe('Image source selection', () => {

    test('browser selects AVIF format (Chromium)', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(posts[0].url);

      const img = page.locator('.post-article-photo picture img').first();
      await expect(img).toBeVisible({ timeout: 10000 });

      await page.waitForFunction(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img && img.complete && img.naturalWidth > 0;
      }, { timeout: 10000 });

      const currentSrc = await page.evaluate(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img ? (img.currentSrc || img.src) : '';
      });

      // Chromium supports AVIF, so it should pick the AVIF source
      expect(currentSrc, 'Browser should select AVIF source').toContain('.avif');
    });

    test('mobile viewport selects grid-size image (560w)', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // Mobile viewport at 1x DPR — 375px < 560w, so browser should pick 560w grid image
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto(posts[0].url);

      const img = page.locator('.post-article-photo picture img').first();
      await expect(img).toBeVisible({ timeout: 10000 });

      await page.waitForFunction(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img && img.complete && img.naturalWidth > 0;
      }, { timeout: 10000 });

      const currentSrc = await page.evaluate(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img ? (img.currentSrc || img.src) : '';
      });

      // On mobile (375px, 1x DPR), sizes="100vw" means 375px needed → 560w grid image
      expect(currentSrc, 'Mobile should select grid-size image').toMatch(/_grid\./);
    });

    test('desktop viewport selects article-size image (1000w)', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // Desktop viewport — 1280px > 560w, so browser should pick 1000w article image
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(posts[0].url);

      const img = page.locator('.post-article-photo picture img').first();
      await expect(img).toBeVisible({ timeout: 10000 });

      await page.waitForFunction(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img && img.complete && img.naturalWidth > 0;
      }, { timeout: 10000 });

      const currentSrc = await page.evaluate(() => {
        const img = document.querySelector('.post-article-photo picture img');
        return img ? (img.currentSrc || img.src) : '';
      });

      // On desktop (1280px, 1x DPR), sizes="100vw" means 1280px needed → 1000w article image
      expect(currentSrc, 'Desktop should select article-size image').toMatch(/_article\./);
    });

    test('no horizontal scroll on any viewport', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const viewports = [
        { width: 320, height: 568, name: 'iPhone SE (small)' },
        { width: 375, height: 667, name: 'iPhone 8' },
        { width: 414, height: 896, name: 'iPhone 11' },
        { width: 768, height: 1024, name: 'iPad' },
        { width: 1280, height: 800, name: 'laptop' },
        { width: 1920, height: 1080, name: 'full HD' },
      ];

      for (const vp of viewports) {
        await page.setViewportSize({ width: vp.width, height: vp.height });
        await page.goto(posts[0].url);

        await page.locator('.post-article-photo').first().waitFor({ timeout: 10000 });

        const { scrollWidth, clientWidth } = await page.evaluate(() => ({
          scrollWidth: document.documentElement.scrollWidth,
          clientWidth: document.documentElement.clientWidth,
        }));

        expect(scrollWidth, `No horizontal scroll on ${vp.name} (${vp.width}px)`).toBeLessThanOrEqual(clientWidth);
      }
    });

    test('image rendered width matches container on all viewports', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const viewports = [
        { width: 320, height: 568, name: 'iPhone SE (small)' },
        { width: 375, height: 667, name: 'iPhone 8' },
        { width: 414, height: 896, name: 'iPhone 11' },
        { width: 768, height: 1024, name: 'iPad' },
        { width: 1280, height: 800, name: 'laptop' },
        { width: 1920, height: 1080, name: 'full HD' },
      ];

      for (const vp of viewports) {
        await page.setViewportSize({ width: vp.width, height: vp.height });
        await page.goto(posts[0].url);

        const img = page.locator('.post-article-photo picture img').first();
        await expect(img).toBeVisible({ timeout: 10000 });

        await page.waitForFunction(() => {
          const img = document.querySelector('.post-article-photo picture img');
          return img && img.complete && img.naturalWidth > 0;
        }, { timeout: 10000 });

        const { figureWidth, imgWidth } = await page.evaluate(() => {
          const figure = document.querySelector('.post-article-photo');
          const img = document.querySelector('.post-article-photo picture img');
          return {
            figureWidth: figure ? figure.getBoundingClientRect().width : 0,
            imgWidth: img ? img.getBoundingClientRect().width : 0,
          };
        });

        expect(figureWidth, `Figure should have width on ${vp.name}`).toBeGreaterThan(0);
        expect(imgWidth, `Image should fill figure on ${vp.name} (${vp.width}px): got ${imgWidth}px vs ${figureWidth}px`).toBeGreaterThanOrEqual(figureWidth * 0.95);
      }
    });

  });

  test.describe('Gallery pages', () => {

    test('gallery grid uses <picture> with AVIF source', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      const post = posts[0];
      const galleryUrl = post.url.replace(/\.html$/, '').replace(/^\//, '/galeria/') + '.html';

      await page.goto(galleryUrl);

      // Dynamic gallery renders into .masonry-grid
      const pictures = page.locator('.masonry-grid .gallery-item picture');
      await expect(pictures.first()).toBeVisible({ timeout: 10000 });

      const count = await pictures.count();
      expect(count, 'Gallery items should have picture elements').toBeGreaterThan(0);

      const avifSources = page.locator('.masonry-grid .gallery-item picture source[type="image/avif"]');
      expect(await avifSources.count()).toBe(count);
    });

    test('non-dynamic gallery uses <picture> with AVIF', async ({ pageWithErrorTracking, payload }) => {
      const page = pageWithErrorTracking;
      const posts = getReadyPosts(payload).filter(p => p.photos_count > 0);

      if (posts.length === 0) {
        test.skip('No posts with photos');
        return;
      }

      // Tag gallery pages use the static gallery template
      const tags = getTags(payload);
      if (tags.length === 0) {
        test.skip('No tags available');
        return;
      }

      // Try to find a tag gallery that exists
      for (const tag of tags.slice(0, 5)) {
        const galleryUrl = tag.url.replace('/tag/', '/galeria/tag/');
        const response = await page.goto(galleryUrl);
        if (response?.status() !== 200) continue;

        // Static galleries use .gallery-image picture
        const pictures = page.locator('.gallery-image picture');
        const count = await pictures.count();

        if (count > 0) {
          const avifSources = page.locator('.gallery-image picture source[type="image/avif"]');
          expect(await avifSources.count(), 'Static gallery should have AVIF sources').toBe(count);
          return;
        }
      }

      test.skip('No tag gallery found with static images');
    });

  });

});
