/// ARCameraView – conditional export.
/// On web: uses the real camera via dart:html + GraziaAR JS engine.
/// On mobile: uses camera package for native iOS/Android camera.
library;

export 'ar_camera_view_web.dart'
    if (dart.library.io) 'ar_camera_view_mobile.dart';
