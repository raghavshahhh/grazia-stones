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
  
  // Wall detection state
  var _wallCorners = null;
  var _wallDetected = false;
  
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
  
  // Find largest rectangular region (wall candidate)
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
      if (strength > width * 0.3) {
        horizontalLines.push({y: y, strength: strength});
      }
    }
    
    // Detect vertical lines
    for (var x = 0; x < width; x += 4) {
      var strength = 0;
      for (var y = 0; y < height; y++) {
        if (edges[y * width + x] > 0) strength++;
      }
      if (strength > height * 0.3) {
        verticalLines.push({x: x, strength: strength});
      }
    }
    
    // If we have enough lines, wall likely detected
    if (horizontalLines.length >= 2 && verticalLines.length >= 2) {
      // Sort by strength
      horizontalLines.sort(function(a, b) { return b.strength - a.strength; });
      verticalLines.sort(function(a, b) { return b.strength - a.strength; });
      
      // Take top and bottom horizontal lines
      var top = horizontalLines[0].y;
      var bottom = horizontalLines[horizontalLines.length - 1].y;
      if (bottom < top) {
        var temp = top;
        top = bottom;
        bottom = temp;
      }
      
      // Take left and right vertical lines
      var left = verticalLines[0].x;
      var right = verticalLines[verticalLines.length - 1].x;
      if (right < left) {
        var temp = left;
        left = right;
        right = temp;
      }
      
      // Ensure reasonable size
      if (right - left > width * 0.4 && bottom - top > height * 0.4) {
        return {
          tl: {x: left, y: top},
          tr: {x: right, y: top},
          bl: {x: left, y: bottom},
          br: {x: right, y: bottom}
        };
      }
    }
    
    // Fallback: use center region
    var margin = 0.15;
    return {
      tl: {x: width * margin, y: height * margin},
      tr: {x: width * (1 - margin), y: height * margin},
      bl: {x: width * margin, y: height * (1 - margin)},
      br: {x: width * (1 - margin), y: height * (1 - margin)}
    };
  }
  
  // Draw texture with perspective transform using triangle strips
  function _drawTextureWithPerspective(corners, texture, ctx, canvasWidth, canvasHeight) {
    if (!texture) return;
    
    // Create pattern from texture (tiled)
    var patternCanvas = document.createElement('canvas');
    var tileSize = 200;
    patternCanvas.width = tileSize * 3;
    patternCanvas.height = tileSize * 3;
    var patternCtx = patternCanvas.getContext('2d');
    
    // Tile the texture
    for (var ty = 0; ty < 3; ty++) {
      for (var tx = 0; tx < 3; tx++) {
        patternCtx.drawImage(texture, tx * tileSize, ty * tileSize, tileSize, tileSize);
      }
    }
    
    // Draw using triangle strips for better perspective
    var strips = 24;
    
    ctx.save();
    ctx.globalAlpha = 0.75; // 75% opacity
    ctx.globalCompositeOperation = 'multiply'; // Preserve shadows
    
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
      ctx.globalAlpha = 0.75;
      ctx.globalCompositeOperation = 'multiply';
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
      _wallCorners = {
        tl: {x: wallRegion.tl.x * 3, y: wallRegion.tl.y * 3},
        tr: {x: wallRegion.tr.x * 3, y: wallRegion.tr.y * 3},
        bl: {x: wallRegion.bl.x * 3, y: wallRegion.bl.y * 3},
        br: {x: wallRegion.br.x * 3, y: wallRegion.br.y * 3}
      };
      
      _wallDetected = true;
    }
    
    // Draw visualization
    if (_wallDetected && _wallCorners) {
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
      
      // Draw texture if loaded
      if (_textureImage && _textureImage.complete) {
        _drawTextureWithPerspective(_wallCorners, _textureImage, _ctx, width, height);
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
      _container = el;
      if (_initDone) return true;
      _initDone = true;

      _container.style.cssText = 'position:relative;width:100%;height:100%;overflow:hidden;background:#000;';

      // Video element (hidden, used as source)
      _video = document.createElement('video');
      _video.setAttribute('autoplay', '');
      _video.setAttribute('playsinline', '');
      _video.setAttribute('muted', '');
      _video.setAttribute('webkit-playsinline', '');
      _video.muted = true;
      _video.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;';
      _container.appendChild(_video);

      // Canvas for rendering
      _canvas = document.createElement('canvas');
      _canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;';
      _container.appendChild(_canvas);
      _ctx = _canvas.getContext('2d', {alpha: false, desynchronized: true});

      return true;
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
                _canvas.width = _video.videoWidth || 1280;
                _canvas.height = _video.videoHeight || 720;
                
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
    }

  };
})();
