import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_manager.dart';

class BleScanPage extends StatefulWidget {
  const BleScanPage({super.key});

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  StreamSubscription<List<ScanResult>>? _scanSub;

  bool isScanning = false;

  // Dedup by device id
  final Map<String, ScanResult> _byId = {};

  // per-device loading
  final Set<String> _connecting = {};

  @override
  void initState() {
    super.initState();

    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (!mounted) return;

        setState(() {
          for (final r in results) {
            _byId[r.device.id.id] = r;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan error: $e")),
        );
      },
    );

    startScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      _byId.clear();
      isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Start scan failed: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => isScanning = false);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    final id = device.id.id;
    if (_connecting.contains(id)) return;

    setState(() => _connecting.add(id));

    try {
      await FlutterBluePlus.stopScan();

      // ✅ Use global persistent connection
      await BleManager.I.connect(device);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Connected to ${device.name.isNotEmpty ? device.name : id}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _connecting.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _byId.values.toList()
      ..sort((a, b) {
        final an = a.device.name.isNotEmpty ? a.device.name : a.device.id.id;
        final bn = b.device.name.isNotEmpty ? b.device.name : b.device.id.id;
        return an.compareTo(bn);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Devices"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isScanning ? null : startScan,
          ),
        ],
      ),
      body: results.isEmpty
          ? Center(
              child: Text(
                isScanning ? "Scanning..." : "No BLE devices found",
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                final device = result.device;
                final id = device.id.id;

                final name = device.name.isNotEmpty ? device.name : "Unknown Device";
                final connecting = _connecting.contains(id);

                return ListTile(
                  title: Text(name),
                  subtitle: Text(id),
                  trailing: ElevatedButton(
                    onPressed: connecting ? null : () => connectToDevice(device),
                    child: connecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Connect"),
                  ),
                );
              },
            ),
    );
  }
}