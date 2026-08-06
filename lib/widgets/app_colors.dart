import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF18BE98);
  static const primaryDark = Color(0xFF079C84);
  static const mint = Color(0xFF57D672);
  static const aqua = Color(0xFF09B9C4);
  static const ink = Color(0xFF132239);
  static const muted = Color(0xFF7B879B);
  static const background = Color(0xFFF5F8F8);
  static const surface = Colors.white;
  static const surfaceWarm = Color(0xFFF1F8F5);
  static const border = Color(0xFFE5ECEB);
  static const low = Color(0xFF1DBF7B);
  static const lowSoft = Color(0xFFE8F8F0);
  static const lowBorder = Color(0xFFCDEEDF);
  static const medium = Color(0xFFF5A623);
  static const high = Color(0xFFEF5C63);
  static const blue = Color(0xFF4E8FE8);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [mint, primary, aqua],
  );
}
