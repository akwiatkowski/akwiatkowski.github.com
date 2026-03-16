// focal_heatmap.js — Canvas-based focal length × time heatmap.
//
// Renders a smooth gradient heatmap where:
//   X = time (months), Y = focal length bins (log scale)
//   Color intensity = photo count (normalized per column)
//
// The raw grid is rendered to a tiny offscreen canvas, then scaled up
// with browser image smoothing for a natural gradient appearance.
//
// Usage:
//   var heatmap = FocalHeatmap.create(canvasId, photos, options);
//   heatmap.destroy();  // cleanup
//
// Exported as window.FocalHeatmap for use by exif_stats.js.

(function() {
    'use strict';

    // --- Color scale ---
    // Attempt 1: viridis-inspired perceptually uniform palette.
    // Maps 0..1 intensity to dark purple → blue → teal → green → yellow.
    // Better than rainbow for heatmaps: no luminance reversals, colorblind safe.
    var PALETTE = [
        [13, 8, 35],     // 0.0 — dark purple (background)
        [53, 14, 90],     // 0.1
        [94, 17, 110],    // 0.2
        [136, 34, 106],   // 0.3
        [168, 62, 85],    // 0.4
        [196, 97, 58],    // 0.5
        [218, 139, 33],   // 0.6
        [233, 184, 29],   // 0.7
        [241, 229, 55],   // 0.8
        [252, 254, 164]   // 1.0 — bright yellow (hotspot)
    ];

    function intensityToRGB(t) {
        // t in [0, 1] → interpolate through PALETTE
        t = Math.max(0, Math.min(1, t));
        var idx = t * (PALETTE.length - 1);
        var lo = Math.floor(idx);
        var hi = Math.min(lo + 1, PALETTE.length - 1);
        var frac = idx - lo;
        return [
            Math.round(PALETTE[lo][0] + (PALETTE[hi][0] - PALETTE[lo][0]) * frac),
            Math.round(PALETTE[lo][1] + (PALETTE[hi][1] - PALETTE[lo][1]) * frac),
            Math.round(PALETTE[lo][2] + (PALETTE[hi][2] - PALETTE[lo][2]) * frac)
        ];
    }

    // --- Data processing ---

    // Default focal length bins (35mm equivalent), logarithmically spaced.
    var DEFAULT_BINS = [10, 14, 20, 28, 35, 50, 70, 100, 135, 200, 280, 400, 600];

    // buildGrid creates a 2D grid: grid[binIdx][monthIdx] = count.
    // Returns {grid, months, bins, maxCount}.
    function buildGrid(photos, bins) {
        var monthMap = {};  // 'YYYY-MM' → column index
        var monthKeys = []; // sorted month keys

        // First pass: collect all months and bin photos
        var tempGrid = {}; // 'YYYY-MM' → {binIdx: count}
        photos.forEach(function(p) {
            var f = p['exif.focal_35mm'], t = p['exif.time'];
            if (!f || !t) return;
            var d = new Date(t);
            var key = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2);
            if (!tempGrid[key]) tempGrid[key] = {};
            // Find bin
            for (var i = 0; i < bins.length - 1; i++) {
                if (f >= bins[i] && f < bins[i + 1]) {
                    tempGrid[key][i] = (tempGrid[key][i] || 0) + 1;
                    break;
                }
            }
        });

        monthKeys = Object.keys(tempGrid).sort();

        // Fill gaps: add empty months between first and last
        if (monthKeys.length > 1) {
            var allMonths = [];
            var first = monthKeys[0].split('-'), last = monthKeys[monthKeys.length - 1].split('-');
            var y = parseInt(first[0]), m = parseInt(first[1]);
            var endY = parseInt(last[0]), endM = parseInt(last[1]);
            while (y < endY || (y === endY && m <= endM)) {
                var k = y + '-' + ('0' + m).slice(-2);
                allMonths.push(k);
                if (!tempGrid[k]) tempGrid[k] = {};
                m++;
                if (m > 12) { m = 1; y++; }
            }
            monthKeys = allMonths;
        }

        // Build 2D grid: rows = bins (bottom=wide, top=tele), cols = months
        var numBins = bins.length - 1;
        var numMonths = monthKeys.length;
        var grid = [];
        var maxCount = 0;
        for (var bi = 0; bi < numBins; bi++) {
            grid[bi] = new Float32Array(numMonths);
            for (var mi = 0; mi < numMonths; mi++) {
                var count = (tempGrid[monthKeys[mi]] || {})[bi] || 0;
                grid[bi][mi] = count;
                if (count > maxCount) maxCount = count;
            }
        }

        return {grid: grid, months: monthKeys, bins: bins, numBins: numBins, numMonths: numMonths, maxCount: maxCount};
    }

    // smoothGrid applies a Gaussian-like smoothing kernel to the grid.
    // radiusX/radiusY control the smoothing window in each dimension.
    function smoothGrid(data, radiusX, radiusY) {
        var numBins = data.numBins, numMonths = data.numMonths;
        var smoothed = [];
        for (var bi = 0; bi < numBins; bi++) {
            smoothed[bi] = new Float32Array(numMonths);
        }

        var maxVal = 0;
        for (var b = 0; b < numBins; b++) {
            for (var m = 0; m < numMonths; m++) {
                var sum = 0, weight = 0;
                for (var db = -radiusY; db <= radiusY; db++) {
                    for (var dm = -radiusX; dm <= radiusX; dm++) {
                        var bb = b + db, mm = m + dm;
                        if (bb < 0 || bb >= numBins || mm < 0 || mm >= numMonths) continue;
                        // Gaussian weight: closer cells contribute more
                        var w = Math.exp(-(db * db) / (2 * radiusY * radiusY + 0.5)
                                        -(dm * dm) / (2 * radiusX * radiusX + 0.5));
                        sum += data.grid[bb][mm] * w;
                        weight += w;
                    }
                }
                var val = weight > 0 ? sum / weight : 0;
                smoothed[b][m] = val;
                if (val > maxVal) maxVal = val;
            }
        }

        return {
            grid: smoothed, months: data.months, bins: data.bins,
            numBins: numBins, numMonths: numMonths, maxCount: maxVal
        };
    }

    // normalizeColumns normalizes each column to [0, 1] by its column max.
    // This shows proportional distribution per month, not absolute counts.
    function normalizeColumns(data) {
        var norm = [];
        for (var b = 0; b < data.numBins; b++) {
            norm[b] = new Float32Array(data.numMonths);
        }

        for (var m = 0; m < data.numMonths; m++) {
            var colMax = 0;
            for (var b2 = 0; b2 < data.numBins; b2++) {
                if (data.grid[b2][m] > colMax) colMax = data.grid[b2][m];
            }
            for (var b3 = 0; b3 < data.numBins; b3++) {
                norm[b3][m] = colMax > 0 ? data.grid[b3][m] / colMax : 0;
            }
        }

        return {
            grid: norm, months: data.months, bins: data.bins,
            numBins: data.numBins, numMonths: data.numMonths, maxCount: 1
        };
    }

    // --- Rendering ---

    // renderToCanvas paints the heatmap onto the given canvas element.
    // Uses an offscreen canvas at native grid resolution, then scales up
    // with imageSmoothingEnabled for a smooth gradient effect.
    function renderToCanvas(canvas, data, options) {
        var opts = options || {};
        var marginLeft = opts.marginLeft || 60;
        var marginBottom = opts.marginBottom || 40;
        var marginTop = opts.marginTop || 10;
        var marginRight = opts.marginRight || 20;
        var legendWidth = opts.legendWidth || 15;
        var legendGap = opts.legendGap || 8;

        // Set canvas size from container
        var container = canvas.parentElement;
        var dpr = window.devicePixelRatio || 1;
        var displayWidth = container.clientWidth;
        var displayHeight = opts.height || 280;
        canvas.style.width = displayWidth + 'px';
        canvas.style.height = displayHeight + 'px';
        canvas.width = displayWidth * dpr;
        canvas.height = displayHeight * dpr;

        var ctx = canvas.getContext('2d');
        ctx.scale(dpr, dpr);

        var plotW = displayWidth - marginLeft - marginRight - legendWidth - legendGap;
        var plotH = displayHeight - marginTop - marginBottom;

        // --- Draw heatmap via offscreen canvas ---
        var offscreen = document.createElement('canvas');
        offscreen.width = data.numMonths;
        offscreen.height = data.numBins;
        var offCtx = offscreen.getContext('2d');
        var imgData = offCtx.createImageData(data.numMonths, data.numBins);

        var maxVal = data.maxCount || 1;
        for (var b = 0; b < data.numBins; b++) {
            for (var m = 0; m < data.numMonths; m++) {
                // Flip Y: row 0 = top = highest focal length (tele)
                var row = data.numBins - 1 - b;
                var idx = (row * data.numMonths + m) * 4;
                var intensity = data.grid[b][m] / maxVal;
                // Apply sqrt to spread out low values (perceptual scaling)
                intensity = Math.sqrt(intensity);
                var rgb = intensityToRGB(intensity);
                imgData.data[idx] = rgb[0];
                imgData.data[idx + 1] = rgb[1];
                imgData.data[idx + 2] = rgb[2];
                imgData.data[idx + 3] = 255;
            }
        }
        offCtx.putImageData(imgData, 0, 0);

        // Scale up with smooth interpolation
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(offscreen, marginLeft, marginTop, plotW, plotH);

        // --- Y-axis labels (focal lengths) ---
        ctx.fillStyle = getComputedStyle(document.body).color || '#333';
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'right';
        ctx.textBaseline = 'middle';
        var binLabels = [10, 14, 20, 28, 35, 50, 70, 100, 135, 200, 280, 400];
        for (var i = 0; i < data.bins.length - 1; i++) {
            var yFrac = 1 - (i + 0.5) / data.numBins; // top=tele, bottom=wide
            var yPos = marginTop + yFrac * plotH;
            ctx.fillText(binLabels[i] || data.bins[i], marginLeft - 4, yPos);
        }
        // "mm" label at top
        ctx.textAlign = 'center';
        ctx.fillText('mm', marginLeft - 20, marginTop - 2);

        // --- X-axis labels (years) ---
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        for (var mi = 0; mi < data.months.length; mi++) {
            var parts = data.months[mi].split('-');
            if (parts[1] === '01') {
                var xPos = marginLeft + (mi + 0.5) / data.numMonths * plotW;
                ctx.fillText(parts[0], xPos, marginTop + plotH + 4);
                // Tick line
                ctx.strokeStyle = 'rgba(128,128,128,0.3)';
                ctx.beginPath();
                ctx.moveTo(xPos, marginTop);
                ctx.lineTo(xPos, marginTop + plotH);
                ctx.stroke();
            }
        }

        // --- Color legend bar ---
        var legendX = marginLeft + plotW + legendGap;
        var legendH = plotH;
        for (var ly = 0; ly < legendH; ly++) {
            var t = 1 - ly / legendH; // top=1, bottom=0
            var rgb2 = intensityToRGB(Math.sqrt(t));
            ctx.fillStyle = 'rgb(' + rgb2[0] + ',' + rgb2[1] + ',' + rgb2[2] + ')';
            ctx.fillRect(legendX, marginTop + ly, legendWidth, 1);
        }
        // Legend labels
        ctx.textAlign = 'left';
        ctx.textBaseline = 'top';
        ctx.fillStyle = getComputedStyle(document.body).color || '#333';
        ctx.fillText('dużo', legendX + legendWidth + 3, marginTop);
        ctx.textBaseline = 'bottom';
        ctx.fillText('mało', legendX + legendWidth + 3, marginTop + legendH);
    }

    // --- Public API ---

    var instances = {};

    window.FocalHeatmap = {
        // create renders the heatmap to the given canvas element.
        // photos: array of photo objects with 'exif.focal_35mm' and 'exif.time'
        // options: {smoothX, smoothY, normalize, height}
        create: function(canvasId, photos, options) {
            var opts = options || {};
            var canvas = document.getElementById(canvasId);
            if (!canvas) return null;

            var bins = DEFAULT_BINS;
            var data = buildGrid(photos, bins);

            // Smooth: default 2 months horizontal, 1 bin vertical
            var sx = opts.smoothX !== undefined ? opts.smoothX : 2;
            var sy = opts.smoothY !== undefined ? opts.smoothY : 1;
            if (sx > 0 || sy > 0) {
                data = smoothGrid(data, sx, sy);
            }

            // Normalize columns so each month shows relative distribution
            if (opts.normalize !== false) {
                data = normalizeColumns(data);
            }

            renderToCanvas(canvas, data, opts);

            instances[canvasId] = {canvas: canvas, data: data, options: opts};
            return instances[canvasId];
        },

        // destroy cleans up a heatmap instance
        destroy: function(canvasId) {
            if (instances[canvasId]) {
                var ctx = instances[canvasId].canvas.getContext('2d');
                ctx.clearRect(0, 0, instances[canvasId].canvas.width, instances[canvasId].canvas.height);
                delete instances[canvasId];
            }
        },

        // Expose for testing
        _buildGrid: buildGrid,
        _smoothGrid: smoothGrid,
        _normalizeColumns: normalizeColumns,
        _intensityToRGB: intensityToRGB
    };
})();
