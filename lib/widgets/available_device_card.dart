import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AvailableDeviceCard extends StatelessWidget {
  final ScanResult result;
  final bool connecting;
  final VoidCallback onConnect;

  const AvailableDeviceCard({
    super.key,
    required this.result,
    required this.connecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final dev = result.device;
    final name = dev.name.trim().isNotEmpty ? dev.name.trim() : dev.id.id;

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
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${dev.id.id}',
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 4),
                Text(
                  'RSSI: ${result.rssi}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: connecting ? null : onConnect,
            child: connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Connect',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
