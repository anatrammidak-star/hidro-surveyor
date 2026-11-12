import 'package:flutter/material.dart';

class RepeatedMeasurementResult {
  final int count;
  final List<double> readings;
  final double average;

  const RepeatedMeasurementResult({
    required this.count,
    required this.readings,
    required this.average,
  });
}

Future<RepeatedMeasurementResult?> showRepeatedMeasurementDialog({
  required BuildContext context,
  required String title,
  double? initialValue,
}) {
  return showDialog<RepeatedMeasurementResult>(
    context: context,
    builder: (_) => RepeatedMeasurementDialog(
      title: title,
      initialValue: initialValue,
    ),
  );
}

class RepeatedMeasurementDialog extends StatefulWidget {
  final String title;
  final double? initialValue;

  const RepeatedMeasurementDialog({
    super.key,
    required this.title,
    this.initialValue,
  });

  @override
  State<RepeatedMeasurementDialog> createState() =>
      _RepeatedMeasurementDialogState();
}

class _RepeatedMeasurementDialogState
    extends State<RepeatedMeasurementDialog> {
  int _count = 1;

  late final TextEditingController _reading1Ctrl;
  late final TextEditingController _reading2Ctrl;
  late final TextEditingController _reading3Ctrl;

  String? _error;

  @override
  void initState() {
    super.initState();

    _reading1Ctrl = TextEditingController(
      text: widget.initialValue == null
          ? ''
          : widget.initialValue!.toStringAsFixed(3),
    );
    _reading2Ctrl = TextEditingController();
    _reading3Ctrl = TextEditingController();
  }

  double? _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _submit() {
    final controllers = _count == 1
        ? [_reading1Ctrl]
        : [_reading1Ctrl, _reading2Ctrl, _reading3Ctrl];

    final readings = <double>[];

    for (final controller in controllers) {
      final value = _parse(controller);

      if (value == null) {
        setState(() {
          _error = 'Semua nilai pengukuran harus diisi dengan angka yang valid.';
        });
        return;
      }

      if (!value.isFinite || value < 0) {
        setState(() {
          _error = 'Nilai pengukuran tidak boleh negatif atau tidak valid.';
        });
        return;
      }

      readings.add(value);
    }

    final average =
        readings.reduce((sum, value) => sum + value) / readings.length;

    Navigator.of(context).pop(
      RepeatedMeasurementResult(
        count: readings.length,
        readings: List<double>.unmodifiable(readings),
        average: average,
      ),
    );
  }

  @override
  void dispose() {
    _reading1Ctrl.dispose();
    _reading2Ctrl.dispose();
    _reading3Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih metode pengukuran:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 1,
                  label: Text('1 kali'),
                  icon: Icon(Icons.looks_one),
                ),
                ButtonSegment<int>(
                  value: 3,
                  label: Text('3 kali'),
                  icon: Icon(Icons.filter_3),
                ),
              ],
              selected: {_count},
              onSelectionChanged: (selection) {
                setState(() {
                  _count = selection.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              _count == 3
                  ? 'Masukkan tiga hasil pengukuran. Nilai yang digunakan aplikasi adalah rata-ratanya.'
                  : 'Masukkan satu hasil pengukuran lapangan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _measurementField(
              controller: _reading1Ctrl,
              label: 'Pengukuran 1',
              autofocus: true,
            ),
            if (_count == 3) ...[
              const SizedBox(height: 10),
              _measurementField(
                controller: _reading2Ctrl,
                label: 'Pengukuran 2',
              ),
              const SizedBox(height: 10),
              _measurementField(
                controller: _reading3Ctrl,
                label: 'Pengukuran 3',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.calculate),
          label: const Text('Gunakan hasil'),
        ),
      ],
    );
  }

  Widget _measurementField({
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) {
        if (_error != null) {
          setState(() {
            _error = null;
          });
        }
      },
    );
  }
}
