import 'widget_pet_renderer.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel(
    'com.kwallet.raccon/widget',
  );

  static int _generation = 0;
  static String _pose = 'idle';
  static String _mood = 'normal';
  static bool _facingRight = true;

  static Future<bool> syncWidget({
    required String petName,
    required int xp,
    required int completedHabits,
    required int totalHabits,
    required int pendingHabits,
    String? statusMessage,
    String? petStyle,
    Map<String, String> petSettings = const {},
    String petPose = 'idle',
    String petMood = 'normal',
    bool petFacingRight = true,
    String? themePalette,
    String? widgetBgMode,
    int? widgetBgColor,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    final generation = ++_generation;
    _pose = petPose;
    _mood = petMood;
    _facingRight = petFacingRight;
    try {
      final level = xp ~/ 100 + 1;
      final xpInLevel = xp % 100;

      final sprites = await WidgetPetRenderer.render({
        ...petSettings,
        'pet_style': ?petStyle,
      }, xp);
      if (generation != _generation) return false;
      final result = await _channel.invokeMethod<bool>('updateWidgetData', {
        'pet_name': petName,
        'pet_sprites': sprites,
        'pet_pose': _pose,
        'pet_mood': _mood,
        'pet_facing_right': _facingRight,
        'pet_level': level,
        'pet_xp': xp,
        'pet_xp_in_level': xpInLevel,
        'completed_habits': completedHabits,
        'total_habits': totalHabits,
        'pending_habits': pendingHabits,
        'status_message': statusMessage,
        'pet_style': petStyle ?? 'classic',
        'theme_palette': themePalette ?? 'forest',
        'widget_bg_mode': widgetBgMode ?? 'default',
        'widget_bg_color': ?widgetBgColor,
      });
      return result ?? true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('Widget sync failed: $e');
      return false;
    }
  }

  static Future<void> syncPetState({
    required String pose,
    required String mood,
    required bool facingRight,
  }) async {
    _pose = pose;
    _mood = mood;
    _facingRight = facingRight;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('updatePetState', {
        'pet_pose': pose,
        'pet_mood': mood,
        'pet_facing_right': facingRight,
      });
    } on MissingPluginException {
      // Widget is only available in Android builds with the native bridge.
    } catch (e) {
      debugPrint('Widget pet state sync failed: $e');
    }
  }

  static Future<String?> getLaunchRoute() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('getLaunchRoute');
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Widget launch route failed: $e');
      return null;
    }
  }

  static Future<int> consumePendingAffection() async {
    if (kIsWeb || !Platform.isAndroid) {
      return 0;
    }
    try {
      final points = await _channel.invokeMethod<int>(
        'consumePendingAffection',
      );
      return points ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
