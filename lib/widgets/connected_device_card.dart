import 'package:flutter/material.dart';
import '../models/connected_device.dart';

class ConnectedDeviceCard extends StatelessWidget {
  final ConnectedDevice device;
  final VoidCallback onDisconnect;

  const ConnectedDeviceCard({
    super.key,
    required this.device,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final type = device.type ?? 'BLE Device';
    final batteryText = device.batteryPercent == null
        ? null
        : 'Battery: ${device.batteryPercent}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withOpacity(0.25),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.bluetooth, color: Color(0xFF93C5FD)),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E), size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(type, style: const TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                if (batteryText != null)
                  Text(
                    batteryText,
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'ID: ${device.id}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF64748B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onDisconnect,
            child: const Text(
              'Disconnect',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
