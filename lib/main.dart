import 'package:flutter/material.dart';

import 'ui/screens/main_menu_screen.dart';

void main() {
  runApp(const RoughlikeApp());
}

class RoughlikeApp extends StatelessWidget {
  const RoughlikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
