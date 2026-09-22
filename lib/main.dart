import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/screens/main_menu_screen.dart';
import 'ui/theme/bloodwake_theme.dart';

import 'game/progression/meta_progression.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await MetaProgression.instance.load();
  runApp(const RoughlikeApp());
}

class RoughlikeApp extends StatelessWidget {
  const RoughlikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloodwake',
      debugShowCheckedModeBanner: false,
      theme: BloodwakeTheme.material(),
      home: const MainMenuScreen(),
    );
  }
}
