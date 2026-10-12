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
    if (busy) {
      face = Stack(
        alignment: Alignment.center,
        children: [
          face,
          SizedBox(
            width: size + 6,
            height: size + 6,
            child: const CircularProgressIndicator(strokeWidth: 1.6, color: _kGold),
          ),
        ],
      );
    }
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
