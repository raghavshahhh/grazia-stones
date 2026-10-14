import 'dart:math' as math;

/// Result of reading the phone's gravity vector as a spirit level.
class LevelReading {
  /// True when the phone lies flat (screen up/down): the level shows a 2-axis bubble.
  final bool flat;

  /// Tilt in degrees. Flat: angle away from horizontal. Upright: rotation of the phone's edge vs true level.
  final double degrees;

  /// Bubble offset, -1..1 on each axis (flat mode only); moves toward the high side like a real bubble.
  final double bubbleX;
  final double bubbleY;

  const LevelReading({required this.flat, required this.degrees, required this.bubbleX, required this.bubbleY});

  bool get isLevel => degrees.abs() < 0.6;
}

/// [x], [y], [z] are accelerometer values in m/s² (Android convention: z ≈ +9.8 when lying flat, face up).
LevelReading readLevel(double x, double y, double z) {
  final g = math.sqrt(x * x + y * y + z * z);
  if (g < 1e-3) return const LevelReading(flat: true, degrees: 0, bubbleX: 0, bubbleY: 0);
  const rad2deg = 180 / math.pi;

  if (z.abs() >= 0.8 * g) {
    final tilt = math.atan2(math.sqrt(x * x + y * y), z.abs()) * rad2deg;
    return LevelReading(
      flat: true,
      degrees: tilt,
      bubbleX: (x / g * 4).clamp(-1.0, 1.0),
      bubbleY: (-y / g * 4).clamp(-1.0, 1.0),
    );
  }

  // Upright (against a wall / on its edge): rotation in the screen plane relative to true vertical or horizontal.
  double roll = x.abs() <= y.abs() ? math.atan2(x, y) * rad2deg : math.atan2(-y, x) * rad2deg;
  if (roll > 90) roll -= 180;
  if (roll < -90) roll += 180;
  return LevelReading(flat: false, degrees: roll, bubbleX: 0, bubbleY: 0);
}
