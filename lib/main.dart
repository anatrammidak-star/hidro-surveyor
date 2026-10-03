import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/expedition_screen.dart';

const String syncTaskKey = 'id.go.menlhk.hydro.backgroundSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Tahap berikutnya: panggil SyncService untuk mengirim record PENDING.
    // Database lokal menjadi sumber antrean.
    // Tidak ada data yang dihapus hanya karena perangkat sedang offline.
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (_) {
    // WorkManager tidak boleh menghalangi aplikasi survei offline.
  }

  runApp(const HydroSurveyorApp());
}

class HydroSurveyorApp extends StatelessWidget {
  const HydroSurveyorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroSurveyor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const ExpeditionScreen(),
    );
  }
}
