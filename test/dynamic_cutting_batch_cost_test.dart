import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'inventory_accrual_accounting_test.dart' as fixture;

void actual(
  ERPProvider e,
  CuttingOperationModel batch,
  double amount,
  String id,
) => e.addExpenseRecord(
  ExpenseRecordModel(
    id: id,
    typeId: ERPProvider.cuttingExpenseTypeId,
    expenseType: ExpenseRecordModel.manufacturing,
    amount: amount,
    currency: batch.currency,
    cuttingBatchId: batch.id,
  ),
);
Future<ERPProvider> cutFactory([String currency = AppCurrency.usd]) async {
  final e = await fixture.clean();
  e.cuttingOperations.clear();
  e.addSupplierPurchaseInvoice(fixture.purchase(e, currency));
  fixture.cut(e, e.factoryBlocks.single);
  return e;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final c in [AppCurrency.usd, AppCurrency.syp]) {
    test(
      'cutting estimate is informational and actual cash costs capitalize ($c)',
      () async {
        final e = await cutFactory(c);
        final batch = e.cuttingOperations.single;
        expect(batch.estimatedUnitCost, 13.5);
        expect(e.factoryWarehouse.single.netCostPerUnit, 12.5);
        expect(e.currentInventoryValueOf(c), 1000);
        expect(e.expenseRecords, isEmpty);
        expect(e.cashOf('main', c), 10000);
        expect(e.netOperatingProfitOf(c), 0);
        actual(e, batch, 80, 'actual');
        expect(e.cashOf('main', c), 9920);
        expect(e.currentInventoryValueOf(c), 1080);
        expect(e.factoryWarehouse.single.netCostPerUnit, 13.5);
        expect(e.netOperatingProfitOf(c), 0);
        expect(e.actualCuttingExpensesForBatch(batch.id), 80);
        expect(
          e.addFactoryPOSInvoice(fixture.sale(e, e.factoryWarehouse.single)),
          isTrue,
        );
        expect(e.totalCOGSOf(c), 270);
        expect(e.netOperatingProfitOf(c), 130);
      },
    );
  }

  test(
    'multiple payments accumulate and cost recalculation is idempotent',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      actual(e, batch, 80, 'one');
      actual(e, batch, 40, 'two');
      expect(e.factoryWarehouse.single.netCostPerUnit, 14);
      expect(e.mainCashBox, 9880);
      e.recalculateCuttingBatchCosts(batch.id);
      expect(e.factoryWarehouse.single.netCostPerUnit, 14);
      expect(e.mainCashBox, 9880);
    },
  );

  test(
    'staged outputs allocate actual expenses across separate thickness balances',
    () async {
      final e = await fixture.clean();
      e.cuttingOperations.clear();
      e.addSupplierPurchaseInvoice(fixture.purchase(e, AppCurrency.usd));
      e.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            typeName: 'test stone',
            grade: 'A',
            isGranite: false,
            inputTons: 5,
            avgTonCost: 999,
            feePercent: .1,
            thicknessCm: 2,
            category: 'متر مربع',
            outputQty: 40,
            netCost: 999,
            salePrice: 20,
          ),
          StagedCutConversion(
            typeName: 'test stone',
            grade: 'A',
            isGranite: false,
            inputTons: 5,
            avgTonCost: 999,
            feePercent: .1,
            thicknessCm: 3,
            category: 'متر مربع',
            outputQty: 20,
            netCost: 999,
            salePrice: 30,
          ),
        ],
        wasteValue: 0,
      );
      expect(e.currentInventoryValueUsd, closeTo(1000, .000001));
      final batch = e.cuttingOperations.single;
      expect(batch.outputItemIds.length, 2);
      actual(e, batch, 600, 'shared');
      expect(e.factoryWarehouse[0].netCostPerUnit, closeTo(22.5, .000001));
      expect(e.factoryWarehouse[1].netCostPerUnit, closeTo(35, .000001));
      expect(e.currentInventoryValueUsd, closeTo(1600, .000001));
      expect(e.mainCashBox, 9400);
    },
  );

  test(
    'late costs follow transferred and sold output while preserving the balance equation',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      final w = e.factoryWarehouse.single;
      e.transferFactoryToWorkshop(w, 20);
      expect(e.addFactoryPOSInvoice(fixture.sale(e, w)), isTrue);
      expect(e.currentInventoryValueUsd, 750);
      expect(e.totalCOGS, 250);
      final equity =
          e.mainCashBox +
          e.currentInventoryValueUsd +
          e.clients.first.debtBalance -
          e.suppliers.first.debtBalance;
      actual(e, batch, 160, 'late');
      expect(w.netCostPerUnit, 14.5);
      expect(e.workshopStock.single.netCostPerUnit, 14.5);
      expect(e.totalCOGS, 290);
      expect(e.currentInventoryValueUsd, 870);
      final after =
          e.mainCashBox +
          e.currentInventoryValueUsd +
          e.clients.first.debtBalance -
          e.suppliers.first.debtBalance;
      expect(after, equity - 40);
      expect(e.netOperatingProfit, 110);
    },
  );

  test(
    'fully sold batch expenses become COGS rather than manufacturing phantom stock',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      expect(
        e.addFactoryPOSInvoice(
          fixture.sale(e, e.factoryWarehouse.single, quantity: 80),
        ),
        isTrue,
      );
      actual(e, batch, 160, 'fully-sold');
      expect(e.currentInventoryValueUsd, 0);
      expect(e.totalCOGS, 1160);
      expect(e.netOperatingProfit, 440);
    },
  );

  test(
    'workshop estimates stay outside actual cost and costs follow simple tailoring outputs',
    () async {
      final e = await cutFactory();
      final upstream = e.cuttingOperations.single;
      e.transferFactoryToWorkshop(e.factoryWarehouse.single, 20);
      final stock = e.workshopStock.single;
      final line = TailoringLineItem(
        id: 'line',
        source: 'materials',
        stockId: stock.id,
        typeName: stock.typeName,
        grade: stock.grade,
        thicknessCm: 2,
        category: 'متر مربع',
        lengthCm: 100,
        widthCm: 100,
        quantity: 10,
        netCostPerMeter: 12.5,
        sellingPricePerMeter: 30,
        services: [ServiceAttachment(serviceName: 'estimate', price: 50)],
      );
      stock.availableQty -= 10;
      final t = WorkshopTailoringModel(
        id: 'tailored',
        name: 'simple',
        complexity: 'بسيط',
        rawMaterialDescription: 'raw',
        quantity: 10,
        materialNetCost: 0,
        lineItems: [line],
        sellingPrice: 30,
      );
      e.simpleTailorings.add(t);
      e.refresh();
      final batch = e.cuttingOperations.firstWhere(
        (b) => b.outputItemIds.contains(t.id),
      );
      expect(batch.sourceSection, 'workshop_simple');
      expect(batch.estimatedUnitCost, 17.5);
      expect(t.costPerMeterAfterServices, 12.5);
      expect(e.currentInventoryValueUsd, 1000);
      actual(e, batch, 100, 'tailor');
      expect(t.costPerMeterAfterServices, 22.5);
      expect(line.netCostPerMeterAfterServices, 22.5);
      expect(e.currentInventoryValueUsd, 1100);
      actual(e, upstream, 160, 'upstream');
      expect(t.costPerMeterAfterServices, 24.5);
      expect(line.netCostPerMeterAfterServices, 24.5);
      expect(e.currentInventoryValueUsd, 1260);
      final inv = WorkshopInvoiceModel(
        id: 'workshop-sale',
        invoiceNo: 'WS',
        date: DateTime.now(),
        clientName: 'buyer',
        depositDeducted: 0,
        cashPaidNow: 0,
        sourceType: 'تفصيل بسيط',
        sourceId: t.id,
        sourceQuantity: 5,
        agreedPrice: 200,
        netCost: 0,
      );
      expect(e.createWorkshopInvoice(inv), isTrue);
      expect(inv.netCost, 122.5);
      expect(t.quantity, 5);
      actual(e, batch, 20, 'after-sale');
      expect(inv.netCost, 132.5);
      expect(t.costPerMeterAfterServices, 26.5);
      expect(e.totalCOGS, 132.5);
    },
  );

  test(
    'mixed-cost complex outputs allocate by produced piece and carry cost into sales',
    () async {
      final e = await fixture.clean();
      e.cuttingOperations.clear();
      final t = WorkshopTailoringModel(
        id: 'complex',
        name: 'complex',
        complexity: 'معقد',
        rawMaterialDescription: '',
        quantity: 1,
        materialNetCost: 250,
        laborCostPerMeter: 90,
        attachedServices: [ServiceAttachment(serviceName: 'quote', price: 10)],
        sellingPrice: 500,
      );
      e.complexTailorings.add(t);
      e.refresh();
      final batch = e.cuttingOperations.single;
      expect(t.totalNetCost, 250);
      expect(batch.estimatedUnitCost, 350);
      actual(e, batch, 60, 'complex-cost');
      expect(t.totalNetCost, 310);
      final inv = WorkshopInvoiceModel(
        id: 'complex-sale',
        invoiceNo: 'CS',
        date: DateTime.now(),
        clientName: 'buyer',
        depositDeducted: 0,
        cashPaidNow: 0,
        sourceType: 'تفصيل معقد',
        sourceId: t.id,
        sourceQuantity: 1,
        agreedPrice: 500,
        netCost: 0,
      );
      expect(e.createWorkshopInvoice(inv), isTrue);
      expect(inv.netCost, 310);
      actual(e, batch, 30, 'later');
      expect(inv.netCost, 340);
      expect(e.currentInventoryValueUsd, 0);
    },
  );

  test(
    'invalid batch and currency do not touch cash, costs or the expense ledger',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      for (final (id, currency) in [
        ('missing', AppCurrency.usd),
        (batch.id, AppCurrency.syp),
      ]) {
        expect(
          () => e.addExpenseRecord(
            ExpenseRecordModel(
              id: 'invalid',
              typeId: ERPProvider.cuttingExpenseTypeId,
              expenseType: ExpenseRecordModel.manufacturing,
              amount: 80,
              currency: currency,
              cuttingBatchId: id,
            ),
          ),
          throwsArgumentError,
        );
        expect(e.mainCashBox, 10000);
        expect(e.currentInventoryValueUsd, 1000);
        expect(e.expenseRecords, isEmpty);
      }
    },
  );

  test(
    'restoring and recalculating a batch does not capitalize its cash payment twice',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      actual(e, batch, 80, 'restore');
      final copy = ERPProvider();
      await copy.importFullBackupData(e.exportFullBackupData());
      copy.recalculateCuttingBatchCosts(batch.id);
      expect(copy.mainCashBox, 9920);
      expect(copy.currentInventoryValueUsd, 1080);
      expect(copy.factoryWarehouse.single.batchUnitsPerUnit[batch.id], 1);
      expect(copy.expenseRecords.single.cuttingBatchId, batch.id);
      expect(
        copy.expenseTypes.any((t) => t.name == 'مصروف قص وتصنيع مباشر'),
        isTrue,
      );
    },
  );
  test(
    'late actual expense follows returned goods and only the net sold quantity enters COGS',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      final inv = fixture.sale(e, e.factoryWarehouse.single);
      expect(e.addFactoryPOSInvoice(inv), isTrue);
      expect(
        e.addAdjustmentInvoice(
          AdjustmentInvoiceModel(
            id: 'return',
            invoiceNo: 'RET1',
            description: 'return',
            kind: 'sales_return',
            module: 'factory',
            targetInvoiceId: inv.id,
            targetInvoiceNo: inv.invoiceNo,
            partyName: inv.partyName,
            amount: 100,
            currency: AppCurrency.usd,
            paymentAction: 'تخفيض دين',
            lines: [
              AdjustmentLineModel(
                itemId: inv.items.first.itemId,
                itemIndex: 0,
                description: inv.items.first.description,
                unit: 'متر مربع',
                quantity: 5,
                unitPrice: 20,
                amount: 100,
              ),
            ],
          ),
        ),
        isTrue,
      );
      actual(e, batch, 80, 'after-return');
      expect(e.factoryWarehouse.single.availableQty, 65);
      expect(e.currentInventoryValueUsd, 877.5);
      expect(e.totalCOGS, 202.5);
      expect(e.netOperatingProfit, 97.5);
    },
  );

  test(
    'abnormal waste retains batch identity for later actual expenses',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      e.transferFactoryToWorkshop(e.factoryWarehouse.single, 20);
      expect(
        e.recordWorkshopWaste(
          sourceSection: 'مواد المعمل',
          sourceItemId: e.workshopStock.single.id,
          quantity: 5,
          cost: 999,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(e.wasteLogs.single.cost, 62.5);
      actual(e, batch, 80, 'after-waste');
      expect(e.wasteLogs.single.cost, 67.5);
      expect(e.currentInventoryValueUsd, 1012.5);
      expect(e.netOperatingProfit, -67.5);
    },
  );

  test(
    'reserved factory materials carry actual costs until order delivery',
    () async {
      final e = await cutFactory();
      final batch = e.cuttingOperations.single;
      final w = e.factoryWarehouse.single;
      final order = FactoryOrderModel(
        id: 'reserved',
        orderNo: 'R1',
        date: DateTime.now(),
        partyId: e.clients.first.id,
        clientName: e.clients.first.name,
        items: [
          FactoryInvoiceItem(
            itemId: w.id,
            description: w.typeName,
            itemCategory: 'meter',
            quantity: 10,
            unitPrice: 20,
            unitCost: 0,
          ),
        ],
        depositAmount: 0,
      );
      e.createFactoryOrder(order);
      expect(e.currentInventoryValueUsd, 1000);
      actual(e, batch, 80, 'reserved-cost');
      expect(e.currentInventoryValueUsd, 1080);
      expect(order.items.single.unitCost, 13.5);
      final inv = FactoryInvoiceModel(
        id: 'delivered',
        invoiceNo: 'D1',
        date: DateTime.now(),
        partyId: order.partyId,
        partyName: order.clientName,
        invoiceType: 'بيع_معتمد',
        items: List.of(order.items),
      );
      expect(e.assignFactoryOrderToPOSInvoice(order, inv), isTrue);
      expect(e.totalCOGS, 135);
      expect(e.currentInventoryValueUsd, 945);
    },
  );

  test(
    'workshop replenishment has a separate batch and preserves both upstream allocations',
    () async {
      final e = await cutFactory();
      e.transferFactoryToWorkshop(e.factoryWarehouse.single, 20);
      final stock = e.workshopStock.single;
      final line = TailoringLineItem(
        id: 'rep-line',
        source: 'materials',
        stockId: stock.id,
        typeName: stock.typeName,
        grade: stock.grade,
        thicknessCm: 2,
        category: 'متر مربع',
        lengthCm: 100,
        widthCm: 100,
        quantity: 10,
        netCostPerMeter: 12.5,
        sellingPricePerMeter: 30,
      );
      stock.availableQty -= 10;
      final t = WorkshopTailoringModel(
        id: 'replenished',
        name: 'replenish',
        complexity: 'بسيط',
        rawMaterialDescription: '',
        quantity: 10,
        materialNetCost: 0,
        lineItems: [line],
        sellingPrice: 30,
      );
      e.simpleTailorings.add(t);
      e.refresh();
      stock.availableQty -= 5;
      line.quantity += 5;
      t.quantity += 5;
      e.registerTailoringReplenishment(
        tailoring: t,
        line: line,
        source: stock,
        quantity: 5,
        oldQuantity: 10,
        oldCapital: 125,
        oldLineArea: 10,
      );
      final batch = e.cuttingOperations.last;
      expect(batch.sourceSection, 'workshop_replenishment');
      actual(e, batch, 30, 'replenish-cost');
      expect(t.totalNetCost, 217.5);
      expect(line.netCostPerMeter, 14.5);
      expect(e.currentInventoryValueUsd, 1030);
    },
  );
}
