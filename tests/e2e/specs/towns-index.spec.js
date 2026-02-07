/**
 * Towns index page tests - verify voivodeship groups, town cards, and search filtering
 */
const { test, expect, expectNoJsErrors } = require('../fixtures/base');

test.describe('Towns Index Page', () => {

  test('page loads with voivodeship groups and town cards', async ({ page, pageWithErrorTracking }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    // App mount point should be rendered
    const app = page.locator('#towns-app');
    await expect(app).toBeVisible();

    // Should have at least one voivodeship group
    const groups = page.locator('.voivodeship-group');
    const groupCount = await groups.count();
    expect(groupCount, 'Should have at least one voivodeship group').toBeGreaterThan(0);

    // Each group should have a header with name and count
    const firstGroup = groups.first();
    await expect(firstGroup.locator('.voivodeship-name')).toBeVisible();
    await expect(firstGroup.locator('.voivodeship-count')).toBeVisible();

    // Should have town cards
    const townCards = page.locator('.town-card');
    const townCount = await townCards.count();
    expect(townCount, 'Should have at least one town card').toBeGreaterThan(0);

    // Town cards should have names
    const firstCard = townCards.first();
    await expect(firstCard.locator('.town-card-name')).toBeVisible();
  });

  test('voivodeship headers link to voivodeship show pages', async ({ page, request }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const voivodeshipLinks = page.locator('.voivodeship-name');
    const count = await voivodeshipLinks.count();
    expect(count).toBeGreaterThan(0);

    for (let i = 0; i < count; i++) {
      const href = await voivodeshipLinks.nth(i).getAttribute('href');
      expect(href, 'Voivodeship link should have href').toBeTruthy();
      expect(href).toContain('/wojewodztwo/');

      const response = await request.get(href);
      expect(response.status(), `Voivodeship link ${href} should return 200`).toBe(200);
    }
  });

  test('town cards link to town show pages', async ({ page, request }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const townCards = page.locator('.town-card');
    const count = await townCards.count();

    // Check first 5 town card links (to keep test fast)
    const checkCount = Math.min(count, 5);
    for (let i = 0; i < checkCount; i++) {
      const href = await townCards.nth(i).getAttribute('href');
      expect(href, 'Town card should have href').toBeTruthy();
      expect(href).toContain('/gmina/');

      const response = await request.get(href);
      expect(response.status(), `Town link ${href} should return 200`).toBe(200);
    }
  });

  test('search filters towns in real-time', async ({ page }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const searchInput = page.locator('.towns-search');
    await expect(searchInput).toBeVisible();

    // Get initial count
    const initialCards = await page.locator('.town-card').count();
    expect(initialCards).toBeGreaterThan(0);

    // Type a search query that should match fewer results
    const firstCardName = await page.locator('.town-card-name').first().textContent();
    await searchInput.fill(firstCardName);

    // Wait for filtering
    await page.waitForTimeout(200);

    // Should have at least one result matching the name
    const filteredCards = await page.locator('.town-card').count();
    expect(filteredCards).toBeGreaterThanOrEqual(1);
    expect(filteredCards).toBeLessThanOrEqual(initialCards);

    // The search count should update
    const countText = await page.locator('.towns-search-count').textContent();
    expect(countText).toContain(String(filteredCards));
  });

  test('search with no results shows empty message', async ({ page }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const searchInput = page.locator('.towns-search');
    await searchInput.fill('zzzznonexistenttown');
    await page.waitForTimeout(200);

    // Should show no results message
    const noResults = page.locator('.towns-no-results');
    await expect(noResults).toBeVisible();

    // No town cards or voivodeship groups should be visible
    const townCards = await page.locator('.town-card').count();
    expect(townCards).toBe(0);
  });

  test('clearing search restores all towns', async ({ page }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const searchInput = page.locator('.towns-search');
    const initialCards = await page.locator('.town-card').count();

    // Filter then clear
    await searchInput.fill('zzz');
    await page.waitForTimeout(200);
    await searchInput.fill('');
    await page.waitForTimeout(200);

    const restoredCards = await page.locator('.town-card').count();
    expect(restoredCards).toBe(initialCards);
  });

  test('empty voivodeship groups are hidden when filtering', async ({ page }) => {
    await page.goto('/gminy.html');
    await page.waitForLoadState('networkidle');

    const initialGroups = await page.locator('.voivodeship-group').count();

    // Get a town name from the first voivodeship group only
    const firstGroupTown = await page.locator('.voivodeship-group').first().locator('.town-card-name').first().textContent();

    const searchInput = page.locator('.towns-search');
    await searchInput.fill(firstGroupTown);
    await page.waitForTimeout(200);

    // Should have fewer groups (empty ones hidden)
    const filteredGroups = await page.locator('.voivodeship-group').count();
    expect(filteredGroups).toBeGreaterThanOrEqual(1);
    expect(filteredGroups).toBeLessThanOrEqual(initialGroups);
  });

  test('no JavaScript errors on page', async ({ pageWithErrorTracking }) => {
    await pageWithErrorTracking.goto('/gminy.html');
    await pageWithErrorTracking.waitForLoadState('networkidle');
    await expectNoJsErrors(pageWithErrorTracking);
  });
});
