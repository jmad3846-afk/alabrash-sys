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
  void expense(
    ERPProvider e,
    CuttingOperationModel b,
    double amount,
    String id,
  ) => e.addExpenseRecord(
    ExpenseRecordModel(
      id: id,
      typeId: ERPProvider.cuttingExpenseTypeId,
      expenseType: ExpenseRecordModel.manufacturing,
      cuttingBatchId: b.id,
      amount: amount,
      currency: b.currency,
    ),
  );
  for (final c in [AppCurrency.usd, AppCurrency.syp]) {
    test(
      'purchase, supplier payments, actual cutting and deferred delivery ($c)',
      () async {
        final e = await clean();
        final inv = purchase(e, c);
        expect(e.addSupplierPurchaseInvoice(inv), isTrue);
        expect(e.currentInventoryValueOf(c), 1000);
        expect(e.suppliers.first.debtOf(c), 1000);
        expect(e.paySupplierInvoice(inv, 400), isTrue);
        expect(e.expenseRecords, isEmpty);
        expect(e.netOperatingProfitOf(c), 0);
        cut(e, e.factoryBlocks.single);
        expect(e.currentInventoryValueOf(c), 1000);
        expense(e, e.cuttingOperations.last, 80, 'actual');
        final w = e.factoryWarehouse.single;
        final invoice = sale(e, w);
        expect(e.addFactoryPOSInvoice(invoice), isTrue);
        expect(invoice.totalCOGS, 270);
        expect(e.netOperatingProfitOf(c), 130);
        expect(e.currentInventoryValueOf(c), 810);
        expect(e.clients.first.debtOf(c), 400);
        expect(e.collectFactoryInvoice(invoice, 100), isTrue);
        expect(e.netOperatingProfitOf(c), 130);
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
      },
    );
  }
  test(
    'staged cutting uses actual raw cost independently of pricing estimates',
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
      expect(e.factoryWarehouse.single.netCostPerUnit, 12.5);
      expect(e.netOperatingProfit, 0);
      expect(e.currentInventoryValueUsd, 1000);
    },
  );
  test(
    'insufficient sales stock is rejected without cash or receivable changes',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      cut(e, e.factoryBlocks.single);
      final w = e.factoryWarehouse.single;
      expect(e.addFactoryPOSInvoice(sale(e, w, quantity: 81)), isFalse);
      expect(e.clients.first.debtBalance, 0);
      expect(w.availableQty, 80);
    },
  );
  test(
    'invalid or missing cutting batch cannot change cash, stock or expense ledger',
    () async {
      final e = await clean();
      e.addSupplierPurchaseInvoice(purchase(e, AppCurrency.usd));
      expect(
        () => e.addExpenseRecord(
          ExpenseRecordModel(
            id: 'bad',
            typeId: ERPProvider.cuttingExpenseTypeId,
            expenseType: ExpenseRecordModel.manufacturing,
            amount: 100,
            currency: AppCurrency.usd,
          ),
        ),
        throwsArgumentError,
      );
      expect(e.mainCashBox, 10000);
      expect(e.currentInventoryValueUsd, 1000);
      expect(e.expenseRecords, isEmpty);
    },
  );
  test(
    'legacy purchase and cutting audit records remain excluded from P&L',
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
}
