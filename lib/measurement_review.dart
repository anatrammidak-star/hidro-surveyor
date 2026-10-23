import '../models/visual_analysis_result.dart';

/// Keeps model output, field correction, and the final value used in calculations
/// separate. This object is intentionally independent of SQLite schema changes.
class MeasurementReview {
  const MeasurementReview({
    required this.key,
    required this.unit,
    this.aiValue,
    this.manualValue,
    this.correctedValue,
  });

  final String key;
  final String unit;
  final double? aiValue;
  final double? manualValue;
  final double? correctedValue;

  double? get finalValue => correctedValue ?? manualValue ?? aiValue;
  MeasurementSource? get finalSource => correctedValue != null
      ? MeasurementSource.corrected
      : manualValue != null
          ? MeasurementSource.manual
          : aiValue != null
              ? MeasurementSource.aiEstimate
              : null;

  Map<String, Object?> toMap() => {
        'key': key,
        'unit': unit,
        'ai_estimate': aiValue,
        'manual_value': manualValue,
        'corrected_value': correctedValue,
        'final_value': finalValue,
        'final_source': finalSource?.name,
      };

  static MeasurementReview fromAnalysis({
    required String key,
    required String unit,
    required VisualAnalysisResult result,
    double? manualValue,
    double? correctedValue,
  }) {
    final estimate = result.estimate(key);
    return MeasurementReview(
      key: key,
      unit: unit,
      aiValue: estimate?.hasValidValue == true ? estimate!.value : null,
      manualValue: _positiveOrNull(manualValue),
      correctedValue: _positiveOrNull(correctedValue),
    );
  }

  static double? _positiveOrNull(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;
}
