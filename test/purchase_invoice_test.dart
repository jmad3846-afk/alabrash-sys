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
}
