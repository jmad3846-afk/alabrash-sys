import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'inventory_accrual_accounting_test.dart' as fixtures;
import 'dynamic_cutting_batch_cost_test.dart' as batches;

FactoryInvoiceModel meterReceipt(
  ERPProvider e,
  String id, {
  double quantity = 20,
  double cost = 20,
  double selling = 30,
  String currency = AppCurrency.usd,
  String unit = 'متر مربع',
  String grade = 'A',
  double thickness = 2,
}) => FactoryInvoiceModel(
  id: id,
  invoiceNo: id,
  date: DateTime.now(),
  partyId: e.suppliers.first.id,
  partyName: e.suppliers.first.name,
  invoiceType: 'شراء_مورد',
  currency: currency,
  items: [
    FactoryInvoiceItem(
      itemId: id + '_type',
      description: 'test stone',
      typeName: 'test stone',
      grade: grade,
      thicknessCm: thickness,
      itemCategory: 'meter',
      meterUnit: unit,
      quantity: quantity,
      unitPrice: cost,
      unitCost: cost,
      sellingPrice: selling,
    ),
  ],
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'supplier meters join cutting stock at weighted cost and latest selling price',
    () async {
      final e = await batches.cutFactory();
      final batch = e.cuttingOperations.single;
      final originalId = e.factoryWarehouse.single.id;
      expect(
        e.addSupplierPurchaseInvoice(meterReceipt(e, 'new-purchase')),
        isTrue,
      );
      final w = e.factoryWarehouse.single;
      expect(w.id, originalId);
      expect(w.availableQty, 100);
      expect(w.netCostPerUnit, 14);
      expect(w.recommendedSalePrice, 30);
      expect(w.allThicknesses, [2]);
      expect(w.batchUnitsPerUnit[batch.id], .8);
      expect(e.currentInventoryValueUsd, 1400);
      batches.actual(e, batch, 80, 'actual');
      expect(w.netCostPerUnit, closeTo(14.8, .000001));
      expect(e.currentInventoryValueUsd, closeTo(1480, .000001));
      expect(e.netOperatingProfit, 0);
      expect(e.addFactoryPOSInvoice(fixtures.sale(e, w, quantity: 10)), isTrue);
      expect(e.totalCOGS, closeTo(148, .000001));
    },
  );

  test(
    'new cutting batch merges with the existing type and grade while retaining both cost allocations',
    () async {
      final e = await batches.cutFactory();
      final first = e.cuttingOperations.single;
      final block = FactoryBlockModel(
        id: 'second',
        blockCode: 'B2',
        typeName: 'test stone',
        grade: 'A',
        supplierId: e.suppliers.first.id,
        supplierName: e.suppliers.first.name,
        weightTons: 5,
        tonCost: 200,
      );
      e.factoryBlocks.add(block);
      e.executeCuttingOperation(
        selectedBlocks: [block],
        cuttingFeePercent: .5,
        targetTypeName: 'test stone',
        targetGrade: 'A',
        thicknessCm: 2,
        category: 'متر مربع',
        totalOutputArea: 40,
        wasteValue: 0,
        recommendedSalePrice: 45,
        isGranite: false,
      );
      final w = e.factoryWarehouse.single;
      final second = e.cuttingOperations.last;
      expect(w.availableQty, 120);
      expect(w.netCostPerUnit, closeTo(2000 / 120, .000001));
      expect(w.recommendedSalePrice, 45);
      expect(w.allThicknesses, [2]);
      expect(first.id, isNot(second.id));
      expect(first.outputItemIds, [w.id]);
      expect(second.outputItemIds, [w.id]);
      batches.actual(e, first, 80, 'first-cost');
      batches.actual(e, second, 120, 'second-cost');
      expect(e.currentInventoryValueUsd, closeTo(2200, .000001));
      expect(w.netCostPerUnit, closeTo(2200 / 120, .000001));
    },
  );

  test(
    'late batch expenses split correctly between pooled remaining stock and pooled sales',
    () async {
      final e = await batches.cutFactory();
      final batch = e.cuttingOperations.single;
      e.addSupplierPurchaseInvoice(meterReceipt(e, 'pool'));
      final w = e.factoryWarehouse.single;
      expect(e.addFactoryPOSInvoice(fixtures.sale(e, w, quantity: 50)), isTrue);
      expect(e.totalCOGS, 700);
      expect(e.currentInventoryValueUsd, 700);
      batches.actual(e, batch, 80, 'late');
      expect(e.totalCOGS, closeTo(740, .000001));
      expect(e.currentInventoryValueUsd, closeTo(740, .000001));
      expect(e.factoryWarehouse.single.availableQty, 50);
      expect(w.recommendedSalePrice, 30);
    },
  );

  test(
    'square meters separate thickness while cubic meters pool volumes',
    () async {
      final e = await fixtures.clean();
      for (final unit in ['متر مربع', 'متر مكعب']) {
        for (final thickness in [2.0, 3.0]) {
          expect(
            e.addSupplierPurchaseInvoice(
              meterReceipt(
                e,
                '$unit-$thickness',
                unit: unit,
                thickness: thickness,
                cost: thickness * 10,
                selling: thickness * 15,
              ),
            ),
            isTrue,
          );
        }
      }
      expect(e.factoryWarehouse.length, 3);
      final square = e.factoryWarehouse
          .where((w) => w.category == 'متر مربع')
          .toList();
      expect(square.map((w) => w.thicknessCm).toSet(), {2.0, 3.0});
      expect(square.map((w) => w.availableQty), everyElement(20));
      expect(square.map((w) => w.netCostPerUnit).toList()..sort(), [20, 30]);
      expect(square.map((w) => w.recommendedSalePrice).toList()..sort(), [
        30,
        45,
      ]);
      final cube = e.factoryWarehouse.singleWhere(
        (w) => w.category == 'متر مكعب',
      );
      expect(cube.availableQty, 40);
      expect(cube.netCostPerUnit, 25);
      expect(cube.recommendedSalePrice, 45);
    },
  );

  test('measurement units, currencies and grades remain separate', () async {
    final e = await fixtures.clean();
    var id = 0;
    for (final (currency, unit, grade) in [
      (AppCurrency.usd, 'متر مربع', 'A'),
      (AppCurrency.usd, 'متر مكعب', 'A'),
      (AppCurrency.usd, 'متر طولي', 'A'),
      (AppCurrency.syp, 'متر مربع', 'A'),
      (AppCurrency.usd, 'متر مربع', 'B'),
    ]) {
      expect(
        e.addSupplierPurchaseInvoice(
          meterReceipt(
            e,
            'receipt_' + (id++).toString(),
            currency: currency,
            unit: unit,
            grade: grade,
          ),
        ),
        isTrue,
      );
    }
    expect(e.factoryWarehouse.length, 5);
  });

  test(
    'existing separate lots consolidate without losing values, old IDs, or invoice references',
    () async {
      final e = await fixtures.clean();
      e.cuttingOperations.clear();
      e.factoryWarehouse.addAll([
        FactoryWarehouseModel(
          id: 'old-a',
          typeName: 'same',
          grade: 'A',
          thicknessCm: 2,
          category: 'متر مربع',
          availableQty: 5,
          netCostPerUnit: 10,
          recommendedSalePrice: 15,
        ),
        FactoryWarehouseModel(
          id: 'old-b',
          typeName: 'same',
          grade: 'A',
          thicknessCm: 2,
          category: 'متر مربع',
          availableQty: 5,
          netCostPerUnit: 20,
          recommendedSalePrice: 30,
        ),
      ]);
      final inv = FactoryInvoiceModel(
        id: 'history',
        invoiceNo: 'H',
        date: DateTime.now(),
        partyId: e.clients.first.id,
        partyName: e.clients.first.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'old-b',
            description: 'same',
            quantity: 1,
            unitPrice: 25,
            unitCost: 17,
          ),
        ],
      );
      e.factoryInvoices.add(inv);
      e.refresh();
      final w = e.factoryWarehouse.single;
      expect(w.availableQty, 10);
      expect(w.netCostPerUnit, 15);
      expect(w.totalInventoryValue, 150);
      expect(w.recommendedSalePrice, 30);
      expect(w.matchesId('old-b'), isTrue);
      expect(inv.items.single.itemId, w.id);
      expect(inv.items.single.unitCost, 17);
      expect(w.allThicknesses, [2]);
      final copy = ERPProvider();
      await copy.importFullBackupData(e.exportFullBackupData());
      expect(copy.factoryWarehouse.single.toJson(), w.toJson());
    },
  );

  test(
    'returning workshop meters joins the existing factory balance without replacing its selling price',
    () async {
      final e = await batches.cutFactory();
      final original = e.factoryWarehouse.single;
      e.transferFactoryToWorkshop(original, 20);
      e.addSupplierPurchaseInvoice(meterReceipt(e, 'receipt'));
      final ws = e.workshopStock.single;
      expect(e.transferWorkshopToFactory(ws, 20), isTrue);
      final w = e.factoryWarehouse.single;
      expect(w.availableQty, 100);
      expect(w.netCostPerUnit, closeTo(14, .000001));
      expect(w.recommendedSalePrice, 30);
      batches.actual(e, e.cuttingOperations.single, 80, 'after-transfer');
      expect(w.netCostPerUnit, closeTo(14.8, .000001));
    },
  );
}
