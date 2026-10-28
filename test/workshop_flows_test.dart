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
import 'package:marble_granite_erp/screens/workforce_screen.dart';
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
    WidgetTester tester,
    ERPProvider erp,
    String tab,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(workshopWrap(erp));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  testWidgets('materials transfer dialog opens', (tester) async {
    await openWorkshopTab(tester, ERPProvider(), '1. مواد المعمل (Raw Stock)');
    await tester.tap(find.text('تحويل كمية من مستودع المصنع'));
    await tester.pumpAndSettle();
    expect(find.text('تحويل كمية من مستودع المصنع إلى المعمل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple tailoring builder opens', (tester) async {
    await openWorkshopTab(
      tester,
      ERPProvider(),
      '2. مفصل (تفصيلات بسيطة ومعقدة)',
    );
    await tester.tap(find.text('[إضافة تفصيل بسيط]'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة تفصيل بسيط جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workshop invoice builder opens', (tester) async {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('ERR_SUMMARY: ${details.summary}');
      if (details.informationCollector != null) {
        for (final info in details.informationCollector!()) {
          debugPrint('ERR_INFO: $info');
        }
      }
      oldHandler?.call(details);
    };
    await openWorkshopTab(
      tester,
      ERPProvider(),
      '6. فاتورة معمل (Workshop Invoices)',
    );
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
    await tester.tap(find.textContaining('إضافة طلبية مصنع'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة طلبية مصنع جديدة (Factory Order)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('financials shows new sections, projects tab works', (
    tester,
  ) async {
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
      '5. مالية المعمل',
      '6. مالية الزيادات (Surplus Financials)',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Old workforce tab and old supplier tab are gone.
    expect(
      find.textContaining('مالية القوى العاملة'),
      findsNothing,
    );
    expect(
      find.textContaining('مالية الموردين (Supplier Finances)'),
      findsNothing,
    );

    // Workshop finances tab renders retail finances directly (Projects removed).
    await tester.tap(find.text('5. مالية المعمل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('مالية المشاريع'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workshop projects section removed and replaced cleanly', (tester) async {
    final erp = ERPProvider();
    await setDesktop(tester);
    await tester.pumpWidget(workshopWrap(erp));
    await tester.pumpAndSettle();
    expect(find.textContaining('المشاريع'), findsNothing);
    expect(find.text('7. مرتجعات ومسموحات المبيعات'), findsOneWidget);
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
      laborPerMeter: 5.0,
      services: [ServiceAttachment(serviceName: 'جلي', price: 45.0)],
    );
    expect(line.area, closeTo(1.2 * 0.33 * 10, 0.001));
    expect(erp.deductWorkshopStock('ws1', line.area), isTrue);
    final after = erp.workshopStock
        .firstWhere((w) => w.id == 'ws1')
        .availableQty;
    expect(after, closeTo(before - line.area, 0.001));
    expect(erp.deductWorkshopStock('ws1', 1e9), isFalse);
  });

  testWidgets('simple tailoring builder keeps only name and material items', (
    tester,
  ) async {
    final erp = ERPProvider();
    await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
    await tester.tap(find.text('[إضافة تفصيل بسيط]'));
    await tester.pumpAndSettle();

    expect(find.text('اسم التفصيل'), findsOneWidget);
    expect(find.text('بنود المواد (أضف كل بند بزر +):'), findsOneWidget);
    expect(find.text('وحدة البيع'), findsNothing);
    expect(find.text('الطول (سم)'), findsNothing);
    expect(find.text('العرض (سم)'), findsNothing);
    expect(find.text('الكمية الناتجة:'), findsNothing);
    expect(find.textContaining('سعر البيع للمتر م²'), findsNothing);
    expect(find.textContaining('صورة التفصيل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'complex tailoring keeps only name before material lines and derives stock unit',
    (tester) async {
      final erp = ERPProvider();
      final wsItem = erp.workshopStock.lastWhere((w) => w.typeName.contains('رخام كاردينال'));
      final stockBefore = wsItem.availableQty;
      await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
      await tester.tap(find.text('تفصيل معقد (Complex)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('[إضافة تفصيل معقد]'));
      await tester.pumpAndSettle();

      expect(find.text('اسم التفصيل'), findsOneWidget);
      expect(find.text('بنود المواد (أضف كل بند بزر +):'), findsOneWidget);
      expect(find.text('وحدة البيع'), findsNothing);
      expect(find.text('الطول (سم)'), findsNothing);
      expect(find.text('العرض (سم)'), findsNothing);
      expect(find.text('الارتفاع (سم)'), findsNothing);
      expect(find.text('الكمية الناتجة:'), findsNothing);
      expect(find.textContaining('صورة التفصيل'), findsNothing);

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'اسم التفصيل',
        ),
        'تفصيل معقد اختبار',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('رخام كاردينال').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'الطول (سم)',
        ),
        '100',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'العرض (سم)',
        ),
        '100',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'الكمية',
        ),
        '2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة بند المواد +'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التفصيل بالمتر'));
      await tester.pumpAndSettle();

      final tailoring = erp.complexTailorings.last;
      expect(tailoring.name, 'تفصيل معقد اختبار');
      expect(tailoring.quantity, 1);
      expect(tailoring.unitCategory, 'قطعة');
      expect(tailoring.lengthCm, 0);
      expect(
        erp.workshopStock.firstWhere((item) => item.id == wsItem.id).availableQty,
        closeTo(stockBefore - 2, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'simple tailoring shows material consumption and blocks overselling stock',
    (tester) async {
      final erp = ERPProvider();
      final wsItem = erp.workshopStock.lastWhere((w) => w.typeName.contains('رخام كاردينال'));
      wsItem.availableQty = 85.0;
      final originalStock = wsItem.availableQty;
      final originalTailorings = erp.simpleTailorings.length;
      await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
      await tester.tap(find.text('[إضافة تفصيل بسيط]'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'اسم التفصيل',
        ),
        'تفصيل اختبار',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('رخام كاردينال').last);
      await tester.pumpAndSettle();

      Future<void> enterMaterialDimensions(String quantity) async {
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'الطول (سم)',
          ),
          '100',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'العرض (سم)',
          ),
          '100',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == 'الكمية',
          ),
          quantity,
        );
        await tester.pumpAndSettle();
      }

      await enterMaterialDimensions('50');
      expect(
        find.textContaining('استهلاك المادة المحددة: 50 م²'),
        findsOneWidget,
      );
      await tester.tap(find.text('إضافة بند المواد +'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('رخام كاردينال').last);
      await tester.pumpAndSettle();
      await enterMaterialDimensions('36');
      expect(find.textContaining('سبق تخصيصه: 50'), findsOneWidget);
      expect(find.textContaining('المتبقي بعد هذا البند: -1'), findsOneWidget);
      await tester.tap(find.text('إضافة بند المواد +'));
      await tester.pumpAndSettle();
      expect(find.textContaining('الكمية تتجاوز المتاح'), findsOneWidget);
      expect(erp.simpleTailorings.length, originalTailorings);

      await enterMaterialDimensions('35');
      expect(find.textContaining('المتبقي بعد هذا البند: 0'), findsOneWidget);
      await tester.tap(find.text('إضافة بند المواد +'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التفصيل بالمتر'));
      await tester.pumpAndSettle();

      expect(erp.simpleTailorings.length, originalTailorings + 1);
      expect(erp.simpleTailorings.last.name, 'تفصيل اختبار');
      expect(erp.simpleTailorings.last.quantity, 85);
      expect(
        erp.workshopStock.firstWhere((item) => item.id == wsItem.id).availableQty,
        closeTo(originalStock - 85, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('workshop invoice from order moves deposit to main box', () async {
    final erp = ERPProvider();
    final mainBefore = erp.mainCashBox;
    final orderBefore = erp.orderCashBox;
    erp.createWorkshopOrder(
      WorkshopOrderModel(
        id: 'wo_t1',
        orderNo: 'ORD-T1',
        date: DateTime(2026, 1, 10),
        clientName: 'زبون اختبار',
        clientPhone: '000',
        customDimensionsText: 'درج',
        agreedPrice: 750.0,
        depositAmount: 300.0,
      ),
    );
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
      erp.workshopOrders.firstWhere((o) => o.id == 'wo_t1').status,
      'مكتملة ومرحلة',
    );
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

  test('factory order assign creates POS invoice and deducts stock', () async {
    final erp = ERPProvider();
    final whBefore = erp.factoryWarehouse
        .firstWhere((w) => w.id == 'fw1')
        .availableQty;
    final invBefore = erp.factoryInvoices.length;
    erp.createFactoryOrder(
      FactoryOrderModel(
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
      ),
    );
    erp.assignFactoryOrderToInvoice(
      erp.factoryOrders.firstWhere((o) => o.id == 'fo_t1'),
      340.0,
    );

    expect(erp.factoryInvoices.length, invBefore + 1);
    final inv = erp.factoryInvoices.last;
    expect(inv.invoiceType, 'بيع_معتمد');
    expect(inv.isDue, isFalse);
    expect(
      erp.factoryOrders.firstWhere((o) => o.id == 'fo_t1').status,
      'مكتملة ومرحلة',
    );
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
    erp.addSupplierPurchaseInvoice(
      FactoryInvoiceModel(
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
            unitCost: 100.0,
          ),
        ],
        isGoodsDelivered: true,
        advancePayment: 200.0,
      ),
    );
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
      closeTo(debtBefore - 800.0, 0.001),
    );
    // Overpay / empty payment rejected.
    expect(erp.paySupplierInvoice(inv, 10.0), isFalse);
  });

  test('factory client collect moves invoice toward Paid', () async {
    final erp = ERPProvider();
    erp.addFactoryPOSInvoice(
      FactoryInvoiceModel(
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
            unitCost: 14.5,
          ),
        ],
        isGoodsDelivered: true,
        advancePayment: 100.0,
      ),
    );
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
    expect(erp.expenseTypes.any((type) => type.name == 'أجور العمال'), isTrue);
    expect(erp.expenseRecords.last.staffId, stf.id);
    expect(erp.expenseRecords.last.amount, closeTo(1050, 0.001));
    expect(erp.settleStaffDue(stf), isFalse);
    expect(erp.settleStaffDue(erp.staffList[1]), isTrue);
    expect(
      erp.expenseTypes.where((type) => type.name == 'أجور العمال'),
      hasLength(1),
    );
  });

  test(
    'worker type attendance accrues its rate and opens a clean next week',
    () async {
      final erp = ERPProvider();
      final type = StaffTypeModel(
        id: 'worker_type_test',
        category: 'عمال',
        name: 'عامل قص',
        dailyRate: 72,
      );
      expect(erp.addStaffType(type), isTrue);
      final worker = StaffModel(
        id: 'worker_test',
        name: 'عامل اختبار',
        category: 'عمال',
        phone: '',
        typeId: type.id,
      );
      erp.addStaff(worker);
      final monday = erp.activeWorkweekStart;

      expect(
        erp.setStaffAttendance(staff: worker, date: monday, present: true),
        isTrue,
      );
      expect(worker.netRemainingBalance, 72);
      expect(
        erp.setStaffAttendance(staff: worker, date: monday, present: true),
        isTrue,
      );
      expect(worker.netRemainingBalance, 72);
      expect(erp.staffAttendance, hasLength(1));

      await erp.saveToDisk();
      final reloaded = ERPProvider();
      await reloaded.loadFromDisk();
      final reloadedWorker = reloaded.staffList.firstWhere(
        (item) => item.id == worker.id,
      );
      expect(reloaded.staffTypes.any((item) => item.id == type.id), isTrue);
      expect(reloaded.staffAttendance, hasLength(1));
      expect(reloadedWorker.netRemainingBalance, 72);

      erp.openNextWorkweek();
      expect(erp.activeWorkweekStart, monday.add(const Duration(days: 7)));
      expect(erp.staffAttendance, hasLength(1));
      expect(worker.netRemainingBalance, 72);
      expect(
        erp.setStaffAttendance(staff: worker, date: monday, present: false),
        isTrue,
      );
      expect(worker.netRemainingBalance, 0);
      expect(erp.staffAttendance, isEmpty);

      final nextWeekDay = erp.activeWorkweekStart.add(const Duration(days: 1));
      expect(
        erp.setStaffAttendance(staff: worker, date: nextWeekDay, present: true),
        isTrue,
      );
      expect(erp.settleStaffDue(worker), isTrue);
      expect(
        erp.setStaffAttendance(
          staff: worker,
          date: nextWeekDay,
          present: false,
        ),
        isFalse,
      );
      expect(erp.staffAttendance, hasLength(1));
    },
  );

  test('technician workday records agreed daily or fixed amount as a due', () {
    final erp = ERPProvider();
    final technician = erp.staffList.firstWhere(
      (staff) => staff.category == 'معلمين',
    );
    final before = technician.totalEarned;
    final operationalExpensesBefore = erp.totalOperationalExpenses;
    expect(
      erp.recordTechnicianWorkday(
        WorkdayEntryModel(
          id: 'technician_fixed_work_test',
          date: erp.activeWorkweekStart,
          staffNames: [technician.name],
          staffId: technician.id,
          workDescription: 'عقد ثابت',
          rateType: 'حساب مقطوع',
          agreedAmountPerPerson: 215,
        ),
      ),
      isTrue,
    );
    expect(technician.totalEarned, before + 215);
    expect(erp.workdayEntries.last.rateType, 'حساب مقطوع');
    expect(erp.totalOperationalExpenses, operationalExpensesBefore);
  });

  testWidgets('workforce renders Add New Worker and category tabs', (
    tester,
  ) async {
    final erp = ERPProvider();
    await setDesktop(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<ERPProvider>.value(
        value: erp,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WorkforceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('إضافة موظف/عامل جديد'), findsOneWidget);
    expect(find.textContaining('1. العمال (Workers)'), findsOneWidget);
    expect(find.textContaining('2. المعلمون (Masters)'), findsOneWidget);
    expect(find.textContaining('3. الإداريون (Administrators)'), findsOneWidget);

    // Old buttons removed
    expect(find.text('تحديد عمالة'), findsNothing);
    expect(find.text('إضافة نوع عامل'), findsNothing);
    expect(find.text('إضافة نوع إداري'), findsNothing);

    // The three action buttons are present for staff in list
    expect(find.text('دفع أجور'), findsWidgets);
    expect(find.text('دفع سلفة'), findsWidgets);
    expect(find.text('قبض/تحصيل سلفة'), findsWidgets);
  });

  test('workforce advance payment, collection and wages flow', () {
    final erp = ERPProvider();
    erp.mainCashBox = 10000;
    erp.mainCashBoxSyp = 100000000;
    final worker = erp.staffList.firstWhere(
      (staff) => staff.category == 'عمال',
    );
    final initialCashUsd = erp.cashOf('main', AppCurrency.usd);

    // 1. Pay Wages
    expect(erp.payStaffWages(worker, 150, AppCurrency.usd), isTrue);
    expect(erp.cashOf('main', AppCurrency.usd), initialCashUsd - 150);
    expect(
      erp.expenseRecords.any((e) => e.amount == 150 && e.personName == worker.name),
      isTrue,
    );

    // 2. Pay Advance
    final workerAdvBefore = worker.cashAdvancesDisbursed;
    expect(erp.payStaffAdvance(worker, 200, AppCurrency.usd), isTrue);
    expect(worker.cashAdvancesDisbursed, workerAdvBefore + 200);
    expect(
      erp.expenseRecords.any((e) => e.amount == 200 && e.personName == worker.name),
      isTrue,
    );

    // 3. Collect Advance (Same Currency)
    final revBefore = erp.totalAdvanceRepaymentsRevenue;
    expect(
      erp.collectStaffAdvance(
        staff: worker,
        originalCurrency: AppCurrency.usd,
        collectedCurrency: AppCurrency.usd,
        collectedAmount: 50,
        deductedAmount: 50,
      ),
      isTrue,
    );
    expect(worker.cashAdvancesDisbursed, workerAdvBefore + 150);
    expect(erp.totalAdvanceRepaymentsRevenue, revBefore + 50);

    // 4. Collect Advance (Cross-Currency: original advance USD, paid in SYP)
    // 100$ deducted with rate 14000 = 1,400,000 SYP collected
    final sypCashBefore = erp.cashOf('main', AppCurrency.syp);
    expect(
      erp.collectStaffAdvance(
        staff: worker,
        originalCurrency: AppCurrency.usd,
        collectedCurrency: AppCurrency.syp,
        collectedAmount: 1400000,
        deductedAmount: 100,
        exchangeRate: 14000,
      ),
      isTrue,
    );
    expect(erp.cashOf('main', AppCurrency.syp), sypCashBefore + 1400000);
    expect(worker.cashAdvancesDisbursed, workerAdvBefore + 50);
  });

  test('project lifecycle: pending -> invoiced -> completed', () async {
    final erp = ERPProvider();
    erp.addProject(
      WorkshopProjectModel(
        id: 'prj_t1',
        name: 'مشروع اختبار',
        clientName: 'زبون مشروع',
      ),
    );
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
    expect(erp.completedProjects.map((p) => p.id), contains('prj_t1'));
    expect(erp.pendingProjects.map((p) => p.id), isNot(contains('prj_t1')));

    erp.deleteProject('prj_t1');
    expect(erp.workshopProjects, isEmpty);
  });

  test('sales returns restore stock', () async {
    final erp = ERPProvider();
    final fw = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw1');
    final before = fw.availableQty;
    erp.processReturnInvoice(
      ReturnInvoiceModel(
        id: 'ret_t1',
        returnNo: 'RET-T1',
        date: DateTime(2026, 1, 13),
        returnType: 'مرتجع مبيعات مصنع',
        partyName: 'زبون',
        itemDescription: 'رخام كاردينال 2سم مرتجع',
        quantity: 5.0,
        refundAmount: 110.0,
        paymentAction: 'تخفيض دين',
      ),
    );
    expect(fw.availableQty, closeTo(before + 5.0, 0.001));

    final ws = erp.workshopStock.firstWhere((w) => w.id == 'ws1');
    final wsBefore = ws.availableQty;
    erp.processReturnInvoice(
      ReturnInvoiceModel(
        id: 'ret_t2',
        returnNo: 'RET-T2',
        date: DateTime(2026, 1, 13),
        returnType: 'مرتجع مبيعات معمل',
        partyName: 'زبون',
        itemDescription: 'رخام كاردينال',
        quantity: 2.0,
        refundAmount: 50.0,
        paymentAction: 'تخفيض دين',
      ),
    );
    expect(ws.availableQty, closeTo(wsBefore + 2.0, 0.001));
  });
  testWidgets('simple tailoring dialog omits labor cost and shows post-tailoring net cost', (tester) async {
    final erp = ERPProvider();
    await setDesktop(tester);
    await tester.pumpWidget(workshopWrap(erp));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2. مفصل (تفصيلات بسيطة ومعقدة)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. مفصل (تفصيلات بسيطة ومعقدة)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[إضافة تفصيل بسيط]'));
    await tester.pumpAndSettle();

    // In simple tailoring, 'أجر المتر ($)' must NOT appear
    expect(find.text('أجر المتر (\$)'), findsNothing);

    // Enter name
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'اسم التفصيل',
      ),
      'درج بسيط فاخر',
    );

    // Pick material
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('رخام كاردينال').last);
    await tester.pumpAndSettle();

    // Enter dimensions: 120 x 30 cm, qty 10
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'الطول (سم)',
      ),
      '120',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'العرض (سم)',
      ),
      '30',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'الكمية',
      ),
      '10',
    );
    await tester.pumpAndSettle();

    // Check net cost post-tailoring container is shown
    expect(find.textContaining('صافي تكلفة المتر بعد الخدمات'), findsOneWidget);

    // Meter Selling Price is present after services
    expect(find.text('سعر البيع للمتر (\$)'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'سعر البيع للمتر (\$)',
      ),
      '35.0',
    );
    await tester.pumpAndSettle();

    // Add material line
    await tester.tap(find.text('إضافة بند المواد +'));
    await tester.pumpAndSettle();

    // Save tailoring
    await tester.tap(find.text('حفظ التفصيل بالمتر'));
    await tester.pumpAndSettle();

    // In Simple Tailoring, there is no overall price for the entire tailoring item;
    // instead, there is an individual price for each line item on its own.
    final tailoring = erp.simpleTailorings.last;
    expect(tailoring.name, 'درج بسيط فاخر');
    expect(tailoring.quantity, closeTo(3.6, 0.001)); // 1.2 * 0.3 * 10 = 3.6 m2
    expect(tailoring.sellingPrice, 0.0); // No overall selling price for simple tailoring
    expect(tailoring.lineItems.first.sellingPricePerMeter, 35.0); // Individual price for this line item

    expect(find.textContaining('درج بسيط فاخر • المتاح 3.6 م²'), findsOneWidget);
    // Simple tailoring card has no overall selling price chip or total price chip
    expect(find.textContaining('سعر بيع المتر:'), findsNothing);
    expect(find.textContaining('التسعير: تسعير فردي لكل بند على حدة'), findsWidgets);

    // Outside view shows marble type, available quantity in meters, and line item price
    expect(find.textContaining('نوع الرخام: رخام كاردينال'), findsOneWidget);
    expect(find.textContaining('الكمية المتاحة: 3.6 م²'), findsOneWidget);
    expect(find.textContaining('سعر البند: 35 \$ / م²'), findsOneWidget);

    // Open details modal
    await tester.tap(find.byIcon(Icons.info_outline_rounded).last);
    await tester.pumpAndSettle();

    // Verify grouped by marble type
    expect(find.textContaining('بنود التفصيل مصنفة حسب نوع الرخام'), findsOneWidget);
    expect(find.textContaining('نوع الرخام / الخامة: رخام كاردينال'), findsOneWidget);
    expect(find.textContaining('التسعير: تسعير فردي لكل بند على حدة'), findsWidgets);

    // Edit individual line item selling price
    final lineSellingField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText?.contains('سعر بيع المتر لهذا البند') == true,
    );
    expect(lineSellingField, findsOneWidget);
    await tester.enterText(lineSellingField, '42.0');
    await tester.pumpAndSettle();
    await tester.tap(find.text('تطبيق السعر'));
    await tester.pumpAndSettle();

    expect(tailoring.lineItems.first.sellingPricePerMeter, 42.0);
    expect(tailoring.sellingPrice, 0.0); // Remains 0.0 - no overall price for simple tailoring
  });

  test('replenish tailoring line item inventory deducts factory warehouse and updates quantity', () async {
    final erp = ERPProvider();
    final fw = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw1');
    final fwBefore = fw.availableQty;

    final lineItem = TailoringLineItem(
      id: 'li_rep_1',
      source: 'materials',
      stockId: 'ws1',
      typeName: fw.typeName,
      grade: fw.grade,
      thicknessCm: fw.thicknessCm,
      category: fw.category,
      lengthCm: 100,
      widthCm: 100,
      quantity: 5,
      netCostPerMeter: fw.netCostPerUnit,
      sellingPricePerMeter: 30.0,
      services: [ServiceAttachment(serviceName: 'شطف', price: 20.0)],
    );

    final tailoring = WorkshopTailoringModel(
      id: 'tailoring_rep_test',
      name: 'تفصيل مخزون اختبار',
      complexity: 'بسيط',
      rawMaterialDescription: '${fw.typeName} ${fw.grade}',
      quantity: 5.0, // 5 m2
      materialNetCost: fw.netCostPerUnit * 5.0,
      sellingPrice: 30.0,
      lineItems: [lineItem],
    );
    erp.simpleTailorings.add(tailoring);

    // Replenish 3 pieces (3 m2) from Factory Warehouse
    const double addedPieces = 3.0;
    final double addedArea = (lineItem.lengthCm / 100.0) * (lineItem.widthCm / 100.0) * addedPieces;
    expect(addedArea, 3.0);

    // Deduct stock from Factory Warehouse
    final deducted = erp.deductFactoryWarehouseStock(fw.id, addedArea);
    expect(deducted, isTrue);
    expect(fw.availableQty, closeTo(fwBefore - addedArea, 0.001));

    // Update line item and tailoring
    lineItem.quantity += addedPieces;
    tailoring.quantity += addedArea;
    tailoring.sellingPrice = 32.0;

    expect(lineItem.quantity, 8.0);
    expect(tailoring.quantity, 8.0);
    expect(tailoring.sellingPrice, 32.0);
  });

  test('factory POS invoice sells tailoring line items and deducts stock', () async {
    final erp = ERPProvider();
    final client = erp.clients.firstWhere((c) => c.clientType == 'معتمد مصنع');

    final lineItem = TailoringLineItem(
      id: 'li_sale_1',
      source: 'materials',
      stockId: 'ws1',
      typeName: 'رخام كاردينال',
      grade: 'درجة أولى',
      thicknessCm: 2.0,
      category: 'متر مربع',
      lengthCm: 100,
      widthCm: 50,
      quantity: 10, // 10 pieces = 5.0 m2
      netCostPerMeter: 15.0,
      sellingPricePerMeter: 28.0,
      services: [],
    );

    final tailoring = WorkshopTailoringModel(
      id: 'tailoring_sale_test',
      name: 'تفصيل بيع اختبار',
      complexity: 'بسيط',
      rawMaterialDescription: 'رخام كاردينال',
      quantity: 5.0,
      materialNetCost: 75.0,
      sellingPrice: 28.0,
      lineItems: [lineItem],
    );
    erp.simpleTailorings.add(tailoring);

    // Sell 4 pieces (4 * 1.0 * 0.5 = 2.0 m2)
    final invoiceItem = FactoryInvoiceItem(
      itemId: 'tailoring_${tailoring.id}_${lineItem.id}',
      description: 'تفصيل: ${tailoring.name} - بند: ${lineItem.typeName} ${lineItem.grade} (${lineItem.lengthCm}×${lineItem.widthCm}سم)',
      typeName: tailoring.name,
      grade: tailoring.complexity,
      lengthCm: lineItem.lengthCm,
      widthCm: lineItem.widthCm,
      heightCm: lineItem.heightCm,
      quantity: 4, // 4 pieces
      unitPrice: 28.0,
      unitCost: 15.0,
      itemCategory: 'tailoring',
    );

    expect(invoiceItem.isTailoringItem, isTrue);
    expect(invoiceItem.calculatedArea, closeTo(2.0, 0.001));
    expect(invoiceItem.totalPrice, closeTo(56.0, 0.001)); // 2.0 * 28

    final inv = FactoryInvoiceModel(
      id: 'fi_pos_tailoring_test',
      invoiceNo: 'FAC-POS-TEST-1',
      date: DateTime.now(),
      partyId: client.id,
      partyName: client.name,
      invoiceType: 'بيع_معتمد',
      items: [invoiceItem],
      advancePayment: 56.0,
    );

    final created = erp.addFactoryPOSInvoice(inv);
    expect(created, isTrue);

    // Line item pieces deducted: 10 - 4 = 6 pieces
    expect(lineItem.quantity, closeTo(6.0, 0.001));
    // Tailoring area deducted: 5.0 - 2.0 = 3.0 m2
    expect(tailoring.quantity, closeTo(3.0, 0.001));
  });

  testWidgets(
    'complex tailoring calculates auto service price, displays net meter cost, aggregates net price, accepts manual total selling, and deducts workshop stock',
    (tester) async {
      final erp = ERPProvider();
      final wsItem = erp.workshopStock.first;
      final wsStockBefore = wsItem.availableQty;
      final wsCost = wsItem.netCostPerUnit;

      await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
      await tester.tap(find.text('تفصيل معقد (Complex)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('[إضافة تفصيل معقد]'));
      await tester.pumpAndSettle();

      // Enter tailoring name
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'اسم التفصيل',
        ),
        'كاونتر استقبال فاخر',
      );

      // Select workshop stock material
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('${wsItem.typeName} ${wsItem.grade} ${wsItem.thicknessCm}سم').first,
      );
      await tester.pumpAndSettle();

      // Enter Length, Width, Quantity
      // Length = 200 cm, Width = 50 cm, Quantity = 2 pieces
      // Area = (200/100) * (50/100) * 2 = 2.0 m2
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'الطول (سم)',
        ),
        '200',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'العرض (سم)',
        ),
        '50',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'الكمية',
        ),
        '2',
      );
      await tester.pumpAndSettle();

      // Select a service from dropdown
      final srv = erp.services.first;
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(srv.name).last);
      await tester.pumpAndSettle();

      // Auto service price should equal: (200/100) * 2 * srv.unitRate = 4 * srv.unitRate
      final expectedServicePrice = (200.0 / 100.0) * 2.0 * srv.unitRate;
      final serviceField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'إجمالي سعر الخدمة (\$)',
      );
      expect(serviceField, findsOneWidget);
      final TextField serviceTf = tester.widget(serviceField);
      expect(
        double.parse(serviceTf.controller!.text),
        closeTo(expectedServicePrice, 0.01),
      );

      // Attach service
      await tester.tap(find.text('إرفاق +'));
      await tester.pumpAndSettle();

      // Verify "سعر المتر بعد الخدمات لهذا البند" banner
      expect(find.textContaining('سعر المتر بعد الخدمات لهذا البند:'), findsOneWidget);
      final expectedPostMeterCost = wsCost + (expectedServicePrice / 2.0);
      expect(
        find.textContaining('${expectedPostMeterCost.fmt} \$'),
        findsWidgets,
      );

      // Add line item
      await tester.tap(find.text('إضافة بند المواد +'));
      await tester.pumpAndSettle();

      // Verify "صافي سعر التفصيل المعقد بعد الخدمات" banner
      expect(find.textContaining('صافي سعر التفصيل المعقد بعد الخدمات:'), findsOneWidget);
      final expectedTotalNetCost = (2.0 * wsCost) + expectedServicePrice;
      expect(find.textContaining('${expectedTotalNetCost.fmt} \$'), findsWidgets);

      // Enter manual total selling price
      final sellingField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText ==
                'إجمالي سعر البيع للتفصيل المعقد (\$)',
      );
      await tester.ensureVisible(sellingField);
      await tester.enterText(sellingField, '500');
      await tester.pumpAndSettle();

      // Save tailoring
      final saveBtn = find.text('حفظ التفصيل بالمتر');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify complex tailoring created with unified price and 1-piece unit
      final tailoring = erp.complexTailorings.last;
      expect(tailoring.name, 'كاونتر استقبال فاخر');
      expect(tailoring.quantity, closeTo(1.0, 0.001));
      expect(tailoring.sellingPrice, closeTo(500.0, 0.001)); // Unified total selling price entered manually

      // Verify deduction from workshopStock (initial 2.0 m2)
      final wsAfter = erp.workshopStock.firstWhere((w) => w.id == wsItem.id);
      expect(wsAfter.availableQty, closeTo(wsStockBefore - 2.0, 0.001));

      // 1. Verify Outside View displays net tailoring price, selling price, and total available pieces
      expect(find.textContaining('كاونتر استقبال فاخر • المتاح 1 قطعة'), findsOneWidget);
      expect(find.textContaining('صافي سعر التفصيل:'), findsWidgets);
      expect(find.textContaining('سعر البيع: 500 \$'), findsWidgets);
      expect(find.textContaining('إجمالي القطع المتاحة: 1 قطعة'), findsWidgets);

      // Verify action buttons exist on card
      expect(find.text('إضافة مخزون للتفصيل ككل'), findsWidgets);
      expect(find.text('التفاصيل'), findsWidgets);

      // 2. Test "إضافة مخزون للتفصيل ككل" button
      await tester.tap(find.text('إضافة مخزون للتفصيل ككل').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('إضافة مخزون للتفصيل المعقد: كاونتر استقبال فاخر'), findsOneWidget);
      expect(find.textContaining('المواد المطلوبة للاستهلاك والخصم من مواد المعمل:'), findsOneWidget);

      // Confirm adding 1 piece
      final confirmAddBtn = find.text('تأكيد وإضافة المخزون للتفصيل ككل');
      await tester.ensureVisible(confirmAddBtn);
      await tester.tap(confirmAddBtn);
      await tester.pumpAndSettle();

      // Verify piece count incremented to 2 pieces
      expect(tailoring.quantity, closeTo(2.0, 0.001));
      final wsAfter2 = erp.workshopStock.firstWhere((w) => w.id == wsItem.id);
      expect(wsAfter2.availableQty, closeTo(wsStockBefore - 4.0, 0.001));
      expect(find.textContaining('إجمالي القطع المتاحة: 2 قطعة'), findsWidgets);

      // 3. Test "التفاصيل" button
      await tester.tap(find.text('التفاصيل').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('تفاصيل: كاونتر استقبال فاخر (معقد)'), findsOneWidget);
      expect(find.textContaining('إجمالي القطع المتاحة: 2 قطعة'), findsWidgets);
      expect(find.textContaining('إجمالي سعر البيع: 500 \$'), findsWidgets);
      expect(find.textContaining('الخدمات المرفقة:'), findsWidgets);

      // Close details modal
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'simple tailoring auto calculates service price by length, quantity and unit rate',
    (tester) async {
      final erp = ERPProvider();
      await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
      await tester.tap(find.text('[إضافة تفصيل بسيط]'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('رخام كاردينال').last);
      await tester.pumpAndSettle();

      // Enter Length = 150 cm, Width = 100 cm, Quantity = 3
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'الطول (سم)',
        ),
        '150',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'العرض (سم)',
        ),
        '100',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'الكمية',
        ),
        '3',
      );
      await tester.pumpAndSettle();

      // Select service
      final srv = erp.services.first;
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(srv.name).last);
      await tester.pumpAndSettle();

      // (150 / 100) * 3 * srv.unitRate = 4.5 * srv.unitRate
      final expectedServicePrice = (150.0 / 100.0) * 3.0 * srv.unitRate;
      final serviceField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'إجمالي سعر الخدمة (\$)',
      );
      expect(serviceField, findsOneWidget);
      final TextField serviceTf = tester.widget(serviceField);
      expect(
        double.parse(serviceTf.controller!.text),
        closeTo(expectedServicePrice, 0.01),
      );
    },
  );

  testWidgets(
    'adding inventory to simple tailoring deducts meters from workshop stock',
    (tester) async {
      final erp = ERPProvider();
      final wsItem = erp.workshopStock.firstWhere((w) => w.id == 'ws1');
      final wsStockBefore = wsItem.availableQty;

      // Seed a simple tailoring with a line item matching ws1
      final li = TailoringLineItem(
        id: 'li_st_test',
        source: 'materials',
        stockId: wsItem.id,
        typeName: wsItem.typeName,
        grade: wsItem.grade,
        thicknessCm: wsItem.thicknessCm,
        category: wsItem.category,
        lengthCm: 100,
        widthCm: 100,
        quantity: 5,
        netCostPerMeter: wsItem.netCostPerUnit,
        sellingPricePerMeter: 30.0,
      );
      final tailoring = WorkshopTailoringModel(
        id: 'st_replenish_ui_test',
        name: 'درج رخام كاردينال بسيط',
        complexity: 'بسيط',
        rawMaterialDescription: '${wsItem.typeName} ${wsItem.grade}',
        quantity: 5.0,
        unitCategory: 'متر مربع',
        materialNetCost: wsItem.netCostPerUnit * 5.0,
        sellingPrice: 0.0,
        lineItems: [li],
      );
      erp.simpleTailorings.add(tailoring);

      await openWorkshopTab(tester, erp, '2. مفصل (تفصيلات بسيطة ومعقدة)');
      final addStockBtn = find.widgetWithText(ElevatedButton, 'إضافة مخزون').last;
      await tester.ensureVisible(addStockBtn);
      await tester.tap(addStockBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('إضافة مخزون لتفصيل: درج رخام كاردينال بسيط'), findsOneWidget);
      expect(find.textContaining('المخزون المتاح في مواد المعمل:'), findsOneWidget);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'الكمية المراد إضافتها لهذا البند (عدد القطع)',
        ),
        '4',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('الأمتار المحسوبة: 4 متر مربع'), findsOneWidget);

      await tester.tap(find.text('تأكيد وإضافة المخزون للبند'));
      await tester.pumpAndSettle();

      final wsAfter = erp.workshopStock.firstWhere((w) => w.id == 'ws1');
      expect(wsAfter.availableQty, closeTo(wsStockBefore - 4.0, 0.001));

      expect(tailoring.quantity, closeTo(9.0, 0.001));
      expect(li.quantity, closeTo(9.0, 0.001));
    },
  );
}
