// focal_heatmap.js — Canvas-based focal length streamgraph.
//
// Renders a normalized stacked area chart (streamgraph) where:
//   X = time (months), each vertical slice = 100% height
//   Band thickness = share of photos at that focal length
//   Band color = focal length (indigo=wide → blue → green → amber → red → magenta=tele)
//
// Wide focal lengths always at the bottom, tele at the top.
// Data is smoothed with a configurable Gaussian window (default 3 months)
// to remove spikes. Empty months inherit from neighbors.
//
// Usage:
//   FocalHeatmap.create(canvasId, photos, options);
//   FocalHeatmap.destroy(canvasId);
//
// Exported as window.FocalHeatmap for use by exif_stats.js.

(function() {
    'use strict';

    // --- Focal length color palette ---
    // Maps focal length (log scale) to color.
    // 15mm=deep indigo, 24mm=blue, 50mm=green, 150mm=amber, 300mm=red, 600mm=magenta.
    // Interpolated continuously so every focal length gets a unique color.
    var FOCAL_COLORS = [
        { focal: 10,  rgb: [58, 12, 112] },   // deep indigo (ultrawide)
        { focal: 15,  rgb: [74, 14, 143] },    // indigo
        { focal: 24,  rgb: [33, 150, 243] },   // blue
        { focal: 35,  rgb: [38, 166, 154] },   // teal
        { focal: 50,  rgb: [76, 175, 80] },    // green
        { focal: 70,  rgb: [139, 195, 74] },   // light green
        { focal: 100, rgb: [205, 220, 57] },   // lime-yellow
        { focal: 150, rgb: [255, 193, 7] },     // amber
        { focal: 200, rgb: [255, 152, 0] },     // orange
        { focal: 300, rgb: [255, 87, 34] },     // deep orange
        { focal: 450, rgb: [233, 30, 99] },     // magenta
        { focal: 600, rgb: [156, 39, 176] }     // purple (supertele)
    ];

    // focalToRGB maps a focal length (mm) to an RGB color via log-space interpolation.
    function focalToRGB(focalMM) {
        var logF = Math.log(focalMM);
        // Clamp to palette range
        if (logF <= Math.log(FOCAL_COLORS[0].focal)) return FOCAL_COLORS[0].rgb;
        if (logF >= Math.log(FOCAL_COLORS[FOCAL_COLORS.length - 1].focal)) {
            return FOCAL_COLORS[FOCAL_COLORS.length - 1].rgb;
        }
        // Find surrounding stops
        for (var i = 0; i < FOCAL_COLORS.length - 1; i++) {
            var logLo = Math.log(FOCAL_COLORS[i].focal);
            var logHi = Math.log(FOCAL_COLORS[i + 1].focal);
            if (logF >= logLo && logF <= logHi) {
                var t = (logF - logLo) / (logHi - logLo);
                var a = FOCAL_COLORS[i].rgb, b = FOCAL_COLORS[i + 1].rgb;
                return [
                    Math.round(a[0] + (b[0] - a[0]) * t),
                    Math.round(a[1] + (b[1] - a[1]) * t),
                    Math.round(a[2] + (b[2] - a[2]) * t)
                ];
            }
        }
        return FOCAL_COLORS[0].rgb;
    }

    // --- Default bins ---
    // Generate ~30 logarithmically spaced focal length bins (10mm–600mm).
    // More bins = thinner bands = smoother gradient appearance.
    var DEFAULT_BINS = (function() {
        var NUM_BINS = 30;
        var logMin = Math.log(10), logMax = Math.log(600);
        var step = (logMax - logMin) / NUM_BINS;
        var bins = [];
        for (var i = 0; i <= NUM_BINS; i++) {
            bins.push(Math.round(Math.exp(logMin + i * step)));
        }
        return bins;
    })();

    // Representative focal length for each bin (geometric mean of bin edges).
    function binFocal(bins, binIdx) {
        return Math.sqrt(bins[binIdx] * bins[binIdx + 1]);
    }

    // --- Data processing ---

    // buildGrid creates a 2D grid: grid[binIdx][monthIdx] = photo count.
    function buildGrid(photos, bins) {
        var tempGrid = {}; // 'YYYY-MM' → {binIdx: count}

        photos.forEach(function(p) {
            var f = p['exif.focal_35mm'], t = p['exif.time'];
            if (!f || !t) return;
            var d = new Date(t);
            var key = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2);
            if (!tempGrid[key]) tempGrid[key] = {};
            for (var i = 0; i < bins.length - 1; i++) {
                if (f >= bins[i] && f < bins[i + 1]) {
                    tempGrid[key][i] = (tempGrid[key][i] || 0) + 1;
                    break;
                }
            }
        });

        // Collect and fill gaps
        var monthKeys = Object.keys(tempGrid).sort();
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

        var numBins = bins.length - 1;
        var numMonths = monthKeys.length;
        var grid = [];
        for (var bi = 0; bi < numBins; bi++) {
            grid[bi] = new Float32Array(numMonths);
            for (var mi = 0; mi < numMonths; mi++) {
                grid[bi][mi] = (tempGrid[monthKeys[mi]] || {})[bi] || 0;
            }
        }

        return { grid: grid, months: monthKeys, bins: bins, numBins: numBins, numMonths: numMonths };
    }

    // smoothRows applies Gaussian smoothing along the time axis (per bin row).
    // radius is in months (e.g., 3 = ±3 months window).
    function smoothRows(data, radius) {
        var numBins = data.numBins, numMonths = data.numMonths;
        var smoothed = [];
        for (var bi = 0; bi < numBins; bi++) {
            smoothed[bi] = new Float32Array(numMonths);
        }

        for (var b = 0; b < numBins; b++) {
            for (var m = 0; m < numMonths; m++) {
                var sum = 0, weight = 0;
                for (var dm = -radius; dm <= radius; dm++) {
                    var mm = m + dm;
                    if (mm < 0 || mm >= numMonths) continue;
                    var w = Math.exp(-(dm * dm) / (2 * radius * radius / 4 + 0.5));
                    sum += data.grid[b][mm] * w;
                    weight += w;
                }
                smoothed[b][m] = weight > 0 ? sum / weight : 0;
            }
        }

        return {
            grid: smoothed, months: data.months, bins: data.bins,
            numBins: numBins, numMonths: numMonths
        };
    }

    // normalizeToShares converts each column to shares summing to 1.0.
    // If a column is all zeros, distributes evenly.
    function normalizeToShares(data) {
        var numBins = data.numBins, numMonths = data.numMonths;
        var shares = [];
        for (var b = 0; b < numBins; b++) {
            shares[b] = new Float32Array(numMonths);
        }

        for (var m = 0; m < numMonths; m++) {
            var colSum = 0;
            for (var b2 = 0; b2 < numBins; b2++) {
                colSum += data.grid[b2][m];
            }
            if (colSum > 0) {
                for (var b3 = 0; b3 < numBins; b3++) {
                    shares[b3][m] = data.grid[b3][m] / colSum;
                }
            } else {
                // Empty column: inherit from nearest non-empty neighbors
                // (smoothing should have mostly eliminated this, but just in case)
                var even = 1.0 / numBins;
                for (var b4 = 0; b4 < numBins; b4++) {
                    shares[b4][m] = even;
                }
            }
        }

        return {
            grid: shares, months: data.months, bins: data.bins,
            numBins: numBins, numMonths: numMonths
        };
    }

    // computeCumulativeShares builds stacked Y positions for the streamgraph.
    // Returns cumY[binIdx][monthIdx] = bottom edge of that band (0..1).
    // Band top = cumY[binIdx+1][monthIdx]. cumY[numBins] = 1.0 for all months.
    // Bins stacked bottom-to-top: bin 0 (widest) at bottom.
    function computeCumulativeShares(shares) {
        var numBins = shares.numBins, numMonths = shares.numMonths;
        var cumY = [];
        for (var b = 0; b <= numBins; b++) {
            cumY[b] = new Float32Array(numMonths);
        }

        for (var m = 0; m < numMonths; m++) {
            var acc = 0;
            for (var b2 = 0; b2 < numBins; b2++) {
                cumY[b2][m] = acc;
                acc += shares.grid[b2][m];
            }
            cumY[numBins][m] = 1.0;
        }

        return cumY;
    }

    // --- Rendering ---

    function renderStreamgraph(canvas, shares, cumY, options) {
        var opts = options || {};
        var marginLeft = opts.marginLeft || 50;
        var marginBottom = opts.marginBottom || 50;
        var marginTop = opts.marginTop || 10;
        var marginRight = opts.marginRight || 10;

        // Canvas sizing — fit within parent container, never overflow.
        var container = canvas.parentElement;
        var dpr = window.devicePixelRatio || 1;
        var displayWidth = container.clientWidth;
        var displayHeight = Math.min(opts.height || 300, container.clientHeight || 300);
        canvas.style.width = '100%';
        canvas.style.height = displayHeight + 'px';
        canvas.style.display = 'block';
        canvas.width = displayWidth * dpr;
        canvas.height = displayHeight * dpr;

        var ctx = canvas.getContext('2d');
        ctx.scale(dpr, dpr);

        var plotW = displayWidth - marginLeft - marginRight;
        var plotH = displayHeight - marginTop - marginBottom;
        var numMonths = shares.numMonths;
        var numBins = shares.numBins;

        // Helper: month index → x pixel
        function xAt(mi) {
            return marginLeft + (mi / (numMonths - 1)) * plotW;
        }
        // Helper: share fraction (0..1) → y pixel (0=top, 1=bottom)
        function yAt(frac) {
            return marginTop + (1 - frac) * plotH;
        }

        // Draw each band with a vertical gradient fill (bottom color → top color).
        // Combined with ~30 thin bins, this produces a smooth continuous gradient.
        for (var b = 0; b < numBins; b++) {
            // Colors at bottom and top edges of this band
            var rgbBottom = focalToRGB(shares.bins[b]);
            var rgbTop = focalToRGB(shares.bins[b + 1]);

            // Find the vertical extent of this band for the gradient direction.
            // Use the average Y positions across all months for a stable gradient.
            var avgYBot = 0, avgYTop = 0;
            for (var mg = 0; mg < numMonths; mg++) {
                avgYBot += yAt(cumY[b][mg]);
                avgYTop += yAt(cumY[b + 1][mg]);
            }
            avgYBot /= numMonths;
            avgYTop /= numMonths;

            // Vertical gradient from bottom edge color to top edge color
            var grad = ctx.createLinearGradient(0, avgYBot, 0, avgYTop);
            grad.addColorStop(0, 'rgb(' + rgbBottom[0] + ',' + rgbBottom[1] + ',' + rgbBottom[2] + ')');
            grad.addColorStop(1, 'rgb(' + rgbTop[0] + ',' + rgbTop[1] + ',' + rgbTop[2] + ')');

            ctx.beginPath();
            // Top edge: left to right
            ctx.moveTo(xAt(0), yAt(cumY[b + 1][0]));
            for (var m = 1; m < numMonths; m++) {
                ctx.lineTo(xAt(m), yAt(cumY[b + 1][m]));
            }
            // Bottom edge: right to left
            for (var m2 = numMonths - 1; m2 >= 0; m2--) {
                ctx.lineTo(xAt(m2), yAt(cumY[b][m2]));
            }
            ctx.closePath();
            ctx.fillStyle = grad;
            ctx.fill();
        }

        // --- X-axis labels (years) ---
        var textColor = getComputedStyle(document.body).color || '#333';
        ctx.fillStyle = textColor;
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        for (var mi = 0; mi < numMonths; mi++) {
            var parts = shares.months[mi].split('-');
            if (parts[1] === '01') {
                var xPos = xAt(mi);
                ctx.fillText(parts[0], xPos, marginTop + plotH + 4);
                // Subtle vertical grid line
                ctx.strokeStyle = 'rgba(255,255,255,0.1)';
                ctx.beginPath();
                ctx.moveTo(xPos, marginTop);
                ctx.lineTo(xPos, marginTop + plotH);
                ctx.stroke();
            }
        }

        // --- Color legend bar (horizontal, below chart) ---
        var legendY = marginTop + plotH + 22;
        var legendH = 12;
        var legendLeft = marginLeft;
        var legendRight = marginLeft + plotW;
        var legendW = legendRight - legendLeft;

        for (var lx = 0; lx < legendW; lx++) {
            var t = lx / legendW;
            // Map 0..1 to focal range (log scale)
            var logMin = Math.log(shares.bins[0]);
            var logMax = Math.log(shares.bins[shares.bins.length - 1]);
            var focalAtT = Math.exp(logMin + t * (logMax - logMin));
            var lrgb = focalToRGB(focalAtT);
            ctx.fillStyle = 'rgb(' + lrgb[0] + ',' + lrgb[1] + ',' + lrgb[2] + ')';
            ctx.fillRect(legendLeft + lx, legendY, 1, legendH);
        }

        // Legend focal labels
        ctx.fillStyle = textColor;
        ctx.font = '9px sans-serif';
        ctx.textBaseline = 'top';
        var legendLabels = [15, 24, 50, 100, 200, 400];
        for (var li = 0; li < legendLabels.length; li++) {
            var lf = legendLabels[li];
            var logMin2 = Math.log(shares.bins[0]);
            var logMax2 = Math.log(shares.bins[shares.bins.length - 1]);
            var lt = (Math.log(lf) - logMin2) / (logMax2 - logMin2);
            ctx.textAlign = 'center';
            ctx.fillText(lf + 'mm', legendLeft + lt * legendW, legendY + legendH + 2);
        }
    }

    // --- Public API ---

    var instances = {};

    window.FocalHeatmap = {
        // create renders the streamgraph to the given canvas element.
        // photos: array of photo objects with 'exif.focal_35mm' and 'exif.time'
        // options: {smoothRadius, height}
        create: function(canvasId, photos, options) {
            var opts = options || {};
            var canvas = document.getElementById(canvasId);
            if (!canvas) return null;

            var bins = DEFAULT_BINS;
            var data = buildGrid(photos, bins);

            // Smooth along time axis (default 3 months radius = ~6 month window)
            var radius = opts.smoothRadius !== undefined ? opts.smoothRadius : 3;
            if (radius > 0) {
                data = smoothRows(data, radius);
            }

            // Normalize each column to shares summing to 1.0
            var shares = normalizeToShares(data);
            var cumY = computeCumulativeShares(shares);

            renderStreamgraph(canvas, shares, cumY, opts);

            instances[canvasId] = { canvas: canvas, shares: shares, cumY: cumY, options: opts };
            return instances[canvasId];
        },

        destroy: function(canvasId) {
            if (instances[canvasId]) {
                var ctx = instances[canvasId].canvas.getContext('2d');
                ctx.clearRect(0, 0, instances[canvasId].canvas.width, instances[canvasId].canvas.height);
                delete instances[canvasId];
            }
        },

        // Expose for testing
        _buildGrid: buildGrid,
        _smoothRows: smoothRows,
        _normalizeToShares: normalizeToShares,
        _computeCumulativeShares: computeCumulativeShares,
        _focalToRGB: focalToRGB
    };
})();
