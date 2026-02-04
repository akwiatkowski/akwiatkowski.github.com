/**
 * Smoke tests - quick checks that all pages exist
 */
const { test, expect } = require('../fixtures/base');
const { getReadyPosts, getTags, getVoivodeships } = require('../helpers/payload');

test.describe('Smoke tests', () => {

  test.describe('All posts exist', () => {

    test('every post URL returns 200', async ({ request, payload }) => {
      const posts = getReadyPosts(payload);
      const errors = [];

      for (const post of posts) {
        const response = await request.get(post.url);
        if (response.status() !== 200) {
          errors.push({ url: post.url, status: response.status() });
        }
      }

      if (errors.length > 0) {
        console.error('Failed posts:', errors);
      }
      expect(errors, `${errors.length} posts returned non-200 status`).toHaveLength(0);
    });

  });

  test.describe('All tag pages exist', () => {

    test('every tag URL returns 200', async ({ request, payload }) => {
      const tags = getTags(payload);
      const errors = [];

      for (const tag of tags) {
        // Use tag.url which has correct Polish slug (e.g., /tag/najlepsze.html not /tag/best.html)
        const url = tag.url;
        const response = await request.get(url);
        if (response.status() !== 200) {
          errors.push({ url, status: response.status() });
        }
      }

      if (errors.length > 0) {
        console.error('Failed tags:', errors);
      }
      expect(errors, `${errors.length} tags returned non-200 status`).toHaveLength(0);
    });

  });

  test.describe('All voivodeship pages exist', () => {

    test('every voivodeship with posts has page', async ({ request, payload }) => {
      const voivodeships = getVoivodeships(payload);
      const posts = getReadyPosts(payload);

      // Find voivodeships that have at least one post
      const voivodeshipsWithPosts = new Set();
      for (const post of posts) {
        for (const v of (post.voivodeships || [])) {
          voivodeshipsWithPosts.add(v);
        }
      }

      const errors = [];

      for (const v of voivodeships) {
        // Only test voivodeships that have posts (pages are only rendered for these)
        if (!voivodeshipsWithPosts.has(v.slug)) {
          continue;
        }

        // Use show_url from payload which has correct URL
        const url = v.show_url;
        const response = await request.get(url);
        if (response.status() !== 200) {
          errors.push({ url, status: response.status() });
        }
      }

      if (errors.length > 0) {
        console.error('Failed voivodeships:', errors);
      }
      expect(errors, `${errors.length} voivodeships returned non-200 status`).toHaveLength(0);
    });

  });

  test.describe('Feed files exist', () => {

    const feedUrls = [
      '/feed.xml',
      '/feed_atom.xml',
      '/sitemap.xml',
      '/robots.txt',
      '/payload.json',
      '/photos.json',
    ];

    for (const url of feedUrls) {
      test(`${url} returns 200`, async ({ request }) => {
        const response = await request.get(url);
        expect(response.status(), `${url} should exist`).toBe(200);
      });
    }

  });

});
