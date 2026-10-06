import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/local_database.dart';

class SurveyResultScreen extends StatefulWidget {
  final int surveyId;

  const SurveyResultScreen({
    super.key,
    required this.surveyId,
  });

  @override
  State<SurveyResultScreen> createState() =>
      _SurveyResultScreenState();
}

class _SurveyResultScreenState
    extends State<SurveyResultScreen> {
  final _db = LocalDatabase.instance;

  Map<String, Object?>? _survey;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSurvey();
  }

  Future<void> _loadSurvey() async {
    try {
      final result =
          await _db.getSurvey(widget.surveyId);

      if (!mounted) return;

      setState(() {
        _survey = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _text(String key) {
    final value = _survey?[key];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  double? _number(String key) {
    final value = _survey?[key];

    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String _numberText(
    String key, {
    int decimals = 2,
    String suffix = '',
  }) {
    final value = _number(key);

    if (value == null) {
      return '-';
    }

    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');
    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'SYNCED':
        return 'TERSINKRON';
      case 'SYNCING':
        return 'MENYINKRONKAN';
      case 'FAILED':
        return 'GAGAL SINKRON';
      case 'PENDING':
        return 'MENUNGGU SINKRONISASI';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SYNCED':
        return Colors.green;
      case 'SYNCING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _aiStatusLabel(String status) {
    switch (status) {
      case 'ANALYZED':
        return 'DIANALISIS';
      case 'PROCESSING':
        return 'MEMPROSES';
      case 'FAILED':
        return 'GAGAL';
      case 'NOT_ANALYZED':
        return 'BELUM DIANALISIS';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Survei'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Gagal membaca hasil survei:\n\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_survey == null) {
      return const Center(
        child: Text(
          'Data survei tidak ditemukan.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSurvey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 12),

          _buildLocationCard(),
          const SizedBox(height: 12),

          _buildAiResultCard(),
          const SizedBox(height: 12),

          _buildCorrectedResultCard(),
          const SizedBox(height: 12),

          _buildFieldInputCard(),
          const SizedBox(height: 12),

          _buildDocumentationCard(),
          const SizedBox(height: 12),

          _buildMetadataCard(),
          const SizedBox(height: 12),

          _buildSyncCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final mode = _text('survey_mode');

    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water,
                  color: Colors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _text('nama_sungai'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(
              'UPT / Balai',
              _text('nama_upt'),
            ),
            _infoRow(
              'Seksi',
              _text('bidang_seksi'),
            ),
            _infoRow(
              'Mode',
              mode == 'HYDRO_POWER'
                  ? 'Mikrohidro'
                  : 'Debit Air',
            ),
            _infoRow(
              'Waktu survei',
              _formatDate(
                _text('waktu_survey'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${_text('local_id')}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return _sectionCard(
      title: 'Lokasi Survei',
      icon: Icons.location_on,
      children: [
        _infoRow(
          'Latitude',
          _numberText(
            'latitude',
            decimals: 6,
          ),
        ),
        _infoRow(
          'Longitude',
          _numberText(
            'longitude',
            decimals: 6,
          ),
        ),
        _infoRow(
          'Elevasi GPS',
          _numberText(
            'altitude_gps',
            decimals: 1,
            suffix: ' m',
          ),
        ),
      ],
    );
  }

  Widget _buildAiResultCard() {
    final aiStatus =
        _text('ai_status');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estimasi AI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(
                  _aiStatusLabel(aiStatus),
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _resultRangeRow(
              'Debit',
              'visual_discharge_min_cms',
              'visual_discharge_cms',
              'visual_discharge_max_cms',
              'm³/s',
            ),

            _resultRangeRow(
              'Head',
              'visual_head_min_m',
              'visual_head_m',
              'visual_head_max_m',
              'm',
            ),

            _resultRangeRow(
              'Daya',
              'visual_power_min_kw',
              'visual_power_kw',
              'visual_power_max_kw',
              'kW',
            ),

            const Divider(height: 24),

            _infoRow(
              'Model',
              _text('ai_model_version'),
            ),
            _infoRow(
              'Confidence',
              _text('confidence_level'),
            ),
            _infoRow(
              'Quality score',
              _numberText(
                'ai_quality_score',
                decimals: 2,
              ),
            ),
            _infoRow(
              'Evidence',
              '${_text('ai_evidence_count')} file',
            ),
            _infoRow(
              'Metode',
              _text('estimation_method'),
            ),

            if (_text('ai_notes') != '-') ...[
              const SizedBox(height: 8),
              Text(
                'Catatan AI',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text('ai_notes'),
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ],

            if (aiStatus == 'NOT_ANALYZED')
              _notice(
                icon: Icons.info_outline,
                text:
                    'Prediction engine AI belum terhubung. '
                    'Tidak ada angka AI yang dibuat secara '
                    'heuristik.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectedResultCard() {
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Colors.teal,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hasil Terkoreksi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _resultValueRow(
              'Debit',
              _numberText(
                'corrected_discharge_cms',
                decimals: 3,
                suffix: ' m³/s',
              ),
            ),

            _resultValueRow(
              'Net head',
              _numberText(
                'corrected_head_m',
                decimals: 2,
                suffix: ' m',
              ),
            ),

            _resultValueRow(
              'Daya',
              _numberText(
                'corrected_power_kw',
                decimals: 2,
                suffix: ' kW',
              ),
            ),

            _resultValueRow(
              'Turbin',
              _text('recommended_turbine'),
            ),

            const Divider(height: 24),

            _infoRow(
              'Precision',
              _text('precision_level'),
            ),
            _infoRow(
              'Metode',
              _text('estimation_method'),
            ),
            _infoRow(
              'Profil koreksi',
              _text('correction_profile'),
            ),

            const SizedBox(height: 8),

            const Text(
              'Hasil ini merupakan perhitungan '
              'physics-based field correction, '
              'bukan hasil AI.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldInputCard() {
    return _sectionCard(
      title: 'Data Lapangan',
      icon: Icons.straighten,
      children: [
        _infoRow(
          'Lebar sungai',
          _numberText(
            'river_width_m',
            decimals: 2,
            suffix: ' m',
          ),
        ),
        _infoRow(
          'Kedalaman',
          _numberText(
            'depth_estimate_m',
            decimals: 2,
            suffix: ' m',
          ),
        ),
        _infoRow(
          'Kecepatan permukaan',
          _numberText(
            'surface_velocity_mps',
            decimals: 2,
            suffix: ' m/s',
          ),
        ),
        _infoRow(
          'Gross head',
          _numberText(
            'gross_head_m',
            decimals: 2,
            suffix: ' m',
          ),
        ),
        _infoRow(
          'Mean velocity',
          _numberText(
            'mean_velocity_mps',
            decimals: 2,
            suffix: ' m/s',
          ),
        ),
        _infoRow(
          'Luas penampang',
          _numberText(
            'cross_section_area_sqm',
            decimals: 2,
            suffix: ' m²',
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentationCard() {
    return _sectionCard(
      title: 'Dokumentasi',
      icon: Icons.photo_library,
      children: [
        _infoRow(
          'Status',
          _text('documentation_status'),
        ),
        _infoRow(
          'Jumlah evidence',
          '${_text('ai_evidence_count')} file',
        ),
        const SizedBox(height: 8),
        const Text(
          'Foto/video tersimpan secara lokal '
          'dan akan menjadi bagian dari proses '
          'sinkronisasi.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard() {
    return _sectionCard(
      title: 'Informasi Survei',
      icon: Icons.assignment,
      children: [
        _infoRow(
          'Penanggung jawab',
          _text('nama_penanggung_jawab'),
        ),
        _infoRow(
          'NIP',
          _text('nip_penanggung_jawab'),
        ),
        _infoRow(
          'Referensi digunakan',
          _text('reference_used'),
        ),
        _infoRow(
          'Faktor velocity',
          _numberText(
            'surface_velocity_factor',
            decimals: 2,
          ),
        ),
        _infoRow(
          'Faktor head loss',
          _numberText(
            'head_loss_factor',
            decimals: 2,
          ),
        ),
        _infoRow(
          'Efisiensi turbin',
          _numberText(
            'turbine_efficiency',
            decimals: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCard() {
    final status =
        _text('sync_status');

    final color =
        _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              status == 'SYNCED'
                  ? Icons.cloud_done
                  : Icons.cloud_upload,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sinkronisasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusLabel(status),
                  ),
                  if (_text('last_sync_error') != '-')
                    Text(
                      _text('last_sync_error'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultValueRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRangeRow(
    String label,
    String minKey,
    String bestKey,
    String maxKey,
    String unit,
  ) {
    final min = _number(minKey);
    final best = _number(bestKey);
    final max = _number(maxKey);

    if (min == null &&
        best == null &&
        max == null) {
      return _resultValueRow(
        label,
        'Belum tersedia',
      );
    }

    final parts = <String>[];

    if (min != null) {
      parts.add(
        min.toStringAsFixed(2),
      );
    }

    if (best != null) {
      parts.add(
        best.toStringAsFixed(2),
      );
    }

    if (max != null) {
      parts.add(
        max.toStringAsFixed(2),
      );
    }

    return _resultValueRow(
      label,
      '${parts.join(' – ')} $unit',
    );
  }

  Widget _statusChip(
    String label,
    Color color,
  ) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      side: BorderSide(
        color: color.withOpacity(0.35),
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
