import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/core/theme/app_theme.dart';
import 'package:marble_granite_erp/screens/factory_workspace_screen.dart';
import 'package:marble_granite_erp/screens/financials_screen.dart';
import 'package:marble_granite_erp/screens/workshop_workspace_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> setDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget workshopWrap(ERPProvider erp) =>
      ChangeNotifierProvider<ERPProvider>.value(
        value: erp,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: const WorkshopWorkspaceScreen(),
          ),
        ),
      );

  Widget factoryWrap(ERPProvider erp) =>
      ChangeNotifierProvider<ERPProvider>.value(
        value: erp,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FactoryWorkspaceScreen(onNavigateToCutting: (_) {}),
          ),
        ),
      );

  Future<void> openWorkshopTab(
      WidgetTester tester, ERPProvider erp, String tab) async {
    await setDesktop(tester);
    await tester.pumpWidget(workshopWrap(erp));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  testWidgets('materials transfer dialog opens', (tester) async {
    await openWorkshopTab(
        tester, ERPProvider(), '1. مواد المعمل (Raw Stock)');
    await tester.tap(find.text('تحويل كمية من مستودع المصنع'));
    await tester.pumpAndSettle();
    expect(find.text('تحويل كمية من مستودع المصنع إلى المعمل'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple tailoring builder opens', (tester) async {
    await openWorkshopTab(
        tester, ERPProvider(), '2. مفصل (تفصيلات بسيطة ومعقدة)');
    await tester.tap(find.text('[إضافة تفصيل بسيط]'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة تفصيل بسيط جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workshop invoice builder opens', (tester) async {
    await openWorkshopTab(
        tester, ERPProvider(), '6. فاتورة معمل (Workshop Invoices)');
    await tester.tap(find.text('[إضافة فاتورة معمل]'));
    await tester.pumpAndSettle();
    expect(find.text('إنشاء فاتورة معمل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('factory orders tab + builder open', (tester) async {
    final erp = ERPProvider();
    await setDesktop(tester);
    await tester.pumpWidget(factoryWrap(erp));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('9. طلبيات المصنع (Orders)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9. طلبيات المصنع (Orders)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة طلبية مصنع'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة طلبية مصنع (قيد التنفيذ)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('financials shows new sections, projects tab works',
      (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<ERPProvider>.value(
        value: ERPProvider(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: const FinancialsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in [
      '3. مالية موردي المصنع',
      '4. مالية معتمدي المصنع',
      '5. مالية القوى العاملة',
      '6. مالية المعمل',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Old supplier tab is gone.
    expect(find.textContaining('مالية الموردين (Supplier Finances)'),
        findsNothing);

    // Workforce tab renders its three inner tabs.
    await tester.tap(find.text('5. مالية القوى العاملة'));
    await tester.pumpAndSettle();
    expect(find.text('العمال (Workers)'), findsOneWidget);
    expect(find.text('المعلمون (Masters)'), findsOneWidget);
    expect(find.text('الإداريون (Admin)'), findsOneWidget);

    // Workshop finances tab renders retail + projects.
    await tester.tap(find.text('6. مالية المعمل'));
    await tester.pumpAndSettle();
    expect(find.text('زبائن الجزافي (Retail Clients)'), findsOneWidget);
    expect(find.text('المشاريع (Projects)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workshop projects section CRUD tabs render', (tester) async {
    await openWorkshopTab(
        tester, ERPProvider(), '7. المشاريع (Projects)');
    expect(find.text('بانتظار الدفع (Pending Payment)'), findsOneWidget);
    expect(find.text('مكتملة / مدفوعة (Completed)'), findsOneWidget);
    await tester.tap(find.text('إضافة مشروع'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة مشروع جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('tailoring line deducts stock and totals hold', () async {
    final erp = ERPProvider();
    final before = erp.workshopStock
        .firstWhere((w) => w.id == 'ws1')
        .availableQty;
    final line = TailoringLineItem(
      id: 'tl_1',
      source: 'materials',
      stockId: 'ws1',
      typeName: 'رخام كاردينال',
      grade: 'درجة أولى',
      thicknessCm: 2.0,
      category: 'متر مربع',
      lengthCm: 120,
      widthCm: 33,
      quantity: 10,
      netCostPerMeter: 14.5,
      sellingPricePerMeter: 24.0,
      laborPerPiece: 5.0,
      services: [
        ServiceAttachment(serviceName: 'جلي', price: 45.0),
      ],
    );
    expect(line.area, closeTo(1.2 * 0.33 * 10, 0.001));
    expect(erp.deductWorkshopStock('ws1', line.area), isTrue);
    final after = erp.workshopStock
        .firstWhere((w) => w.id == 'ws1')
        .availableQty;
    expect(after, closeTo(before - line.area, 0.001));
    expect(erp.deductWorkshopStock('ws1', 1e9), isFalse);
  });

  test('workshop invoice from order moves deposit to main box', () async {
    final erp = ERPProvider();
    final mainBefore = erp.mainCashBox;
    final orderBefore = erp.orderCashBox;
    erp.createWorkshopOrder(WorkshopOrderModel(
      id: 'wo_t1',
      orderNo: 'ORD-T1',
      date: DateTime(2026, 1, 10),
      clientName: 'زبون اختبار',
      clientPhone: '000',
      customDimensionsText: 'درج',
      agreedPrice: 750.0,
      depositAmount: 300.0,
    ));
    expect(erp.orderCashBox, closeTo(orderBefore + 300.0, 0.001));

    erp.createWorkshopInvoice(
      WorkshopInvoiceModel(
        id: 'wi_t1',
        invoiceNo: 'WRK-INV-T1',
        date: DateTime(2026, 1, 11),
        clientName: 'زبون اختبار',
        sourceType: 'طلبية معمل',
        sourceId: 'wo_t1',
        itemDescription: 'درج',
        agreedPrice: 750.0,
        depositDeducted: 300.0,
        cashPaidNow: 450.0,
        netCost: 400.0,
      ),
    );
    expect(erp.orderCashBox, closeTo(orderBefore, 0.001));
    expect(erp.mainCashBox, closeTo(mainBefore + 750.0, 0.001));
    expect(
        erp.workshopOrders
            .firstWhere((o) => o.id == 'wo_t1')
            .status,
        'مكتملة ومرحلة');
  });

  test('scrap invoice routes to scrap box', () async {
    final erp = ERPProvider();
    final scrapBefore = erp.scrapCashBox;
    erp.createWorkshopInvoice(
      WorkshopInvoiceModel(
        id: 'wi_t2',
        invoiceNo: 'WRK-INV-T2',
        date: DateTime(2026, 1, 11),
        clientName: 'زبون',
        sourceType: 'قطع زائدة',
        sourceId: 'sc1',
        itemDescription: 'قصاصات',
        agreedPrice: 40.0,
        depositDeducted: 0.0,
        cashPaidNow: 40.0,
        netCost: 15.0,
      ),
    );
    expect(erp.scrapCashBox, closeTo(scrapBefore + 40.0, 0.001));
    expect(erp.scrapItems.firstWhere((s) => s.id == 'sc1').isSold, isTrue);
  });

  test('factory order assign creates POS invoice and deducts stock',
      () async {
    final erp = ERPProvider();
    final whBefore = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw1')
        .availableQty;
    final invBefore = erp.factoryInvoices.length;
    erp.createFactoryOrder(FactoryOrderModel(
      id: 'fo_t1',
      orderNo: 'FORD-T1',
      date: DateTime(2026, 1, 12),
      clientName: 'معتمد اختبار',
      clientPhone: '111',
      warehouseItemId: 'fw1',
      itemDescription: 'رخام كاردينال 2سم',
      lengthCm: 200,
      widthCm: 100,
      quantity: 10,
      unitPrice: 22.0,
      agreedPrice: 440.0,
      depositAmount: 100.0,
    ));
    erp.assignFactoryOrderToInvoice(
        erp.factoryOrders.firstWhere((o) => o.id == 'fo_t1'), 340.0);

    expect(erp.factoryInvoices.length, invBefore + 1);
    final inv = erp.factoryInvoices.last;
    expect(inv.invoiceType, 'بيع_معتمد');
    expect(inv.isDue, isFalse);
    expect(
        erp.factoryOrders.firstWhere((o) => o.id == 'fo_t1').status,
        'مكتملة ومرحلة');
    final whAfter = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw1')
        .availableQty;
    expect(whAfter, closeTo(whBefore - 20.0, 0.001));
  });

  test('cancel keeps deposit as profit unless special refund', () async {
    final erp = ERPProvider();
    final base = erp.orderCashBox;
    final ord = WorkshopOrderModel(
      id: 'wo_t2',
      orderNo: 'ORD-T2',
      date: DateTime(2026, 1, 12),
      clientName: 'زبون',
      clientPhone: '',
      customDimensionsText: 'x',
      agreedPrice: 500.0,
      depositAmount: 200.0,
    );
    erp.createWorkshopOrder(ord);
    erp.cancelWorkshopOrder(ord, false);
    expect(erp.orderCashBox, closeTo(base + 200.0, 0.001));
    expect(ord.status, 'ملغاة');

    final ord2 = WorkshopOrderModel(
      id: 'wo_t3',
      orderNo: 'ORD-T3',
      date: DateTime(2026, 1, 12),
      clientName: 'زبون',
      clientPhone: '',
      customDimensionsText: 'x',
      agreedPrice: 500.0,
      depositAmount: 200.0,
    );
    erp.createWorkshopOrder(ord2);
    erp.cancelWorkshopOrder(ord2, true);
    expect(erp.orderCashBox, closeTo(base + 200.0, 0.001));
  });

  test('supplier pay moves invoice toward Paid', () async {
    final erp = ERPProvider();
    erp.addSupplierPurchaseInvoice(FactoryInvoiceModel(
      id: 'fi_pay_1',
      invoiceNo: 'FAC-PUR-PAY-1',
      date: DateTime(2026, 2, 1),
      partyId: 'sup1',
      partyName: 'شركة مقالع الرخام الوطنية',
      invoiceType: 'شراء_مورد',
      items: [
        FactoryInvoiceItem(
            itemId: 'd1',
            description: 'بازلت',
            typeName: 'بازلت',
            grade: 'درجة أولى',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 100.0),
      ],
      isGoodsDelivered: true,
      advancePayment: 200.0,
    ));
    final inv = erp.factoryInvoices.last;
    expect(inv.isDue, isTrue);
    final mainBefore = erp.mainCashBox;
    final debtBefore = erp.suppliers
        .firstWhere((s) => s.id == 'sup1')
        .debtBalance;
    expect(erp.paySupplierInvoice(inv, 800.0), isTrue);
    expect(inv.isDue, isFalse);
    expect(inv.paymentStatus, 'مدفوعة');
    expect(erp.mainCashBox, closeTo(mainBefore - 800.0, 0.001));
    expect(
        erp.suppliers.firstWhere((s) => s.id == 'sup1').debtBalance,
        closeTo(debtBefore - 800.0, 0.001));
    // Overpay / empty payment rejected.
    expect(erp.paySupplierInvoice(inv, 10.0), isFalse);
  });

  test('factory client collect moves invoice toward Paid', () async {
    final erp = ERPProvider();
    erp.addFactoryPOSInvoice(FactoryInvoiceModel(
      id: 'fi_col_1',
      invoiceNo: 'FAC-POS-COL-1',
      date: DateTime(2026, 2, 2),
      partyId: 'cli1',
      partyName: 'شركة العمران للمقاولات',
      invoiceType: 'بيع_معتمد',
      items: [
        FactoryInvoiceItem(
            itemId: 'fw1',
            description: 'رخام',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            lengthCm: 200,
            widthCm: 100,
            quantity: 10,
            unitPrice: 22.0,
            unitCost: 14.5),
      ],
      isGoodsDelivered: true,
      advancePayment: 100.0,
    ));
    final inv = erp.factoryInvoices.last;
    expect(inv.isDue, isTrue);
    final mainBefore = erp.mainCashBox;
    expect(erp.collectFactoryInvoice(inv, inv.remainingBalance), isTrue);
    expect(inv.isDue, isFalse);
    expect(erp.mainCashBox, greaterThan(mainBefore));
  });

  test('staff settlement zeroes the due balance', () async {
    final erp = ERPProvider();
    erp.mainCashBox = 100000.0;
    final stf = erp.staffList.first;
    expect(stf.netRemainingBalance, greaterThan(0));
    expect(erp.settleStaffDue(stf), isTrue);
    expect(stf.netRemainingBalance, closeTo(0.0, 0.001));
    expect(erp.settleStaffDue(stf), isFalse);
  });

  test('project lifecycle: pending -> invoiced -> completed', () async {
    final erp = ERPProvider();
    erp.addProject(WorkshopProjectModel(
      id: 'prj_t1',
      name: 'مشروع اختبار',
      clientName: 'زبون مشروع',
    ));
    expect(erp.pendingProjects.map((p) => p.id), contains('prj_t1'));

    erp.createWorkshopInvoice(
      WorkshopInvoiceModel(
        id: 'wi_prj_1',
        invoiceNo: 'WRK-PRJ-1',
        date: DateTime(2026, 2, 3),
        clientName: 'زبون مشروع',
        sourceType: 'تفصيل بسيط',
        projectId: 'prj_t1',
        itemDescription: 'درج',
        agreedPrice: 500.0,
        depositDeducted: 0.0,
        cashPaidNow: 100.0,
        netCost: 300.0,
      ),
    );
    expect(erp.projectDue('prj_t1'), closeTo(400.0, 0.001));
    expect(erp.pendingProjects.map((p) => p.id), contains('prj_t1'));

    final inv = erp.workshopInvoices.firstWhere((i) => i.id == 'wi_prj_1');
    expect(erp.collectWorkshopInvoice(inv, 400.0), isTrue);
    expect(erp.projectDue('prj_t1'), closeTo(0.0, 0.001));
    expect(
        erp.completedProjects.map((p) => p.id), contains('prj_t1'));
    expect(
        erp.pendingProjects.map((p) => p.id), isNot(contains('prj_t1')));

    erp.deleteProject('prj_t1');
    expect(erp.workshopProjects, isEmpty);
  });

  test('sales returns restore stock', () async {
    final erp = ERPProvider();
    final fw = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw1');
    final before = fw.availableQty;
    erp.processReturnInvoice(ReturnInvoiceModel(
      id: 'ret_t1',
      returnNo: 'RET-T1',
      date: DateTime(2026, 1, 13),
      returnType: 'مرتجع مبيعات مصنع',
      partyName: 'زبون',
      itemDescription: 'رخام كاردينال 2سم مرتجع',
      quantity: 5.0,
      refundAmount: 110.0,
      paymentAction: 'تخفيض دين',
    ));
    expect(fw.availableQty, closeTo(before + 5.0, 0.001));

    final ws = erp.workshopStock.firstWhere((w) => w.id == 'ws1');
    final wsBefore = ws.availableQty;
    erp.processReturnInvoice(ReturnInvoiceModel(
      id: 'ret_t2',
      returnNo: 'RET-T2',
      date: DateTime(2026, 1, 13),
      returnType: 'مرتجع مبيعات معمل',
      partyName: 'زبون',
      itemDescription: 'رخام كاردينال',
      quantity: 2.0,
      refundAmount: 50.0,
      paymentAction: 'تخفيض دين',
    ));
    expect(ws.availableQty, closeTo(wsBefore + 2.0, 0.001));
  });
}
