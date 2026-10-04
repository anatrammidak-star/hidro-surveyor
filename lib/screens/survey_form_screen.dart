import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
  bool _saving = false;

  String? _gpsError;

  CameraCaptureResult? _media;
  final List<CapturedMedia> _uploadedMedia = [];

  // ---------------------------------------------------------------------------
  // FIELD CORRECTION PROFILE
  // ---------------------------------------------------------------------------

  double _surfaceVelocityFactor = 0.85;
  double _headLossFactor = 0.92;
  double _turbineEfficiency = 0.78;

  String _correctionProfile = 'DEFAULT';

  static const List<double> _velocityFactors = [
    0.80,
    0.85,
    0.90,
  ];

  static const List<double> _headLossFactors = [
    0.85,
    0.92,
    0.95,
  ];

  static const List<double> _turbineEfficiencies = [
    0.60,
    0.70,
    0.78,
    0.80,
    0.85,
  ];

  // ---------------------------------------------------------------------------
  // AI STATE
  //
  // Prediction engine belum diaktifkan pada versi ini. Form sengaja hanya
  // menyiapkan kontrak data AI dan tidak membuat angka prediksi palsu.
  // ---------------------------------------------------------------------------

  String _aiStatus = 'NOT_ANALYZED';
  String _aiModelVersion = 'NOT_CONNECTED';
  double? _aiQualityScore;
  DateTime? _aiProcessedAt;
  String? _aiNotes;

  // AI ranges: null sampai prediction engine benar-benar menghasilkan nilai.
  double? _visualDischargeMin;
  double? _visualDischargeBest;
  double? _visualDischargeMax;

  double? _visualHeadMin;
  double? _visualHeadBest;
  double? _visualHeadMax;

  double? _visualPowerMin;
  double? _visualPowerBest;
  double? _visualPowerMax;

  @override
  void initState() {
    super.initState();

    _lockGps();

    for (final controller in [
      _widthCtrl,
      _depthCtrl,
      _velocityCtrl,
      _headCtrl,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
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

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------

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

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _gpsError = 'Izin lokasi ditolak.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError =
              'Izin lokasi ditolak permanen. '
              'Buka Settings aplikasi untuk mengizinkan lokasi.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
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

  // ---------------------------------------------------------------------------
  // CAMERA
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // UPLOAD / IMPORT MEDIA
  // ---------------------------------------------------------------------------

  Future<void> _openMediaPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final mediaRoot = Directory(
        path.join(appDir.path, 'hydro_surveyor_media'),
      );

      if (!await mediaRoot.exists()) {
        await mediaRoot.create(recursive: true);
      }

      int imported = 0;

      for (final picked in result.files) {
        final sourcePath = picked.path;
        if (sourcePath == null || sourcePath.isEmpty) continue;

        final extension =
            path.extension(sourcePath).toLowerCase();
        final isVideo = _isVideoExtension(extension);

        final destination = path.join(
          mediaRoot.path,
          '${DateTime.now().microsecondsSinceEpoch}_'
          '${_safeFileName(picked.name)}',
        );

        await File(sourcePath).copy(destination);

        _uploadedMedia.add(
          CapturedMedia(
            path: destination,
            mediaType:
                isVideo ? 'VIDEO_OTHER' : 'PHOTO_OTHER',
          ),
        );

        imported++;
      }

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$imported file berhasil diimpor dan disalin '
            'ke penyimpanan HydroSurveyor.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengimpor media: $e'),
        ),
      );
    }
  }

  bool _isVideoExtension(String extension) {
    const extensions = {
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
      '.3gp',
    };
    return extensions.contains(extension);
  }

  String _safeFileName(String value) {
    return value.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
  }

  List<CapturedMedia> _allMedia() {
    return [
      ...(_media?.media ?? const <CapturedMedia>[]),
      ..._uploadedMedia,
    ];
  }

  Future<void> _chooseUploadedMediaType(
    CapturedMedia item,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final isVideo = item.mediaType.startsWith('VIDEO');

        final options = isVideo
            ? const [
                ['VIDEO_FLOW', 'Video kondisi aliran'],
                ['VIDEO_FLOAT', 'Video objek terapung'],
                ['VIDEO_OTHER', 'Video lainnya'],
              ]
            : const [
                ['PHOTO_FAR', 'Foto dari jauh'],
                ['PHOTO_SCALE', 'Foto dengan orang sebagai skala'],
                ['PHOTO_FLOW', 'Foto kondisi aliran'],
                ['PHOTO_OTHER', 'Foto lainnya'],
              ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Kategori media',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(
                    isVideo ? Icons.videocam : Icons.photo,
                  ),
                  title: Text(option[1]),
                  onTap: () => Navigator.pop(context, option[0]),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    final index = _uploadedMedia.indexOf(item);
    if (index < 0) return;

    setState(() {
      _uploadedMedia[index] = CapturedMedia(
        path: item.path,
        mediaType: selected,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // BASIC PARSING
  // ---------------------------------------------------------------------------

  double? _num(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');

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

  int get _manualMaximum {
    return _surveyMode == 'HYDRO_POWER' ? 4 : 3;
  }

  String _manualDataStatus() {
    final count = _manualFieldCount();
    final max = _manualMaximum;

    if (count == 0) {
      return 'Belum ada parameter manual.';
    }

    if (count < 3) {
      return '$count dari $max parameter manual terisi. '
          'Data masih parsial.';
    }

    if (count == 3 && max == 4) {
      return '3 dari 4 parameter manual terisi. '
          'Koreksi debit dapat dihitung; head masih diperlukan '
          'untuk estimasi daya.';
    }

    return '$count dari $max parameter manual terisi. '
        'Data lapangan memadai untuk koreksi.';
  }

  String _precisionLevel() {
    final count = _manualFieldCount();

    if (count >= 4) {
      return 'PRECISION_ESTIMATION';
    }

    if (count >= 3) {
      return 'FIELD_CORRECTED';
    }

    if (count > 0) {
      return 'PARTIAL_CORRECTION';
    }

    return 'AI_ONLY';
  }

  // ---------------------------------------------------------------------------
  // DOCUMENTATION
  // ---------------------------------------------------------------------------

  String _documentationStatus() {
    final media = _allMedia();

    if (media.isEmpty) {
      return 'INADEQUATE';
    }

    bool hasFar = false;
    bool hasScale = false;
    bool hasFlowPhoto = false;
    bool hasFlowVideo = false;
    bool hasFloatVideo = false;

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

        case 'VIDEO_FLOAT':
          hasFloatVideo = true;
          break;
      }
    }

    final coreCount = [
      hasFar,
      hasScale,
      hasFlowPhoto,
      hasFlowVideo,
    ].where((value) => value).length;

    if (coreCount >= 3 || hasFloatVideo) {
      return 'COMPLETE';
    }

    return 'PARTIAL';
  }

  int _aiEvidenceCount() {
    return _allMedia().length;
  }

  String _confidenceLevel() {
    // Jangan mengklaim confidence AI sebelum prediction engine menghasilkan
    // quality score/model output yang nyata.
    if (_aiStatus == 'ANALYZED') {
      if (_aiQualityScore != null) {
        if (_aiQualityScore! >= 0.80) {
          return 'HIGH';
        }

        if (_aiQualityScore! >= 0.60) {
          return 'MEDIUM';
        }

        return 'LOW';
      }

      return 'UNASSESSED';
    }

    return 'UNASSESSED';
  }

  // ---------------------------------------------------------------------------
  // CORRECTION ENGINE
  //
  // Ini bukan AI.
  // Ini physics-based field correction menggunakan parameter lapangan.
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _calculateFieldCorrection({
    required double? width,
    required double? depth,
    required double? surfaceVelocity,
    required double? grossHead,
  }) {
    double? area;
    double? meanVelocity;
    double? discharge;
    double? netHead;
    double? powerKw;
    String? turbine;

    if (width != null &&
        depth != null &&
        surfaceVelocity != null) {
      // Faktor 0.75 mempertahankan pendekatan area efektif yang digunakan
      // pada kalkulator versi sebelumnya.
      area = width * depth * 0.75;

      meanVelocity =
          surfaceVelocity * _surfaceVelocityFactor;

      discharge = area * meanVelocity;
    }

    if (_surveyMode == 'HYDRO_POWER' &&
        grossHead != null) {
      netHead = grossHead * _headLossFactor;

      if (discharge != null) {
        powerKw =
            9.81 *
            discharge *
            netHead *
            _turbineEfficiency;

        turbine = _recommendTurbine(
          netHead: netHead,
          discharge: discharge,
        );
      }
    }

    return {
      'area': area,
      'meanVelocity': meanVelocity,
      'discharge': discharge,
      'netHead': netHead,
      'powerKw': powerKw,
      'turbine': turbine,
    };
  }

  String _recommendTurbine({
    required double netHead,
    required double discharge,
  }) {
    if (netHead > 50) {
      return 'Pelton / Turgo';
    }

    if (netHead >= 15) {
      return discharge > 1.2
          ? 'Francis'
          : 'Turgo / Crossflow';
    }

    if (netHead >= 3) {
      return discharge > 0.6
          ? 'Kaplan / Propeller'
          : 'Crossflow';
    }

    return 'Archimedes Screw / Vortex';
  }

  String _factorProfileName() {
    if (_surfaceVelocityFactor == 0.85 &&
        _headLossFactor == 0.92 &&
        _turbineEfficiency == 0.78) {
      return 'DEFAULT';
    }

    if (_surfaceVelocityFactor == 0.80 &&
        _headLossFactor == 0.85) {
      return 'CONSERVATIVE';
    }

    if (_surfaceVelocityFactor == 0.90 &&
        _headLossFactor == 0.95) {
      return 'OPTIMISTIC';
    }

    return 'CUSTOM';
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

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
    final surfaceVelocity = _num(_velocityCtrl);

    final grossHead =
        _surveyMode == 'HYDRO_POWER'
            ? _num(_headCtrl)
            : null;

    final manualCount = _manualFieldCount();

    final correction = _calculateFieldCorrection(
      width: width,
      depth: depth,
      surfaceVelocity: surfaceVelocity,
      grossHead: grossHead,
    );

    final area = correction['area'] as double?;
    final meanVelocity =
        correction['meanVelocity'] as double?;
    final correctedDischarge =
        correction['discharge'] as double?;
    final correctedHead =
        correction['netHead'] as double?;
    final correctedPower =
        correction['powerKw'] as double?;
    final recommendedTurbine =
        correction['turbine'] as String?;

    // Range corrected sengaja tidak dibuat-buat.
    // Sampai ada uncertainty/calibration engine, best estimate saja yang
    // disimpan. Kolom min/max tetap NULL.
    final correctedDischargeMin = <double?>[null].first;
    final correctedDischargeBest = correctedDischarge;
    final correctedDischargeMax = <double?>[null].first;

    final correctedHeadMin = <double?>[null].first;
    final correctedHeadBest = correctedHead;
    final correctedHeadMax = <double?>[null].first;

    final correctedPowerMin = <double?>[null].first;
    final correctedPowerBest = correctedPower;
    final correctedPowerMax = <double?>[null].first;

    final now = DateTime.now();

    final localId =
        'HYD-${now.millisecondsSinceEpoch}';

    final documentationStatus =
        _documentationStatus();

    final confidence =
        _confidenceLevel();

    final precisionLevel =
        _precisionLevel();

    final correctionProfile =
        _factorProfileName();

    _correctionProfile = correctionProfile;

    String estimationMethod;

    if (_aiStatus == 'ANALYZED' &&
        _visualDischargeBest != null) {
      estimationMethod =
          manualCount > 0
              ? 'AI_WITH_FIELD_CORRECTION'
              : 'AI_VISUAL';
    } else if (correctedDischarge != null) {
      if (manualCount >= 4) {
        estimationMethod = 'FIELD_CORRECTED';
      } else {
        estimationMethod = 'PARTIAL_FIELD_CORRECTION';
      }
    } else if (_aiEvidenceCount() > 0) {
      estimationMethod = 'AI_PENDING';
    } else {
      estimationMethod = 'INSUFFICIENT_DATA';
    }

    setState(() {
      _saving = true;
    });

    try {
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

        'nama_penanggung_jawab':
            _ketuaCtrl.text.trim(),
        'nip_penanggung_jawab':
            _nipCtrl.text.trim(),

        // FIELD INPUT
        'river_width_m': width,
        'depth_estimate_m': depth,
        'surface_velocity_mps':
            surfaceVelocity,

        // FIELD PHYSICS RESULT
        'mean_velocity_mps': meanVelocity,
        'cross_section_area_sqm': area,
        'discharge_cms': correctedDischarge,

        'gross_head_m': grossHead,
        'net_head_m': correctedHead,
        'power_output_kw': correctedPower,
        'recommended_turbine':
            recommendedTurbine,

        // AI / VISUAL RANGE
        'visual_discharge_min':
            _visualDischargeMin,
        'visual_discharge_best':
            _visualDischargeBest,
        'visual_discharge_max':
            _visualDischargeMax,

        'visual_head_min':
            _visualHeadMin,
        'visual_head_best':
            _visualHeadBest,
        'visual_head_max':
            _visualHeadMax,

        'visual_power_min':
            _visualPowerMin,
        'visual_power_best':
            _visualPowerBest,
        'visual_power_max':
            _visualPowerMax,

        // FIELD-CORRECTED RANGE
        'corrected_discharge_min':
            correctedDischargeMin,
        'corrected_discharge_best':
            correctedDischargeBest,
        'corrected_discharge_max':
            correctedDischargeMax,

        'corrected_head_min':
            correctedHeadMin,
        'corrected_head_best':
            correctedHeadBest,
        'corrected_head_max':
            correctedHeadMax,

        'corrected_power_min':
            correctedPowerMin,
        'corrected_power_best':
            correctedPowerBest,
        'corrected_power_max':
            correctedPowerMax,

        // CORRECTION FACTORS
        'surface_velocity_factor':
            _surfaceVelocityFactor,
        'head_loss_factor':
            _headLossFactor,
        'turbine_efficiency':
            _turbineEfficiency,
        'correction_profile':
            _correctionProfile,

        // AI METADATA
        'ai_status': _aiStatus,
        'ai_model_version':
            _aiModelVersion,
        'ai_quality_score':
            _aiQualityScore,
        'ai_processed_at':
            _aiProcessedAt?.toIso8601String(),
        'ai_notes': _aiNotes,
        'ai_evidence_count':
            _aiEvidenceCount(),
        'reference_used':
            manualCount > 0 ? 1 : 0,

        'precision_level':
            precisionLevel,

        'estimation_method':
            estimationMethod,
        'confidence_level':
            confidence,
        'documentation_status':
            documentationStatus,

        'sync_status': 'PENDING',
        'sync_attempts': 0,
        'last_sync_error': null,

        'created_at':
            now.toIso8601String(),
        'updated_at':
            now.toIso8601String(),
      };

      final surveyId =
          await _db.insertSurvey(values);

      final media = _allMedia();

      if (media.isNotEmpty) {
        for (final item in media) {
          await _db.insertMedia(
            surveyId: surveyId,
            mediaType: item.mediaType,
            localPath: item.path,
          );
        }
      } else {
        // Fallback kompatibilitas dengan CameraCaptureResult lama.
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
        builder: (context) => AlertDialog(
          title: const Text(
            'Pengukuran tersimpan',
          ),
          content: SingleChildScrollView(
            child: Text(
              '$localId\n\n'
              'Dokumentasi: '
              '$documentationStatus\n'
              'Parameter lapangan: '
              '$manualCount/$_manualMaximum\n'
              'Precision level: '
              '$precisionLevel\n'
              'AI status: '
              '$_aiStatus\n\n'
              '${correctedDischarge == null ? 'Debit AI belum dianalisis dan data lapangan belum cukup untuk menghitung debit.' : 'Debit terkoreksi: ${correctedDischarge.toStringAsFixed(3)} m³/s\n'}'
              '${correctedHead == null ? '' : 'Net head terkoreksi: ${correctedHead.toStringAsFixed(2)} m\n'}'
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

      ScaffoldMessenger.of(context).showSnackBar(
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

  // ---------------------------------------------------------------------------
  // GPS UI
  // ---------------------------------------------------------------------------

  String _gpsTitle() {
    if (_loadingGps) {
      return 'Mencari GPS...';
    }

    if (_pos != null) {
      return 'GPS terkunci';
    }

    return 'GPS belum terkunci';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

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
                  label: Text('Mikrohidro'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: 'DISCHARGE_ONLY',
                  label: Text('Debit Air'),
                  icon: Icon(Icons.water),
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
              'Foto dan video menjadi evidence utama '
              'untuk prediction engine. Jangan menganggap '
              'angka AI tersedia sebelum engine benar-benar '
              'memproses media.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 10),

            _buildDocumentationCard(),

            const SizedBox(height: 18),

            _buildAiPredictionCard(),

            const SizedBox(height: 18),

            const Text(
              'Field Correction (Opsional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Parameter lapangan digunakan untuk '
              'memvalidasi atau mengoreksi prediksi AI. '
              'Tidak wajib diisi agar survei dapat disimpan.',
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

            const SizedBox(height: 10),

            _buildCorrectionFactorCard(),

            const SizedBox(height: 18),

            _buildResultPreview(),

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

  // ---------------------------------------------------------------------------
  // GPS CARD
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // DOCUMENTATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildDocumentationCard() {
    final allMedia = _allMedia();
    final count = allMedia.length;

    final status =
        _documentationStatus();

    final videoCount = allMedia
        .where(
          (item) =>
              item.mediaType == 'VIDEO_FLOW' ||
              item.mediaType == 'VIDEO_FLOAT' ||
              item.mediaType == 'VIDEO_OTHER',
        )
        .length;

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
                _statusChip(status),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              'Evidence AI: ${_aiEvidenceCount()} file',
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Video: $videoCount file',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openMediaPicker,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),

            if (_uploadedMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Media dari perangkat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._uploadedMedia.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.mediaType.startsWith('VIDEO')
                        ? Icons.videocam
                        : Icons.photo,
                  ),
                  title: Text(
                    path.basename(item.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.mediaType,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'Ubah kategori',
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () =>
                        _chooseUploadedMediaType(item),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI CARD
  // ---------------------------------------------------------------------------

  Widget _buildAiPredictionCard() {
    final analyzed =
        _aiStatus == 'ANALYZED';

    return Card(
      elevation: 1,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
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
                    'AI Prediction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                _aiStatusChip(),
              ],
            ),

            const SizedBox(height: 10),

            if (!analyzed) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.indigo.withOpacity(0.06),
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        Colors.indigo.withOpacity(0.20),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belum dianalisis',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Prediction engine AI belum terhubung '
                      'pada build ini. Tidak ada angka debit, '
                      'head, atau daya yang dibuat secara '
                      'heuristik dari foto/video.',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildRangeRow(
                'Debit',
                _visualDischargeMin,
                _visualDischargeBest,
                _visualDischargeMax,
                'm³/s',
              ),
              _buildRangeRow(
                'Head',
                _visualHeadMin,
                _visualHeadBest,
                _visualHeadMax,
                'm',
              ),
              _buildRangeRow(
                'Daya',
                _visualPowerMin,
                _visualPowerBest,
                _visualPowerMax,
                'kW',
              ),
            ],

            const SizedBox(height: 10),

            _infoRow(
              'Model',
              _aiModelVersion,
            ),
            _infoRow(
              'Evidence',
              '${_aiEvidenceCount()} file',
            ),
            _infoRow(
              'Confidence',
              _confidenceLevel(),
            ),
            _infoRow(
              'Precision level',
              _precisionLevel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiStatusChip() {
    String label;
    Color color;

    switch (_aiStatus) {
      case 'ANALYZED':
        label = 'DIANALISIS';
        color = Colors.green;
        break;

      case 'PROCESSING':
        label = 'MEMPROSES';
        color = Colors.orange;
        break;

      case 'FAILED':
        label = 'GAGAL';
        color = Colors.red;
        break;

      default:
        label = 'MENUNGGU AI';
        color = Colors.grey;
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
      side: BorderSide(
        color:
            color.withOpacity(0.35),
      ),
    );
  }

  Widget _buildRangeRow(
    String label,
    double? min,
    double? best,
    double? max,
    String unit,
  ) {
    if (min == null &&
        best == null &&
        max == null) {
      return _infoRow(
        label,
        'Belum tersedia',
      );
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${_formatNumber(min)} – '
              '${_formatNumber(best)} – '
              '${_formatNumber(max)} $unit',
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '-';
    }

    return value.toStringAsFixed(2);
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FIELD CORRECTION STATUS
  // ---------------------------------------------------------------------------

  Widget _buildManualStatus() {
    final count =
        _manualFieldCount();

    Color color;
    IconData icon;

    if (count >= 4) {
      color = Colors.green;
      icon = Icons.verified;
    } else if (count >= 3) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (count > 0) {
      color = Colors.orange;
      icon = Icons.info_outline;
    } else {
      color = Colors.grey;
      icon = Icons.auto_awesome;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              color.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _precisionLevel(),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _manualDataStatus(),
                  style:
                      const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CORRECTION FACTORS
  // ---------------------------------------------------------------------------

  Widget _buildCorrectionFactorCard() {
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.tune,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Faktor Koreksi',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _correctionProfile,
                    style:
                        const TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Faktor ini hanya digunakan untuk '
              'field correction/physics engine. '
              'Bukan faktor AI.',
              style: TextStyle(
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 10),

            _buildDropdown<double>(
              label:
                  'Faktor kecepatan permukaan',
              value:
                  _surfaceVelocityFactor,
              items:
                  _velocityFactors,
              itemLabel:
                  (value) =>
                      value.toStringAsFixed(2),
              onChanged:
                  (value) {
                if (value == null) return;

                setState(() {
                  _surfaceVelocityFactor =
                      value;
                  _correctionProfile =
                      _factorProfileName();
                });
              },
            ),

            const SizedBox(height: 8),

            _buildDropdown<double>(
              label:
                  'Faktor kehilangan head',
              value:
                  _headLossFactor,
              items:
                  _headLossFactors,
              itemLabel:
                  (value) =>
                      value.toStringAsFixed(2),
              onChanged:
                  (value) {
                if (value == null) return;

                setState(() {
                  _headLossFactor =
                      value;
                  _correctionProfile =
                      _factorProfileName();
                });
              },
            ),

            const SizedBox(height: 8),

            _buildDropdown<double>(
              label:
                  'Efisiensi turbin',
              value:
                  _turbineEfficiency,
              items:
                  _turbineEfficiencies,
              itemLabel:
                  (value) =>
                      '${(value * 100).round()}%',
              onChanged:
                  (value) {
                if (value == null) return;

                setState(() {
                  _turbineEfficiency =
                      value;
                  _correctionProfile =
                      _factorProfileName();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration:
          InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
        isDense: true,
      ),
      items:
          items.map(
        (item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel(item),
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }

  // ---------------------------------------------------------------------------
  // RESULT PREVIEW
  // ---------------------------------------------------------------------------

  Widget _buildResultPreview() {
    final width = _num(_widthCtrl);
    final depth = _num(_depthCtrl);
    final velocity =
        _num(_velocityCtrl);

    final head =
        _surveyMode ==
                'HYDRO_POWER'
            ? _num(_headCtrl)
            : null;

    final result =
        _calculateFieldCorrection(
      width: width,
      depth: depth,
      surfaceVelocity:
          velocity,
      grossHead: head,
    );

    final discharge =
        result['discharge'] as double?;
    final netHead =
        result['netHead'] as double?;
    final power =
        result['powerKw'] as double?;
    final turbine =
        result['turbine'] as String?;

    if (discharge == null &&
        netHead == null &&
        power == null) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hasil field correction akan '
                  'muncul setelah parameter yang '
                  'diperlukan tersedia.',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
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
                Text(
                  'Field Correction Result',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (discharge != null)
              _resultRow(
                'Debit',
                '${discharge.toStringAsFixed(3)} m³/s',
              ),

            if (netHead != null)
              _resultRow(
                'Net head',
                '${netHead.toStringAsFixed(2)} m',
              ),

            if (power != null)
              _resultRow(
                'Daya',
                '${power.toStringAsFixed(2)} kW',
              ),

            if (turbine != null)
              _resultRow(
                'Turbine',
                turbine,
              ),

            const SizedBox(height: 8),

            const Text(
              'Catatan: hasil ini merupakan physics-based '
              'field correction, bukan hasil AI.',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE BUTTON
  // ---------------------------------------------------------------------------

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
            _saving
                ? null
                : _saveSurvey,
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

  // ---------------------------------------------------------------------------
  // STATUS CHIP
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // GENERAL FIELD
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // NUMBER FIELD
  // ---------------------------------------------------------------------------

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
          if (value == null ||
              value.trim().isEmpty) {
            return null;
          }

          final number =
              double.tryParse(
            value.replaceAll(
              ',',
              '.',
            ),
          );

          if (number == null) {
            return 'Masukkan angka yang valid';
          }

          if (number < 0) {
            return 'Nilai tidak boleh negatif';
          }

          return null;
        },
      ),
    );
  }
}
