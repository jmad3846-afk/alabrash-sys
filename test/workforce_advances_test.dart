import 'package:flutter_test/flutter_test.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  group('Workforce, Wages, and Advances Lifecycle', () {
    test('Add new worker with role, phone, and location', () {
      final erp = ERPProvider();

      final initialWorkersCount =
          erp.staffList.where((s) => s.category == 'عمال').length;
      final initialMastersCount =
          erp.staffList.where((s) => s.category == 'معلمين').length;
      final initialAdminsCount =
          erp.staffList.where((s) => s.category == 'إداريين').length;

      // Add Worker
      erp.addStaff(
        StaffModel(
          id: 'w_test_1',
          name: 'عامل تجريبي',
          category: 'عمال',
          phone: '0911111111',
          location: 'حمص - الورشة',
        ),
      );

      // Add Master / Specialist
      erp.addStaff(
        StaffModel(
          id: 'm_test_1',
          name: 'معلم تجريبي',
          category: 'معلمين',
          phone: '0922222222',
          location: 'دمشق - المعمل',
        ),
      );

      // Add Administrator
      erp.addStaff(
        StaffModel(
          id: 'a_test_1',
          name: 'إداري تجريبي',
          category: 'إداريين',
          phone: '0933333333',
          location: 'المكتب الرئيسي',
        ),
      );

      expect(
        erp.staffList.where((s) => s.category == 'عمال').length,
        initialWorkersCount + 1,
      );
      expect(
        erp.staffList.where((s) => s.category == 'معلمين').length,
        initialMastersCount + 1,
      );
      expect(
        erp.staffList.where((s) => s.category == 'إداريين').length,
        initialAdminsCount + 1,
      );

      final addedWorker = erp.staffList.firstWhere((s) => s.id == 'w_test_1');
      expect(addedWorker.name, 'عامل تجريبي');
      expect(addedWorker.category, 'عمال');
      expect(addedWorker.phone, '0911111111');
      expect(addedWorker.location, 'حمص - الورشة');
    });

    test('Pay Wages routes to Expenses under Salaries & Wages and deducts from Main Safe', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000;
      erp.mainCashBoxSyp = 50000000;

      final staff = StaffModel(
        id: 'staff_wages_test',
        name: 'أحمد النجار',
        category: 'معلمين',
        phone: '0944444444',
        location: 'المعمل',
      );
      erp.addStaff(staff);

      final initialCashUsd = erp.cashOf('main', AppCurrency.usd);
      final initialCashSyp = erp.cashOf('main', AppCurrency.syp);

      // Pay USD Wage
      final payUsdOk = erp.payStaffWages(staff, 250, AppCurrency.usd);
      expect(payUsdOk, isTrue);
      expect(erp.cashOf('main', AppCurrency.usd), initialCashUsd - 250);

      final wageExpUsd = erp.expenseRecords.lastWhere((e) => e.staffId == staff.id);
      expect(wageExpUsd.amount, 250);
      expect(wageExpUsd.currency, AppCurrency.usd);
      expect(wageExpUsd.typeId, 'salaries_and_wages_expense');

      // Pay SYP Wage
      final paySypOk = erp.payStaffWages(staff, 1500000, AppCurrency.syp);
      expect(paySypOk, isTrue);
      expect(erp.cashOf('main', AppCurrency.syp), initialCashSyp - 1500000);

      final wageExpSyp = erp.expenseRecords.lastWhere((e) => e.staffId == staff.id);
      expect(wageExpSyp.amount, 1500000);
      expect(wageExpSyp.currency, AppCurrency.syp);
      expect(wageExpSyp.typeId, 'salaries_and_wages_expense');

      // Paying wages has NO relation to advances
      expect(staff.cashAdvancesDisbursed, 0.0);
      expect(staff.cashAdvancesDisbursedSyp, 0.0);
    });

    test('Pay Advance routes to Expenses under Advances, deducts from Main Safe, and updates balance', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000;
      erp.mainCashBoxSyp = 50000000;

      final staff = StaffModel(
        id: 'staff_adv_test',
        name: 'سامر الحداد',
        category: 'عمال',
        phone: '0955555555',
        location: 'حمص',
      );
      erp.addStaff(staff);

      final initialCashUsd = erp.cashOf('main', AppCurrency.usd);
      final initialCashSyp = erp.cashOf('main', AppCurrency.syp);

      // Issue USD Advance
      final advUsdOk = erp.payStaffAdvance(staff, 100, AppCurrency.usd);
      expect(advUsdOk, isTrue);
      expect(erp.cashOf('main', AppCurrency.usd), initialCashUsd - 100);
      expect(staff.cashAdvancesDisbursed, 100);

      final advExpUsd = erp.expenseRecords.lastWhere((e) => e.staffId == staff.id);
      expect(advExpUsd.amount, 100);
      expect(advExpUsd.currency, AppCurrency.usd);
      expect(advExpUsd.typeId, 'advances_expense');

      // Issue SYP Advance
      final advSypOk = erp.payStaffAdvance(staff, 700000, AppCurrency.syp);
      expect(advSypOk, isTrue);
      expect(erp.cashOf('main', AppCurrency.syp), initialCashSyp - 700000);
      expect(staff.cashAdvancesDisbursedSyp, 700000);

      final advExpSyp = erp.expenseRecords.lastWhere((e) => e.staffId == staff.id);
      expect(advExpSyp.amount, 700000);
      expect(advExpSyp.currency, AppCurrency.syp);
      expect(advExpSyp.typeId, 'advances_expense');
    });

    test('Collect Advance Scenario A (Same Currency) enters Main Safe, deducts advance, and adds to Revenues', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000;
      erp.mainCashBoxSyp = 50000000;

      final staff = StaffModel(
        id: 'staff_col_same_test',
        name: 'ياسر الكهربائي',
        category: 'معلمين',
        phone: '0966666666',
        location: 'حماة',
      );
      erp.addStaff(staff);

      // Issue 200 USD advance
      erp.payStaffAdvance(staff, 200, AppCurrency.usd);
      expect(staff.cashAdvancesDisbursed, 200);

      final cashBefore = erp.cashOf('main', AppCurrency.usd);
      final revBefore = erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd);

      // Partial repayment: 80 USD
      final collectOk = erp.collectStaffAdvance(
        staff: staff,
        originalCurrency: AppCurrency.usd,
        collectedCurrency: AppCurrency.usd,
        collectedAmount: 80,
        deductedAmount: 80,
      );
      expect(collectOk, isTrue);

      // Safe increased
      expect(erp.cashOf('main', AppCurrency.usd), cashBefore + 80);
      // Advance reduced
      expect(staff.cashAdvancesDisbursed, 120);
      // Revenue increased
      expect(
        erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd),
        revBefore + 80,
      );
      expect(erp.advanceRepayments.last.staffName, staff.name);
      expect(erp.advanceRepayments.last.collectedAmount, 80);
    });

    test('Collect Advance Scenario B Sub-case 1: Original advance was paid in SYP, collected in USD', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000;
      erp.mainCashBoxSyp = 50000000;

      final staff = StaffModel(
        id: 'staff_col_b1_test',
        name: 'خالد الفني',
        category: 'معلمين',
        phone: '0977777777',
        location: 'طرطوس',
      );
      erp.addStaff(staff);

      // Issue 2,800,000 SYP advance
      erp.payStaffAdvance(staff, 2800000, AppCurrency.syp);
      expect(staff.cashAdvancesDisbursedSyp, 2800000);

      final usdSafeBefore = erp.cashOf('main', AppCurrency.usd);
      final usdRevBefore = erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd);

      // Repay in USD: 100 USD at daily exchange rate 14000
      // Field 1 (Amount): 100 USD
      // Field 2 (Daily Rate): 14000
      // Deducted from SYP = 100 * 14000 = 1,400,000 SYP
      const field1Amount = 100.0;
      const field2Rate = 14000.0;
      const deductedSyp = field1Amount * field2Rate; // 1,400,000

      final ok = erp.collectStaffAdvance(
        staff: staff,
        originalCurrency: AppCurrency.syp,
        collectedCurrency: AppCurrency.usd,
        collectedAmount: field1Amount,
        deductedAmount: deductedSyp,
        exchangeRate: field2Rate,
      );
      expect(ok, isTrue);

      // 100 USD entered Main Safe
      expect(erp.cashOf('main', AppCurrency.usd), usdSafeBefore + 100);
      // 1,400,000 SYP deducted from SYP advance balance
      expect(staff.cashAdvancesDisbursedSyp, 2800000 - 1400000);
      // USD Revenue increased by 100
      expect(
        erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd),
        usdRevBefore + 100,
      );
    });

    test('Collect Advance Scenario B Sub-case 2: Original advance was paid in USD, collected in SYP', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000;
      erp.mainCashBoxSyp = 50000000;

      final staff = StaffModel(
        id: 'staff_col_b2_test',
        name: 'رامي المحاسب',
        category: 'إداريين',
        phone: '0988888888',
        location: 'اللاذقية',
      );
      erp.addStaff(staff);

      // Issue 150 USD advance
      erp.payStaffAdvance(staff, 150, AppCurrency.usd);
      expect(staff.cashAdvancesDisbursed, 150);

      final sypSafeBefore = erp.cashOf('main', AppCurrency.syp);
      final sypRevBefore = erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.syp);

      // Repay in SYP: 1,400,000 SYP at daily exchange rate 14000
      // Field 1 (Amount): 1,400,000 SYP
      // Field 2 (Daily Rate): 14000
      // Deducted from USD = 1,400,000 / 14000 = 100 USD
      const field1Amount = 1400000.0;
      const field2Rate = 14000.0;
      const deductedUsd = field1Amount / field2Rate; // 100 USD

      final ok = erp.collectStaffAdvance(
        staff: staff,
        originalCurrency: AppCurrency.usd,
        collectedCurrency: AppCurrency.syp,
        collectedAmount: field1Amount,
        deductedAmount: deductedUsd,
        exchangeRate: field2Rate,
      );
      expect(ok, isTrue);

      // 1,400,000 SYP entered Main Safe
      expect(erp.cashOf('main', AppCurrency.syp), sypSafeBefore + 1400000);
      // 100 USD deducted from USD advance balance
      expect(staff.cashAdvancesDisbursed, 150 - 100);
      // SYP Revenue increased by 1,400,000
      expect(
        erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.syp),
        sypRevBefore + 1400000,
      );
      // Included in totalRevenues
      expect(erp.totalRevenuesSyp >= sypRevBefore + 1400000, isTrue);
    });
  });
}
