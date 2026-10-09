import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'survey_form_screen.dart';
import 'survey_result_screen.dart';
import 'backend_test_screen.dart';

class ExpeditionScreen extends StatefulWidget {
  const ExpeditionScreen({super.key});

  @override
  State<ExpeditionScreen> createState() => _ExpeditionScreenState();
}

class _ExpeditionScreenState extends State<ExpeditionScreen> {
  final LocalDatabase _db = LocalDatabase.instance;

  List<Map<String, Object?>> _expeditions = [];
  final Map<int, int> _surveyCounts = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final expeditions = await _db.getExpeditions();

      final counts = <int, int>{};

      for (final expedition in expeditions) {
        final id = expedition['id'];

        if (id is int) {
          counts[id] =
              await _db.countSurveysForExpedition(id);
        }
      }

      if (!mounted) return;

      setState(() {
        _expeditions = expeditions;
        _surveyCounts
          ..clear()
          ..addAll(counts);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createExpedition() async {
    final result = await showDialog<_ExpeditionFormData>(
      context: context,
      builder: (_) => const _CreateExpeditionDialog(),
    );

    if (result == null) return;

    try {
      final localId =
          'EXP-${DateTime.now().millisecondsSinceEpoch}';

      await _db.createExpedition(
        localId: localId,
        name: result.name,
        dateStart: result.dateStart,
        dateEnd: result.dateEnd,
        team: result.team,
        location: result.location,
        notes: result.notes,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat ekspedisi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _openExpedition(
    Map<String, Object?> expedition,
  ) async {
    final id = expedition['id'];

    if (id is! int) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyListScreen(
          expeditionId: id,
        ),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SiCA - Survei Cepat Air',
        ),
        actions: [
          IconButton(
            tooltip: 'Tes Backend SiCA',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BackendTestScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(
              Icons.exit_to_app,
            ),
            onPressed: () {
              SystemNavigator.pop();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createExpedition,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Ekspedisi Baru',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline,
            size: 56,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Gagal memuat data ekspedisi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Coba Lagi',
              ),
            ),
          ),
        ],
      );
    }

    if (_expeditions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        100,
      ),
      children: [
        _buildOverviewCard(),
        const SizedBox(height: 12),
        ..._expeditions.map(
          _buildExpeditionCard,
        ),
      ],
    );
  }

  Widget _buildOverviewCard() {
    int totalSurveys = 0;
    int pendingSurveys = 0;

    for (final expedition in _expeditions) {
      final id = expedition['id'];

      if (id is int) {
        totalSurveys +=
            _surveyCounts[id] ?? 0;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _miniMetric(
                icon: Icons.explore,
                label: 'Ekspedisi',
                value: '${_expeditions.length}',
              ),
            ),
            Expanded(
              child: _miniMetric(
                icon: Icons.water_drop,
                label: 'Titik Survei',
                value: '$totalSurveys',
              ),
            ),
            Expanded(
              child: FutureBuilder<int>(
                future: _db.countPending(),
                builder: (
                  context,
                  snapshot,
                ) {
                  pendingSurveys =
                      snapshot.data ?? 0;

                  return _miniMetric(
                    icon: Icons.sync,
                    label: 'Pending',
                    value: '$pendingSurveys',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpeditionCard(
    Map<String, Object?> expedition,
  ) {
    final id = expedition['id'];

    final name =
        '${expedition['name'] ?? 'Ekspedisi tanpa nama'}';

    final location =
        '${expedition['location'] ?? '-'}';

    final team =
        '${expedition['team'] ?? '-'}';

    final dateStart =
        '${expedition['date_start'] ?? ''}';

    final dateEnd =
        '${expedition['date_end'] ?? ''}';

    final surveyCount = id is int
        ? (_surveyCounts[id] ?? 0)
        : 0;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openExpedition(
          expedition,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.explore,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style: TextStyle(
                            color:
                                Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$surveyCount survei',
                      style: TextStyle(
                        color:
                            Colors.teal.shade800,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoItem(
                      Icons.calendar_today,
                      _formatDateRange(
                        dateStart,
                        dateEnd,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoItem(
                      Icons.groups,
                      team,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  Text(
                    'Buka ekspedisi',
                    style: TextStyle(
                      color:
                          Colors.teal.shade700,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color:
                        Colors.teal.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String text,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateRange(
    String start,
    String end,
  ) {
    if (start.isEmpty && end.isEmpty) {
      return '-';
    }

    final formattedStart =
        _formatDate(start);

    if (end.isEmpty || end == start) {
      return formattedStart;
    }

    return '$formattedStart - ${_formatDate(end)}';
  }

  String _formatDate(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return '-';
    }

    final date =
        DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(
    Object? value,
  ) {
    if (value == null) {
      return '-';
    }

    final date =
        DateTime.tryParse('$value');

    if (date == null) {
      return '-';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(
    Object? value, {
    int decimals = 2,
  }) {
    if (value == null) {
      return '-';
    }

    double? number;

    if (value is num) {
      number = value.toDouble();
    } else {
      number =
          double.tryParse('$value');
    }

    if (number == null) {
      return '-';
    }

    return number.toStringAsFixed(
      decimals,
    );
  }

  Widget _buildSurveyCard(
    Map<String, Object?> survey,
  ) {
    final surveyId = survey['id'];

    final mode =
        '${survey['survey_mode'] ?? 'DISCHARGE_ONLY'}';

    final power =
        survey['power_output_kw'];

    final head =
        survey['gross_head_m'];

    final discharge =
        survey['discharge_cms'];

    final surveyName =
        '${survey['nama_sungai'] ?? 'Sungai tidak diketahui'}';

    final localId =
        '${survey['local_id'] ?? '-'}';

    final syncStatus =
        '${survey['sync_status'] ?? 'PENDING'}';

    final hasGps =
        survey['latitude'] != null &&
        survey['longitude'] != null;

    final hasDischarge =
        discharge != null &&
        (double.tryParse(
                  '$discharge',
                ) ??
                0) >
            0;

    final isHydro =
        mode == 'HYDRO_POWER';

    final hasHydroData =
        !isHydro ||
        ((double.tryParse(
                  '$head',
                ) ??
                0) >
            0 &&
        power != null);

    final dataComplete =
        hasGps &&
        hasDischarge &&
        hasHydroData;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor:
              isHydro
                  ? Colors.teal.shade50
                  : Colors.blue.shade50,
          child: Icon(
            isHydro
                ? Icons.bolt
                : Icons.water_drop,
            color: isHydro
                ? Colors.teal.shade700
                : Colors.blue.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                surveyName,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isHydro
                    ? Colors.teal.shade50
                    : Colors.blue.shade50,
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                isHydro
                    ? 'HIDRO'
                    : 'DEBIT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                  color: isHydro
                      ? Colors.teal.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '$localId • '
                '${_formatTime(survey['waktu_survey'])}',
              ),
              const SizedBox(height: 3),
              Text(
                'Debit: '
                '${_formatNumber(discharge)} m³/s',
              ),
              if (isHydro) ...[
                const SizedBox(height: 2),
                Text(
                  'Head: '
                  '${_formatNumber(head)} m',
                ),
                if (power != null)
                  Text(
                    'Potensi: '
                    '${_formatNumber(
                      power,
                      decimals: 2,
                    )} kW',
                  ),
              ],
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    dataComplete
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    size: 15,
                    color: dataComplete
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dataComplete
                        ? 'Data lengkap'
                        : 'Perlu verifikasi',
                    style: TextStyle(
                      fontSize: 12,
                      color: dataComplete
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing:
            _statusIcon(syncStatus),
        onTap: surveyId == null
            ? null
            : () => _openSurvey(
                  surveyId as int,
                ),
      ),
    );
  }

  Future<void> _openSurvey(
    int surveyId,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyResultScreen(
          surveyId: surveyId,
        ),
      ),
    );

    await _load();
  }

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.explore_off,
          size: 72,
          color: Colors.teal.shade300,
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Belum ada ekspedisi',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Buat ekspedisi pertama untuk '
          'mulai mencatat titik survei sungai.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: _createExpedition,
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Buat Ekspedisi',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection(
    String title,
    List<Map<String, Object?>> surveys,
  ) {
    if (surveys.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            4,
            12,
            4,
            8,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        ...surveys.map(
          _buildSurveyCard,
        ),
      ],
    );
  }

  Widget _buildExpeditionHeader(
    Map<String, Object?> expedition,
    List<Map<String, Object?>> surveys,
  ) {
    double totalDischarge = 0;
    double totalPower = 0;

    double minDischarge =
        double.infinity;
    double maxDischarge =
        double.negativeInfinity;

    double minPower =
        double.infinity;
    double maxPower =
        double.negativeInfinity;

    double minHead =
        double.infinity;
    double maxHead =
        double.negativeInfinity;

    int hydroCount = 0;
    int dischargeOnlyCount = 0;

    for (final survey in surveys) {
      final discharge =
          _toDouble(
        survey['discharge_cms'],
      );

      final power =
          _toDouble(
        survey['power_output_kw'],
      );

      final head =
          _toDouble(
        survey['gross_head_m'],
      );

      if (discharge != null) {
        totalDischarge += discharge;

        if (discharge <
            minDischarge) {
          minDischarge =
              discharge;
        }

        if (discharge >
            maxDischarge) {
          maxDischarge =
              discharge;
        }
      }

      if (power != null) {
        totalPower += power;

        if (power < minPower) {
          minPower = power;
        }

        if (power > maxPower) {
          maxPower = power;
        }
      }

      if (head != null) {
        if (head < minHead) {
          minHead = head;
        }

        if (head > maxHead) {
          maxHead = head;
        }
      }

      final mode =
          '${survey['survey_mode'] ?? ''}';

      if (mode ==
          'HYDRO_POWER') {
        hydroCount++;
      } else {
        dischargeOnlyCount++;
      }
    }

    final dischargeCount =
        surveys.where(
      (survey) =>
          _toDouble(
            survey['discharge_cms'],
          ) !=
          null,
    ).length;

    final powerCount =
        surveys.where(
      (survey) =>
          _toDouble(
            survey['power_output_kw'],
          ) !=
          null,
    ).length;

    final headCount =
        surveys.where(
      (survey) =>
          _toDouble(
            survey['gross_head_m'],
          ) !=
          null,
    ).length;

    final avgDischarge =
        dischargeCount == 0
            ? null
            : totalDischarge /
                dischargeCount;

    final avgPower =
        powerCount == 0
            ? null
            : totalPower /
                powerCount;

    final name =
        '${expedition['name'] ?? 'Ekspedisi'}';

    final location =
        '${expedition['location'] ?? '-'}';

    final team =
        '${expedition['team'] ?? '-'}';

    final dateStart =
        '${expedition['date_start'] ?? ''}';

    final dateEnd =
        '${expedition['date_end'] ?? ''}';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color:
                        Colors.teal.shade50,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    Icons.explore,
                    size: 28,
                    color:
                        Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name,
                        style:
                            const TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        location,
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _summaryBox(
              icon: Icons.calendar_today,
              label: 'Periode',
              value: _formatDateRange(
                dateStart,
                dateEnd,
              ),
            ),
            const SizedBox(height: 8),
            _summaryBox(
              icon: Icons.groups,
              label: 'Tim',
              value: team,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    icon:
                        Icons.location_on,
                    label:
                        'Titik Survei',
                    value:
                        '${surveys.length}',
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    icon:
                        Icons.water_drop,
                    label:
                        'Rata-rata Debit',
                    value:
                        avgDischarge == null
                            ? '-'
                            : '${avgDischarge.toStringAsFixed(2)} m³/s',
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    icon:
                        Icons.bolt,
                    label:
                        'Titik Hidro',
                    value:
                        '$hydroCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (surveys.isNotEmpty) ...[
              _rangeRow(
                icon:
                    Icons.water_drop,
                label:
                    'Rentang Debit',
                value:
                    minDischarge ==
                            double.infinity
                        ? '-'
                        : '${minDischarge.toStringAsFixed(2)} - '
                          '${maxDischarge.toStringAsFixed(2)} m³/s',
              ),
              const SizedBox(height: 8),
              _rangeRow(
                icon:
                    Icons.bolt,
                label:
                    'Rentang Daya',
                value:
                    minPower ==
                            double.infinity
                        ? '-'
                        : '${minPower.toStringAsFixed(2)} - '
                          '${maxPower.toStringAsFixed(2)} kW',
              ),
              const SizedBox(height: 8),
              _rangeRow(
                icon:
                    Icons.height,
                label:
                    'Rentang Head',
                value:
                    minHead ==
                            double.infinity
                        ? '-'
                        : '${minHead.toStringAsFixed(2)} - '
                          '${maxHead.toStringAsFixed(2)} m',
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.water_drop,
                    label:
                        'Debit',
                    value:
                        '$dischargeOnlyCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.bolt,
                    label:
                        'Hidro',
                    value:
                        '$hydroCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.height,
                    label:
                        'Head',
                    value:
                        '$headCount',
                  ),
                ),
              ],
            ),
            if (avgPower != null) ...[
              const SizedBox(height: 10),
              Text(
                'Rata-rata potensi daya: '
                '${avgPower.toStringAsFixed(2)} kW',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangeRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.teal.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _countChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
              ),
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 21,
          color: Colors.teal.shade700,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color:
                Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Icon _statusIcon(
    String status,
  ) {
    switch (status.toUpperCase()) {
      case 'SYNCED':
        return const Icon(
          Icons.cloud_done,
          color: Colors.green,
        );

      case 'SYNCING':
        return const Icon(
          Icons.cloud_upload,
          color: Colors.orange,
        );

      case 'FAILED':
        return const Icon(
          Icons.cloud_off,
          color: Colors.red,
        );

      case 'PENDING':
      default:
        return const Icon(
          Icons.cloud_queue,
          color: Colors.grey,
        );
    }
  }

  double? _toDouble(
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      '$value',
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
  State<SurveyListScreen> createState() =>
      _SurveyListScreenState();
}

class _SurveyListScreenState
    extends State<SurveyListScreen> {
  final LocalDatabase _db =
      LocalDatabase.instance;

  Map<String, Object?>? _expedition;

  List<Map<String, Object?>> _surveys = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final expedition =
          await _db.getExpedition(
        widget.expeditionId,
      );

      final surveys =
          await _db.getSurveysForExpedition(
        widget.expeditionId,
      );

      if (!mounted) return;

      setState(() {
        _expedition = expedition;
        _surveys = surveys;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _newSurvey() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyFormScreen(
          expeditionId:
              widget.expeditionId,
        ),
      ),
    );

    await _load();
  }

  Future<void> _openSurvey(
    int surveyId,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyResultScreen(
          surveyId: surveyId,
        ),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${_expedition?['name'] ?? 'Ekspedisi'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _newSurvey,
        icon: const Icon(
          Icons.add_location_alt,
        ),
        label: const Text(
          'Tambah Survei',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 56,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text(
                'Coba Lagi',
              ),
            ),
          ),
        ],
      );
    }

    final expedition =
        _expedition ??
            <String, Object?>{};

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        100,
      ),
      children: [
        _buildExpeditionHeader(
          expedition,
          _surveys,
        ),
        if (_surveys.isEmpty)
          _buildNoSurveyState()
        else
          ..._buildSurveyGroups(),
      ],
    );
  }

  List<Widget> _buildSurveyGroups() {
    final Map<String,
            List<Map<String, Object?>>>
        grouped = {};

    for (final survey in _surveys) {
      final rawDate =
          '${survey['waktu_survey'] ?? ''}';

      final date =
          DateTime.tryParse(rawDate);

      final key = date == null
          ? 'Tanggal tidak diketahui'
          : '${date.year}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(
        key,
        () => [],
      );

      grouped[key]!.add(
        survey,
      );
    }

    final keys =
        grouped.keys.toList()
          ..sort(
            (a, b) =>
                b.compareTo(a),
          );

    return keys.map(
      (key) => _buildDateSection(
        _displayGroupDate(key),
        grouped[key]!,
      ),
    ).toList();
  }

  String _displayGroupDate(
    String value,
  ) {
    if (value ==
        'Tanggal tidak diketahui') {
      return value;
    }

    final date =
        DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildDateSection(
    String title,
    List<Map<String, Object?>> surveys,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            4,
            8,
            4,
            8,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        ...surveys.map(
          (survey) =>
              _buildSurveyCard(
            survey,
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyCard(
    Map<String, Object?> survey,
  ) {
    final surveyId =
        survey['id'];

    final mode =
        '${survey['survey_mode'] ?? 'DISCHARGE_ONLY'}';

    final isHydro =
        mode == 'HYDRO_POWER';

    final power =
        survey['power_output_kw'];

    final head =
        survey['gross_head_m'];

    final discharge =
        survey['discharge_cms'];

    final surveyName =
        '${survey['nama_sungai'] ?? 'Sungai tidak diketahui'}';

    final localId =
        '${survey['local_id'] ?? '-'}';

    final syncStatus =
        '${survey['sync_status'] ?? 'PENDING'}';

    final hasGps =
        survey['latitude'] != null &&
        survey['longitude'] != null;

    final dischargeValue =
        double.tryParse(
              '$discharge',
            ) ??
            0;

    final headValue =
        double.tryParse(
              '$head',
            ) ??
            0;

    final hasDischarge =
        dischargeValue > 0;

    final hasHydroData =
        !isHydro ||
        (headValue > 0 &&
            power != null);

    final dataComplete =
        hasGps &&
        hasDischarge &&
        hasHydroData;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor:
              isHydro
                  ? Colors.teal.shade50
                  : Colors.blue.shade50,
          child: Icon(
            isHydro
                ? Icons.bolt
                : Icons.water_drop,
            color: isHydro
                ? Colors.teal.shade700
                : Colors.blue.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                surveyName,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isHydro
                    ? Colors.teal.shade50
                    : Colors.blue.shade50,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                isHydro
                    ? 'HIDRO'
                    : 'DEBIT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                  color: isHydro
                      ? Colors.teal.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 5,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '$localId • '
                '${_formatTime(
                  survey['waktu_survey'],
                )}',
              ),
              const SizedBox(height: 3),
              Text(
                'Debit: '
                '${_formatNumber(
                  discharge,
                )} m³/s',
              ),
              if (isHydro) ...[
                const SizedBox(height: 2),
                Text(
                  'Head: '
                  '${_formatNumber(
                    head,
                  )} m',
                ),
                if (power != null)
                  Text(
                    'Potensi: '
                    '${_formatNumber(
                      power,
                      decimals: 2,
                    )} kW',
                  ),
              ],
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    dataComplete
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    size: 15,
                    color: dataComplete
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dataComplete
                        ? 'Data lengkap'
                        : 'Perlu verifikasi',
                    style: TextStyle(
                      fontSize: 12,
                      color: dataComplete
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing:
            _statusIcon(syncStatus),
        onTap: surveyId == null
            ? null
            : () => _openSurvey(
                  surveyId as int,
                ),
      ),
    );
  }

  Widget _buildNoSurveyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 56,
              color:
                  Colors.teal.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada titik survei',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan survei sungai '
              'pertama pada ekspedisi ini.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _newSurvey,
              icon: const Icon(
                Icons.add_location_alt,
              ),
              label: const Text(
                'Tambah Survei',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(
    String start,
    String end,
  ) {
    if (start.isEmpty && end.isEmpty) {
      return '-';
    }

    final formattedStart = _formatDate(start);

    if (end.isEmpty || end == start) {
      return formattedStart;
    }

    return '$formattedStart - ${_formatDate(end)}';
  }

  String _formatDate(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildExpeditionHeader(
    Map<String, Object?> expedition,
    List<Map<String, Object?>> surveys,
  ) {
    double totalDischarge = 0;
    double totalPower = 0;

    double minDischarge =
        double.infinity;
    double maxDischarge =
        double.negativeInfinity;

    double minPower =
        double.infinity;
    double maxPower =
        double.negativeInfinity;

    double minHead =
        double.infinity;
    double maxHead =
        double.negativeInfinity;

    int hydroCount = 0;
    int dischargeOnlyCount = 0;

    int dischargeCount = 0;
    int powerCount = 0;
    int headCount = 0;

    for (final survey in surveys) {
      final discharge =
          _toDouble(
        survey['discharge_cms'],
      );

      final power =
          _toDouble(
        survey['power_output_kw'],
      );

      final head =
          _toDouble(
        survey['gross_head_m'],
      );

      if (discharge != null) {
        dischargeCount++;
        totalDischarge +=
            discharge;

        if (discharge <
            minDischarge) {
          minDischarge =
              discharge;
        }

        if (discharge >
            maxDischarge) {
          maxDischarge =
              discharge;
        }
      }

      if (power != null) {
        powerCount++;
        totalPower += power;

        if (power < minPower) {
          minPower = power;
        }

        if (power > maxPower) {
          maxPower = power;
        }
      }

      if (head != null) {
        headCount++;

        if (head < minHead) {
          minHead = head;
        }

        if (head > maxHead) {
          maxHead = head;
        }
      }

      final mode =
          '${survey['survey_mode'] ?? ''}';

      if (mode ==
          'HYDRO_POWER') {
        hydroCount++;
      } else {
        dischargeOnlyCount++;
      }
    }

    final avgDischarge =
        dischargeCount == 0
            ? null
            : totalDischarge /
                dischargeCount;

    final avgPower =
        powerCount == 0
            ? null
            : totalPower /
                powerCount;

    final name =
        '${expedition['name'] ?? 'Ekspedisi'}';

    final location =
        '${expedition['location'] ?? '-'}';

    final team =
        '${expedition['team'] ?? '-'}';

    final dateStart =
        '${expedition['date_start'] ?? ''}';

    final dateEnd =
        '${expedition['date_end'] ?? ''}';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color:
                        Colors.teal.shade50,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    Icons.explore,
                    size: 28,
                    color:
                        Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name,
                        style:
                            const TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        location,
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _summaryBox(
              icon:
                  Icons.calendar_today,
              label:
                  'Periode',
              value:
                  _formatDateRange(
                dateStart,
                dateEnd,
              ),
            ),
            const SizedBox(height: 8),
            _summaryBox(
              icon: Icons.groups,
              label: 'Tim',
              value: team,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    icon:
                        Icons.location_on,
                    label:
                        'Titik Survei',
                    value:
                        '${surveys.length}',
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    icon:
                        Icons.water_drop,
                    label:
                        'Rata-rata Debit',
                    value:
                        avgDischarge == null
                            ? '-'
                            : '${avgDischarge.toStringAsFixed(2)} m³/s',
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    icon: Icons.bolt,
                    label:
                        'Titik Hidro',
                    value:
                        '$hydroCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (surveys.isNotEmpty) ...[
              _rangeRow(
                icon:
                    Icons.water_drop,
                label:
                    'Rentang Debit',
                value:
                    minDischarge ==
                            double.infinity
                        ? '-'
                        : '${minDischarge.toStringAsFixed(2)} - '
                          '${maxDischarge.toStringAsFixed(2)} m³/s',
              ),
              const SizedBox(height: 8),
              _rangeRow(
                icon:
                    Icons.bolt,
                label:
                    'Rentang Daya',
                value:
                    minPower ==
                            double.infinity
                        ? '-'
                        : '${minPower.toStringAsFixed(2)} - '
                          '${maxPower.toStringAsFixed(2)} kW',
              ),
              const SizedBox(height: 8),
              _rangeRow(
                icon:
                    Icons.height,
                label:
                    'Rentang Head',
                value:
                    minHead ==
                            double.infinity
                        ? '-'
                        : '${minHead.toStringAsFixed(2)} - '
                          '${maxHead.toStringAsFixed(2)} m',
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.water_drop,
                    label:
                        'Debit',
                    value:
                        '$dischargeOnlyCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.bolt,
                    label:
                        'Hidro',
                    value:
                        '$hydroCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countChip(
                    icon:
                        Icons.height,
                    label:
                        'Head',
                    value:
                        '$headCount',
                  ),
                ),
              ],
            ),
            if (avgPower != null) ...[
              const SizedBox(height: 10),
              Text(
                'Rata-rata potensi daya: '
                '${avgPower.toStringAsFixed(2)} kW',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangeRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.teal.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _countChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
              ),
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 21,
          color: Colors.teal.shade700,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color:
                Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Icon _statusIcon(
    String status,
  ) {
    switch (status.toUpperCase()) {
      case 'SYNCED':
        return const Icon(
          Icons.cloud_done,
          color: Colors.green,
        );

      case 'SYNCING':
        return const Icon(
          Icons.cloud_upload,
          color: Colors.orange,
        );

      case 'FAILED':
        return const Icon(
          Icons.cloud_off,
          color: Colors.red,
        );

      case 'PENDING':
      default:
        return const Icon(
          Icons.cloud_queue,
          color: Colors.grey,
        );
    }
  }

  String _formatTime(
    Object? value,
  ) {
    if (value == null) {
      return '-';
    }

    final date =
        DateTime.tryParse('$value');

    if (date == null) {
      return '-';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(
    Object? value, {
    int decimals = 2,
  }) {
    if (value == null) {
      return '-';
    }

    double? number;

    if (value is num) {
      number = value.toDouble();
    } else {
      number =
          double.tryParse('$value');
    }

    if (number == null) {
      return '-';
    }

    return number.toStringAsFixed(
      decimals,
    );
  }

  double? _toDouble(
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      '$value',
    );
  }
}

class _ExpeditionFormData {
  final String name;
  final DateTime dateStart;
  final String dateEnd;
  final String team;
  final String location;
  final String notes;

  const _ExpeditionFormData({
    required this.name,
    required this.dateStart,
    required this.dateEnd,
    required this.team,
    required this.location,
    required this.notes,
  });
}

class _CreateExpeditionDialog
    extends StatefulWidget {
  const _CreateExpeditionDialog();

  @override
  State<_CreateExpeditionDialog>
      createState() =>
          _CreateExpeditionDialogState();
}

class _CreateExpeditionDialogState
    extends State<_CreateExpeditionDialog> {
  final _formKey =
      GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _teamController =
      TextEditingController();

  final _locationController =
      TextEditingController();

  final _notesController =
      TextEditingController();

  DateTime? _dateStart;
  DateTime? _dateEnd;

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked =
        await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate:
          _dateStart ??
              DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _dateStart = picked;

      if (_dateEnd != null &&
          _dateEnd!.isBefore(picked)) {
        _dateEnd = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initial =
        _dateEnd ??
            _dateStart ??
            DateTime.now();

    final picked =
        await showDatePicker(
      context: context,
      firstDate:
          _dateStart ??
              DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );

    if (picked == null) return;

    setState(() {
      _dateEnd = picked;
    });
  }

  String _dateText(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Pilih tanggal';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_dateStart == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Tanggal mulai harus dipilih.',
          ),
        ),
      );
      return;
    }

    if (_dateEnd == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Tanggal selesai harus dipilih.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _ExpeditionFormData(
        name:
            _nameController.text.trim(),
        dateStart: _dateStart!,
        dateEnd: _dateEnd!.toIso8601String(),
        team:
            _teamController.text.trim(),
        location:
            _locationController.text.trim(),
        notes:
            _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Ekspedisi Baru',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextFormField(
                  controller:
                      _nameController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Nama ekspedisi',
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Nama ekspedisi wajib diisi.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _pickStartDate,
                        icon: const Icon(
                          Icons.calendar_today,
                        ),
                        label: Text(
                          _dateText(
                            _dateStart,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _pickEndDate,
                        icon: const Icon(
                          Icons.event,
                        ),
                        label: Text(
                          _dateText(
                            _dateEnd,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _teamController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Tim',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _locationController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Lokasi wilayah',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Catatan',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          child: const Text(
            'Batal',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Simpan',
          ),
        ),
      ],
    );
  }
}
