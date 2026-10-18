import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/expedition_screen.dart';

const String syncTaskKey = 'id.go.menlhk.hydro.backgroundSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Sinkronisasi data survei akan ditambahkan pada tahap berikutnya.
    // SQLite tetap menjadi penyimpanan lokal dan antrean offline.
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase hanya jika URL dan Publishable Key tersedia.
  // Jika belum tersedia atau koneksi gagal, aplikasi tetap dapat dibuka.
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    } catch (e) {
      debugPrint('Inisialisasi Supabase gagal: $e');
    }
  }

  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (e) {
    debugPrint('Inisialisasi Workmanager gagal: $e');
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
