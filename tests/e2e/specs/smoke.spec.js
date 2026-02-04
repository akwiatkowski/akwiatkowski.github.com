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
        const url = `/tag/${tag.slug}.html`;
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

    test('every voivodeship URL returns 200', async ({ request, payload }) => {
      const voivodeships = getVoivodeships(payload);
      const errors = [];

      for (const v of voivodeships) {
        const url = `/wojewodztwo/${v.slug}.html`;
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
