import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SurvivorsArenaApp());
}

class SurvivorsArenaApp extends StatelessWidget {
  const SurvivorsArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Survivors Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BE495),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101820),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
