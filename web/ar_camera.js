// Grazia Stones AR Camera Engine — Hybrid AI + Local Tracking
// Real wall detection + perspective transform + realistic texture mapping
// Architecture:
//   CAMERA FRAME
//     ↓
//   FAST LOCAL PREPROCESSING (edge detection, downscaled)
//     ↓
//   AI WALL/OBJECT UNDERSTANDING (periodic, async, 3s interval)
//     ↓
//   WALL SEGMENTATION / REGION (polygon from AI, refined locally)
//     ↓
//   PLANE / QUAD ESTIMATION (homography from 4 corners)
//     ↓
//   TEMPORAL STABILIZATION (EMA smoothing, confidence gating)
//     ↓
//   TRACKING (local high-freq + AI low-freq correction)
//     ↓
//   OCCLUSION MASK (objects excluded from tile rendering)
//     ↓
//   TILE MATERIAL GENERATION (repeatable, perspective-correct, grout)
//     ↓
//   PERSPECTIVE / HOMOGRAPHY (quad warp)
//     ↓
//   LIGHTING / SHADOW / BLENDING (edge feather, luminance adaptation)
//     ↓
//   FINAL COMPOSITE

(function () {
  'use strict';

  // ── State ──────────────────────────────────────────────────────────────
  var _stream = null;
  var _video = null;
  var _canvas = null;
  var _ctx = null;
  var _textureImage = null;
  var _container = null;
  var _animationFrame = null;
  var _initDone = false;
  var _mediaRecorder = null;
  var _recordedChunks = [];

  // Wall detection state
  var _walls = [];           // Array of wall objects from AI + local refinement
  var _selectedWallId = null; // Currently selected wall for texturing
  var _manualCorners = null;  // User-dragged corner override {tl,tr,bl,br}
  var _hasRealLock = false;   // True once a real (non-fallback) wall was found
  var _lostFrames = 0;        // Consecutive frames without real edges
  var _lastAiCorners = null;  // Last AI-detected corners for each wall

  // AI-assisted wall detection (NVIDIA NIM, via server proxy) — periodic
  // correction on top of the local edge heuristic, not a per-frame replacement.
  // Now supports pixel-level segmentation masks from SAM.
  var _aiRequestInFlight = false;
  var _lastAiRequestAt = 0;
  var AI_REQUEST_INTERVAL_MS = 3000; // 3s for VLM, 10s for SAM (more expensive)

  // Object detection state
  var _objects = [];          // Array of detected objects (paintings, windows, etc.)

  // Stone control state
  var _opacity = 0.96;
  var _scale = 1.0;
  var _position = {x: 0, y: 0};
  var _rotation = 0;
  var _showWallBoundary = true;

  // Calibration state
  var _calibrationMode = false;
  var _calibrationPoints = [];
  var _pixelsPerUnit = null;  // pixels per foot/meter
  var _calibrationUnit = 'ft';

  // Performance monitoring
  var _frameCount = 0;
  var _lastFpsTime = Date.now();
  var _renderTime = 0;
  var _aiTime = 0;

  // Segmentation state
  var _segmentationRequested = false;
  var _lastSegmentationAt = 0;
  var SEGMENTATION_INTERVAL_MS = 10000; // SAM is expensive, run less frequently

  // Wall masks for pixel-level rendering
  var _wallMasks = {}; // wallId -> {polygon, maskCanvas, maskData}

  // ── Utility ────────────────────────────────────────────────────────────

  function _lerp(a, b, t) { return a + (b - a) * t; }

  function _lerpPt(a, b, t) {
    return { x: _lerp(a.x, b.x, t), y: _lerp(a.y, b.y, t) };
  }

  function _lerpCorners(from, to, t) {
    return {
      tl: _lerpPt(from.tl, to.tl, t),
      tr: _lerpPt(from.tr, to.tr, t),
      bl: _lerpPt(from.bl, to.bl, t),
      br: _lerpPt(from.br, to.br, t),
    };
  }

  function _avgCorners(cornersList) {
    if (!cornersList.length) return null;
    var sum = { tl: {x:0,y:0}, tr: {x:0,y:0}, bl: {x:0,y:0}, br: {x:0,y:0} };
    cornersList.forEach(function(c) {
      sum.tl.x += c.tl.x; sum.tl.y += c.tl.y;
      sum.tr.x += c.tr.x; sum.tr.y += c.tr.y;
      sum.bl.x += c.bl.x; sum.bl.y += c.bl.y;
      sum.br.x += c.br.x; sum.br.y += c.br.y;
    });
    var n = cornersList.length;
    return {
      tl: {x: sum.tl.x/n, y: sum.tl.y/n},
      tr: {x: sum.tr.x/n, y: sum.tr.y/n},
      bl: {x: sum.bl.x/n, y: sum.bl.y/n},
      br: {x: sum.br.x/n, y: sum.br.y/n},
    };
  }

  function _cornersToPolygon(corners) {
    return [
      [corners.tl.x, corners.tl.y],
      [corners.tr.x, corners.tr.y],
      [corners.br.x, corners.br.y],
      [corners.bl.x, corners.bl.y]
    ];
  }

  function _polygonToCorners(poly) {
    if (!poly || poly.length < 4) return null;
    return {
      tl: {x: poly[0][0], y: poly[0][1]},
      tr: {x: poly[1][0], y: poly[1][1]},
      br: {x: poly[2][0], y: poly[2][1]},
      bl: {x: poly[3][0], y: poly[3][1]},
    };
  }

  function _scaleCorners(corners, scaleX, scaleY) {
    return {
      tl: {x: corners.tl.x * scaleX, y: corners.tl.y * scaleY},
      tr: {x: corners.tr.x * scaleX, y: corners.tr.y * scaleY},
      bl: {x: corners.bl.x * scaleX, y: corners.bl.y * scaleY},
      br: {x: corners.br.x * scaleX, y: corners.br.y * scaleY},
    };
  }

  function _distance(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y;
    return Math.sqrt(dx*dx + dy*dy);
  }

  function _wallArea(corners) {
    // Shoelace formula for quad area
    var p = _cornersToPolygon(corners);
    var area = 0;
    for (var i = 0; i < 4; i++) {
      var j = (i + 1) % 4;
      area += p[i][0] * p[j][1];
      area -= p[j][0] * p[i][1];
    }
    return Math.abs(area) / 2;
  }

  // ── Container ──────────────────────────────────────────────────────────

  function _findContainer(containerId) {
    var el = document.getElementById(containerId);
    if (el) return el;

    var views = document.querySelectorAll('flt-platform-view');
    for (var i = 0; i < views.length; i++) {
      if (views[i].shadowRoot) {
        var inner = views[i].shadowRoot.getElementById(containerId);
        if (inner) return inner;
      }
      var child = views[i].querySelector('#' + containerId);
      if (child) return child;
    }

    var allEls = document.querySelectorAll('*');
    for (var j = 0; j < allEls.length; j++) {
      if (allEls[j].shadowRoot) {
        var found = allEls[j].shadowRoot.getElementById(containerId);
        if (found) return found;
      }
    }
    return null;
  }

  // ── Edge Detection (Fast Local Preprocessing) ──────────────────────────

  function _detectEdges(imageData, width, height) {
    var data = imageData.data;
    var edges = new Uint8Array(width * height);
    var threshold = 30;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        var idx = y * width + x;

        var gx = 0, gy = 0;

        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            var pixelIdx = ((y + dy) * width + (x + dx)) * 4;
            var gray = (data[pixelIdx] + data[pixelIdx + 1] + data[pixelIdx + 2]) / 3;

            if (dx === -1) gx -= gray * (dy === 0 ? 2 : 1);
            if (dx === 1) gx += gray * (dy === 0 ? 2 : 1);
            if (dy === -1) gy -= gray * (dx === 0 ? 2 : 1);
            if (dy === 1) gy += gray * (dx === 0 ? 2 : 1);
          }
        }

        var magnitude = Math.sqrt(gx * gx + gy * gy);
        edges[idx] = magnitude > threshold ? 255 : 0;
      }
    }
    return edges;
  }

  // Find largest rectangular region (wall candidate) from edges
  function _findWallRegion(edges, width, height) {
    var horizontalLines = [];
    var verticalLines = [];

    for (var y = 0; y < height; y += 4) {
      var strength = 0;
      for (var x = 0; x < width; x++) {
        if (edges[y * width + x] > 0) strength++;
      }
      if (strength > width * 0.22) horizontalLines.push({y: y, strength: strength});
    }

    for (var x = 0; x < width; x += 4) {
      var strength = 0;
      for (var y = 0; y < height; y++) {
        if (edges[y * width + x] > 0) strength++;
      }
      if (strength > height * 0.22) verticalLines.push({x: x, strength: strength});
    }

    if (horizontalLines.length >= 2 && verticalLines.length >= 2) {
      horizontalLines.sort(function (a, b) { return a.y - b.y; });
      verticalLines.sort(function (a, b) { return a.x - b.x; });
      var N = 3;
      var top = _avg(horizontalLines, 0, Math.min(N, horizontalLines.length), 'y');
      var bottom = _avg(horizontalLines, Math.max(0, horizontalLines.length - N), horizontalLines.length, 'y');
      var left = _avg(verticalLines, 0, Math.min(N, verticalLines.length), 'x');
      var right = _avg(verticalLines, Math.max(0, verticalLines.length - N), verticalLines.length, 'x');

      if (right - left > width * 0.3 && bottom - top > height * 0.3) {
        return {
          real: true,
          corners: { tl: {x: left, y: top}, tr: {x: right, y: top}, bl: {x: left, y: bottom}, br: {x: right, y: bottom} }
        };
      }
    }

    // Fallback: center region
    var margin = 0.15;
    return {
      real: false,
      corners: {
        tl: {x: width * margin, y: height * margin},
        tr: {x: width * (1 - margin), y: height * margin},
        bl: {x: width * margin, y: height * (1 - margin)},
        br: {x: width * (1 - margin), y: height * (1 - margin)}
      }
    };
  }

  function _avg(list, from, to, key) {
    var sum = 0, count = to - from;
    for (var i = from; i < to; i++) sum += list[i][key];
    return sum / count;
  }

  // ── Local Object Detection (Fallback for Occlusion) ──────────────────────
  // Detects rectangular objects on the wall (paintings, windows, doors, etc.)
  // from the edge map. Used when AI doesn't return reliable object polygons.

  function _findObjectsOnWall(edges, width, height, wallCorners) {
    var objects = [];
    var wallLeft = Math.min(wallCorners.tl.x, wallCorners.bl.x);
    var wallRight = Math.max(wallCorners.tr.x, wallCorners.br.x);
    var wallTop = Math.min(wallCorners.tl.y, wallCorners.tr.y);
    var wallBottom = Math.max(wallCorners.bl.y, wallCorners.br.y);
    var wallW = wallRight - wallLeft;
    var wallH = wallBottom - wallTop;

    // Skip if wall region is too small
    if (wallW < width * 0.2 || wallH < height * 0.2) return objects;

    // Scan for rectangular objects inside the wall region
    // Look for closed rectangular edge loops that are NOT the wall boundary
    var visited = new Uint8Array(width * height);

    function isWallBoundary(x, y) {
      // Check if point is near wall boundary (within 20px)
      var distToLeft = Math.abs(x - wallLeft);
      var distToRight = Math.abs(x - wallRight);
      var distToTop = Math.abs(y - wallTop);
      var distToBottom = Math.abs(y - wallBottom);
      return distToLeft < 20 || distToRight < 20 || distToTop < 20 || distToBottom < 20;
    }

    // Find connected components of edges inside wall region
    for (var y = Math.floor(wallTop) + 10; y < Math.floor(wallBottom) - 10; y += 2) {
      for (var x = Math.floor(wallLeft) + 10; x < Math.floor(wallRight) - 10; x += 2) {
        var idx = y * width + x;
        if (edges[idx] === 0 || visited[idx]) continue;
        if (isWallBoundary(x, y)) continue;

        // Flood fill to find connected edge component
        var component = [];
        var stack = [{x: x, y: y}];
        var minX = x, maxX = x, minY = y, maxY = y;

        while (stack.length) {
          var p = stack.pop();
          var px = p.x, py = p.y;
          var pidx = py * width + px;
          if (px < 0 || px >= width || py < 0 || py >= height) continue;
          if (visited[pidx] || edges[pidx] === 0) continue;
          if (isWallBoundary(px, py)) continue;
          
          // Check if inside wall bounds
          if (px < wallLeft + 10 || px > wallRight - 10 || py < wallTop + 10 || py > wallBottom - 10) continue;

          visited[pidx] = 1;
          component.push({x: px, y: py});
          minX = Math.min(minX, px); maxX = Math.max(maxX, px);
          minY = Math.min(minY, py); maxY = Math.max(maxY, py);

          stack.push({x: px + 1, y: py});
          stack.push({x: px - 1, y: py});
          stack.push({x: px, y: py + 1});
          stack.push({x: px, y: py - 1});
        }

        if (component.length < 50) continue; // Too small

        var compW = maxX - minX;
        var compH = maxY - minY;
        var compArea = compW * compH;
        var wallArea = wallW * wallH;

        // Filter: object should be 2-40% of wall area, roughly rectangular
        var areaRatio = compArea / wallArea;
        var aspectRatio = compW / compH;
        if (areaRatio < 0.02 || areaRatio > 0.4) continue;
        if (aspectRatio < 0.3 || aspectRatio > 3.5) continue;

        // Check rectangularity: edge density should be high on perimeter
        var perimeter = 2 * (compW + compH);
        var edgeCount = 0;
        for (var px = minX; px <= maxX; px++) {
          if (edges[minY * width + px]) edgeCount++;
          if (edges[maxY * width + px]) edgeCount++;
        }
        for (var py = minY; py <= maxY; py++) {
          if (edges[py * width + minX]) edgeCount++;
          if (edges[py * width + maxX]) edgeCount++;
        }
        var edgeDensity = edgeCount / perimeter;
        if (edgeDensity < 0.4) continue; // Not a clean rectangle

        // Classify object type based on position and aspect ratio
        var type = 'other';
        var relY = (minY - wallTop) / wallH;
        var relX = (minX - wallLeft) / wallW;
        
        if (aspectRatio > 1.5 && aspectRatio < 4 && relY > 0.1 && relY < 0.9) {
          type = 'painting'; // Horizontal rectangle, mid-wall
        } else if (aspectRatio > 2 && aspectRatio < 5 && relY > 0.3 && relY < 0.8) {
          type = 'window'; // Tall rectangle
        } else if (aspectRatio > 0.5 && aspectRatio < 1.5 && relY > 0.5) {
          type = 'furniture'; // Square-ish, lower wall
        } else if (aspectRatio > 0.2 && aspectRatio < 0.5) {
          type = 'door'; // Very tall
        }

        objects.push({
          type: type,
          confidence: 0.6,
          polygon: [
            [minX / width, minY / height],
            [maxX / width, minY / height],
            [maxX / width, maxY / height],
            [minX / width, maxY / height]
          ],
          corners: {
            tl: {x: minX, y: minY},
            tr: {x: maxX, y: minY},
            bl: {x: minX, y: maxY},
            br: {x: maxX, y: maxY}
          }
        });
      }
    }

    return objects;
  }

  // ── AI Wall Detection (Server Proxy) ───────────────────────────────────

  function _requestAiWallDetection(width, height) {
    if (_aiRequestInFlight || !_video || _video.readyState < 2) return;
    var now = Date.now();
    if (now - _lastAiRequestAt < AI_REQUEST_INTERVAL_MS) return;
    _lastAiRequestAt = now;
    _aiRequestInFlight = true;

    var snapW = 320;
    var snapH = Math.round((height / width) * snapW) || 240;
    var snapCanvas = document.createElement('canvas');
    snapCanvas.width = snapW;
    snapCanvas.height = snapH;
    snapCanvas.getContext('2d').drawImage(_video, 0, 0, snapW, snapH);
    var dataUrl = snapCanvas.toDataURL('image/jpeg', 0.6);

    // Request segmentation periodically (less frequent due to cost)
    var useSegmentation = _segmentationRequested || (now - _lastSegmentationAt > SEGMENTATION_INTERVAL_MS);
    if (useSegmentation) {
      _lastSegmentationAt = now;
      _segmentationRequested = false;
    }

    fetch('/api/wall-detect', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({image: dataUrl, useSegmentation: useSegmentation})
    })
      .then(function (r) { return r.json(); })
      .then(function (result) {
        if (!result || !result.wallDetected || !result.walls || !result.walls.length) return;

        var aiStart = Date.now();
        // Merge AI walls with local tracking
        _mergeAiWalls(result, width, height);
        _aiTime = Date.now() - aiStart;
      })
      .catch(function () { /* silent — local heuristic keeps running */ })
      .finally(function () { _aiRequestInFlight = false; });
  }

  function _mergeAiWalls(result, width, height) {
    var newWalls = [];
    var seenIds = new Set();

    result.walls.forEach(function(aiWall) {
      var corners = _polygonToCorners(aiWall.polygon);
      if (!corners) return;

      // Scale to full resolution
      corners = _scaleCorners(corners, width, height);

      // Find matching existing wall (by proximity)
      var matchIdx = -1;
      var bestDist = Infinity;
      _walls.forEach(function(existing, idx) {
        var d = _cornerDistance(existing.corners, corners);
        if (d < bestDist && d < Math.max(width, height) * 0.15) {
          bestDist = d;
          matchIdx = idx;
        }
      });

      var wallObj = {
        id: aiWall.id || 'wall_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9),
        corners: corners,
        aiCorners: corners,
        confidence: aiWall.confidence || 0.7,
        real: true,
        lastSeen: Date.now(),
        lockFrames: 0,
        pixelLevel: aiWall.pixelLevel || false,
        surfaceType: aiWall.surfaceType || 'flat'
      };

      // Store pixel-level mask if available
      if (aiWall.maskData) {
        _wallMasks[wallObj.id] = {
          polygon: aiWall.polygon,
          maskData: aiWall.maskData
        };
      }

      if (matchIdx >= 0) {
        // Smooth blend with existing wall
        var existing = _walls[matchIdx];
        wallObj.corners = _lerpCorners(existing.corners, corners, existing.lockFrames > 10 ? 0.1 : 0.3);
        wallObj.lockFrames = existing.lockFrames + 1;
        seenIds.add(wallObj.id);
        newWalls[matchIdx] = wallObj;
      } else {
        seenIds.add(wallObj.id);
        newWalls.push(wallObj);
      }
    });

    // Update objects
    if (result.objects && result.objects.length) {
      _objects = result.objects.map(function(obj) {
        var corners = obj.polygon ? _polygonToCorners(obj.polygon) : null;
        var objData = {
          type: obj.type || 'other',
          confidence: obj.confidence || 0.5,
          polygon: obj.polygon || [],
          corners: corners,
          pixelLevel: obj.pixelLevel || false
        };
        if (obj.maskData) {
          objData.maskData = obj.maskData;
        }
        return objData;
      });
    }

    // Remove walls not seen in AI for too long
    _walls = _walls.filter(function(w) { return seenIds.has(w.id) || (Date.now() - w.lastSeen < 5000); });

    // Add new walls
    result.walls.forEach(function(aiWall) {
      var corners = _polygonToCorners(aiWall.polygon);
      if (!corners) return;
      corners = _scaleCorners(corners, width, height);
      var exists = _walls.some(function(w) { return _cornerDistance(w.corners, corners) < Math.max(width, height) * 0.1; });
      if (!exists) {
        _walls.push({
          id: aiWall.id || 'wall_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9),
          corners: corners,
          aiCorners: corners,
          confidence: aiWall.confidence || 0.7,
          real: true,
          lastSeen: Date.now(),
          lockFrames: 0,
          pixelLevel: aiWall.pixelLevel || false
        });
      }
    });

    // Auto-select first wall if none selected
    if (_selectedWallId === null && _walls.length > 0) {
      _selectedWallId = _walls[0].id;
    }
  }

  function _cornerDistance(c1, c2) {
    return (
      _distance(c1.tl, c2.tl) +
      _distance(c1.tr, c2.tr) +
      _distance(c1.bl, c2.bl) +
      _distance(c1.br, c2.br)
    ) / 4;
  }

  // ── Texture & Rendering ────────────────────────────────────────────────

  // Store tile dimensions for accurate pattern generation
  var _currentTileWidth = 600; // mm
  var _currentTileHeight = 600; // mm
  var _currentTileUnit = 'mm';

  function _createTilePattern(texture, wallWidthPx, wallHeightPx, tileWidthMm, tileHeightMm, tileUnit) {
    // Convert tile dimensions to pixels based on wall size
    // We need to calculate the pixel size of one tile based on wall dimensions
    var tileWidthPx, tileHeightPx;
    
    if (tileUnit === 'mm') {
      tileWidthPx = (tileWidthMm / 1000) * wallWidthPx * 100; // approximate conversion
      tileHeightPx = (tileHeightMm / 1000) * wallHeightPx * 100;
    } else if (tileUnit === 'in') {
      tileWidthPx = (tileWidthMm / 12) * wallWidthPx * 12;
      tileHeightPx = (tileHeightMm / 12) * wallHeightPx * 12;
    } else {
      // Default to 200px
      tileWidthPx = 200;
      tileHeightPx = 200;
    }

    var tilesAcross = Math.min(20, Math.max(1, Math.round(wallWidthPx / tileWidthPx)));
    var tilesDown = Math.min(20, Math.max(1, Math.round(wallHeightPx / tileHeightPx)));

    var patternCanvas = document.createElement('canvas');
    patternCanvas.width = tileWidthPx * tilesAcross;
    patternCanvas.height = tileHeightPx * tilesDown;
    var patternCtx = patternCanvas.getContext('2d');

    var srcSize = Math.min(texture.naturalWidth || texture.width, texture.naturalHeight || texture.height);
    var srcX = ((texture.naturalWidth || texture.width) - srcSize) / 2;
    var srcY0 = ((texture.naturalHeight || texture.height) - srcSize) / 2;

    for (var ty = 0; ty < tilesDown; ty++) {
      for (var tx = 0; tx < tilesAcross; tx++) {
        patternCtx.drawImage(texture, srcX, srcY0, srcSize, srcSize, tx * tileWidthPx, ty * tileHeightPx, tileWidthPx, tileHeightPx);
      }
    }

    // Grout lines - realistic 2-3mm grout scaled to pixels
    var groutWidthPx = Math.max(1, Math.round(tileWidthPx * 0.015)); // ~1.5% of tile width
    patternCtx.strokeStyle = 'rgba(80,70,60,0.4)'; // Warm gray grout color
    patternCtx.lineWidth = groutWidthPx;
    
    for (var gx = 1; gx < tilesAcross; gx++) {
      patternCtx.beginPath();
      patternCtx.moveTo(gx * tileWidthPx, 0);
      patternCtx.lineTo(gx * tileWidthPx, patternCanvas.height);
      patternCtx.stroke();
    }
    for (var gy = 1; gy < tilesDown; gy++) {
      patternCtx.beginPath();
      patternCtx.moveTo(0, gy * tileHeightPx);
      patternCtx.lineTo(patternCanvas.width, gy * tileHeightPx);
      patternCtx.stroke();
    }

    return { canvas: patternCanvas, tilesAcross: tilesAcross, tilesDown: tilesDown, tileWidthPx: tileWidthPx, tileHeightPx: tileHeightPx };
  }

  function _drawTextureWithPerspective(corners, texture, ctx, canvasWidth, canvasHeight) {
    if (!texture) return;

    var wallWidthPx = _distance(corners.tl, corners.tr);
    var wallHeightPx = _distance(corners.tl, corners.bl);

    var pattern = _createTilePattern(texture, wallWidthPx, wallHeightPx, _currentTileWidth, _currentTileHeight, _currentTileUnit);
    var patternCanvas = pattern.canvas;

    var strips = 24;

    ctx.save();
    ctx.globalAlpha = _opacity;
    ctx.globalCompositeOperation = 'source-over';

    // Use pixel-level wall mask if available for exact clipping
    var selectedWall = _walls.find(function(w) { return w.id === _selectedWallId; });
    var usePixelMask = selectedWall && selectedWall.pixelLevel && _wallMasks[selectedWall.id];

    for (var i = 0; i < strips; i++) {
      var t1 = i / strips;
      var t2 = (i + 1) / strips;

      var topLeft = {
        x: corners.tl.x + (corners.bl.x - corners.tl.x) * t1,
        y: corners.tl.y + (corners.bl.y - corners.tl.y) * t1
      };
      var topRight = {
        x: corners.tr.x + (corners.br.x - corners.tr.x) * t1,
        y: corners.tr.y + (corners.br.y - corners.tr.y) * t1
      };
      var bottomLeft = {
        x: corners.tl.x + (corners.bl.x - corners.tl.x) * t2,
        y: corners.tl.y + (corners.bl.y - corners.tl.y) * t2
      };
      var bottomRight = {
        x: corners.tr.x + (corners.br.x - corners.tr.x) * t2,
        y: corners.tr.y + (corners.br.y - corners.tr.y) * t2
      };

      var stripHeight = bottomLeft.y - topLeft.y;
      var topWidth = topRight.x - topLeft.x;
      var bottomWidth = bottomRight.x - bottomLeft.x;

      ctx.beginPath();
      ctx.moveTo(topLeft.x, topLeft.y);
      ctx.lineTo(topRight.x, topRight.y);
      ctx.lineTo(bottomRight.x, bottomRight.y);
      ctx.lineTo(bottomLeft.x, bottomLeft.y);
      ctx.closePath();
      
      if (usePixelMask) {
        // Clip to pixel-perfect wall mask
        ctx.clip();
      } else {
        ctx.clip();
      }

      var srcY = patternCanvas.height * t1;
      var srcHeight = patternCanvas.height / strips;

      ctx.drawImage(
        patternCanvas,
        0, srcY, patternCanvas.width, srcHeight,
        topLeft.x, topLeft.y, topWidth, stripHeight
      );

      ctx.restore();
      ctx.save();
      ctx.globalAlpha = _opacity;
      ctx.globalCompositeOperation = 'source-over';
    }

    ctx.restore();

    // Draw occlusions on top
    _drawOcclusions(corners, ctx);
    
    // Edge feathering - soft transition at wall boundaries
    _applyEdgeFeathering(corners, ctx);
  }

  function _applyEdgeFeathering(corners, ctx) {
    ctx.save();
    
    // Top edge feather
    var grad = ctx.createLinearGradient(0, corners.tl.y - 4, 0, corners.tl.y + 4);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(0.5, 'rgba(0,0,0,0.15)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(corners.tl.x, corners.tl.y - 4, corners.tr.x - corners.tl.x, 8);

    // Bottom edge feather
    grad = ctx.createLinearGradient(0, corners.bl.y - 4, 0, corners.bl.y + 4);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(0.5, 'rgba(0,0,0,0.15)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(corners.bl.x, corners.bl.y - 4, corners.br.x - corners.bl.x, 8);

    // Left edge feather
    grad = ctx.createLinearGradient(corners.tl.x - 4, 0, corners.tl.x + 4, 0);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(0.5, 'rgba(0,0,0,0.15)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(corners.tl.x - 4, corners.tl.y, 8, corners.bl.y - corners.tl.y);

    // Right edge feather
    grad = ctx.createLinearGradient(corners.tr.x - 4, 0, corners.tr.x + 4, 0);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(0.5, 'rgba(0,0,0,0.15)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(corners.tr.x - 4, corners.tr.y, 8, corners.br.y - corners.tr.y);
    
    ctx.restore();
  }

  function _drawOcclusions(corners, ctx) {
    if (!_objects.length) return;
    ctx.save();
    ctx.globalCompositeOperation = 'destination-out'; // Punch holes in tile

    _objects.forEach(function(obj) {
      // Use pixel-level mask if available
      if (obj.maskData && obj.pixelLevel) {
        _drawPixelMaskOcclusion(obj.maskData, ctx);
      } else if (obj.corners) {
        // Fallback to polygon
        var oc = obj.corners;
        if (_rectsOverlap(corners, oc)) {
          ctx.beginPath();
          ctx.moveTo(oc.tl.x, oc.tl.y);
          ctx.lineTo(oc.tr.x, oc.tr.y);
          ctx.lineTo(oc.br.x, oc.br.y);
          ctx.lineTo(oc.bl.x, oc.bl.y);
          ctx.closePath();
          ctx.fill();
        }
      }
    });
    ctx.restore();
  }

  function _drawPixelMaskOcclusion(maskData, ctx) {
    // If maskData is a base64 encoded image (RGBA or RLE decoded)
    if (typeof maskData === 'string' && maskData.startsWith('data:image/')) {
      var img = new Image();
      img.onload = function() {
        // This is async - for real-time we'd need to pre-load
        // For now, just skip async mask drawing in render loop
      };
      img.src = maskData;
      return;
    }
    // If maskData is RLE, we'd decode it here
    // For now, polygon fallback is used
  }

  function _rectsOverlap(a, b) {
    var aMinX = Math.min(a.tl.x, a.tr.x, a.bl.x, a.br.x);
    var aMaxX = Math.max(a.tl.x, a.tr.x, a.bl.x, a.br.x);
    var aMinY = Math.min(a.tl.y, a.tr.y, a.bl.y, a.br.y);
    var aMaxY = Math.max(a.tl.y, a.tr.y, a.bl.y, a.br.y);
    var bMinX = Math.min(b.tl.x, b.tr.x, b.bl.x, b.br.x);
    var bMaxX = Math.max(b.tl.x, b.tr.x, b.bl.x, b.br.x);
    var bMinY = Math.min(b.tl.y, b.tr.y, b.bl.y, b.br.y);
    var bMaxY = Math.max(b.tl.y, b.tr.y, b.bl.y, b.br.y);
    return !(aMaxX < bMinX || aMinX > bMaxX || aMaxY < bMinY || aMinY > bMaxY);
  }

  // ── Static Visualization (Photo Mode) ──────────────────────────────────

  function _loadImage(src) {
    return new Promise(function (resolve, reject) {
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function () { resolve(img); };
      img.onerror = function () { reject(new Error('Failed to load image: ' + src)); };
      img.src = src;
    });
  }

  function renderStaticVisualization(roomImageUrl, textureUrl, opacity) {
    return Promise.all([_loadImage(roomImageUrl), _loadImage(textureUrl)])
      .then(function (imgs) {
        var roomImg = imgs[0], textureImg = imgs[1];

        var maxDim = 1400;
        var scale = Math.min(1, maxDim / Math.max(roomImg.naturalWidth, roomImg.naturalHeight));
        var w = Math.round(roomImg.naturalWidth * scale);
        var h = Math.round(roomImg.naturalHeight * scale);

        var canvas = document.createElement('canvas');
        canvas.width = w; canvas.height = h;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(roomImg, 0, 0, w, h);

        // Local heuristic
        var imageData = ctx.getImageData(0, 0, w, h);
        var edges = _detectEdges(imageData, w, h);
        var localRegion = _findWallRegion(edges, w, h);

        // AI detection with segmentation
        var snapCanvas = document.createElement('canvas');
        snapCanvas.width = 320;
        snapCanvas.height = Math.round((h / w) * 320) || 240;
        snapCanvas.getContext('2d').drawImage(canvas, 0, 0, snapCanvas.width, snapCanvas.height);

        return fetch('/api/wall-detect', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({image: snapCanvas.toDataURL('image/jpeg', 0.7), useSegmentation: true})
        })
          .then(function (r) { return r.json(); })
          .catch(function () { return null; })
          .then(function (aiResult) {
            var region = localRegion;
            var bestWall = null;

            if (aiResult && aiResult.wallDetected && aiResult.walls && aiResult.walls.length) {
              bestWall = aiResult.walls.reduce(function(best, w) {
                return (w.confidence > best.confidence) ? w : best;
              }, aiResult.walls[0]);
            }

            if (bestWall) {
              region = {
                real: true,
                corners: _scaleCorners(_polygonToCorners(bestWall.polygon), w, h),
                pixelLevel: bestWall.pixelLevel || false
              };
              // Store objects for occlusion (AI + local fallback)
              var aiObjects = (aiResult.objects || []).map(function(obj) {
                var corners = obj.polygon ? _polygonToCorners(obj.polygon) : null;
                var objData = {
                  type: obj.type || 'other',
                  confidence: obj.confidence || 0.5,
                  polygon: obj.polygon || [],
                  corners: corners,
                  pixelLevel: obj.pixelLevel || false
                };
                if (obj.maskData) objData.maskData = obj.maskData;
                return objData;
              });
              
              // Add local object detection as fallback
              var localObjects = _findObjectsOnWall(edges, w, h, region.corners);
              var existingTypes = new Set(aiObjects.map(function(o) { return o.type; }));
              localObjects.forEach(function(obj) {
                if (!existingTypes.has(obj.type)) {
                  aiObjects.push(obj);
                }
              });
              
              _objects = aiObjects;
              
              // Store wall mask for pixel-perfect rendering
              if (bestWall.maskData) {
                _wallMasks['static_wall'] = {
                  polygon: bestWall.polygon,
                  maskData: bestWall.maskData
                };
              }
            }

            if (!region.real) {
              return {success: false, image: canvas.toDataURL('image/jpeg', 0.92)};
            }

            var prevOpacity = _opacity;
            _opacity = Math.max(0.0, Math.min(1.0, opacity));
            _drawTextureWithPerspective(region.corners, textureImg, ctx, w, h);
            _drawOcclusions(region.corners, ctx);
            _opacity = prevOpacity;

            return {success: true, image: canvas.toDataURL('image/jpeg', 0.92)};
          });
      });
  }

  // ── Main Render Loop ──────────────────────────────────────────────────

  function _renderFrame() {
    if (!_video || !_canvas || !_ctx) return;

    var renderStart = Date.now();
    _frameCount++;
    var width = _canvas.width;
    var height = _canvas.height;

    // FPS logging
    var now = Date.now();
    if (now - _lastFpsTime >= 1000) {
      console.log('[GraziaAR] FPS:', _frameCount, 'render:', _renderTime.toFixed(1), 'ms, AI:', _aiTime, 'ms, walls:', _walls.length);
      _frameCount = 0;
      _lastFpsTime = now;
    }

    // Draw camera feed
    _ctx.drawImage(_video, 0, 0, width, height);

    // Local edge detection every 3 frames
    if (_frameCount % 3 === 0) {
      var detectWidth = Math.floor(width / 3);
      var detectHeight = Math.floor(height / 3);
      var detectCanvas = document.createElement('canvas');
      detectCanvas.width = detectWidth; detectCanvas.height = detectHeight;
      var detectCtx = detectCanvas.getContext('2d');
      detectCtx.drawImage(_video, 0, 0, detectWidth, detectHeight);
      var imageData = detectCtx.getImageData(0, 0, detectWidth, detectHeight);
      var edges = _detectEdges(imageData, detectWidth, detectHeight);
      var wallRegion = _findWallRegion(edges, detectWidth, detectHeight);

      var scaledCorners = _scaleCorners(wallRegion.corners, 3, 3);

      if (wallRegion.real) {
        _lostFrames = 0;
        // Update or create wall from local detection
        if (_selectedWallId) {
          var wallIdx = _walls.findIndex(function(w) { return w.id === _selectedWallId; });
          if (wallIdx >= 0) {
            var existing = _walls[wallIdx];
            // Blend local with existing (AI-corrected)
            var blendFactor = existing.lockFrames > 10 ? 0.1 : 0.3;
            existing.corners = _lerpCorners(existing.corners, scaledCorners, blendFactor);
            existing.lastSeen = Date.now();
          }
        } else if (!_hasRealLock) {
          // No AI lock yet, use local
          if (!_walls.length) {
            _walls.push({
              id: 'wall_local_1',
              corners: scaledCorners,
              confidence: 0.5,
              real: true,
              lastSeen: Date.now(),
              lockFrames: 0
            });
            _selectedWallId = _walls[0].id;
          }
        }

        // Local object detection for occlusion fallback (every 6 frames)
        if (_frameCount % 6 === 0 && _hasRealLock && _selectedWallId) {
          var selectedWall = _walls.find(function(w) { return w.id === _selectedWallId; });
          if (selectedWall) {
            var localObjects = _findObjectsOnWall(edges, detectWidth, detectHeight, scaledCorners);
            if (localObjects.length) {
              // Merge with AI objects, preferring AI but filling gaps
              var existingTypes = new Set(_objects.map(function(o) { return o.type; }));
              localObjects.forEach(function(obj) {
                if (!existingTypes.has(obj.type)) {
                  _objects.push(obj);
                }
              });
            }
          }
        }
      } else if (_hasRealLock && _selectedWallId) {
        // Briefly lost edges — stay anchored
        _lostFrames++;
        var MAX_LOST = 20;
        if (_lostFrames > MAX_LOST) {
          _hasRealLock = false;
        }
      }
    }

    // Request AI detection periodically
    _requestAiWallDetection(width, height);

    // Draw selected wall
    var selectedWall = _walls.find(function(w) { return w.id === _selectedWallId; });

    if (selectedWall && _hasRealLock && _showWallBoundary) {
      var corners = _manualCorners || selectedWall.corners;

      // Draw wall boundary
      _ctx.save();
      _ctx.strokeStyle = 'rgba(200, 165, 60, 0.5)';
      _ctx.lineWidth = 2;
      _ctx.setLineDash([10, 5]);
      _ctx.beginPath();
      _ctx.moveTo(corners.tl.x, corners.tl.y);
      _ctx.lineTo(corners.tr.x, corners.tr.y);
      _ctx.lineTo(corners.br.x, corners.br.y);
      _ctx.lineTo(corners.bl.x, corners.bl.y);
      _ctx.closePath();
      _ctx.stroke();
      _ctx.setLineDash([]);

      // Corner brackets
      var bracketSize = 22;
      _ctx.strokeStyle = 'rgba(200, 165, 60, 0.9)';
      _ctx.lineWidth = 3; _ctx.lineCap = 'round';
      [[corners.tl, +bracketSize, +bracketSize],
       [corners.tr, -bracketSize, +bracketSize],
       [corners.bl, +bracketSize, -bracketSize],
       [corners.br, -bracketSize, -bracketSize]].forEach(function(c) {
        _ctx.beginPath();
        _ctx.moveTo(c[0].x + c[1], c[0].y);
        _ctx.lineTo(c[0].x, c[0].y);
        _ctx.lineTo(c[0].x, c[0].y + c[2]);
        _ctx.stroke();
      });
      _ctx.restore();

      // Draw texture
      if (_textureImage && _textureImage.complete) {
        _drawTextureWithPerspective(corners, _textureImage, _ctx, width, height);
        // Draw occlusions on top
        _drawOcclusions(corners, _ctx);
      } else {
        _ctx.save();
        _ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        _ctx.fillRect(width/2 - 140, height/2 - 25, 280, 50);
        _ctx.fillStyle = '#C8A53C';
        _ctx.font = 'bold 14px -apple-system, sans-serif';
        _ctx.textAlign = 'center'; _ctx.textBaseline = 'middle';
        _ctx.fillText('Select a stone to preview on wall', width/2, height/2);
        _ctx.restore();
      }
    } else {
      // Hint message
      _ctx.save();
      _ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
      _ctx.fillRect(width/2 - 160, height/2 - 35, 320, 70);
      _ctx.fillStyle = '#C8A53C';
      _ctx.font = 'bold 15px -apple-system, sans-serif';
      _ctx.textAlign = 'center'; _ctx.textBaseline = 'middle';
      _ctx.fillText('Move camera towards a flat wall', width/2, height/2 - 10);
      _ctx.font = '13px -apple-system, sans-serif';
      _ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
      _ctx.fillText('Wall detection will activate automatically', width/2, height/2 + 15);
      _ctx.restore();
    }

    _renderTime = Date.now() - renderStart;
    _animationFrame = requestAnimationFrame(_renderFrame);
  }

  // ── Public API ────────────────────────────────────────────────────────

  window.GraziaAR = {
    init: function (containerId) {
      var el = _findContainer(containerId);
      if (!el) return false;

      if (_initDone && _container === el) return true;

      el.style.cssText = 'position:relative;width:100%;height:100%;overflow:hidden;background:#000;';

      if (!_initDone) {
        _initDone = true;

        _video = document.createElement('video');
        _video.setAttribute('autoplay', '');
        _video.setAttribute('playsinline', '');
        _video.setAttribute('muted', '');
        _video.setAttribute('webkit-playsinline', '');
        _video.muted = true;
        _video.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;';

        _canvas = document.createElement('canvas');
        _canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;';
        _ctx = _canvas.getContext('2d', {alpha: false, desynchronized: true});
      }

      el.appendChild(_video);
      el.appendChild(_canvas);
      _container = el;

      if (typeof ResizeObserver !== 'undefined') {
        var ro = new ResizeObserver(function () { window.GraziaAR._resizeCanvas(); });
        ro.observe(_container);
      }
      window.GraziaAR._resizeCanvas();

      return true;
    },

    _resizeCanvas: function () {
      if (!_canvas || !_video) return;
      var parent = _canvas.parentElement;
      if (!parent) return;
      var rect = parent.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        var videoAspect = (_video.videoWidth || 1280) / (_video.videoHeight || 720);
        var containerAspect = rect.width / rect.height;
        if (containerAspect > videoAspect) {
          _canvas.height = rect.height;
          _canvas.width = Math.floor(rect.height * videoAspect);
        } else {
          _canvas.width = rect.width;
          _canvas.height = Math.floor(rect.width / videoAspect);
        }
      }
    },

    startCamera: function () {
      window._graziaARReady = false;
      window._graziaARError = null;
      console.log('[GraziaAR] startCamera() called');

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        window._graziaARError = 'Camera API not supported';
        return Promise.reject(window._graziaARError);
      }

      var constraintSets = [
        { video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false },
        { video: { facingMode: 'environment' }, audio: false },
        { video: true, audio: false },
      ];

      function tryNext(idx) {
        if (idx >= constraintSets.length) {
          window._graziaARError = 'Camera not available';
          return Promise.reject(window._graziaARError);
        }
        return navigator.mediaDevices.getUserMedia(constraintSets[idx])
          .then(function (stream) {
            _stream = stream;
            _video.srcObject = stream;
            return new Promise(function(resolve, reject) {
              _video.onloadedmetadata = function() {
                window.GraziaAR._resizeCanvas();
                var playPromise = _video.play();
                if (playPromise !== undefined) {
                  playPromise.then(function () {
                    window._graziaARReady = true;
                    _renderFrame();
                    resolve('ready');
                  }).catch(function (err) {
                    _video.muted = true;
                    _video.play().then(function () {
                      window._graziaARReady = true;
                      _renderFrame();
                      resolve('ready');
                    }).catch(reject);
                  });
                } else {
                  window._graziaARReady = true;
                  _renderFrame();
                  resolve('ready');
                }
              };
            });
          })
          .catch(function (err) { return tryNext(idx + 1); });
      }

      return tryNext(0);
    },

    stopCamera: function () {
      if (_mediaRecorder) { _mediaRecorder.stop(); _mediaRecorder = null; _recordedChunks = []; }
      if (_animationFrame) { cancelAnimationFrame(_animationFrame); _animationFrame = null; }
      if (_stream) { _stream.getTracks().forEach(function (t) { t.stop(); }); _stream = null; }
      if (_video) _video.srcObject = null;
      if (_ctx && _canvas) _ctx.clearRect(0, 0, _canvas.width, _canvas.height);
      window._graziaARReady = false;
      _walls = []; _selectedWallId = null; _hasRealLock = false; _lostFrames = 0; _frameCount = 0;
      _objects = []; _manualCorners = null; _lastAiCorners = null;
    },

    setTexture: function (textureUrl) {
      if (!textureUrl) { _textureImage = null; return; }
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function () { _textureImage = img; };
      img.onerror = function () { console.warn('[GraziaAR] Failed to load texture:', textureUrl); };
      img.src = textureUrl;
    },

    isReady: function () { return window._graziaARReady === true; },
    getError: function () { return window._graziaARError; },

    setOpacity: function (value) { _opacity = Math.max(0.0, Math.min(1.0, value)); },
    setScale: function (value) { _scale = Math.max(0.1, Math.min(5.0, value)); },
    setPosition: function (x, y) { _position = {x: x||0, y: y||0}; },
    setRotation: function (degrees) { _rotation = degrees || 0; },

    setTileDimensions: function (width, height, unit) {
      _currentTileWidth = width || 600;
      _currentTileHeight = height || 600;
      _currentTileUnit = unit || 'mm';
    },

    renderStaticVisualization: function (roomImageUrl, textureUrl, opacity) {
      window._graziaARStaticResult = null; window._graziaARStaticError = null;
      renderStaticVisualization(roomImageUrl, textureUrl, opacity)
        .then(function (result) { window._graziaARStaticResult = JSON.stringify(result); })
        .catch(function (e) { window._graziaARStaticError = e ? (e.message || e.toString()) : 'Visualization failed'; });
    },

    showWallBoundary: function (show) { _showWallBoundary = show !== false; },

    requestSegmentation: function () { _segmentationRequested = true; },

    getWallCorners: function () {
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall) return null;
      var c = _manualCorners || wall.corners;
      return { tl: {x: c.tl.x, y: c.tl.y}, tr: {x: c.tr.x, y: c.tr.y}, bl: {x: c.bl.x, y: c.bl.y}, br: {x: c.br.x, y: c.br.y} };
    },

    getWallDetected: function () { return _hasRealLock && _selectedWallId !== null; },

    getWalls: function () {
      return _walls.map(function(w) {
        var c = w.corners;
        return {
          id: w.id,
          corners: { tl: {x: c.tl.x, y: c.tl.y}, tr: {x: c.tr.x, y: c.tr.y}, bl: {x: c.bl.x, y: c.bl.y}, br: {x: c.br.x, y: c.br.y} },
          confidence: w.confidence,
          area: _wallArea(c)
        };
      });
    },

    selectWall: function (wallId) {
      var wall = _walls.find(function(w) { return w.id === wallId; });
      if (wall) { _selectedWallId = wallId; _hasRealLock = true; return true; }
      return false;
    },

    setManualCorner: function (name, x, y) {
      if (!_selectedWallId) return;
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall) return;
      if (!_manualCorners) {
        _manualCorners = { tl: {x: wall.corners.tl.x, y: wall.corners.tl.y}, tr: {x: wall.corners.tr.x, y: wall.corners.tr.y}, bl: {x: wall.corners.bl.x, y: wall.corners.bl.y}, br: {x: wall.corners.br.x, y: wall.corners.br.y} };
      }
      _manualCorners[name] = {x: x, y: y};
    },

    clearManualCorners: function () { _manualCorners = null; },
    hasManualCorners: function () { return _manualCorners !== null; },

    getWallCornersJson: function () {
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall) return null;
      var c = _manualCorners || wall.corners;
      return JSON.stringify({ tl: {x: c.tl.x, y: c.tl.y}, tr: {x: c.tr.x, y: c.tr.y}, bl: {x: c.bl.x, y: c.bl.y}, br: {x: c.br.x, y: c.br.y} });
    },

    // Enhanced Calibration with proper unit support (mm, cm, m, ft, in)
    startCalibration: function (unit) {
      _calibrationMode = true;
      _calibrationUnit = unit || 'mm'; // Default to mm for precision
      _calibrationPoints = [];
      _pixelsPerUnit = null;
      console.log('[GraziaAR] Calibration started, unit:', _calibrationUnit);
    },

    addCalibrationPoint: function (x, y) {
      if (!_calibrationMode) return;
      _calibrationPoints.push({x: x, y: y});
    },

    finishCalibration: function (realLength, unit) {
      if (!_calibrationMode || _calibrationPoints.length < 2) return false;
      var pixelDist = _distance(_calibrationPoints[0], _calibrationPoints[1]);
      var calibrationUnit = unit || _calibrationUnit;
      _pixelsPerUnit = pixelDist / realLength;
      _calibrationUnit = calibrationUnit;
      _calibrationMode = false;
      _calibrationPoints = [];
      console.log('[GraziaAR] Calibration complete:', _pixelsPerUnit, 'pixels per', _calibrationUnit);
      return true;
    },

    getCalibration: function () {
      return { pixelsPerUnit: _pixelsPerUnit, unit: _calibrationUnit };
    },

    measureDistance: function (x1, y1, x2, y2) {
      if (!_pixelsPerUnit) return null;
      var pixelDist = Math.hypot(x2 - x1, y2 - y1);
      return pixelDist / _pixelsPerUnit;
    },

    // Measure wall dimensions (returns object with width, height, area in calibration unit)
    measureWall: function () {
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall || !_pixelsPerUnit) return null;
      
      var corners = _manualCorners || wall.corners;
      var wallWidthPx = _distance(corners.tl, corners.tr);
      var wallHeightPx = _distance(corners.tl, corners.bl);
      
      return {
        width: wallWidthPx / _pixelsPerUnit,
        height: wallHeightPx / _pixelsPerUnit,
        area: (wallWidthPx * wallHeightPx) / (_pixelsPerUnit * _pixelsPerUnit),
        unit: _calibrationUnit,
        pixelsPerUnit: _pixelsPerUnit,
        isCalibrated: true
      };
    },

    // Calculate tile quantity using calibrated measurements
    calculateTileQuantity: function (tileWidth, tileHeight, tileUnit, wastagePercent) {
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall || !_pixelsPerUnit) return null;

      var corners = _manualCorners || wall.corners;
      var wallWidth = _distance(corners.tl, corners.tr) / _pixelsPerUnit;
      var wallHeight = _distance(corners.tl, corners.bl) / _pixelsPerUnit;
      var wallArea = wallWidth * wallHeight;

      // Convert tile dimensions to calibration unit
      var tileW = _convertToUnit(tileWidth, tileUnit, _calibrationUnit);
      var tileH = _convertToUnit(tileHeight, tileUnit, _calibrationUnit);
      var tileArea = tileW * tileH;

      var baseQty = Math.ceil(wallArea / tileArea);
      var wastage = wastagePercent || 10;
      var recommended = Math.ceil(baseQty * (1 + wastage / 100));

      return {
        wallWidth: wallWidth.toFixed(2),
        wallHeight: wallHeight.toFixed(2),
        wallArea: wallArea.toFixed(2),
        tileWidth: tileW.toFixed(2),
        tileHeight: tileH.toFixed(2),
        tileArea: tileArea.toFixed(2),
        baseQuantity: baseQty,
        wastagePercent: wastage,
        recommendedQuantity: recommended,
        unit: _calibrationUnit,
        isCalibrated: true,
        calibrationSource: 'user' // 'user' or 'ar' for ARKit/ARCore
      };
    },

    // Unit conversion helper
    _convertToUnit: function (value, fromUnit, toUnit) {
      // Convert to mm first
      var valueInMm;
      switch (fromUnit.toLowerCase()) {
        case 'mm': valueInMm = value; break;
        case 'cm': valueInMm = value * 10; break;
        case 'm': valueInMm = value * 1000; break;
        case 'in': valueInMm = value * 25.4; break;
        case 'ft': valueInMm = value * 304.8; break;
        default: valueInMm = value; // Assume mm
      }
      
      // Convert from mm to target unit
      switch (toUnit.toLowerCase()) {
        case 'mm': return valueInMm;
        case 'cm': return valueInMm / 10;
        case 'm': return valueInMm / 1000;
        case 'in': return valueInMm / 25.4;
        case 'ft': return valueInMm / 304.8;
        default: return valueInMm;
      }
    },

    // Recording
    startRecording: function () {
      if (!_canvas || _mediaRecorder) return false;
      var stream = _canvas.captureStream(30);
      var mimeType = MediaRecorder.isTypeSupported('video/mp4') ? 'video/mp4'
        : (MediaRecorder.isTypeSupported('video/webm;codecs=vp9') ? 'video/webm;codecs=vp9' : 'video/webm');
      _recordedChunks = [];
      _mediaRecorder = new MediaRecorder(stream, { mimeType: mimeType });
      _mediaRecorder.ondataavailable = function (e) { if (e.data && e.data.size > 0) _recordedChunks.push(e.data); };
      _mediaRecorder.start();
      return true;
    },

    stopRecording: function () {
      if (!_mediaRecorder) return false;
      var mimeType = _mediaRecorder.mimeType || 'video/webm';
      _mediaRecorder.onstop = function () {
        var blob = new Blob(_recordedChunks, { type: mimeType });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url; a.download = 'grazia-ar-' + Date.now() + (mimeType.indexOf('mp4') >= 0 ? '.mp4' : '.webm');
        document.body.appendChild(a); a.click(); a.remove();
        setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
        _recordedChunks = [];
      };
      _mediaRecorder.stop(); _mediaRecorder = null;
      return true;
    },

    isRecording: function () { return _mediaRecorder !== null && _mediaRecorder.state === 'recording'; },

    // Measurement & Quantity Calculation
    calculateTileQuantity: function (tileWidth, tileHeight, tileUnit, wastagePercent) {
      var wall = _walls.find(function(w) { return w.id === _selectedWallId; });
      if (!wall || !_pixelsPerUnit) return null;

      var corners = _manualCorners || wall.corners;
      var wallWidth = _distance(corners.tl, corners.tr) / _pixelsPerUnit;
      var wallHeight = _distance(corners.tl, corners.bl) / _pixelsPerUnit;
      var wallArea = wallWidth * wallHeight;

      var tileW = (tileUnit === 'in') ? tileWidth / 12 : tileWidth;
      var tileH = (tileUnit === 'in') ? tileHeight / 12 : tileH;
      var tileArea = tileW * tileH;

      var baseQty = Math.ceil(wallArea / tileArea);
      var wastage = wastagePercent || 10;
      var recommended = Math.ceil(baseQty * (1 + wastage / 100));

      return {
        wallWidth: wallWidth.toFixed(2),
        wallHeight: wallHeight.toFixed(2),
        wallArea: wallArea.toFixed(2),
        tileArea: tileArea.toFixed(2),
        baseQuantity: baseQty,
        wastagePercent: wastage,
        recommendedQuantity: recommended,
        unit: _calibrationUnit
      };
    }
  };
})();