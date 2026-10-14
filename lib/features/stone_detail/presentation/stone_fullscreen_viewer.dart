import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

const _gold = Color(0xFFC9A24B);

/// Full-screen stone viewer: pinch/double-tap zoom on the photo, or a real 3D slab
/// (photo as colour + relief map, true thickness) that can be orbited 360 and zoomed.
/// [images] are the colour variants; the thumbnail strip switches between them.
class StoneFullscreenViewer extends StatefulWidget {
  final String title;
  final List<String> images;
  final List<String> labels;
  final int initialIndex;
  final double thicknessMm;
  final bool start3D;

  const StoneFullscreenViewer({
    super.key,
    required this.title,
    required this.images,
    required this.labels,
    this.initialIndex = 0,
    this.thicknessMm = 20,
    this.start3D = false,
  });

  @override
  State<StoneFullscreenViewer> createState() => _StoneFullscreenViewerState();
}

class _StoneFullscreenViewerState extends State<StoneFullscreenViewer> {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);
  late bool _is3D = widget.start3D;
  final _zoomCtrl = TransformationController();
  WebViewController? _web;
  bool _webLoaded = false;
  String? _webError;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (_is3D) _init3D();
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    super.dispose();
  }

  Future<void> _init3D() async {
    if (_web != null) return;
    final js = await rootBundle.loadString('assets/3d/model-viewer.min.js');
    final glb = base64Encode((await rootBundle.load('assets/3d/slab.glb')).buffer.asUint8List());
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0A09))
      ..addJavaScriptChannel('SlabBridge', onMessageReceived: _onMessage)
      ..loadHtmlString(_html(js, glb));
    if (!mounted) return;
    setState(() => _web = web);
  }

  void _onMessage(JavaScriptMessage m) {
    final msg = m.message;
    if (msg == 'loaded') {
      _webLoaded = true;
      _applyTexture();
    } else if (msg == 'ready') {
      if (mounted) setState(() => _webError = null);
    } else if (msg.startsWith('error:')) {
      debugPrint('Slab3D $msg');
      if (mounted) setState(() => _webError = msg.substring(6));
    }
  }

  void _applyTexture() {
    if (!_webLoaded || _web == null) return;
    final url = jsonEncode(widget.images[_index]);
    _web!.runJavaScript('setTexture($url, ${widget.thicknessMm});');
  }

  void _selectColour(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _zoomCtrl.value = Matrix4.identity();
    });
    _applyTexture();
  }

  void _setMode(bool to3D) {
    if (to3D == _is3D) return;
    setState(() => _is3D = to3D);
    if (to3D) {
      _init3D().then((_) => _applyTexture());
    }
  }

  void _onDoubleTap() {
    final zoomed = _zoomCtrl.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed) {
      _zoomCtrl.value = Matrix4.identity();
      return;
    }
    const s = 3.0;
    final p = _doubleTapAt;
    _zoomCtrl.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A09),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _is3D ? _view3D() : _viewZoom()),
            _thumbnails(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          _modeChip('Zoom', Icons.zoom_in_rounded, !_is3D, () => _setMode(false)),
          const SizedBox(width: 8),
          _modeChip('3D', Icons.view_in_ar_rounded, _is3D, () => _setMode(true)),
        ],
      ),
    );
  }

  Widget _modeChip(String label, IconData icon, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _gold : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: on ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: on ? Colors.black : Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _viewZoom() {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        key: ValueKey(_index),
        transformationController: _zoomCtrl,
        minScale: 1,
        maxScale: 10,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.images[_index],
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            width: double.infinity,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: _gold)),
            errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _view3D() {
    final web = _web;
    if (web == null) return const Center(child: CircularProgressIndicator(color: _gold));
    return Stack(
      children: [
        WebViewWidget(controller: web),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
              child: Text(
                _webError != null
                    ? '3D unavailable on this device. Use Zoom.'
                    : 'Drag to rotate 360°  •  Pinch to zoom  •  Thickness ${widget.thicknessMm.toStringAsFixed(0)} mm',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnails() {
    if (widget.images.length < 2) return const SizedBox(height: 8);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final on = i == _index;
          return GestureDetector(
            onTap: () => _selectColour(i),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: on ? _gold : Colors.white12, width: on ? 2.5 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: widget.images[i], fit: BoxFit.cover, memCacheWidth: 200),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          widget.labels[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _html(String js, String glbBase64) => _template
      .replaceFirst('__JS__', js)
      .replaceFirst('__GLB__', glbBase64);

  // The slab is a unit cube scaled to (1, aspect, thickness/600mm). The photo is the colour map and a
  // luminance-derived normal map, so lighting while orbiting shows the stone's relief.
  static const _template = r'''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;height:100%;background:#0B0A09;overflow:hidden}
model-viewer{width:100%;height:100%;background:#0B0A09;--poster-color:#0B0A09;outline:none}</style>
<script type="module">__JS__</script></head><body>
<model-viewer id="m" src="data:model/gltf-binary;base64,__GLB__" camera-controls touch-action="none"
 camera-orbit="-25deg 72deg auto" min-camera-orbit="auto auto 0.35m" max-camera-orbit="auto auto 6m"
 environment-image="neutral" exposure="1.15" shadow-intensity="0.9" interaction-prompt="none"></model-viewer>
<script>
const v=document.getElementById('m');
function post(t){try{SlabBridge.postMessage(t)}catch(e){}}
function loadImg(url){return new Promise((res,rej)=>{const i=new Image();i.crossOrigin='anonymous';
 i.onload=()=>res(i);i.onerror=()=>rej(new Error('image load failed'));i.src=url;});}
function normalMap(img,strength){
 const w=Math.min(img.width,512),h=Math.max(1,Math.round(w*img.height/img.width));
 const c=document.createElement('canvas');c.width=w;c.height=h;const x=c.getContext('2d');x.drawImage(img,0,0,w,h);
 const d=x.getImageData(0,0,w,h),g=new Float32Array(w*h);
 for(let i=0;i<w*h;i++)g[i]=(0.299*d.data[4*i]+0.587*d.data[4*i+1]+0.114*d.data[4*i+2])/255;
 const at=(a,b)=>g[Math.min(h-1,Math.max(0,b))*w+Math.min(w-1,Math.max(0,a))];
 const o=x.createImageData(w,h);
 for(let b=0;b<h;b++)for(let a=0;a<w;a++){
  const nx=-(at(a+1,b)-at(a-1,b))*strength,ny=(at(a,b+1)-at(a,b-1))*strength,l=Math.hypot(nx,ny,1),p=4*(b*w+a);
  o.data[p]=(nx/l*.5+.5)*255;o.data[p+1]=(ny/l*.5+.5)*255;o.data[p+2]=(1/l*.5+.5)*255;o.data[p+3]=255;}
 x.putImageData(o,0,0);return c.toDataURL('image/png');}
async function setTexture(url,thicknessMm){
 try{
  const img=await loadImg(url),mat=v.model.materials[0];
  mat.pbrMetallicRoughness.baseColorTexture.setTexture(await v.createTexture(url));
  mat.normalTexture.setTexture(await v.createTexture(normalMap(img,2.4)));
  v.scale='1 '+(img.height/img.width)+' '+Math.max(0.02,thicknessMm/600);
  post('ready');
 }catch(e){post('error:'+(e&&e.message||e));}}
customElements.whenDefined('model-viewer').then(()=>{
 if(v.loaded)post('loaded');
 v.addEventListener('load',()=>post('loaded'));
});
v.addEventListener('error',e=>post('error:model '+(e.detail&&e.detail.type||'')));
</script></body></html>''';
}
