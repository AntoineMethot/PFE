import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Accelerometer App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BLEAccelerometerScreen(),
    );
  }
}

class BLEAccelerometerScreen extends StatefulWidget {

  const BLEAccelerometerScreen({super.key});

  @override
  State<BLEAccelerometerScreen> createState() => _BLEAccelerometerScreenState();
}

class _BLEAccelerometerScreenState extends State<BLEAccelerometerScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Accelerometer App'),
      ),
    );
  }
}