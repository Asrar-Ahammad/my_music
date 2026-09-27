import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  PermissionHelper._();

  /// Request storage/audio permissions according to platform version
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      // 1. Android 13+ (API 33+) uses Permission.audio
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;

      final reqAudio = await Permission.audio.request();
      if (reqAudio.isGranted) return true;

      // 2. Storage permission for Android 12 and below
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final reqStorage = await Permission.storage.request();
      if (reqStorage.isGranted) return true;

      // 3. Optional manageExternalStorage for Android 11+
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      return false;
    }

    return true;
  }

  /// Request notification permission for system player on Android 13+
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      if (await Permission.manageExternalStorage.isGranted) return true;
      return false;
    }

    return true;
  }
}
