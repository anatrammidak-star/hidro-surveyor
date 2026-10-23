import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Local video-assisted surface-velocity measurement.
///
/// This tool does not perform computer-vision object tracking. The operator
/// reviews the video, enters a measured travel distance and the elapsed time
/// between two frames/events, and the app calculates surface velocity.
class VideoFloatAnalysisScreen extends StatefulWidget {
  final String videoPath;

  const VideoFloatAnalysisScreen({
    super.key,
    required this.videoPath,
  });

  @override
  State<VideoFloatAnalysisScreen> createState() =>
      _VideoFloatAnalysisScreenState();
}

class _VideoFloatAnalysisScreenState
    extends State<VideoFloatAnalysisScreen> {
  VideoPlayerController? _controller;
  final _distanceController = TextEditingController();
  final _startController = TextEditingController(text: '0.00');
  final _endController = TextEditingController();

  bool _initializing = true;
  String? _error;
  double? _velocityMps;
  double? _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception('Berkas video tidak ditemukan.');
      }

      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _initializing = false;
        _endController.text =
            controller.value.duration.inMilliseconds / 1000.0 > 0
                ? (controller.value.duration.inMilliseconds / 1000.0)
                    .toStringAsFixed(2)
                : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Video tidak dapat dibuka: $e';
      });
    }
  }

  double? _parse(TextEditingController controller) {
    return double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
  }

  void _calculate() {
    final distance = _parse(_distanceController);
    final start = _parse(_startController);
    final end = _parse(_endController);

    if (distance == null || distance <= 0) {
      _showMessage('Masukkan jarak lintasan yang diketahui (meter), lebih dari 0.');
      return;
    }
    if (start == null || end == null || start < 0 || end <= start) {
      _showMessage('Waktu akhir harus lebih besar daripada waktu awal.');
      return;
    }

    final duration = end - start;
    final velocity = distance / duration;

    setState(() {
      _elapsedSeconds = duration;
      _velocityMps = velocity;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _seekToStart() {
    final start = _parse(_startController);
    if (start == null || start < 0) return;
    _controller?.seekTo(
      Duration(milliseconds: (start * 1000).round()),
    );
  }

  void _seekToEnd() {
    final end = _parse(_endController);
    if (end == null || end < 0) return;
    _controller?.seekTo(
      Duration(milliseconds: (end * 1000).round()),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _distanceController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Video Objek Terapung'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (controller != null &&
                        controller.value.isInitialized) ...[
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio > 0
                            ? controller.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(controller),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: controller.value.isPlaying
                                ? 'Jeda video'
                                : 'Putar video',
                            onPressed: () {
                              setState(() {
                                controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play();
                              });
                            },
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Durasi video: ${_formatDuration(controller.value.duration)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Masukkan hasil pengamatan dari video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tentukan dua titik pada lintasan objek terapung dengan jarak '
                      'yang diketahui. Catat waktu saat objek melewati titik awal '
                      'dan titik akhir dengan mengamati waktu video. Penghitungan '
                      'dilakukan di perangkat; tidak ada pengenalan objek otomatis.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _distanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Jarak lintasan diketahui (m)',
                        hintText: 'Contoh: 5.0',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _startController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Waktu saat melewati titik awal (detik)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Pindahkan video ke waktu awal',
                          onPressed: _seekToStart,
                          icon: const Icon(Icons.skip_previous),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _endController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Waktu saat melewati titik akhir (detik)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Pindahkan video ke waktu akhir',
                          onPressed: _seekToEnd,
                          icon: const Icon(Icons.skip_next),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Hitung Kecepatan Permukaan'),
                    ),
                    if (_velocityMps != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hasil pengukuran berbantuan video',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_velocityMps!.toStringAsFixed(3)} m/s',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Jarak: ${_parse(_distanceController)!.toStringAsFixed(2)} m; '
                                'waktu tempuh: ${_elapsedSeconds!.toStringAsFixed(2)} s.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ini adalah estimasi kecepatan permukaan berdasarkan '
                                'jarak dan waktu yang dimasukkan operator, bukan hasil '
                                'pelacakan AI otomatis. Periksa ulang jarak, titik lintasan, '
                                'dan waktu sebelum digunakan untuk menghitung debit.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop<double>(
                        context,
                        _velocityMps,
                      ),
                      child: Text(
                        _velocityMps == null
                            ? 'Kembali ke survei'
                            : 'Gunakan hasil dan kembali',
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)} detik';
  }
}
