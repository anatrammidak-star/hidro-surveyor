import 'dart:io';

import 'package:share_plus/share_plus.dart';

class WhatsAppReportService {
  WhatsAppReportService._();

  static Future<ShareResult> shareSurvey({
    required String surveyId,
    required Map<String, Object?> survey,
    required List<Map<String, Object?>> media,
  }) async {
    final text = _buildReport(
      surveyId: surveyId,
      survey: survey,
    );

    final files = <XFile>[];

    for (final item in media) {
      final localPath = '${item['local_path'] ?? ''}'.trim();

      if (localPath.isEmpty) {
        continue;
      }

      final file = File(localPath);

      if (await file.exists()) {
        files.add(XFile(file.path));
      }
    }

    if (files.isEmpty) {
      return Share.share(
        text,
        subject: 'Hydro Surveyor - $surveyId',
      );
    }

    return Share.shareXFiles(
      files,
      subject: 'Hydro Surveyor - $surveyId',
      text: text,
    );
  }

  static String _value(
    Map<String, Object?> survey,
    String key, {
    int decimals = 3,
    String suffix = '',
  }) {
    final value = survey[key];

    if (value == null) {
      return '-';
    }

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (number == null || !number.isFinite) {
      return '-';
    }

    return '${number.toStringAsFixed(decimals)}$suffix';
  }

  static String _text(
    Map<String, Object?> survey,
    String key,
  ) {
    final value = survey[key];

    if (value == null) {
      return '-';
    }

    final result = value.toString().trim();

    return result.isEmpty ? '-' : result;
  }

  static String _date(
    Map<String, Object?> survey,
    String key,
  ) {
    final value = survey[key];

    if (value == null) {
      return '-';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  static String _buildReport({
    required String surveyId,
    required Map<String, Object?> survey,
  }) {
    final mode =
        _text(survey, 'survey_mode') == 'HYDRO_POWER'
            ? 'Potensi Mikro/Minihidro'
            : 'Pengukuran Debit';

    return '''
LAPORAN SURVEI HYDRO SURVEYOR
================================

IDENTITAS SURVEI
ID Survei              : $surveyId
ID Lokal                : ${_text(survey, 'local_id')}
Jenis Survei            : $mode
Waktu Survei            : ${_date(survey, 'waktu_survey')}

UPT / Balai             : ${_text(survey, 'nama_upt')}
Bidang / Seksi          : ${_text(survey, 'bidang_seksi')}
Nama Sungai / Air Terjun: ${_text(survey, 'nama_sungai')}

PETUGAS
Nama                    : ${_text(survey, 'nama_penanggung_jawab')}
NIP                     : ${_text(survey, 'nip_penanggung_jawab')}

LOKASI
Latitude                : ${_value(survey, 'latitude', decimals: 6)}
Longitude               : ${_value(survey, 'longitude', decimals: 6)}
Elevasi GPS             : ${_value(survey, 'altitude_gps', decimals: 1, suffix: ' m')}

PENGUKURAN LAPANGAN
Lebar Sungai            : ${_value(survey, 'river_width_m', suffix: ' m')}
Kedalaman               : ${_value(survey, 'depth_estimate_m', suffix: ' m')}
Kecepatan Permukaan     : ${_value(survey, 'surface_velocity_mps', suffix: ' m/s')}
Kecepatan Rata-rata     : ${_value(survey, 'mean_velocity_mps', suffix: ' m/s')}
Luas Penampang          : ${_value(survey, 'cross_section_area_sqm', suffix: ' m²')}

HASIL KOREKSI
Debit                    : ${_value(survey, 'corrected_discharge_cms', suffix: ' m³/s')}
Gross Head               : ${_value(survey, 'gross_head_m', suffix: ' m')}
Net Head                 : ${_value(survey, 'corrected_head_m', suffix: ' m')}
Daya                     : ${_value(survey, 'corrected_power_kw', suffix: ' kW')}
Rekomendasi Turbin       : ${_text(survey, 'recommended_turbine')}

METADATA ANALISIS
Status AI                : ${_text(survey, 'ai_status')}
Model AI                 : ${_text(survey, 'ai_model_version')}
Quality Score             : ${_value(survey, 'ai_quality_score', decimals: 2)}
Jumlah Evidence           : ${_text(survey, 'ai_evidence_count')}
Precision Level           : ${_text(survey, 'precision_level')}
Metode Estimasi           : ${_text(survey, 'estimation_method')}
Confidence                : ${_text(survey, 'confidence_level')}

CATATAN
${_text(survey, 'ai_notes')}

================================
Laporan dibuat oleh Hydro Surveyor.
Hasil estimasi visual/AI merupakan pendukung survei lapangan
dan tetap harus divalidasi sebelum digunakan untuk keputusan teknis.
''';
  }
}
