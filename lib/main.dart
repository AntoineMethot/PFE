import 'package:flutter/material.dart';
import 'find_devices.dart';
import 'sensor_data.dart';

void main() {
  runApp(const MaterialApp(home: AccelerometerScreen()));
}

class AccelerometerScreen extends StatefulWidget {
  const AccelerometerScreen({Key? key}) : super(key: key);

  @override
  State<AccelerometerScreen> createState() => _AccelerometerScreenState();
}

class _AccelerometerScreenState extends State<AccelerometerScreen> {
  // accelerometer values
  double ax = 0.0;
  double ay = 0.0;
  double az = 0.0;
  // gyroscope values
  double gx = 0.0;
  double gy = 0.0;
  double gz = 0.0;

  @override
  void initState() {
    super.initState();
    SensorData.instance.addListener(_onSensorUpdate);
  }

  void _onSensorUpdate() {
    final s = SensorData.instance;
    setState(() {
      ax = s.ax;
      ay = s.ay;
      az = s.az;
      gx = s.gx;
      gy = s.gy;
      gz = s.gz;
    });
  }

  @override
  void dispose() {
    SensorData.instance.removeListener(_onSensorUpdate);
    super.dispose();
  }

  // TODO: Add BLE connection and data update logic here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: const Text('Find Devices'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FindDevicesScreen(),
                ));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: const Text('SENSOR DATA'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Accelerometer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('AX: ', style: TextStyle(fontSize: 18)),
                Text(ax.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 24),
                const Text('AY: ', style: TextStyle(fontSize: 18)),
                Text(ay.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 24),
                const Text('AZ: ', style: TextStyle(fontSize: 18)),
                Text(az.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Gyroscope', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('GX: ', style: TextStyle(fontSize: 18)),
                Text(gx.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 24),
                const Text('GY: ', style: TextStyle(fontSize: 18)),
                Text(gy.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 24),
                const Text('GZ: ', style: TextStyle(fontSize: 18)),
                Text(gz.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}