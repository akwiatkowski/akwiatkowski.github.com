(function() {
  'use strict';

  var CONFIG = {
    GRID_SIZE_KM: 10,
    DAILY_DISTANCE_KM: 60,
    BASE_STATION: { lat: 52.4082, lon: 16.9254, name: 'Poznań' },
    POLAND_BOUNDS: [[49.0, 14.1], [54.8, 24.1]],
    TILE_URL: '/tiles/ump/{z}/{x}/{y}.png',
    FALLBACK_TILE_URL: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    ROUTES_SLICE: 15,
    DUPLICATE_PENALTY: 0.3
  };

  var map;
  var stations = [];
  var gridCells = new Map();
  var drawnRoutes = [];
  var stationMarkers = [];

  function initMap() {
    map = L.map('map').setView([52.0, 19.0], 7);

    var tileLayer = L.tileLayer(CONFIG.TILE_URL, {
      attribution: 'Map tiles',
      maxZoom: 16,
      minZoom: 6,
      errorTileUrl: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect fill="%23f0f0f0" width="256" height="256"/></svg>'
    });

    tileLayer.on('tileerror', function() {
      map.removeLayer(tileLayer);
      L.tileLayer(CONFIG.FALLBACK_TILE_URL).addTo(map);
    });

    tileLayer.addTo(map);

    map.setMaxBounds(CONFIG.POLAND_BOUNDS);
    map.on('drag', function() {
      map.panInsideBounds(CONFIG.POLAND_BOUNDS, { animate: false });
    });
  }

  function getCellKey(lat, lon) {
    var KM_PER_DEGREE_LAT = 111;
    var KM_PER_DEGREE_LON_BASE = 111;

    var latCellSize = CONFIG.GRID_SIZE_KM / KM_PER_DEGREE_LAT;
    var lonCellSize = CONFIG.GRID_SIZE_KM / (KM_PER_DEGREE_LON_BASE * Math.cos(lat * Math.PI / 180));

    var cellX = Math.floor(lon / lonCellSize);
    var cellY = Math.floor(lat / latCellSize);

    return cellX + ',' + cellY;
  }

  function getDistance(lat1, lon1, lat2, lon2) {
    var R = 6371;
    var dLat = (lat2 - lat1) * Math.PI / 180;
    var dLon = (lon2 - lon1) * Math.PI / 180;
    var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  async function loadData() {
    try {
      var gridRes = await fetch('/jsons/photo_grid.json');
      var gridData = await gridRes.json();

      var stationsRes = await fetch('/train_stations.json');
      var stationsData = await stationsRes.json();

      var rawStations = stationsData.train_stations || [];
      stations = rawStations.map(function(s) {
        return {
          name: s.name,
          lat: typeof s.lat === 'number' ? s.lat : parseFloat(s.lat),
          lon: typeof s.lon === 'number' ? s.lon : parseFloat(s.lon),
          time_distance: typeof s.time_distance === 'number' ? s.time_distance : 0
        };
      });

      processCoords(gridData.coords || []);
      drawGrid();
      drawStations();
      updateStats();
    } catch (error) {
      showError('Nie udało się załadować danych: ' + error.message);
    }
  }

  function processCoords(coords) {
    gridCells.clear();

    coords.forEach(function(pair) {
      var lat = pair[0];
      var lon = pair[1];
      if (lat != null && lon != null) {
        var key = getCellKey(lat, lon);
        gridCells.set(key, (gridCells.get(key) || 0) + 1);
      }
    });
  }

  function drawGrid() {
    var KM_PER_DEGREE_LAT = 111;
    var KM_PER_DEGREE_LON_BASE = 111;

    var latCellSize = CONFIG.GRID_SIZE_KM / KM_PER_DEGREE_LAT;
    var lonCellSize = CONFIG.GRID_SIZE_KM / (KM_PER_DEGREE_LON_BASE * Math.cos(52 * Math.PI / 180));

    var bounds = CONFIG.POLAND_BOUNDS;
    var minLat = bounds[0][0], minLon = bounds[0][1];
    var maxLat = bounds[1][0], maxLon = bounds[1][1];

    for (var lat = Math.floor(minLat / latCellSize) * latCellSize; lat < maxLat; lat += latCellSize) {
      for (var lon = Math.floor(minLon / lonCellSize) * lonCellSize; lon < maxLon; lon += lonCellSize) {
        var key = getCellKey(lat + latCellSize/2, lon + lonCellSize/2);
        var hasPhotos = gridCells.has(key);
        var color = hasPhotos ? 'rgba(76, 175, 80, 0.3)' : 'rgba(244, 67, 54, 0.45)';
        var borderColor = hasPhotos ? 'rgba(76, 175, 80, 0.4)' : 'rgba(244, 67, 54, 0.5)';

        L.rectangle(
          [[lat, lon], [lat + latCellSize, lon + lonCellSize]],
          { color: borderColor, weight: 1, fillColor: color, fillOpacity: hasPhotos ? 0.3 : 0.6, interactive: false }
        ).addTo(map);
      }
    }
  }

  function drawStations() {
    stationMarkers.forEach(function(marker) { map.removeLayer(marker); });
    stationMarkers = [];

    stations.forEach(function(station) {
      if (station.lat == null || station.lon == null) return;

      var marker = L.circleMarker([station.lat, station.lon], {
        radius: 6,
        fillColor: '#2196F3',
        color: '#1565C0',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.8
      }).addTo(map);

      var content = '<div class="route-popup">' +
        '<h4>' + station.name + '</h4>' +
        '<p>Czas dojazdu: <strong>' + station.time_distance + ' h</strong></p>' +
        '</div>';
      marker.bindPopup(content);

      stationMarkers.push(marker);
    });
  }

  function generateTrips() {
    clearResults();

    var days = parseInt(document.querySelector('input[name="tripDays"]:checked').value);
    var maxKm = days * CONFIG.DAILY_DISTANCE_KM;

    var routes = findBestRoutes(days, maxKm);
    displayRoutes(routes);
  }

  function findBestRoutes(days, maxKm) {
    var routes = [];
    var stationUsage = new Map();
    var MAX_USES_PER_STATION = 2;

    for (var i = 0; i < stations.length; i++) {
      for (var j = i + 1; j < stations.length; j++) {
        var station1 = stations[i];
        var station2 = stations[j];

        if (!station1.lat || !station1.lon || !station2.lat || !station2.lon) continue;

        var dist = getDistance(station1.lat, station1.lon, station2.lat, station2.lon);
        if (dist > maxKm || dist < 20) continue;

        var blankCells = countBlankCellsOnSegment(station1.lat, station1.lon, station2.lat, station2.lon);

        var route = {
          stations: [station1, station2],
          totalKm: dist,
          blankCells: blankCells,
          segments: [{
            from: station1,
            to: station2,
            km: dist
          }]
        };

        var current1 = stationUsage.get(station1.name) || 0;
        var current2 = stationUsage.get(station2.name) || 0;

        if (current1 < MAX_USES_PER_STATION || current2 < MAX_USES_PER_STATION) {
          routes.push(route);
          stationUsage.set(station1.name, current1 + 1);
          stationUsage.set(station2.name, current2 + 1);
        }
      }
    }

    routes.sort(function(a, b) {
      return calculateEfficiency(b, routes) - calculateEfficiency(a, routes) ||
             b.totalKm - a.totalKm;
    });

    return routes.slice(0, CONFIG.ROUTES_SLICE);
  }

  function calculateEfficiency(route, allRoutes) {
    allRoutes = allRoutes || [];
    var bikingDays = Math.ceil(route.totalKm / 60);
    var bikingHours = bikingDays * 10;

    var startTime = route.stations[0] ? route.stations[0].time_distance : 0;
    var endTime = route.stations[1] ? route.stations[1].time_distance : 0;
    var trainHours = startTime + endTime;

    var totalHours = bikingHours + trainHours;
    var totalDays = Math.ceil(totalHours / 10);

    var efficiency = route.blankCells / totalDays;

    var usedStations = new Set();
    if (Array.isArray(allRoutes)) {
      allRoutes.slice(0, 3).forEach(function(r) {
        if (r && r.stations && Array.isArray(r.stations)) {
          r.stations.forEach(function(s) { if (s && s.name) usedStations.add(s.name); });
        }
      });
    }

    var duplicatePenalty = 0;
    if (route.stations[0] && route.stations[0].name && usedStations.has(route.stations[0].name)) duplicatePenalty += CONFIG.DUPLICATE_PENALTY;
    if (route.stations[1] && route.stations[1].name && usedStations.has(route.stations[1].name)) duplicatePenalty += CONFIG.DUPLICATE_PENALTY;

    efficiency *= (1 - duplicatePenalty);

    return isFinite(efficiency) && efficiency > 0 ? efficiency : 0;
  }

  function countCellsOnSegment(lat1, lon1, lat2, lon2) {
    var steps = 20;
    var counted = new Set();

    for (var i = 0; i <= steps; i++) {
      var t = i / steps;
      var lat = lat1 + (lat2 - lat1) * t;
      var lon = lon1 + (lon2 - lon1) * t;
      counted.add(getCellKey(lat, lon));
    }

    return counted.size;
  }

  function countBlankCellsOnSegment(lat1, lon1, lat2, lon2) {
    var steps = 20;
    var blankCount = 0;
    var counted = new Set();

    for (var i = 0; i <= steps; i++) {
      var t = i / steps;
      var lat = lat1 + (lat2 - lat1) * t;
      var lon = lon1 + (lon2 - lon1) * t;

      var key = getCellKey(lat, lon);
      if (!counted.has(key)) {
        counted.add(key);
        if (!gridCells.has(key)) {
          blankCount++;
        }
      }
    }

    return blankCount;
  }

  function generateExportLinks(route) {
    var s1 = route.stations[0];
    var s2 = route.stations[1];

    var google = 'https://www.google.com/maps/dir/' + s1.lat + ',' + s1.lon + '/' + s2.lat + ',' + s2.lon + '/?dirflg=b';

    return '<div class="export-links">' +
      '<a class="export-link" href="' + google + '" target="_blank">Google Maps</a>' +
      '</div>';
  }

  function displayRoutes(routes) {
    clearRouteLines();

    var resultsDiv = document.getElementById('results-content');
    resultsDiv.innerHTML = '';

    routes.forEach(function(route, idx) {
      var efficiency = calculateEfficiency(route);
      var s0time = route.stations[0].time_distance || 0;
      var s1time = route.stations[1].time_distance || 0;

      var routeHtml =
        '<div class="route-card">' +
          '<div class="route-card-head">' +
            '<span class="route-card-num">Trasa ' + (idx + 1) + '</span>' +
            '<span class="route-card-eff">' + efficiency.toFixed(1) + ' kom/dz</span>' +
          '</div>' +
          '<div class="route-card-body">' +
            '<div class="route-card-stations">' +
              route.stations.map(function(s) { return s.name; }).join(' \u2192 ') +
            '</div>' +
            '<div class="route-card-stats">' +
              '<span>Dystans: <strong>' + route.totalKm.toFixed(0) + ' km</strong></span>' +
              '<span>Nowe: <strong>' + route.blankCells + ' kom</strong></span>' +
              '<span>Pociąg: <strong>' + s0time + 'h + ' + s1time + 'h</strong></span>' +
            '</div>' +
            generateExportLinks(route) +
          '</div>' +
        '</div>';

      resultsDiv.innerHTML += routeHtml;
      drawRoute(route, idx);
    });

    document.getElementById('results').style.display = 'block';
  }

  function drawRoute(route, idx) {
    var colors = [
      '#D32F2F', '#1976D2', '#C2185B', '#6A1B9A', '#388E3C',
      '#F57C00', '#2E7D32', '#7B1FA2', '#E65100', '#01579B'
    ];
    var color = colors[idx % colors.length];

    route.segments.forEach(function(segment) {
      var polyline = L.polyline(
        [[segment.from.lat, segment.from.lon], [segment.to.lat, segment.to.lon]],
        { color: color, weight: 5, opacity: 0.8, dashArray: '5, 5' }
      ).addTo(map);

      var popup = '<div class="route-popup">' +
        '<h4>' + route.stations[0].name + ' \u2192 ' + route.stations[1].name + '</h4>' +
        '<p>Dystans: <strong>' + segment.km.toFixed(1) + ' km</strong></p>' +
        '<p>Nowe komórki: <strong>' + route.blankCells + '</strong></p>' +
        '<p>Komórki na trasie: <strong>' + countCellsOnSegment(segment.from.lat, segment.from.lon, segment.to.lat, segment.to.lon) + '</strong></p>' +
        '<p>Czas dojazdu: <strong>' + (route.stations[0].time_distance || 0) + 'h + ' + (route.stations[1].time_distance || 0) + 'h</strong></p>' +
        '</div>';
      polyline.bindPopup(popup);

      drawnRoutes.push(polyline);
    });
  }

  function clearRouteLines() {
    drawnRoutes.forEach(function(line) { map.removeLayer(line); });
    drawnRoutes = [];
  }

  function clearResults() {
    document.getElementById('results').style.display = 'none';
    document.getElementById('results-content').innerHTML = '';
    clearRouteLines();
  }

  function updateStats() {
    var KM_PER_DEGREE_LAT = 111;
    var KM_PER_DEGREE_LON_BASE = 111;

    var latCellSize = CONFIG.GRID_SIZE_KM / KM_PER_DEGREE_LAT;
    var lonCellSize = CONFIG.GRID_SIZE_KM / (KM_PER_DEGREE_LON_BASE * Math.cos(52 * Math.PI / 180));

    var bounds = CONFIG.POLAND_BOUNDS;
    var minLat = bounds[0][0], minLon = bounds[0][1];
    var maxLat = bounds[1][0], maxLon = bounds[1][1];

    var totalCells = 0;
    for (var lat = Math.floor(minLat / latCellSize) * latCellSize; lat < maxLat; lat += latCellSize) {
      for (var lon = Math.floor(minLon / lonCellSize) * lonCellSize; lon < maxLon; lon += lonCellSize) {
        totalCells++;
      }
    }

    var filledCells = gridCells.size;
    var blankCells = totalCells - filledCells;
    var coverage = ((filledCells / totalCells) * 100).toFixed(1);

    document.getElementById('totalCells').textContent = totalCells;
    document.getElementById('filledCells').textContent = filledCells;
    document.getElementById('blankCells').textContent = blankCells;
    document.getElementById('coveragePercent').textContent = coverage;
  }

  function showError(message) {
    var errorDiv = document.getElementById('error-container');
    errorDiv.innerHTML = '<div class="error">' + message + '</div>';
  }

  window.addEventListener('load', function() {
    initMap();
    loadData();

    document.getElementById('generate-btn').addEventListener('click', generateTrips);
  });
})();
