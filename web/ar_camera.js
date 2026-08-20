// Grazia Stones AR Camera Engine
// Real wall detection + perspective transform + realistic texture mapping

(function () {
  'use strict';

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
  var _wallCorners = null;
  var _wallDetected = false;
  var _manualCorners = null; // user-dragged corner override, {tl,tr,bl,br} or null
  var _hasRealLock = false; // true once a real (non-fallback) wall was found
  var _lostFrames = 0; // consecutive detection cycles without real edges

  // AI-assisted wall detection (NVIDIA NIM, via server proxy) — periodic
  // correction on top of the local edge heuristic, not a per-frame replacement.
  var _aiRequestInFlight = false;
  var _lastAiRequestAt = 0;
  var AI_REQUEST_INTERVAL_MS = 3000;
  
  // Stone control state
  var _opacity = 0.96; // near-opaque: user wants the true selected tile, not the wall showing through
  var _scale = 1.0;
  var _position = {x: 0, y: 0};
  var _rotation = 0;
  var _showWallBoundary = true;
  
  // Find container (handles Flutter Web shadow DOM)
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
  
  // Improved edge detection with Sobel operator
  function _detectEdges(imageData, width, height) {
    var data = imageData.data;
    var edges = new Uint8Array(width * height);
    var threshold = 30;
    
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        var idx = y * width + x;
        
        // Sobel kernels
        var gx = 0, gy = 0;
        
        // Get 3x3 neighborhood grayscale values
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            var pixelIdx = ((y + dy) * width + (x + dx)) * 4;
            var gray = (data[pixelIdx] + data[pixelIdx + 1] + data[pixelIdx + 2]) / 3;
            
            // Sobel X kernel: [-1,0,1; -2,0,2; -1,0,1]
            if (dx === -1) gx -= gray * (dy === 0 ? 2 : 1);
            if (dx === 1) gx += gray * (dy === 0 ? 2 : 1);
            
            // Sobel Y kernel: [-1,-2,-1; 0,0,0; 1,2,1]
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
  
  // Find largest rectangular region (wall candidate).
  // Returns { corners, real } — real=false means no strong edges were found
  // and the caller fell back to a fixed placeholder region.
  function _avg(list, from, to, key) {
    var sum = 0, count = to - from;
    for (var i = from; i < to; i++) sum += list[i][key];
    return sum / count;
  }

  function _findWallRegion(edges, width, height) {
    // Find strong horizontal and vertical lines
    var horizontalLines = [];
    var verticalLines = [];

    // Detect horizontal lines
    for (var y = 0; y < height; y += 4) {
      var strength = 0;
      for (var x = 0; x < width; x++) {
        if (edges[y * width + x] > 0) strength++;
      }
      if (strength > width * 0.22) {
        horizontalLines.push({y: y, strength: strength});
      }
    }

    // Detect vertical lines
    for (var x = 0; x < width; x += 4) {
      var strength = 0;
      for (var y = 0; y < height; y++) {
        if (edges[y * width + x] > 0) strength++;
      }
      if (strength > height * 0.22) {
        verticalLines.push({x: x, strength: strength});
      }
    }

    // If we have enough lines, wall likely detected
    if (horizontalLines.length >= 2 && verticalLines.length >= 2) {
      // Box = average of the outermost few qualifying edges on each side,
      // not a single min/max line — a lone noisy pixel row/column at the
      // true extreme flips the box edge every pass (this is what still
      // "breathed"/resized constantly even after switching off strength
      // ranking). Averaging a small cluster near each extreme is far less
      // sensitive to one-frame noise while still tracking the real edge.
      horizontalLines.sort(function (a, b) { return a.y - b.y; });
      verticalLines.sort(function (a, b) { return a.x - b.x; });
      var N = 3;
      var top = _avg(horizontalLines, 0, Math.min(N, horizontalLines.length), 'y');
      var bottom = _avg(horizontalLines, Math.max(0, horizontalLines.length - N), horizontalLines.length, 'y');
      var left = _avg(verticalLines, 0, Math.min(N, verticalLines.length), 'x');
      var right = _avg(verticalLines, Math.max(0, verticalLines.length - N), verticalLines.length, 'x');

      // Ensure reasonable size
      if (right - left > width * 0.3 && bottom - top > height * 0.3) {
        return {
          real: true,
          corners: {
            tl: {x: left, y: top},
            tr: {x: right, y: top},
            bl: {x: left, y: bottom},
            br: {x: right, y: bottom}
          }
        };
      }
    }

    // Fallback: use center region (only used when no real edges seen yet)
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

  // Blend corners toward a target (exponential smoothing) so the overlay
  // doesn't jitter/snap between detections — reads as "anchored" to the wall.
  function _lerpCorners(from, to, t) {
    function lerpPt(a, b) {
      return {x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t};
    }
    return {
      tl: lerpPt(from.tl, to.tl),
      tr: lerpPt(from.tr, to.tr),
      bl: lerpPt(from.bl, to.bl),
      br: lerpPt(from.br, to.br)
    };
  }

  // Ask the server-side NIM proxy where the wall is, roughly every
  // AI_REQUEST_INTERVAL_MS. Cloud round-trips are too slow for per-frame use,
  // so this only *corrects* the local edge-detection heuristic above, it
  // doesn't replace it. Fire-and-forget: never blocks the render loop.
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

    fetch('/api/wall-detect', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({image: dataUrl})
    })
      .then(function (r) { return r.json(); })
      .then(function (result) {
        if (!result || !result.found) return;
        var x = result.x * width, y = result.y * height;
        var w = result.width * width, h = result.height * height;
        var aiCorners = {
          tl: {x: x, y: y},
          tr: {x: x + w, y: y},
          bl: {x: x, y: y + h},
          br: {x: x + w, y: y + h}
        };
        // Treat an AI hit as a real, higher-confidence detection — snap
        // most of the way there, keep the same smoothing/anchor system.
        _lostFrames = 0;
        _hasRealLock = true;
        _wallCorners = _wallCorners ? _lerpCorners(_wallCorners, aiCorners, 0.6) : aiCorners;
        _wallDetected = true;
      })
      .catch(function () { /* ponytail: silent — local heuristic keeps running regardless */ })
      .finally(function () { _aiRequestInFlight = false; });
  }

  // Draw texture with perspective transform using triangle strips
  function _drawTextureWithPerspective(corners, texture, ctx, canvasWidth, canvasHeight) {
    if (!texture) return;
    
    // Create pattern from texture (tiled)
    // Tile count scales with the wall's actual on-screen size so each tile
    // stays roughly TILE_SCREEN_PX wide regardless of how big/small the
    // detected wall is — a fixed 3x3 grid squashed to fit the quad (the old
    // approach) made tiles look stretched into giant fake slabs on a big
    // wall and squeezed into slivers on a small one.
    var tileSize = 200;
    var wallWidthPx = Math.hypot(corners.tr.x - corners.tl.x, corners.tr.y - corners.tl.y);
    var wallHeightPx = Math.hypot(corners.bl.x - corners.tl.x, corners.bl.y - corners.tl.y);
    var tilesAcross = Math.min(12, Math.max(1, Math.round(wallWidthPx / tileSize)));
    var tilesDown = Math.min(12, Math.max(1, Math.round(wallHeightPx / tileSize)));

    var patternCanvas = document.createElement('canvas');
    patternCanvas.width = tileSize * tilesAcross;
    patternCanvas.height = tileSize * tilesDown;
    var patternCtx = patternCanvas.getContext('2d');

    // Tile the texture — sample a centered square crop so non-square source
    // images (our cropped stone textures) don't stretch when tiled.
    var srcSize = Math.min(texture.naturalWidth || texture.width, texture.naturalHeight || texture.height);
    var srcX = ((texture.naturalWidth || texture.width) - srcSize) / 2;
    var srcY0 = ((texture.naturalHeight || texture.height) - srcSize) / 2;
    for (var ty = 0; ty < tilesDown; ty++) {
      for (var tx = 0; tx < tilesAcross; tx++) {
        patternCtx.drawImage(texture, srcX, srcY0, srcSize, srcSize, tx * tileSize, ty * tileSize, tileSize, tileSize);
      }
    }

    // Grout lines between tiles — a seamless stretched image reads as a
    // flat photo pasted on the wall rather than individually laid tiles.
    patternCtx.strokeStyle = 'rgba(0,0,0,0.35)';
    patternCtx.lineWidth = 2;
    for (var gx = 1; gx < tilesAcross; gx++) {
      patternCtx.beginPath();
      patternCtx.moveTo(gx * tileSize, 0);
      patternCtx.lineTo(gx * tileSize, patternCanvas.height);
      patternCtx.stroke();
    }
    for (var gy = 1; gy < tilesDown; gy++) {
      patternCtx.beginPath();
      patternCtx.moveTo(0, gy * tileSize);
      patternCtx.lineTo(patternCanvas.width, gy * tileSize);
      patternCtx.stroke();
    }
    
    // Draw using triangle strips for better perspective
    var strips = 24;
    
    ctx.save();
    ctx.globalAlpha = _opacity;
    ctx.globalCompositeOperation = 'source-over'; // true tile color, not tinted by wall lighting
    
    for (var i = 0; i < strips; i++) {
      var t1 = i / strips;
      var t2 = (i + 1) / strips;
      
      // Interpolate corners
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
      
      // Calculate strip dimensions
      var stripHeight = bottomLeft.y - topLeft.y;
      var topWidth = topRight.x - topLeft.x;
      var bottomWidth = bottomRight.x - bottomLeft.x;
      
      // Draw quad as textured strip
      ctx.beginPath();
      ctx.moveTo(topLeft.x, topLeft.y);
      ctx.lineTo(topRight.x, topRight.y);
      ctx.lineTo(bottomRight.x, bottomRight.y);
      ctx.lineTo(bottomLeft.x, bottomLeft.y);
      ctx.closePath();
      ctx.clip();
      
      // Draw pattern slice
      var srcY = (patternCanvas.height * t1);
      var srcHeight = (patternCanvas.height / strips);
      
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
    
    // Add edge feathering (soft blur at edges)
    ctx.save();
    
    // Top edge feather
    var gradient = ctx.createLinearGradient(0, corners.tl.y - 3, 0, corners.tl.y + 3);
    gradient.addColorStop(0, 'rgba(0,0,0,0.2)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(corners.tl.x, corners.tl.y - 3, corners.tr.x - corners.tl.x, 6);
    
    // Bottom edge feather
    gradient = ctx.createLinearGradient(0, corners.bl.y - 3, 0, corners.bl.y + 3);
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(1, 'rgba(0,0,0,0.2)');
    ctx.fillStyle = gradient;
    ctx.fillRect(corners.bl.x, corners.bl.y - 3, corners.br.x - corners.bl.x, 6);
    
    // Left edge feather
    gradient = ctx.createLinearGradient(corners.tl.x - 2, 0, corners.tl.x + 2, 0);
    gradient.addColorStop(0, 'rgba(0,0,0,0.2)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(corners.tl.x - 2, corners.tl.y, 4, corners.bl.y - corners.tl.y);
    
    // Right edge feather
    gradient = ctx.createLinearGradient(corners.tr.x - 2, 0, corners.tr.x + 2, 0);
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(1, 'rgba(0,0,0,0.2)');
    ctx.fillStyle = gradient;
    ctx.fillRect(corners.tr.x - 2, corners.tr.y, 4, corners.br.y - corners.tr.y);
    
    ctx.restore();
  }
  
  // Photo-mode visualization: detect the wall in a still room photo (same
  // Sobel heuristic + server AI check used for live AR, just run once
  // instead of per-frame) and composite the stone texture onto ONLY that
  // region, warped to match its perspective. Everything else in the photo
  // (floor, furniture, ceiling) is left byte-for-byte untouched.
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

        // Cap working resolution — full phone-camera photos (4000px+) make
        // the Sobel scan take seconds for no detection-quality benefit.
        var maxDim = 1400;
        var scale = Math.min(1, maxDim / Math.max(roomImg.naturalWidth, roomImg.naturalHeight));
        var w = Math.round(roomImg.naturalWidth * scale);
        var h = Math.round(roomImg.naturalHeight * scale);

        var canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(roomImg, 0, 0, w, h);

        // 1) Local heuristic (instant, no network dependency).
        var imageData = ctx.getImageData(0, 0, w, h);
        var edges = _detectEdges(imageData, w, h);
        var localRegion = _findWallRegion(edges, w, h);

        // 2) Ask the server AI detector too — it's a single request here
        // (not fire-and-forget like the live loop), so we can afford to
        // wait for a more reliable quad before compositing.
        var snapCanvas = document.createElement('canvas');
        snapCanvas.width = 320;
        snapCanvas.height = Math.round((h / w) * 320) || 240;
        snapCanvas.getContext('2d').drawImage(canvas, 0, 0, snapCanvas.width, snapCanvas.height);

        return fetch('/api/wall-detect', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({image: snapCanvas.toDataURL('image/jpeg', 0.7)})
        })
          .then(function (r) { return r.json(); })
          .catch(function () { return null; })
          .then(function (aiResult) {
            var region = localRegion;
            if (aiResult && aiResult.found) {
              region = {
                real: true,
                corners: {
                  tl: {x: aiResult.x * w, y: aiResult.y * h},
                  tr: {x: (aiResult.x + aiResult.width) * w, y: aiResult.y * h},
                  bl: {x: aiResult.x * w, y: (aiResult.y + aiResult.height) * h},
                  br: {x: (aiResult.x + aiResult.width) * w, y: (aiResult.y + aiResult.height) * h}
                }
              };
            }

            if (!region.real) {
              // No confident wall found — don't guess across the whole
              // photo, that's the exact "fake overlay" bug being fixed.
              return {success: false, image: canvas.toDataURL('image/jpeg', 0.92)};
            }

            var prevOpacity = _opacity;
            _opacity = Math.max(0.0, Math.min(1.0, opacity));
            _drawTextureWithPerspective(region.corners, textureImg, ctx, w, h);
            _opacity = prevOpacity;

            return {success: true, image: canvas.toDataURL('image/jpeg', 0.92)};
          });
      });
  }

  // Main render loop
  var _frameCount = 0;
  function _renderFrame() {
    if (!_video || !_canvas || !_ctx) {
      console.warn('[GraziaAR] Render skipped - missing elements');
      return;
    }
    
    _frameCount++;
    var width = _canvas.width;
    var height = _canvas.height;
    
    // Debug log every 60 frames (once per second at 60fps)
    if (_frameCount % 60 === 0) {
      console.log('[GraziaAR] Rendering frame', _frameCount, 'video ready:', _video.readyState, 'size:', width, 'x', height);
    }
    
    // Draw camera feed
    _ctx.drawImage(_video, 0, 0, width, height);

    if (_manualCorners) {
      // User has manually corrected the wall corners to match the real
      // angle/perspective — trust them completely, skip heuristic detection.
      _wallCorners = _manualCorners;
      _wallDetected = true;
      _hasRealLock = true;
    } else
    // Detect wall every 3 frames (performance optimization)
    if (_frameCount % 3 === 0) {
      // Downsample for edge detection
      var detectWidth = Math.floor(width / 3);
      var detectHeight = Math.floor(height / 3);
      var detectCanvas = document.createElement('canvas');
      detectCanvas.width = detectWidth;
      detectCanvas.height = detectHeight;
      var detectCtx = detectCanvas.getContext('2d');
      detectCtx.drawImage(_video, 0, 0, detectWidth, detectHeight);
      var imageData = detectCtx.getImageData(0, 0, detectWidth, detectHeight);
      
      // Detect edges
      var edges = _detectEdges(imageData, detectWidth, detectHeight);
      
      // Find wall region
      var wallRegion = _findWallRegion(edges, detectWidth, detectHeight);

      // Scale back to full resolution
      var scaledCorners = {
        tl: {x: wallRegion.corners.tl.x * 3, y: wallRegion.corners.tl.y * 3},
        tr: {x: wallRegion.corners.tr.x * 3, y: wallRegion.corners.tr.y * 3},
        bl: {x: wallRegion.corners.bl.x * 3, y: wallRegion.corners.bl.y * 3},
        br: {x: wallRegion.corners.br.x * 3, y: wallRegion.corners.br.y * 3}
      };

      if (wallRegion.real) {
        // Real edges found — smoothly blend toward the new reading so the
        // overlay tracks the wall without jittering frame to frame.
        _lostFrames = 0;
        _hasRealLock = true;
        _wallCorners = _wallCorners
          ? _lerpCorners(_wallCorners, scaledCorners, 0.18)
          : scaledCorners;
      } else if (_hasRealLock && _wallCorners) {
        // Briefly lost strong edges (motion blur while moving closer/back,
        // low light, etc). Stay anchored to the last known wall position
        // instead of snapping to the fixed placeholder.
        // ponytail: heuristic dead-reckoning, not real 3D tracking — release
        // after ~2s (MAX_LOST_FRAMES) of no edges, i.e. camera panned away.
        _lostFrames++;
        var MAX_LOST_FRAMES = 20;
        if (_lostFrames > MAX_LOST_FRAMES) {
          _hasRealLock = false;
          _wallCorners = scaledCorners;
        }
      } else {
        // Never had a real lock yet — show the fallback placeholder so
        // there's still visual feedback while the user aims at a wall.
        _wallCorners = scaledCorners;
      }

      _wallDetected = true;
      _requestAiWallDetection(width, height);
    }

    // Draw visualization — only once we have a REAL detected wall, never for
    // the guessed fallback placeholder. Painting texture over an unconfirmed
    // guess is what made the overlay look like a flat image slapped over the
    // whole screen (floor/furniture included) instead of real tiles on the
    // actual wall.
    if (_hasRealLock && _wallDetected && _wallCorners && _showWallBoundary) {
      // Draw wall detection bracket
      _ctx.save();
      _ctx.strokeStyle = 'rgba(200, 165, 60, 0.5)';
      _ctx.lineWidth = 2;
      _ctx.setLineDash([10, 5]);
      _ctx.beginPath();
      _ctx.moveTo(_wallCorners.tl.x, _wallCorners.tl.y);
      _ctx.lineTo(_wallCorners.tr.x, _wallCorners.tr.y);
      _ctx.lineTo(_wallCorners.br.x, _wallCorners.br.y);
      _ctx.lineTo(_wallCorners.bl.x, _wallCorners.bl.y);
      _ctx.closePath();
      _ctx.stroke();
      _ctx.setLineDash([]);
      
      // Draw corner brackets
      var bracketSize = 22;
      _ctx.strokeStyle = 'rgba(200, 165, 60, 0.9)';
      _ctx.lineWidth = 3;
      _ctx.lineCap = 'round';
      
      // Top-left
      _ctx.beginPath();
      _ctx.moveTo(_wallCorners.tl.x + bracketSize, _wallCorners.tl.y);
      _ctx.lineTo(_wallCorners.tl.x, _wallCorners.tl.y);
      _ctx.lineTo(_wallCorners.tl.x, _wallCorners.tl.y + bracketSize);
      _ctx.stroke();
      
      // Top-right
      _ctx.beginPath();
      _ctx.moveTo(_wallCorners.tr.x - bracketSize, _wallCorners.tr.y);
      _ctx.lineTo(_wallCorners.tr.x, _wallCorners.tr.y);
      _ctx.lineTo(_wallCorners.tr.x, _wallCorners.tr.y + bracketSize);
      _ctx.stroke();
      
      // Bottom-left
      _ctx.beginPath();
      _ctx.moveTo(_wallCorners.bl.x, _wallCorners.bl.y - bracketSize);
      _ctx.lineTo(_wallCorners.bl.x, _wallCorners.bl.y);
      _ctx.lineTo(_wallCorners.bl.x + bracketSize, _wallCorners.bl.y);
      _ctx.stroke();
      
      // Bottom-right
      _ctx.beginPath();
      _ctx.moveTo(_wallCorners.br.x, _wallCorners.br.y - bracketSize);
      _ctx.lineTo(_wallCorners.br.x, _wallCorners.br.y);
      _ctx.lineTo(_wallCorners.br.x - bracketSize, _wallCorners.br.y);
      _ctx.stroke();
      
      _ctx.restore();
      
      // Draw texture if loaded, otherwise show selection hint
      if (_textureImage && _textureImage.complete) {
        _drawTextureWithPerspective(_wallCorners, _textureImage, _ctx, width, height);
      } else {
        _ctx.save();
        _ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        _ctx.fillRect(width/2 - 140, height/2 - 25, 280, 50);
        _ctx.fillStyle = '#C8A53C';
        _ctx.font = 'bold 14px -apple-system, sans-serif';
        _ctx.textAlign = 'center';
        _ctx.textBaseline = 'middle';
        _ctx.fillText('Select a stone to preview on wall', width/2, height/2);
        _ctx.restore();
      }
    } else {
      // Show hint message
      _ctx.save();
      _ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
      _ctx.fillRect(width/2 - 160, height/2 - 35, 320, 70);
      _ctx.fillStyle = '#C8A53C';
      _ctx.font = 'bold 15px -apple-system, sans-serif';
      _ctx.textAlign = 'center';
      _ctx.textBaseline = 'middle';
      _ctx.fillText('Move camera towards a flat wall', width/2, height/2 - 10);
      _ctx.font = '13px -apple-system, sans-serif';
      _ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
      _ctx.fillText('Wall detection will activate automatically', width/2, height/2 + 15);
      _ctx.restore();
    }
    
    _animationFrame = requestAnimationFrame(_renderFrame);
  }

  // Public API
  window.GraziaAR = {

    init: function (containerId) {
      var el = _findContainer(containerId);
      if (!el) return false;

      // Flutter tears down and recreates the platform-view container on every
      // navigation, so re-parent the existing video/canvas into the new node
      // instead of only ever wiring them up once.
      if (_initDone && _container === el) return true;

      el.style.cssText = 'position:relative;width:100%;height:100%;overflow:hidden;background:#000;';

      if (!_initDone) {
        _initDone = true;

        // Video element (hidden, used as source)
        _video = document.createElement('video');
        _video.setAttribute('autoplay', '');
        _video.setAttribute('playsinline', '');
        _video.setAttribute('muted', '');
        _video.setAttribute('webkit-playsinline', '');
        _video.muted = true;
        _video.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;';

        // Canvas for rendering
        _canvas = document.createElement('canvas');
        _canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;';
        _ctx = _canvas.getContext('2d', {alpha: false, desynchronized: true});
      }

      el.appendChild(_video);
      el.appendChild(_canvas);
      _container = el;

      // Auto-resize canvas when container changes size
      if (typeof ResizeObserver !== 'undefined') {
        var ro = new ResizeObserver(function () {
          window.GraziaAR._resizeCanvas();
        });
        ro.observe(_container);
      }
      window.GraziaAR._resizeCanvas();

      return true;
    },

    // Handle canvas resize when container size changes
    _resizeCanvas: function () {
      if (!_canvas || !_video) return;
      var parent = _canvas.parentElement;
      if (!parent) return;
      var rect = parent.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        // Keep aspect ratio from video but fit container
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
        console.error('[GraziaAR]', window._graziaARError);
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
          console.error('[GraziaAR]', window._graziaARError);
          return Promise.reject(window._graziaARError);
        }
        console.log('[GraziaAR] Trying constraint set', idx);
        return navigator.mediaDevices.getUserMedia(constraintSets[idx])
          .then(function (stream) {
            console.log('[GraziaAR] Got media stream', stream);
            _stream = stream;
            _video.srcObject = stream;
            
            return new Promise(function(resolve, reject) {
              _video.onloadedmetadata = function() {
                console.log('[GraziaAR] Video metadata loaded, dimensions:', _video.videoWidth, 'x', _video.videoHeight);
                // Backing store must match the container's CSS pixel size
                // (not the raw video resolution) — _wallCorners/manual drag
                // coordinates are all in CSS-pixel space, same as the
                // Flutter overlay's Offsets. Sizing to video resolution here
                // desynced the two spaces and broke corner dragging.
                window.GraziaAR._resizeCanvas();

                var playPromise = _video.play();
                if (playPromise !== undefined) {
                  playPromise.then(function () {
                    console.log('[GraziaAR] Video playing');
                    window._graziaARReady = true;
                    _renderFrame();
                    resolve('ready');
                  }).catch(function (err) {
                    console.warn('[GraziaAR] Play failed, retrying with muted');
                    _video.muted = true;
                    _video.play().then(function () {
                      console.log('[GraziaAR] Video playing (muted)');
                      window._graziaARReady = true;
                      _renderFrame();
                      resolve('ready');
                    }).catch(reject);
                  });
                } else {
                  console.log('[GraziaAR] Video playing (no promise)');
                  window._graziaARReady = true;
                  _renderFrame();
                  resolve('ready');
                }
              };
            });
          })
          .catch(function (err) {
            console.warn('[GraziaAR] Constraint set', idx, 'failed:', err);
            return tryNext(idx + 1);
          });
      }

      return tryNext(0);
    },

    stopCamera: function () {
      if (_mediaRecorder) {
        _mediaRecorder.stop();
        _mediaRecorder = null;
        _recordedChunks = [];
      }
      if (_animationFrame) {
        cancelAnimationFrame(_animationFrame);
        _animationFrame = null;
      }
      if (_stream) {
        _stream.getTracks().forEach(function (t) { t.stop(); });
        _stream = null;
      }
      if (_video) _video.srcObject = null;
      if (_ctx && _canvas) _ctx.clearRect(0, 0, _canvas.width, _canvas.height);
      window._graziaARReady = false;
      _wallDetected = false;
      _wallCorners = null;
      _hasRealLock = false;
      _lostFrames = 0;
      _frameCount = 0;
    },

    setTexture: function (textureUrl) {
      if (!textureUrl) {
        _textureImage = null;
        return;
      }
      
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function () {
        _textureImage = img;
      };
      img.onerror = function () {
        console.warn('[GraziaAR] Failed to load texture:', textureUrl);
      };
      img.src = textureUrl;
    },

    isReady: function () {
      return window._graziaARReady === true;
    },

    getError: function () {
      return window._graziaARError;
    },

    setOpacity: function (value) {
      _opacity = Math.max(0.0, Math.min(1.0, value));
      console.log('[GraziaAR] Opacity set to', _opacity);
    },

    setScale: function (value) {
      _scale = Math.max(0.1, Math.min(5.0, value));
      console.log('[GraziaAR] Scale set to', _scale);
    },

    setPosition: function (x, y) {
      _position = {x: x || 0, y: y || 0};
      console.log('[GraziaAR] Position set to', _position);
    },

    setRotation: function (degrees) {
      _rotation = degrees || 0;
      console.log('[GraziaAR] Rotation set to', _rotation, 'degrees');
    },

    renderStaticVisualization: function (roomImageUrl, textureUrl, opacity) {
      window._graziaARStaticResult = null;
      window._graziaARStaticError = null;
      renderStaticVisualization(roomImageUrl, textureUrl, opacity)
        .then(function (result) { window._graziaARStaticResult = JSON.stringify(result); })
        .catch(function (e) {
          window._graziaARStaticError = e ? (e.message || e.toString()) : 'Visualization failed';
        });
    },

    showWallBoundary: function (show) {
      _showWallBoundary = show !== false;
      console.log('[GraziaAR] Wall boundary', _showWallBoundary ? 'shown' : 'hidden');
    },

    getWallCorners: function () {
      if (!_wallCorners) return null;
      return {
        tl: {x: _wallCorners.tl.x, y: _wallCorners.tl.y},
        tr: {x: _wallCorners.tr.x, y: _wallCorners.tr.y},
        bl: {x: _wallCorners.bl.x, y: _wallCorners.bl.y},
        br: {x: _wallCorners.br.x, y: _wallCorners.br.y}
      };
    },

    getWallDetected: function () {
      return _wallDetected;
    },

    // Manual corner override — the local edge heuristic only finds an
    // axis-aligned rectangle, so it can never represent a wall photographed
    // at an angle. Letting the user drag the 4 corners onto the real wall
    // outline is the reliable fix; _drawTextureWithPerspective already
    // supports arbitrary (non-rectangular) quads.
    setManualCorner: function (name, x, y) {
      if (!_wallCorners) return;
      if (!_manualCorners) {
        _manualCorners = {
          tl: {x: _wallCorners.tl.x, y: _wallCorners.tl.y},
          tr: {x: _wallCorners.tr.x, y: _wallCorners.tr.y},
          bl: {x: _wallCorners.bl.x, y: _wallCorners.bl.y},
          br: {x: _wallCorners.br.x, y: _wallCorners.br.y}
        };
      }
      _manualCorners[name] = {x: x, y: y};
    },

    clearManualCorners: function () {
      _manualCorners = null;
    },

    hasManualCorners: function () {
      return _manualCorners !== null;
    },

    getWallCornersJson: function () {
      if (!_wallCorners) return null;
      return JSON.stringify(_wallCorners);
    },

    // Records exactly what's on screen (camera + texture overlay) by
    // capturing the render canvas itself — no separate compositing needed.
    startRecording: function () {
      if (!_canvas || _mediaRecorder) return false;
      var stream = _canvas.captureStream(30);
      var mimeType = MediaRecorder.isTypeSupported('video/mp4')
        ? 'video/mp4'
        : (MediaRecorder.isTypeSupported('video/webm;codecs=vp9') ? 'video/webm;codecs=vp9' : 'video/webm');
      _recordedChunks = [];
      _mediaRecorder = new MediaRecorder(stream, { mimeType: mimeType });
      _mediaRecorder.ondataavailable = function (e) {
        if (e.data && e.data.size > 0) _recordedChunks.push(e.data);
      };
      _mediaRecorder.start();
      console.log('[GraziaAR] Recording started');
      return true;
    },

    // Stops recording and triggers a browser download of the captured clip.
    stopRecording: function () {
      if (!_mediaRecorder) return false;
      var mimeType = _mediaRecorder.mimeType || 'video/webm';
      _mediaRecorder.onstop = function () {
        var blob = new Blob(_recordedChunks, { type: mimeType });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = 'grazia-ar-' + Date.now() + (mimeType.indexOf('mp4') >= 0 ? '.mp4' : '.webm');
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
        _recordedChunks = [];
        console.log('[GraziaAR] Recording saved');
      };
      _mediaRecorder.stop();
      _mediaRecorder = null;
      return true;
    },

    isRecording: function () {
      return _mediaRecorder !== null && _mediaRecorder.state === 'recording';
    }

  };
})();
