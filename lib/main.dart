import 'package:flutter/material.dart';
import 'screens/mode_selection_screen.dart';

void main() {
  runApp(const NetSyncApp());
}

class NetSyncApp extends StatelessWidget {
  const NetSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ModeSelectionScreen(),
    );
  }
}
