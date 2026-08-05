// Grazia Stones AR Camera Engine
// Real camera access + stone texture overlay for Live AI screen
// Uses CSS mix-blend-mode:multiply for realistic AR stone projection

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

  window.GraziaAR = {

    // Initialize the AR container inside the given div
    init: function (containerId) {
      _container = document.getElementById(containerId);
      if (!_container) return false;
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
      _video.setAttribute('playsinline', '');
      _video.setAttribute('muted', '');
      _video.muted = true;
      _video.style.cssText = [
        'position:absolute;top:0;left:0;',
        'width:100%;height:100%;',
        'object-fit:cover;',
        'z-index:1;',
      ].join('');
      _container.appendChild(_video);

      // ── Stone texture overlay ──
      _textureOverlay = document.createElement('div');
      _textureOverlay.style.cssText = [
        'position:absolute;inset:0;',
        'z-index:2;',
        'background-size:280px 280px;',
        'background-repeat:repeat;',
        'mix-blend-mode:multiply;',
        'opacity:0;',
        'pointer-events:none;',
        'transition:opacity 0.5s cubic-bezier(.4,0,.2,1), background-image 0.3s ease;',
      ].join('');
      _container.appendChild(_textureOverlay);

      // ── Subtle dark vignette for depth ──
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
        'box-shadow:inset 0 0 40px rgba(200,165,60,0);',
      ].join('');
      ['tl','tr','bl','br'].forEach(function(pos) {
        _wallBracket.appendChild(_createCornerBracket(pos));
      });
      _wallBracket.style.opacity = '0';
      _container.appendChild(_wallBracket);

      return true;
    },

    // Request camera permission and start stream
    startCamera: function () {
      window._graziaARReady = false;
      window._graziaARError = null;

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        window._graziaARError = 'Camera API not supported';
        return Promise.reject(window._graziaARError);
      }

      return navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
        audio: false,
      }).then(function (stream) {
        _stream = stream;
        if (_video) {
          _video.srcObject = stream;
          return _video.play().then(function () {
            window._graziaARReady = true;
            return 'ready';
          });
        }
        return 'no-video';
      }).catch(function (err) {
        window._graziaARError = err ? err.message || err.toString() : 'Camera error';
        return Promise.reject(window._graziaARError);
      });
    },

    // Stop all camera tracks
    stopCamera: function () {
      if (_stream) {
        _stream.getTracks().forEach(function (t) { t.stop(); });
        _stream = null;
      }
      window._graziaARReady = false;
    },

    // Apply a stone texture to the AR overlay
    // imageUrl: relative path like 'assets/images/grande_ledge_ta02.png'
    // opacity: 0.0 – 1.0
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

    // Live opacity control (e.g. from a slider)
    setOpacity: function (opacity) {
      if (_textureOverlay) {
        _textureOverlay.style.opacity = String(Math.max(0, Math.min(1, opacity)));
      }
    },

    // Switch blending mode: 'multiply' (natural), 'overlay', 'screen', 'hard-light'
    setBlendMode: function (mode) {
      if (_textureOverlay) {
        _textureOverlay.style.mixBlendMode = mode || 'multiply';
      }
    },

    // Show / hide wall detection golden bracket
    showWallDetection: function (show) {
      if (!_wallBracket) return;
      if (show) {
        _wallBracket.style.opacity = '1';
        _wallBracket.style.border = '1px dashed rgba(200,165,60,0.75)';
        _wallBracket.style.boxShadow = [
          'inset 0 0 60px rgba(200,165,60,0.08)',
          '0 0 0 1px rgba(200,165,60,0.15)',
        ].join(',');
        // Animate bracket pulsing
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
  };
})();
