import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Poses the chat UI can ask for. Only [waving] has its own 3D clip; the rest play the idle clip.
enum AarnaPose {
  idle,
  searching,
  combinations,
  quote,
  technical,
  waving,
}

const _kGold = Color(0xFFD4AF37);
const _kHeadPoster = 'assets/images/aarna/aarna_3d_head.png';
const _kFullPoster = 'assets/images/aarna/aarna_3d_full.png';

/// Aarna, Grazia's AI consultant.
///
/// Small sizes (AppBar, chat bubbles, prompt pill) show a head render of the real 3D model: a live WebGL view per
/// 32-44px avatar would cost far more than it adds. From [liveThreshold] up the avatar is the live 3D model
/// (assets/3d/aarna.glb: joint-animated Idle / Wave clips, blinking eyes) rendered by model-viewer.
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

  /// Header style: the head pops out above the ring, and while searching/waving an arm comes
  /// out beside the circle (magnifying glass / wave).
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
    if (size >= liveThreshold) {
      return Aarna3DView(
        size: size,
        wave: pose == AarnaPose.waving,
        greetOnLoad: greetOnLoad,
        thinking: isSearching,
        onTap: onTap,
      );
    }
    final busy = isSearching || showRadarRings;
    if (popOut) {
      return _PopOutAvatar(
        size: size,
        searching: busy,
        waving: pose == AarnaPose.waving && !busy,
        showOnlineBadge: showOnlineBadge,
        onTap: onTap,
      );
    }
    final isCircle = shape == BoxShape.circle;
    final radius = borderRadius ?? BorderRadius.circular(size / 4);
    Widget face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: isCircle ? null : radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7EBDB), Color(0xFFE6D2B5)],
        ),
        border: Border.all(color: _kGold.withValues(alpha: 0.65), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: isCircle ? BorderRadius.circular(size) : radius,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(_kHeadPoster, fit: BoxFit.contain, semanticLabel: 'Aarna'),
        ),
      ),
    );
    // Searching: Aarna takes out her magnifying glass and sways, all clipped inside the avatar
    // shape so nothing moves outside the circle.
    if (busy) face = _SearchingFace(size: size, shape: shape, radius: radius);
    if (showOnlineBadge) {
      final d = (size * 0.26).clamp(7.0, 14.0);
      face = Stack(
        clipBehavior: Clip.none,
        children: [
          face,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
            ),
          ),
        ],
      );
    }
    return onTap == null ? face : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: face);
  }
}

const _kSearchPose = 'assets/images/aarna/aarna_pose_designs.png';
const _kRoseGold = Color(0xFFC98F7A);
const _kCream = Color(0xFFFBF1E2);

/// Header avatar: the transparent head render overflows the top of the ring (bow and ears
/// outside the circle), bobs gently, and an arm comes out beside the ring when she is searching
/// (hand + magnifying glass sweeping) or greeting (wave).
class _PopOutAvatar extends StatefulWidget {
  final double size;
  final bool searching;
  final bool waving;
  final bool showOnlineBadge;
  final VoidCallback? onTap;

  const _PopOutAvatar({
    required this.size,
    required this.searching,
    required this.waving,
    required this.showOnlineBadge,
    this.onTap,
  });

  @override
  State<_PopOutAvatar> createState() => _PopOutAvatarState();
}

class _PopOutAvatarState extends State<_PopOutAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final armOut = widget.searching || widget.waving;
    final d = (s * 0.26).clamp(7.0, 14.0);
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: armOut ? s * 1.85 : s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeInOut.transform(_c.value);
          final bob = (t - 0.5) * s * 0.05;
          final tilt = widget.searching ? (t - 0.5) * 0.14 : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7EBDB), Color(0xFFE6D2B5)],
                  ),
                  border: Border.all(color: _kGold.withValues(alpha: 0.65), width: 1.2),
                ),
              ),
              SizedBox(
                width: s,
                height: s,
                child: ClipPath(
                  clipper: _PopOutClipper(),
                  child: OverflowBox(
                    maxWidth: s * 1.4,
                    maxHeight: s * 1.4,
                    child: Transform.translate(
                      offset: Offset(0, bob - s * 0.17),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Image.asset(_kHeadPoster, width: s * 1.05, fit: BoxFit.contain, semanticLabel: 'Aarna'),
                      ),
                    ),
                  ),
                ),
              ),
              if (armOut)
                Positioned(
                  left: 0,
                  top: -s * 0.35,
                  width: s * 1.85,
                  height: s * 1.7,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ArmPainter(s: s, t: t, wave: widget.waving),
                    ),
                  ),
                ),
              if (widget.showOnlineBadge)
                Positioned(
                  left: s - d + 1,
                  bottom: -1,
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    return widget.onTap == null ? body : GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: body);
  }
}

/// Clips to the ring plus everything above its middle, so the head stays inside the circle at
/// the bottom but overflows freely at the top and sides.
class _PopOutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final s = size.width;
    return Path()
      ..addOval(Rect.fromLTWH(0, 0, s, s))
      ..addRect(Rect.fromLTRB(-s * 0.3, -s * 0.6, s * 1.3, s * 0.5));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Arm + hand that reaches out of the ring. Searching: the hand sweeps a magnifying glass side to side.
/// Waving: the hand is raised and rocks. Drawn with paths so it needs no extra art.
class _ArmPainter extends CustomPainter {
  final double s;
  final double t;
  final bool wave;

  _ArmPainter({required this.s, required this.t, required this.wave});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(0, s * 0.35);
    final sway = (t - 0.5) * 2; // -1..1
    final shoulder = Offset(s * 0.82, s * 0.86);
    final hand = wave
        ? Offset(s * 1.2 + sway * s * 0.05, s * 0.18 + sway.abs() * s * 0.03)
        : Offset(s * 1.14 + sway * s * 0.13, s * 0.55 + sway * s * 0.05);

    // Upper arm bends through an elbow so it looks like an arm, not a stick.
    final elbow = Offset(s * 1.12, s * 0.9);
    final armPath = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(elbow.dx, elbow.dy, hand.dx, hand.dy);
    canvas.drawPath(
      armPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.25
        ..color = _kRoseGold,
    );
    canvas.drawPath(
      armPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.19
        ..color = _kCream,
    );
    // Rose-gold cuff just before the hand.
    final cuffAt = Offset.lerp(elbow, hand, 0.72)!;
    canvas.drawCircle(cuffAt, s * 0.115, Paint()..color = _kRoseGold);
    canvas.drawCircle(cuffAt, s * 0.07, Paint()..color = _kCream);
    // Hand.
    canvas.drawCircle(hand, s * 0.15, Paint()..color = _kRoseGold);
    canvas.drawCircle(hand, s * 0.125, Paint()..color = _kCream);

    if (wave) return;

    // Magnifying glass: handle from the hand up to the lens.
    final lens = hand + Offset(s * 0.28, -s * 0.46);
    final dir = (lens - hand) / (lens - hand).distance;
    canvas.drawLine(
      hand,
      lens - dir * (s * 0.22),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.09
        ..color = const Color(0xFF8A6A1F),
    );
    final r = s * 0.22;
    canvas.drawCircle(lens, r, Paint()..color = Colors.white.withValues(alpha: 0.38));
    canvas.drawCircle(
      lens,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.075
        ..color = _kGold,
    );
    canvas.drawArc(
      Rect.fromCircle(center: lens, radius: r * 0.62),
      3.5,
      1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.035
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    // Re-draw the fingers over the handle so the glass looks held.
    canvas.drawCircle(hand, s * 0.15, Paint()..color = _kRoseGold);
    canvas.drawCircle(hand, s * 0.125, Paint()..color = _kCream);
  }

  @override
  bool shouldRepaint(covariant _ArmPainter old) => old.t != t || old.wave != wave || old.s != s;
}

/// Small-avatar "searching" state: Aarna with her magnifying glass, gently swaying with a gold
/// scan line sweeping across. Everything is clipped to the avatar shape.
class _SearchingFace extends StatefulWidget {
  final double size;
  final BoxShape shape;
  final BorderRadius radius;

  const _SearchingFace({required this.size, required this.shape, required this.radius});

  @override
  State<_SearchingFace> createState() => _SearchingFaceState();
}

class _SearchingFaceState extends State<_SearchingFace> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final isCircle = widget.shape == BoxShape.circle;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: isCircle ? null : widget.radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7EBDB), Color(0xFFE6D2B5)],
            ),
            border: Border.all(color: _kGold.withValues(alpha: 0.45 + 0.5 * t), width: 1.6),
          ),
          child: ClipRRect(
            borderRadius: isCircle ? BorderRadius.circular(s) : widget.radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset((t - 0.5) * s * 0.10, (0.5 - t) * s * 0.04),
                  child: Transform.scale(
                    scale: 1.22,
                    child: Image.asset(
                      _kSearchPose,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.2, -0.2),
                      semanticLabel: 'Aarna searching',
                    ),
                  ),
                ),
                Positioned(
                  left: -s * 0.2 + t * s * 1.2,
                  top: 0,
                  bottom: 0,
                  width: s * 0.2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kGold.withValues(alpha: 0),
                          _kGold.withValues(alpha: 0.35),
                          _kGold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Live 3D Aarna. Falls back to the full-body render until the model is ready (and if WebView fails).
class Aarna3DView extends StatefulWidget {
  final double size;
  final bool wave;
  final bool greetOnLoad;
  final bool thinking;
  final VoidCallback? onTap;

  const Aarna3DView({
    super.key,
    required this.size,
    this.wave = false,
    this.greetOnLoad = false,
    this.thinking = false,
    this.onTap,
  });

  @override
  State<Aarna3DView> createState() => _Aarna3DViewState();
}

class _Aarna3DViewState extends State<Aarna3DView> with WidgetsBindingObserver {
  WebViewController? _web;
  bool _ready = false;

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
        ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
          // Only the inline page may load; never follow links out of the avatar.
          return r.url == 'about:blank' || r.url.startsWith('data:') ? NavigationDecision.navigate : NavigationDecision.prevent;
        }))
        ..addJavaScriptChannel('AarnaBridge', onMessageReceived: _onMessage)
        ..loadHtmlString(_html(js, glb));
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
        if (widget.greetOnLoad || widget.wave) _run('wave()');
      case 'tap':
        _run('wave()');
        widget.onTap?.call();
    }
  }

  void _run(String code) => _web?.runJavaScript(code).catchError((Object e) => debugPrint('Aarna3D js: $e'));

  @override
  void didUpdateWidget(covariant Aarna3DView old) {
    super.didUpdateWidget(old);
    if (widget.wave && !old.wave && _ready) _run('wave()');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Stop rendering while backgrounded so the avatar costs no battery.
    _run(s == AppLifecycleState.resumed ? 'resumeAnim()' : 'pauseAnim()');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _ready ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Image.asset(_kFullPoster, fit: BoxFit.contain, semanticLabel: 'Aarna'),
          ),
          if (_web != null) WebViewWidget(controller: _web!),
        ],
      ),
    );
  }

  static String _html(String modelViewerJs, String glbBase64) => '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;height:100%;background:transparent;overflow:hidden}
model-viewer{width:100%;height:100%;background:transparent;--poster-color:transparent;outline:none}</style>
<script type="module">$modelViewerJs</script></head><body>
<model-viewer id="m" src="data:model/gltf-binary;base64,$glbBase64" camera-controls disable-zoom disable-pan
 camera-orbit="0deg 82deg 2.15m" camera-target="0m 0.42m 0m" field-of-view="30deg"
 min-camera-orbit="-35deg 68deg auto" max-camera-orbit="35deg 96deg auto"
 interpolation-decay="90" exposure="1.15" shadow-intensity="0" environment-image="neutral"
 interaction-prompt="none" touch-action="pan-y"></model-viewer>
<script>
const m=document.getElementById('m');
const home='0deg 82deg 2.15m';
function idle(){m.animationName='Idle';m.play({repetitions:Infinity});}
function wave(){m.animationName='Wave';m.play({repetitions:1});}
function pauseAnim(){m.pause();}
function resumeAnim(){m.play({repetitions:m.animationName==='Wave'?1:Infinity});}
m.addEventListener('load',()=>{idle();AarnaBridge.postMessage('ready');});
m.addEventListener('finished',idle);
m.addEventListener('click',()=>AarnaBridge.postMessage('tap'));
// After a drag the head/body spring back to the rest view instead of staying turned.
let back;m.addEventListener('camera-change',e=>{if(e.detail.source==='user-interaction'){clearTimeout(back);back=setTimeout(()=>{m.cameraOrbit=home;},700);}});
</script></body></html>''';
}
