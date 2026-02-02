import 'package:flutter/material.dart';

class MuscleChip extends StatelessWidget {
  final String label;

  const MuscleChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF).withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF93C5FD),
        ),
      ),
    );
  }
}
