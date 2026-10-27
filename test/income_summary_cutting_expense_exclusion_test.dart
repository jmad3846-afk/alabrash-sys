import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Income Summary (ملخص الدخل) Cutting Expenses Exclusion Tests', () {
    test('incomeSummaryExpensesOf and incomeSummaryNetProfitOf exclude direct cutting expenses', () async {
      final erp = ERPProvider();
      await erp.populateComprehensiveSeedData(lockOpeningEntry: true);

      // Verify initial direct expenses and cutting expenses
      final initialCuttingUsd = erp.totalCuttingExpensesOf(AppCurrency.usd);
      final initialCuttingSyp = erp.totalCuttingExpensesOf(AppCurrency.syp);
      final initialDirectExpensesUsd = erp.totalDirectExpensesOf(AppCurrency.usd);
      final initialDirectExpensesSyp = erp.totalDirectExpensesOf(AppCurrency.syp);

      // Income Summary expenses must exclude cutting expenses
      expect(
        erp.incomeSummaryExpensesOf(AppCurrency.usd),
        closeTo(initialDirectExpensesUsd - initialCuttingUsd, 0.01),
      );
      expect(
        erp.incomeSummaryExpensesOf(AppCurrency.syp),
        closeTo(initialDirectExpensesSyp - initialCuttingSyp, 0.01),
      );

      // Income Summary net profit must exclude cutting expenses (profit is higher by cutting expense)
      expect(
        erp.incomeSummaryNetProfitOf(AppCurrency.usd),
        closeTo(erp.netOperatingProfitOf(AppCurrency.usd) + initialCuttingUsd, 0.01),
      );
      expect(
        erp.incomeSummaryNetProfitOf(AppCurrency.syp),
        closeTo(erp.netOperatingProfitOf(AppCurrency.syp) + initialCuttingSyp, 0.01),
      );

      // Add a block cutting operation to produce new cutting expenses
      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'test_blk_cut_summary',
          blockCode: 'BLK-CS-99',
          typeName: 'رخام روزا',
          grade: 'ممتاز',
          supplierId: 'sup1',
          supplierName: 'مورد اختبار',
          weightTons: 20.0,
          tonCost: 300.0, // base cost = 6000 USD
        ),
      );

      const feePercent = 0.08;
      const inputTons = 10.0;
      const avgTonCost = 300.0;
      const newCuttingFee = inputTons * avgTonCost * feePercent; // 240.0 USD

      erp.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            typeName: 'رخام روزا',
            grade: 'ممتاز',
            isGranite: false,
            inputTons: inputTons,
            avgTonCost: avgTonCost,
            feePercent: feePercent,
            thicknessCm: 2.0,
            category: 'متر مربع',
            outputQty: 85.0,
            netCost: 35.0,
            salePrice: 45.0,
          ),
        ],
        wasteValue: 0.0,
      );

      // Cutting expenses increased by 240 USD
      expect(
        erp.totalCuttingExpensesOf(AppCurrency.usd) - initialCuttingUsd,
        closeTo(newCuttingFee, 0.01),
      );

      // Total direct expenses increased by 240 USD
      expect(
        erp.totalDirectExpensesOf(AppCurrency.usd) - initialDirectExpensesUsd,
        closeTo(newCuttingFee, 0.01),
      );

      // BUT Income Summary expenses must NOT increase with cutting expenses!
      expect(
        erp.incomeSummaryExpensesOf(AppCurrency.usd),
        closeTo(initialDirectExpensesUsd - initialCuttingUsd, 0.01),
      );

      // And Income Summary net profit remains unaffected by the cutting fee
      expect(
        erp.incomeSummaryNetProfitOf(AppCurrency.usd),
        closeTo(erp.totalRevenuesOf(AppCurrency.usd) - erp.incomeSummaryExpensesOf(AppCurrency.usd), 0.01),
      );
    });
  });
}
