// Photo Timeline - Horizontal scrolling photo grid by date
// Displays photos organized by day-of-year with lazy loading and modal viewer
(function() {
  'use strict';

  // =======================================================
  // CONFIGURATION - Edit these values to customize the grid
  // =======================================================
  var CONFIG = {
    // Grid layout (visible rows/columns on screen)
    COLUMNS_DESKTOP: 8,
    ROWS_DESKTOP: 5,
    COLUMNS_TABLET: 5,
    ROWS_TABLET: 4,
    COLUMNS_MOBILE: 3,
    ROWS_MOBILE: 3,

    // How many days each column represents
    DAYS_PER_COLUMN: 5,

    // Shuffle photos on each page load
    ENABLE_SHUFFLE: true,

    // Random seed: null = different each time
    RANDOM_SEED: null,

    // Data source URL
    PHOTOS_URL: '/photos.json',

    // Tag weights for prioritizing photos
    TAG_WEIGHTS: {
      'best': 12,
      'good': 4,
      'timeline': 3,
      'mountains': 3,
      'winter': 4,
      'spring': 3,
      'summer': 3,
      'autumn': 3,
      'night': 5,
      'sunrise': 7,
      'sunset': 6,
      'city': 2,
      'nature': 3,
      'landscape': 4,
      'animal': 3,
      'countryside': 2
    }
  };

  // ===== STATE =====
  var allPhotos = [];
  var timelinePhotos = [];
  var fallbackPhotos = [];
  var gridPhotos = [];
  var usedPhotoIds = new Set();
  var currentModalIndex = -1;
  var isScrolling = false;
  var touchStartY = 0;

  var gridStats = {
    totalSlots: 0,
    filledSlots: 0,
    timelinePhotosUsed: 0,
    fallbackPhotosUsed: 0,
    emptySlots: 0,
    totalColumns: 0,
    rows: 0
  };

  var columnStats = [];
  var modalMap = null;
  var modalMarker = null;
  var currentPhotoCoords = null;

  // ===== UTILITY FUNCTIONS =====
  var randomSeed = CONFIG.RANDOM_SEED || Date.now();

  function seededRandom(seed) {
    var x = Math.sin(seed++) * 10000;
    return x - Math.floor(x);
  }

  function random() {
    if (CONFIG.ENABLE_SHUFFLE) {
      randomSeed++;
      return seededRandom(randomSeed);
    }
    return Math.random();
  }

  function getDayOfYear(dateStr) {
    var date = new Date(dateStr);
    var month = date.getMonth();
    var day = date.getDate();
    var daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var dayOfYear = day;
    for (var i = 0; i < month; i++) {
      dayOfYear += daysInMonth[i];
    }
    return dayOfYear;
  }

  function dayOfYearToDate(dayOfYear) {
    var daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var remaining = dayOfYear;
    var month = 0;

    while (remaining > daysInMonth[month]) {
      remaining -= daysInMonth[month];
      month++;
    }

    var mm = String(month + 1).padStart(2, '0');
    var dd = String(remaining).padStart(2, '0');
    return mm + '-' + dd;
  }

  function calculatePhotoWeight(photo) {
    var weight = 0;
    if (photo.tags && Array.isArray(photo.tags)) {
      photo.tags.forEach(function(tag) {
        weight += CONFIG.TAG_WEIGHTS[tag.toLowerCase()] || 1;
      });
    }
    return weight;
  }

  function formatExposure(exposure) {
    if (!exposure) return null;
    if (exposure >= 1) return exposure + 's';
    var denominator = Math.round(1 / exposure);
    return '1/' + denominator + 's';
  }

  // ===== THEME =====
  window.toggleTheme = function() {
    document.body.classList.toggle('light-theme');
    var icon = document.querySelector('.theme-icon');
    icon.textContent = document.body.classList.contains('light-theme') ? '🌙' : '☀️';
    localStorage.setItem('theme', document.body.classList.contains('light-theme') ? 'light' : 'dark');
  };

  function initTheme() {
    var savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'light') {
      document.body.classList.add('light-theme');
      document.querySelector('.theme-icon').textContent = '🌙';
    }
  }

  // ===== DATA LOADING =====
  function loadPhotos() {
    fetch(CONFIG.PHOTOS_URL)
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        allPhotos = data.photos || [];
        processPhotos();
      })
      .catch(function(error) {
        console.error('Error loading photos:', error);
        useSampleData();
      });
  }

  function useSampleData() {
    allPhotos = [{
      desc: "Sample Photo",
      full_url: "https://picsum.photos/1200/900?random=1",
      article_url: "https://picsum.photos/400/300?random=1",
      time: "2020-05-03T12:00:00+02:00",
      post_slug: "sample-post",
      post_url: "2020/05/03/sample.html",
      is_published: true,
      tags: ["timeline", "good"]
    }];

    var months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
    var tags = ['timeline', 'good', 'best', 'mountains', 'nature'];

    for (var i = 2; i <= 100; i++) {
      var month = months[Math.floor(Math.random() * 12)];
      var day = String(Math.floor(Math.random() * 28) + 1).padStart(2, '0');
      var photoTags = ['timeline'];

      allPhotos.push({
        desc: 'Photo ' + i,
        full_url: 'https://picsum.photos/1200/900?random=' + i,
        article_url: 'https://picsum.photos/400/300?random=' + i,
        time: '2020-' + month + '-' + day + 'T12:00:00+02:00',
        post_slug: 'post-' + i,
        post_url: '2020/' + month + '/' + day + '/post-' + i + '.html',
        is_published: true,
        tags: photoTags
      });
    }

    processPhotos();
  }

  function processPhotos() {
    allPhotos.forEach(function(photo, index) {
      photo._id = photo.full_url || 'photo_' + index;
    });

    timelinePhotos = [];
    fallbackPhotos = [];

    allPhotos.forEach(function(photo) {
      var hasTimelineTag = photo.tags &&
        Array.isArray(photo.tags) &&
        photo.tags.some(function(tag) { return tag.toLowerCase() === 'timeline'; });

      photo.dayOfYear = getDayOfYear(photo.time);
      photo.weight = calculatePhotoWeight(photo);

      if (hasTimelineTag) {
        timelinePhotos.push(photo);
      } else if (photo.tags && photo.tags.length > 0) {
        fallbackPhotos.push(photo);
      }
    });

    timelinePhotos.sort(function(a, b) {
      return a.dayOfYear - b.dayOfYear || b.weight - a.weight;
    });
    fallbackPhotos.sort(function(a, b) {
      return a.dayOfYear - b.dayOfYear || b.weight - a.weight;
    });

    buildGrid();

    var spinner = document.getElementById('loadingSpinner');
    if (spinner) spinner.style.display = 'none';
  }

  function buildGrid() {
    var gridContainer = document.getElementById('photoGrid');
    if (!gridContainer) return;
    gridContainer.innerHTML = '';

    usedPhotoIds = new Set();

    var rows;
    if (window.innerWidth <= 600) {
      rows = CONFIG.ROWS_MOBILE;
    } else if (window.innerWidth <= 1024) {
      rows = CONFIG.ROWS_TABLET;
    } else {
      rows = CONFIG.ROWS_DESKTOP;
    }

    var totalColumns = Math.ceil(366 / CONFIG.DAYS_PER_COLUMN);

    var timelineByColumn = {};
    var fallbackByColumn = {};
    for (var col = 0; col < totalColumns; col++) {
      timelineByColumn[col] = [];
      fallbackByColumn[col] = [];
    }

    timelinePhotos.forEach(function(photo) {
      var column = Math.floor((photo.dayOfYear - 1) / CONFIG.DAYS_PER_COLUMN);
      if (column >= 0 && column < totalColumns) {
        timelineByColumn[column].push(photo);
      }
    });

    fallbackPhotos.forEach(function(photo) {
      var column = Math.floor((photo.dayOfYear - 1) / CONFIG.DAYS_PER_COLUMN);
      if (column >= 0 && column < totalColumns) {
        fallbackByColumn[column].push(photo);
      }
    });

    Object.keys(timelineByColumn).forEach(function(col) {
      timelineByColumn[col].sort(function(a, b) { return b.weight - a.weight; });
      if (CONFIG.ENABLE_SHUFFLE) {
        timelineByColumn[col] = shuffleWithWeight(timelineByColumn[col]);
      }
    });

    Object.keys(fallbackByColumn).forEach(function(col) {
      fallbackByColumn[col].sort(function(a, b) { return b.weight - a.weight; });
      if (CONFIG.ENABLE_SHUFFLE) {
        fallbackByColumn[col] = shuffleWithWeight(fallbackByColumn[col]);
      }
    });

    gridPhotos = [];

    gridStats = {
      totalSlots: totalColumns * rows,
      filledSlots: 0,
      timelinePhotosUsed: 0,
      fallbackPhotosUsed: 0,
      emptySlots: 0,
      totalColumns: totalColumns,
      rows: rows
    };

    columnStats = [];

    var timelineIds = new Set(timelinePhotos.map(function(p) { return p._id; }));

    for (var col = 0; col < totalColumns; col++) {
      var colStat = {
        timelineAvailable: timelineByColumn[col].length,
        timelineUsed: 0,
        fallbackUsed: 0,
        empty: 0,
        slots: rows
      };

      for (var row = 0; row < rows; row++) {
        var photo = null;

        photo = getUnusedPhoto(timelineByColumn[col]);
        if (!photo) photo = borrowUnusedPhoto(timelineByColumn, col, totalColumns);
        if (!photo) photo = getUnusedPhoto(fallbackByColumn[col]);
        if (!photo) photo = borrowUnusedPhoto(fallbackByColumn, col, totalColumns);

        if (photo) {
          usedPhotoIds.add(photo._id);
          var cell = createPhotoCell(photo, gridPhotos.length);
          gridContainer.appendChild(cell);
          gridPhotos.push(photo);

          gridStats.filledSlots++;
          if (timelineIds.has(photo._id)) {
            gridStats.timelinePhotosUsed++;
            colStat.timelineUsed++;
          } else {
            gridStats.fallbackPhotosUsed++;
            colStat.fallbackUsed++;
          }
        } else {
          var emptyCell = document.createElement('div');
          emptyCell.className = 'photo-cell';
          emptyCell.style.background = 'var(--bg-tertiary)';
          gridContainer.appendChild(emptyCell);
          gridPhotos.push(null);
          gridStats.emptySlots++;
          colStat.empty++;
        }
      }

      columnStats.push(colStat);
    }

    setupScrollSync();
  }

  function getUnusedPhoto(photos) {
    if (!photos) return null;
    for (var i = 0; i < photos.length; i++) {
      if (!usedPhotoIds.has(photos[i]._id)) {
        return photos[i];
      }
    }
    return null;
  }

  function borrowUnusedPhoto(photosByColumn, targetCol, totalColumns) {
    var MAX_BORROW_DISTANCE = 2;
    for (var offset = 1; offset <= MAX_BORROW_DISTANCE; offset++) {
      var leftCol = targetCol - offset;
      var rightCol = targetCol + offset;

      if (leftCol >= 0) {
        var photo = getUnusedPhoto(photosByColumn[leftCol]);
        if (photo) return photo;
      }
      if (rightCol < totalColumns) {
        var photo = getUnusedPhoto(photosByColumn[rightCol]);
        if (photo) return photo;
      }
    }
    return null;
  }

  function shuffleWithWeight(photos) {
    return photos.map(function(photo, index) {
      return { photo: photo, sortKey: index + random() * 2 };
    })
    .sort(function(a, b) { return a.sortKey - b.sortKey; })
    .map(function(item) { return item.photo; });
  }

  function createPhotoCell(photo, index) {
    var cell = document.createElement('div');
    cell.className = 'photo-cell';
    cell.onclick = function() { openModal(index); };

    var img = document.createElement('img');
    img.className = 'loading';
    img.alt = photo.desc || '';
    img.loading = 'lazy';
    img.onload = function() { img.classList.remove('loading'); };
    img.src = photo.article_url || photo.full_url;

    var overlay = document.createElement('div');
    overlay.className = 'photo-date-overlay';
    overlay.textContent = dayOfYearToDate(photo.dayOfYear);

    cell.appendChild(img);
    cell.appendChild(overlay);

    return cell;
  }

  // ===== SCROLL & SLIDER SYNC =====
  function setupScrollSync() {
    var gridContainer = document.getElementById('gridContainer');
    var slider = document.getElementById('daySlider');
    if (!gridContainer || !slider) return;

    var scrollRafId = null;
    gridContainer.addEventListener('scroll', function() {
      if (isScrolling) return;
      if (scrollRafId) return;
      scrollRafId = requestAnimationFrame(function() {
        scrollRafId = null;
        var scrollPercent = gridContainer.scrollLeft / (gridContainer.scrollWidth - gridContainer.clientWidth);
        var day = Math.round(scrollPercent * 365) + 1;
        slider.value = day;
        updateDateDisplay(day);
        updateVisibleColumnsStats();
      });
    });

    slider.addEventListener('input', function(e) {
      var day = parseInt(e.target.value);
      updateDateDisplay(day);
      scrollToDay(day);
    });

    updateDateDisplay(1);
    updateVisibleColumnsStats();
  }

  function updateDateDisplay(day) {
    var el = document.getElementById('currentDate');
    if (el) el.textContent = dayOfYearToDate(day);
  }

  function updateVisibleColumnsStats() {
    var statsEl = document.getElementById('photoStats');
    var gridContainer = document.getElementById('gridContainer');
    if (!statsEl || !gridContainer || columnStats.length === 0) return;

    var scrollLeft = gridContainer.scrollLeft;
    var viewportWidth = gridContainer.clientWidth;
    var centerX = scrollLeft + viewportWidth / 2;

    var firstCell = document.querySelector('.photo-cell');
    if (!firstCell) return;

    var cellWidth = firstCell.offsetWidth + 1;
    var centerColumn = Math.floor(centerX / cellWidth);

    var colIndices = [
      Math.max(0, centerColumn - 1),
      Math.min(columnStats.length - 1, centerColumn),
      Math.min(columnStats.length - 1, centerColumn + 1)
    ];

    var totalAvailable = 0;
    var totalSlots = 0;
    var fallbackUsed = 0;

    var uniqueCols = [];
    colIndices.forEach(function(idx) {
      if (uniqueCols.indexOf(idx) === -1) uniqueCols.push(idx);
    });

    uniqueCols.forEach(function(colIdx) {
      if (columnStats[colIdx]) {
        totalAvailable += columnStats[colIdx].timelineAvailable;
        totalSlots += columnStats[colIdx].slots;
        fallbackUsed += columnStats[colIdx].fallbackUsed;
      }
    });

    var startDay = uniqueCols[0] * CONFIG.DAYS_PER_COLUMN + 1;
    var endDay = Math.min(366, (uniqueCols[uniqueCols.length - 1] + 1) * CONFIG.DAYS_PER_COLUMN);
    var dateRange = dayOfYearToDate(startDay) + '-' + dayOfYearToDate(endDay);

    var statsText = dateRange + ': ' + totalAvailable + ' / ' + totalSlots;
    if (fallbackUsed > 0) statsText += ' (+' + fallbackUsed + ')';
    if (totalAvailable >= totalSlots) {
      statsText += ' ✓';
    } else {
      statsText += ' ⚠';
    }

    statsEl.textContent = statsText;
  }

  function scrollToDay(day) {
    var gridContainer = document.getElementById('gridContainer');
    if (!gridContainer) return;

    var scrollPercent = (day - 1) / 365;
    var targetScroll = scrollPercent * (gridContainer.scrollWidth - gridContainer.clientWidth);

    isScrolling = true;
    gridContainer.scrollTo({ left: targetScroll, behavior: 'smooth' });

    setTimeout(function() {
      isScrolling = false;
      updateVisibleColumnsStats();
    }, 500);
  }

  // ===== MODAL =====
  function openModal(index) {
    var photo = gridPhotos[index];
    if (!photo) return;

    currentModalIndex = index;
    var modal = document.getElementById('modalOverlay');
    var modalImage = document.getElementById('modalImage');
    var modalDate = document.getElementById('modalDate');
    var modalDesc = document.getElementById('modalDesc');
    var modalLink = document.getElementById('modalLink');
    var modalExif = document.getElementById('modalExif');
    var modalMapContainer = document.getElementById('modalMapContainer');

    modalImage.src = photo.full_url;

    var date = new Date(photo.time);
    modalDate.textContent = date.toLocaleDateString('pl-PL', {
      year: 'numeric', month: '2-digit', day: '2-digit'
    });

    modalDesc.textContent = photo.desc || '';

    if (photo.post_url) {
      modalLink.href = photo.post_url;
      modalLink.style.display = 'inline-block';
    } else {
      modalLink.style.display = 'none';
    }

    var hasCoords = photo['exif.lat'] != null && photo['exif.lon'] != null;
    if (hasCoords && modalMapContainer) {
      modalMapContainer.classList.add('visible');
      setTimeout(function() {
        initModalMap(photo['exif.lat'], photo['exif.lon']);
      }, 50);
    } else if (modalMapContainer) {
      modalMapContainer.classList.remove('visible');
    }

    var exifParts = [];
    if (photo['exif.camera_name']) exifParts.push(photo['exif.camera_name']);
    if (photo['exif.lens_name']) exifParts.push(photo['exif.lens_name']);
    if (photo['exif.aperture']) exifParts.push('f/' + photo['exif.aperture']);
    if (photo['exif.exposure']) exifParts.push(formatExposure(photo['exif.exposure']));
    if (photo['exif.iso']) exifParts.push('ISO ' + photo['exif.iso']);
    if (photo['exif.focal_35mm']) exifParts.push(photo['exif.focal_35mm'] + 'mm');

    modalExif.textContent = exifParts.join(' • ');

    modal.classList.add('active');
    requestAnimationFrame(function() {
      modal.classList.add('visible');
    });

    document.body.style.overflow = 'hidden';
  }

  function initModalMap(lat, lon) {
    currentPhotoCoords = { lat: lat, lon: lon };

    var circleIcon = L.divIcon({
      className: 'custom-marker',
      iconSize: [16, 16],
      iconAnchor: [8, 8]
    });

    if (modalMap) {
      modalMap.setView([lat, lon], 14);
      if (modalMarker) {
        modalMarker.setLatLng([lat, lon]);
      } else {
        modalMarker = L.marker([lat, lon], { icon: circleIcon }).addTo(modalMap);
      }
      modalMap.invalidateSize();
    } else {
      modalMap = L.map('modalMap', {
        zoomControl: false,
        attributionControl: false,
        dragging: false,
        touchZoom: false,
        scrollWheelZoom: false,
        doubleClickZoom: false,
        boxZoom: false,
        keyboard: false
      }).setView([lat, lon], 14);

      L.tileLayer('/tiles/ump/{z}/{x}/{y}.png', {
        maxZoom: 16,
        minZoom: 6
      }).addTo(modalMap);

      modalMarker = L.marker([lat, lon], { icon: circleIcon }).addTo(modalMap);

      var mapContainer = document.getElementById('modalMapContainer');
      if (mapContainer) {
        mapContainer.addEventListener('click', openInOSM);
      }
    }
  }

  function openInOSM() {
    if (currentPhotoCoords) {
      var lat = currentPhotoCoords.lat;
      var lon = currentPhotoCoords.lon;
      var osmUrl = 'https://www.openstreetmap.org/?mlat=' + lat + '&mlon=' + lon + '#map=15/' + lat + '/' + lon;
      window.open(osmUrl, '_blank');
    }
  }

  window.closeModal = function() {
    var modal = document.getElementById('modalOverlay');
    modal.classList.remove('visible');

    setTimeout(function() {
      modal.classList.remove('active');
      document.body.style.overflow = '';
    }, 300);

    currentModalIndex = -1;
  };

  window.navigateModal = function(direction) {
    var newIndex = currentModalIndex + direction;

    while (newIndex >= 0 && newIndex < gridPhotos.length && !gridPhotos[newIndex]) {
      newIndex += direction;
    }

    if (newIndex >= 0 && newIndex < gridPhotos.length && gridPhotos[newIndex]) {
      openModal(newIndex);
    }
  };

  // ===== EVENT LISTENERS =====
  function setupEventListeners() {
    var modalOverlay = document.getElementById('modalOverlay');
    if (modalOverlay) {
      modalOverlay.addEventListener('click', function(e) {
        if (e.target === modalOverlay) {
          window.closeModal();
        }
      });

      modalOverlay.addEventListener('touchstart', function(e) {
        touchStartY = e.touches[0].clientY;
      });

      modalOverlay.addEventListener('touchmove', function(e) {
        var touchY = e.touches[0].clientY;
        var deltaY = touchY - touchStartY;
        if (deltaY > 100) {
          window.closeModal();
        }
      });
    }

    document.addEventListener('keydown', function(e) {
      if (currentModalIndex === -1) return;

      switch (e.key) {
        case 'Escape':
          window.closeModal();
          break;
        case 'ArrowLeft':
          window.navigateModal(-1);
          break;
        case 'ArrowRight':
          window.navigateModal(1);
          break;
      }
    });

    var resizeTimeout;
    window.addEventListener('resize', function() {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(function() {
        buildGrid();
      }, 250);
    });
  }

  // ===== INITIALIZATION =====
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initTheme();
      setupEventListeners();
      loadPhotos();
    });
  } else {
    initTheme();
    setupEventListeners();
    loadPhotos();
  }
})();
