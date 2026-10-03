import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/survey_form_screen.dart';

const String syncTaskKey = "id.go.menlhk.hydro.backgroundSync";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  } catch (_) {}
  runApp(const HydroSurveyorApp());
}

class HydroSurveyorApp extends StatelessWidget {
  const HydroSurveyorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydro & Discharge Surveyor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SurveyFormScreen(),
    );
  }
}
