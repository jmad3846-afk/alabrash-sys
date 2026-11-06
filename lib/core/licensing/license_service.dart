import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appSecret = 'FactoryProcurement_Secret_Core_Key_9988';

class LicenseService {
  static const _deviceIdKey = 'license_device_id_v1';
  static const _expiryKey = 'license_expiry_v1';

  String cleanDeviceId(String rawDeviceId) =>
      rawDeviceId.replaceAll(RegExp(r'[{}]'), '').trim();

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final id = (await deviceInfo.iosInfo).identifierForVendor?.trim();
        if (id != null && id.isNotEmpty) return cleanDeviceId(id);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final id = (await deviceInfo.windowsInfo).deviceId.trim();
        if (id.isNotEmpty) return cleanDeviceId(id);
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final id = (await deviceInfo.linuxInfo).machineId?.trim();
        if (id != null && id.isNotEmpty) return cleanDeviceId(id);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final id = (await deviceInfo.macOsInfo).systemGUID?.trim();
        if (id != null && id.isNotEmpty) return cleanDeviceId(id);
      }
    } catch (_) {
      // Fall back to an installation-specific identifier if the platform
      // doesn't expose a stable identifier.
    }

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      id = List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      await prefs.setString(_deviceIdKey, id);
    }
    final cleanId = cleanDeviceId(id);
    if (cleanId != id) await prefs.setString(_deviceIdKey, cleanId);
    return cleanId;
  }

  Future<DateTime?> getValidExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_expiryKey);
    if (value == null) return null;
    final expiry = DateTime.tryParse(value);
    if (expiry == null || !_isCurrentOrFutureDate(expiry)) {
      await prefs.remove(_expiryKey);
      return null;
    }
    return expiry;
  }

  Future<ActivationResult> activate(String input, String rawDeviceId) async {
    final deviceId = cleanDeviceId(rawDeviceId);
    final parts = input.trim().toUpperCase().split('-');
    if (parts.length != 4 ||
        !RegExp(r'^\d{4}$').hasMatch(parts[0]) ||
        !RegExp(r'^\d{2}$').hasMatch(parts[1]) ||
        !RegExp(r'^\d{2}$').hasMatch(parts[2]) ||
        !RegExp(r'^[A-F0-9]{10}$').hasMatch(parts[3])) {
      return ActivationResult.invalid;
    }

    final expiryText = '${parts[0]}-${parts[1]}-${parts[2]}';
    final expiry = DateTime.tryParse(expiryText);
    if (expiry == null || _dateOnly(expiry) != expiryText) {
      return ActivationResult.invalid;
    }
    if (!_isCurrentOrFutureDate(expiry)) return ActivationResult.expired;
    if (appSecret.isEmpty || appSecret.contains('PLACEHOLDER')) {
      return ActivationResult.notConfigured;
    }

    final message = '$deviceId|$expiryText';
    final digest = Hmac(
      sha256,
      utf8.encode(appSecret),
    ).convert(utf8.encode(message));
    final signature = digest
        .toString()
        .replaceAll('-', '')
        .substring(0, 10)
        .toUpperCase();
    if (signature != parts[3]) return ActivationResult.invalid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_expiryKey, expiryText);
    return ActivationResult.activated;
  }

  bool _isCurrentOrFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(date.year, date.month, date.day);
    return !expiryDay.isBefore(today);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

enum ActivationResult { activated, invalid, expired, notConfigured }
