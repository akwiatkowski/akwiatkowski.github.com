/**
 * Navigation tests - verify navigation styling is consistent across pages
 */
const { test, expect } = require('../fixtures/base');

test.describe('Navigation styling', () => {

  const pagesToTest = [
    { url: '/', name: 'Homepage' },
    { url: '/wiecej.html', name: 'More page' },
    { url: '/wpisy-dla/tagu/rowerem.html', name: 'Tag page' },
    { url: '/mapa_tras.html', name: 'Map page' },
    { url: '/o-mnie.html', name: 'About page' },
  ];

  for (const pageInfo of pagesToTest) {
    test.describe(pageInfo.name, () => {

      test('has navigation with logo and links', async ({ page }) => {
        await page.goto(pageInfo.url);

        // Should have nav element
        const nav = page.locator('nav.site-nav, nav.nav');
        await expect(nav.first()).toBeVisible();

        // Should have logo
        const logo = nav.locator('.site-nav-logo, .nav-logo').first();
        await expect(logo).toBeVisible();

        // Should have links
        const links = nav.locator('.site-nav-links, .nav-links').first();
        await expect(links).toBeVisible();
      });

      test('navigation layout: logo left, links right', async ({ page }) => {
        await page.goto(pageInfo.url);

        const navInner = page.locator('.site-nav-inner, .nav-inner').first();
        const logo = page.locator('.site-nav-logo, .nav-logo').first();
        const links = page.locator('.site-nav-links, .nav-links').first();

        // Get bounding boxes
        const logoBox = await logo.boundingBox();
        const linksBox = await links.boundingBox();

        expect(logoBox, 'Logo should be visible').not.toBeNull();
        expect(linksBox, 'Links should be visible').not.toBeNull();

        if (logoBox && linksBox) {
          // Logo should be on the left (smaller x)
          expect(logoBox.x, 'Logo should be on the left of links').toBeLessThan(linksBox.x);

          // There should be space between them (not touching)
          const logoRight = logoBox.x + logoBox.width;
          expect(linksBox.x - logoRight, 'Should have gap between logo and links').toBeGreaterThan(20);
        }
      });

      test('navigation uses flexbox with space-between', async ({ page }) => {
        await page.goto(pageInfo.url);

        const navInner = page.locator('.site-nav-inner, .nav-inner').first();

        // Check computed styles
        const styles = await navInner.evaluate((el) => {
          const computed = window.getComputedStyle(el);
          return {
            display: computed.display,
            justifyContent: computed.justifyContent,
            alignItems: computed.alignItems
          };
        });

        expect(styles.display, 'Nav inner should be flex').toBe('flex');
        expect(styles.justifyContent, 'Should use space-between').toBe('space-between');
        expect(styles.alignItems, 'Should align center').toBe('center');
      });

    });
  }

});
