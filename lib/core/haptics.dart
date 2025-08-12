import 'package:flutter/services.dart';

class HapticsService {
  static Future<void> lightTap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Haptics may not be available on all devices
    }
  }

  static Future<void> mediumTap() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Haptics may not be available on all devices
    }
  }

  static Future<void> heavyTap() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Haptics may not be available on all devices
    }
  }

  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      // Haptics may not be available on all devices
    }
  }
}