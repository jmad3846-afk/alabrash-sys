import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Semi-Annual Archiving & Opening Balance Roll-over Engine Tests', () {
    test('previewNextPeriodOpeningEntry correctly transfers safes, assets, stock, and debts', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      final proposedEntry = erp.previewNextPeriodOpeningEntry();

      // 1. Safes transferred exactly
      expect(proposedEntry.mainCashValue, closeTo(erp.mainCashBox, 0.01));
      expect(proposedEntry.scrapCashValue, closeTo(erp.scrapCashBox, 0.01));
      expect(proposedEntry.orderCashValue, closeTo(erp.orderCashBox, 0.01));
      expect(proposedEntry.mainCashValueSyp, closeTo(erp.mainCashBoxSyp, 0.01));
      expect(proposedEntry.scrapCashValueSyp, closeTo(erp.scrapCashBoxSyp, 0.01));
      expect(proposedEntry.orderCashValueSyp, closeTo(erp.orderCashBoxSyp, 0.01));

      // 2. Fixed Assets transferred at active book value
      final activeAssets = erp.openingEntry.fixedAssets.where((a) => !a.isSold).toList();
      expect(proposedEntry.fixedAssets.length, activeAssets.length);
      expect(proposedEntry.totalFixedAssets, closeTo(erp.openingEntry.totalFixedAssets, 0.01));

      // 3. Opening Stock reflects current inventory
      expect(proposedEntry.openingStock.isNotEmpty, isTrue);
      expect(proposedEntry.inventoryValue, closeTo(erp.currentInventoryValueUsd, 0.01));

      // 4. Receivables & Payables migrated into legacyFinancials
      expect(proposedEntry.legacyFinancials.isNotEmpty, isTrue);
      final clientDebtsTotal = proposedEntry.legacyFinancials
          .where((r) => r.category == 'clients' && r.currency == AppCurrency.usd)
          .fold<double>(0.0, (s, r) => s + r.amount);
      expect(proposedEntry.customerDebtsValue, closeTo(clientDebtsTotal, 0.01));

      // 5. Mathematical Trial Balance Integrity
      final validation = erp.validateTrialBalanceIntegrity(proposedEntry: proposedEntry);
      expect(validation.isValid, isTrue);
      expect(validation.discrepancyUsd, closeTo(0.0, 0.01));
    });

    test('validateTrialBalanceIntegrity rejects imbalanced opening entry and displays error logs', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      final proposedEntry = erp.previewNextPeriodOpeningEntry();

      // Artificially corrupt the balance by altering asset cash without adjusting equity
      final corruptedEntry = OpeningEntryModel(
        mainCashValue: proposedEntry.mainCashValue + 50000.0, // Imbalance!
        scrapCashValue: proposedEntry.scrapCashValue,
        orderCashValue: proposedEntry.orderCashValue,
        inventoryValue: proposedEntry.inventoryValue,
        customerDebtsValue: proposedEntry.customerDebtsValue,
        supplierPayablesValue: proposedEntry.supplierPayablesValue,
        workerSalariesValue: proposedEntry.workerSalariesValue,
        fixedAssets: proposedEntry.fixedAssets,
        openingStock: proposedEntry.openingStock,
        legacyFinancials: proposedEntry.legacyFinancials,
        openingCapital: proposedEntry.totalEquity,
      );

      final validation = erp.validateTrialBalanceIntegrity(proposedEntry: corruptedEntry);
      expect(validation.isValid, isFalse);
      expect(validation.discrepancyUsd, closeTo(50000.0, 0.01));
      expect(validation.errorMessage, isNotNull);
    });

    test('archiveAndClosePeriod successfully bundles historical data, zeroes operational accounts, and generates new opening entry', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      // Verify initial state has active invoices and reports
      expect(erp.factoryInvoices.isNotEmpty, isTrue);
      expect(erp.workshopInvoices.isNotEmpty, isTrue);
      expect(erp.dailyReports.isNotEmpty, isTrue);
      expect(erp.periodArchives.isEmpty, isTrue);

      final initialCashUsd = erp.mainCashBox;

      // Execute Archive & Close Period
      final validation = erp.archiveAndClosePeriod(
        archiveName: 'أرشيف النصف الأول 2026',
        notes: 'إقفال الفترة المحاسبية النصف سنوية وتوليد القيد الافتتاحي الجديد',
      );

      expect(validation.isValid, isTrue);

      // 1. Archive Record Created
      expect(erp.periodArchives.length, 1);
      final archive = erp.periodArchives.first;
      expect(archive.archiveName, 'أرشيف النصف الأول 2026');
      expect(archive.notes, contains('إقفال الفترة المحاسبية'));
      expect(archive.factoryInvoices.isNotEmpty, isTrue);
      expect(archive.workshopInvoices.isNotEmpty, isTrue);
      expect(archive.dailyReports.isNotEmpty, isTrue);

      // 2. Active Operational Lists are Zeroed/Emptied for new clean period
      expect(erp.factoryInvoices.isEmpty, isTrue);
      expect(erp.workshopInvoices.isEmpty, isTrue);
      expect(erp.adjustmentInvoices.isEmpty, isTrue);
      expect(erp.returnInvoices.isEmpty, isTrue);
      expect(erp.dailyReports.isEmpty, isTrue);
      expect(erp.workdayEntries.isEmpty, isTrue);
      expect(erp.staffAttendance.isEmpty, isTrue);
      expect(erp.advanceRepayments.isEmpty, isTrue);

      // 3. New Opening Entry Generated and Locked
      expect(erp.openingEntry.isLocked, isTrue);
      expect(erp.openingEntry.openingStockApplied, isTrue);
      expect(erp.isOpeningEntryCompleted, isTrue);
      expect(erp.openingEntry.isBalanced, isTrue);

      // 4. Safes are preserved accurately across periods
      expect(erp.mainCashBox, closeTo(initialCashUsd, 0.01));
      expect(erp.openingEntry.mainCashValue, closeTo(initialCashUsd, 0.01));

      // 5. Partner Equity and Capital Rollover
      expect(erp.partners.length, greaterThan(0));
      final totalInjectedCapital = erp.partners.fold<double>(
        0.0,
        (s, p) => s + p.injectedCapital,
      );
      expect(totalInjectedCapital, closeTo(erp.openingEntry.totalEquity, 0.01));

      // 6. Net Debts rolled into legacyFinancials
      expect(erp.openingEntry.legacyFinancials.isNotEmpty, isTrue);
    });

    test('Period Archives are persisted in full backup and restored faithfully', () async {
      final erp1 = ERPProvider();
      await erp1.populateComprehensiveSeedData(lockOpeningEntry: true);

      // Archive period
      final validation = erp1.archiveAndClosePeriod(
        archiveName: 'أرشيف الفترة السنوية 2025',
        notes: 'نسخة اختبار التصدير والاستعادة',
      );
      expect(validation.isValid, isTrue);
      expect(erp1.periodArchives.length, 1);

      // Export full backup
      final backupMap = erp1.exportFullBackupData();
      expect(backupMap['periodArchives'], isNotNull);
      expect((backupMap['periodArchives'] as List).length, 1);

      // Restore into a fresh provider
      final erp2 = ERPProvider();
      final importResult = await erp2.importFullBackupData(backupMap);
      expect(importResult['success'], isTrue);

      expect(erp2.periodArchives.length, 1);
      final restoredArchive = erp2.periodArchives.first;
      expect(restoredArchive.archiveName, 'أرشيف الفترة السنوية 2025');
      expect(restoredArchive.notes, 'نسخة اختبار التصدير والاستعادة');
      expect(restoredArchive.factoryInvoices.length, erp1.periodArchives.first.factoryInvoices.length);
      expect(restoredArchive.rolledOpeningEntry.isBalanced, isTrue);
    });
  });
}
