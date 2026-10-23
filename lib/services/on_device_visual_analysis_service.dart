import 'dart:io';

import '../models/visual_analysis_result.dart';

/// Interface for offline image/video analysis. Implement this with a real
/// LiteRT/TFLite/MediaPipe model in the next phase. This scaffold deliberately
/// returns no fabricated measurements until a model is bundled and validated.
abstract interface class OnDeviceVisualAnalysisService {
  Future<VisualAnalysisResult> analyzePhoto({
    required String filePath,
    required String mediaType,
    double? referenceLengthM,
    String? referenceDescription,
  });
}

/// Safe initial adapter used by SiCA until a real model is supplied.
/// It checks local evidence and returns an explicit status, never numeric guesses.
class UnconfiguredVisualAnalysisService implements OnDeviceVisualAnalysisService {
  const UnconfiguredVisualAnalysisService();

  @override
  Future<VisualAnalysisResult> analyzePhoto({
    required String filePath,
    required String mediaType,
    double? referenceLengthM,
    String? referenceDescription,
  }) async {
    final file = File(filePath);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    final validReference = referenceLengthM != null &&
        referenceLengthM.isFinite &&
        referenceLengthM > 0;

    final status = !exists || size == 0
        ? VisualAnalysisStatus.insufficientEvidence
        : !validReference
            ? VisualAnalysisStatus.needsReference
            : VisualAnalysisStatus.notAnalyzed;

    final message = !exists || size == 0
        ? 'Berkas tidak ditemukan atau kosong.'
        : !validReference
            ? 'Berkas tersedia. Masukkan panjang objek referensi yang diketahui untuk analisis dimensi.'
            : 'Bukti dan referensi tersedia, tetapi model AI lokal belum dipasang. Tidak ada estimasi angka yang dibuat.';

    return VisualAnalysisResult(
      status: status,
      engineId: 'unconfigured-no-model',
      processedAt: DateTime.now(),
      sourcePath: filePath,
      referenceObject: referenceDescription,
      message: message,
      estimates: const [],
    );
  }
}
