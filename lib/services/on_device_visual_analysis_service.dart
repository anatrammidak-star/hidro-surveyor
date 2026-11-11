import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/visual_analysis_result.dart';

abstract interface class OnDeviceVisualAnalysisService {
  Future<VisualAnalysisResult> analyzePhoto({
    required String filePath,
    required String mediaType,
    double? referenceLengthM,
    String? referenceDescription,
  });
}

class MlKitVisualAnalysisService
    implements OnDeviceVisualAnalysisService {
  MlKitVisualAnalysisService();

  ObjectDetector? _objectDetector;
  ImageLabeler? _imageLabeler;

  Future<void> _initialize() async {
    if (_objectDetector != null && _imageLabeler != null) {
      return;
    }

    final objectOptions = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );

    _objectDetector = ObjectDetector(
      options: objectOptions,
    );

    final labelOptions = ImageLabelerOptions(
      confidenceThreshold: 0.45,
    );

    _imageLabeler = ImageLabeler(
      options: labelOptions,
    );
  }

  @override
  Future<VisualAnalysisResult> analyzePhoto({
    required String filePath,
    required String mediaType,
    double? referenceLengthM,
    String? referenceDescription,
  }) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return VisualAnalysisResult(
        status: VisualAnalysisStatus.insufficientEvidence,
        engineId: 'mlkit-on-device-v1',
        processedAt: DateTime.now(),
        sourcePath: filePath,
        message: 'File foto tidak ditemukan.',
        estimates: const [],
      );
    }

    final fileSize = await file.length();

    if (fileSize <= 0) {
      return VisualAnalysisResult(
        status: VisualAnalysisStatus.insufficientEvidence,
        engineId: 'mlkit-on-device-v1',
        processedAt: DateTime.now(),
        sourcePath: filePath,
        message: 'File foto kosong atau tidak dapat dibaca.',
        estimates: const [],
      );
    }

    try {
      await _initialize();

      final inputImage = InputImage.fromFilePath(filePath);

      final objects = await _objectDetector!.processImage(inputImage);
      final labels = await _imageLabeler!.processImage(inputImage);

      final personConfidences = <double>[];
      final objectDescriptions = <String>[];

      for (final object in objects) {
        for (final label in object.labels) {
          final text = label.text.trim();
          final confidence = label.confidence;

          if (text.isEmpty) {
            continue;
          }

          objectDescriptions.add(
            '$text ${(confidence * 100).toStringAsFixed(0)}%',
          );

          if (text.toLowerCase() == 'person') {
            personConfidences.add(confidence);
          }
        }
      }

      final imageLabels = <String>[];

      for (final label in labels) {
        final text = label.label.trim();

        if (text.isEmpty) {
          continue;
        }

        imageLabels.add(
          '$text ${(label.confidence * 100).toStringAsFixed(0)}%',
        );
      }

      final personDetected = personConfidences.isNotEmpty;
      final personConfidence = personConfidences.isEmpty
          ? 0.0
          : personConfidences.reduce(
              (a, b) => a > b ? a : b,
            );

      const waterKeywords = <String>[
        'water',
        'river',
        'waterfall',
        'stream',
        'lake',
        'rapids',
        'nature',
        'landscape',
      ];

      double waterScore = 0.0;

      for (final label in labels) {
        final normalized = label.label.toLowerCase();

        for (final keyword in waterKeywords) {
          if (normalized.contains(keyword)) {
            if (label.confidence > waterScore) {
              waterScore = label.confidence;
            }
          }
        }
      }

      final referenceValid = referenceLengthM != null &&
          referenceLengthM.isFinite &&
          referenceLengthM > 0;

      double evidenceScore = 0.0;

      if (personDetected) {
        evidenceScore += 0.40 * personConfidence;
      }

      if (waterScore > 0) {
        evidenceScore += 0.40 * waterScore;
      }

      if (objects.isNotEmpty) {
        evidenceScore += 0.10;
      }

      if (referenceValid) {
        evidenceScore += 0.10;
      }

      evidenceScore = evidenceScore.clamp(0.0, 1.0);

      final notes = <String>[
        'AI lokal: ML Kit on-device.',
        'Foto diproses di perangkat dan tidak dikirim ke server oleh modul ini.',
        'Objek terdeteksi: ${objects.length}.',
        if (personDetected)
          'Manusia terdeteksi sebagai kandidat referensi skala dengan confidence '
              '${(personConfidence * 100).toStringAsFixed(1)}%.',
        if (!personDetected)
          'Tidak ditemukan manusia sebagai referensi skala.',
        if (waterScore > 0)
          'Label lingkungan air terdeteksi dengan score maksimum '
              '${(waterScore * 100).toStringAsFixed(1)}%.',
        if (waterScore == 0)
          'Tidak ada label air yang cukup kuat pada model umum.',
        if (referenceValid)
          'Referensi fisik tersedia: ${referenceLengthM!.toStringAsFixed(2)} m.',
        if (!referenceValid)
          'Belum ada referensi fisik untuk mengubah ukuran piksel menjadi meter.',
        if (objectDescriptions.isNotEmpty)
          'Objek: ${objectDescriptions.take(8).join(', ')}.',
        if (imageLabels.isNotEmpty)
          'Label: ${imageLabels.take(10).join(', ')}.',
        'Evidence score: ${(evidenceScore * 100).toStringAsFixed(0)}/100.',
        'Model ini belum menghasilkan estimasi numerik debit, head, atau daya.',
      ];

      return VisualAnalysisResult(
        status: VisualAnalysisStatus.completed,
        engineId: 'mlkit-on-device-v1',
        processedAt: DateTime.now(),
        sourcePath: filePath,
        referenceObject: referenceDescription,
        message: notes.join(' '),
        estimates: const [],
      );
    } catch (e) {
      return VisualAnalysisResult(
        status: VisualAnalysisStatus.failed,
        engineId: 'mlkit-on-device-v1',
        processedAt: DateTime.now(),
        sourcePath: filePath,
        message: 'Analisis AI lokal gagal: $e',
        estimates: const [],
      );
    }
  }

  Future<void> close() async {
    await _objectDetector?.close();
    await _imageLabeler?.close();
    _objectDetector = null;
    _imageLabeler = null;
  }
}
