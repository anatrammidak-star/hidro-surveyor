import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/hydro_calculator.dart';
import '../services/local_database.dart';
import 'camera_capture_screen.dart';

class SurveyFormScreen extends StatefulWidget {
  final int expeditionId;

  const SurveyFormScreen({
    super.key,
    required this.expeditionId,
  });

  @override
  State<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends State<SurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = LocalDatabase.instance;

  String _surveyMode = 'HYDRO_POWER';

  final _uptCtrl = TextEditingController(
    text: 'Balai Besar KSDA / Taman Nasional',
  );
  final _seksiCtrl = TextEditingController(
    text: 'Seksi Pengelolaan Wilayah II',
  );
  final _sungaiCtrl = TextEditingController();
  final _ketuaCtrl = TextEditingController(
    text: 'Ketua Tim Survei',
  );
  final _nipCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _depthCtrl = TextEditingController();
  final _velocityCtrl = TextEditingController();
  final _headCtrl = TextEditingController();

  Position? _pos;
  bool _loadingGps = false;
  String? _gpsError;
  CameraCaptureResult? _media;

  @override
  void initState() {
    super.initState();
    _lockGps();
  }

  @override
  void dispose() {
    for (final c in [
      _uptCtrl,
      _seksiCtrl,
      _sungaiCtrl,
      _ketuaCtrl,
      _nipCtrl,
      _widthCtrl,
      _depthCtrl,
      _velocityCtrl,
      _headCtrl,
    ]) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _lockGps() async {
    if (!mounted) return;

    setState(() {
      _loadingGps = true;
      _gpsError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _gpsError = 'Layanan lokasi/GPS perangkat sedang mati.';
        });
        return;
      }

      var perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        setState(() {
          _gpsError = 'Izin lokasi ditolak.';
        });
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _gpsError =
              'Izin lokasi ditolak permanen. Buka Settings aplikasi untuk mengizinkan lokasi.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _pos = pos;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _gpsError = 'GPS gagal: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGps = false;
        });
      }
    }
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<CameraCaptureResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _media = result;
      });
    }
  }

  double? _num(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    return double.tryParse(text);
  }

  Future<void> _saveSurvey() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kunci GPS terlebih dahulu sebelum menyimpan pengukuran.',
          ),
        ),
      );
      return;
    }

    final width = _num(_widthCtrl)!;
    final depth = _num(_depthCtrl)!;
    final surfaceVelocity = _num(_velocityCtrl)!;

    final grossHead =
        _surveyMode == 'HYDRO_POWER' ? _num(_headCtrl) : null;

    if (_surveyMode == 'HYDRO_POWER' && grossHead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Isi tinggi jatuh/head untuk survei hidro.',
          ),
        ),
      );
      return;
    }

    final result = HydroCalculator.compute(
      mode: _surveyMode,
      width: width,
      depth: depth,
      surfaceVelocity: surfaceVelocity,
      grossHead: grossHead,
    );

    final now = DateTime.now();
    final localId = 'HYD-${now.millisecondsSinceEpoch}';

    final values = <String, Object?>{
      'expedition_id': widget.expeditionId,
      'local_id': localId,
      'survey_mode': _surveyMode,
      'nama_upt': _uptCtrl.text.trim(),
      'bidang_seksi': _seksiCtrl.text.trim(),
      'waktu_survey': now.toIso8601String(),
      'nama_sungai': _sungaiCtrl.text.trim(),
      'latitude': _pos!.latitude,
      'longitude': _pos!.longitude,
      'altitude_gps': _pos!.altitude,
      'nama_penanggung_jawab': _ketuaCtrl.text.trim(),
      'nip_penanggung_jawab': _nipCtrl.text.trim(),
      'river_width_m': width,
      'depth_estimate_m': depth,
      'surface_velocity_mps': surfaceVelocity,
      'mean_velocity_mps': result['vMean'],
      'cross_section_area_sqm': result['area'],
      'discharge_cms': result['discharge'],
      'gross_head_m': grossHead,
      'net_head_m': result['netHead'],
      'power_output_kw': result['powerKw'],
      'recommended_turbine': result['turbine'],
      'sync_status': 'PENDING',
      'sync_attempts': 0,
      'last_sync_error': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    final surveyId = await _db.insertSurvey(values);

    for (final path in _media?.photoPaths ?? const <String>[]) {
      await _db.insertMedia(
        surveyId: surveyId,
        mediaType: 'PHOTO',
        localPath: path,
      );
    }

    if (_media?.videoPath != null) {
      await _db.insertMedia(
        surveyId: surveyId,
        mediaType: 'VIDEO',
        localPath: _media!.videoPath!,
      );
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengukuran tersimpan'),
        content: Text(
          '$localId\n\n'
          'Debit: ${result['discharge'].toStringAsFixed(3)} m³/s\n'
          '${result['powerKw'] == null ? '' : 'Potensi: ${result['powerKw'].toStringAsFixed(2)} kW\n'}'
          '\nData disimpan di perangkat dengan status PENDING. '
          'Tidak membutuhkan sinyal internet.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String _gpsTitle() {
    if (_loadingGps) return 'Mencari GPS...';
    if (_pos != null) return 'GPS terkunci';
    return 'GPS belum terkunci';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengukuran Baru'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'HYDRO_POWER',
                  label: Text('Mikrohidro'),
                ),
                ButtonSegment(
                  value: 'DISCHARGE_ONLY',
                  label: Text('Debit Air'),
                ),
              ],
              selected: {_surveyMode},
              onSelectionChanged: (set) {
                setState(() {
                  _surveyMode = set.first;
                });
              },
            ),

            const SizedBox(height: 16),

            _field(_uptCtrl, 'Nama UPT / Balai'),
            _field(_seksiCtrl, 'Bidang / Seksi Wilayah'),
            _field(
              _sungaiCtrl,
              'Nama Sungai / Air Terjun',
              required: true,
            ),
            _field(
              _ketuaCtrl,
              'Ketua Tim / PJ Survei',
              required: true,
            ),
            _field(_nipCtrl, 'NIP Ketua Tim'),

            const SizedBox(height: 6),

            Card(
              color: _pos != null
                  ? Colors.teal.shade50
                  : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(
                  _pos != null
                      ? Icons.location_on
                      : Icons.location_searching,
                  color: _pos != null
                      ? Colors.teal
                      : Colors.orange,
                ),
                title: Text(
                  _gpsTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _pos != null
                      ? 'Lat ${_pos!.latitude.toStringAsFixed(6)} | '
                          'Lon ${_pos!.longitude.toStringAsFixed(6)} | '
                          '${_pos!.altitude.toStringAsFixed(1)} m dpl'
                      : (_gpsError ??
                          'Tekan refresh untuk mengambil posisi.'),
                ),
                trailing: IconButton(
                  tooltip: 'Ambil GPS lagi',
                  onPressed: _loadingGps ? null : _lockGps,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Dokumentasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _media == null
                    ? 'Mulai Pengambilan Foto & Video'
                    : 'Dokumentasi: '
                        '${_media!.photoPaths.length} foto'
                        '${_media!.videoPath == null ? '' : ' + 1 video'}',
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Pengukuran Aliran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            _numberField(
              _widthCtrl,
              'Lebar sungai (m)',
            ),

            _numberField(
              _depthCtrl,
              'Kedalaman rata-rata/estimasi (m)',
            ),

            _numberField(
              _velocityCtrl,
              'Kecepatan permukaan (m/s)',
            ),

            if (_surveyMode == 'HYDRO_POWER')
              _numberField(
                _headCtrl,
                'Gross head / tinggi jatuh (m)',
              ),

            const SizedBox(height: 20),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _saveSurvey,
              icon: const Icon(Icons.save),
              label: const Text(
                'Simpan Pengukuran ke Perangkat',
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Penyimpanan lokal tidak bergantung pada sinyal. '
              'Pengukuran berikutnya dapat dilakukan beberapa jam '
              'atau beberapa hari kemudian.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty
                ? 'Wajib diisi'
                : null
            : null,
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Wajib diisi';
          }

          if (double.tryParse(
                v.replaceAll(',', '.'),
              ) ==
              null) {
            return 'Masukkan angka yang valid';
          }

          return null;
        },
      ),
    );
  }
}
