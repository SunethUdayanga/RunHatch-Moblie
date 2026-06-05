import 'package:flutter/material.dart';
import 'package:runhutch/screens/splash/splash.dart';
import 'package:runhutch/services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.instance.initialize();
  runApp(const RunHutchApp());
}

class RunHutchApp extends StatelessWidget {
  const RunHutchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunHutch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
