// Grazia Stones AR Camera Engine
// Real camera + stone texture overlay for Live AI screen
// Safari-compatible: user-gesture-based camera start, fallback constraints

(function () {
  'use strict';

  var _stream = null;
  var _video = null;
  var _textureOverlay = null;
  var _wallBracket = null;
  var _container = null;
  var _initDone = false;

  function _createCornerBracket(position) {
    var el = document.createElement('div');
    var isLeft = position === 'tl' || position === 'bl';
    var isTop = position === 'tl' || position === 'tr';
    el.style.cssText = [
      'position:absolute;width:22px;height:22px;',
      isTop ? 'top:-1px;' : 'bottom:-1px;',
      isLeft ? 'left:-1px;' : 'right:-1px;',
      'border-top:' + (isTop ? '3px solid rgba(200,165,60,0.9)' : 'none') + ';',
      'border-bottom:' + (!isTop ? '3px solid rgba(200,165,60,0.9)' : 'none') + ';',
      'border-left:' + (isLeft ? '3px solid rgba(200,165,60,0.9)' : 'none') + ';',
      'border-right:' + (!isLeft ? '3px solid rgba(200,165,60,0.9)' : 'none') + ';',
    ].join('');
    return el;
  }

  // Find the container by id, checking shadow DOMs too (Flutter Web wraps in shadow)
  function _findContainer(containerId) {
    // 1. Normal DOM
    var el = document.getElementById(containerId);
    if (el) return el;
    // 2. Search inside every flt-platform-view shadow root
    var views = document.querySelectorAll('flt-platform-view');
    for (var i = 0; i < views.length; i++) {
      if (views[i].shadowRoot) {
        var inner = views[i].shadowRoot.getElementById(containerId);
        if (inner) return inner;
      }
      // also try direct children
      var child = views[i].querySelector('#' + containerId);
      if (child) return child;
    }
    // 3. Deep search in all shadow roots
    var allEls = document.querySelectorAll('*');
    for (var j = 0; j < allEls.length; j++) {
      if (allEls[j].shadowRoot) {
        var found = allEls[j].shadowRoot.getElementById(containerId);
        if (found) return found;
      }
    }
    return null;
  }

  window.GraziaAR = {

    // Initialize the AR container (call this after the div is in DOM)
    init: function (containerId) {
      var el = _findContainer(containerId);
      if (!el) return false;
      _container = el;
      if (_initDone) return true;
      _initDone = true;

      _container.style.cssText = [
        'position:relative;',
        'width:100%;height:100%;',
        'overflow:hidden;',
        'background:#000;',
      ].join('');

      // ── Video element (real camera feed) ──
      _video = document.createElement('video');
      _video.setAttribute('autoplay', '');
      _video.setAttribute('playsinline', '');    // Required for iOS Safari
      _video.setAttribute('muted', '');          // Required for iOS autoplay
      _video.setAttribute('webkit-playsinline', ''); // Older iOS Safari
      _video.muted = true;
      _video.style.cssText = [
        'position:absolute;top:0;left:0;',
        'width:100%;height:100%;',
        'object-fit:cover;',
        'z-index:1;',
        '-webkit-transform:translateZ(0);',      // GPU acceleration on iOS
        'transform:translateZ(0);',
      ].join('');
      _container.appendChild(_video);

      // ── Stone texture overlay ──
      // Use 'screen' blend mode: works on dark camera pixels
      // On dark backgrounds (wall) it brightens with stone color naturally
      _textureOverlay = document.createElement('div');
      _textureOverlay.style.cssText = [
        'position:absolute;inset:0;',
        'z-index:2;',
        'background-size:300px 300px;',
        'background-repeat:repeat;',
        'mix-blend-mode:multiply;',
        '-webkit-mix-blend-mode:multiply;',
        'opacity:0;',
        'pointer-events:none;',
        'transition:opacity 0.5s cubic-bezier(.4,0,.2,1);',
        '-webkit-transition:opacity 0.5s cubic-bezier(.4,0,.2,1);',
      ].join('');
      _container.appendChild(_textureOverlay);

      // ── Subtle dark vignette ──
      var vignette = document.createElement('div');
      vignette.style.cssText = [
        'position:absolute;inset:0;z-index:3;',
        'background:radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.35) 100%);',
        'pointer-events:none;',
      ].join('');
      _container.appendChild(vignette);

      // ── Wall detection bracket ──
      _wallBracket = document.createElement('div');
      _wallBracket.style.cssText = [
        'position:absolute;z-index:4;',
        'top:8%;left:4%;right:4%;bottom:22%;',
        'border:1px dashed rgba(200,165,60,0);',
        'border-radius:4px;',
        'pointer-events:none;',
        'transition:all 0.6s cubic-bezier(.4,0,.2,1);',
        '-webkit-transition:all 0.6s cubic-bezier(.4,0,.2,1);',
        'box-shadow:inset 0 0 40px rgba(200,165,60,0);',
      ].join('');
      ['tl', 'tr', 'bl', 'br'].forEach(function (pos) {
        _wallBracket.appendChild(_createCornerBracket(pos));
      });
      _wallBracket.style.opacity = '0';
      _container.appendChild(_wallBracket);

      return true;
    },

    // Start camera — MUST be called from a user gesture (tap) for Safari
    startCamera: function () {
      window._graziaARReady = false;
      window._graziaARError = null;

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        window._graziaARError = 'Camera API not supported on this browser';
        return Promise.reject(window._graziaARError);
      }

      // Try multiple constraint sets in order (Safari-compatible fallbacks)
      var constraintSets = [
        // 1. Rear camera, HD
        { video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false },
        // 2. Rear camera only (no resolution)
        { video: { facingMode: 'environment' }, audio: false },
        // 3. Any camera (front/rear)
        { video: true, audio: false },
      ];

      function tryNext(idx) {
        if (idx >= constraintSets.length) {
          var msg = 'No camera available. Please allow camera access.';
          window._graziaARError = msg;
          return Promise.reject(msg);
        }
        return navigator.mediaDevices.getUserMedia(constraintSets[idx])
          .then(function (stream) {
            _stream = stream;
            if (!_video) {
              window._graziaARError = 'Video element not ready';
              return Promise.reject(window._graziaARError);
            }
            _video.srcObject = stream;
            // On iOS Safari, play() must be called after setting srcObject
            var playPromise = _video.play();
            if (playPromise !== undefined) {
              return playPromise.then(function () {
                window._graziaARReady = true;
                return 'ready';
              }).catch(function (playErr) {
                // iOS sometimes rejects play() — try muting and replaying
                _video.muted = true;
                return _video.play().then(function () {
                  window._graziaARReady = true;
                  return 'ready';
                });
              });
            } else {
              // Older Safari: no promise from play()
              window._graziaARReady = true;
              return 'ready';
            }
          })
          .catch(function (err) {
            var name = err && err.name ? err.name : '';
            // NotAllowedError / PermissionDeniedError = user denied → don't retry
            if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
              var msg = 'Camera permission denied. Please allow camera access in your browser settings.';
              window._graziaARError = msg;
              return Promise.reject(msg);
            }
            // Otherwise try next constraint set
            return tryNext(idx + 1);
          });
      }

      return tryNext(0);
    },

    // Stop all camera tracks
    stopCamera: function () {
      if (_stream) {
        _stream.getTracks().forEach(function (t) { t.stop(); });
        _stream = null;
      }
      if (_video) {
        _video.srcObject = null;
      }
      window._graziaARReady = false;
    },

    // Apply stone texture overlay
    setStoneTexture: function (imageUrl, opacity) {
      if (!_textureOverlay) return;
      var op = (opacity !== undefined && opacity !== null) ? Math.max(0, Math.min(1, opacity)) : 0.72;
      if (!imageUrl) {
        _textureOverlay.style.opacity = '0';
        return;
      }
      _textureOverlay.style.backgroundImage = 'url("' + imageUrl + '")';
      _textureOverlay.style.opacity = String(op);
    },

    setOpacity: function (opacity) {
      if (_textureOverlay) {
        _textureOverlay.style.opacity = String(Math.max(0, Math.min(1, opacity)));
      }
    },

    setBlendMode: function (mode) {
      if (_textureOverlay) {
        _textureOverlay.style.mixBlendMode = mode || 'multiply';
        _textureOverlay.style['-webkit-mix-blend-mode'] = mode || 'multiply';
      }
    },

    showWallDetection: function (show) {
      if (!_wallBracket) return;
      if (show) {
        _wallBracket.style.opacity = '1';
        _wallBracket.style.border = '1px dashed rgba(200,165,60,0.75)';
        _wallBracket.style.boxShadow = [
          'inset 0 0 60px rgba(200,165,60,0.08)',
          '0 0 0 1px rgba(200,165,60,0.15)',
        ].join(',');
        if (!_wallBracket._interval) {
          var phase = 0;
          _wallBracket._interval = setInterval(function () {
            phase = (phase + 0.05) % (Math.PI * 2);
            var a = 0.5 + 0.3 * Math.sin(phase);
            _wallBracket.style.borderColor = 'rgba(200,165,60,' + a + ')';
          }, 50);
        }
      } else {
        _wallBracket.style.opacity = '0';
        if (_wallBracket._interval) {
          clearInterval(_wallBracket._interval);
          _wallBracket._interval = null;
        }
      }
    },

    isCameraActive: function () {
      return !!(_stream && _stream.active);
    },

    // Reset state (for retry)
    reset: function () {
      window.GraziaAR.stopCamera();
      _initDone = false;
      _container = null;
      _video = null;
      _textureOverlay = null;
      _wallBracket = null;
    },
  };
})();
