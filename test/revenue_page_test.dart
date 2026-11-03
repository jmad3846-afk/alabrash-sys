import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'revenue receipts update cash and income per currency and survive restore',
    () async {
      final erp = ERPProvider();
      await erp.loadFuture;
      for (final currency in [AppCurrency.usd, AppCurrency.syp]) {
        final cash = erp.cashOf('main', currency);
        final profit = erp.incomeSummaryNetProfitOf(currency);
        final revenue = erp.totalRevenuesOf(currency);
        final record = RevenueRecordModel(
          id: currency,
          description: 'Other income',
          amount: 75,
          currency: currency,
          date: DateTime(2026, 11, 2),
        );
        erp.addRevenueRecord(record);
        expect(erp.revenuePageEarningsOf(currency), 75);
        expect(erp.cashOf('main', currency), cash + 75);
        expect(erp.totalRevenuesOf(currency), revenue + 75);
        expect(erp.incomeSummaryNetProfitOf(currency), profit + 75);
        expect(() => erp.addRevenueRecord(record), throwsArgumentError);
        expect(erp.cashOf('main', currency), cash + 75);
      }
      await erp.saveToDisk();
      final loaded = ERPProvider();
      await loaded.loadFuture;
      expect(loaded.revenueRecords.length, 2);
      expect(loaded.revenuePageEarningsOf(AppCurrency.syp), 75);
      final backup = erp.exportFullBackupData();
      await loaded.importFullBackupData(backup);
      expect(loaded.revenueRecords.length, 2);
      expect(loaded.revenuePageEarningsOf(AppCurrency.usd), 75);
      expect(loaded.mainCashBox, erp.mainCashBox);
      erp.dispose();
      loaded.dispose();
    },
  );
  test('invalid amounts cannot change the ledger or cash', () async {
    final erp = ERPProvider();
    await erp.loadFuture;
    final cash = erp.mainCashBox;
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => erp.addRevenueRecord(
          RevenueRecordModel(
            id: 'bad',
            description: 'Invalid',
            amount: amount,
            currency: AppCurrency.usd,
            date: DateTime.now(),
          ),
        ),
        throwsArgumentError,
      );
    }
    expect(erp.revenueRecords, isEmpty);
    expect(erp.mainCashBox, cash);
    erp.dispose();
  });
}
