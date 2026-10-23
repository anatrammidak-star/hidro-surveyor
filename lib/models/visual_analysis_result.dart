/// Typed contract between the future on-device vision engine and SiCA's survey form.
/// Null means the engine could not produce a defensible estimate; never substitute zero.
enum VisualAnalysisStatus { notAnalyzed, needsReference, completed, insufficientEvidence, failed }

enum MeasurementSource { aiEstimate, manual, corrected }

class MeasurementEstimate {
  const MeasurementEstimate({
    required this.key,
    required this.unit,
    required this.source,
    this.value,
    this.minimum,
    this.maximum,
    this.confidence,
    this.note,
  });

  final String key;
  final String unit;
  final MeasurementSource source;
  final double? value;
  final double? minimum;
  final double? maximum;
  /// Optional 0..1 score from a real model/algorithm, not a subjective UI score.
  final double? confidence;
  final String? note;

  bool get hasValidValue => value != null && value!.isFinite && value! > 0;

  Map<String, Object?> toMap() => {
        'key': key,
        'unit': unit,
        'source': source.name,
        'value': value,
        'minimum': minimum,
        'maximum': maximum,
        'confidence': confidence,
        'note': note,
      };

  factory MeasurementEstimate.fromMap(Map<String, Object?> map) =>
      MeasurementEstimate(
        key: map['key'] as String,
        unit: map['unit'] as String,
        source: MeasurementSource.values.firstWhere(
          (e) => e.name == map['source'],
          orElse: () => MeasurementSource.aiEstimate,
        ),
        value: (map['value'] as num?)?.toDouble(),
        minimum: (map['minimum'] as num?)?.toDouble(),
        maximum: (map['maximum'] as num?)?.toDouble(),
        confidence: (map['confidence'] as num?)?.toDouble(),
        note: map['note'] as String?,
      );
}

class VisualAnalysisResult {
  const VisualAnalysisResult({
    required this.status,
    required this.engineId,
    required this.processedAt,
    required this.estimates,
    this.sourcePath,
    this.message,
    this.referenceObject,
  });

  final VisualAnalysisStatus status;
  final String engineId;
  final DateTime processedAt;
  final String? sourcePath;
  final String? message;
  final String? referenceObject;
  final List<MeasurementEstimate> estimates;

  MeasurementEstimate? estimate(String key) {
    for (final item in estimates) {
      if (item.key == key) return item;
    }
    return null;
  }

  Map<String, Object?> toMap() => {
        'status': status.name,
        'engine_id': engineId,
        'processed_at': processedAt.toIso8601String(),
        'source_path': sourcePath,
        'message': message,
        'reference_object': referenceObject,
        'estimates': estimates.map((e) => e.toMap()).toList(),
      };
}
