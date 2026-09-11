import 'package:flutter/material.dart';
import 'screens/theme_gallery_screen.dart';
import 'services/home_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.init();
  runApp(const LockForgeApp());
}

class LockForgeApp extends StatelessWidget {
  const LockForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B2FBE), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      // Landing on the gallery instead of jumping straight into a single
      // hardcoded editor session is what makes "multiple saved themes"
      // actually usable — previously there was nowhere to see or switch
      // between themes at all, only ever one in memory at a time.
      home: const ThemeGalleryScreen(),
    );
  }
}
