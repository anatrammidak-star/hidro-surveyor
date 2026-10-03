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
  State<SurveyFormScreen> createState() =>
      _SurveyFormScreenState();
}

class _SurveyFormScreenState
    extends State<SurveyFormScreen> {
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
  bool _saving = false;

  String? _gpsError;

  CameraCaptureResult? _media;

  @override
  void initState() {
    super.initState();
    _lockGps();
  }

  @override
  void dispose() {
    for (final controller in [
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
      controller.dispose();
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
          _gpsError =
              'Layanan lokasi/GPS perangkat sedang mati.';
        });
        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        setState(() {
          _gpsError = 'Izin lokasi ditolak.';
        });
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        setState(() {
          _gpsError =
              'Izin lokasi ditolak permanen. '
              'Buka Settings aplikasi untuk mengizinkan lokasi.';
        });
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _pos = position;
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
    final result =
        await Navigator.push<CameraCaptureResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CameraCaptureScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _media = result;
      });
    }
  }

  double? _num(TextEditingController controller) {
    final text = controller.text
        .trim()
        .replaceAll(',', '.');

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  int _manualFieldCount() {
    int count = 0;

    if (_num(_widthCtrl) != null) {
      count++;
    }

    if (_num(_depthCtrl) != null) {
      count++;
    }

    if (_num(_velocityCtrl) != null) {
      count++;
    }

    if (_surveyMode == 'HYDRO_POWER' &&
        _num(_headCtrl) != null) {
      count++;
    }

    return count;
  }

  String _manualDataStatus() {
    final count = _manualFieldCount();

    if (count == 0) {
      return 'Belum ada parameter manual.';
    }

    if (count < 3) {
      return '$count dari 4 parameter manual terisi. '
          'Data masih parsial.';
    }

    if (count == 3) {
      return '3 dari 4 parameter manual terisi. '
          'Koreksi dapat dihitung pada parameter yang tersedia.';
    }

    return '4 dari 4 parameter manual terisi. '
        'Koreksi hidrologi lengkap.';
  }

  String _documentationStatus() {
    final media = _media?.media ?? [];

    if (media.isEmpty) {
      return 'INADEQUATE';
    }

    bool hasFar = false;
    bool hasScale = false;
    bool hasFlowPhoto = false;
    bool hasFlowVideo = false;

    for (final item in media) {
      switch (item.mediaType) {
        case 'PHOTO_FAR':
          hasFar = true;
          break;

        case 'PHOTO_SCALE':
          hasScale = true;
          break;

        case 'PHOTO_FLOW':
          hasFlowPhoto = true;
          break;

        case 'VIDEO_FLOW':
          hasFlowVideo = true;
          break;
      }
    }

    final coreCount = [
      hasFar,
      hasScale,
      hasFlowPhoto,
      hasFlowVideo,
    ].where((value) => value).length;

    if (coreCount >= 3) {
      return 'COMPLETE';
    }

    return 'PARTIAL';
  }

  String _confidenceLevel() {
    final documentation =
        _documentationStatus();

    final manualCount =
        _manualFieldCount();

    if (documentation == 'COMPLETE' &&
        manualCount >= 3) {
      return 'HIGH';
    }

    if (documentation == 'COMPLETE' ||
        manualCount >= 3) {
      return 'MEDIUM';
    }

    if (documentation == 'PARTIAL' ||
        manualCount > 0) {
      return 'LOW';
    }

    return 'UNASSESSED';
  }

  Future<void> _saveSurvey() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GPS harus terkunci sebelum pengukuran disimpan.',
          ),
        ),
      );
      return;
    }

    final width = _num(_widthCtrl);
    final depth = _num(_depthCtrl);
    final surfaceVelocity =
        _num(_velocityCtrl);

    final grossHead =
        _surveyMode == 'HYDRO_POWER'
            ? _num(_headCtrl)
            : null;

    final manualCount =
        _manualFieldCount();

    /*
     * Perhitungan corrected estimate.
     *
     * Debit membutuhkan:
     * - lebar
     * - kedalaman
     * - kecepatan permukaan
     *
     * Head diperlukan untuk estimasi daya.
     *
     * Kita tidak mengisi nilai visual estimate di sini.
     * Nilai visual akan berasal dari tahap prediction engine.
     */

    double? correctedDischarge;
    double? correctedHead;
    double? correctedPower;

    double? meanVelocity;
    double? crossSectionArea;

    String? recommendedTurbine;

    if (width != null &&
        depth != null &&
        surfaceVelocity != null) {
      final result =
          HydroCalculator.compute(
        mode: _surveyMode,
        width: width,
        depth: depth,
        surfaceVelocity:
            surfaceVelocity,
        grossHead: grossHead,
      );

      meanVelocity =
          result['vMean'] as double?;

      crossSectionArea =
          result['area'] as double?;

      correctedDischarge =
          result['discharge'] as double?;

      if (_surveyMode ==
              'HYDRO_POWER' &&
          grossHead != null) {
        correctedHead =
            result['netHead'] as double?;

        correctedPower =
            result['powerKw'] as double?;

        recommendedTurbine =
            result['turbine'] as String?;
      }
    }

    final now = DateTime.now();

    final localId =
        'HYD-${now.millisecondsSinceEpoch}';

    final documentationStatus =
        _documentationStatus();

    final confidence =
        _confidenceLevel();

    String estimationMethod;

    if (correctedDischarge != null) {
      if (manualCount >= 4) {
        estimationMethod =
            'MANUAL_CORRECTED';
      } else {
        estimationMethod =
            'PARTIAL_MANUAL_CORRECTED';
      }
    } else if (_media != null &&
        _media!.media.isNotEmpty) {
      estimationMethod =
          'VISUAL_DOCUMENTATION_PENDING';
    } else {
      estimationMethod =
          'INSUFFICIENT_DATA';
    }

    setState(() {
      _saving = true;
    });

    try {
      final values = <String, Object?>{
        'expedition_id':
            widget.expeditionId,

        'local_id': localId,

        'survey_mode':
            _surveyMode,

        'nama_upt':
            _uptCtrl.text.trim(),

        'bidang_seksi':
            _seksiCtrl.text.trim(),

        'waktu_survey':
            now.toIso8601String(),

        'nama_sungai':
            _sungaiCtrl.text.trim(),

        'latitude':
            _pos!.latitude,

        'longitude':
            _pos!.longitude,

        'altitude_gps':
            _pos!.altitude,

        'nama_penanggung_jawab':
            _ketuaCtrl.text.trim(),

        'nip_penanggung_jawab':
            _nipCtrl.text.trim(),

        /*
         * Parameter manual sekarang nullable.
         */
        'river_width_m':
            width,

        'depth_estimate_m':
            depth,

        'surface_velocity_mps':
            surfaceVelocity,

        'mean_velocity_mps':
            meanVelocity,

        'cross_section_area_sqm':
            crossSectionArea,

        'discharge_cms':
            correctedDischarge,

        'gross_head_m':
            grossHead,

        'net_head_m':
            correctedHead,

        'power_output_kw':
            correctedPower,

        'recommended_turbine':
            recommendedTurbine,

        /*
         * Visual prediction belum diisi.
         * Akan dikerjakan pada tahap prediction engine.
         */
        'visual_discharge_cms':
            null,

        'visual_head_m':
            null,

        'visual_power_kw':
            null,

        /*
         * Corrected estimate disimpan terpisah
         * sehingga tidak menimpa visual estimate.
         */
        'corrected_discharge_cms':
            correctedDischarge,

        'corrected_head_m':
            correctedHead,

        'corrected_power_kw':
            correctedPower,

        'estimation_method':
            estimationMethod,

        'confidence_level':
            confidence,

        'documentation_status':
            documentationStatus,

        'sync_status':
            'PENDING',

        'sync_attempts':
            0,

        'last_sync_error':
            null,

        'created_at':
            now.toIso8601String(),

        'updated_at':
            now.toIso8601String(),
      };

      final surveyId =
          await _db.insertSurvey(values);

      /*
       * Simpan seluruh media dengan kategori baru.
       */
      final media =
          _media?.media ?? [];

      if (media.isNotEmpty) {
        for (final item in media) {
          await _db.insertMedia(
            surveyId: surveyId,
            mediaType:
                item.mediaType,
            localPath:
                item.path,
          );
        }
      } else {
        /*
         * Fallback untuk kompatibilitas
         * dengan CameraCaptureResult lama.
         */
        for (final path
            in _media?.photoPaths ??
                const <String>[]) {
          await _db.insertMedia(
            surveyId: surveyId,
            mediaType: 'PHOTO_OTHER',
            localPath: path,
          );
        }

        if (_media?.videoPath != null) {
          await _db.insertMedia(
            surveyId: surveyId,
            mediaType: 'VIDEO_OTHER',
            localPath:
                _media!.videoPath!,
          );
        }
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) =>
            AlertDialog(
          title: const Text(
            'Pengukuran tersimpan',
          ),
          content: SingleChildScrollView(
            child: Text(
              '$localId\n\n'
              'Dokumentasi: '
              '$documentationStatus\n'
              'Parameter manual: '
              '$manualCount/4\n'
              'Kepercayaan: '
              '$confidence\n\n'
              '${correctedDischarge == null ? 'Prediksi visual menunggu prediction engine.' : 'Debit terkoreksi: ${correctedDischarge.toStringAsFixed(3)} m³/s\n'}'
              '${correctedPower == null ? '' : 'Daya terkoreksi: ${correctedPower.toStringAsFixed(2)} kW\n'}'
              '\nData tersimpan di perangkat dengan status PENDING. '
              'Internet tidak diperlukan untuk menyimpan survei.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan pengukuran: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _gpsTitle() {
    if (_loadingGps) {
      return 'Mencari GPS...';
    }

    if (_pos != null) {
      return 'GPS terkunci';
    }

    return 'GPS belum terkunci';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengukuran Baru',
        ),
        backgroundColor:
            Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'HYDRO_POWER',
                  label:
                      Text('Mikrohidro'),
                  icon: Icon(
                    Icons.bolt,
                  ),
                ),
                ButtonSegment(
                  value: 'DISCHARGE_ONLY',
                  label:
                      Text('Debit Air'),
                  icon: Icon(
                    Icons.water,
                  ),
                ),
              ],
              selected: {
                _surveyMode,
              },
              onSelectionChanged:
                  (set) {
                setState(() {
                  _surveyMode =
                      set.first;
                });
              },
            ),

            const SizedBox(height: 16),

            _field(
              _uptCtrl,
              'Nama UPT / Balai',
            ),

            _field(
              _seksiCtrl,
              'Bidang / Seksi Wilayah',
            ),

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

            _field(
              _nipCtrl,
              'NIP Ketua Tim',
            ),

            const SizedBox(height: 6),

            _buildGpsCard(),

            const SizedBox(height: 18),

            const Text(
              'Dokumentasi Lapangan',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Dokumentasi menjadi dasar utama untuk '
              'prediction engine. Ambil foto/video '
              'sesuai kondisi lapangan.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 10),

            _buildDocumentationCard(),

            const SizedBox(height: 18),

            const Text(
              'Parameter Hidrologi '
              '(Opsional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Isi jika data tersedia di lapangan. '
              'Pengukuran tetap dapat disimpan tanpa '
              'mengisi seluruh parameter.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 10),

            _buildManualStatus(),

            const SizedBox(height: 10),

            _numberField(
              _widthCtrl,
              'Lebar sungai (m)',
            ),

            _numberField(
              _depthCtrl,
              'Kedalaman rata-rata / estimasi (m)',
            ),

            _numberField(
              _velocityCtrl,
              'Kecepatan permukaan (m/s)',
            ),

            if (_surveyMode ==
                'HYDRO_POWER')
              _numberField(
                _headCtrl,
                'Gross head / tinggi jatuh (m)',
              ),

            const SizedBox(height: 20),

            _buildSaveButton(),

            const SizedBox(height: 10),

            const Text(
              'Data disimpan lokal terlebih dahulu. '
              'Sinkronisasi server akan dilakukan pada '
              'tahap berikutnya.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    return Card(
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
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
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
        trailing:
            IconButton(
          tooltip:
              'Ambil GPS lagi',
          onPressed: _loadingGps
              ? null
              : _lockGps,
          icon:
              const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _buildDocumentationCard() {
    final count =
        _media?.media.length ?? 0;

    final status =
        _documentationStatus();

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library,
                  color:
                      Colors.teal.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count dokumentasi tersimpan',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(
                  status,
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Dokumentasi minimum yang dianjurkan:',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              '• Foto dari jauh\n'
              '• Foto dengan orang sebagai skala\n'
              '• Foto kondisi aliran\n'
              '• Video kondisi aliran\n'
              '• Video objek terapung jika memungkinkan',
              style: TextStyle(
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: _openCamera,
                icon: const Icon(
                  Icons.camera_alt,
                ),
                label: Text(
                  count == 0
                      ? 'Mulai Dokumentasi'
                      : 'Tambah Dokumentasi',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualStatus() {
    final count =
        _manualFieldCount();

    Color color;

    if (count >= 3) {
      color = Colors.green;
    } else if (count > 0) {
      color = Colors.orange;
    } else {
      color = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            count >= 3
                ? Icons.check_circle
                : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _manualDataStatus(),
              style:
                  const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    String label;

    switch (status) {
      case 'COMPLETE':
        label = 'LENGKAP';
        break;
      case 'PARTIAL':
        label = 'PARSIAL';
        break;
      default:
        label = 'BELUM CUKUP';
    }

    return Chip(
      label: Text(
        label,
        style:
            const TextStyle(
          fontSize: 10,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style:
            FilledButton.styleFrom(
          padding:
              const EdgeInsets.all(16),
        ),
        onPressed:
            _saving ? null : _saveSurvey,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.save,
              ),
        label: Text(
          _saving
              ? 'Menyimpan...'
              : 'Simpan Pengukuran',
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
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: TextFormField(
        controller:
            controller,
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
        ),
        validator:
            required
                ? (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Wajib diisi';
                    }

                    return null;
                  }
                : null,
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: TextFormField(
        controller:
            controller,
        keyboardType:
            const TextInputType
                .numberWithOptions(
          decimal: true,
        ),
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
        ),
        validator: (value) {
          /*
           * Parameter sekarang OPSIONAL.
           * Kosong = valid.
           */
          if (value == null ||
              value.trim().isEmpty) {
            return null;
          }

          if (double.tryParse(
                value.replaceAll(
                  ',',
                  '.',
                ),
              ) ==
              null) {
            return 'Masukkan angka yang valid';
          }

          final number =
              double.tryParse(
            value.replaceAll(
              ',',
              '.',
            ),
          );

          if (number != null &&
              number < 0) {
            return 'Nilai tidak boleh negatif';
          }

          return null;
        },
      ),
    );
  }
}
