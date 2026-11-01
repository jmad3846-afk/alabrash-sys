import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

Future<ERPProvider> clean() async {
  final e = ERPProvider();
  await e.loadFuture;
  e.factoryInvoices.clear();
  e.workshopInvoices.clear();
  e.factoryOrders.clear();
  e.workshopOrders.clear();
  e.factoryBlocks.clear();
  e.factoryWarehouse.clear();
  e.workshopStock.clear();
  e.simpleTailorings.clear();
  e.complexTailorings.clear();
  e.scrapItems.clear();
  e.expenseRecords.clear();
  e.workdayEntries.clear();
  e.wasteLogs.clear();
  e.adjustmentInvoices.clear();
  e.returnInvoices.clear();
  e.advanceRepayments.clear();
  e.surplusCosts.clear();
  e.assetSaleRecords.clear();
  e.graniteAccountantPercentage = 0;
  e.mainCashBox = 10000;
  e.mainCashBoxSyp = 10000;
  e.suppliers.first.debtBalance = 0;
  e.suppliers.first.debtBalanceSyp = 0;
  e.clients.first.debtBalance = 0;
  e.clients.first.debtBalanceSyp = 0;
  return e;
}

FactoryInvoiceModel purchase(
  ERPProvider e,
  String c, {
  double freight = 0,
  double discount = 0,
}) => FactoryInvoiceModel(
  id: 'purchase',
  invoiceNo: 'P1',
  date: DateTime.now(),
  partyId: e.suppliers.first.id,
  partyName: e.suppliers.first.name,
  invoiceType: 'شراء_مورد',
  currency: c,
  shippingFee: freight,
  discountAmount: discount,
  items: [
    FactoryInvoiceItem(
      itemId: 'raw',
      description: 'test stone',
      typeName: 'test stone',
      grade: 'A',
      quantity: 10,
      unitPrice: 100,
      unitCost: 100,
    ),
  ],
);
FactoryInvoiceModel sale(
  ERPProvider e,
  FactoryWarehouseModel w, {
  String id = 'sale',
  double quantity = 20,
  double price = 20,
  double paid = 0,
}) => FactoryInvoiceModel(
  id: id,
  invoiceNo: id,
  date: DateTime.now(),
  partyId: e.clients.first.id,
  partyName: e.clients.first.name,
  invoiceType: 'بيع_معتمد',
  currency: w.currency,
  advancePayment: paid,
  items: [
    FactoryInvoiceItem(
      itemId: w.id,
      description: w.typeName,
      itemCategory: 'meter',
      quantity: quantity,
      unitPrice: price,
      unitCost: 0,
    ),
  ],
);
void cut(
  ERPProvider e,
  FactoryBlockModel block, {
  double fee = .08,
  double output = 80,
}) => e.executeCuttingOperation(
  selectedBlocks: [block],
  cuttingFeePercent: fee,
  targetTypeName: block.typeName,
  targetGrade: block.grade,
  thicknessCm: 2,
  category: 'متر مربع',
  totalOutputArea: output,
  wasteValue: 0,
  recommendedSalePrice: 20,
  isGranite: false,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final c in [AppCurrency.usd, AppCurrency.syp]) {
    test(
      'purchase, supplier payments, capitalized cutting and deferred delivery ($c)',
      () async {
        final e = await clean();
        final inv = purchase(e, c);
        expect(e.addSupplierPurchaseInvoice(inv), isTrue);
        expect(e.currentInventoryValueOf(c), 1000);
        expect(e.suppliers.first.debtOf(c), 1000);
        expect(e.netOperatingProfitOf(c), 0);
        expect(e.paySupplierInvoice(inv, 400), isTrue);
        expect(e.expenseRecords, isEmpty);
        expect(e.netOperatingProfitOf(c), 0);
        expect(e.cashOf('main', c), 9600);
        cut(e, e.factoryBlocks.single);
        expect(e.currentInventoryValueOf(c), 1080);
        expect(e.netOperatingProfitOf(c), 0);
        final w = e.factoryWarehouse.single;
        final invoice = sale(e, w);
        expect(e.addFactoryPOSInvoice(invoice), isTrue);
        expect(invoice.totalCOGS, 270);
        expect(e.totalFactoryRevenueOf(c), 400);
        expect(e.totalCOGSOf(c), 270);
        expect(e.netOperatingProfitOf(c), 130);
        expect(e.currentInventoryValueOf(c), 810);
        expect(e.clients.first.debtOf(c), 400);
        expect(e.cashOf('main', c), 9600);
        expect(e.collectFactoryInvoice(invoice, 100), isTrue);
        expect(e.netOperatingProfitOf(c), 130);
        expect(
          e.addFactoryPOSInvoice(sale(e, w, id: 'cash', paid: 400)),
          isTrue,
        );
        expect(e.netOperatingProfitOf(c), 260);
        e.addExpenseRecord(
          ExpenseRecordModel(
            id: 'rent',
            typeId: 'rent',
            expenseType: ExpenseRecordModel.operational,
            amount: 50,
            currency: c,
          ),
        );
        expect(e.incomeSummaryNetProfitOf(c), 210);
        expect(
          e.netOperatingProfitOf(
            c == AppCurrency.usd ? AppCurrency.syp : AppCurrency.usd,
          ),
          0,
        );
      },
    );

    test(
      'manual manufacturing allocates only selected tons and survives backup ($c)',
      () async {
        final e = await clean();
        e.addSupplierPurchaseInvoice(purchase(e, c));
        final block = e.factoryBlocks.single;
        e.addExpenseRecord(
          ExpenseRecordModel(
            id: 'manual',
            typeId: 'custom',
            expenseType: ExpenseRecordModel.manufacturing,
            amount: 200,
            currency: c,
            inventorySource: 'block',
            inventoryId: block.id,
            manufacturingQuantity: 5,
          ),
        );
        expect(e.currentInventoryValueOf(c), 1200);
        expect(block.weightTons, 5);
        expect(block.tonCost, 100);
        final record = e.expenseRecords.single;
        final batch = e.factoryBlocks.firstWhere(
          (b) => b.id == record.capitalizedInventoryId,
        );
        expect(batch.tonCost, 140);
        expect(batch.weightTons, 5);
        expect(e.netOperatingProfitOf(c), 0);
        cut(e, batch, fee: 0, output: 50);
        final w = e.factoryWarehouse.single;
        expect(e.addFactoryPOSInvoice(sale(e, w, quantity: 25)), isTrue);
        expect(e.totalCOGSOf(c), 350);
        expect(e.netOperatingProfitOf(c), 150);
        final restored = ERPProvider();
        await restored.importFullBackupData(e.exportFullBackupData());
        expect(
          restored.currentInventoryValueOf(c),
          e.currentInventoryValueOf(c),
        );
        expect(restored.netOperatingProfitOf(c), 150);
        expect(restored.expenseRecords.first.toJson(), record.toJson());
      },
    );

    test(
      'freight and purchase discount adjust inventory, not profit ($c)',
      () async {
        final e = await clean();
        expect(
          e.addSupplierPurchaseInvoice(
            purchase(e, c, freight: 100, discount: 100),
          ),
          isTrue,
        );
        expect(e.currentInventoryValueOf(c), 1000);
        expect(e.suppliers.first.debtOf(c), 900);
        expect(e.netOperatingProfitOf(c), 0);
        expect(e.cashOf('main', c), 9900);
      },
    );
  }

  test(
    'partial warehouse manufacturing freezes sold COGS and preserves unallocated stock',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      cut(e, e.factoryBlocks.single);
      final w = e.factoryWarehouse.single;
      e.addExpenseRecord(
        ExpenseRecordModel(
          id: 'finish',
          typeId: 'finish',
          expenseType: ExpenseRecordModel.manufacturing,
          amount: 100,
          currency: AppCurrency.usd,
          inventorySource: 'factory_warehouse',
          inventoryId: w.id,
          manufacturingQuantity: 10,
        ),
      );
      expect(w.availableQty, 70);
      expect(w.netCostPerUnit, 13.5);
      final processed = e.factoryWarehouse.firstWhere(
        (i) => i.id == e.expenseRecords.last.capitalizedInventoryId,
      );
      expect(processed.netCostPerUnit, 23.5);
      expect(
        e.addFactoryPOSInvoice(sale(e, processed, quantity: 5, price: 30)),
        isTrue,
      );
      expect(e.totalCOGS, 117.5);
      processed.netCostPerUnit = 99;
      expect(e.totalCOGS, 117.5);
    },
  );

  test('invalid allocation never changes cash, inventory or records', () async {
    final e = await clean();
    e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
    for (final q in [0.0, 11.0, double.nan]) {
      final expense = ExpenseRecordModel(
        id: 'bad',
        typeId: 'cut',
        expenseType: ExpenseRecordModel.manufacturing,
        amount: 100,
        currency: AppCurrency.usd,
        inventorySource: 'block',
        inventoryId: e.factoryBlocks.single.id,
        manufacturingQuantity: q,
      );
      expect(() => e.addExpenseRecord(expense), throwsArgumentError);
      expect(e.mainCashBox, 10000);
      expect(e.currentInventoryValueUsd, 1000);
      expect(e.expenseRecords, isEmpty);
    }
  });

  test(
    'staged cutting uses actual inventory base cost, not an editable output estimate',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      e.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            typeName: 'test stone',
            grade: 'A',
            isGranite: false,
            inputTons: 10,
            avgTonCost: 1,
            feePercent: .08,
            thicknessCm: 2,
            category: 'متر مربع',
            outputQty: 80,
            netCost: 1,
            salePrice: 20,
          ),
        ],
        wasteValue: 0,
      );
      expect(e.factoryWarehouse.single.netCostPerUnit, 13.5);
      expect(e.netOperatingProfit, 0);
      expect(e.currentInventoryValueUsd, 1080);
    },
  );

  test(
    'legacy purchase and cutting audit records are excluded from P&L',
    () async {
      final e = await clean();
      for (final id in [
        ERPProvider.blockPurchaseExpenseTypeId,
        ERPProvider.cuttingExpenseTypeId,
        'shipping_transport_costs',
      ]) {
        e.expenseRecords.add(
          ExpenseRecordModel(
            id: id,
            typeId: id,
            amount: 100,
            currency: AppCurrency.usd,
          ),
        );
      }
      expect(e.incomeSummaryExpenses, 0);
    },
  );
  test(
    'staged cutting honors a specifically selected manufactured batch',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      final original = e.factoryBlocks.single;
      e.addExpenseRecord(
        ExpenseRecordModel(
          id: 'split-selected',
          typeId: 'cut',
          expenseType: ExpenseRecordModel.manufacturing,
          amount: 200,
          currency: AppCurrency.usd,
          inventorySource: 'block',
          inventoryId: original.id,
          manufacturingQuantity: 5,
        ),
      );
      final processed = e.factoryBlocks.firstWhere((b) => b.id != original.id);
      e.setPendingCuttingBatch([
        CuttingBatchInput(
          typeName: processed.typeName,
          grade: processed.grade,
          isGranite: false,
          totalTons: 5,
          avgTonCost: 140,
          selections: [
            CuttingBatchSelection(
              blockId: processed.id,
              supplierName: processed.supplierName,
              tons: 5,
              tonCost: 140,
            ),
          ],
        ),
      ]);
      e.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            typeName: processed.typeName,
            grade: processed.grade,
            isGranite: false,
            inputTons: 5,
            avgTonCost: 1,
            feePercent: 0,
            thicknessCm: 2,
            category: 'متر مربع',
            outputQty: 50,
            netCost: 1,
            salePrice: 20,
          ),
        ],
        wasteValue: 0,
      );
      expect(original.weightTons, 5);
      expect(e.factoryWarehouse.single.totalInventoryValue, 700);
      expect(e.currentInventoryValueUsd, 1200);
    },
  );

  test(
    'insufficient sales stock is rejected without changing cash or receivables',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      cut(e, e.factoryBlocks.single);
      final w = e.factoryWarehouse.single;
      final inv = sale(e, w, quantity: 81);
      final cash = e.mainCashBox;
      expect(e.addFactoryPOSInvoice(inv), isFalse);
      expect(e.mainCashBox, cash);
      expect(e.clients.first.debtBalance, 0);
      expect(w.availableQty, 80);
      expect(
        e.factoryInvoices.where((i) => i.invoiceType == 'بيع_معتمد'),
        isEmpty,
      );
    },
  );
}
