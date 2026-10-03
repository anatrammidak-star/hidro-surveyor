import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'survey_form_screen.dart';

class ExpeditionScreen extends StatefulWidget {
  const ExpeditionScreen({super.key});

  @override
  State<ExpeditionScreen> createState() => _ExpeditionScreenState();
}

class _ExpeditionScreenState extends State<ExpeditionScreen> {
  final LocalDatabase _database = LocalDatabase.instance;

  List<Map<String, Object?>> _expeditions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpeditions();
  }

  Future<void> _loadExpeditions() async {
    setState(() {
      _loading = true;
    });

    final data = await _database.getExpeditions();

    if (!mounted) return;

    setState(() {
      _expeditions = data;
      _loading = false;
    });
  }

  Future<void> _createExpedition() async {
    final nameController = TextEditingController();
    final teamController = TextEditingController();
    final locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ekspedisi Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama ekspedisi',
                    hintText: 'Contoh: Survei Potensi DAS XYZ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teamController,
                  decoration: const InputDecoration(
                    labelText: 'Tim survei',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi / wilayah',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(context, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final now = DateTime.now();
    final localId = 'EXP-${now.microsecondsSinceEpoch}';

    await _database.insertExpedition({
      'local_id': localId,
      'name': nameController.text.trim(),
      'date_start': now.toIso8601String(),
      'team': teamController.text.trim(),
      'location': locationController.text.trim(),
      'sync_status': 'LOCAL',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _loadExpeditions();
  }

  Future<void> _openExpedition(
    Map<String, Object?> expedition,
  ) async {
    final id = expedition['id'];

    if (id is! int) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyFormScreen(
          expeditionId: id,
          expeditionName: expedition['name']?.toString() ?? '',
        ),
      ),
    );

    await _loadExpeditions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HydroSurveyor'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _expeditions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadExpeditions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _expeditions.length,
                    itemBuilder: (context, index) {
                      final expedition = _expeditions[index];

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.explore),
                          ),
                          title: Text(
                            expedition['name']?.toString() ??
                                'Tanpa nama',
                          ),
                          subtitle: Text(
                            [
                              expedition['team']
                                      ?.toString()
                                      .trim() ??
                                  '',
                              expedition['location']
                                      ?.toString()
                                      .trim() ??
                                  '',
                              'Status: ${expedition['sync_status'] ?? 'LOCAL'}',
                            ].where((e) => e.isNotEmpty).join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            _openExpedition(expedition);
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createExpedition,
        icon: const Icon(Icons.add),
        label: const Text('Ekspedisi Baru'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada ekspedisi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buat ekspedisi terlebih dahulu, '
              'kemudian tambahkan pengukuran sungai '
              'satu per satu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createExpedition,
              icon: const Icon(Icons.add),
              label: const Text('Buat Ekspedisi'),
            ),
          ],
        ),
      ),
    );
  }
}
