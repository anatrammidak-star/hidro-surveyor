import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'survey_form_screen.dart';

class ExpeditionScreen extends StatefulWidget {
  const ExpeditionScreen({super.key});

  @override
  State<ExpeditionScreen> createState() => _ExpeditionScreenState();
}

class _ExpeditionScreenState extends State<ExpeditionScreen> {
  final _db = LocalDatabase.instance;

  List<Map<String, Object?>> _expeditions = [];
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

    if (!mounted) return;

    setState(() {
      _expeditions = expeditions;
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
        title: const Text('HydroSurveyor'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
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
                (e) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.forest),
                    ),
                    title: Text('${e['name']}'),
                    subtitle: Text(
                      '${e['team']}\n${e['location'] ?? '-'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () => _openExpedition(e),
                  ),
                ),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_expedition?['name'] ?? 'Ekspedisi'}',
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.forest),
              title: Text(
                '${_expedition?['local_id'] ?? ''}',
              ),
              subtitle: Text(
                '${_surveys.length} titik/pengukuran tersimpan lokal',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_surveys.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada pengukuran. Anda dapat kembali '
                  'beberapa jam atau hari kemudian dan menambahkan '
                  'titik baru.',
                ),
              ),
            )
          else
            ..._surveys.map(
              (s) {
                final power = s['power_output_kw'];

                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.water_drop,
                      color: Colors.teal.shade700,
                    ),
                    title: Text(
                      '${s['local_id']} — ${s['nama_sungai']}',
                    ),
                    subtitle: Text(
                      '${s['waktu_survey']}\n'
                      'Debit: '
                      '${((s['discharge_cms'] as num?) ?? 0).toStringAsFixed(3)} '
                      'm³/s'
                      '${power == null ? '' : '\nPotensi: ${(power as num).toStringAsFixed(2)} kW'}',
                    ),
                    isThreeLine: true,
                    trailing: _statusIcon(
                      '${s['sync_status']}',
                    ),
                  ),
                );
              },
            ),
        ],
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

  Widget _statusIcon(String status) {
    if (status == 'SYNCED') {
      return const Icon(
        Icons.cloud_done,
        color: Colors.green,
      );
    }

    if (status == 'FAILED') {
      return const Icon(
        Icons.cloud_off,
        color: Colors.red,
      );
    }

    return const Icon(
      Icons.cloud_upload_outlined,
      color: Colors.orange,
    );
  }
}
