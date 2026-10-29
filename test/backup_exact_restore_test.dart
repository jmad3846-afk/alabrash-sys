import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all screen data and collection balances survive replacement restore', () async {
    final source = ERPProvider();
    await source.populateComprehensiveSeedData(lockOpeningEntry: true);
    source.unallocatedFactoryCollectionsUsd = 123;
    source.unallocatedFactoryCollectionsSyp = 456;
    source.unallocatedWorkshopCollectionsUsd = 789;
    source.unallocatedWorkshopCollectionsSyp = 1011;
    final backup = jsonDecode(jsonEncode(source.exportFullBackupData())) as Map<String, dynamic>;
    final target = ERPProvider();
    await target.loadFuture;
    await target.importFullBackupData(backup);
    final actual = target.exportFullBackupData()..remove('metadata');
    backup.remove('metadata');
    expect(actual, equals(backup));
    target.dispose();
    source.dispose();
  });

  test('invalid collection cannot partially replace live records', () async {
    final erp = ERPProvider();
    await erp.loadFuture;
    final before = jsonDecode(jsonEncode(erp.exportFullBackupData())) as Map<String, dynamic>;
    final invalid = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
    invalid['financials']['mainCashBox'] = 777;
    invalid['factory']['clients'] = 'invalid';
    await expectLater(erp.importFullBackupData(invalid), throwsFormatException);
    final after = erp.exportFullBackupData()..remove('metadata');
    before.remove('metadata');
    expect(after, equals(before));
    erp.dispose();
  });
}