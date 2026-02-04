// Post collection dynamic loader
// Fetches posts from payload.json and renders them with lazy loading
(function() {
  'use strict';

  // Read configuration from page
  function getConfig() {
    var configEl = document.getElementById('post-collection-config');
    if (configEl) {
      try {
        return JSON.parse(configEl.textContent);
      } catch (e) {
        console.error('Failed to parse post-collection-config:', e);
      }
    }
    return { filterBy: '', filterValue: '' };
  }

  var CONFIG = getConfig();
  var FILTER_BY = CONFIG.filterBy || '';
  var FILTER_VALUE = CONFIG.filterValue || '';

  // State management
  var postsData = [];
  var renderedCount = 0;
  var PAGE_SIZE = 12;
  var observer = null;

  // Fetch and display posts
  function loadPosts() {
    var container = document.getElementById('posts-container');
    if (!container) return;

    fetch('/payload.json')
      .then(function(response) {
        if (!response.ok) {
          throw new Error('HTTP error! status: ' + response.status);
        }
        return response.json();
      })
      .then(function(data) {
        var posts = (data.posts || []).filter(function(p) {
          return p.visible && p.ready;
        });
        var tags = data.tags;

        // Filter posts by area or tag
        if (FILTER_BY && FILTER_VALUE) {
          var filterFieldMap = {
            'tag': 'tags',
            'town': 'towns',
            'county': 'counties',
            'voivodeship': 'voivodeships',
            'meso_region': 'meso_regions',
            'macro_region': 'macro_regions'
          };
          var field = filterFieldMap[FILTER_BY];
          if (field) {
            posts = posts.filter(function(p) {
              return (p[field] || []).indexOf(FILTER_VALUE) !== -1;
            });
          }
        }

        // Sort by date (descending, newest first)
        posts.sort(function(a, b) {
          return new Date(b.time) - new Date(a.time);
        });

        postsData = posts;
        container.innerHTML = '';
        setupLazyRender(postsData, tags);
      })
      .catch(function(error) {
        console.error('Error loading posts:', error);
        container.innerHTML = '<div class="error-state">Błąd wczytywania wpisów</div>';
      });
  }

  function setupLazyRender(postsArr, tags) {
    var container = document.getElementById('posts-container');
    var grid = document.createElement('div');
    grid.className = 'posts-grid';
    container.appendChild(grid);

    renderedCount = 0;
    renderBatch(postsArr, grid, PAGE_SIZE, tags);
    setupScrollObserver(postsArr, grid, tags);
  }

  function setupScrollObserver(postsArr, grid, tags) {
    var sentinel = document.createElement('div');
    sentinel.id = 'scroll-sentinel';
    sentinel.style.height = '1px';
    grid.appendChild(sentinel);

    if (observer) observer.disconnect();

    observer = new window.IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting && renderedCount < postsArr.length) {
          renderBatch(postsArr, grid, PAGE_SIZE, tags);
        }
      });
    }, { rootMargin: '700px' });

    observer.observe(sentinel);
  }

  function renderBatch(postsArr, grid, batchSize, tags) {
    var nextIdx = Math.min(renderedCount + batchSize, postsArr.length);
    var sentinel = document.getElementById('scroll-sentinel');

    for (var i = renderedCount; i < nextIdx; i++) {
      var card = createPostCard(postsArr[i], tags, i);
      grid.insertBefore(card, sentinel);
    }
    renderedCount = nextIdx;
  }

  function createPostCard(post, tags, index) {
    var card = document.createElement('article');
    card.className = 'post-card';

    var statsHtml = renderStats(post);
    var tagsHtml = renderTags(post.tags || [], tags);
    var subtitleHtml = post.subtitle
      ? '<p class="post-subtitle">' + escapeHtml(post.subtitle) + '</p>'
      : '';

    card.innerHTML =
      '<div class="post-image-container" data-post-index="' + index + '">' +
        '<img src="' + post.card_image_url + '" alt="' + escapeHtml(post.title) + '" class="post-image" loading="lazy">' +
      '</div>' +
      '<div class="post-overlay">' +
        '<h2 class="post-title">' +
          '<a href="' + post.url + '">' + escapeHtml(post.title) + '</a>' +
        '</h2>' +
        subtitleHtml +
      '</div>' +
      '<div class="post-overlay-bottom">' +
        statsHtml +
        '<div class="post-tags">' + tagsHtml + '</div>' +
      '</div>' +
      '<div class="post-overlay-top-corner">' +
        '<div class="post-date">' + escapeHtml(post.date) + '</div>' +
      '</div>';

    return card;
  }

  function renderStats(post) {
    var stats = [];

    if (post.distace && post.distace > 0) {
      stats.push(
        '<div class="stat-item">' +
          '<span class="icon-distance"></span>' +
          '<span>' + post.distace + ' km</span>' +
        '</div>'
      );
    }

    if (post.time_spent && post.time_spent > 0) {
      stats.push(
        '<div class="stat-item">' +
          '<span class="icon-time"></span>' +
          '<span>' + post.time_spent + 'h</span>' +
        '</div>'
      );
    }

    return stats.length > 0
      ? '<div class="post-stats">' + stats.join('') + '</div>'
      : '';
  }

  function renderTags(postTags, tags) {
    return postTags.map(function(tag) {
      var tagObj = tags.find(function(t) { return t.slug === tag; });
      if (tagObj) {
        var tagClass = 'tag tag-' + tag.toLowerCase();
        return '<a href="' + tagObj.url + '" class="' + tagClass + '">' + escapeHtml(tagObj.name) + '</a>';
      }
      return '';
    }).join('');
  }

  function escapeHtml(text) {
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadPosts);
  } else {
    loadPosts();
  }
})();
