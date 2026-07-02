/**
 * Base test fixtures with common functionality
 */
const { test: base, expect } = require('@playwright/test');
const { fetchPayload } = require('../helpers/payload');

/**
 * Extended test with payload data and JS error tracking
 */
const test = base.extend({
  // Payload data available in all tests
  payload: async ({ baseURL }, use) => {
    const payload = await fetchPayload(baseURL);
    await use(payload);
  },

  // Page with automatic JS error tracking
  pageWithErrorTracking: async ({ page }, use) => {
    const jsErrors = [];
    const failedRequests = [];

    page.on('pageerror', error => {
      jsErrors.push(error.message);
    });

    page.on('requestfailed', request => {
      // Ignore external requests
      if (!request.url().includes('localhost')) return;
      failedRequests.push({
        url: request.url(),
        failure: request.failure()?.errorText
      });
    });

    // Attach error getters to page
    page.getJsErrors = () => jsErrors;
    page.getFailedRequests = () => failedRequests;

    await use(page);
  },
});

/**
 * Assert page loaded without JS errors
 */
async function expectNoJsErrors(page) {
  const errors = page.getJsErrors ? page.getJsErrors() : [];
  if (errors.length > 0) {
    console.error('JS Errors:', errors);
  }
  expect(errors, 'Expected no JavaScript errors').toHaveLength(0);
}

/**
 * Assert no failed requests (404s, etc.)
 */
async function expectNoFailedRequests(page) {
  const failed = page.getFailedRequests ? page.getFailedRequests() : [];
  if (failed.length > 0) {
    console.error('Failed requests:', failed);
  }
  expect(failed, 'Expected no failed requests').toHaveLength(0);
}

/**
 * Common page assertions
 */
async function expectPageLoads(page, url) {
  const response = await page.goto(url);
  expect(response?.status(), `Page ${url} should return 200`).toBe(200);
}

module.exports = {
  test,
  expect,
  expectNoJsErrors,
  expectNoFailedRequests,
  expectPageLoads,
};
