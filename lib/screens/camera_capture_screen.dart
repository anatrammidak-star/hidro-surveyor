import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CapturedMedia {
  final String path;
  final String mediaType;

  const CapturedMedia({
    required this.path,
    required this.mediaType,
  });

  bool get isPhoto => mediaType.startsWith('PHOTO');

  bool get isVideo => mediaType.startsWith('VIDEO');
}

class CameraCaptureResult {
  final List<String> photoPaths;

  // Kompatibilitas dengan kode lama.
  final String? videoPath;

  // Struktur baru: sampai 3 video.
  final List<String> videoPaths;

  final List<CapturedMedia> media;

  const CameraCaptureResult({
    required this.photoPaths,
    this.videoPath,
    this.videoPaths = const [],
    this.media = const [],
  });
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
  });

  @override
  State<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState
    extends State<CameraCaptureScreen> {
  static const int maxVideoCount = 3;
  static const int maxVideoSeconds = 20;

  CameraController? _controller;

  bool _initializing = true;
  bool _recording = false;

  String? _error;

  final List<String> _photoPaths = [];
  final List<String> _videoPaths = [];
  final List<CapturedMedia> _media = [];

  String? _videoPath;

  String _selectedType = 'PHOTO_FAR';

  Timer? _recordingTimer;

  int _remainingSeconds = maxVideoSeconds;

  static const List<Map<String, String>> _mediaTypes = [
    {
      'value': 'PHOTO_FAR',
      'label': 'Foto kondisi dari jauh',
      'description':
          'Tampakkan keseluruhan air terjun/sungai dan konteks lokasi.',
    },
    {
      'value': 'PHOTO_SCALE',
      'label': 'Foto dengan orang sebagai skala',
      'description':
          'Orang berdiri di samping/bawah objek sebagai pembanding ukuran.',
    },
    {
      'value': 'PHOTO_FLOW',
      'label': 'Foto kondisi aliran',
      'description':
          'Tampakkan permukaan dan karakter aliran sungai.',
    },
    {
      'value': 'VIDEO_FLOW',
      'label': 'Video kondisi aliran',
      'description':
          'Rekam kondisi aliran dari posisi yang stabil.',
    },
    {
      'value': 'VIDEO_FLOAT',
      'label': 'Video objek terapung',
      'description':
          'Rekam benda terapung yang bergerak mengikuti arus.',
    },
    {
      'value': 'PHOTO_OTHER',
      'label': 'Foto tambahan',
      'description':
          'Dokumentasi tambahan yang dianggap penting.',
    },
    {
      'value': 'VIDEO_OTHER',
      'label': 'Video tambahan',
      'description':
          'Video tambahan untuk mendukung interpretasi lapangan.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'Kamera tidak tersedia pada perangkat.',
        );
      }

      final selected = cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error =
            '${e.code}: ${e.description ?? 'kamera gagal diinisialisasi'}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = e.toString();
      });
    }
  }

  Future<Directory> _mediaDirectory() async {
    final root =
        await getApplicationDocumentsDirectory();

    final directory = Directory(
      p.join(root.path, 'hydro_media'),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  Future<void> _takePhoto() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _recording) {
      return;
    }

    try {
      final xfile =
          await controller.takePicture();

      final directory =
          await _mediaDirectory();

      final filename =
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final target = p.join(
        directory.path,
        filename,
      );

      await File(xfile.path).copy(target);

      final captured = CapturedMedia(
        path: target,
        mediaType: _selectedType,
      );

      if (!mounted) return;

      setState(() {
        _photoPaths.add(target);
        _media.add(captured);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${_labelFor(_selectedType)} tersimpan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil foto: $e',
          ),
        ),
      );
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _recording) {
      return;
    }

    if (!_selectedType.startsWith('VIDEO')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih kategori video terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    if (_videoPaths.length >= maxVideoCount) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Maksimal 3 video sudah tercapai.',
          ),
        ),
      );
      return;
    }

    try {
      await controller.startVideoRecording();

      if (!mounted) return;

      setState(() {
        _recording = true;
        _remainingSeconds = maxVideoSeconds;
      });

      _startRecordingTimer();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memulai video: $e',
          ),
        ),
      );
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();

    _recordingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || !_recording) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds <= 1) {
          timer.cancel();
          _stopVideoRecording(
            automatic: true,
          );
          return;
        }

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  Future<void> _stopVideoRecording({
    bool automatic = false,
  }) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        !_recording) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final xfile =
          await controller.stopVideoRecording();

      final directory =
          await _mediaDirectory();

      final videoNumber =
          _videoPaths.length + 1;

      final filename =
          'video_${videoNumber}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final target = p.join(
        directory.path,
        filename,
      );

      await File(xfile.path).copy(target);

      final captured = CapturedMedia(
        path: target,
        mediaType: _selectedType,
      );

      if (!mounted) return;

      setState(() {
        _recording = false;

        _videoPaths.add(target);

        // Tetap menyediakan videoPath pertama
        // untuk kompatibilitas dengan kode lama.
        _videoPath ??= target;

        _media.add(captured);

        _remainingSeconds =
            maxVideoSeconds;
      });

      final message = automatic
          ? 'Video $videoNumber/3 otomatis berhenti setelah 20 detik.'
          : 'Video $videoNumber/3 tersimpan.';

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _recording = false;
        _remainingSeconds =
            maxVideoSeconds;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan video: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleVideo() async {
    if (_recording) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  String _labelFor(String value) {
    final item = _mediaTypes.firstWhere(
      (item) => item['value'] == value,
      orElse: () => {
        'value': value,
        'label': 'Dokumentasi',
        'description': '',
      },
    );

    return item['label']!;
  }

  String _descriptionFor(String value) {
    final item = _mediaTypes.firstWhere(
      (item) => item['value'] == value,
      orElse: () => {
        'value': value,
        'label': 'Dokumentasi',
        'description': '',
      },
    );

    return item['description']!;
  }

  IconData _iconFor(String value) {
    switch (value) {
      case 'PHOTO_FAR':
        return Icons.photo_camera;
      case 'PHOTO_SCALE':
        return Icons.accessibility;
      case 'PHOTO_FLOW':
        return Icons.water;
      case 'VIDEO_FLOW':
        return Icons.videocam;
      case 'VIDEO_FLOAT':
        return Icons.directions_boat;
      case 'PHOTO_OTHER':
        return Icons.add_a_photo;
      case 'VIDEO_OTHER':
        return Icons.video_library;
      default:
        return Icons.photo;
    }
  }

  void _finish() {
    if (_recording) return;

    Navigator.pop(
      context,
      CameraCaptureResult(
        photoPaths:
            List.unmodifiable(
          _photoPaths,
        ),
        videoPath: _videoPath,
        videoPaths:
            List.unmodifiable(
          _videoPaths,
        ),
        media:
            List.unmodifiable(
          _media,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dokumentasi Lapangan',
        ),
        backgroundColor:
            Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _initializing
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : _buildCamera(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initCamera,
              child:
                  const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return Column(
      children: [
        Expanded(
          child: _controller == null
              ? const Center(
                  child: Text(
                    'Kamera tidak siap.',
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(
                      _controller!,
                    ),

                    if (_recording)
                      _buildRecordingOverlay(),
                  ],
                ),
        ),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildRecordingOverlay() {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.black.withOpacity(
              0.75,
            ),
            borderRadius:
                BorderRadius.circular(
              30,
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                    const BoxDecoration(
                  color: Colors.red,
                  shape:
                      BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'REKAM  $_remainingSeconds',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'detik',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    final videosFull =
        _videoPaths.length >=
            maxVideoCount;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          14,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Jenis dokumentasi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection:
                    Axis.horizontal,
                itemCount:
                    _mediaTypes.length,
                separatorBuilder:
                    (_, __) =>
                        const SizedBox(
                  width: 8,
                ),
                itemBuilder:
                    (context, index) {
                  final item =
                      _mediaTypes[index];

                  final value =
                      item['value']!;

                  final selected =
                      value ==
                          _selectedType;

                  return SizedBox(
                    width: 150,
                    child: ChoiceChip(
                      selected:
                          selected,
                      onSelected:
                          _recording
                              ? null
                              : (_) {
                                  setState(
                                    () {
                                      _selectedType =
                                          value;
                                    },
                                  );
                                },
                      avatar: Icon(
                        _iconFor(
                          value,
                        ),
                        size: 20,
                      ),
                      label: Text(
                        item['label']!,
                        maxLines: 3,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(
                color:
                    Colors.teal.shade50,
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Icon(
                    _iconFor(
                      _selectedType,
                    ),
                    color:
                        Colors.teal.shade800,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          _labelFor(
                            _selectedType,
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          _descriptionFor(
                            _selectedType,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (_selectedType
                    .startsWith('VIDEO'))
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      videosFull
                          ? Colors.grey
                              .shade100
                          : Colors.orange
                              .shade50,
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: videosFull
                          ? Colors.grey
                          : Colors.orange
                              .shade800,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        videosFull
                            ? '3/3 video sudah direkam.'
                            : 'Video ${_videoPaths.length + 1}/3 — maksimum 20 detik per video.',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedType
                    .startsWith('VIDEO'))
              const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed:
                        _selectedType
                                .startsWith(
                              'PHOTO',
                            )
                            ? _takePhoto
                            : null,
                    icon: const Icon(
                      Icons.photo_camera,
                    ),
                    label: Text(
                      'Foto (${_photoPaths.length})',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      FilledButton.icon(
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          _recording
                              ? Colors.red
                              : null,
                    ),
                    onPressed:
                        _selectedType
                                    .startsWith(
                                  'VIDEO',
                                ) &&
                                (videosFull
                                    ? false
                                    : true)
                            ? _toggleVideo
                            : null,
                    icon: Icon(
                      _recording
                          ? Icons.stop
                          : Icons.videocam,
                    ),
                    label: Text(
                      _recording
                          ? 'Stop ($_remainingSeconds)'
                          : videosFull
                              ? 'Video 3/3 selesai'
                              : 'Video ${_videoPaths.length + 1}/3',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_media.length} dokumentasi | '
                    '${_videoPaths.length}/3 video',
                    style:
                        const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed:
                      _recording
                          ? null
                          : _finish,
                  child:
                      const Text('Selesai'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
