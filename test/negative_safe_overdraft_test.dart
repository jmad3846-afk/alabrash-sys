import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Negative Safe Balances (Overdraft) for Sidebar Expenses & Supplier Payments', () {
    test('1. Sidebar Expense in USD exceeding main safe drives mainCashBox negative (Overdraft)', () {
      final erp = ERPProvider();
      erp.mainCashBox = 100.0; // Current safe balance: 100 USD

      final initialExpenses = erp.expenseRecordsTotalOf(AppCurrency.usd);

      // Record an expense of 350 USD from Sidebar Expenses (exceeds 100 USD available)
      final expense = ExpenseRecordModel(
        id: 'exp_test_usd_overdraft',
        typeId: 'et1',
        amount: 350.0,
        currency: AppCurrency.usd,
        personName: 'ورشة الصيانة',
        description: 'صيانة طارئة للمعدات',
      );

      erp.addExpenseRecord(expense);

      // System must proceed and deduct full amount, driving safe negative
      expect(erp.mainCashBox, closeTo(-250.0, 0.001));
      expect(erp.expenseRecords.contains(expense), isTrue);
      expect(erp.expenseRecordsTotalOf(AppCurrency.usd) - initialExpenses, closeTo(350.0, 0.001));
    });

    test('2. Sidebar Expense in SYP exceeding main safe drives mainCashBoxSyp negative (Overdraft)', () {
      final erp = ERPProvider();
      erp.mainCashBoxSyp = 500000.0; // Current safe balance: 500,000 SYP

      final initialExpensesSyp = erp.expenseRecordsTotalOf(AppCurrency.syp);

      // Record an expense of 1,500,000 SYP from Sidebar Expenses
      final expense = ExpenseRecordModel(
        id: 'exp_test_syp_overdraft',
        typeId: 'et3',
        amount: 1500000.0,
        currency: AppCurrency.syp,
        personName: 'شركة الكهرباء',
        description: 'فاتورة كهرباء صناعية متأخرة',
      );

      erp.addExpenseRecord(expense);

      // System must proceed and deduct full amount, driving safe negative
      expect(erp.mainCashBoxSyp, closeTo(-1000000.0, 0.001));
      expect(erp.expenseRecords.contains(expense), isTrue);
      expect(erp.expenseRecordsTotalOf(AppCurrency.syp) - initialExpensesSyp, closeTo(1500000.0, 0.001));
    });

    test('3. Supplier Debt Payment in USD exceeding safe balance proceeds and drives safe negative', () {
      final erp = ERPProvider();
      erp.mainCashBox = 200.0; // Available cash: 200 USD

      final supplier = erp.suppliers.first;
      supplier.debtBalance = 1500.0;

      // Pay 800 USD to supplier (exceeds 200 USD cash, but within 1500 USD debt)
      final ok = erp.paySupplierDebt(
        supplier: supplier,
        amount: 800.0,
        currency: AppCurrency.usd,
      );

      expect(ok, isTrue);
      expect(supplier.debtBalance, closeTo(700.0, 0.001));
      // Safe dropped from 200 to -600 USD
      expect(erp.mainCashBox, closeTo(-600.0, 0.001));
    });

    test('4. Supplier Debt Payment in SYP exceeding safe balance proceeds and drives safe negative', () {
      final erp = ERPProvider();
      erp.mainCashBoxSyp = 1000000.0; // Available cash: 1,000,000 SYP

      final supplier = erp.suppliers.first;
      supplier.debtBalanceSyp = 5000000.0;

      // Pay 3,000,000 SYP to supplier (exceeds 1,000,000 SYP cash, but within 5,000,000 SYP debt)
      final ok = erp.paySupplierDebt(
        supplier: supplier,
        amount: 3000000.0,
        currency: AppCurrency.syp,
      );

      expect(ok, isTrue);
      expect(supplier.debtBalanceSyp, closeTo(2000000.0, 0.001));
      // Safe dropped from 1,000,000 to -2,000,000 SYP
      expect(erp.mainCashBoxSyp, closeTo(-2000000.0, 0.001));
    });

    test('5. Supplier Purchase Invoice Payment exceeding safe balance proceeds and drives safe negative', () {
      final erp = ERPProvider();
      erp.mainCashBox = 50.0; // Only 50 USD in safe

      final supplier = erp.suppliers.first;
      final invoice = FactoryInvoiceModel(
        id: 'fi_sup_od_1',
        invoiceNo: 'PUR-OD-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'blk_od_1',
            description: 'كتلة مرمر',
            typeName: 'مرمر أبيض',
            grade: 'نخب أول',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 100.0,
          ),
        ],
        advancePayment: 0.0, // Remaining balance = 1000 USD
        currency: AppCurrency.usd,
      );
      erp.factoryInvoices.add(invoice);
      supplier.debtBalance = 1000.0;

      // Pay 600 USD on invoice (exceeds 50 USD in safe)
      final ok = erp.paySupplierInvoice(invoice, 600.0);

      expect(ok, isTrue);
      expect(invoice.advancePayment, closeTo(600.0, 0.001));
      expect(invoice.remainingBalance, closeTo(400.0, 0.001));
      expect(erp.mainCashBox, closeTo(-550.0, 0.001));
    });

    test('6. Targeted Bypassing: Other operations (Staff Wages, Cash Transfers) still strictly enforce balance checks', () {
      final erp = ERPProvider();
      erp.mainCashBox = 100.0;

      final staff = erp.staffList.first;
      staff.totalEarned = 500.0;

      // Staff wage payment exceeding safe balance MUST FAIL
      final wageOk = erp.payStaffWages(staff, 300.0, AppCurrency.usd);
      expect(wageOk, isFalse);
      expect(erp.mainCashBox, closeTo(100.0, 0.001)); // Untouched

      // Staff advance payment exceeding safe balance MUST FAIL
      final advOk = erp.payStaffAdvance(staff, 250.0, AppCurrency.usd);
      expect(advOk, isFalse);
      expect(erp.mainCashBox, closeTo(100.0, 0.001)); // Untouched

      // Cash transfer exceeding balance MUST FAIL
      final transferOk = erp.transferCash(
        fromBox: 'main',
        toBox: 'scrap',
        currency: AppCurrency.usd,
        amount: 500.0,
      );
      expect(transferOk, isFalse);
      expect(erp.mainCashBox, closeTo(100.0, 0.001)); // Untouched
    });

    test('7. SmartNumberFormat and AppCurrency accurately format negative deficits', () {
      expect((-200.0).fmt, '-200');
      expect((-50000.0).fmt, '-50000');
      expect(AppCurrency.dual(-200.0, -50000.0), '-200 \$ • -50000 ل.س');
      expect(AppCurrency.single(-200.0, AppCurrency.usd), '-200 \$');
      expect(AppCurrency.single(-50000.0, AppCurrency.syp), '-50000 ل.س');
    });

    test('8. Every expense added regardless of type (custom or predefined) deducts from the specified safe', () {
      final erp = ERPProvider();
      erp.mainCashBox = 1000.0;
      erp.scrapCashBox = 500.0;
      erp.orderCashBox = 300.0;

      // Add custom expense type
      final customType = ExpenseTypeModel(
        id: 'custom_type_1',
        name: 'مصاريف تسويق وإعلانات',
        description: 'إعلانات طرق وحملات ممولة',
      );
      erp.addExpenseType(customType);

      // 1. Add expense with custom type -> deducts from main safe
      erp.addExpenseRecord(ExpenseRecordModel(
        id: 'exp_c1',
        typeId: customType.id,
        amount: 250.0,
        currency: AppCurrency.usd,
      ));
      expect(erp.mainCashBox, closeTo(750.0, 0.001));

      // 2. Add expense under block purchase expense type via sidebar -> deducts from safe
      erp.addExpenseRecord(ExpenseRecordModel(
        id: 'exp_c2',
        typeId: ERPProvider.blockPurchaseExpenseTypeId,
        amount: 300.0,
        currency: AppCurrency.usd,
      ));
      expect(erp.mainCashBox, closeTo(450.0, 0.001));

      // 3. Add expense under cutting expense type via sidebar -> deducts from safe
      erp.addExpenseRecord(ExpenseRecordModel(
        id: 'exp_c3',
        typeId: ERPProvider.cuttingExpenseTypeId,
        amount: 150.0,
        currency: AppCurrency.usd,
      ));
      expect(erp.mainCashBox, closeTo(300.0, 0.001));

      // 4. Add expense explicitly assigned to scrap box -> deducts from scrap safe
      erp.addExpenseRecord(ExpenseRecordModel(
        id: 'exp_c4',
        typeId: customType.id,
        amount: 120.0,
        currency: AppCurrency.usd,
        cashBox: 'scrap',
      ));
      expect(erp.scrapCashBox, closeTo(380.0, 0.001));
    });
  });
}
