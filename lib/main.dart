import 'package:flutter/material.dart';
void main() {
  runApp(const MaterialApp(home: AccelerometerScreen()));
}

class AccelerometerScreen extends StatefulWidget {
  const AccelerometerScreen({Key? key}) : super(key: key);

  @override
  State<AccelerometerScreen> createState() => _AccelerometerScreenState();
}

class _AccelerometerScreenState extends State<AccelerometerScreen> {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;

  // TODO: Add BLE connection and data update logic here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: const Text('ACCELEROMETER DATA'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('X: ', style: TextStyle(fontSize: 18)),
                Text(x.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Y: ', style: TextStyle(fontSize: 18)),
                Text(y.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Z: ', style: TextStyle(fontSize: 18)),
                Text(z.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}