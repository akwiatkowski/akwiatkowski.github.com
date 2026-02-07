/**
 * Area post list filtering tests - verify posts are correctly filtered for all area types
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

// Area types with example pages and their JSON field/filter config
const AREA_TYPES = [
  {
    name: 'Town',
    url: '/wpisy-dla/gminy/grudziadz.html',
    filterBy: 'town',
    jsonField: 'town_slugs',
    slug: 'grudziadz',
  },
  {
    name: 'Voivodeship',
    url: '/wpisy-dla/wojewodztwa/kujawskopomorskie.html',
    filterBy: 'voivodeship',
    jsonField: 'voivodeship_slugs',
    slug: 'kujawskopomorskie',
  },
  {
    name: 'MesoRegion',
    url: '/wpisy-dla/regionu/pojezierze_brodnickie.html',
    filterBy: 'meso_region',
    jsonField: 'meso_region_slugs',
    slug: 'pojezierze_brodnickie',
  },
  {
    name: 'County',
    url: '/wpisy-dla/powiatu/grudziadzki.html',
    filterBy: 'county',
    jsonField: 'county_slugs',
    slug: 'grudziadzki',
  },
  {
    name: 'MacroRegion',
    url: '/wpisy-dla/obszaru/pojezierze_chelminskodobrzynskie.html',
    filterBy: 'macro_region',
    jsonField: 'macro_region_slugs',
    slug: 'pojezierze_chelminskodobrzynskie',
  },
];

test.describe('Area post list filtering', () => {

  for (const areaType of AREA_TYPES) {
    test.describe(`${areaType.name} (${areaType.url})`, () => {

      test('page loads and shows posts', async ({ page }) => {
        await page.goto(areaType.url);
        await page.waitForLoadState('networkidle');

        const postsGrid = page.locator('.posts-grid');
        await expect(postsGrid).toBeVisible({ timeout: 10000 });

        const postCards = postsGrid.locator('.post-card');
        const count = await postCards.count();
        console.log(`${areaType.name} page (${areaType.slug}): ${count} posts found`);
        expect(count, `Should have at least one post for ${areaType.name}`).toBeGreaterThan(0);
      });

      test('has correct filter config', async ({ page }) => {
        await page.goto(areaType.url);

        const config = await page.evaluate(() => {
          const el = document.getElementById('post-collection-config');
          return el ? JSON.parse(el.textContent) : null;
        });

        expect(config).not.toBeNull();
        expect(config.filterBy).toBe(areaType.filterBy);
        expect(config.filterValue).toBe(areaType.slug);
      });

      test('displayed posts match JSON data', async ({ page, request }) => {
        const jsonResponse = await request.get('/jsons/homepage.json');
        const json = await jsonResponse.json();

        const expectedPosts = json.posts.filter(p =>
          p.visible && p.ready && (p[areaType.jsonField] || []).includes(areaType.slug)
        );
        console.log(`${areaType.name} (${areaType.slug}): expected ${expectedPosts.length} posts from JSON`);
        expect(expectedPosts.length, `JSON should have posts for ${areaType.slug}`).toBeGreaterThan(0);

        await page.goto(areaType.url);
        await page.waitForLoadState('networkidle');
        await page.waitForSelector('.post-card', { timeout: 10000 });

        const postCards = page.locator('.post-card');
        const displayedCount = await postCards.count();
        console.log(`${areaType.name} (${areaType.slug}): displayed ${displayedCount} posts`);

        expect(displayedCount, `Should show ${expectedPosts.length} posts for ${areaType.name}`).toBe(expectedPosts.length);
      });

      test('has no JS errors', async ({ pageWithErrorTracking }) => {
        await pageWithErrorTracking.goto(areaType.url);
        await pageWithErrorTracking.waitForLoadState('networkidle');
        await expectNoJsErrors(pageWithErrorTracking);
      });

    });
  }

});
