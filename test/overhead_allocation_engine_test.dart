import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ERPProvider> freshErp() async {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    await erp.loadFuture;
    // Wipe the demo seed so pool math reflects only this test's data.
    erp.factoryInvoices.clear();
    erp.workshopInvoices.clear();
    erp.factoryOrders.clear();
    erp.workshopOrders.clear();
    erp.factoryBlocks.clear();
    erp.factoryWarehouse.clear();
    erp.workshopStock.clear();
    erp.simpleTailorings.clear();
    erp.complexTailorings.clear();
    erp.scrapItems.clear();
    erp.expenseRecords.clear();
    erp.workdayEntries.clear();
    erp.wasteLogs.clear();
    erp.adjustmentInvoices.clear();
    erp.returnInvoices.clear();
    erp.advanceRepayments.clear();
    erp.surplusCosts.clear();
    erp.assetSaleRecords.clear();
    erp.serviceInvoices.clear();
    erp.cuttingOperations.clear();
    erp.mainCashBox = 10000;
    erp.mainCashBoxSyp = 10000;
    return erp;
  }

  void customType(ERPProvider erp, String id, String name) {
    erp.expenseTypes.add(ExpenseTypeModel(id: id, name: name));
  }

  ExpenseRecordModel rec(
    String id,
    String typeId,
    double amount, {
    String currency = AppCurrency.usd,
  }) => ExpenseRecordModel(
    id: id,
    typeId: typeId,
    amount: amount,
    currency: currency,
  );

  group('Controlled operational expense pool', () {
    test('custom general types are permanently OUT of the overhead pool', () async {
      final erp = await freshErp();
      customType(erp, 't_general', 'ضيافة ومشاوير');
      erp.mainCashBox = 5000;
      erp.addExpenseRecord(rec('e1', 't_general', 500));

      // Standard expense: deducted cash but never feeds the pool.
      expect(erp.coreOperationalExpensesTotalOf(AppCurrency.usd), 0);
      expect(erp.mainCashBox, 4500);

      // Classification is strictly locked to the two designated families;
      // a custom type can never join the pool (no toggle exists).
      expect(
        erp.isLockedOperationalType(
          erp.expenseTypes.firstWhere((t) => t.id == 't_general'),
        ),
        isFalse,
      );
      expect(
        erp.coreOperationalExpensesTotalOf(AppCurrency.usd),
        0,
      );
    });

    test('worker wage payments are always core operational', () async {
      final erp = await freshErp();
      erp.mainCashBox = 5000;
      // Wage records land with the auto wage typeId even when the type
      // row itself is missing (legacy ledgers).
      erp.addExpenseRecord(rec('w1', 'workforce_wages_expense', 300));
      erp.addExpenseRecord(rec('w2', 'salaries_and_wages_expense', 200));
      expect(
        erp.coreOperationalExpensesTotalOf(AppCurrency.usd),
        closeTo(500, 0.001),
      );
      expect(
        erp.operatingExpensesForPeriodOf(AppCurrency.usd),
        closeTo(500, 0.001),
      );
    });

    test('only the two locked types (cutting & wages) are operational', () async {
      final erp = await freshErp();
      erp.mainCashBox = 5000;
      erp.addExpenseRecord(rec('c1', 'cutting_processing_expense', 150));
      expect(
        erp.coreOperationalExpensesTotalOf(AppCurrency.usd),
        closeTo(150, 0.001),
      );
      expect(
        erp.isLockedOperationalType(
          ExpenseTypeModel(
            id: ERPProvider.cuttingExpenseTypeId,
            name: 'مصاريف القص',
          ),
        ),
        isTrue,
      );
      expect(
        erp.isLockedOperationalType(
          ExpenseTypeModel(id: 'workforce_wages_expense', name: 'أجور العمال'),
        ),
        isTrue,
      );
      // A lookalike custom type is NOT operational.
      expect(
        erp.isLockedOperationalType(
          ExpenseTypeModel(id: 't_x', name: 'كهرباء ومياه المعمل'),
        ),
        isFalse,
      );
    });
  });

  group('Dynamic rolling overhead rate', () {
    Future<ERPProvider> erpWithCut({double fee = 0.12}) async {
      final erp = await freshErp();
      erp.mainCashBox = 10000;
      erp.factoryBlocks = [
        FactoryBlockModel(
          id: 'blk1',
          blockCode: 'B1',
          typeName: 'رخام اختبار',
          grade: 'أولى',
          supplierId: 's1',
          supplierName: 'مورد',
          weightTons: 10,
          tonCost: 100,
        ),
      ];
      erp.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            currency: AppCurrency.usd,
            typeName: 'رخام اختبار',
            grade: 'أولى',
            isGranite: false,
            inputTons: 10,
            avgTonCost: 100,
            feePercent: fee,
            thicknessCm: 2,
            category: 'متر مربع',
            outputQty: 50,
            netCost: 0,
            salePrice: 150,
          ),
        ],
        wasteValue: 0,
      );
      return erp;
    }

    test('the chosen percentage is baked into the batch (not the fixed 9%)',
        () async {
      final erp = await erpWithCut(fee: 0.12);
      final op = erp.cuttingOperations.single;
      // Material-only unit cost 1000/50 = 20; stored rate must be 12%.
      expect(op.netCostPerUnit, closeTo(20, 0.001));
      expect(op.cuttingFeePercentage, closeTo(0.12, 0.0001));
      // Warehouse lot carries material + 12% overhead.
      expect(erp.factoryWarehouse.single.netCostPerUnit, closeTo(22.4, 0.001));
    });

    test('recovered overhead uses each batch stored rate', () async {
      final erp = await erpWithCut(fee: 0.12);
      erp.clients = [
        ClientModel(id: 'cl1', name: 'معتمد', clientType: 'معتمد مصنع'),
      ];
      final w = erp.factoryWarehouse.single;
      // Sell 10 m² carrying {batch: 1} units.
      final sale = FactoryInvoiceModel(
        id: 'fi_sale1',
        invoiceNo: 'FAC-1',
        date: DateTime(2026, 11, 14),
        partyId: 'cl1',
        partyName: 'معتمد',
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: w.id,
            description: '${w.typeName} ${w.grade} ${w.thicknessCm}سم',
            typeName: w.typeName,
            grade: w.grade,
            lengthCm: 100,
            widthCm: 100,
            quantity: 10,
            unitPrice: 150,
            unitCost: w.netCostPerUnit,
            itemCategory: 'meter',
            meterUnit: 'متر مربع',
            batchUnitsPerUnit: {erp.cuttingOperations.single.id: 1},
          ),
        ],
        currency: AppCurrency.usd,
      );
      expect(erp.addFactoryPOSInvoice(sale), isTrue);

      // Recovered per sold meter = material unit cost 20 × 12% = 2.4 × 10.
      expect(
        erp.collectedStandardCuttingOverheadOf(AppCurrency.usd),
        closeTo(24, 0.001),
      );
    });

    test('suggested rate = uncovered gap over the cutting material base',
        () async {
      final erp = await erpWithCut(fee: 0.12);
      // base = 10t × 100$ = 1000$. No expenses, no coverage yet -> 0%.
      expect(
        erp.cuttingMaterialCostBaseOf(AppCurrency.usd),
        closeTo(1000, 0.001),
      );
      expect(erp.dynamicOverheadRateOf(AppCurrency.usd), closeTo(0, 0.0001));

      // Core expense of 100$ -> suggestion 10%. Under the locked rule
      // only wages/cutting qualify, so the entry uses the wage type.
      erp.mainCashBox = 5000;
      erp.addExpenseRecord(rec('ce1', 'workforce_wages_expense', 100));
      expect(
        erp.dynamicOverheadRateOf(AppCurrency.usd),
        closeTo(0.10, 0.0001),
      );

      // A general (non-core) expense of 500$ must NOT move the rate.
      customType(erp, 't_gen', 'ضيافة');
      erp.addExpenseRecord(rec('ge1', 't_gen', 500));
      expect(
        erp.dynamicOverheadRateOf(AppCurrency.usd),
        closeTo(0.10, 0.0001),
      );

      // Coverage from a services income shrinks the gap in real time:
      // collected overhead so far (none sold) + service revenue 40$ ->
      // gap = 100 - 40 = 60 -> 6%.
      erp.serviceInvoices.add(
        ServiceInvoiceModel(
          id: 'svc1',
          invoiceNumber: 'SVC-1',
          clientId: 'cl-x',
          clientName: 'عميل',
          invoiceDate: DateTime(2026, 11, 14),
          currency: AppCurrency.usd,
          items: [
            ServiceInvoiceItemModel(
              id: 'si1',
              serviceName: 'قص خارجي',
              customDescription: '',
              quantity: 1,
              unitPrice: 40,
            ),
          ],
        ),
      );
      expect(
        erp.dynamicOverheadRateOf(AppCurrency.usd),
        closeTo(0.06, 0.0001),
      );
    });

    test('variance reports surplus when coverage exceeds core expenses',
        () async {
      final erp = await erpWithCut(fee: 0.12);
      erp.mainCashBox = 5000;
      erp.addExpenseRecord(rec('v1', 'salaries_and_wages_expense', 100));
      // Nothing sold => coverage 0, core 100 => deficit variance.
      expect(
        erp.operatingCostVarianceOf(AppCurrency.usd),
        closeTo(-100, 0.001),
      );
      // Services covering more than the pool flip it to surplus.
      erp.serviceInvoices.add(
        ServiceInvoiceModel(
          id: 'svc2',
          invoiceNumber: 'SVC-2',
          clientId: 'cl-x',
          clientName: 'عميل',
          invoiceDate: DateTime(2026, 11, 14),
          currency: AppCurrency.usd,
          items: [
            ServiceInvoiceItemModel(
              id: 'si2',
              serviceName: 'قص خارجي',
              customDescription: '',
              quantity: 1,
              unitPrice: 150,
            ),
          ],
        ),
      );
      expect(
        erp.operatingCostVarianceOf(AppCurrency.usd),
        closeTo(50, 0.001),
      );
    });
  });
}
