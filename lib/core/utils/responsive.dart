import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widest the UI is allowed to stretch; beyond this (big tablets, desktop
/// windows) the content stays centred instead of spreading edge to edge.
const double kMaxContentWidth = 1200;

/// Phones keep [phone] columns; wider windows (tablet, Z Fold inner screen,
/// landscape, split-screen) add columns so tiles stay a similar size.
int gridColumns(BuildContext context, {int phone = 2}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return phone + 3;
  if (w >= 840) return phone + 2;
  if (w >= 600) return phone + 1;
  return phone;
}

/// Wraps the whole app: caps content width and unlocks rotation on
/// tablets/foldables (phones stay portrait).
class ResponsiveFrame extends StatefulWidget {
  const ResponsiveFrame({super.key, required this.child});
  final Widget child;

  @override
  State<ResponsiveFrame> createState() => _ResponsiveFrameState();
}

class _ResponsiveFrameState extends State<ResponsiveFrame> {
  bool? _large;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Fold/unfold changes the window size at runtime, so decide per build.
    final large = mq.size.shortestSide >= 600;
    if (large != _large) {
      _large = large;
      SystemChrome.setPreferredOrientations(large
          ? DeviceOrientation.values
          : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
    if (mq.size.width <= kMaxContentWidth) return widget.child;
    // Override size so every MediaQuery-based breakpoint sees the capped width.
    return Center(
      child: SizedBox(
        width: kMaxContentWidth,
        child: MediaQuery(
          data: mq.copyWith(size: Size(kMaxContentWidth, mq.size.height)),
          child: widget.child,
        ),
      ),
    );
  }
}
