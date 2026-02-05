// Homepage dynamic content
// Fetches data from /jsons/homepage.json and uses fuzzy logic to select:
// - Hero image (seasonal, time-of-day aware)
// - Posts grid (mixed: seasonal featured, latest, throwback)
// - Category chips (fixed + dynamic rotating)
(function() {
  'use strict';

  // ============================================
  // Configuration
  // ============================================

  var CONFIG = {
    jsonUrl: '/jsons/homepage.json',
    postsToShow: 5,
    dynamicChipsCount: 4,
    randomnessFactor: 0.5,
    seasonWindowMonths: 1
  };

  var FIXED_CHIPS = [
    { name: 'Rowerem', slug: 'bicycle', icon: 'bike' },
    { name: 'Pieszo', slug: 'hike', icon: 'hike' },
    { name: 'Kolejowe', slug: 'train', icon: 'train' }
  ];

  var DISCOVERY_TAGS = ['air', 'bikepacking', 'birds', 'countryside', 'mountains', 'coast'];

  // ============================================
  // Fuzzy Logic Selection Functions
  // ============================================

  function getCurrentMonth() {
    return new Date().getMonth() + 1;
  }

  function getCurrentHour() {
    return new Date().getHours();
  }

  function getPostMonth(post) {
    return new Date(post.time).getMonth() + 1;
  }

  function isSeasonalMatch(postMonth, currentMonth, window) {
    var diff = Math.abs(postMonth - currentMonth);
    if (diff > 6) diff = 12 - diff;
    return diff <= window;
  }

  function weightedRandomSelect(items, weights) {
    var totalWeight = weights.reduce(function(sum, w) { return sum + w; }, 0);
    var random = Math.random() * totalWeight;
    var cumulative = 0;

    for (var i = 0; i < items.length; i++) {
      cumulative += weights[i];
      if (random <= cumulative) return items[i];
    }
    return items[items.length - 1];
  }

  function shuffleArray(array) {
    var result = array.slice();
    for (var i = result.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  // Check if post tags array (objects with slug) contains a specific slug
  function hasTagSlug(tags, slug) {
    if (!tags || !Array.isArray(tags)) return false;
    return tags.some(function(t) { return t.slug === slug; });
  }

  // Find tag object by slug in post tags array
  function findTagBySlug(tags, slug) {
    if (!tags || !Array.isArray(tags)) return null;
    return tags.find(function(t) { return t.slug === slug; });
  }

  function selectHeroPost(posts) {
    var currentMonth = getCurrentMonth();
    var currentHour = getCurrentHour();
    var eligiblePosts = posts.filter(function(p) {
      return p.visible && p.ready && p.tags && p.tags.length > 0 && p.photos && p.photos.length > 0;
    });

    if (eligiblePosts.length === 0) return posts[0];

    var scored = eligiblePosts.map(function(post) {
      var score = 1.0;
      var postMonth = getPostMonth(post);

      if (isSeasonalMatch(postMonth, currentMonth, CONFIG.seasonWindowMonths)) {
        score += 2.0;
      }

      if (hasTagSlug(post.tags, 'best') || hasTagSlug(post.tags, 'najlepsze')) {
        score += 1.5;
      }

      if ((currentHour >= 5 && currentHour <= 10) || (currentHour >= 16 && currentHour <= 20)) {
        score += Math.random() * 0.5;
      }

      var postYear = new Date(post.time).getFullYear();
      var yearDiff = new Date().getFullYear() - postYear;
      if (yearDiff <= 1) score += 0.5;
      else if (yearDiff <= 3) score += 0.25;

      score += Math.random() * CONFIG.randomnessFactor * 2;

      return { post: post, score: score };
    });

    scored.sort(function(a, b) { return b.score - a.score; });

    var topCandidates = scored.slice(0, Math.min(5, scored.length));
    var weights = topCandidates.map(function(s) { return s.score; });

    return weightedRandomSelect(
      topCandidates.map(function(s) { return s.post; }),
      weights
    );
  }

  // Select a random photo from the post's photos array
  // Uses weighted selection favoring higher-scored photos
  function selectHeroPhoto(post) {
    if (!post.photos || post.photos.length === 0) {
      return { src: post.card_image_url, alt: post.title };
    }

    // Weight by points (higher points = more likely to be selected)
    var photos = post.photos;
    var weights = photos.map(function(p) {
      return Math.max(1, p.points + 1); // Add 1 to avoid zero weights
    });

    return weightedRandomSelect(photos, weights);
  }

  function selectPosts(posts, heroPost) {
    var currentMonth = getCurrentMonth();
    var currentYear = new Date().getFullYear();
    var eligiblePosts = posts.filter(function(p) {
      return p.visible && p.ready && p !== heroPost;
    });

    if (eligiblePosts.length === 0) return [];

    var selected = [];
    var used = {};

    function usePost(post) {
      if (post && !used[post.url]) {
        selected.push(post);
        used[post.url] = true;
        return true;
      }
      return false;
    }

    var byDate = eligiblePosts.slice().sort(function(a, b) {
      return new Date(b.time) - new Date(a.time);
    });

    var seasonal = shuffleArray(eligiblePosts.filter(function(p) {
      return isSeasonalMatch(getPostMonth(p), currentMonth, CONFIG.seasonWindowMonths);
    }));

    var throwback = shuffleArray(eligiblePosts.filter(function(p) {
      var postYear = new Date(p.time).getFullYear();
      return isSeasonalMatch(getPostMonth(p), currentMonth, CONFIG.seasonWindowMonths) &&
             postYear < currentYear - 1;
    }));

    // Latest (2 posts)
    for (var i = 0; i < byDate.length && selected.length < 2; i++) {
      usePost(byDate[i]);
    }

    // Seasonal (1 post)
    for (var j = 0; j < seasonal.length && selected.length < 3; j++) {
      usePost(seasonal[j]);
    }

    // Throwback (1 post)
    for (var k = 0; k < throwback.length && selected.length < 4; k++) {
      usePost(throwback[k]);
    }

    // Fill remaining
    var remaining = shuffleArray(eligiblePosts.filter(function(p) {
      return !used[p.url];
    }));
    for (var l = 0; l < remaining.length && selected.length < CONFIG.postsToShow - 1; l++) {
      usePost(remaining[l]);
    }

    return selected;
  }

  function selectCategoryChips(posts, tags, mesoRegions) {
    var chips = [];
    var usedSlugs = {};

    // Add fixed chips - use tag_post_list_url pattern from JSON
    FIXED_CHIPS.forEach(function(chip) {
      var tag = tags.find(function(t) { return t.slug === chip.slug; });
      if (tag) {
        chips.push({ name: chip.name, url: tag.url, icon: chip.icon });
        usedSlugs[chip.slug] = true;
      }
    });

    // Count posts per meso_region (using meso_region_slugs field)
    var regionCounts = {};
    posts.forEach(function(post) {
      (post.meso_region_slugs || []).forEach(function(regionSlug) {
        regionCounts[regionSlug] = (regionCounts[regionSlug] || 0) + 1;
      });
    });

    // Mid-tier regions (2-5 posts)
    var midTierRegions = shuffleArray(Object.keys(regionCounts).filter(function(r) {
      var count = regionCounts[r];
      return count >= 2 && count <= 5;
    }));

    // Add 1-2 region chips (lookup name/url from meso_regions table)
    for (var i = 0; i < midTierRegions.length && chips.length < FIXED_CHIPS.length + 2; i++) {
      var regionSlug = midTierRegions[i];
      var region = mesoRegions.find(function(r) { return r.slug === regionSlug; });
      if (region) {
        chips.push({
          name: region.name,
          url: region.url,
          icon: null
        });
      }
    }

    // Add discovery tags
    var availableDiscovery = shuffleArray(DISCOVERY_TAGS.filter(function(slug) {
      return tags.some(function(t) { return t.slug === slug; }) && !usedSlugs[slug];
    }));

    for (var j = 0; j < availableDiscovery.length && chips.length < FIXED_CHIPS.length + CONFIG.dynamicChipsCount; j++) {
      var tag = tags.find(function(t) { return t.slug === availableDiscovery[j]; });
      if (tag) {
        chips.push({ name: tag.name, url: tag.url, icon: null });
        usedSlugs[tag.slug] = true;
      }
    }

    // Add map chip
    chips.push({ name: 'Mapa', url: '/mapa.html', icon: 'map' });

    return chips;
  }

  // ============================================
  // Helper Functions
  // ============================================

  function formatDatePolish(timeStr) {
    var months = ['', 'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
                  'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'];
    var date = new Date(timeStr);
    return date.getDate() + ' ' + months[date.getMonth() + 1] + ' ' + date.getFullYear();
  }

  // Get primary tag name from post's tags array (objects with slug, name)
  function getPrimaryTagName(postTags) {
    if (!postTags || postTags.length === 0) return 'Wpis';

    var priority = ['best', 'najlepsze', 'bicycle', 'hike', 'train'];
    for (var i = 0; i < priority.length; i++) {
      var tag = findTagBySlug(postTags, priority[i]);
      if (tag) return tag.name;
    }

    // Return first tag's name
    return postTags[0].name || 'Wpis';
  }

  function escapeHtml(text) {
    if (!text) return '';
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // ============================================
  // SVG Icons
  // ============================================

  function getIconSvg(name) {
    var icons = {
      bike: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M15 6a1 1 0 100-2 1 1 0 000 2zM12 17.5V14l-3-3 4-3 2 3h2"/></svg>',
      hike: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M13.5 5.5a2 2 0 100-4 2 2 0 000 4zM6 20l3-7 2.5 2V20M9.5 11l3-2 2 3-4 3M14 4l5 4-2 1"/></svg>',
      train: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><rect x="4" y="3" width="16" height="14" rx="2"/><path d="M4 11h16M9 21l3-4 3 4M12 3v4"/></svg>',
      map: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l5.447 2.724A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/></svg>',
      distance: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/></svg>',
      time: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'
    };
    return icons[name] || '';
  }

  // ============================================
  // DOM Element Creation
  // ============================================

  function createPostCardElement(post, isFeatured) {
    var card = document.createElement('a');
    card.href = post.url;
    card.className = 'post-card' + (isFeatured ? ' post-featured' : '');

    var primaryTag = getPrimaryTagName(post.tags);
    var distanceText = post.distance_km ? post.distance_km + ' km' : '';
    var timeText = post.time_spent ? post.time_spent + 'h' : '';

    var statsHtml = '';
    if (distanceText || timeText) {
      statsHtml = '<div class="post-card-stats">';
      if (distanceText) {
        statsHtml += '<span class="post-card-stat">' + getIconSvg('distance') + distanceText + '</span>';
      }
      if (timeText) {
        statsHtml += '<span class="post-card-stat">' + getIconSvg('time') + timeText + '</span>';
      }
      statsHtml += '</div>';
    }

    card.innerHTML =
      '<div class="post-card-image">' +
        '<img src="' + escapeHtml(post.card_image_url) + '" alt="' + escapeHtml(post.title) + '" loading="lazy">' +
      '</div>' +
      '<div class="post-card-content">' +
        '<div class="post-card-meta">' +
          '<span class="post-card-date">' + formatDatePolish(post.time) + '</span>' +
          '<span class="post-card-tag">' + escapeHtml(primaryTag) + '</span>' +
        '</div>' +
        '<h3 class="post-card-title">' + escapeHtml(post.title) + '</h3>' +
        '<p class="post-card-subtitle">' + escapeHtml(post.subtitle || '') + '</p>' +
        statsHtml +
      '</div>';

    return card;
  }

  function createChipElement(chip) {
    var el = document.createElement('a');
    el.href = chip.url;
    el.className = 'category-chip';
    el.innerHTML = (chip.icon ? getIconSvg(chip.icon) : '') + escapeHtml(chip.name);
    return el;
  }

  // ============================================
  // Initialization
  // ============================================

  function init() {
    fetch(CONFIG.jsonUrl)
      .then(function(response) {
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.json();
      })
      .then(function(json) {
        var posts = (json.posts || []).filter(function(p) {
          return p.visible && p.ready;
        });
        var tags = json.tags || [];
        var mesoRegions = json.meso_regions || [];

        if (posts.length === 0) {
          console.warn('No posts available');
          return;
        }

        // Select content using fuzzy logic
        var heroPost = selectHeroPost(posts);
        var gridPosts = selectPosts(posts, heroPost);
        var chips = selectCategoryChips(posts, tags, mesoRegions);

        // Update hero image - select random photo from post's photos
        var heroLink = document.querySelector('.hero-image');
        if (heroLink && heroPost) {
          var heroPhoto = selectHeroPhoto(heroPost);

          heroLink.href = heroPost.url;
          var heroImg = heroLink.querySelector('img');
          if (heroImg) {
            heroImg.src = heroPhoto.src;
            heroImg.alt = heroPhoto.alt || heroPost.title;
            heroImg.style.display = '';
          }
          var heroTitle = heroLink.querySelector('.hero-image-caption h3');
          if (heroTitle) heroTitle.textContent = heroPost.title;
          var heroSubtitle = heroLink.querySelector('.hero-image-caption p');
          if (heroSubtitle) heroSubtitle.textContent = heroPost.subtitle || '';

          // Remove loading state
          heroLink.classList.remove('hero-loading');
        }

        // Render posts grid - clear and populate
        var postsContainer = document.querySelector('.posts-grid');
        if (postsContainer) {
          postsContainer.innerHTML = '';
          gridPosts.forEach(function(post, index) {
            var card = createPostCardElement(post, index === 0);
            postsContainer.appendChild(card);
          });
        }

        // Render category chips - clear and populate
        var chipsContainer = document.querySelector('.categories');
        if (chipsContainer) {
          chipsContainer.innerHTML = '';
          chips.forEach(function(chip) {
            var chipEl = createChipElement(chip);
            chipsContainer.appendChild(chipEl);
          });
        }
      })
      .catch(function(error) {
        console.error('Error loading homepage data:', error);
      });
  }

  // Run when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
