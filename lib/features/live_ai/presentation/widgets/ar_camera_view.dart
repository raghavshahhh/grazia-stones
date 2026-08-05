/// ARCameraView – conditional export.
/// On web: uses the real camera via dart:html + GraziaAR JS engine.
/// On other platforms: renders a no-camera stub.
library;

export 'ar_camera_view_web.dart'
    if (dart.library.io) 'ar_camera_view_stub.dart';
