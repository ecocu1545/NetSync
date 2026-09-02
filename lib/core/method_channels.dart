import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.example.netsync/service');

  static Future<bool> startService() async {
    try {
      final res = await _channel.invokeMethod<bool>('startMonitorService');
      return res ?? false;
    } on PlatformException catch (e) {
      print("Servis başlatılamadı: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> stopService() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopMonitorService');
      return res ?? false;
    } on PlatformException catch (e) {
      print("Servis durdurulamadı: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> isServiceRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isServiceRunning');
      return res ?? false;
    } on PlatformException catch (e) {
      print("Servis durumu sorgulanamadı: '${e.message}'.");
      return false;
    }
  }

  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } on PlatformException catch (e) {
      print("Pil optimizasyonu penceresi açılamadı: '${e.message}'.");
    }
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final res = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } on PlatformException catch (e) {
      print("Pil optimizasyonu durumu sorgulanamadı: '${e.message}'.");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      return res;
    } on PlatformException catch (e) {
      print("Native konum alınamadı: '${e.message}'.");
      return null;
    }
  }
}
