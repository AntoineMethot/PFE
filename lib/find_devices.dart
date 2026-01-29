import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FindDevicesScreen extends StatefulWidget {
  const FindDevicesScreen({Key? key}) : super(key: key);

  @override
  State<FindDevicesScreen> createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  StreamSubscription<List<ScanResult>>? _scanSub;

  List<ScanResult> _results = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();

    // flutter_blue_plus 2.x: use the STATIC scan results stream
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
    }, onError: (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Scan stream error: $e')));
    });
  }

  @override
  void dispose() {
    // stop scan + cancel stream subscription
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);

    try {
      // (optional) clear previous results in UI
      setState(() => _results = []);

      // flutter_blue_plus 2.x: startScan is STATIC
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Scan error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    final name = device.name.isNotEmpty ? device.name : device.id.id;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Connecting to $name...')));

    try {
      await FlutterBluePlus.stopScan();

      // flutter_blue_plus 2.1.0: license is REQUIRED
      await device.connect(
        license: License.free, // use License.commercial if required for your org
        timeout: const Duration(seconds: 10),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connected to $name')));

      // NOTE: I removed your auto-disconnect in finally.
      // Keep the connection open; disconnect when you actually want to.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connect failed: $e')));
    }
  }

  Future<void> _disconnectFrom(BluetoothDevice device) async {
    final name = device.name.isNotEmpty ? device.name : device.id.id;

    try {
      await device.disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Disconnected from $name')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Disconnect failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Devices'),
        actions: [
          IconButton(
            icon: _isScanning ? const Icon(Icons.stop) : const Icon(Icons.search),
            onPressed: _isScanning ? _stopScan : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                ),
                const SizedBox(width: 12),
                Text('${_results.length} devices found'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                final dev = r.device;
                final name = dev.name.isNotEmpty ? dev.name : dev.id.id;

                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(name),
                  subtitle: Text('ID: ${dev.id.id} • RSSI: ${r.rssi}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        child: const Text('Connect'),
                        onPressed: () => _connectTo(dev),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        child: const Text('Disconnect'),
                        onPressed: () => _disconnectFrom(dev),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
