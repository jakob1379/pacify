import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pacify/features/cadence_detector/data/services/foreground_service.dart';
import 'package:pacify/features/cadence_detector/presentation/pages/cadence_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('MyApp build');
    // Start foreground task only on Android (required for background sensor reading)
    if (Platform.isAndroid) {
      startForegroundTask();
    }
    return MaterialApp(
      title: 'Pacify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CadencePage(),
    );
  }
}

