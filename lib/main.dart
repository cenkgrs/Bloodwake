import 'package:flutter/material.dart';

import 'ui/screens/main_menu_screen.dart';
import 'ui/theme/bloodwake_theme.dart';

void main() {
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
