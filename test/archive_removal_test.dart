import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/app_sidebar.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'sidebar has no archive destination and retains financial navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              selectedIndex: 0,
              onDestinationSelected: (index) => destination = index,
            ),
          ),
        ),
      );
      expect(find.text('الأرشيف'), findsNothing);
      expect(find.text('الميزانية العمومية'), findsOneWidget);
      await tester.ensureVisible(find.text('الميزانية العمومية'));
      await tester.tap(find.text('الميزانية العمومية'));
      expect(destination, 13);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'saving active data creates no period history or financial reset',
    () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);
      final cash = erp.mainCashBox;
      final invoiceCount = erp.factoryInvoices.length;
      final tailoring = erp.simpleTailorings.map((t) => t.toJson()).toList();
      await erp.saveToDisk();
      expect(erp.exportFullBackupData().containsKey('periodArchives'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('periodArchives'), isFalse);
      final restored = ERPProvider();
      await restored.loadFuture;
      expect(restored.mainCashBox, cash);
      expect(restored.factoryInvoices.length, invoiceCount);
      expect(
        restored.simpleTailorings.map((t) => t.toJson()).toList(),
        tailoring,
      );
      erp.dispose();
      restored.dispose();
    },
  );

  test(
    'old backup history remains opaque and cannot reintroduce recognized costs',
    () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);
      final backup =
          jsonDecode(jsonEncode(erp.exportFullBackupData()))
              as Map<String, dynamic>;
      final history = [
        {
          'id': 'historical-record',
          'archiveName': 'Previously saved records',
          'closingSnapshot': {
            'scrapItems': erp.scrapItems.map((s) => s.toJson()).toList(),
            'wasteLogs': erp.wasteLogs.map((w) => w.toJson()).toList(),
          },
        },
      ];
      backup['periodArchives'] = history;
      final restored = ERPProvider();
      final result = await restored.importFullBackupData(backup);
      expect(result['success'], isTrue);
      expect(result.containsKey('periodArchives'), isFalse);
      expect(restored.exportFullBackupData()['periodArchives'], history);
      expect(restored.factoryInvoices.length, erp.factoryInvoices.length);
      expect(restored.currentInventoryValueUsd, erp.currentInventoryValueUsd);
      for (final currency in [AppCurrency.usd, AppCurrency.syp]) {
        expect(restored.totalScrapRevenueOf(currency), 0);
        expect(restored.totalSurplusInitialCostOf(currency), 0);
        expect(restored.totalUnnaturalWasteLossesOf(currency), 0);
      }
      final reloaded = ERPProvider();
      await reloaded.loadFuture;
      expect(reloaded.exportFullBackupData()['periodArchives'], history);
      await restored.importFullBackupData(erp.exportFullBackupData());
      expect(
        restored.exportFullBackupData().containsKey('periodArchives'),
        isFalse,
      );
      erp.dispose();
      restored.dispose();
      reloaded.dispose();
    },
  );
}
