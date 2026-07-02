// Post collection dynamic loader
// Fetches posts from homepage.json (minimal payload), filters by tag/area,
// and renders an editorial masthead + a lazy-loaded card grid.
(function() {
  'use strict';

  // --- Configuration -------------------------------------------------------

  // Read the render config the page shell embeds as JSON (filter dimension +
  // value, e.g. {filterBy:"tag", filterValue:"bicycle"}).
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

  var FILTER_BY = '';
  var FILTER_VALUE = '';

  // Maps the filter dimension to the post field holding its slug list, plus
  // the Polish eyebrow label shown above the page title.
  var FILTER_FIELD_MAP = {
    tag: 'tags',
    town: 'town_slugs',
    county: 'county_slugs',
    voivodeship: 'voivodeship_slugs',
    meso_region: 'meso_region_slugs',
    macro_region: 'macro_region_slugs'
  };

  var EYEBROW_MAP = {
    tag: 'Wpisy z tagiem',
    town: 'Wpisy z gminy',
    county: 'Wpisy z powiatu',
    voivodeship: 'Wpisy z województwa',
    meso_region: 'Wpisy z mezoregionu',
    macro_region: 'Wpisy z makroregionu'
  };

  // --- State ---------------------------------------------------------------

  var postsData = [];
  var renderedCount = 0;
  var PAGE_SIZE = 12;
  var observer = null;

  // --- Load ----------------------------------------------------------------

  function loadPosts() {
    var container = document.getElementById('posts-container');
    if (!container) return;

    var CONFIG = getConfig();
    FILTER_BY = CONFIG.filterBy || '';
    FILTER_VALUE = CONFIG.filterValue || '';

    fetch('/jsons/homepage.json')
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

        // homepage.json ships tags as an array of {slug, url, name}; index by
        // slug so renderTags can resolve each post's tags to links.
        var tags = {};
        (data.tags || []).forEach(function(t) { tags[t.slug] = t; });

        // Filter by the configured dimension (tag / area).
        if (FILTER_BY && FILTER_VALUE) {
          var field = FILTER_FIELD_MAP[FILTER_BY];
          if (field) {
            posts = posts.filter(function(p) {
              return (p[field] || []).indexOf(FILTER_VALUE) !== -1;
            });
          }
        }

        // Newest first.
        posts.sort(function(a, b) {
          return new Date(b.time) - new Date(a.time);
        });

        postsData = posts;
        container.innerHTML = '';
        renderHeader(container, posts);

        if (posts.length === 0) {
          renderEmpty(container);
          return;
        }
        setupLazyRender(container, posts, tags);
      })
      .catch(function(error) {
        console.error('Error loading posts:', error);
        container.innerHTML = '<div class="error-state">Błąd wczytywania wpisów</div>';
      });
  }

  // --- Header --------------------------------------------------------------

  // Derives the display name from the document title, which the server
  // already localises (e.g. "Wpisy: Rowerem - OdkrywajacPolske.pl").
  function collectionTitle() {
    var raw = (document.title || '').split(' - ')[0].trim();
    return raw.replace(/^Wpisy:\s*/i, '').trim() || 'Wpisy';
  }

  // Polish pluralization for a count noun (nominative / few / many forms).
  function plPlural(n, one, few, many) {
    var mod10 = n % 10;
    var mod100 = n % 100;
    if (n === 1) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  // Groups digits with a thin space, matching Polish number formatting
  // (e.g. 1240 -> "1 240").
  function formatNumber(n) {
    return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  }

  function renderHeader(container, posts) {
    var count = posts.length;

    // Aggregate distance (km) and photo count across the filtered set.
    var totalDistance = 0;
    var totalPhotos = 0;
    posts.forEach(function(p) {
      if (p.distance_km > 0) totalDistance += p.distance_km;
      if (p.photos && p.photos.length) totalPhotos += p.photos.length;
      else if (p.photos_count > 0) totalPhotos += p.photos_count;
    });

    var metaParts = [];
    metaParts.push(
      '<span><strong>' + count + '</strong> ' +
      plPlural(count, 'wpis', 'wpisy', 'wpisów') + '</span>'
    );
    if (totalDistance > 0) {
      metaParts.push(
        '<span><strong>' + formatNumber(totalDistance) + '</strong> km</span>'
      );
    }
    if (totalPhotos > 0) {
      metaParts.push(
        '<span><strong>' + formatNumber(totalPhotos) + '</strong> ' +
        plPlural(totalPhotos, 'zdjęcie', 'zdjęcia', 'zdjęć') + '</span>'
      );
    }

    var eyebrow = EYEBROW_MAP[FILTER_BY] || 'Wpisy';

    var header = document.createElement('header');
    header.className = 'pc-header';
    header.innerHTML =
      '<p class="pc-header__eyebrow">' + escapeHtml(eyebrow) + '</p>' +
      '<h1 class="pc-header__title">' + escapeHtml(collectionTitle()) + '</h1>' +
      '<div class="pc-header__rule"></div>' +
      '<div class="pc-header__meta">' + metaParts.join('') + '</div>';
    container.appendChild(header);
  }

  function renderEmpty(container) {
    var empty = document.createElement('div');
    empty.className = 'pc-empty';
    empty.innerHTML =
      '<p class="pc-empty__title">Brak wpisów</p>' +
      '<p>Nie ma jeszcze wpisów w tej kategorii.</p>';
    container.appendChild(empty);
  }

  // --- Grid + lazy render --------------------------------------------------

  function setupLazyRender(container, postsArr, tags) {
    var grid = document.createElement('div');
    grid.className = 'pc-grid';
    container.appendChild(grid);

    renderedCount = 0;
    renderBatch(postsArr, grid, PAGE_SIZE, tags);
    setupScrollObserver(postsArr, grid, tags);
  }

  function setupScrollObserver(postsArr, grid, tags) {
    var sentinel = document.createElement('div');
    sentinel.id = 'scroll-sentinel';
    sentinel.style.height = '1px';
    sentinel.style.gridColumn = '1 / -1';
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
      var card = createPostCard(postsArr[i], tags);
      grid.insertBefore(card, sentinel);
    }
    renderedCount = nextIdx;
  }

  // --- Card ----------------------------------------------------------------

  function createPostCard(post, tags) {
    var card = document.createElement('article');
    card.className = 'pc-card';

    var statsHtml = renderStats(post);
    var tagsHtml = renderTags(post.tags || [], tags);
    var subtitleHtml = post.subtitle
      ? '<p class="pc-card__subtitle">' + escapeHtml(post.subtitle) + '</p>'
      : '';
    var footerHtml = (statsHtml || tagsHtml)
      ? '<div class="pc-card__footer">' + statsHtml +
        '<div class="post-tags">' + tagsHtml + '</div></div>'
      : '';

    card.innerHTML =
      '<div class="pc-card__media">' + pictureHtml(post) + '</div>' +
      '<div class="pc-card__scrim"></div>' +
      '<a class="pc-card__hitbox" href="' + post.url + '" ' +
        'aria-label="' + escapeHtml(post.title) + '"></a>' +
      '<div class="pc-card__date">' + escapeHtml(formatDate(post.date)) + '</div>' +
      '<div class="pc-card__body">' +
        '<h2 class="pc-card__title">' + escapeHtml(post.title) + '</h2>' +
        subtitleHtml +
        footerHtml +
      '</div>';

    return card;
  }

  // Builds a <picture> that prefers AVIF and falls back to the JPEG card image.
  function pictureHtml(post) {
    var avif = post.card_image_url_avif
      ? '<source type="image/avif" srcset="' + post.card_image_url_avif + '">'
      : '';
    return '<picture>' + avif +
      '<img src="' + post.card_image_url + '" ' +
      'alt="' + escapeHtml(post.title) + '" loading="lazy" decoding="async">' +
      '</picture>';
  }

  // Formats an ISO date (YYYY-MM-DD) as a Polish long date, e.g. "18 lipca 2021".
  var PL_MONTHS = ['stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
    'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'];

  function formatDate(dateStr) {
    if (!dateStr) return '';
    var parts = dateStr.split('-');
    if (parts.length !== 3) return dateStr;
    var day = parseInt(parts[2], 10);
    var monthIdx = parseInt(parts[1], 10) - 1;
    if (isNaN(day) || monthIdx < 0 || monthIdx > 11) return dateStr;
    return day + ' ' + PL_MONTHS[monthIdx] + ' ' + parts[0];
  }

  function renderStats(post) {
    var stats = [];

    // distance_km is the canonical field in homepage.json.
    if (post.distance_km && post.distance_km > 0) {
      stats.push(statChip('📍', Math.round(post.distance_km) + ' km'));
    }
    if (post.time_spent && post.time_spent > 0) {
      stats.push(statChip('⏱️', post.time_spent + ' h'));
    }

    return stats.join('');
  }

  function statChip(icon, text) {
    return '<span class="pc-stat">' +
      '<span class="pc-stat__icon">' + icon + '</span>' +
      '<span>' + escapeHtml(text) + '</span>' +
    '</span>';
  }

  // Tags that are internal flags rather than reader-facing categories.
  var HIDDEN_TAGS = { main: true };

  // Renders tag links for a card. `tags` maps slug -> {url, name}.
  function renderTags(postTags, tags) {
    return postTags.map(function(tag) {
      if (HIDDEN_TAGS[tag]) return '';
      var tagObj = tags[tag];
      if (tagObj) {
        var tagClass = 'tag tag-' + tag.toLowerCase();
        return '<a href="' + tagObj.url + '" class="' + tagClass + '">' +
          escapeHtml(tagObj.name) + '</a>';
      }
      return '';
    }).join('');
  }

  function escapeHtml(text) {
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // --- Init ----------------------------------------------------------------

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadPosts);
  } else {
    loadPosts();
  }
})();
