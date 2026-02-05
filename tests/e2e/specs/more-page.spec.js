/**
 * More page (/wiecej.html) tests - verify all links are valid
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('More page (/wiecej.html)', () => {

  test('page loads without errors', async ({ pageWithErrorTracking }) => {
    await pageWithErrorTracking.goto('/wiecej.html');
    await pageWithErrorTracking.waitForLoadState('networkidle');
    await expectNoJsErrors(pageWithErrorTracking);
  });

  test('has page title', async ({ page }) => {
    await page.goto('/wiecej.html');
    const title = await page.title();
    expect(title).toContain('Więcej');
  });

  test('has navigation links', async ({ page }) => {
    await page.goto('/wiecej.html');

    // Check nav exists
    const nav = page.locator('nav.nav');
    await expect(nav).toBeVisible();

    // Check nav links
    const navLinks = nav.locator('a');
    const count = await navLinks.count();
    expect(count, 'Should have navigation links').toBeGreaterThan(3);
  });

  test('has more links grid', async ({ page }) => {
    await page.goto('/wiecej.html');

    // Check more links grid exists
    const linksGrid = page.locator('.more-links-grid');
    await expect(linksGrid).toBeVisible();

    // Should have at least one link
    const moreLinks = linksGrid.locator('.more-link');
    const count = await moreLinks.count();
    expect(count, 'Should have at least one more link').toBeGreaterThan(0);
  });

  test('all links in more-links-grid return 200', async ({ page, request }) => {
    await page.goto('/wiecej.html');

    // Get all links in the more links grid
    const moreLinks = page.locator('.more-links-grid .more-link');
    const count = await moreLinks.count();

    const errors = [];
    for (let i = 0; i < count; i++) {
      const href = await moreLinks.nth(i).getAttribute('href');
      const linkText = await moreLinks.nth(i).locator('.more-link-name').textContent();

      if (href && !href.startsWith('http') && !href.startsWith('#')) {
        const response = await request.get(href);
        if (response.status() !== 200) {
          errors.push({ url: href, status: response.status(), linkText });
        }
      }
    }

    if (errors.length > 0) {
      console.error('Broken links in more-links-grid:', errors);
    }
    expect(errors, `${errors.length} links returned non-200 status`).toHaveLength(0);
  });

  test('panoramio map link works', async ({ page, request }) => {
    await page.goto('/wiecej.html');

    // Find the panoramio/mapa2 link
    const mapa2Link = page.locator('.more-link[href="/mapa2.html"]');
    await expect(mapa2Link).toBeVisible();

    // Verify the page exists
    const response = await request.get('/mapa2.html');
    expect(response.status()).toBe(200);
  });

  test('panoramio map link is clickable and loads page', async ({ page }) => {
    await page.goto('/wiecej.html');

    // Click the panoramio/mapa2 link
    const mapa2Link = page.locator('.more-link[href="/mapa2.html"]');
    await mapa2Link.click();

    // Should navigate to the page
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/mapa2.html');

    // Page should have content
    await expect(page.locator('body')).not.toBeEmpty();
  });

  test('all navigation links return 200', async ({ page, request }) => {
    await page.goto('/wiecej.html');

    // Get all links in navigation
    const navLinks = page.locator('nav.nav a');
    const count = await navLinks.count();

    const errors = [];
    for (let i = 0; i < count; i++) {
      const href = await navLinks.nth(i).getAttribute('href');
      const linkText = await navLinks.nth(i).textContent();

      if (href && !href.startsWith('http') && !href.startsWith('#')) {
        const response = await request.get(href);
        if (response.status() !== 200) {
          errors.push({ url: href, status: response.status(), linkText });
        }
      }
    }

    if (errors.length > 0) {
      console.error('Broken navigation links:', errors);
    }
    expect(errors, `${errors.length} navigation links returned non-200 status`).toHaveLength(0);
  });

  test('all footer links return 200', async ({ page, request }) => {
    await page.goto('/wiecej.html');

    // Get all links in footer
    const footerLinks = page.locator('footer.footer a');
    const count = await footerLinks.count();

    const errors = [];
    for (let i = 0; i < count; i++) {
      const href = await footerLinks.nth(i).getAttribute('href');
      const linkText = await footerLinks.nth(i).textContent();

      if (href && !href.startsWith('http') && !href.startsWith('#')) {
        const response = await request.get(href);
        if (response.status() !== 200) {
          errors.push({ url: href, status: response.status(), linkText });
        }
      }
    }

    if (errors.length > 0) {
      console.error('Broken footer links:', errors);
    }
    expect(errors, `${errors.length} footer links returned non-200 status`).toHaveLength(0);
  });

});
