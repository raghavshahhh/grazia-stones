import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';

/// App settings state
class SettingsState {
  final bool notificationsEnabled;
  final bool emailUpdatesEnabled;
  final bool smsUpdatesEnabled;
  final MeasurementUnit measurementUnit;
  final String language;
  final String currency;

  const SettingsState({
    this.notificationsEnabled = true,
    this.emailUpdatesEnabled = false,
    this.smsUpdatesEnabled = true,
    this.measurementUnit = MeasurementUnit.imperial,
    this.language = 'en',
    this.currency = 'INR',
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? emailUpdatesEnabled,
    bool? smsUpdatesEnabled,
    MeasurementUnit? measurementUnit,
    String? language,
    String? currency,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailUpdatesEnabled: emailUpdatesEnabled ?? this.emailUpdatesEnabled,
      smsUpdatesEnabled: smsUpdatesEnabled ?? this.smsUpdatesEnabled,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      language: language ?? this.language,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'emailUpdatesEnabled': emailUpdatesEnabled,
      'smsUpdatesEnabled': smsUpdatesEnabled,
      'measurementUnit': measurementUnit.name,
      'language': language,
      'currency': currency,
    };
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      emailUpdatesEnabled: json['emailUpdatesEnabled'] as bool? ?? false,
      smsUpdatesEnabled: json['smsUpdatesEnabled'] as bool? ?? true,
      measurementUnit: MeasurementUnit.values.firstWhere(
        (e) => e.name == json['measurementUnit'],
        orElse: () => MeasurementUnit.imperial,
      ),
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

enum MeasurementUnit {
  imperial, // feet, inches
  metric,   // meters, centimeters
}

extension MeasurementUnitExtension on MeasurementUnit {
  String get displayName {
    switch (this) {
      case MeasurementUnit.imperial:
        return 'Imperial (ft, in)';
      case MeasurementUnit.metric:
        return 'Metric (m, cm)';
    }
  }

  String get lengthUnit {
    switch (this) {
      case MeasurementUnit.imperial:
        return 'ft';
      case MeasurementUnit.metric:
        return 'm';
    }
  }

  String get smallLengthUnit {
    switch (this) {
      case MeasurementUnit.imperial:
        return 'in';
      case MeasurementUnit.metric:
        return 'cm';
    }
  }

  String get areaUnit {
    switch (this) {
      case MeasurementUnit.imperial:
        return 'sq ft';
      case MeasurementUnit.metric:
        return 'm²';
    }
  }

  // Convert from imperial to this unit
  double convertLength(double feet) {
    switch (this) {
      case MeasurementUnit.imperial:
        return feet;
      case MeasurementUnit.metric:
        return feet * 0.3048; // feet to meters
    }
  }

  // Convert from imperial to this unit
  double convertArea(double sqft) {
    switch (this) {
      case MeasurementUnit.imperial:
        return sqft;
      case MeasurementUnit.metric:
        return sqft * 0.092903; // sqft to m²
    }
  }

  // Format length with unit
  String formatLength(double value, {int decimals = 2}) {
    return '${value.toStringAsFixed(decimals)} $lengthUnit';
  }

  // Format area with unit
  String formatArea(double value, {int decimals = 2}) {
    return '${value.toStringAsFixed(decimals)} $areaUnit';
  }
}

/// Settings notifier with persistent storage
class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage = StorageService.instance;
  static const _settingsKey = 'app_settings';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = _storage.getData(_settingsKey);
      if (data != null && data is Map<String, dynamic>) {
        state = SettingsState.fromJson(data);
        debugPrint('✅ Settings loaded: ${state.measurementUnit.displayName}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _storage.saveData(_settingsKey, state.toJson());
      debugPrint('✅ Settings saved');
    } catch (e) {
      debugPrint('❌ Failed to save settings: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setEmailUpdatesEnabled(bool enabled) async {
    state = state.copyWith(emailUpdatesEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setSmsUpdatesEnabled(bool enabled) async {
    state = state.copyWith(smsUpdatesEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setMeasurementUnit(MeasurementUnit unit) async {
    state = state.copyWith(measurementUnit: unit);
    await _saveSettings();
    debugPrint('✅ Measurement unit changed to: ${unit.displayName}');
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await _saveSettings();
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = const SettingsState();
    await _saveSettings();
    debugPrint('✅ Settings reset to defaults');
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// Convenience provider for measurement unit
final measurementUnitProvider = Provider<MeasurementUnit>((ref) {
  return ref.watch(settingsProvider).measurementUnit;
});
