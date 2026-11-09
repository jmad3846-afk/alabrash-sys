import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appSecret = 'FactoryProcurement_Secret_Core_Key_9988';

/// Encodes and verifies keys in the `YYYY-MM-DD-HASH` format.
class LicenseKeyCodec {
  static final _keyPattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})-([A-F0-9]{10})$',
  );

  const LicenseKeyCodec(this._secret);

  final String _secret;

  String generate(String rawDeviceId, DateTime expirationDate) {
    final expiryDate = _utcDate(expirationDate);
    final expiryText = _dateOnly(expiryDate);
    final deviceId = _cleanDeviceId(rawDeviceId);
    return '$expiryText-${_signature(deviceId, expiryText)}';
  }

  DecodedLicense? decodeAndVerify(String input, String rawDeviceId) {
    final match = _keyPattern.firstMatch(input.trim().toUpperCase());
    if (match == null) return null;

    final expiryText = '${match.group(1)}-${match.group(2)}-${match.group(3)}';
    final expiryDate = DateTime.tryParse(expiryText);
    if (expiryDate == null || _dateOnly(expiryDate) != expiryText) return null;

    final deviceId = _cleanDeviceId(rawDeviceId);
    if (_signature(deviceId, expiryText) != match.group(4)) return null;

    return DecodedLicense(_utcDate(expiryDate));
  }

  String _signature(String deviceId, String expiryText) {
    final digest = Hmac(
      sha256,
      utf8.encode(_secret),
    ).convert(utf8.encode('$deviceId|$expiryText'));
    return digest.toString().substring(0, 10).toUpperCase();
  }
}

class DecodedLicense {
  const DecodedLicense(this.expiryDateUtc);

  final DateTime expiryDateUtc;
}

class LicenseService {
  static const _deviceIdKey = 'license_device_id_v1';
  static const _expiryKey = 'license_expiry_date_utc_v2';
  static const _legacyExpiryKey = 'license_expiry_v1';

  LicenseService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String cleanDeviceId(String rawDeviceId) => _cleanDeviceId(rawDeviceId);

  /// Used by the separate license generator with the same key format.
  String generateActivationKey(String rawDeviceId, DateTime expirationDate) =>
      LicenseKeyCodec(appSecret).generate(rawDeviceId, expirationDate);

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
      // Fall back to an installation-specific identifier.
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
    final storedValue =
        prefs.getString(_expiryKey) ?? prefs.getString(_legacyExpiryKey);
    if (storedValue == null) return null;

    final expiryDate = _parseUtcDate(storedValue);
    if (expiryDate == null ||
        !_isCurrentDateValid(expiryDate, source: 'stored activation')) {
      await prefs.remove(_expiryKey);
      await prefs.remove(_legacyExpiryKey);
      return null;
    }

    if (storedValue != _dateOnly(expiryDate)) {
      await prefs.setString(_expiryKey, _dateOnly(expiryDate));
      await prefs.remove(_legacyExpiryKey);
    }
    return expiryDate;
  }

  Future<ActivationResult> activate(String input, String rawDeviceId) async {
    if (appSecret.isEmpty || appSecret.contains('PLACEHOLDER')) {
      return ActivationResult.notConfigured;
    }

    final license = LicenseKeyCodec(
      appSecret,
    ).decodeAndVerify(input, cleanDeviceId(rawDeviceId));
    if (license == null) {
      _log('activation rejected: invalid date, format, or hash');
      return ActivationResult.invalid;
    }
    if (!_isCurrentDateValid(license.expiryDateUtc, source: 'activation key')) {
      return ActivationResult.expired;
    }

    final prefs = await SharedPreferences.getInstance();
    final expiryText = _dateOnly(license.expiryDateUtc);
    await prefs.setString(_expiryKey, expiryText);
    await prefs.remove(_legacyExpiryKey);
    _log('activation saved: expirationDateUtc=$expiryText');
    return ActivationResult.activated;
  }

  bool _isCurrentDateValid(DateTime expiryDateUtc, {required String source}) {
    final currentDateUtc = _utcDate(_now());
    final isValid = !currentDateUtc.isAfter(expiryDateUtc);
    _log(
      '$source validation: currentDateUtc=${_dateOnly(currentDateUtc)} '
      'expirationDateUtc=${_dateOnly(expiryDateUtc)} '
      'currentDateOnOrBeforeExpiry=$isValid',
    );
    return isValid;
  }

  void _log(String message) => developer.log(message, name: 'LicenseService');
}

DateTime? _parseUtcDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _dateOnly(parsed) != value) return null;
  return _utcDate(parsed);
}

DateTime _utcDate(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _cleanDeviceId(String rawDeviceId) =>
    rawDeviceId.replaceAll(RegExp(r'[{}]'), '').trim();

enum ActivationResult { activated, invalid, expired, notConfigured }
