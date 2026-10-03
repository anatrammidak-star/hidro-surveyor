import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/survey_payload.dart';

class SurveyFormScreen extends StatefulWidget {
  const SurveyFormScreen({super.key});

  @override
  State<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends State<SurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _surveyMode = 'HYDRO_POWER'; // 'HYDRO_POWER' atau 'DISCHARGE_ONLY'

  final _uptCtrl = TextEditingController(text: "Balai Besar KSDA / Taman Nasional");
  final _seksiCtrl = TextEditingController(text: "Seksi Pengelolaan Wilayah II");
  final _sungaiCtrl = TextEditingController(text: "Sungai Mandiri Air");
  final _ketuaCtrl = TextEditingController(text: "Kadim Martana");
  final _nipCtrl = TextEditingController(text: "19710417xxxxxxxxxx");

  Position? _pos;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    _lockGps();
  }

  Future<void> _lockGps() async {
    setState(() => _loadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        _pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    } catch (_) {}
    setState(() => _loadingGps = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survei Hidrologi & Hidro"),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Mode Survei
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'HYDRO_POWER', label: Text("Mikrohidro (Lengkap)")),
                ButtonSegment(value: 'DISCHARGE_ONLY', label: Text("Debit Air Saja")),
              ],
              selected: {_surveyMode},
              onSelectionChanged: (set) => setState(() => _surveyMode = set.first),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _uptCtrl, decoration: const InputDecoration(labelText: "Nama UPT / Balai", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _seksiCtrl, decoration: const InputDecoration(labelText: "Bidang / Seksi Wilayah", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _sungaiCtrl, decoration: const InputDecoration(labelText: "Nama Sungai / Air Terjun", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _ketuaCtrl, decoration: const InputDecoration(labelText: "Ketua Tim / PJ Survei", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _nipCtrl, decoration: const InputDecoration(labelText: "NIP Ketua Tim", border: OutlineInputBorder())),
            const SizedBox(height: 14),
            Card(
              color: Colors.teal.shade50,
              child: ListTile(
                leading: const Icon(Icons.my_location, color: Colors.teal),
                title: Text(_pos != null ? "GPS: ${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}" : "Kunci GPS...", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(_pos != null ? "Elevasi: ${_pos!.altitude.toStringAsFixed(1)} m dpl" : "Tekan tombol untuk deteksi"),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _lockGps),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              icon: const Icon(Icons.camera_alt),
              label: Text(_surveyMode == 'HYDRO_POWER' ? "Mulai Pengambilan Foto & Video Hidro" : "Mulai Pengambilan Penampang & Arus"),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Mode Aktif: ${_surveyMode == 'HYDRO_POWER' ? 'Mikro-Minihidro' : 'Debit Air Saja'}")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
