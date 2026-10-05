import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'survey_form_screen.dart';
import 'survey_result_screen.dart';

class SurveyHistoryScreen extends StatefulWidget {
  final int expeditionId;

  const SurveyHistoryScreen({
    super.key,
    required this.expeditionId,
  });

  @override
  State<SurveyHistoryScreen> createState() =>
      _SurveyHistoryScreenState();
}

class _SurveyHistoryScreenState
    extends State<SurveyHistoryScreen> {
  final _db = LocalDatabase.instance;

  List<Map<String, Object?>> _surveys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _loading = true;
    });

    try {
      final surveys =
          await _db.getSurveysForExpedition(
        widget.expeditionId,
      );

      if (!mounted) return;

      setState(() {
        _surveys = surveys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membaca riwayat pengukuran: $e',
          ),
        ),
      );
    }
  }

  Future<void> _newSurvey() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SurveyFormScreen(
          expeditionId: widget.expeditionId,
        ),
      ),
    );

    if (!mounted) return;

    await _loadSurveys();
  }

  Future<void> _openSurvey(
    int surveyId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SurveyResultScreen(
          surveyId: surveyId,
        ),
      ),
    );

    if (!mounted) return;

    await _loadSurveys();
  }

  String _text(
    Map<String, Object?> row,
    String key,
  ) {
    final value = row[key];

    if (value == null) {
      return '-';
    }

    return value.toString();
  }

  String _surveyNumber(int index) {
    return 'Pengukuran ${index + 1}';
  }

  String _statusLabel(
    String? status,
  ) {
    switch (status) {
      case 'SYNCED':
        return 'TERKIRIM';

      case 'SYNCING':
        return 'MENGIRIM';

      case 'FAILED':
        return 'GAGAL';

      case 'PENDING':
        return 'PENDING';

      case 'LOCAL':
        return 'LOCAL';

      default:
        return status ?? 'UNKNOWN';
    }
  }

  Color _statusColor(
    String? status,
  ) {
    switch (status) {
      case 'SYNCED':
        return Colors.green;

      case 'SYNCING':
        return Colors.blue;

      case 'FAILED':
        return Colors.red;

      case 'PENDING':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  String _documentationLabel(
    String? status,
  ) {
    switch (status) {
      case 'COMPLETE':
        return 'Dokumentasi lengkap';

      case 'PARTIAL':
        return 'Dokumentasi parsial';

      default:
        return 'Dokumentasi belum lengkap';
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Pengukuran',
        ),
        backgroundColor:
            Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSurvey,
        icon: const Icon(Icons.add),
        label: const Text(
          'Pengukuran Baru',
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_surveys.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSurveys,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.water_drop_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Belum ada pengukuran.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Tekan "Pengukuran Baru" untuk '
                'menambahkan pengukuran pertama.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSurveys,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          100,
        ),
        itemCount: _surveys.length,
        itemBuilder: (
          context,
          index,
        ) {
          final row = _surveys[index];

          final id =
              row['id'] as int;

          final river =
              _text(
            row,
            'nama_sungai',
          );

          final surveyTime =
              _text(
            row,
            'waktu_survey',
          );

          final syncStatus =
              row['sync_status']
                  ?.toString();

          final documentation =
              row['documentation_status']
                  ?.toString();

          final aiStatus =
              row['ai_status']
                  ?.toString();

          final discharge =
              row['discharge_cms'];

          final power =
              row['power_output_kw'];

          return Card(
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(12),
              onTap: () =>
                  _openSurvey(id),
              child: Padding(
                padding:
                    const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _surveyNumber(
                              index,
                            ),
                            style:
                                const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusChip(
                          syncStatus,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop,
                          size: 18,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Text(
                            river.isEmpty
                                ? 'Nama sungai belum diisi'
                                : river,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      'Waktu: $surveyTime',
                      style:
                          const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _infoChip(
                          Icons.cloud_off,
                          _statusLabel(
                            syncStatus,
                          ),
                        ),
                        _infoChip(
                          Icons.description_outlined,
                          _documentationLabel(
                            documentation,
                          ),
                        ),
                        _infoChip(
                          Icons.auto_awesome,
                          aiStatus ??
                              'NOT_ANALYZED',
                        ),
                      ],
                    ),

                    if (discharge != null ||
                        power != null) ...[
                      const Divider(
                        height: 20,
                      ),

                      if (discharge != null)
                        Text(
                          'Debit: '
                          '${_formatNumber(discharge)} '
                          'm³/s',
                        ),

                      if (power != null)
                        Text(
                          'Daya: '
                          '${_formatNumber(power)} '
                          'kW',
                        ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        Text(
                          'Lihat detail',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(
    String? status,
  ) {
    final color =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(0.35),
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String label,
  ) {
    return Chip(
      avatar: Icon(
        icon,
        size: 15,
      ),
      label: Text(
        label,
        style:
            const TextStyle(
          fontSize: 10,
        ),
      ),
      visualDensity:
          VisualDensity.compact,
    );
  }

  String _formatNumber(
    Object? value,
  ) {
    if (value == null) {
      return '-';
    }

    final number =
        double.tryParse(
      value.toString(),
    );

    if (number == null) {
      return value.toString();
    }

    return number
        .toStringAsFixed(3);
  }
}
