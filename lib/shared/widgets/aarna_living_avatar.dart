import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Poses the chat UI can ask for. Each maps to a clip of the 3D model (see [AarnaRenders.forPose]).
enum AarnaPose { idle, searching, combinations, quote, technical, waving }

const _kGold = Color(0xFFD4AF37);

/// Renders of the real 3D model (assets/3d/aarna.glb), produced by tool/aarna_sprites. Animated WebP plays natively in
/// Flutter, so every small avatar moves with the model's own clips without a WebGL view per avatar.
abstract final class AarnaRenders {
  static const _dir = 'assets/3d/renders';
  static const headIdle = '$_dir/aarna_head_idle.webp';
  static const headWave = '$_dir/aarna_head_wave.webp';
  static const headThink = '$_dir/aarna_head_think.webp';
  static const bodyIdle = '$_dir/aarna_body_idle.webp';
  static const bodyIdleAlt = '$_dir/aarna_body_idle_alt.webp';
  static const bodyWave = '$_dir/aarna_body_wave.webp';
  static const bodyThink = '$_dir/aarna_body_think.webp';
  static const bodyHop = '$_dir/aarna_body_hop.webp';
  static const posterFull = '$_dir/aarna_poster_full.png';
  static const posterHead = '$_dir/aarna_poster_head.png';

  static String forPose(AarnaPose pose, {bool body = false}) => switch (pose) {
        AarnaPose.waving => body ? bodyWave : headWave,
        AarnaPose.searching => body ? bodyThink : headThink,
        AarnaPose.quote => body ? bodyHop : headIdle,
        AarnaPose.technical => body ? bodyIdleAlt : headIdle,
        AarnaPose.combinations || AarnaPose.idle => body ? bodyIdle : headIdle,
      };
}

/// Aarna, Grazia's AI consultant.
///
/// From [liveThreshold] up she is the live 3D model rendered by model-viewer (drag to turn, tap to wave). Smaller
/// avatars play renders of the same model (idle / wave / think clips), so lists of chat bubbles stay smooth.
class AarnaLivingAvatar extends StatelessWidget {
  static const double liveThreshold = 90;

  final double size;
  final AarnaPose pose;
  final bool isSearching;
  final bool showRadarRings;
  final bool showOnlineBadge;
  final bool greetOnLoad;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  /// Header style: the head rises out of the top of the ring (the bow breaks the circle).
  final bool popOut;

  const AarnaLivingAvatar({
    super.key,
    this.size = 48,
    this.pose = AarnaPose.idle,
    this.isSearching = false,
    this.showRadarRings = false,
    this.showOnlineBadge = true,
    this.greetOnLoad = false,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.onTap,
    this.popOut = false,
    // Kept so existing call sites compile; the 3D model replaced these 2D effects.
    bool showSparkle = true,
    bool showHologramRing = true,
    bool enableInteractiveTilt = true,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isSearching || showRadarRings;
    if (size >= liveThreshold) {
      final radius = shape == BoxShape.circle ? BorderRadius.circular(size / 2) : (borderRadius ?? BorderRadius.circular(size / 4));
      return ClipRRect(
        borderRadius: radius,
        child: Aarna3DView(
          size: size,
          thinking: busy,
          wave: pose == AarnaPose.waving,
          greetOnLoad: greetOnLoad,
          onTap: onTap,
        ),
      );
    }

    final clip = AarnaRenders.forPose(busy ? AarnaPose.searching : pose);
    final isCircle = shape == BoxShape.circle;
    final radius = isCircle ? BorderRadius.circular(size) : (borderRadius ?? BorderRadius.circular(size / 4));
    final model = _Interactive3D(
      child: Image.asset(
        clip,
        // Key by clip so switching pose restarts the new animation from its first frame.
        key: ValueKey(clip),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Aarna',
      ),
    );

    final Widget face = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Ring(size: size, shape: shape, radius: radius, glow: busy),
          Positioned.fill(
            child: ClipPath(
              clipper: popOut ? _PopOutClipper() : null,
              clipBehavior: Clip.antiAlias,
              child: popOut ? Transform.scale(scale: 1.18, alignment: const Alignment(0, 0.4), child: model) : ClipRRect(borderRadius: radius, child: model),
            ),
          ),
          if (showOnlineBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: _OnlineDot(d: (size * 0.26).clamp(7.0, 14.0)),
            ),
        ],
      ),
    );

    return onTap == null
        ? face
        : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: face);
  }
}

/// The marble-cream backdrop and gold hairline ring. While Aarna is thinking the ring breathes.
class _Ring extends StatefulWidget {
  final double size;
  final BoxShape shape;
  final BorderRadius radius;
  final bool glow;

  const _Ring({required this.size, required this.shape, required this.radius, required this.glow});

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    if (widget.glow) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Ring old) {
    super.didUpdateWidget(old);
    if (widget.glow && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.glow && _c.isAnimating) _c.animateTo(0, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = widget.shape == BoxShape.circle;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: isCircle ? null : widget.radius,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.4),
              radius: 1.1,
              colors: [Color(0xFFFFFAF1), Color(0xFFEFE2CC), Color(0xFFDCC6A4)],
              stops: [0, 0.65, 1],
            ),
            border: Border.all(color: _kGold.withValues(alpha: 0.55 + 0.4 * t), width: 1.1 + 0.6 * t),
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: 0.10 + 0.30 * t),
                blurRadius: 6 + 10 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineDot extends StatelessWidget {
  final double d;
  const _OnlineDot({required this.d});

  @override
  Widget build(BuildContext context) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
      );
}

/// Circle for the lower half, open above the centre line: the model sits in the ring but her head and bow rise out of it.
class _PopOutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..addOval(Offset.zero & s)
    ..addRect(Rect.fromLTRB(-s.width * 0.1, -s.height * 0.4, s.width * 1.1, s.height / 2));

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Camera framings for the live view.
enum AarnaFraming { fullBody, head }

/// Live 3D Aarna. Shows a still render of the model until WebGL is ready (and if the WebView fails).
class Aarna3DView extends StatefulWidget {
  final double size;
  final bool wave;
  final bool greetOnLoad;
  final bool thinking;
  final AarnaFraming framing;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onReady;

  const Aarna3DView({
    super.key,
    required this.size,
    this.wave = false,
    this.greetOnLoad = false,
    this.thinking = false,
    this.framing = AarnaFraming.fullBody,
    this.interactive = true,
    this.onTap,
    this.onReady,
  });

  @override
  State<Aarna3DView> createState() => Aarna3DViewState();
}

class Aarna3DViewState extends State<Aarna3DView> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  WebViewController? _web;
  bool _ready = false;

  // The hero card lives in a ListView; without keep-alive every scroll-away recreated the WebView (1-2 s reload).
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    try {
      final js = await rootBundle.loadString('assets/3d/model-viewer.min.js');
      final glb = base64Encode((await rootBundle.load('assets/3d/aarna.glb')).buffer.asUint8List());
      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (r) {
              // Only the inline page may load; never follow links out of the avatar.
              return r.url == 'about:blank' || r.url.startsWith('data:') ? NavigationDecision.navigate : NavigationDecision.prevent;
            },
          ),
        )
        ..addJavaScriptChannel('AarnaBridge', onMessageReceived: _onMessage)
        ..loadHtmlString(_html(js, glb, widget.framing, widget.interactive));
      if (!mounted) return;
      setState(() => _web = web);
    } catch (e) {
      debugPrint('Aarna3D: could not start 3D view, showing render instead: $e');
    }
  }

  void _onMessage(JavaScriptMessage m) {
    if (!mounted) return;
    switch (m.message) {
      case 'ready':
        setState(() => _ready = true);
        if (widget.greetOnLoad || widget.wave) run('wave()');
        if (widget.thinking) run('search(true)');
        widget.onReady?.call();
      case 'tap':
        widget.onTap?.call();
    }
  }

  /// Runs a command in the model page: wave(), hop(), search(bool), peek().
  void run(String code) => _web?.runJavaScript(code).catchError((Object e) => debugPrint('Aarna3D js: $e'));

  @override
  void didUpdateWidget(covariant Aarna3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (widget.wave && !oldWidget.wave) run('wave()');
    // Thinking: she plays her Think clip and glances around; when the answer lands she leans in and waves.
    if (widget.thinking != oldWidget.thinking) run(widget.thinking ? 'search(true)' : 'search(false);peek()');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop rendering while backgrounded so the avatar costs no battery.
    run(state == AppLifecycleState.resumed ? 'resumeAnim()' : 'pauseAnim()');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _ready ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Image.asset(
              widget.framing == AarnaFraming.head ? AarnaRenders.posterHead : AarnaRenders.posterFull,
              fit: BoxFit.contain,
              semanticLabel: 'Aarna',
            ),
          ),
          if (_web != null) WebViewWidget(controller: _web!),
        ],
      ),
    );
  }

  static String _html(String modelViewerJs, String glbBase64, AarnaFraming framing, bool interactive) {
    // Camera presets must match tool/aarna_sprites/shots.json so the live view and the renders line up.
    final (orbit, target, fov) = switch (framing) {
      AarnaFraming.fullBody => ('0deg 82deg 2.4m', '0m 0.45m 0m', '28deg'),
      AarnaFraming.head => ('8deg 84deg 1.72m', '0m 0.63m 0m', '28deg'),
    };
    final controls = interactive
        ? 'camera-controls disable-zoom disable-pan min-camera-orbit="-35deg 68deg auto" max-camera-orbit="35deg 96deg auto"'
        : '';
    return '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;height:100%;background:transparent;overflow:hidden}
model-viewer{width:100%;height:100%;background:transparent;--poster-color:transparent;outline:none}</style>
<script type="module">$modelViewerJs</script></head><body>
<model-viewer id="m" src="data:model/gltf-binary;base64,$glbBase64" $controls
 camera-orbit="$orbit" camera-target="$target" field-of-view="$fov"
 interpolation-decay="90" exposure="1.15" shadow-intensity="0" environment-image="neutral"
 interaction-prompt="none" touch-action="pan-y"></model-viewer>
<script>
const m=document.getElementById('m');
const home='$orbit', homeTarget='$target', homeFov='$fov';
const has=n=>(m.availableAnimations||[]).includes(n);
let paused=false, searching=false, blinkT, searchT, peekT, flip=1;
function idle(){m.animationName=searching&&has('Think')?'Think':'Idle';m.play({repetitions:Infinity});}
function once(n){if(!has(n))return;m.animationName=n;m.play({repetitions:1});}
function wave(){once('Wave');}
function hop(){once('Hop');}
// model-viewer plays one clip at a time, so blinks are short clip swaps while idling.
function blink(){if(paused||m.animationName!=='Idle')return;once('Blink');}
function scheduleBlink(){clearTimeout(blinkT);blinkT=setTimeout(()=>{blink();scheduleBlink();},2600+Math.random()*2600);}
// Thinking: the Think clip loops and the camera drifts side to side so she seems to look around.
function search(on){searching=on;clearTimeout(searchT);idle();if(!on){m.cameraOrbit=home;return;}
  const step=()=>{if(!searching)return;flip=-flip;m.cameraOrbit=(flip*16)+'deg 79deg '+home.split(' ')[2];searchT=setTimeout(step,1400+Math.random()*500);};step();}
// Peek: she leans toward the viewer and waves, then settles back.
function peek(){clearTimeout(peekT);m.cameraTarget='0m 0.60m 0m';m.fieldOfView='21deg';m.cameraOrbit='-14deg 77deg 1.55m';wave();
  peekT=setTimeout(()=>{m.cameraTarget=homeTarget;m.fieldOfView=homeFov;m.cameraOrbit=home;},2600);}
function pauseAnim(){paused=true;m.pause();clearTimeout(blinkT);clearTimeout(searchT);}
function resumeAnim(){paused=false;idle();scheduleBlink();if(searching)search(true);}
m.addEventListener('load',()=>{idle();scheduleBlink();AarnaBridge.postMessage('ready');});
// One-shot clips (Wave, Hop, Blink) all return to the idle loop.
m.addEventListener('finished',idle);
m.addEventListener('click',()=>{peek();AarnaBridge.postMessage('tap');});
// After a drag she springs back to the rest view instead of staying turned.
let back;m.addEventListener('camera-change',e=>{if(e.detail.source==='user-interaction'&&!searching){clearTimeout(back);back=setTimeout(()=>{m.cameraOrbit=home;},900);}});
</script></body></html>''';
  }
}

/// Makes a small avatar react to touch: it turns toward the finger (perspective tilt), springs back with a little
/// overshoot on release, and gives a soft bounce on tap. Uses raw pointer events, so the avatar's own onTap and any
/// surrounding scroll view keep working.
class _Interactive3D extends StatefulWidget {
  final Widget child;
  const _Interactive3D({required this.child});

  @override
  State<_Interactive3D> createState() => _Interactive3DState();
}

class _Interactive3DState extends State<_Interactive3D> with TickerProviderStateMixin {
  static const _maxTilt = 0.5; // radians at the edge
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  Offset _tilt = Offset.zero; // -1..1 from the centre
  Offset _from = Offset.zero;

  @override
  void dispose() {
    _back.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _track(PointerEvent e, Size size) {
    if (size.isEmpty) return;
    final c = size.center(Offset.zero);
    final dx = ((e.localPosition.dx - c.dx) / (size.width / 2)).clamp(-1.0, 1.0);
    final dy = ((e.localPosition.dy - c.dy) / (size.height / 2)).clamp(-1.0, 1.0);
    _back.stop();
    _back.value = 0; // a fresh touch starts from the live finger position, not the spring
    setState(() => _tilt = Offset(dx, dy));
  }

  void _release() {
    _from = _tilt;
    _back.forward(from: 0);
    _bounce.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.hasBoundedWidth ? box.maxWidth : 0, box.hasBoundedHeight ? box.maxHeight : 0);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _track(e, size),
          onPointerMove: (e) => _track(e, size),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_back, _bounce]),
            builder: (_, child) {
              final tilt = _back.isAnimating
                  ? Offset.lerp(_from, Offset.zero, Curves.elasticOut.transform(_back.value))!
                  : (_back.value == 1 ? Offset.zero : _tilt);
              final squash = _bounce.isAnimating ? 1 - 0.08 * (1 - Curves.elasticOut.transform(_bounce.value)) : 1.0;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateX(-tilt.dy * _maxTilt)
                  ..rotateY(tilt.dx * _maxTilt)
                  ..scale(squash, squash, 1),
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
