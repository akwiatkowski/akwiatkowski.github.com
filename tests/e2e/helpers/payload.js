/**
 * Helper to fetch and work with e2e.json test data
 */

let cachedPayload = null;

async function fetchPayload(baseURL) {
  if (cachedPayload) return cachedPayload;

  const response = await fetch(`${baseURL}/jsons/e2e.json`);
  if (!response.ok) {
    throw new Error(`Failed to fetch e2e.json: ${response.status}`);
  }

  cachedPayload = await response.json();
  return cachedPayload;
}

function getPosts(payload) {
  return payload.posts || [];
}

function getTags(payload) {
  return payload.tags || [];
}

function getVoivodeships(payload) {
  return payload.voivodeships || [];
}

function getReadyPosts(payload) {
  return getPosts(payload).filter(post => post.ready !== false);
}

function getPostsWithGallery(payload) {
  return getReadyPosts(payload).filter(post => post.photos_count > 0);
}

function getPostsWithRoutes(payload) {
  return getReadyPosts(payload).filter(post => post.has_route);
}

module.exports = {
  fetchPayload,
  getPosts,
  getTags,
  getVoivodeships,
  getReadyPosts,
  getPostsWithGallery,
  getPostsWithRoutes,
};
