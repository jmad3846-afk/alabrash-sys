import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/core/theme/app_theme.dart';
import 'package:marble_granite_erp/main.dart';
import 'package:marble_granite_erp/screens/factory_workspace_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(ERPProvider erp) => ChangeNotifierProvider<ERPProvider>.value(
        value: erp,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FactoryWorkspaceScreen(onNavigateToCutting: (_) {}),
          ),
        ),
      );

  Future<void> openSupplierInvoiceTab(WidgetTester tester, ERPProvider erp) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(erp));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6. فواتير شراء من موردين'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('[إضافة فاتورة شراء من مورد]'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens supplier purchase dialog with seeded master data',
      (tester) async {
    await openSupplierInvoiceTab(tester, ERPProvider());
    expect(find.text('إنشاء فاتورة شراء من مورد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows guidance (no crash) when master data is empty',
      (tester) async {
    final erp = ERPProvider();
    erp.suppliers.clear();
    erp.blockTypes.clear();

    await openSupplierInvoiceTab(tester, erp);

    expect(find.text('لا يمكن إضافة فاتورة شراء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('multi-item purchase: shipping distributed, Due status, inventory split',
      () async {
    final erp = ERPProvider();
    final blocksBefore = erp.factoryBlocks.length;

    erp.addSupplierPurchaseInvoice(FactoryInvoiceModel(
      id: 'fi_test_1',
      invoiceNo: 'FAC-PUR-TEST-1',
      date: DateTime(2026, 1, 5),
      partyId: 'sup1',
      partyName: 'شركة مقالع الرخام الوطنية',
      invoiceType: 'شراء_مورد',
      items: [
        FactoryInvoiceItem(
            itemId: 'd1',
            description: 'بازلت (درجة أولى)',
            typeName: 'بازلت',
            grade: 'درجة أولى',
            quantity: 15.0,
            unitPrice: 100.0,
            unitCost: 100.0),
        FactoryInvoiceItem(
            itemId: 'd2',
            description: 'بازلت (درجة أولى)',
            typeName: 'بازلت',
            grade: 'درجة أولى',
            quantity: 10.0,
            unitPrice: 80.0,
            unitCost: 80.0),
      ],
      isGoodsDelivered: false,
      shippingFee: 230.0,
      advancePayment: 1000.0,
    ));

    final inv = erp.factoryInvoices.last;
    // Items 1500 + 800 = 2300, + shipping 230 = 2530, - 1000 = 1530 due.
    expect(inv.grandTotal, closeTo(2530.0, 0.001));
    expect(inv.isDue, isTrue);
    expect(inv.paymentStatus, 'مستحق الدفع');

    // Two new raw blocks grouped later by type+grade+supplier price.
    expect(erp.factoryBlocks.length, blocksBefore + 2);
    final added = erp.factoryBlocks.sublist(blocksBefore);
    expect(added[0].typeName, 'بازلت');
    // Proportional shipping: item1 capital 1500 of 2300 -> share 150.
    expect(added[0].tonCost, closeTo(100.0 + 150.0 / 15.0, 0.001));
    expect(added[1].tonCost, closeTo(80.0 + 80.0 / 10.0, 0.001));

    // Supplier debt increased by the remainder.
    final sup = erp.suppliers.firstWhere((s) => s.id == 'sup1');
    expect(sup.debtBalance, closeTo(25000.0 + 1530.0, 0.001));
  });

  test('fully paid purchase lands in Paid section', () async {
    final erp = ERPProvider();
    erp.addSupplierPurchaseInvoice(FactoryInvoiceModel(
      id: 'fi_test_2',
      invoiceNo: 'FAC-PUR-TEST-2',
      date: DateTime(2026, 1, 6),
      partyId: 'sup2',
      partyName: 'مؤسسة الغرانيت المستورد',
      invoiceType: 'شراء_مورد',
      items: [
        FactoryInvoiceItem(
            itemId: 'd1',
            description: 'غرانيت (ممتاز)',
            typeName: 'غرانيت أسود جالكسي',
            grade: 'ممتاز',
            quantity: 5.0,
            unitPrice: 200.0,
            unitCost: 200.0,
            isGranite: true),
      ],
      isGoodsDelivered: true,
      advancePayment: 1000.0,
    ));

    final inv = erp.factoryInvoices.last;
    expect(inv.isDue, isFalse);
    expect(inv.paymentStatus, 'مدفوعة');
    expect(
        erp.factoryInvoices
            .where((i) => i.invoiceType == 'شراء_مورد' && !i.isDue)
            .length,
        1);
  });

  testWidgets('opens factory POS dialog with seeded data', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ERPProvider()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('7. بيع لمعتمدين (POS المصنع)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7. بيع لمعتمدين (POS المصنع)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('[إضافة فاتورة مصنع]'));
    await tester.pumpAndSettle();

    expect(find.text('إنشاء فاتورة مصنع لمعتمد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('POS invoice: per-item services, m2 deduction, Pending status', () async {
    final erp = ERPProvider();
    final whBefore = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw1')
        .availableQty;

    erp.addFactoryPOSInvoice(FactoryInvoiceModel(
      id: 'fi_pos_test_1',
      invoiceNo: 'FAC-POS-TEST-1',
      date: DateTime(2026, 1, 7),
      partyId: 'cli1',
      partyName: 'شركة العمران للمقاولات',
      invoiceType: 'بيع_معتمد',
      items: [
        FactoryInvoiceItem(
          itemId: 'fw1',
          description: 'رخام كاردينال درجة أولى 2سم',
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          lengthCm: 200,
          widthCm: 100,
          quantity: 10,
          unitPrice: 22.0,
          unitCost: 14.5,
          services: [
            ServiceAttachment(
                serviceName: 'شطف حواف وتفريز',
                price: 120.0,
                notes: 'شطف دبل'),
          ],
        ),
      ],
      isGoodsDelivered: false,
      advancePayment: 200.0,
    ));

    final inv = erp.factoryInvoices.last;
    // Goods 2*1*10=20... area = (200/100)*(100/100)*10 = 20 m2 * 22 = 440
    // + service 120 = 560, - 200 = 360 due.
    expect(inv.grandTotal, closeTo(560.0, 0.001));
    expect(inv.isDue, isTrue);
    expect(
        erp.factoryInvoices
            .where((i) => i.invoiceType == 'بيع_معتمد' && i.isDue)
            .length,
        greaterThanOrEqualTo(1));

    final whAfter = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw1')
        .availableQty;
    expect(whAfter, closeTo(whBefore - 20.0, 0.001));

    final client = erp.clients.firstWhere((c) => c.id == 'cli1');
    expect(client.debtBalance, closeTo(18500.0 + 360.0, 0.001));
  });

  test('POS invoice: m3 volume deduction, fully paid', () async {
    final erp = ERPProvider();
    final whBefore = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw4')
        .availableQty;

    erp.addFactoryPOSInvoice(FactoryInvoiceModel(
      id: 'fi_pos_test_2',
      invoiceNo: 'FAC-POS-TEST-2',
      date: DateTime(2026, 1, 8),
      partyId: 'cli1',
      partyName: 'شركة العمران للمقاولات',
      invoiceType: 'بيع_معتمد',
      items: [
        FactoryInvoiceItem(
          itemId: 'fw4',
          description: 'رخام أبيض ترافنتينو 8سم',
          typeName: 'رخام أبيض ترافنتينو',
          grade: 'درجة أولى',
          lengthCm: 100,
          widthCm: 100,
          heightCm: 100,
          quantity: 1,
          unitPrice: 180.0,
          unitCost: 120.0,
        ),
      ],
      isGoodsDelivered: true,
      advancePayment: 180.0,
      photoUrl: 'receipts/pos-2.jpg',
    ));

    final inv = erp.factoryInvoices.last;
    // Volume 1*1*1*1 = 1 m3 * 180 = 180, - 180 = 0 paid.
    expect(inv.grandTotal, closeTo(180.0, 0.001));
    expect(inv.isDue, isFalse);
    expect(inv.paymentStatus, 'مدفوعة');
    expect(inv.photoUrl, 'receipts/pos-2.jpg');

    final whAfter = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw4')
        .availableQty;
    expect(whAfter, closeTo(whBefore - 1.0, 0.001));
  });

  testWidgets('transfer to cutting opens the cutting screen, not dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ERPProvider(),
        child: const MarbleGraniteERPApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Go to the Factory module from the sidebar.
    await tester.tap(find.text('المصنع').first);
    await tester.pumpAndSettle();

    // Open the inventory tab (Section 2).
    await tester.ensureVisible(find.text('2. مخزون مصنع (البلوكات)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. مخزون مصنع (البلوكات)'));
    await tester.pumpAndSettle();

    // Expand the first type+grade group.
    expect(find.byType(ExpansionTile), findsWidgets);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    // Enter tons for cutting in the first lot row.
    final qtyField = find.widgetWithText(TextField, 'أطنان للقص').first;
    await tester.enterText(qtyField, '10');
    await tester.pumpAndSettle();

    // Add to the aggregation (+ button of the first lot row).
    await tester.tap(find.widgetWithText(ElevatedButton, '+').first);
    await tester.pumpAndSettle();

    // Aggregate and transfer.
    await tester.tap(find.text('تجميع (Aggregate)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[نقل إلى عملية القص]'));
    await tester.pumpAndSettle();

    // Must land on the Cutting screen with the staged batch...
    expect(find.text('واجهة القص والتحويل (Cutting Process)'), findsOneWidget);
    // ...and NOT stay on the main dashboard.
    expect(find.text('الشاشة الرئيسية (لوحة القيادة والمؤشرات)'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('staged cutting deducts blocks, merges warehouse, logs operation',
      () async {
    final erp = ERPProvider();
    final tonsBefore = erp.factoryBlocks
        .where((b) => b.typeName == 'رخام كاردينال' && b.grade == 'درجة أولى')
        .fold(0.0, (s, b) => s + b.weightTons);
    final opsBefore = erp.cuttingOperations.length;

    erp.setPendingCuttingBatch([
      CuttingBatchInput(
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        isGranite: false,
        totalTons: 10.0,
        avgTonCost: 110.0,
        selections: [
          CuttingBatchSelection(
              blockId: 'fb1', supplierName: 'س', tons: 10.0, tonCost: 110.0),
        ],
      ),
    ]);
    expect(erp.pendingCuttingBatch.length, 1);

    // 10 tons at 110 with 8% fee -> 1188 over 55 m2 = 21.6/m.
    erp.executeStagedCutting(
      conversions: [
        StagedCutConversion(
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          isGranite: false,
          inputTons: 10.0,
          avgTonCost: 110.0,
          feePercent: 0.08,
          thicknessCm: 3.0,
          category: 'متر مربع',
          outputQty: 55.0,
          netCost: 21.6,
          salePrice: 30.0,
        ),
      ],
      wasteValue: 5.0,
    );

    final tonsAfter = erp.factoryBlocks
        .where((b) => b.typeName == 'رخام كاردينال' && b.grade == 'درجة أولى')
        .fold(0.0, (s, b) => s + b.weightTons);
    expect(tonsAfter, closeTo(tonsBefore - 10.0, 0.001));
    expect(erp.pendingCuttingBatch, isEmpty);
    expect(erp.cuttingOperations.length, opsBefore + 1);

    final wh = erp.factoryWarehouse.firstWhere((w) =>
        w.typeName == 'رخام كاردينال' &&
        w.grade == 'درجة أولى' &&
        w.thicknessCm == 3.0);
    expect(wh.availableQty, greaterThan(0));
  });

  test(
      'single purchase invoice with both blocks and meters updates factoryBlocks and factoryWarehouse',
      () async {
    final erp = ERPProvider();
    final blocksCountBefore = erp.factoryBlocks.length;
    final whExisting = erp.factoryWarehouse.firstWhere((w) =>
        w.typeName == 'رخام كاردينال' &&
        w.grade == 'درجة أولى' &&
        w.thicknessCm == 2.0);
    final whQtyBefore = whExisting.availableQty;
    final whCostBefore = whExisting.netCostPerUnit;

    final invoice = FactoryInvoiceModel(
      id: 'fi_mixed_1',
      invoiceNo: 'FAC-PUR-MIX-1',
      date: DateTime(2026, 1, 10),
      partyId: 'sup1',
      partyName: 'شركة مقالع الرخام الوطنية',
      invoiceType: 'شراء_مورد',
      items: [
        // 1. Blocks line item
        FactoryInvoiceItem(
          itemId: 'item_blk_1',
          description: 'بازلت (درجة أولى)',
          typeName: 'بازلت',
          grade: 'درجة أولى',
          quantity: 10.0,
          unitPrice: 120.0,
          unitCost: 120.0,
          itemCategory: 'block',
        ),
        // 2. Meters line item
        FactoryInvoiceItem(
          itemId: 'mt1',
          description: 'رخام كاردينال (درجة أولى) 2سم - متر مربع',
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          thicknessCm: 2.0,
          quantity: 50.0,
          unitPrice: 30.0,
          unitCost: 30.0,
          itemCategory: 'meter',
          meterUnit: 'متر مربع',
        ),
      ],
      isGoodsDelivered: true,
      advancePayment: 700.0,
    );

    // Blocks: 10 * 120 = 1200, Meters: 50 * 30 = 1500. Total = 2700.
    expect(invoice.grandTotal, 2700.0);
    expect(invoice.remainingBalance, 2000.0);
    expect(invoice.isDue, isTrue);

    final saved = erp.addSupplierPurchaseInvoice(invoice);
    expect(saved, isTrue);

    // 1. Factory Block Inventory received the block item
    expect(erp.factoryBlocks.length, blocksCountBefore + 1);
    final addedBlock = erp.factoryBlocks.last;
    expect(addedBlock.typeName, 'بازلت');
    expect(addedBlock.weightTons, 10.0);
    expect(addedBlock.tonCost, 120.0);

    // 2. Factory Warehouse Inventory received the meter item
    final whUpdated = erp.factoryWarehouse.firstWhere((w) =>
        w.typeName == 'رخام كاردينال' &&
        w.grade == 'درجة أولى' &&
        w.thicknessCm == 2.0);
    expect(whUpdated.availableQty, closeTo(whQtyBefore + 50.0, 0.001));
    // Weighted average cost: (prevQty * prevCost + 50 * 30) / (prevQty + 50)
    final expectedCost =
        ((whQtyBefore * whCostBefore) + (50.0 * 30.0)) / (whQtyBefore + 50.0);
    expect(whUpdated.netCostPerUnit, closeTo(expectedCost, 0.001));

    // 3. Supplier debt increased by remainder
    final sup = erp.suppliers.firstWhere((s) => s.id == 'sup1');
    expect(sup.debtBalance, closeTo(25000.0 + 2000.0, 0.001));
  });

  test(
      'cash purchase invoice with meter item is paid from main cash box and increases factoryWarehouse',
      () async {
    final erp = ERPProvider();
    final cashBefore = erp.cashOf('main', AppCurrency.usd);

    final invoice = FactoryInvoiceModel(
      id: 'fi_cash_meter_1',
      invoiceNo: 'FAC-PUR-CASH-M1',
      date: DateTime(2026, 1, 11),
      partyId: 'sup2',
      partyName: 'مؤسسة الغرانيت المستورد',
      invoiceType: 'شراء_مورد',
      isCashInvoice: true,
      items: [
        FactoryInvoiceItem(
          itemId: 'mt_new_1',
          description: 'غرانيت أسود جالكسي (ممتاز) 3سم - متر مربع',
          typeName: 'غرانيت أسود جالكسي',
          grade: 'ممتاز',
          thicknessCm: 3.0,
          quantity: 20.0,
          unitPrice: 45.0,
          unitCost: 45.0,
          isGranite: true,
          itemCategory: 'meter',
          meterUnit: 'متر مربع',
        ),
      ],
      isGoodsDelivered: true,
      advancePayment: 900.0, // Full payment
    );

    expect(invoice.grandTotal, 900.0);
    expect(invoice.remainingBalance, 0.0);

    final saved = erp.addSupplierPurchaseInvoice(invoice);
    expect(saved, isTrue);

    // Main cash box deducted
    expect(erp.cashOf('main', AppCurrency.usd), closeTo(cashBefore - 900.0, 0.001));

    // Warehouse has the granite meters
    final wh = erp.factoryWarehouse.firstWhere((w) =>
        w.typeName == 'غرانيت أسود جالكسي' &&
        w.grade == 'ممتاز' &&
        w.thicknessCm == 3.0);
    expect(wh.isGranite, isTrue);
    expect(wh.availableQty, greaterThanOrEqualTo(20.0));
  });

  test(
      'undelivered purchase invoice distributes shipping fee proportionally across blocks and meters',
      () async {
    final erp = ERPProvider();
    final blocksCountBefore = erp.factoryBlocks.length;

    // Capital: Block 10 tons * $100 = $1,000. Meter 50 m2 * $20 = $1,000. Total capital = $2,000.
    // Shipping fee = $200.
    // Block share: (1000 / 2000) * 200 = $100 -> effective ton cost = $100 + ($100 / 10) = $110.
    // Meter share: (1000 / 2000) * 200 = $100 -> effective unit cost = $20 + ($100 / 50) = $22.
    final invoice = FactoryInvoiceModel(
      id: 'fi_shipping_prop_1',
      invoiceNo: 'FAC-PUR-SHIP-1',
      date: DateTime(2026, 1, 12),
      partyId: 'sup1',
      partyName: 'شركة مقالع الرخام الوطنية',
      invoiceType: 'شراء_مورد',
      items: [
        FactoryInvoiceItem(
          itemId: 'blk_s1',
          description: 'بازلت (درجة أولى)',
          typeName: 'بازلت',
          grade: 'درجة أولى',
          quantity: 10.0,
          unitPrice: 100.0,
          unitCost: 100.0,
          itemCategory: 'block',
        ),
        FactoryInvoiceItem(
          itemId: 'mt_brand_new',
          description: 'حجر ترافرتين (درجة ثانية) 2سم - متر مربع',
          typeName: 'حجر ترافرتين',
          grade: 'درجة ثانية',
          thicknessCm: 2.0,
          quantity: 50.0,
          unitPrice: 20.0,
          unitCost: 20.0,
          itemCategory: 'meter',
          meterUnit: 'متر مربع',
        ),
      ],
      isGoodsDelivered: false,
      shippingFee: 200.0,
      advancePayment: 2200.0,
    );

    expect(invoice.grandTotal, 2200.0);
    final saved = erp.addSupplierPurchaseInvoice(invoice);
    expect(saved, isTrue);

    // Verify block cost includes shipping
    expect(erp.factoryBlocks.length, blocksCountBefore + 1);
    final addedBlock = erp.factoryBlocks.last;
    expect(addedBlock.tonCost, closeTo(110.0, 0.001));

    // Verify new warehouse item includes shipping
    final whNew = erp.factoryWarehouse.firstWhere((w) =>
        w.typeName == 'حجر ترافرتين' &&
        w.grade == 'درجة ثانية' &&
        w.thicknessCm == 2.0);
    expect(whNew.availableQty, 50.0);
    expect(whNew.netCostPerUnit, closeTo(22.0, 0.001));
  });

  testWidgets('dialog allows switching to meters and adding a meters purchase item',
      (tester) async {
    final erp = ERPProvider();
    await openSupplierInvoiceTab(tester, erp);

    // Verify tabs exist
    expect(find.text('بند شراء بلوكات (Blocks)'), findsOneWidget);
    expect(find.text('بند شراء أمتار (Meters)'), findsOneWidget);

    // Switch to Meters
    await tester.tap(find.text('بند شراء أمتار (Meters)'));
    await tester.pumpAndSettle();

    // Verify meter fields are displayed
    expect(find.text('بحث نوع المتر أو السماكة...'), findsOneWidget);
    expect(find.text('وحدة القياس: '), findsOneWidget);
    expect(find.text('متر مربع (م²)'), findsOneWidget);
    expect(find.text('متر طولي (م.ط)'), findsOneWidget);
    expect(find.text('إضافة بند الأمتار للفاتورة +'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
