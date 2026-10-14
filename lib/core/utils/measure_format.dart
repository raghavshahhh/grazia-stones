/// Length formatting for the AR ruler. Pure functions so every unit is unit-tested.
const kMeasureUnits = ['mm', 'cm', 'm', 'in', 'ft'];

const _inchesPerMeter = 39.37007874;

String formatMeasureLength(double meters, String unit) {
  switch (unit) {
    case 'mm':
      return '${(meters * 1000).round()} mm';
    case 'cm':
      return '${(meters * 100).toStringAsFixed(1)} cm';
    case 'in':
      return '${(meters * _inchesPerMeter).toStringAsFixed(1)}"';
    case 'ft':
      final totalIn = (meters * _inchesPerMeter * 10).round() / 10; // one decimal of an inch
      final feet = (totalIn / 12).floor();
      final inches = totalIn - feet * 12;
      return '$feet\' ${inches.toStringAsFixed(1)}"';
    case 'm':
    default:
      return '${meters.toStringAsFixed(2)} m';
  }
}
