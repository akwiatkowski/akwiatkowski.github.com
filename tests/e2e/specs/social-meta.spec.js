/**
 * Social meta tags tests - verify og:type, og:locale, Twitter Card, descriptions
 */
const { test, expect } = require('../fixtures/base');

/**
 * Helper: extract meta tags from a page
 */
async function getMetaTags(page) {
  return page.evaluate(() => {
    const get = (attr, value) => {
      const el = document.querySelector(`meta[${attr}="${value}"]`);
      return el ? el.getAttribute('content') : null;
    };
    return {
      ogType: get('property', 'og:type'),
      ogLocale: get('property', 'og:locale'),
      ogTitle: get('property', 'og:title'),
      ogDescription: get('property', 'og:description'),
      ogUrl: get('property', 'og:url'),
      ogSiteName: get('property', 'og:site_name'),
      ogImage: get('property', 'og:image'),
      ogImageAlt: get('property', 'og:image:alt'),
      twitterCard: get('name', 'twitter:card'),
      twitterTitle: get('name', 'twitter:title'),
      twitterDescription: get('name', 'twitter:description'),
      metaDescription: get('name', 'description'),
    };
  });
}

const PAGES_WITH_IMAGES = [
  { url: '/portfolio.html', name: 'Portfolio' },
  { url: '/gmina/dragacz.html', name: 'Area show (town)' },
];

const ALL_PAGES = [
  { url: '/', name: 'Homepage' },
  { url: '/portfolio.html', name: 'Portfolio' },
  { url: '/gmina/dragacz.html', name: 'Area show (town)' },
  { url: '/wiecej.html', name: 'More page' },
  { url: '/o-mnie.html', name: 'About page' },
];

test.describe('Social meta tags', () => {

  for (const page of ALL_PAGES) {
    test.describe(page.name, () => {

      test('has og:type and og:locale', async ({ page: p }) => {
        await p.goto(page.url);
        const meta = await getMetaTags(p);

        expect(meta.ogType, 'og:type should be "website"').toBe('website');
        expect(meta.ogLocale, 'og:locale should be "pl_PL"').toBe('pl_PL');
      });

      test('has Twitter Card tags', async ({ page: p }) => {
        await p.goto(page.url);
        const meta = await getMetaTags(p);

        expect(meta.twitterCard, 'twitter:card should be summary_large_image').toBe('summary_large_image');
        expect(meta.twitterTitle, 'twitter:title should not be empty').toBeTruthy();
        expect(meta.twitterDescription, 'twitter:description should not be empty').toBeTruthy();
      });

      test('has non-empty description', async ({ page: p }) => {
        await p.goto(page.url);
        const meta = await getMetaTags(p);

        expect(meta.metaDescription, 'meta description should not be empty').toBeTruthy();
        expect(meta.ogDescription, 'og:description should not be empty').toBeTruthy();
      });

      test('has og:title, og:url, og:site_name', async ({ page: p }) => {
        await p.goto(page.url);
        const meta = await getMetaTags(p);

        expect(meta.ogTitle, 'og:title should not be empty').toBeTruthy();
        expect(meta.ogUrl, 'og:url should not be empty').toBeTruthy();
        expect(meta.ogSiteName, 'og:site_name should not be empty').toBeTruthy();
      });

    });
  }

  for (const page of PAGES_WITH_IMAGES) {
    test(`${page.name} has og:image:alt`, async ({ page: p }) => {
      await p.goto(page.url);
      const meta = await getMetaTags(p);

      expect(meta.ogImage, 'og:image should be present').toBeTruthy();
      expect(meta.ogImageAlt, 'og:image:alt should be present').toBeTruthy();
    });
  }

  test.describe('Per-view descriptions', () => {

    test('portfolio has custom description', async ({ page }) => {
      await page.goto('/portfolio.html');
      const meta = await getMetaTags(page);

      expect(meta.metaDescription).toContain('Portfolio fotograficzne');
    });

    test('area show has custom description with stats', async ({ page }) => {
      await page.goto('/gmina/dragacz.html');
      const meta = await getMetaTags(page);

      expect(meta.metaDescription).toContain('Dragacz');
      expect(meta.metaDescription).toMatch(/wypraw/);
      expect(meta.metaDescription).toMatch(/zdjęć/);
    });

  });

  test.describe('Old homepage removed', () => {

    test('/index.old.html no longer exists', async ({ request }) => {
      const response = await request.get('/index.old.html');
      expect(response.status(), '/index.old.html should return 404').toBe(404);
    });

  });

});
