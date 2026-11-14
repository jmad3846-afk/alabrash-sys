import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ERPProvider> freshErp() async {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    await erp.loadFuture;
    return erp;
  }

  test('equipment type catalog + opening stock lands on the stock card', () async {
    final erp = await freshErp();
    expect(
      erp.addEquipmentType(name: 'مولد كهرباء', description: 'ديزل 5 كيلو'),
      isTrue,
    );
    // Synchronization: the card appears on the Equipment page immediately.
    expect(erp.equipmentStock, hasLength(1));
    expect(erp.equipmentStock.single.name, 'مولد كهرباء');
    expect(erp.equipmentStock.single.availableQty, 0);
    expect(
      erp.addEquipmentType(name: 'مولد كهرباء'),
      isFalse,
      reason: 'no duplicates',
    );
    expect(erp.equipmentStock, hasLength(1), reason: 'no duplicate cards');

    final stock = erp.addEquipmentStock(
      typeId: erp.equipmentTypes.single.id,
      quantity: 3,
      costPrice: 200,
      sellingPrice: 260,
    );
    expect(stock, isNotNull);
    expect(erp.equipmentStock.single.availableQty, 3);
    expect(erp.equipmentStock.single.costPrice, 200);
    expect(erp.equipmentStock.single.sellingPrice, 260);
  });

  test('equipment purchase invoice: stock up, supplier debt, cash down', () async {
    final erp = await freshErp();
    erp.suppliers = [
      SupplierModel(id: 's1', name: 'مورد التجهيزات', phone: '', location: ''),
    ];
    erp.mainCashBox = 1000;
    erp.addEquipmentType(name: 'قاطع بلازما');
    final typeId = erp.equipmentTypes.single.id;

    final ok = erp.addEquipmentPurchaseInvoice(
      supplierId: 's1',
      typeId: typeId,
      quantity: 4,
      unitPrice: 150,
      sellingPrice: 220,
      downPayment: 300,
    );
    expect(ok, isTrue);

    // Stock raised to the purchased quantity and prices updated.
    final card = erp.equipmentStock.single;
    expect(card.availableQty, 4);
    expect(card.costPrice, 150);
    expect(card.sellingPrice, 220);

    // Down payment deducted from the main cash box (1000 - 300).
    expect(erp.mainCashBox, closeTo(700, 0.001));

    // Full invoice value recorded on the supplier statement.
    final statement = A4StatementData.fromSupplier(
      supplier: erp.suppliers.single,
      erp: erp,
    );
    final invoiceRow = statement.items
        .where((i) => i.category == 'فاتورة شراء')
        .single;
    expect(invoiceRow.totalAmount, closeTo(600, 0.001));
    expect(invoiceRow.paidAmount, closeTo(300, 0.001));
    expect(invoiceRow.remainingAmount, closeTo(300, 0.001));

    // Supplier balance raised by the remaining amount.
    expect(erp.suppliers.single.debtBalance, closeTo(300, 0.001));
  });

  test(
    'selling equipment in a workshop invoice deducts stock and feeds P&L line',
    () async {
      final erp = await freshErp();
      erp.addEquipmentType(name: 'صاروخ جلي');
      final stock = erp.addEquipmentStock(
        typeId: erp.equipmentTypes.single.id,
        quantity: 5,
        costPrice: 80,
        sellingPrice: 120,
      );
      erp.clients = [
        ClientModel(id: 'c1', name: 'زبون التجهيزات', clientType: 'زبون معمل'),
      ];

      final invoice = WorkshopInvoiceModel(
        id: 'wi_test_1',
        invoiceNo: 'WRK-TEST-1',
        date: DateTime(2026, 11, 14),
        clientName: 'زبون التجهيزات',
        items: [
          WorkshopInvoiceItem(
            id: 'wii_test_1',
            sourceType: 'بيع تجهيزات',
            sourceId: stock!.id,
            description: stock.name,
            quantity: 2,
            unitCategory: 'قطعة',
            unitPrice: stock.sellingPrice,
            agreedPrice: 2 * stock.sellingPrice,
            netCost: 2 * stock.costPrice,
          ),
        ],
        sourceType: 'بيع تجهيزات',
        sourceId: stock.id,
        itemDescription: stock.name,
        sourceQuantity: 2,
        sourceUnitCategory: 'قطعة',
        agreedPrice: 240,
        depositDeducted: 0,
        cashPaidNow: 240,
        netCost: 160,
      );

      expect(erp.createWorkshopInvoice(invoice), isTrue);
      expect(stock.availableQty, 3);
      expect(erp.equipmentSalesRevenueOf(AppCurrency.usd), closeTo(240, 0.001));
    },
  );

  test('over-selling available equipment is rejected', () async {
    final erp = await freshErp();
    erp.addEquipmentType(name: 'فرصة قطع');
    final stock = erp.addEquipmentStock(
      typeId: erp.equipmentTypes.single.id,
      quantity: 1,
      costPrice: 50,
      sellingPrice: 70,
    );
    erp.clients = [
      ClientModel(id: 'c1', name: 'زبون', clientType: 'زبون معمل'),
    ];
    final invoice = WorkshopInvoiceModel(
      id: 'wi_test_2',
      invoiceNo: 'WRK-TEST-2',
      date: DateTime(2026, 11, 14),
      clientName: 'زبون',
      items: [
        WorkshopInvoiceItem(
          id: 'wii_test_2',
          sourceType: 'بيع تجهيزات',
          sourceId: stock!.id,
          description: stock.name,
          quantity: 10,
          unitCategory: 'قطعة',
          unitPrice: 70,
          agreedPrice: 700,
          netCost: 500,
        ),
      ],
      sourceType: 'بيع تجهيزات',
      sourceId: stock.id,
      itemDescription: stock.name,
      sourceQuantity: 10,
      sourceUnitCategory: 'قطعة',
      agreedPrice: 700,
      depositDeducted: 0,
      cashPaidNow: 700,
      netCost: 500,
    );
    expect(erp.createWorkshopInvoice(invoice), isFalse);
    expect(stock.availableQty, 1);
  });
}
