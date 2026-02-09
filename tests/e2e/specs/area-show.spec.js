/**
 * Area show page tests - verify area pages load with polygon-cached photos
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

// Area show pages available in dev environment
const AREA_PAGES = [
  {
    name: 'Town with photos',
    url: '/gmina/radzyn_chelminski.html',
    expectPhotos: true,
  },
  {
    name: 'Town with posts',
    url: '/gmina/grudziadz.html',
    expectPhotos: true,
  },
  {
    name: 'County',
    url: '/powiat/grudziadzki.html',
    expectPhotos: true,
  },
  {
    name: 'MacroRegion',
    url: '/obszar/pojezierze_chelminsko-dobrzynskie.html',
    expectPhotos: true,
  },
];

test.describe('Area show pages', () => {

  for (const areaPage of AREA_PAGES) {
    test.describe(areaPage.name, () => {

      test('page loads successfully', async ({ page }) => {
        const response = await page.goto(areaPage.url);
        expect(response?.status(), `${areaPage.url} should return 200`).toBe(200);
      });

      test('has inline area-data JSON', async ({ page }) => {
        await page.goto(areaPage.url);

        const areaData = await page.evaluate(() => {
          const el = document.getElementById('area-data');
          return el ? JSON.parse(el.textContent) : null;
        });

        expect(areaData, 'Should have area-data script block').not.toBeNull();
        expect(areaData.slug).toBeTruthy();
        expect(areaData.name).toBeTruthy();
        expect(areaData.areaType).toBeTruthy();
      });

      test('has posts in area data', async ({ page }) => {
        await page.goto(areaPage.url);

        const areaData = await page.evaluate(() => {
          const el = document.getElementById('area-data');
          return el ? JSON.parse(el.textContent) : null;
        });

        expect(areaData.posts).toBeDefined();
        expect(areaData.posts.length).toBeGreaterThan(0);
      });

      if (areaPage.expectPhotos) {
        test('has photos from polygon cache', async ({ page }) => {
          await page.goto(areaPage.url);

          const areaData = await page.evaluate(() => {
            const el = document.getElementById('area-data');
            return el ? JSON.parse(el.textContent) : null;
          });

          expect(areaData.photos).toBeDefined();
          expect(areaData.photos.length, 'Should have polygon-cached photos').toBeGreaterThan(0);

          // Each photo should have required fields
          const photo = areaData.photos[0];
          expect(photo.desc).toBeTruthy();
          expect(photo.article_url).toBeTruthy();
          expect(photo.post_url).toBeTruthy();
          expect(photo.points).toBeDefined();
        });
      }

      test('has no JS errors', async ({ pageWithErrorTracking }) => {
        await pageWithErrorTracking.goto(areaPage.url);
        await pageWithErrorTracking.waitForLoadState('networkidle');
        await expectNoJsErrors(pageWithErrorTracking);
      });

    });
  }

});
