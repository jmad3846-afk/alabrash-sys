import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Comprehensive Backup & Restore System Tests', () {
    test('populateComprehensiveSeedData populates 100% of interfaces with rich test data', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      // 1. Opening Entry Verification
      expect(erp.openingEntry.isLocked, isTrue);
      expect(erp.openingEntry.openingStockApplied, isTrue);
      expect(erp.openingEntry.fixedAssets.length, greaterThanOrEqualTo(6));
      expect(erp.openingEntry.openingStock.length, greaterThanOrEqualTo(8));
      expect(erp.openingEntry.legacyFinancials.length, greaterThanOrEqualTo(5));
      expect(erp.openingEntry.mainCashValue, 45000.0);
      expect(erp.openingEntry.scrapCashValue, 8500.0);
      expect(erp.openingEntry.orderCashValue, 4200.0);
      expect(erp.openingEntry.mainCashValueSyp, 15000000.0);
      expect(erp.openingEntry.scrapCashValueSyp, 2500000.0);
      expect(erp.openingEntry.orderCashValueSyp, 3000000.0);
      expect(erp.isOpeningEntryCompleted, isTrue);
      expect(erp.openingEntry.isBalanced, isTrue);

      // 2. Financials & Partners
      expect(erp.partners.length, 3);
      expect(erp.partners[0].ratio, 0.42);
      expect(erp.partners[1].ratio, 0.35);
      expect(erp.partners[2].ratio, 0.23);
      expect(erp.mainCashBox, 45000.0);
      expect(erp.scrapCashBox, 8500.0);
      expect(erp.orderCashBox, 4200.0);
      expect(erp.mainCashBoxSyp, 15000000.0);
      expect(erp.scrapCashBoxSyp, 2500000.0);
      expect(erp.orderCashBoxSyp, 3000000.0);

      // 3. Factory Entities
      expect(erp.suppliers.length, greaterThanOrEqualTo(3));
      expect(erp.clients.length, greaterThanOrEqualTo(4));
      expect(erp.blockTypes.length, greaterThanOrEqualTo(4));
      expect(erp.meterTypes.length, greaterThanOrEqualTo(4));
      expect(erp.factoryBlocks.length, greaterThanOrEqualTo(3));
      expect(erp.factoryWarehouse.length, greaterThanOrEqualTo(4));
      expect(erp.cuttingOperations.length, greaterThanOrEqualTo(1));
      expect(erp.factoryInvoices.length, greaterThanOrEqualTo(3));
      expect(erp.factoryOrders.length, greaterThanOrEqualTo(2));

      // 4. Workshop Entities
      expect(erp.workshopStock.length, greaterThanOrEqualTo(2));
      expect(erp.simpleTailorings.length, greaterThanOrEqualTo(2));
      expect(erp.complexTailorings.length, greaterThanOrEqualTo(1));
      expect(erp.scrapItems.length, greaterThanOrEqualTo(2));
      expect(erp.surplusCosts.length, greaterThanOrEqualTo(2));
      expect(erp.wasteLogs.length, greaterThanOrEqualTo(2));
      expect(erp.workshopOrders.length, greaterThanOrEqualTo(1));
      expect(erp.workshopInvoices.length, greaterThanOrEqualTo(1));
      expect(erp.workshopProjects.length, greaterThanOrEqualTo(3));

      // 5. Staff & Workforce
      expect(erp.staffTypes.length, greaterThanOrEqualTo(3));
      expect(erp.staffList.length, greaterThanOrEqualTo(3));
      expect(erp.staffAttendance.length, greaterThanOrEqualTo(3));
      expect(erp.workdayEntries.length, greaterThanOrEqualTo(1));
      expect(erp.advanceRepayments.length, greaterThanOrEqualTo(1));

      // 6. Operations & Daily Reports
      expect(erp.returnInvoices.length, greaterThanOrEqualTo(1));
      expect(erp.expenseTypes.length, greaterThanOrEqualTo(4));
      expect(erp.expenseRecords.length, greaterThanOrEqualTo(3));
      expect(erp.adjustmentInvoices.length, greaterThanOrEqualTo(1));
      expect(erp.services.length, greaterThanOrEqualTo(5));
      expect(erp.dailyReports.length, greaterThanOrEqualTo(1));
      expect(erp.centerInfo.centerName.isNotEmpty, isTrue);
    });

    test('exportFullBackupData generates a complete JSON-serializable backup containing 100% of data', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      final exported = erp.exportFullBackupData();

      // Verify root sections
      expect(exported.containsKey('metadata'), isTrue);
      expect(exported.containsKey('financials'), isTrue);
      expect(exported.containsKey('factory'), isTrue);
      expect(exported.containsKey('workshop'), isTrue);
      expect(exported.containsKey('staff'), isTrue);
      expect(exported.containsKey('operations'), isTrue);
      expect(exported.containsKey('centerInfo'), isTrue);

      // Verify Opening Entry in financials
      final fin = exported['financials'] as Map<String, dynamic>;
      expect(fin.containsKey('openingEntry'), isTrue);
      final opening = fin['openingEntry'] as Map<String, dynamic>;
      expect(opening['isLocked'], isTrue);
      expect((opening['fixedAssets'] as List).length, greaterThanOrEqualTo(6));
      expect((opening['openingStock'] as List).length, greaterThanOrEqualTo(8));
      expect((opening['legacyFinancials'] as List).length, greaterThanOrEqualTo(5));

      // JSON Encode and Decode Round-Trip test
      final jsonString = jsonEncode(exported);
      expect(jsonString.isNotEmpty, isTrue);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['metadata']['systemIdentifier'], 'abaad_marble_granite_erp');
      expect((decoded['factory']['factoryInvoices'] as List).length, erp.factoryInvoices.length);
      expect((decoded['workshop']['workshopProjects'] as List).length, erp.workshopProjects.length);
    });

    test('importFullBackupData completely restores all entities, opening entry, and balances', () async {
      final erpOriginal = ERPProvider();
      await erpOriginal.populateComprehensiveSeedData(lockOpeningEntry: true);

      // Export full backup
      final backup = erpOriginal.exportFullBackupData();
      final backupJson = jsonEncode(backup);

      // Create a fresh ERP instance and reset it to blank slate
      final erpTarget = ERPProvider();
      erpTarget.factoryBlocks.clear();
      erpTarget.factoryWarehouse.clear();
      erpTarget.factoryInvoices.clear();
      erpTarget.factoryOrders.clear();
      erpTarget.workshopStock.clear();
      erpTarget.workshopProjects.clear();
      erpTarget.staffList.clear();
      erpTarget.dailyReports.clear();
      erpTarget.mainCashBox = 0.0;
      erpTarget.mainCashBoxSyp = 0.0;
      erpTarget.openingEntry = OpeningEntryModel(
        landValue: 0,
        buildingsValue: 0,
        machineryValue: 0,
        vehiclesValue: 0,
        mainCashValue: 0,
        scrapCashValue: 0,
        orderCashValue: 0,
        inventoryValue: 0,
        customerDebtsValue: 0,
        supplierPayablesValue: 0,
        workerSalariesValue: 0,
        isLocked: false,
      );

      expect(erpTarget.factoryBlocks.isEmpty, isTrue);
      expect(erpTarget.openingEntry.fixedAssets.isEmpty, isTrue);
      expect(erpTarget.mainCashBox, 0.0);

      // Restore from backup JSON
      final rawDecoded = jsonDecode(backupJson) as Map<String, dynamic>;
      final metrics = await erpTarget.importFullBackupData(rawDecoded);

      // Verify Restored Metrics
      expect(metrics['openingEntryStatus'], 'معتمد ومرحل');
      expect(metrics['openingFixedAssets'], erpOriginal.openingEntry.fixedAssets.length);
      expect(metrics['openingStockItems'], erpOriginal.openingEntry.openingStock.length);
      expect(metrics['factoryInvoices'], erpOriginal.factoryInvoices.length);
      expect(metrics['workshopProjects'], erpOriginal.workshopProjects.length);
      expect(metrics['staffList'], erpOriginal.staffList.length);
      expect(metrics['dailyReports'], erpOriginal.dailyReports.length);
      expect(metrics['totalCashUsd'], erpOriginal.mainCashBox + erpOriginal.scrapCashBox + erpOriginal.orderCashBox);
      expect(metrics['totalCashSyp'], erpOriginal.mainCashBoxSyp + erpOriginal.scrapCashBoxSyp + erpOriginal.orderCashBoxSyp);

      // Verify Restored Entities in ERP Target
      expect(erpTarget.openingEntry.isLocked, isTrue);
      expect(erpTarget.openingEntry.fixedAssets.length, erpOriginal.openingEntry.fixedAssets.length);
      expect(erpTarget.openingEntry.openingStock.length, erpOriginal.openingEntry.openingStock.length);
      expect(erpTarget.openingEntry.legacyFinancials.length, erpOriginal.openingEntry.legacyFinancials.length);
      expect(erpTarget.mainCashBox, erpOriginal.mainCashBox);
      expect(erpTarget.mainCashBoxSyp, erpOriginal.mainCashBoxSyp);
      expect(erpTarget.scrapCashBox, erpOriginal.scrapCashBox);
      expect(erpTarget.scrapCashBoxSyp, erpOriginal.scrapCashBoxSyp);
      expect(erpTarget.orderCashBox, erpOriginal.orderCashBox);
      expect(erpTarget.orderCashBoxSyp, erpOriginal.orderCashBoxSyp);

      expect(erpTarget.factoryBlocks.length, erpOriginal.factoryBlocks.length);
      expect(erpTarget.factoryWarehouse.length, erpOriginal.factoryWarehouse.length);
      expect(erpTarget.factoryInvoices.length, erpOriginal.factoryInvoices.length);
      expect(erpTarget.factoryOrders.length, erpOriginal.factoryOrders.length);
      expect(erpTarget.workshopStock.length, erpOriginal.workshopStock.length);
      expect(erpTarget.workshopProjects.length, erpOriginal.workshopProjects.length);
      expect(erpTarget.staffList.length, erpOriginal.staffList.length);
      expect(erpTarget.dailyReports.length, erpOriginal.dailyReports.length);
      expect(erpTarget.centerInfo.centerName, erpOriginal.centerInfo.centerName);
    });
  });
}
