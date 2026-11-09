import 'package:abaad/core/licensing/license_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const deviceId = 'device-123';
  final currentDate = DateTime.utc(2026, 11, 9, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('verifies a YYYY-MM-DD-HASH key for its device', () {
    final codec = LicenseKeyCodec(appSecret);
    final key = codec.generate(deviceId, DateTime.utc(2026, 12, 9));

    expect(codec.decodeAndVerify(key, deviceId), isNotNull);
    expect(codec.decodeAndVerify(key, 'another-device'), isNull);
  });

  test('stores a verified expiry date and unlocks on restart', () async {
    final service = LicenseService(now: () => currentDate);
    final key = service.generateActivationKey(deviceId, DateTime.utc(2026, 12, 9));

    expect(await service.activate(key, deviceId), ActivationResult.activated);
    expect(await service.getValidExpiry(), DateTime.utc(2026, 12, 9));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('license_expiry_date_utc_v2'), '2026-12-09');
  });

  test('accepts the expiration date itself and rejects the following day', () async {
    final key = LicenseKeyCodec(
      appSecret,
    ).generate(deviceId, DateTime.utc(2026, 11, 9));

    expect(
      await LicenseService(now: () => currentDate).activate(key, deviceId),
      ActivationResult.activated,
    );
    expect(
      await LicenseService(
        now: () => currentDate.add(const Duration(days: 1)),
      ).getValidExpiry(),
      isNull,
    );
  });
}
