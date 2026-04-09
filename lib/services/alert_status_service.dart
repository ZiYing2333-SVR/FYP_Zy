import 'package:flutter/material.dart';

/// Global service to manage and broadcast alert status across all pages in real-time
class AlertStatusService {
  static final AlertStatusService _instance = AlertStatusService._internal();

  factory AlertStatusService() {
    return _instance;
  }

  AlertStatusService._internal();

  // ValueNotifier to broadcast alert status changes
  final ValueNotifier<bool> _hasCautionAlertNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasHighRiskAlertNotifier = ValueNotifier(false);

  ValueNotifier<bool> get hasCautionAlertNotifier => _hasCautionAlertNotifier;
  ValueNotifier<bool> get hasHighRiskAlertNotifier => _hasHighRiskAlertNotifier;

  bool get hasCautionAlert => _hasCautionAlertNotifier.value;
  bool get hasHighRiskAlert => _hasHighRiskAlertNotifier.value;

  bool get hasAnyAlert =>
      _hasCautionAlertNotifier.value || _hasHighRiskAlertNotifier.value;

  /// Update caution alert status and notify all listeners
  void updateCautionAlertStatus(bool value) {
    if (_hasCautionAlertNotifier.value != value) {
      _hasCautionAlertNotifier.value = value;
      print('[AlertStatusService] Caution alert status changed to: $value');
    }
  }

  /// Update high-risk alert status and notify all listeners
  void updateHighRiskAlertStatus(bool value) {
    if (_hasHighRiskAlertNotifier.value != value) {
      _hasHighRiskAlertNotifier.value = value;
      print('[AlertStatusService] High-risk alert status changed to: $value');
    }
  }

  /// Dismiss all alerts
  void dismissAllAlerts() {
    updateCautionAlertStatus(false);
    updateHighRiskAlertStatus(false);
    print('[AlertStatusService] All alerts dismissed');
  }

  /// Refresh alert status (typically called when data changes)
  void refreshAlertStatus({
    required bool hasCaution,
    required bool hasHighRisk,
  }) {
    updateCautionAlertStatus(hasCaution);
    updateHighRiskAlertStatus(hasHighRisk);
    print(
      '[AlertStatusService] Alert status refreshed - Caution: $hasCaution, HighRisk: $hasHighRisk',
    );
  }
}
