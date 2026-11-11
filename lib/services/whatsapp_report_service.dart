
import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Layanan untuk menyusun dan membagikan laporan survei melalui
/// menu berbagi Android. Petugas tetap memilih WhatsApp dan penerima.
class WhatsAppReportService {
  WhatsAppReportService._();

  /// Membuat laporan teks dan membagikannya bersama media yang tersedia.
  ///
  /// Semua parameter pengukuran boleh null jika belum diisi.
  /// File media yang tidak ditemukan akan dilewati.
  static Future<ShareResult> shareSurveyReport({
    required String surveyId,
    required String surveyMode,
    required String namaUpt,
    required String bidangSeksi,
    required String namaSungai,
    required String namaPetugas,
    required String nipPetugas,
    required DateTime waktuSurvey,
    required double? latitude,
    required double? longitude,
    required double? altitudeGps,
    required double? lebarSungaiM,
    required double? kedalamanM,
    required double? kecepatanPermukaanMps,
    required double? kecepatanRataRataMps,
    required double? luasPenampangM2,
    required double? debitM3s,
    required double? tinggiJatuhKotorM,
    required double? tinggiJatuhBersihM,
    required double? dayaKw,
    required String? rekomendasiTurbin,
    required String statusAnalisisFoto,
    required String catatanAnalisis,
    required List<String> mediaPaths,
  }) async {
    final report = _buildReport(
      surveyId: surveyId,
      surveyMode: surveyMode,
      namaUpt: namaUpt,
      bidangSeksi: bidangSeksi,
      namaSungai: namaSungai,
      namaPetugas: namaPetugas,
      nipPetugas: nipPetugas,
      waktuSurvey: waktuSurvey,
      latitude: latitude,
      longitude: longitude,
      altitudeGps: altitudeGps,
      lebarSungaiM: lebarSungaiM,
      kedalamanM: kedalamanM,
      kecepatanPermukaanMps: kecepatanPermukaanMps,
      kecepatanRataRataMps: kecepatanRataRataMps,
      luasPenampangM2: luasPenampangM2,
      debitM3s: debitM3s,
      tinggiJatuhKotorM: tinggiJatuhKotorM,
      tinggiJatuhBersihM: tinggiJatuhBersihM,
      dayaKw: dayaKw,
      rekomendasiTurbin: rekomendasiTurbin,
      statusAnalisisFoto: statusAnalisisFoto,
      catatanAnalisis: catatanAnalisis,
    );

    final files = <XFile>[];

    for (final filePath in mediaPaths) {
      if (filePath.trim().isEmpty) continue;

      final file = File(filePath);
      if (await file.exists()) {
        files.add(XFile(file.path));
      }
    }

    if (files.isEmpty) {
      return Share.share(
        report,
        subject: 'Laporan Survei Hydro Surveyor - $surveyId',
      );
    }

    return Share.shareXFiles(
      files,
      subject: 'Laporan Survei Hydro Surveyor - $surveyId',
      text: report,
    );
  }

  static String _buildReport({
    required String surveyId,
    required String surveyMode,
    required String namaUpt,
    required String bidangSeksi,
    required String namaSungai,
    required String namaPetugas,
    required String nipPetugas,
    required DateTime waktuSurvey,
    required double? latitude,
    required double? longitude,
    required double? altitudeGps,
    required double? lebarSungaiM,
    required double? kedalamanM,
    required double? kecepatanPermukaanMps,
    required double? kecepatanRataRataMps,
    required double? luasPenampangM2,
    required double? debitM3s,
    required double? tinggiJatuhKotorM,
    required double? tinggiJatuhBersihM,
    required double? dayaKw,
    required String? rekomendasiTurbin,
    required String statusAnalisisFoto,
    required String catatanAnalisis,
  }) {
    String number(double? value, {int decimals = 3}) {
      if (value == null || !value.isFinite) {
        return 'Belum tersedia';
      }
      return value.toStringAsFixed(decimals);
    }

    String text(String value) {
      return value.trim().isEmpty ? '-' : value.trim();
    }

    final date =
        '${waktuSurvey.day.toString().padLeft(2, '0')}-'
        '${waktuSurvey.month.toString().padLeft(2, '0')}-'
        '${waktuSurvey.year} '
        '${waktuSurvey.hour.toString().padLeft(2, '0')}:'
        '${waktuSurvey.minute.toString().padLeft(2, '0')}';

    final modeLabel = surveyMode == 'HYDRO_POWER'
        ? 'Potensi mikro/minihidro'
        : 'Pengukuran debit';

    final coordinate = latitude != null && longitude != null
        ? '${latitude.toStringAsFixed(6)}, '
            '${longitude.toStringAsFixed(6)}'
        : 'GPS belum tersedia';

    return '''
LAPORAN SURVEI HYDRO SURVEYOR
================================

IDENTITAS SURVEI
ID Survei       : $surveyId
Jenis Survei    : $modeLabel
Waktu           : $date
UPT             : ${text(namaUpt)}
Bidang/Seksi    : ${text(bidangSeksi)}
Nama Sungai     : ${text(namaSungai)}
Petugas         : ${text(namaPetugas)}
NIP             : ${text(nipPetugas)}

LOKASI
Koordinat       : $coordinate
Elevasi GPS     : ${number(altitudeGps)} m

HASIL PENGUKURAN
Lebar sungai    : ${number(lebarSungaiM)} m
Kedalaman       : ${number(kedalamanM)} m
Kecepatan permukaan : ${number(kecepatanPermukaanMps)} m/s
Kecepatan rata-rata : ${number(kecepatanRataRataMps)} m/s
Luas penampang  : ${number(luasPenampangM2)} m2
Debit           : ${number(debitM3s)} m3/s
Tinggi jatuh kotor : ${number(tinggiJatuhKotorM)} m
Tinggi jatuh bersih : ${number(tinggiJatuhBersihM)} m
Estimasi daya   : ${number(dayaKw)} kW
Rekomendasi turbin : ${text(rekomendasiTurbin ?? '')}

ANALISIS FOTO/VIDEO
Status analisis : ${text(statusAnalisisFoto)}
Catatan         : ${text(catatanAnalisis)}

Catatan:
Hasil merupakan data survei awal. Estimasi visual dan perhitungan
perlu divalidasi dengan pengukuran lapangan sebelum digunakan
sebagai dasar keputusan teknis.

Dikirim melalui aplikasi Hydro Surveyor.
''';
  }
}
