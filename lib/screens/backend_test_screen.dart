import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/ai_api_service.dart';

class BackendTestScreen extends StatefulWidget {
  const BackendTestScreen({super.key});

  @override
  State<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  final AiApiService _api = AiApiService();
  bool _busy = false;
  String _status = 'Belum diuji';
  String _output = 'Tekan salah satu tombol untuk menguji Cloud Run.\n\n'
      'Pengujian ini hanya memakai payload dummy tanpa identitas atau koordinat survei nyata.';
  bool? _ok;

  Future<void> _run({required bool testAnalysis}) async {
    setState(() {
      _busy = true;
      _status = 'Menghubungi backend…';
      _ok = null;
      _output = '';
    });
    try {
      final result = testAnalysis
          ? await _api.analyze({
              'contract_version': '1.0',
              'survey': {
                'local_id': 'SICA-APP-CONNECTION-TEST',
                'survey_mode': 'DISCHARGE_ONLY',
                'gps': {
                  'latitude': null,
                  'longitude': null,
                  'altitude_m': null,
                },
                'field_input': {
                  'river_width_m': null,
                  'depth_estimate_m': null,
                  'surface_velocity_mps': null,
                  'gross_head_m': null,
                },
                'media': [],
              },
            })
          : await _api.checkHealth();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = true;
        _status = testAnalysis
            ? 'Koneksi API dan kontrak analisis berhasil'
            : 'Backend aktif';
        _output = const JsonEncoder.withIndent('  ').convert(result);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = false;
        _status = 'Pengujian gagal';
        _output = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _ok == null
        ? Colors.blueGrey
        : (_ok! ? Colors.green.shade700 : Colors.red.shade700);
    return Scaffold(
      appBar: AppBar(title: const Text('Tes Backend SiCA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Tahap integrasi awal. Backend belum memakai model AI visi; '
                'hasil analisis saat ini seharusnya berstatus INSUFFICIENT_EVIDENCE. '
                'Jangan mengirim data survei nyata sebelum autentikasi ditambahkan.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(testAnalysis: false),
            icon: const Icon(Icons.cloud_done_outlined),
            label: const Text('1. Tes koneksi /health'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(testAnalysis: true),
            icon: const Icon(Icons.api),
            label: const Text('2. Tes endpoint analisis dengan data dummy'),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                _ok == null
                    ? Icons.info_outline
                    : (_ok! ? Icons.check_circle_outline : Icons.error_outline),
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
