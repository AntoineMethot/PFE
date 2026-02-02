import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../screens/sensor_data_screen.dart';
import '../models/connected_device.dart';
import '../widgets/app_menu_drawer.dart';
import '../widgets/connected_device_card.dart';
import '../widgets/available_device_card.dart';

class ConnectDevicesScreen extends StatefulWidget {
  const ConnectDevicesScreen({super.key});
  static const routeName = '/connect-devices';

  @override
  State<ConnectDevicesScreen> createState() => _ConnectDevicesScreenState();
}

class _ConnectDevicesScreenState extends State<ConnectDevicesScreen> {
  StreamSubscription<List<ScanResult>>? _scanSub;

  bool _isScanning = false;

  // Available scan results (deduped by device id)
  final Map<String, ScanResult> _availableById = {};

  // Connected devices (by id)
  final Map<String, ConnectedDevice> _connectedById = {};

  // Track connect button loading per device id
  final Set<String> _connectingIds = {};

  @override
  void initState() {
    super.initState();

    // Listen to scan results stream (flutter_blue_plus 2.x)
    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (!mounted) return;

        setState(() {
          for (final r in results) {
            final id = r.device.id.id;

            // Don’t show devices already connected in the available list
            if (_connectedById.containsKey(id)) continue;

            _availableById[id] = r;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      },
    );
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _availableById.clear(); // optional: clear old scan list each time
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Start scan failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(ScanResult r) async {
    final dev = r.device;
    final id = dev.id.id;

    if (_connectingIds.contains(id)) return;

    setState(() => _connectingIds.add(id));

    try {
      await FlutterBluePlus.stopScan();

      await dev.connect(
        license: License.free, // required by flutter_blue_plus 2.1.0
        timeout: const Duration(seconds: 12),
      );

      if (!mounted) return;

      setState(() {
        // Move to connected section
        _connectedById[id] = ConnectedDevice(
          device: dev,
          // You can set these later when you know what it is / read battery service
          type: null,
          batteryPercent: null,
        );

        // Remove from available list
        _availableById.remove(id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${dev.name.isNotEmpty ? dev.name : id}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _connectingIds.remove(id));
    }
  }

  Future<void> _disconnect(ConnectedDevice d) async {
    final id = d.device.id.id;

    try {
      await d.device.disconnect();
    } catch (_) {
      // ignore
    }

    if (!mounted) return;

    setState(() {
      _connectedById.remove(id);
      // Optionally: move it back to available list if we still have a scan result
      // (Most apps just let it disappear until next scan)
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disconnected from ${d.displayName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedList =
        _connectedById.values.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final availableList =
        _availableById.values.toList()..sort((a, b) {
          final an = a.device.name.isNotEmpty ? a.device.name : a.device.id.id;
          final bn = b.device.name.isNotEmpty ? b.device.name : b.device.id.id;
          return an.compareTo(bn);
        });

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      endDrawer: AppMenuDrawer(
        onConnectDevices: () {}, // already on this page
        onSensorData: () {
          if (_connectedById.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connect a device first.')),
            );
            return;
          }

          final first = _connectedById.values.first;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => SensorDataScreen(
                    device: first.device,

                    // IMPORTANT: put YOUR UUIDs here:
                    imuServiceUuid: Guid(
                      "12345678-1234-1234-1234-1234567890AB",
                    ),
                    imuDataCharacteristicUuid: Guid(
                      "12345678-1234-1234-1234-1234567890AC",
                    ),
                  ),
            ),
          );
        },
      ),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.fitness_center, color: Color(0xFF60A5FA)),
            SizedBox(width: 8),
            Text('LiftTracker'),
          ],
        ),
        actions: [
          Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white70),
                    SizedBox(width: 10),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Connect Devices',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your BLE sensor connections',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
            const SizedBox(height: 22),

            // Connected Devices
            const Text(
              'Connected Devices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            if (connectedList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Text(
                    'No devices connected yet',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ...connectedList.map(
                (d) => ConnectedDeviceCard(
                  device: d,
                  onDisconnect: () => _disconnect(d),
                ),
              ),

            const SizedBox(height: 26),

            // Available Devices + Scan button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isScanning ? null : _scan,
                  icon:
                      _isScanning
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.bluetooth, size: 18),
                  label: Text(
                    _isScanning ? 'Scanning...' : 'Scan',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (availableList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Text(
                    'Click scan to discover nearby devices',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ...availableList.map(
                (r) => AvailableDeviceCard(
                  result: r,
                  connecting: _connectingIds.contains(r.device.id.id),
                  onConnect: () => _connect(r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
