import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

/// Analisis video secara offline menggunakan segmentasi warna dan pelacakan
/// centroid. Ini bukan model AI terlatih.
class VideoFloatAnalysisScreen extends StatefulWidget {
  final String videoPath;

  const VideoFloatAnalysisScreen({super.key, required this.videoPath});

  @override
  State<VideoFloatAnalysisScreen> createState() =>
      _VideoFloatAnalysisScreenState();
}

enum MarkerColor { red, yellow, blue, green }

class _TrackPoint {
  final double seconds;
  final double x;
  final double y;

  const _TrackPoint(this.seconds, this.x, this.y);
}

class _VideoFloatAnalysisScreenState extends State<VideoFloatAnalysisScreen> {
  static const int _frameStepMs = 250;
  static const int _maxAnalysisSeconds = 20;
  static const int _thumbnailWidth = 320;

  static const MethodChannel _frameChannel =
      MethodChannel('hydro_surveyor/video_frames');

  VideoPlayerController? _videoController;
  Uint8List? _firstFrameBytes;
  img.Image? _firstFrameImage;

  final List<Offset> _calibrationTaps = <Offset>[];
  final TextEditingController _referenceLengthController =
      TextEditingController(text: '1.0');

  MarkerColor _markerColor = MarkerColor.red;
  bool _loadingVideo = true;
  bool _analyzing = false;
  double _progress = 0;
  String? _error;
  String _status = 'Menyiapkan video...';

  List<_TrackPoint> _track = <_TrackPoint>[];
  double? _velocityMps;
  double? _pixelPerMeter;
  double? _elapsedSeconds;
  double? _distanceMeters;
  int _framesDetected = 0;
  int _framesTotal = 0;

  /// Meminta Android mengekstrak frame video melalui MediaMetadataRetriever.
  Future<Uint8List?> _extractFrame(int timeMs, {int quality = 85}) async {
    try {
      return await _frameChannel.invokeMethod<Uint8List>(
        'frameAt',
        <String, Object>{
          'path': widget.videoPath,
          'timeMs': timeMs,
          'maxWidth': _thumbnailWidth,
          'quality': quality,
        },
      );
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Frame video tidak dapat diekstrak.');
    }
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception('Berkas video tidak ditemukan.');
      }

      final controller = VideoPlayerController.file(file);
      _videoController = controller;
      await controller.initialize();

      final firstBytes = await _extractFrame(0, quality: 90);
      if (firstBytes == null) {
        throw Exception('Frame awal video tidak dapat dibaca.');
      }

      final decoded = img.decodeImage(firstBytes);
      if (decoded == null) {
        throw Exception('Citra frame awal tidak dapat didekode.');
      }

      if (!mounted) return;
      setState(() {
        _firstFrameBytes = firstBytes;
        _firstFrameImage = decoded;
        _loadingVideo = false;
        _status = 'Tandai dua ujung referensi jarak pada frame awal.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVideo = false;
        _error = 'Tidak dapat menyiapkan video: $e';
      });
    }
  }

  String _colorName(MarkerColor color) {
    switch (color) {
      case MarkerColor.red:
        return 'Merah';
      case MarkerColor.yellow:
        return 'Kuning';
      case MarkerColor.blue:
        return 'Biru';
      case MarkerColor.green:
        return 'Hijau';
    }
  }

  bool _matchesColor(img.Pixel p) {
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();

    switch (_markerColor) {
      case MarkerColor.red:
        return r > 145 && r > g * 1.40 && r > b * 1.35;
      case MarkerColor.yellow:
        return r > 150 && g > 120 && b < 105 && r > b * 1.50;
      case MarkerColor.blue:
        return b > 130 && b > r * 1.30 && b > g * 1.12;
      case MarkerColor.green:
        return g > 115 && g > r * 1.18 && g > b * 1.10;
    }
  }

  /// Mencari centroid komponen warna terbesar.
  Offset? _detectLargestColorBlob(img.Image image) {
    final width = image.width;
    final height = image.height;
    final count = width * height;
    final mask = Uint8List(count);
    final visited = Uint8List(count);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_matchesColor(image.getPixel(x, y))) {
          mask[y * width + x] = 1;
        }
      }
    }

    List<int>? largest;
    final queue = List<int>.filled(count, 0, growable: false);

    for (var i = 0; i < count; i++) {
      if (mask[i] == 0 || visited[i] == 1) continue;

      var head = 0;
      var tail = 0;
      queue[tail++] = i;
      visited[i] = 1;

      var sumX = 0.0;
      var sumY = 0.0;
      final component = <int>[];

      while (head < tail) {
        final current = queue[head++];
        final x = current % width;
        final y = current ~/ width;

        component.add(current);
        sumX += x;
        sumY += y;

        final neighbors = <int>[
          if (x > 0) current - 1,
          if (x + 1 < width) current + 1,
          if (y > 0) current - width,
          if (y + 1 < height) current + width,
        ];

        for (final next in neighbors) {
          if (mask[next] == 1 && visited[next] == 0) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
      }

      if (largest == null || component.length > largest[0]) {
        largest = <int>[
          component.length,
          sumX.round(),
          sumY.round(),
        ];
      }
    }

    if (largest == null) return null;

    final area = largest[0];
    if (area < 5 || area > count * 0.12) return null;

    return Offset(largest[1] / area, largest[2] / area);
  }

  double? get _referenceLength {
    final value = double.tryParse(
      _referenceLengthController.text.trim().replaceAll(',', '.'),
    );

    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  double? _calibrationPixelsPerMeter() {
    final image = _firstFrameImage;
    final length = _referenceLength;

    if (image == null || length == null || _calibrationTaps.length != 2) {
      return null;
    }

    final dx = _calibrationTaps[1].dx - _calibrationTaps[0].dx;
    final dy = _calibrationTaps[1].dy - _calibrationTaps[0].dy;
    final pixels = math.sqrt(dx * dx + dy * dy);

    if (pixels < 8) return null;
    return pixels / length;
  }

  Future<void> _analyze() async {
    final controller = _videoController;
    final image = _firstFrameImage;
    final pxPerMeter = _calibrationPixelsPerMeter();

    if (controller == null || image == null) return;

    if (_calibrationTaps.length != 2 || pxPerMeter == null) {
      _message(
        'Tandai dua ujung referensi jarak dan masukkan panjang sebenarnya.',
      );
      return;
    }

    final fullDurationMs = controller.value.duration.inMilliseconds;
    if (fullDurationMs < 750) {
      _message('Video terlalu pendek untuk dianalisis.');
      return;
    }

    final durationMs =
        math.min(fullDurationMs, _maxAnalysisSeconds * 1000).toInt();
    final frameCount = (durationMs / _frameStepMs).floor() + 1;
    final points = <_TrackPoint>[];

    var detected = 0;
    Offset? previous;

    setState(() {
      _analyzing = true;
      _progress = 0;
      _error = null;
      _velocityMps = null;
      _track = <_TrackPoint>[];
      _status = 'Mengekstrak dan melacak frame...';
      _framesTotal = frameCount;
      _framesDetected = 0;
    });

    try {
      for (var i = 0; i < frameCount; i++) {
        if (!mounted) return;

        final timeMs = math.min(i * _frameStepMs, durationMs).toInt();
        Uint8List? bytes;

        if (timeMs == 0) {
          bytes = _firstFrameBytes;
        } else {
          bytes = await _extractFrame(timeMs, quality: 82);
        }

        if (bytes != null) {
          final decoded = timeMs == 0 ? image : img.decodeImage(bytes);

          if (decoded != null) {
            final center = _detectLargestColorBlob(decoded);

            if (center != null) {
              final maxJump = math.sqrt(
                    decoded.width * decoded.width +
                        decoded.height * decoded.height,
                  ) *
                  0.30;

              if (previous == null ||
                  (center - previous).distance <= maxJump) {
                points.add(
                  _TrackPoint(timeMs / 1000.0, center.dx, center.dy),
                );
                previous = center;
                detected++;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _progress = (i + 1) / frameCount;
            _framesDetected = detected;
            _status = 'Memproses frame ${i + 1} dari $frameCount...';
          });
        }
      }

      if (points.length < 4) {
        throw Exception(
          'Objek warna ${_colorName(_markerColor).toLowerCase()} terdeteksi '
          'pada kurang dari 4 frame. Coba pilih warna lain atau gunakan '
          'pelampung berwarna kontras dengan air.',
        );
      }

      final first = points.first;
      final last = points.last;
      final elapsed = last.seconds - first.seconds;
      final dx = last.x - first.x;
      final dy = last.y - first.y;
      final displacementPixels = math.sqrt(dx * dx + dy * dy);

      if (elapsed <= 0 || displacementPixels < 2) {
        throw Exception(
          'Perpindahan objek tidak cukup untuk menghitung kecepatan.',
        );
      }

      final distanceMeters = displacementPixels / pxPerMeter;
      final velocity = distanceMeters / elapsed;

      if (!velocity.isFinite || velocity <= 0) {
        throw Exception(
          'Hasil kecepatan tidak valid. Periksa kalibrasi video.',
        );
      }

      if (!mounted) return;

      setState(() {
        _track = points;
        _pixelPerMeter = pxPerMeter;
        _elapsedSeconds = elapsed;
        _distanceMeters = distanceMeters;
        _velocityMps = velocity;
        _framesDetected = detected;
        _analyzing = false;
        _progress = 1;
        _status =
            'Analisis selesai. Periksa lintasan dan hasil sebelum digunakan.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _analyzing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _status = 'Analisis belum berhasil.';
      });
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  void _onCalibrationTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) {
    final image = _firstFrameImage;
    if (image == null || _analyzing) return;

    final local = details.localPosition;
    final x = (local.dx / constraints.maxWidth) * image.width;
    final y = (local.dy / constraints.maxHeight) * image.height;

    setState(() {
      if (_calibrationTaps.length >= 2) {
        _calibrationTaps.clear();
      }
      _calibrationTaps.add(Offset(x, y));
      _velocityMps = null;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _referenceLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Computer Vision Aliran'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _loadingVideo
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _firstFrameImage == null
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
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
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Durasi video: '
                        '${(controller.value.duration.inMilliseconds / 1000).toStringAsFixed(2)} detik. '
                        'Analisis dibatasi $_maxAnalysisSeconds detik pertama.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      '1. Pilih warna pelampung',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MarkerColor>(
                      value: _markerColor,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Warna dominan objek',
                      ),
                      items: MarkerColor.values
                          .map(
                            (color) => DropdownMenuItem(
                              value: color,
                              child: Text(_colorName(color)),
                            ),
                          )
                          .toList(),
                      onChanged: _analyzing
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _markerColor = value;
                                _velocityMps = null;
                                _track.clear();
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '2. Kalibrasi skala pada frame awal',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ketuk dua ujung dari benda/referensi yang panjang '
                      'sebenarnya diketahui dan berada pada bidang aliran '
                      'yang sama. Untuk hasil lebih baik, referensi harus '
                      'berada pada kedalaman/perspektif yang sama dengan '
                      'lintasan objek.',
                    ),
                    const SizedBox(height: 10),
                    if (_firstFrameBytes != null && _firstFrameImage != null)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final image = _firstFrameImage!;
                          final ratio = image.width / image.height;
                          final width = constraints.maxWidth;
                          final height = width / ratio;

                          return Column(
                            children: [
                              SizedBox(
                                width: width,
                                height: height,
                                child: GestureDetector(
                                  onTapDown: (details) =>
                                      _onCalibrationTap(
                                    details,
                                    BoxConstraints(
                                      maxWidth: width,
                                      maxHeight: height,
                                    ),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        _firstFrameBytes!,
                                        fit: BoxFit.fill,
                                      ),
                                      CustomPaint(
                                        painter: _CalibrationPainter(
                                          taps: _calibrationTaps,
                                          imageWidth: image.width.toDouble(),
                                          imageHeight: image.height.toDouble(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _calibrationTaps.isEmpty
                                    ? 'Belum ada titik. Ketuk ujung pertama referensi.'
                                    : _calibrationTaps.length == 1
                                        ? 'Titik 1 tersimpan. Ketuk ujung kedua referensi.'
                                        : 'Dua titik tersimpan. Ketuk gambar lagi untuk mengulang. '
                                            'Skala: ${_calibrationPixelsPerMeter()?.toStringAsFixed(1) ?? '-'} piksel/m.',
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _referenceLengthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Panjang referensi sebenarnya (meter)',
                        hintText: 'Contoh: 1.0',
                        helperText:
                            'Masukkan panjang fisik referensi, bukan jarak lintasan pelampung.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _velocityMps = null),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _analyzing ? null : _analyze,
                      icon: const Icon(Icons.track_changes),
                      label: const Text('Deteksi dan Lacak Objek Otomatis'),
                    ),
                    if (_analyzing) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_error != null && _firstFrameImage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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
                                'Hasil pelacakan otomatis',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_velocityMps!.toStringAsFixed(3)} m/s',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.teal.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Frame dengan objek terdeteksi: '
                                '$_framesDetected dari $_framesTotal.',
                              ),
                              Text(
                                'Durasi lintasan yang terlacak: '
                                '${_elapsedSeconds!.toStringAsFixed(2)} detik.',
                              ),
                              Text(
                                'Perpindahan estimasi: '
                                '${_distanceMeters!.toStringAsFixed(3)} meter.',
                              ),
                              Text(
                                'Skala kalibrasi: '
                                '${_pixelPerMeter!.toStringAsFixed(1)} piksel/m.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Peringatan: ini estimasi kecepatan permukaan '
                                'berdasarkan centroid warna. Bayangan, '
                                'pantulan, air berbusa, perspektif, atau objek '
                                'lain dengan warna serupa dapat mengganggu '
                                'pelacakan. Validasi hasil di lapangan sebelum '
                                'digunakan menghitung debit.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop<double>(context, _velocityMps),
                        icon: const Icon(Icons.check),
                        label: const Text('Gunakan kecepatan pada survei'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop<double>(context),
                      child: const Text('Kembali tanpa menggunakan hasil'),
                    ),
                  ],
                ),
    );
  }
}

class _CalibrationPainter extends CustomPainter {
  final List<Offset> taps;
  final double imageWidth;
  final double imageHeight;

  const _CalibrationPainter({
    required this.taps,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = taps
        .map(
          (point) => Offset(
            point.dx / imageWidth * size.width,
            point.dy / imageHeight * size.height,
          ),
        )
        .toList();

    final linePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    if (points.length == 2) {
      canvas.drawLine(points[0], points[1], linePaint);
    }

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 7, dotPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, points[i] + const Offset(8, -8));
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) =>
      oldDelegate.taps != taps ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}
