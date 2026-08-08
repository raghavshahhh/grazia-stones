import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AR View Screen - Redirects to Live AI
/// Native AR (ARCore/ARKit) is replaced by Live AI camera detection
class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect to Live AI screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/live-ai');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC9A96E),
        ),
      ),
    );
  }
}
