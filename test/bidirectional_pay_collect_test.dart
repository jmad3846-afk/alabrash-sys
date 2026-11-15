import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';
import 'package:abaad/widgets/party_balances_modal.dart';

/// Bidirectional Pay / Collect for Suppliers & Accredited Agents:
/// both actions are always executable regardless of the balance direction,
/// each movement updates the Main Cash Register, and every Pay/Collect
/// appears as its own chronological row (دفعة دفع / دفعة قبض) inside the
/// account statement with a correctly recomputed running balance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ERPProvider freshErp() {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.mainCashBox = 1000.0;
    erp.mainCashBoxSyp = 0.0;
    erp.factoryInvoices = [];
    erp.workshopInvoices = [];
    erp.adjustmentInvoices.clear();
    erp.returnInvoices.clear();
    erp.openingEntry.legacyFinancials.clear();
    return erp;
  }

  group('1. Suppliers - fully bidirectional', () {
    test('Paying beyond the due registers an advance, Collect closes it', () {
      final erp = freshErp();
      final supplier = SupplierModel(
        id: 'sup_bi_1',
        name: 'مورد الاختبار الثنائي',
        phone: '',
        location: '',
      );
      erp.suppliers.add(supplier);

      // Zero balance: Pay must still work (classic behaviour kept: no debt
      // to settle, so the whole payment becomes an advance / claim).
      expect(
        erp.paySupplierDebt(
          supplier: supplier,
          amount: 200.0,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(supplier.debtBalance, closeTo(-200.0, 0.001));
      expect(supplier.hasCredit, isTrue);
      expect(erp.mainCashBox, closeTo(800.0, 0.001));

      // Collect: recovering cash moves the balance back up and into the box.
      expect(
        erp.collectFromSupplierCredit(
          supplier: supplier,
          amount: 500.0,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(supplier.debtBalance, closeTo(300.0, 0.001));
      expect(supplier.hasDebt, isTrue);
      expect(erp.mainCashBox, closeTo(1300.0, 0.001));

      // Both logged for the statement with their directions.
      expect(supplier.payments, hasLength(2));
      expect(supplier.payments.first['direction'], 'pay');
      expect(supplier.payments.last['direction'], 'collect');
    });

    test('Supplier statement shows Pay & Collect rows and running balance', () {
      final erp = freshErp();
      final supplier = SupplierModel(
        id: 'sup_bi_2',
        name: 'مورد الكشف',
        phone: '',
        location: '',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.paySupplierDebt(
        supplier: supplier,
        amount: 300.0,
        currency: AppCurrency.usd,
        notes: 'دفعة مقدمة على بلوك',
      );
      erp.collectFromSupplierCredit(
        supplier: supplier,
        amount: 100.0,
        currency: AppCurrency.usd,
      );

      final statement = A4StatementData.fromSupplier(
        supplier: supplier,
        erp: erp,
      );
      final payRow = statement.items
          .where((i) => i.category == 'دفعة دفع')
          .single;
      final collectRow = statement.items
          .where((i) => i.category == 'دفعة قبض')
          .single;
      expect(payRow.paidAmount, closeTo(300.0, 0.001));
      expect(payRow.description, contains('دفعة مقدمة على بلوك'));
      expect(collectRow.remainingAmount, closeTo(100.0, 0.001));

      // Running balance follows the liability: -300 then -200; final balance
      // matches the supplier account (debtBalance = -200).
      expect(collectRow.runningBalance, closeTo(-200.0, 0.001));
      expect(statement.currentBalanceUsd, closeTo(-200.0, 0.001));
    });
  });

  group('2. Accredited Agents - fully bidirectional', () {
    test('Collecting beyond the due creates credit, Payout settles it', () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_bi_1',
        name: 'معتمد الاختبار الثنائي',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
        debtBalance: 250.0,
      );
      erp.clients.add(client);

      // Collect 400 vs 250 due -> 150 credit (أمانة) for the agent.
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.usd,
          paymentAmount: 400.0,
        ),
        isTrue,
      );
      expect(client.debtBalance, closeTo(-150.0, 0.001));
      expect(client.hasCredit, isTrue);
      expect(erp.mainCashBox, closeTo(1400.0, 0.001));

      // Pay out (دفع) even beyond the credit: allowed, opens a receivable.
      expect(
        erp.payCustomerCredit(
          client: client,
          amount: 400.0,
          currency: AppCurrency.usd,
          notes: 'عمولة تسويق',
        ),
        isTrue,
      );
      expect(client.debtBalance, closeTo(250.0, 0.001));
      expect(erp.mainCashBox, closeTo(1000.0, 0.001));
    });

    test('Agent statement shows collection and payout rows with directions',
        () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_bi_2',
        name: 'معتمد الكشف',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 300.0,
      );
      erp.payCustomerCredit(
        client: client,
        amount: 100.0,
        currency: AppCurrency.usd,
        notes: 'استرجاع عربون',
      );

      final statement = A4StatementData.fromAccreditedAgent(
        client: client,
        erp: erp,
      );
      final collectRow = statement.items
          .where((i) => i.category == 'دفعة قبض')
          .single;
      final payoutRow = statement.items
          .where((i) => i.category == 'دفعة دفع')
          .single;
      expect(collectRow.paidAmount, closeTo(300.0, 0.001));
      expect(collectRow.remainingAmount, closeTo(-300.0, 0.001));
      expect(payoutRow.remainingAmount, closeTo(100.0, 0.001));
      expect(payoutRow.description, contains('استرجاع عربون'));

      // Running balance: -300 after collection, -200 after the payout;
      // matches the client account (debtBalance = -200).
      expect(payoutRow.runningBalance, closeTo(-200.0, 0.001));
      expect(statement.currentBalanceUsd, closeTo(-200.0, 0.001));
    });
  });

  group('3. SYP direction stays its own register', () {
    test('Supplier SYP pay & collect touch only the SYP vault', () {
      final erp = freshErp();
      erp.mainCashBoxSyp = 2000000.0;
      final supplier = SupplierModel(
        id: 'sup_bi_syp',
        name: 'مورد الليرة',
        phone: '',
        location: '',
      );
      erp.suppliers.add(supplier);

      erp.paySupplierDebt(
        supplier: supplier,
        amount: 1000000.0,
        currency: AppCurrency.syp,
      );
      expect(supplier.debtBalanceSyp, closeTo(-1000000.0, 0.001));
      expect(erp.mainCashBoxSyp, closeTo(1000000.0, 0.001));
      expect(erp.mainCashBox, closeTo(1000.0, 0.001));

      erp.collectFromSupplierCredit(
        supplier: supplier,
        amount: 1500000.0,
        currency: AppCurrency.syp,
      );
      expect(supplier.debtBalanceSyp, closeTo(500000.0, 0.001));
      expect(erp.mainCashBoxSyp, closeTo(2500000.0, 0.001));
      expect(erp.mainCashBox, closeTo(1000.0, 0.001));
    });
  });

  group('4. Persistence', () {
    test('Supplier payments ledger survives JSON round-trip', () {
      final erp = freshErp();
      final supplier = SupplierModel(
        id: 'sup_bi_json',
        name: 'مورد الحفظ',
        phone: '',
        location: '',
      );
      erp.suppliers.add(supplier);
      erp.paySupplierDebt(
        supplier: supplier,
        amount: 100.0,
        currency: AppCurrency.usd,
      );
      final restored = SupplierModel.fromJson(supplier.toJson());
      expect(restored.payments, hasLength(1));
      expect(restored.payments.first['direction'], 'pay');
      expect(restored.payments.first['amount'], closeTo(100.0, 0.001));
    });
  });

  group('5. Dashboard unified Receivable / Payable totals', () {
    test('Strict scope: suppliers & agents only — retail customers excluded',
        () {
      final erp = freshErp();
      erp.clients = [
        // Approved agent owing 500 → receivable.
        ClientModel(
          id: 'c_u1',
          name: 'معتمد مدين',
          clientType: 'معتمد مصنع',
          debtBalance: 500.0,
        ),
        // RETAIL customer holding a 200 أمانة → fully EXCLUDED (both sides).
        ClientModel(
          id: 'c_u2',
          name: 'زبون جزافي',
          clientType: 'زبون معمل',
          debtBalance: -200.0,
        ),
      ];
      erp.suppliers = [
        // Supplier owed 300 → payable.
        SupplierModel(
          id: 's_u1',
          name: 'مورد له',
          phone: '',
          location: '',
          debtBalance: 300.0,
        ),
        // Supplier holding our 100 advance → receivable (role does not
        // restrict the side; the NET balance direction does).
        SupplierModel(
          id: 's_u2',
          name: 'مورد عليه دفعة مقدمة',
          phone: '',
          location: '',
          debtBalance: -100.0,
        ),
      ];

      // Receivables (لنا) = 500 agent due + 100 supplier advance.
      expect(erp.totalReceivablesOf(AppCurrency.usd), closeTo(600.0, 0.001));
      // Payables (علينا) = 300 supplier due; the retail أمانة is excluded.
      expect(erp.totalPayablesOf(AppCurrency.usd), closeTo(300.0, 0.001));

      final lists = erp.partyBalances();
      expect(
        lists.receivables.map((r) => r.name).toList(),
        containsAll(['معتمد مدين', 'مورد عليه دفعة مقدمة']),
      );
      expect(lists.payables.map((r) => r.name), isNot(contains('زبون جزافي')));
      expect(
        lists.receivables.any((r) => r.name == 'زبون جزافي'),
        isFalse,
      );

      // Drill-down rows carry the role badges of each counterparty.
      final agentRow = lists.receivables.firstWhere((r) => r.id == 'c_u1');
      expect(agentRow.roleLabel, 'معتمد مصنع');
      expect(agentRow.isSupplier, isFalse);
      final supplierRow = lists.receivables.firstWhere((r) => r.id == 's_u2');
      expect(supplierRow.roleLabel, 'مورد');
      expect(supplierRow.isSupplier, isTrue);
      expect(supplierRow.usdAmount, closeTo(100.0, 0.001));
    });

    test('Net-balance classification with SYP register and opening legacies',
        () {
      final erp = freshErp();
      erp.clients = [
        ClientModel(
          id: 'c_l1',
          name: 'معتمد ليرة',
          clientType: 'معتمد مصنع',
          debtBalanceSyp: 1000000.0,
        ),
        // Dealer that owns the carried-forward opening record below.
        ClientModel(
          id: 'c_l2',
          name: 'عميل سابق',
          clientType: 'معتمد مصنع',
          debtBalanceSyp: 0.0,
        ),
      ];
      erp.suppliers = [
        SupplierModel(
          id: 's_l1',
          name: 'مورد دفعة مقدمة ليرة',
          phone: '',
          location: '',
          debtBalanceSyp: -250000.0,
        ),
        SupplierModel(
          id: 's_l2',
          name: 'مورد مستحق ليرة',
          phone: '',
          location: '',
          debtBalanceSyp: 400000.0,
        ),
      ];
      erp.openingEntry.legacyFinancials.addAll([
        LegacyFinancialRecordModel(
          id: 'lg_c',
          category: 'clients',
          name: 'عميل سابق',
          currency: AppCurrency.syp,
          amount: 300000.0,
        ),
        LegacyFinancialRecordModel(
          id: 'lg_s',
          category: 'suppliers',
          name: 'مورد سابق (قيد غير مرتبط)',
          currency: AppCurrency.syp,
          amount: 150000.0,
        ),
        // A retail customer's opening record must NOT count anymore.
        LegacyFinancialRecordModel(
          id: 'lg_r',
          category: 'clients',
          name: 'زبون جزائي سابق',
          currency: AppCurrency.syp,
          amount: 900000.0,
        ),
      ]);

      // SYP receivables: 1,000,000 agent due + 250,000 supplier advance +
      // 300,000 agent opening record (linked by name). Retail opening 900,000
      // belongs to no dealer → excluded under the strict scope.
      expect(
        erp.totalReceivablesOf(AppCurrency.syp),
        closeTo(1550000.0, 0.001),
      );
      // SYP payables: 400,000 supplier due + 150,000 orphan supplier opening.
      expect(erp.totalPayablesOf(AppCurrency.syp), closeTo(550000.0, 0.001));

      // USD side stays untouched by SYP balances.
      expect(erp.totalReceivablesOf(AppCurrency.usd), closeTo(0.0, 0.001));
      expect(erp.totalPayablesOf(AppCurrency.usd), closeTo(0.0, 0.001));

      // The orphan supplier opening record appears as its own payable row.
      final lists = erp.partyBalances();
      final orphan = lists.payables.firstWhere((r) => r.id == 'lg_s');
      expect(orphan.roleLabel, 'مورد');
      expect(orphan.sypAmount, closeTo(150000.0, 0.001));
    });
  });

  group('6. Drill-down modal', () {
    Future<void> pumpModal(
      WidgetTester tester,
      ERPProvider erp, {
      required bool receivableSide,
    }) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ChangeNotifierProvider<ERPProvider>.value(
          value: erp,
          child: MaterialApp(
            home: Scaffold(
              body: PartyBalancesModal(receivableSide: receivableSide),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Receivables list shows suppliers & agents with role badges, '
        'never retail customers or workers', (tester) async {
      final erp = freshErp();
      erp.clients = [
        ClientModel(
          id: 'c_m1',
          name: 'معتمد العرض',
          clientType: 'معتمد مصنع',
          debtBalance: 700.0,
        ),
        ClientModel(
          id: 'c_m2',
          name: 'زبون جزافي',
          clientType: 'زبون معمل',
          debtBalance: 999.0,
        ),
      ];
      erp.suppliers = [
        SupplierModel(
          id: 's_m1',
          name: 'مورد بدفعة مقدمة',
          phone: '',
          location: '',
          debtBalance: -150.0,
        ),
      ];

      await pumpModal(tester, erp, receivableSide: true);

      // Dealer and the supplier holding our advance are listed.
      expect(find.text('معتمد العرض'), findsOneWidget);
      expect(find.text('مورد بدفعة مقدمة'), findsOneWidget);
      // Role badges rendered.
      expect(find.text('معتمد مصنع'), findsWidgets);
      expect(find.text('مورد'), findsWidgets);
      // The retail customer (even with a big due) is never listed here.
      expect(find.text('زبون جزافي'), findsNothing);
    });

    testWidgets('Payables list shows who the company owes, with exact totals',
        (tester) async {
      final erp = freshErp();
      erp.suppliers = [
        SupplierModel(
          id: 's_m2',
          name: 'مورد مستحق',
          phone: '',
          location: '',
          debtBalance: 300.0,
        ),
      ];
      erp.clients = [
        ClientModel(
          id: 'c_m3',
          name: 'معتمد له أمانة',
          clientType: 'معتمد مصنع',
          debtBalance: -200.0,
        ),
      ];

      await pumpModal(tester, erp, receivableSide: false);

      expect(find.text('مورد مستحق'), findsOneWidget);
      expect(find.text('معتمد له أمانة'), findsOneWidget);
      // Footer total = 300 USD + 200 USD = 500.
      expect(find.textContaining('500'), findsWidgets);
    });
  });
}
