import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'survey_form_screen.dart';
import 'survey_result_screen.dart';

class ExpeditionScreen extends StatefulWidget {
  const ExpeditionScreen({super.key});

  @override
  State<ExpeditionScreen> createState() => _ExpeditionScreenState();
}

class _ExpeditionScreenState extends State<ExpeditionScreen> {
  final _db = LocalDatabase.instance;

  List<Map<String, Object?>> _expeditions = [];
  Map<int, int> _surveyCounts = {};
  int _pending = 0;
  int _surveys = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

    Future<void> _load() async {
    final expeditions = await _db.getExpeditions();
    final pending = await _db.countPending();
    final surveys = await _db.countSurveys();

    final surveyCounts = <int, int>{};

    for (final expedition in expeditions) {
      final id = expedition['id'];

      if (id is int) {
        surveyCounts[id] =
            await _db.countSurveysForExpedition(id);
      }
    }

    if (!mounted) return;

    setState(() {
      _expeditions = expeditions;
      _surveyCounts = surveyCounts;
      _pending = pending;
      _surveys = surveys;
    });
  }

  Future<void> _newExpedition() async {
    final nameCtrl = TextEditingController();
    final teamCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekspedisi Baru'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama kegiatan *',
                ),
              ),
              TextField(
                controller: teamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tim survei *',
                ),
              ),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi umum / DAS',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  teamCtrl.text.trim().isEmpty) {
                return;
              }

              final id =
                  'EKS-${DateTime.now().millisecondsSinceEpoch}';

              await _db.createExpedition(
                localId: id,
                name: nameCtrl.text.trim(),
                dateStart: DateTime.now(),
                team: teamCtrl.text.trim(),
                location: locationCtrl.text.trim(),
              );

              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    teamCtrl.dispose();
    locationCtrl.dispose();

    if (result == true) {
      _load();
    }
  }

  Future<void> _openExpedition(
    Map<String, Object?> expedition,
  ) async {
    final id = expedition['id'] as int;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyListScreen(
          expeditionId: id,
        ),
      ),
    );

    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SiCA – Survei Cepat Air'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Tutup aplikasi',
            onPressed: () {
              SystemNavigator.pop();
            },
            icon: const Icon(Icons.close),
        ),
    ],
),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        'Pengukuran',
                        '$_surveys',
                        Icons.water,
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        'Pending',
                        '$_pending',
                        Icons.cloud_upload_outlined,
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        'Ekspedisi',
                        '${_expeditions.length}',
                        Icons.forest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.shade50,
              child: const ListTile(
                leading: Icon(Icons.offline_bolt),
                title: Text('Offline-first aktif'),
                subtitle: Text(
                  'Data pengukuran disimpan di perangkat terlebih dahulu. '
                  'Sinkronisasi server akan ditambahkan pada tahap berikutnya.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ekspedisi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _newExpedition,
                  icon: const Icon(Icons.add),
                  label: const Text('Baru'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_expeditions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada ekspedisi. Buat ekspedisi untuk mulai '
                    'mengumpulkan beberapa titik pengukuran secara terpisah.',
                  ),
                ),
              )
            else
              ..._expeditions.map(
                (e) {
                  final expeditionId = e['id'];
                  final surveyCount = expeditionId is int
                      ? (_surveyCounts[expeditionId] ?? 0)
                      : 0;

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.forest),
                      ),
                      title: Text('${e['name']}'),
                      subtitle: Text(
                        '${e['team']}\n'
                        '${e['location'] ?? '-'}\n'
                        '$surveyCount survei',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: () => _openExpedition(e),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    String title,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.teal.shade700,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class SurveyListScreen extends StatefulWidget {
  final int expeditionId;

  const SurveyListScreen({
    super.key,
    required this.expeditionId,
  });

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  final _db = LocalDatabase.instance;

  List<Map<String, Object?>> _surveys = [];
  Map<String, Object?>? _expedition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final expedition =
        await _db.getExpedition(widget.expeditionId);

    final surveys =
        await _db.getSurveysForExpedition(
      widget.expeditionId,
    );

    if (!mounted) return;

    setState(() {
      _expedition = expedition;
      _surveys = surveys;
      _loading = false;
    });
  }

  Future<void> _newSurvey() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyFormScreen(
          expeditionId: widget.expeditionId,
        ),
      ),
    );

    await _load();
  }

  Future<void> _openSurvey(int surveyId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyResultScreen(
          surveyId: surveyId,
        ),
      ),
    );

    await _load();
  }

  Map<String, List<Map<String, Object?>>> _groupByDate() {
    final grouped =
        <String, List<Map<String, Object?>>>{};

    for (final survey in _surveys) {
      final rawDate = survey['waktu_survey'];

      String dateKey;

      if (rawDate == null) {
        dateKey = 'Tanggal tidak diketahui';
      } else {
        final parsed = DateTime.tryParse(
          rawDate.toString(),
        );

        if (parsed == null) {
          dateKey = rawDate.toString().split(' ').first;
        } else {
          dateKey = _dateKey(parsed);
        }
      }

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(survey);
    }

    return grouped;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(String dateKey) {
    final date = DateTime.tryParse(dateKey);

    if (date == null) {
      return dateKey;
    }

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(Object? rawDate) {
    if (rawDate == null) {
      return '-';
    }

    final parsed = DateTime.tryParse(
      rawDate.toString(),
    );

    if (parsed == null) {
      final text = rawDate.toString();

      if (text.contains(' ')) {
        return text.split(' ').last;
      }

      return text;
    }

    return '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(
    Object? value, {
    int decimals = 3,
  }) {
    if (value == null) {
      return '-';
    }

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (number == null) {
      return '-';
    }

    return number.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_expedition?['name'] ?? 'Ekspedisi'}',
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  100,
                ),
                children: [
                  _buildExpeditionHeader(),
                  const SizedBox(height: 16),

                  if (_surveys.isEmpty)
                    _buildEmptyState()
                  else
                    ...grouped.entries.map(
                      (entry) => _buildDateSection(
                        entry.key,
                        entry.value,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSurvey,
        icon: const Icon(
          Icons.add_location_alt,
        ),
        label: const Text(
          'Pengukuran Baru',
        ),
      ),
    );
  }

    Widget _buildExpeditionHeader() {
    double totalDischarge = 0;
    double totalPower = 0;
    int powerCount = 0;

    for (final survey in _surveys) {
      final discharge = survey['discharge_cms'];
      final power = survey['power_output_kw'];

      if (discharge is num) {
        totalDischarge += discharge.toDouble();
      } else if (discharge != null) {
        totalDischarge +=
            double.tryParse(discharge.toString()) ?? 0;
      }

      if (power is num) {
        totalPower += power.toDouble();
        powerCount++;
      } else if (power != null) {
        final parsedPower =
            double.tryParse(power.toString());

        if (parsedPower != null) {
          totalPower += parsedPower;
          powerCount++;
        }
      }
    }

    final dateStart =
        '${_expedition?['date_start'] ?? '-'}';

    final dateEnd =
        _expedition?['date_end'];

    final period = dateEnd == null ||
            dateEnd.toString().trim().isEmpty
        ? dateStart
        : '$dateStart s/d ${dateEnd.toString()}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Colors.teal.shade50,
                  child: Icon(
                    Icons.forest,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_expedition?['name'] ?? 'Ekspedisi'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              'ID: ${_expedition?['local_id'] ?? '-'}',
            ),
            const SizedBox(height: 4),

            Text(
              'Tim: ${_expedition?['team'] ?? '-'}',
            ),
            const SizedBox(height: 4),

            Text(
              'Lokasi: ${_expedition?['location'] ?? '-'}',
            ),
            const SizedBox(height: 4),

            Text(
              'Periode: $period',
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _summaryBox(
                    icon: Icons.location_on_outlined,
                    label: 'Titik',
                    value: '${_surveys.length}',
                    unit: 'survei',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryBox(
                    icon: Icons.water_drop_outlined,
                    label: 'Total Debit',
                    value: totalDischarge
                        .toStringAsFixed(2),
                    unit: 'm³/s',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryBox(
                    icon: Icons.bolt_outlined,
                    label: 'Total Daya',
                    value: powerCount == 0
                        ? '-'
                        : totalPower
                            .toStringAsFixed(2),
                    unit: 'kW',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.teal.shade100,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: Colors.teal.shade700,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 52,
              color: Colors.teal.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada pengukuran',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda dapat melakukan beberapa '
              'pengukuran dalam satu hari atau '
              'kembali pada hari berikutnya untuk '
              'menambahkan titik pengukuran baru.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _newSurvey,
              icon: const Icon(
                Icons.add_location_alt,
              ),
              label: const Text(
                'Mulai Pengukuran',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(
    String dateKey,
    List<Map<String, Object?>> surveys,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            4,
            4,
            4,
            8,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 19,
                color: Colors.teal.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(dateKey),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              Text(
                '${surveys.length} titik',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        ...surveys.map(
          (survey) => _buildSurveyCard(survey),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSurveyCard(
    Map<String, Object?> survey,
  ) {
    final surveyId = survey['id'];

    final power = survey['power_output_kw'];

    final surveyName =
        '${survey['nama_sungai'] ?? 'Sungai tidak diketahui'}';

    final localId =
        '${survey['local_id'] ?? '-'}';

    final syncStatus =
        '${survey['sync_status'] ?? 'PENDING'}';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor:
              Colors.teal.shade50,
          child: Icon(
            Icons.water_drop,
            color: Colors.teal.shade700,
          ),
        ),
        title: Text(
          surveyName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '$localId • '
                '${_formatTime(survey['waktu_survey'])}',
              ),
              const SizedBox(height: 2),
              Text(
                'Debit: '
                '${_formatNumber(survey['discharge_cms'])} m³/s',
              ),
              if (power != null)
                Text(
                  'Potensi: '
                  '${_formatNumber(power, decimals: 2)} kW',
                ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: _statusIcon(syncStatus),
        onTap: surveyId == null
            ? null
            : () => _openSurvey(
                  surveyId as int,
                ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'SYNCED':
        return const Tooltip(
          message: 'Sudah tersinkron',
          child: Icon(
            Icons.cloud_done,
            color: Colors.green,
          ),
        );

      case 'FAILED':
        return const Tooltip(
          message: 'Sinkronisasi gagal',
          child: Icon(
            Icons.cloud_off,
            color: Colors.red,
          ),
        );

      case 'SYNCING':
        return const Tooltip(
          message: 'Sedang sinkronisasi',
          child: Icon(
            Icons.cloud_sync,
            color: Colors.blue,
          ),
        );

      default:
        return const Tooltip(
          message: 'Menunggu sinkronisasi',
          child: Icon(
            Icons.cloud_upload_outlined,
            color: Colors.orange,
          ),
        );
    }
  }
}
