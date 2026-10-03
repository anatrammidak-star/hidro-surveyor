import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CameraCaptureResult {
  final List<String> photoPaths;
  final String? videoPath;

  const CameraCaptureResult({
    required this.photoPaths,
    this.videoPath,
  });
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  String? _error;
  final List<String> _photoPaths = [];
  String? _videoPath;

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
        (c) => c.lensDirection == CameraLensDirection.back,
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
    final root = await getApplicationDocumentsDirectory();

    final dir = Directory(
      p.join(root.path, 'hydro_media'),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<void> _takePhoto() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _recording) {
      return;
    }

    try {
      final xfile = await controller.takePicture();

      final dir = await _mediaDirectory();

      final filename =
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final target = p.join(
        dir.path,
        filename,
      );

      await File(xfile.path).copy(target);

      if (!mounted) return;

      setState(() {
        _photoPaths.add(target);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Foto tersimpan (${_photoPaths.length})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil foto: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleVideo() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      if (!_recording) {
        await controller.startVideoRecording();

        if (mounted) {
          setState(() {
            _recording = true;
          });
        }
      } else {
        final xfile =
            await controller.stopVideoRecording();

        final dir = await _mediaDirectory();

        final filename =
            'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final target = p.join(
          dir.path,
          filename,
        );

        await File(xfile.path).copy(target);

        if (!mounted) return;

        setState(() {
          _recording = false;
          _videoPath = target;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video tersimpan.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _recording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal merekam video: $e',
          ),
        ),
      );
    }
  }

  void _finish() {
    if (_recording) return;

    Navigator.pop(
      context,
      CameraCaptureResult(
        photoPaths: List.unmodifiable(
          _photoPaths,
        ),
        videoPath: _videoPath,
      ),
    );
  }

  @override
  void dispose() {
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
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _initializing
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _initCamera,
                          child: const Text(
                            'Coba Lagi',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _controller == null
                          ? const Center(
                              child: Text(
                                'Kamera tidak siap.',
                              ),
                            )
                          : CameraPreview(
                              _controller!,
                            ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        16,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child:
                                    FilledButton.icon(
                                  onPressed: _takePhoto,
                                  icon: const Icon(
                                    Icons.photo_camera,
                                  ),
                                  label: Text(
                                    'Foto (${_photoPaths.length})',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                      _toggleVideo,
                                  icon: Icon(
                                    _recording
                                        ? Icons.stop
                                        : Icons.videocam,
                                  ),
                                  label: Text(
                                    _recording
                                        ? 'Stop Video'
                                        : 'Video',
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
                                  _videoPath == null
                                      ? 'Belum ada video'
                                      : 'Video siap disimpan',
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _recording
                                    ? null
                                    : _finish,
                                child: const Text(
                                  'Selesai',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
