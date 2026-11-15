import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';

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
}
