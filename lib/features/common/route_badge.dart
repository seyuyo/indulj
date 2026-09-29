import 'package:flutter/material.dart';

/// Színes járatjelvény (pl. sárga „4").
class RouteBadge extends StatelessWidget {
  const RouteBadge({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final int color;
  final int textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Color(color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(textColor), fontWeight: FontWeight.bold),
      ),
    );
  }
}
