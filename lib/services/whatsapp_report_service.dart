import 'dart:io';

import 'package:share_plus/share_plus.dart';

class WhatsAppReportService {
  const WhatsAppReportService._();

  static Future<void> shareSurvey({
    required String surveyId,
    required Map<String, Object?> survey,
    required List<Map<String, Object?>> media,
  }) async {
    final report = _buildReport(
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

      if (await file.exists() && await file.length() > 0) {
        files.add(
          XFile(
            localPath,
            name: _safeFileName(localPath),
          ),
        );
      }
    }

    final params = ShareParams(
      text: report,
      subject: 'Laporan Hydro Surveyor $surveyId',
      title: 'Laporan Hydro Surveyor $surveyId',
      files: files.isEmpty ? null : files,
    );

    await SharePlus.instance.share(params);
  }

  static String _buildReport({
    required String surveyId,
    required Map<String, Object?> survey,
  }) {
    String value(String key) {
      final raw = survey[key];
      if (raw == null || raw.toString().trim().isEmpty) {
        return '-';
      }
      return raw.toString();
    }

    String number(String key, [int decimals = 2]) {
      final raw = survey[key];

      if (raw == null) {
        return '-';
      }

      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString());

      if (parsed == null || !parsed.isFinite) {
        return '-';
      }

      return parsed.toStringAsFixed(decimals);
    }

    return '''HYDRO SURVEYOR — LAPORAN SURVEI

ID Survei       : $surveyId
Mode            : ${value('survey_mode')}
Waktu survei    : ${value('waktu_survey')}
UPT             : ${value('nama_upt')}
Seksi           : ${value('bidang_seksi')}
Sungai/air terjun: ${value('nama_sungai')}
Penanggung jawab: ${value('nama_penanggung_jawab')}
NIP             : ${value('nip_penanggung_jawab')}

LOKASI
Latitude        : ${number('latitude', 6)}
Longitude       : ${number('longitude', 6)}
Elevasi GPS     : ${number('altitude_gps', 1)} m

PENGUKURAN LAPANGAN
Lebar sungai    : ${number('river_width_m', 3)} m
Kedalaman       : ${number('depth_estimate_m', 3)} m
Kecepatan permukaan: ${number('surface_velocity_mps', 3)} m/s
Kecepatan rata-rata: ${number('mean_velocity_mps', 3)} m/s
Luas penampang  : ${number('cross_section_area_sqm', 3)} m²
Gross head      : ${number('gross_head_m', 2)} m

HASIL PERHITUNGAN
Debit           : ${number('discharge_cms', 3)} m³/s
Net head        : ${number('net_head_m', 2)} m
Daya            : ${number('power_output_kw', 2)} kW
Turbin          : ${value('recommended_turbine')}

HASIL TERKOREKSI
Debit terkoreksi: ${number('corrected_discharge_cms', 3)} m³/s
Head terkoreksi : ${number('corrected_head_m', 2)} m
Daya terkoreksi : ${number('corrected_power_kw', 2)} kW
Profil koreksi  : ${value('correction_profile')}
Faktor velocity : ${number('surface_velocity_factor', 2)}
Faktor head loss: ${number('head_loss_factor', 2)}
Efisiensi turbin: ${number('turbine_efficiency', 2)}

AI LOKAL
Status          : ${value('ai_status')}
Model           : ${value('ai_model_version')}
Quality score   : ${number('ai_quality_score', 2)}
Confidence      : ${value('confidence_level')}
Evidence AI     : ${value('ai_evidence_count')} file
Metode estimasi : ${value('estimation_method')}
Catatan AI      : ${value('ai_notes')}

DOKUMENTASI
Status          : ${value('documentation_status')}

Sinkronisasi    : ${value('sync_status')}

Catatan: laporan dikirim manual oleh petugas melalui menu berbagi Android. Pilih WhatsApp dan kontak pusat tujuan.''';
  }

  static String _safeFileName(String value) {
    final normalized = value.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');

    if (slash >= 0 && slash < normalized.length - 1) {
      return normalized.substring(slash + 1);
    }

    return normalized;
  }
}
