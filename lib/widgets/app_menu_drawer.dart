import 'package:flutter/material.dart';

class AppMenuDrawer extends StatelessWidget {
  final VoidCallback onConnectDevices;
  final VoidCallback onSensorData;
  final VoidCallback onSavedSets;

  const AppMenuDrawer({
    super.key,
    required this.onConnectDevices,
    required this.onSensorData,
    required this.onSavedSets,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0B1220),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: Color(0xFF60A5FA)),
                  SizedBox(width: 10),
                  Text(
                    'Hercuthena',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.white70),
              title: const Text(
                'Connexion des appareils',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onConnectDevices();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sensors, color: Colors.white70),
              title: const Text(
                'Donnees capteur',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onSensorData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.white70),
              title: const Text(
                'Series sauvegardees',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onSavedSets();
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '(c) LiftTracker',
                style: TextStyle(color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
