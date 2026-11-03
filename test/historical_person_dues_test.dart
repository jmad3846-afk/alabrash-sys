import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'opening debts require a registered supplier or factory client',
    () async {
      final erp = ERPProvider();
      await erp.loadFuture;
      erp.openingEntry.isLocked = false;
      for (final category in ['suppliers', 'clients']) {
        expect(
          () => erp.addOpeningFinancialRecord(
            LegacyFinancialRecordModel(
              id: category,
              category: category,
              name: 'Unknown',
              currency: AppCurrency.usd,
              amount: 100,
            ),
          ),
          throwsArgumentError,
        );
      }
      erp.clients.add(
        ClientModel(id: 'retail', name: 'Retail', clientType: 'زبون معمل'),
      );
      expect(
        () => erp.addOpeningFinancialRecord(
          LegacyFinancialRecordModel(
            id: 'retail-debt',
            category: 'clients',
            partyId: 'retail',
            name: 'Retail',
            currency: AppCurrency.usd,
            amount: 100,
          ),
        ),
        throwsArgumentError,
      );
      erp.dispose();
    },
  );
  test('older saved debts default original total to their stored balance', () {
    final record = LegacyFinancialRecordModel.fromJson({
      'id': 'legacy',
      'category': 'clients',
      'name': 'Client',
      'currency': AppCurrency.usd,
      'amount': 80,
    });
    expect(record.originalAmount, 80);
    expect(record.paidAmount, 0);
    record.amount -= 20;
    final loaded = LegacyFinancialRecordModel.fromJson(record.toJson());
    expect(loaded.originalAmount, 80);
    expect(loaded.paidAmount, 20);
    expect(loaded.amount, 60);
  });
  testWidgets(
    'printed statement shows the final old dues column without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final erp = ERPProvider();
      await erp.loadFuture;
      final data = A4StatementData(
        type: AccountStatementType.supplier,
        statementNo: 'OLD-TEST',
        issueDate: DateTime(2026, 11, 3),
        accountId: 'p',
        accountName: 'Supplier',
        currentBalanceUsd: 70,
        currentBalanceSyp: 0,
        openingBalanceUsd: 70,
        items: [
          A4StatementLineItem(
            index: 1,
            date: DateTime(2026, 1, 1),
            documentNo: 'Opening',
            description: 'Old dues',
            category: 'قيد افتتاحي',
            currency: AppCurrency.usd,
            totalAmount: 70,
            paidAmount: 0,
            remainingAmount: 70,
            status: 'رصيد مدور',
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: erp,
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: A4StatementPrintDialog(statementData: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ذمم قديمة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      erp.dispose();
    },
  );
  for (final supplier in [true, false]) {
    for (final currency in [AppCurrency.usd, AppCurrency.syp]) {
      test(
        'old dues stay linked after rename and reflect settlements ($supplier, $currency)',
        () async {
          final erp = ERPProvider();
          await erp.loadFuture;
          erp.openingEntry.isLocked = false;
          erp.openingEntry.legacyFinancials.clear();
          erp.suppliers.add(
            SupplierModel(
              id: 'person',
              name: 'Renamed',
              phone: '',
              location: '',
            ),
          );
          erp.clients.add(
            ClientModel(
              id: 'person',
              name: 'Renamed',
              clientType: 'معتمد مصنع',
            ),
          );
          erp.addOpeningFinancialRecord(
            LegacyFinancialRecordModel(
              id: 'old',
              partyId: 'person',
              category: supplier ? 'suppliers' : 'clients',
              name: 'Original name',
              currency: currency,
              amount: 100,
            ),
          );
          erp.mainCashBox = 1000;
          erp.mainCashBoxSyp = 1000;
          expect(erp.settleLegacyFinancialRecord('old', 30, 'main'), isTrue);
          erp.factoryInvoices.add(
            FactoryInvoiceModel(
              id: 'new',
              invoiceNo: 'NEW',
              date: DateTime.now(),
              partyId: 'person',
              partyName: 'Renamed',
              currency: currency,
              invoiceType: supplier ? 'شراء_مورد' : 'بيع_معتمد',
              items: [],
            ),
          );
          final data = supplier
              ? A4StatementData.fromSupplier(
                  supplier: erp.suppliers.last,
                  erp: erp,
                )
              : A4StatementData.fromAccreditedAgent(
                  client: erp.clients.last,
                  erp: erp,
                );
          expect(
            data.items
                .where((i) => i.category == 'قيد افتتاحي')
                .single
                .remainingAmount,
            70,
          );
          expect(data.items.any((i) => i.documentNo == 'NEW'), isTrue);
          expect(
            currency == AppCurrency.usd
                ? data.currentBalanceUsd
                : data.currentBalanceSyp,
            70,
          );
          final oldRow = data.items.singleWhere(
            (i) => i.category == 'قيد افتتاحي',
          );
          expect(oldRow.totalAmount, 100);
          expect(oldRow.paidAmount, 30);
          expect(oldRow.remainingAmount, 70);
          final restored = LegacyFinancialRecordModel.fromJson(
            erp.openingEntry.legacyFinancials.single.toJson(),
          );
          expect(restored.partyId, 'person');
          expect(restored.amount, 70);
          expect(restored.originalAmount, 100);
          expect(restored.paidAmount, 30);
          erp.dispose();
        },
      );
    }
  }
}
