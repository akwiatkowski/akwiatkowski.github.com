// ============================================================================
// EXIF Stats Dashboard
// ============================================================================

// --- Constants ---
var MAX_ALTITUDE = 4000;
var NON_INTERCHANGEABLE_CAMERAS = [
    'Nieznane', 'Unknown', 'Gopro 3 Black', 'DJI Spark', 'Xiaomi Redmi Note 3',
    'DJI Mini 3 Pro', 'iPhone 13 Pro'
];
var COLORS = {
    teal: '#208081', amber: '#f59e0b', red: '#ef4444', blue: '#3b82f6',
    green: '#22c55e', purple: '#a855f7', indigo: '#6366f1', pink: '#ec4899',
    orange: '#f97316', cyan: '#06b6d4'
};
var COLOR_LIST = [COLORS.teal, COLORS.red, COLORS.amber, COLORS.blue, COLORS.green,
    COLORS.purple, COLORS.indigo, COLORS.pink, COLORS.orange, COLORS.cyan];
var MONTHS_PL = ['Sty','Lut','Mar','Kwi','Maj','Cze','Lip','Sie','Wrz','Paź','Lis','Gru'];
var DAYS_PL = ['Nd','Pn','Wt','Śr','Cz','Pt','Sb'];
var FOCAL_BOUNDARIES = [10, 14, 20, 28, 35, 50, 70, 100, 135, 200, 280, 400, 1000];

// --- State ---
var allPhotos = [];
var filteredPhotos = [];
var charts = {};
var tagNames = {}; // slug → Polish display name (loaded from JSON)

// --- Mock data ---
var MOCK_PHOTOS = [
    {"full_url":"/i1.jpg","article_url":"/i1g.jpg","time":"2011-05-03T21:00:00+02:00","post_slug":"s1","is_published":true,"tags":["spring"],"exif.lat":null,"exif.lon":null,"exif.focal_35mm":75,"exif.aperture":4.5,"exif.lens_name":"Pentax FA 50mm Macro","exif.camera_name":"Pentax K100D","exif.time":"2011-04-30T14:57:28+02:00","exif.exposure":0.004,"exif.altitude":800,"exif.iso":100},
    {"full_url":"/i2.jpg","article_url":"/i2g.jpg","time":"2018-10-08T20:00:00+02:00","post_slug":"s2","is_published":true,"tags":["cat"],"exif.lat":50.87,"exif.lon":15.83,"exif.focal_35mm":50,"exif.aperture":1.4,"exif.lens_name":"Lumix 25mm f1.4","exif.camera_name":"Olympus M1m2","exif.time":"2018-10-08T19:10:08+02:00","exif.exposure":0.001,"exif.altitude":250,"exif.iso":800}
];

// ============================================================================
// CHART DEFAULTS (dark mode aware)
// ============================================================================
function setupChartDefaults() {
    var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    Chart.defaults.color = isDark ? '#a0a7b0' : '#626c7c';
    Chart.defaults.borderColor = isDark ? '#404040' : '#e0e0e0';
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = true;
}

// ============================================================================
// DATA LOADING - Streaming with progress
// ============================================================================
async function loadPhotos() {
    var USE_MOCK = false;
    if (USE_MOCK) {
        allPhotos = MOCK_PHOTOS;
        document.getElementById('mockIndicator').style.display = 'inline-block';
        updateDashboard();
        return;
    }

    document.getElementById('progressContainer').classList.add('visible');
    var progressFill = document.getElementById('progressFill');
    var progressText = document.getElementById('progressText');
    var errorMsg = document.getElementById('errorMessage');
    errorMsg.classList.remove('visible');

    try {
        var response = await fetch('/jsons/photos.json');
        if (!response.ok) throw new Error('HTTP ' + response.status);

        var contentLength = response.headers.get('content-length');
        var totalBytes = contentLength ? parseInt(contentLength, 10) : null;
        var loadedBytes = 0;
        var reader = response.body.getReader();
        var chunks = [];

        while (true) {
            var result = await reader.read();
            if (result.done) break;
            chunks.push(result.value);
            loadedBytes += result.value.length;
            if (totalBytes) {
                var percent = Math.round((loadedBytes / totalBytes) * 100);
                progressFill.style.width = percent + '%';
                progressText.textContent = percent + '%';
            }
        }

        var buffer = new Uint8Array(loadedBytes);
        var position = 0;
        for (var i = 0; i < chunks.length; i++) {
            buffer.set(chunks[i], position);
            position += chunks[i].length;
        }

        var parsed = JSON.parse(new TextDecoder().decode(buffer));
        allPhotos = Array.isArray(parsed) ? parsed : (parsed.photos || []);
        if (parsed.tag_names) tagNames = parsed.tag_names;

        progressFill.style.width = '100%';
        progressText.textContent = '100%';
        setTimeout(function() {
            document.getElementById('progressContainer').classList.remove('visible');
        }, 500);

        cleanPhotos();
        updateDashboard();
    } catch (error) {
        errorMsg.textContent = 'Nie udało się załadować /jsons/photos.json: ' + error.message;
        errorMsg.classList.add('visible');
        allPhotos = MOCK_PHOTOS;
        document.getElementById('mockIndicator').style.display = 'inline-block';
        document.getElementById('progressContainer').classList.remove('visible');
        cleanPhotos();
        updateDashboard();
    }
}

// ============================================================================
// DATA CLEANING
// ============================================================================
function cleanPhotos() {
    allPhotos.forEach(function(p) {
        // Cap altitude at MAX_ALTITUDE
        if (p['exif.altitude'] != null && p['exif.altitude'] > MAX_ALTITUDE) {
            p['exif.altitude'] = null;
        }
        // Cap negative altitudes
        if (p['exif.altitude'] != null && p['exif.altitude'] < 0) {
            p['exif.altitude'] = null;
        }
    });
}

// ============================================================================
// FILTERING
// ============================================================================
function getFilteredPhotos() {
    var yearFilter = document.getElementById('yearFilter').value;
    var cameraFilter = document.getElementById('cameraFilter').value;
    var lensFilter = document.getElementById('lensFilter').value;
    var includeNonInterchangeable = document.getElementById('includeNonInterchangeable').checked;

    return allPhotos.filter(function(photo) {
        if (!includeNonInterchangeable) {
            var cameraName = photo['exif.camera_name'] || '';
            var lensName = photo['exif.lens_name'] || '';
            if (NON_INTERCHANGEABLE_CAMERAS.indexOf(cameraName) !== -1) return false;
            if (NON_INTERCHANGEABLE_CAMERAS.indexOf(lensName) !== -1) return false;
        }
        if (yearFilter) {
            var photoYear = new Date(photo.time).getFullYear().toString();
            if (photoYear !== yearFilter) return false;
        }
        if (cameraFilter && photo['exif.camera_name'] !== cameraFilter) return false;
        if (lensFilter && photo['exif.lens_name'] !== lensFilter) return false;
        return true;
    });
}

function updateFilters() {
    var years = new Set(), cameras = new Set(), lenses = new Set();
    allPhotos.forEach(function(p) {
        years.add(new Date(p.time).getFullYear());
        if (p['exif.camera_name']) cameras.add(p['exif.camera_name']);
        if (p['exif.lens_name']) lenses.add(p['exif.lens_name']);
    });

    fillSelect('yearFilter', Array.from(years).sort(function(a,b){return b-a;}));
    fillSelect('cameraFilter', Array.from(cameras).sort());
    fillSelect('lensFilter', Array.from(lenses).sort());
}

function fillSelect(id, values) {
    var sel = document.getElementById(id);
    var current = sel.value;
    // Keep first option
    while (sel.options.length > 1) sel.remove(1);
    values.forEach(function(v) {
        var opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        sel.appendChild(opt);
    });
    sel.value = current;
}

function resetFilters() {
    document.getElementById('yearFilter').value = '';
    document.getElementById('cameraFilter').value = '';
    document.getElementById('lensFilter').value = '';
    document.getElementById('includeNonInterchangeable').checked = false;
    updateStats();
    updateCharts();
}

// ============================================================================
// STATS CALCULATION
// ============================================================================
function calculateStats(photos) {
    var required = ['exif.focal_35mm', 'exif.aperture', 'exif.lens_name', 'exif.time', 'exif.camera_name'];
    var valid = photos.filter(function(p) {
        return required.every(function(f) { return p[f] != null; });
    });

    var stats = {
        totalPhotos: valid.length,
        allPhotosCount: photos.length,
        publishedCount: valid.filter(function(p){return p.is_published;}).length,
        focalLengths: [], apertures: [], cameras: {}, lenses: {},
        years: {}, allYears: {}, isos: [], exposures: [], altitudes: []
    };

    // Year chart uses ALL photos with a timestamp — not just those with full EXIF.
    // This includes photos from older cameras (Pentax K-5) that lack lens_name,
    // and drone photos that lack focal_35mm.
    photos.forEach(function(p) {
        var t = p['exif.time'] || p.time;
        if (t) {
            var year = new Date(t).getFullYear();
            stats.allYears[year] = (stats.allYears[year] || 0) + 1;
        }
    });

    valid.forEach(function(p) {
        if (p['exif.focal_35mm']) stats.focalLengths.push(p['exif.focal_35mm']);
        if (p['exif.aperture']) stats.apertures.push(p['exif.aperture']);
        if (p['exif.iso']) stats.isos.push(p['exif.iso']);
        if (p['exif.exposure']) stats.exposures.push(p['exif.exposure']);
        if (p['exif.altitude'] != null && p['exif.altitude'] > 0) stats.altitudes.push(p['exif.altitude']);

        var cam = p['exif.camera_name'];
        if (cam) stats.cameras[cam] = (stats.cameras[cam] || 0) + 1;
        var lens = p['exif.lens_name'];
        if (lens) stats.lenses[lens] = (stats.lenses[lens] || 0) + 1;

        var year = new Date(p['exif.time']).getFullYear();
        stats.years[year] = (stats.years[year] || 0) + 1;
    });
    return stats;
}

// ============================================================================
// HELPERS
// ============================================================================
function getFocalBins(focalLengths) {
    var bins = {};
    for (var i = 0; i < FOCAL_BOUNDARIES.length - 1; i++) {
        bins[FOCAL_BOUNDARIES[i] + '-' + FOCAL_BOUNDARIES[i+1] + 'mm'] = 0;
    }
    focalLengths.forEach(function(f) {
        for (var i = 0; i < FOCAL_BOUNDARIES.length - 1; i++) {
            if (f >= FOCAL_BOUNDARIES[i] && f < FOCAL_BOUNDARIES[i+1]) {
                bins[FOCAL_BOUNDARIES[i] + '-' + FOCAL_BOUNDARIES[i+1] + 'mm']++;
                break;
            }
        }
    });
    return bins;
}

function getApertureBins(apertures) {
    var std = [1.0, 1.2, 1.4, 1.7, 2.0, 2.8, 4.0, 5.6, 6.3, 8.0, 11.0, 16.0, 22.0];
    var bins = {};
    std.forEach(function(a) { bins['f/' + a.toFixed(1)] = 0; });
    apertures.forEach(function(ap) {
        var closest = std[0], minDiff = Math.abs(ap - closest);
        std.forEach(function(s) {
            var d = Math.abs(ap - s);
            if (d < minDiff) { minDiff = d; closest = s; }
        });
        bins['f/' + closest.toFixed(1)]++;
    });
    return bins;
}

function median(arr) {
    if (arr.length === 0) return 0;
    var s = arr.slice().sort(function(a,b){return a-b;});
    var m = Math.floor(s.length / 2);
    return s.length % 2 ? s[m] : (s[m-1] + s[m]) / 2;
}

function dateToDecimal(dateStr) {
    var d = new Date(dateStr);
    var y = d.getFullYear();
    var start = new Date(y, 0, 1);
    var end = new Date(y + 1, 0, 1);
    return y + (d - start) / (end - start);
}

function destroyAllCharts() {
    Object.keys(charts).forEach(function(k) { charts[k].destroy(); });
    charts = {};
}

function topN(obj, n) {
    return Object.entries(obj).sort(function(a,b){return b[1]-a[1];}).slice(0, n);
}

function barOpts(extra) {
    var o = { responsive: true, maintainAspectRatio: true, plugins: { legend: { display: false } } };
    if (extra) Object.assign(o, extra);
    return o;
}

// ============================================================================
// UPDATE STAT CARDS
// ============================================================================
function updateStats() {
    filteredPhotos = getFilteredPhotos();
    var stats = calculateStats(filteredPhotos);
    if (stats.totalPhotos === 0) return;

    // Total photos
    document.getElementById('totalPhotos').textContent = stats.totalPhotos;
    document.getElementById('publishedCount').textContent = stats.publishedCount + ' opublikowanych';

    // Modal focal
    var focalCounts = {};
    stats.focalLengths.forEach(function(f) { focalCounts[f] = (focalCounts[f]||0)+1; });
    var modalFocal = Object.keys(focalCounts).length > 0
        ? Object.entries(focalCounts).sort(function(a,b){return b[1]-a[1];})[0][0] : '—';
    var mfv = parseFloat(modalFocal);
    var similarCount = stats.focalLengths.filter(function(f){return Math.abs(f-mfv) <= mfv*0.1;}).length;
    document.getElementById('modalFocal').textContent = modalFocal + 'mm';
    document.getElementById('focalStats').textContent = similarCount + ' zdjęć w pobliżu';

    // Average aperture
    var avgAp = stats.apertures.length > 0
        ? (stats.apertures.reduce(function(a,b){return a+b;},0) / stats.apertures.length).toFixed(1) : '—';
    document.getElementById('avgAperture').textContent = 'f/' + avgAp;
    document.getElementById('apertureStats').textContent = stats.apertures.length + ' zdjęć z EXIF';

    // Top lens/camera
    var tl = topN(stats.lenses, 1)[0];
    var tc = topN(stats.cameras, 1)[0];
    document.getElementById('topLens').textContent = tl ? tl[0].split(' ').slice(0,2).join(' ') : '—';
    document.getElementById('lensStats').textContent = tl ? tl[1] + ' zdjęć' : '';
    document.getElementById('topCamera').textContent = tc ? tc[0] : '—';
    document.getElementById('cameraStats').textContent = tc ? tc[1] + ' zdjęć' : '';

    // Most used ISO
    var isoCounts = {};
    stats.isos.forEach(function(iso) { isoCounts[iso] = (isoCounts[iso]||0)+1; });
    var topIso = Object.entries(isoCounts).sort(function(a,b){return b[1]-a[1];})[0];
    document.getElementById('avgISO').textContent = topIso ? topIso[0] : '—';
    document.getElementById('isoStats').textContent = topIso ? topIso[1] + ' zdjęć' : '';

    // Trips (unique shooting days)
    var tripDays = new Set();
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (t) tripDays.add(t.substring(0, 10));
    });
    var numTrips = tripDays.size;
    var avgPerTrip = numTrips > 0 ? Math.round(filteredPhotos.length / numTrips) : 0;
    document.getElementById('totalTrips').textContent = numTrips;
    document.getElementById('tripsDetail').textContent = 'śr. ' + avgPerTrip + ' zdjęć na wycieczkę';

    // Equipment count
    var camCount = Object.keys(stats.cameras).length;
    var lensCount = Object.keys(stats.lenses).length;
    document.getElementById('equipmentCount').textContent = camCount + ' / ' + lensCount;
    document.getElementById('equipmentDetail').textContent = camCount + ' aparatów, ' + lensCount + ' obiektywów';

    // Active hours
    var hourCounts = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (t && t.indexOf('T') !== -1) {
            var h = parseInt(t.split('T')[1].substring(0,2));
            hourCounts[h] = (hourCounts[h]||0) + 1;
        }
    });
    var activeH = Object.keys(hourCounts).filter(function(h){return hourCounts[h] > filteredPhotos.length * 0.01;})
        .map(Number).sort(function(a,b){return a-b;});
    if (activeH.length > 0) {
        document.getElementById('activeHours').textContent = activeH[0] + ':00 – ' + activeH[activeH.length-1] + ':00';
        var peakH = Object.entries(hourCounts).sort(function(a,b){return b[1]-a[1];})[0];
        document.getElementById('activeHoursDetail').textContent = 'szczyt: ' + peakH[0] + ':00';
    }
}

// ============================================================================
// CHART RENDERING
// ============================================================================
function updateCharts() {
    destroyAllCharts();
    var stats = calculateStats(filteredPhotos);
    if (stats.totalPhotos === 0) return;

    renderYearChart(stats);
    renderPublishedRatioChart();
    renderEquipmentLifespan();
    renderCameraTimeline();
    renderTopCameras(stats);
    renderTopLenses(stats);
    renderWideOpenChart();
    renderFocalChart(stats);
    renderWideTeleChart();
    renderZoomSweetSpots();
    renderFocalTimeline();
    renderApertureChart(stats);
    renderIsoChart(stats);
    renderIsoTrendChart();
    renderExposureChart(stats);
    renderHourChart();
    renderDayOfWeekChart();
    renderHourMonthHeatmap();
    renderIntervalChart();
    renderPhotosPerTripChart();
    renderAltitudeChart(stats);
    renderTagsChart();
}

// --- Photos Over Time ---

function renderYearChart(stats) {
    // Use allYears (all photos with timestamps) for the year chart,
    // not just photos with full EXIF data (years). This includes photos
    // from cameras that don't write lens model or focal_35mm.
    var years = Object.keys(stats.allYears).sort();
    charts.year = new Chart(document.getElementById('yearChart'), {
        type: 'line',
        data: {
            labels: years,
            datasets: [{
                label: 'Zdjęcia',
                data: years.map(function(y){return stats.allYears[y];}),
                borderColor: COLORS.teal, backgroundColor: 'rgba(32,128,129,0.1)',
                tension: 0.4, fill: true, pointBackgroundColor: COLORS.teal,
                pointBorderColor: '#fff', pointBorderWidth: 2
            }]
        },
        options: barOpts()
    });
}

function renderPublishedRatioChart() {
    var byYear = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'] || p.time;
        if (!t) return;
        var y = new Date(t).getFullYear();
        if (!byYear[y]) byYear[y] = {total: 0, pub: 0};
        byYear[y].total++;
        if (p.is_published) byYear[y].pub++;
    });
    var years = Object.keys(byYear).sort();
    charts.publishedRatio = new Chart(document.getElementById('publishedRatioChart'), {
        type: 'bar',
        data: {
            labels: years,
            datasets: [{
                label: '% opublikowanych',
                data: years.map(function(y){
                    return byYear[y].total > 0 ? Math.round(byYear[y].pub / byYear[y].total * 100) : 0;
                }),
                backgroundColor: COLORS.green, borderColor: COLORS.green, borderWidth: 1
            }]
        },
        options: barOpts({scales:{y:{beginAtZero:true,max:100,ticks:{callback:function(v){return v+'%';}}}}})
    });
}

// --- Equipment ---

function renderEquipmentLifespan() {
    var equipment = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (!t) return;
        var dec = dateToDecimal(t);
        var cam = p['exif.camera_name'];
        var lens = p['exif.lens_name'];
        if (cam) {
            if (!equipment['📷 ' + cam]) equipment['📷 ' + cam] = {min: dec, max: dec, count: 0};
            var e = equipment['📷 ' + cam];
            if (dec < e.min) e.min = dec;
            if (dec > e.max) e.max = dec;
            e.count++;
        }
        if (lens) {
            if (!equipment['🔭 ' + lens]) equipment['🔭 ' + lens] = {min: dec, max: dec, count: 0};
            var e2 = equipment['🔭 ' + lens];
            if (dec < e2.min) e2.min = dec;
            if (dec > e2.max) e2.max = dec;
            e2.count++;
        }
    });

    // Sort by first use date
    var entries = Object.entries(equipment).filter(function(e){return e[1].count >= 10;})
        .sort(function(a,b){return a[1].min - b[1].min;});
    var labels = entries.map(function(e){return e[0];});
    var data = entries.map(function(e){return [e[1].min, e[1].max];});
    var bgColors = entries.map(function(e){return e[0].startsWith('📷') ? COLORS.blue : COLORS.teal;});

    charts.equipmentLifespan = new Chart(document.getElementById('equipmentLifespanChart'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: bgColors, borderWidth: 0, barPercentage: 0.7
            }]
        },
        options: {
            indexAxis: 'y', responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: {display: false},
                tooltip: {
                    callbacks: {
                        label: function(ctx) {
                            var v = ctx.raw;
                            var e = entries[ctx.dataIndex][1];
                            return Math.floor(v[0]) + ' – ' + Math.floor(v[1]) + ' (' + e.count + ' zdjęć)';
                        }
                    }
                }
            },
            scales: {
                x: {type:'linear', min: Math.floor(entries[0][1].min), max: Math.ceil(entries[entries.length-1][1].max)}
            }
        }
    });
    // Adjust canvas height based on item count
    document.getElementById('equipmentLifespanChart').parentElement.style.height = Math.max(400, entries.length * 28) + 'px';
}

function renderCameraTimeline() {
    var timeline = {};
    filteredPhotos.forEach(function(p) {
        var y = new Date(p.time).getFullYear();
        var cam = p['exif.camera_name'] || 'Nieznany';
        var key = y + '-' + cam;
        timeline[key] = (timeline[key] || 0) + 1;
    });

    var years = Array.from(new Set(Object.keys(timeline).map(function(k){return k.split('-')[0];}))).sort();
    var cams = Array.from(new Set(Object.keys(timeline).map(function(k){return k.substring(k.indexOf('-')+1);})));

    var datasets = cams.map(function(cam, i) {
        return {
            label: cam,
            data: years.map(function(y) {
                var key = y + '-' + cam;
                var yearTotal = Object.keys(timeline).filter(function(k){return k.startsWith(y+'-');})
                    .reduce(function(s,k){return s+timeline[k];}, 0);
                return yearTotal > 0 ? (timeline[key]||0) / yearTotal * 100 : 0;
            }),
            borderWidth: 0, fill: true, tension: 0.3,
            backgroundColor: COLOR_LIST[i % COLOR_LIST.length]
        };
    });

    charts.cameraTimeline = new Chart(document.getElementById('cameraTimelineChart'), {
        type: 'line', data: {labels: years, datasets: datasets},
        options: {
            responsive: true, maintainAspectRatio: true,
            plugins: {legend: {position: 'top', labels: {boxWidth: 12, font: {size: 11}}}},
            scales: {y: {stacked: true, max: 100, ticks: {callback: function(v){return v+'%';}}}}
        }
    });
}

function renderTopCameras(stats) {
    var top = topN(stats.cameras, 10);
    charts.camera = new Chart(document.getElementById('cameraChart'), {
        type: 'bar',
        data: {
            labels: top.map(function(c){return c[0];}),
            datasets: [{label: 'Zdjęcia', data: top.map(function(c){return c[1];}), backgroundColor: COLORS.blue}]
        },
        options: barOpts({indexAxis:'y', scales:{x:{beginAtZero:true}}})
    });
}

function renderTopLenses(stats) {
    var top = topN(stats.lenses, 10);
    charts.lens = new Chart(document.getElementById('lensChart'), {
        type: 'bar',
        data: {
            labels: top.map(function(l){return l[0];}),
            datasets: [{label: 'Zdjęcia', data: top.map(function(l){return l[1];}), backgroundColor: COLORS.red}]
        },
        options: barOpts({indexAxis:'y', scales:{x:{beginAtZero:true}}})
    });
}

function renderWideOpenChart() {
    // For each lens: find min aperture used, count % shots at min ±0.3
    var lensMin = {}, lensTotal = {}, lensWide = {};
    filteredPhotos.forEach(function(p) {
        var lens = p['exif.lens_name'], ap = p['exif.aperture'];
        if (!lens || !ap) return;
        if (!lensMin[lens] || ap < lensMin[lens]) lensMin[lens] = ap;
        lensTotal[lens] = (lensTotal[lens]||0) + 1;
    });
    filteredPhotos.forEach(function(p) {
        var lens = p['exif.lens_name'], ap = p['exif.aperture'];
        if (!lens || !ap) return;
        if (ap <= lensMin[lens] + 0.3) lensWide[lens] = (lensWide[lens]||0) + 1;
    });

    var entries = Object.keys(lensTotal).filter(function(l){return lensTotal[l]>=50;})
        .map(function(l){return {lens:l, pct: Math.round((lensWide[l]||0)/lensTotal[l]*100), maxAp: lensMin[l]};})
        .sort(function(a,b){return b.pct - a.pct;}).slice(0, 12);

    charts.wideOpen = new Chart(document.getElementById('wideOpenChart'), {
        type: 'bar',
        data: {
            labels: entries.map(function(e){return e.lens + ' (f/' + e.maxAp.toFixed(1) + ')';}),
            datasets: [{
                label: '% przy max przysłonie',
                data: entries.map(function(e){return e.pct;}),
                backgroundColor: entries.map(function(e){
                    return e.pct > 40 ? COLORS.green : e.pct > 20 ? COLORS.amber : COLORS.red;
                })
            }]
        },
        options: barOpts({indexAxis:'y', scales:{x:{beginAtZero:true,max:100,ticks:{callback:function(v){return v+'%';}}}}})
    });
}

// --- Focal Length ---

function renderFocalChart(stats) {
    var bins = getFocalBins(stats.focalLengths);
    charts.focal = new Chart(document.getElementById('focalChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Ilość', data: Object.values(bins), backgroundColor: COLORS.teal, borderColor: '#1a7477', borderWidth: 1}]
        },
        options: barOpts()
    });
}

function renderWideTeleChart() {
    var bands = {'<24mm': 0, '24-35mm': 0, '35-70mm': 0, '70-200mm': 0, '>200mm': 0};
    var byYear = {};
    filteredPhotos.forEach(function(p) {
        var f = p['exif.focal_35mm'], t = p['exif.time'];
        if (!f || !t) return;
        var y = new Date(t).getFullYear();
        if (!byYear[y]) byYear[y] = {'<24mm':0,'24-35mm':0,'35-70mm':0,'70-200mm':0,'>200mm':0, total:0};
        byYear[y].total++;
        if (f < 24) byYear[y]['<24mm']++;
        else if (f < 35) byYear[y]['24-35mm']++;
        else if (f < 70) byYear[y]['35-70mm']++;
        else if (f < 200) byYear[y]['70-200mm']++;
        else byYear[y]['>200mm']++;
    });

    var years = Object.keys(byYear).sort();
    var bandNames = Object.keys(bands);
    var bandColors = [COLORS.cyan, COLORS.blue, COLORS.green, COLORS.amber, COLORS.red];

    charts.wideTele = new Chart(document.getElementById('wideTeleChart'), {
        type: 'bar',
        data: {
            labels: years,
            datasets: bandNames.map(function(band, i) {
                return {
                    label: band,
                    data: years.map(function(y){return byYear[y].total > 0 ? Math.round(byYear[y][band]/byYear[y].total*100) : 0;}),
                    backgroundColor: bandColors[i]
                };
            })
        },
        options: {
            responsive: true, maintainAspectRatio: true,
            plugins: {legend: {position: 'top', labels: {boxWidth: 12, font: {size: 11}}}},
            scales: {x: {stacked: true}, y: {stacked: true, max: 100, ticks: {callback: function(v){return v+'%';}}}}
        }
    });
}

function renderZoomSweetSpots() {
    // Identify zoom lenses: lenses with >5 distinct focal lengths and >100 photos
    var lensFocals = {};
    filteredPhotos.forEach(function(p) {
        var lens = p['exif.lens_name'], f = p['exif.focal_35mm'];
        if (!lens || !f) return;
        if (!lensFocals[lens]) lensFocals[lens] = {counts: {}, total: 0, distinctFocals: new Set()};
        lensFocals[lens].total++;
        lensFocals[lens].distinctFocals.add(Math.round(f));
        // Bin focal length
        for (var i = 0; i < FOCAL_BOUNDARIES.length - 1; i++) {
            if (f >= FOCAL_BOUNDARIES[i] && f < FOCAL_BOUNDARIES[i+1]) {
                var bin = FOCAL_BOUNDARIES[i] + '-' + FOCAL_BOUNDARIES[i+1];
                lensFocals[lens].counts[bin] = (lensFocals[lens].counts[bin]||0) + 1;
                break;
            }
        }
    });

    var zooms = Object.entries(lensFocals)
        .filter(function(e){return e[1].distinctFocals.size > 5 && e[1].total >= 100;})
        .sort(function(a,b){return b[1].total - a[1].total;})
        .slice(0, 5);

    if (zooms.length === 0) return;

    var binLabels = [];
    for (var i = 0; i < FOCAL_BOUNDARIES.length - 1; i++) {
        binLabels.push(FOCAL_BOUNDARIES[i] + '-' + FOCAL_BOUNDARIES[i+1] + 'mm');
    }
    var binKeys = [];
    for (var i = 0; i < FOCAL_BOUNDARIES.length - 1; i++) {
        binKeys.push(FOCAL_BOUNDARIES[i] + '-' + FOCAL_BOUNDARIES[i+1]);
    }

    charts.zoomSweetSpot = new Chart(document.getElementById('zoomSweetSpotChart'), {
        type: 'bar',
        data: {
            labels: binLabels,
            datasets: zooms.map(function(z, i) {
                return {
                    label: z[0],
                    data: binKeys.map(function(bk){
                        return z[1].total > 0 ? Math.round((z[1].counts[bk]||0)/z[1].total*100) : 0;
                    }),
                    backgroundColor: COLOR_LIST[i % COLOR_LIST.length]
                };
            })
        },
        options: {
            responsive: true, maintainAspectRatio: true,
            plugins: {legend: {position: 'top', labels: {boxWidth: 12, font: {size: 11}}}},
            scales: {y: {ticks: {callback: function(v){return v+'%';}}}}
        }
    });
}

function renderFocalTimeline() {
    var byQ = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'], f = p['exif.focal_35mm'];
        if (!t || !f) return;
        var d = new Date(t);
        var q = d.getFullYear() + '-Q' + (Math.floor(d.getMonth()/3)+1);
        if (!byQ[q]) byQ[q] = [];
        byQ[q].push(f);
    });

    var quarters = Object.keys(byQ).sort();
    var avgData = quarters.map(function(q){
        return byQ[q].reduce(function(a,b){return a+b;},0) / byQ[q].length;
    });
    var medData = quarters.map(function(q){ return median(byQ[q]); });

    charts.focalTimeline = new Chart(document.getElementById('focalTimelineChart'), {
        type: 'line',
        data: {
            labels: quarters,
            datasets: [
                {label: 'Średnia', data: avgData, borderColor: COLORS.teal, backgroundColor: 'rgba(32,128,129,0.1)', tension: 0.4, fill: true, pointRadius: 2},
                {label: 'Mediana', data: medData, borderColor: COLORS.amber, backgroundColor: 'transparent', tension: 0.4, borderDash: [5,5], pointRadius: 2}
            ]
        },
        options: {responsive: true, maintainAspectRatio: true, plugins: {legend: {display: true}}, scales: {y: {beginAtZero: false}}}
    });
}

// --- Exposure ---

function renderApertureChart(stats) {
    var bins = getApertureBins(stats.apertures.filter(function(a){return a >= 1.0;}));
    charts.aperture = new Chart(document.getElementById('apertureChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Ilość', data: Object.values(bins), backgroundColor: COLORS.amber, borderColor: '#d97706', borderWidth: 1}]
        },
        options: barOpts()
    });
}

function renderIsoChart(stats) {
    var isoCounts = {};
    stats.isos.forEach(function(iso) { isoCounts[iso] = (isoCounts[iso]||0)+1; });
    var sorted = Object.entries(isoCounts).sort(function(a,b){return b[1]-a[1];});
    charts.iso = new Chart(document.getElementById('isoChart'), {
        type: 'bar',
        data: {
            labels: sorted.map(function(s){return s[0];}),
            datasets: [{label: 'Ilość', data: sorted.map(function(s){return s[1];}), backgroundColor: COLORS.green}]
        },
        options: barOpts()
    });
}

function renderIsoTrendChart() {
    var byYear = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'], iso = p['exif.iso'];
        if (!t || !iso) return;
        var y = new Date(t).getFullYear();
        if (!byYear[y]) byYear[y] = [];
        byYear[y].push(iso);
    });
    var years = Object.keys(byYear).sort();
    charts.isoTrend = new Chart(document.getElementById('isoTrendChart'), {
        type: 'line',
        data: {
            labels: years,
            datasets: [{
                label: 'Mediana ISO',
                data: years.map(function(y){ return median(byYear[y]); }),
                borderColor: COLORS.green, backgroundColor: 'rgba(34,197,94,0.1)',
                tension: 0.4, fill: true, pointRadius: 3
            }]
        },
        options: {responsive: true, maintainAspectRatio: true, plugins: {legend: {display: false}}}
    });
}

function renderExposureChart(stats) {
    var bins = {'1/1000':0,'1/500':0,'1/250':0,'1/125':0,'1/60':0,'1/30':0,'1/15':0,'1/8':0,'1/4':0,'1/2':0,'1s':0,'1-2s':0,'2-5s':0,'5-10s':0,'>10s':0};
    stats.exposures.forEach(function(e) {
        if (e < 0.001) bins['1/1000']++;
        else if (e < 0.002) bins['1/500']++;
        else if (e < 0.004) bins['1/250']++;
        else if (e < 0.008) bins['1/125']++;
        else if (e < 0.016) bins['1/60']++;
        else if (e < 0.033) bins['1/30']++;
        else if (e < 0.066) bins['1/15']++;
        else if (e < 0.125) bins['1/8']++;
        else if (e < 0.25) bins['1/4']++;
        else if (e < 0.5) bins['1/2']++;
        else if (e < 1) bins['1s']++;
        else if (e < 2) bins['1-2s']++;
        else if (e < 5) bins['2-5s']++;
        else if (e < 10) bins['5-10s']++;
        else bins['>10s']++;
    });
    charts.exposure = new Chart(document.getElementById('exposureChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Ilość', data: Object.values(bins), backgroundColor: COLORS.purple}]
        },
        options: barOpts()
    });
}

// --- Shooting Patterns ---

function renderHourChart() {
    var hourCounts = new Array(24).fill(0);
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (t && t.indexOf('T') !== -1) {
            hourCounts[parseInt(t.split('T')[1].substring(0,2))]++;
        }
    });
    var labels = [];
    for (var i = 0; i < 24; i++) labels.push(i + ':00');
    charts.hour = new Chart(document.getElementById('hourChart'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{label: 'Zdjęcia', data: hourCounts, backgroundColor: COLORS.indigo}]
        },
        options: barOpts()
    });
}

function renderDayOfWeekChart() {
    var dayCounts = new Array(7).fill(0);
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (t) dayCounts[new Date(t).getDay()]++;
    });
    charts.dayOfWeek = new Chart(document.getElementById('dayOfWeekChart'), {
        type: 'bar',
        data: {
            labels: DAYS_PL,
            datasets: [{label: 'Zdjęcia', data: dayCounts,
                backgroundColor: dayCounts.map(function(_, i){return (i===0||i===6) ? COLORS.teal : COLORS.blue;})
            }]
        },
        options: barOpts()
    });
}

function renderHourMonthHeatmap() {
    // Only render if matrix plugin available
    if (!Chart.controllers || !Chart.controllers.matrix) {
        // Fallback: skip heatmap
        return;
    }

    var grid = {};
    var maxVal = 0;
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (!t || t.indexOf('T') === -1) return;
        var month = new Date(t).getMonth(); // 0-11
        var hour = parseInt(t.split('T')[1].substring(0,2));
        var key = month + '-' + hour;
        grid[key] = (grid[key]||0) + 1;
        if (grid[key] > maxVal) maxVal = grid[key];
    });

    var data = [];
    // Only include hours 5-22 for readability
    var hours = [];
    for (var h = 5; h <= 22; h++) hours.push(h);
    for (var m = 0; m < 12; m++) {
        hours.forEach(function(h) {
            data.push({x: h + ':00', y: MONTHS_PL[m], v: grid[m + '-' + h] || 0});
        });
    }

    charts.hourMonth = new Chart(document.getElementById('hourMonthChart'), {
        type: 'matrix',
        data: {
            datasets: [{
                data: data,
                backgroundColor: function(ctx) {
                    var v = ctx.dataset.data[ctx.dataIndex].v;
                    var alpha = maxVal > 0 ? Math.min(v / (maxVal * 0.7), 1) : 0;
                    return 'rgba(32, 128, 129, ' + (alpha * 0.9 + 0.05) + ')';
                },
                borderColor: function(ctx) {
                    var v = ctx.dataset.data[ctx.dataIndex].v;
                    return v > 0 ? 'rgba(32, 128, 129, 0.3)' : 'rgba(128,128,128,0.1)';
                },
                borderWidth: 1,
                width: function(ctx) {
                    var a = ctx.chart.chartArea;
                    return a ? (a.right - a.left) / hours.length - 2 : 0;
                },
                height: function(ctx) {
                    var a = ctx.chart.chartArea;
                    return a ? (a.bottom - a.top) / 12 - 2 : 0;
                }
            }]
        },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: {display: false},
                tooltip: {
                    callbacks: {
                        title: function() { return ''; },
                        label: function(ctx) {
                            var d = ctx.dataset.data[ctx.dataIndex];
                            return d.y + ' ' + d.x + ': ' + d.v + ' zdjęć';
                        }
                    }
                }
            },
            scales: {
                x: {type: 'category', labels: hours.map(function(h){return h+':00';}), offset: true, grid: {display: false}},
                y: {type: 'category', labels: MONTHS_PL, offset: true, grid: {display: false}}
            }
        }
    });
}

function renderIntervalChart() {
    // Group photos by date, calculate intervals between consecutive shots
    var byDate = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (!t) return;
        var day = t.substring(0, 10);
        if (!byDate[day]) byDate[day] = [];
        byDate[day].push(new Date(t).getTime());
    });

    var bins = {'<30s':0, '30s-2min':0, '2-5min':0, '5-15min':0, '15-30min':0, '30-60min':0, '>1h':0};
    Object.values(byDate).forEach(function(times) {
        times.sort(function(a,b){return a-b;});
        for (var i = 1; i < times.length; i++) {
            var diffSec = (times[i] - times[i-1]) / 1000;
            if (diffSec < 30) bins['<30s']++;
            else if (diffSec < 120) bins['30s-2min']++;
            else if (diffSec < 300) bins['2-5min']++;
            else if (diffSec < 900) bins['5-15min']++;
            else if (diffSec < 1800) bins['15-30min']++;
            else if (diffSec < 3600) bins['30-60min']++;
            else bins['>1h']++;
        }
    });

    charts.interval = new Chart(document.getElementById('intervalChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Interwały', data: Object.values(bins), backgroundColor: COLORS.pink}]
        },
        options: barOpts()
    });
}

function renderPhotosPerTripChart() {
    // Count photos per unique shooting day
    var byDate = {};
    filteredPhotos.forEach(function(p) {
        var t = p['exif.time'];
        if (!t) return;
        var day = t.substring(0, 10);
        byDate[day] = (byDate[day]||0) + 1;
    });

    var counts = Object.values(byDate);
    var bins = {'1-5':0, '6-10':0, '11-20':0, '21-50':0, '51-100':0, '101-200':0, '>200':0};
    counts.forEach(function(c) {
        if (c <= 5) bins['1-5']++;
        else if (c <= 10) bins['6-10']++;
        else if (c <= 20) bins['11-20']++;
        else if (c <= 50) bins['21-50']++;
        else if (c <= 100) bins['51-100']++;
        else if (c <= 200) bins['101-200']++;
        else bins['>200']++;
    });

    charts.photosPerTrip = new Chart(document.getElementById('photosPerTripChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Wycieczki', data: Object.values(bins), backgroundColor: COLORS.orange}]
        },
        options: barOpts()
    });
}

// --- Geography & Topics ---

function renderAltitudeChart(stats) {
    if (stats.altitudes.length === 0) return;
    var bins = {'0-100m':0,'100-200m':0,'200-300m':0,'300-500m':0,'500-750m':0,
        '750-1000m':0,'1000-1500m':0,'1500-2000m':0,'2000-3000m':0,'3000-4000m':0};
    stats.altitudes.forEach(function(a) {
        if (a < 100) bins['0-100m']++;
        else if (a < 200) bins['100-200m']++;
        else if (a < 300) bins['200-300m']++;
        else if (a < 500) bins['300-500m']++;
        else if (a < 750) bins['500-750m']++;
        else if (a < 1000) bins['750-1000m']++;
        else if (a < 1500) bins['1000-1500m']++;
        else if (a < 2000) bins['1500-2000m']++;
        else if (a < 3000) bins['2000-3000m']++;
        else bins['3000-4000m']++;
    });
    charts.altitude = new Chart(document.getElementById('altitudeChart'), {
        type: 'bar',
        data: {
            labels: Object.keys(bins),
            datasets: [{label: 'Zdjęcia', data: Object.values(bins), backgroundColor: COLORS.cyan}]
        },
        options: barOpts()
    });
}

function renderTagsChart() {
    var tagCounts = {};
    filteredPhotos.forEach(function(p) {
        (p.tags || []).forEach(function(t) { tagCounts[t] = (tagCounts[t]||0)+1; });
    });
    var top = topN(tagCounts, 20);
    if (top.length === 0) return;
    charts.tags = new Chart(document.getElementById('tagsChart'), {
        type: 'bar',
        data: {
            labels: top.map(function(t){return tagNames[t[0]] || t[0];}),
            datasets: [{label: 'Zdjęcia', data: top.map(function(t){return t[1];}), backgroundColor: COLORS.purple}]
        },
        options: barOpts({indexAxis:'y', scales:{x:{beginAtZero:true}}})
    });
}

// ============================================================================
// MASTER UPDATE
// ============================================================================
function updateDashboard() {
    updateFilters();
    updateStats();
    updateCharts();
}

// CSV export (hidden but available)
function downloadStats() {
    var stats = calculateStats(filteredPhotos);
    var csv = 'Metryka,Wartość\n';
    csv += 'Wszystkie zdjęcia,' + stats.totalPhotos + '\n';
    csv += 'Opublikowane,' + stats.publishedCount + '\n';
    if (stats.focalLengths.length > 0)
        csv += 'Średnia ogniskowa,' + (stats.focalLengths.reduce(function(a,b){return a+b;},0)/stats.focalLengths.length).toFixed(0) + '\n';
    if (stats.apertures.length > 0)
        csv += 'Średnia przysłona,' + (stats.apertures.reduce(function(a,b){return a+b;},0)/stats.apertures.length).toFixed(1) + '\n';
    var blob = new Blob([csv], {type:'text/csv'});
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'statystyka-zdjec.csv';
    a.click();
}

// ============================================================================
// INIT
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
    setupChartDefaults();
    loadPhotos();

    ['yearFilter', 'cameraFilter', 'lensFilter', 'includeNonInterchangeable'].forEach(function(id) {
        document.getElementById(id).addEventListener('change', function() {
            updateStats();
            updateCharts();
        });
    });
});
