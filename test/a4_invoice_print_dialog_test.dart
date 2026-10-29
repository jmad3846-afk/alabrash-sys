import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_invoice_print_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A4InvoiceLineItem & A4InvoiceData dimension parsing', () {
    test('line item with numerical lengthCm and widthCm hasDimensions', () {
      const item = A4InvoiceLineItem(
        index: 1,
        description: 'رخام تركي',
        lengthCm: 120,
        widthCm: 60,
        quantityText: '5 م²',
        unitPrice: 25.0,
        lineTotal: 125.0,
      );

      expect(item.hasDimensions, isTrue);
      expect(item.lengthDisplay, equals('120 سم'));
      expect(item.widthDisplay, equals('60 سم'));
    });

    test('line item with string dimensionsText parsing fallback', () {
      const item = A4InvoiceLineItem(
        index: 1,
        description: 'رخام تفصيل',
        dimensionsText: '140 × 70 سم',
        quantityText: '2 قطعة',
        unitPrice: 30.0,
        lineTotal: 60.0,
      );

      expect(item.hasDimensions, isTrue);
      expect(item.lengthDisplay, equals('140 سم'));
      expect(item.widthDisplay, equals('70 سم'));
    });

    test('line item without dimensions hasDimensions is false', () {
      const item = A4InvoiceLineItem(
        index: 1,
        description: 'بلوك خام',
        quantityText: '10 طن',
        unitPrice: 100.0,
        lineTotal: 1000.0,
      );

      expect(item.hasDimensions, isFalse);
      expect(item.lengthDisplay, equals('—'));
      expect(item.widthDisplay, equals('—'));
    });

    test('A4InvoiceData.hasDimensions reflects items', () {
      final invWithDims = A4InvoiceData(
        invoiceTypeTitle: 'فاتورة مبيعات',
        invoiceNo: 'INV-001',
        date: DateTime.now(),
        partyName: 'معتمد 1',
        currency: AppCurrency.usd,
        paymentStatus: 'مدفوعة بالكامل',
        items: const [
          A4InvoiceLineItem(
            index: 1,
            description: 'رخام',
            lengthCm: 100,
            widthCm: 50,
            quantityText: '10 م²',
            unitPrice: 20,
            lineTotal: 200,
          ),
        ],
        subtotal: 200,
        grandTotal: 200,
        paidAmount: 200,
        remainingBalance: 0,
      );

      expect(invWithDims.hasDimensions, isTrue);

      final invWithoutDims = A4InvoiceData(
        invoiceTypeTitle: 'فاتورة مرتجع',
        invoiceNo: 'RET-001',
        date: DateTime.now(),
        partyName: 'جهة 1',
        currency: AppCurrency.usd,
        paymentStatus: 'مسواة',
        items: const [
          A4InvoiceLineItem(
            index: 1,
            description: 'مرتجع مواد',
            quantityText: '1 وحدة',
            unitPrice: 50,
            lineTotal: 50,
          ),
        ],
        subtotal: 50,
        grandTotal: 50,
        paidAmount: 50,
        remainingBalance: 0,
      );

      expect(invWithoutDims.hasDimensions, isFalse);
    });

    test('fromFactoryInvoice populates lengthCm and widthCm', () {
      final factoryInv = FactoryInvoiceModel(
        id: '1',
        invoiceNo: 'FINV-100',
        date: DateTime.now(),
        partyId: 'supplier-1',
        partyName: 'مورد الرخام',
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'w1',
            description: 'رخام ألواح',
            lengthCm: 250,
            widthCm: 150,
            quantity: 3.75,
            unitPrice: 40,
            unitCost: 35,
            itemCategory: 'meter',
          ),
        ],
        shippingFee: 0,
        discountAmount: 0,
        advancePayment: 150,
        isGoodsDelivered: true,
        currency: AppCurrency.usd,
      );

      final a4Data = A4InvoiceData.fromFactoryInvoice(factoryInv);
      expect(a4Data.hasDimensions, isTrue);
      expect(a4Data.items.first.lengthDisplay, equals('250 سم'));
      expect(a4Data.items.first.widthDisplay, equals('150 سم'));
    });

    test('fromWorkshopOrder populates Length, Width, and Quantity (Count) correctly', () {
      final order = WorkshopOrderModel(
        id: 'wo_test_1',
        orderNo: 'ORD-701',
        date: DateTime.now(),
        clientName: 'أبو كريم',
        clientPhone: '0912345678',
        customDimensionsText: 'تفصيل مغسلة رخام 150*60سم',
        agreedPrice: 500.0,
        depositAmount: 150.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'item_1',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: 'ws1',
            description: 'رخام موغلا تركي',
            lengthCm: 140,
            widthCm: 70,
            count: 3,
            quantity: 2.94,
            unitCategory: 'متر مربع',
            unitPrice: 50.0,
            agreedPrice: 147.0,
          ),
          WorkshopInvoiceItem(
            id: 'item_2',
            sourceType: 'بيع خياطة معقدة',
            sourceId: 'c1',
            description: 'طاولة غرانيت 200*90 سم',
            quantity: 2,
            unitCategory: 'قطعة',
            unitPrice: 100.0,
            agreedPrice: 200.0,
          ),
        ],
      );

      final a4Data = A4InvoiceData.fromWorkshopOrder(order);
      expect(a4Data.isWorkshopOrder, isTrue);
      expect(a4Data.hasDimensions, isTrue);

      // Item 1: explicit lengthCm & widthCm & count
      final item1 = a4Data.items[0];
      expect(item1.lengthDisplay, equals('140 سم'));
      expect(item1.widthDisplay, equals('70 سم'));
      expect(item1.count, equals(3));
      expect(item1.quantityText, contains('3 قطعة'));
      expect(item1.quantityText, contains('2.94 متر مربع'));

      // Item 2: extracted from description "200*90" and quantity 2
      final item2 = a4Data.items[1];
      expect(item2.lengthDisplay, equals('200 سم'));
      expect(item2.widthDisplay, equals('90 سم'));
      expect(item2.count, equals(2));
      expect(item2.quantityText, contains('2 قطعة'));
    });
  });

  group('A4InvoicePrintDialog Table Rendering', () {
    testWidgets('renders separate Length and Width columns when invoice has dimensions', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = ERPProvider();

      final invData = A4InvoiceData(
        invoiceTypeTitle: 'فاتورة مبيعات معتمدين (نقدي) — مستودع المصنع',
        invoiceNo: 'POS-999',
        date: DateTime.now(),
        partyName: 'شركة البناء',
        currency: AppCurrency.usd,
        paymentStatus: 'مدفوعة بالكامل',
        items: const [
          A4InvoiceLineItem(
            index: 1,
            description: 'درج رخام بيانكو',
            gradeAndSpecs: 'درجة أولى • 2 سم (رخام)',
            lengthCm: 120,
            widthCm: 33,
            quantityText: '3.96 م²\n(10 قطعة)',
            unitPrice: 22,
            lineTotal: 220,
          ),
        ],
        subtotal: 220,
        grandTotal: 220,
        paidAmount: 220,
        remainingBalance: 0,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ERPProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: A4InvoicePrintDialog(invoiceData: invData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Separate columns must be rendered
      expect(find.text('الطول (سم)'), findsWidgets);
      expect(find.text('العرض (سم)'), findsWidgets);
      expect(find.text('120 سم'), findsWidgets);
      expect(find.text('33 سم'), findsWidgets);

      // The combined "الأبعاد (سم)" header should not be present
      expect(find.text('الأبعاد (سم)'), findsNothing);
    });

    testWidgets('renders single Dimensions column when invoice has no dimensions', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = ERPProvider();

      final invData = A4InvoiceData(
        invoiceTypeTitle: 'إشعار فاتورة مرتجع',
        invoiceNo: 'RET-001',
        date: DateTime.now(),
        partyName: 'العميل جهاد',
        currency: AppCurrency.usd,
        paymentStatus: 'تمت التسوية',
        items: const [
          A4InvoiceLineItem(
            index: 1,
            description: 'مرتجع مالي',
            gradeAndSpecs: 'مرتجع',
            dimensionsText: 'مرتجع نظامي',
            quantityText: '1 وحدة',
            unitPrice: 100,
            lineTotal: 100,
          ),
        ],
        subtotal: 100,
        grandTotal: 100,
        paidAmount: 100,
        remainingBalance: 0,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ERPProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: A4InvoicePrintDialog(invoiceData: invData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Combined header must be rendered
      expect(find.text('الأبعاد (سم)'), findsWidgets);
      expect(find.text('مرتجع نظامي'), findsWidgets);

      // Separate headers should not be present
      expect(find.text('الطول (سم)'), findsNothing);
      expect(find.text('العرض (سم)'), findsNothing);
    });

    testWidgets('renders Length, Width, and Quantity (Count) header for workshop orders', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = ERPProvider();

      final order = WorkshopOrderModel(
        id: 'wo_test_ui',
        orderNo: 'ORD-800',
        date: DateTime.now(),
        clientName: 'السيد أحمد',
        clientPhone: '0912345678',
        customDimensionsText: 'تفصيل طاولة رخام',
        agreedPrice: 400.0,
        depositAmount: 100.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'it_1',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: 'ws1',
            description: 'رخام كريما مارفل',
            lengthCm: 160,
            widthCm: 80,
            count: 2,
            quantity: 2.56,
            unitCategory: 'متر مربع',
            unitPrice: 60,
            agreedPrice: 153.6,
          ),
        ],
      );

      final invData = A4InvoiceData.fromWorkshopOrder(order);

      await tester.pumpWidget(
        ChangeNotifierProvider<ERPProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: A4InvoicePrintDialog(invoiceData: invData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Table headers must show Length, Width, and Quantity (Count)
      expect(find.text('الطول (سم)'), findsWidgets);
      expect(find.text('العرض (سم)'), findsWidgets);
      expect(find.text('الكمية (العدد)'), findsWidgets);

      // Row values must show dimensions and count
      expect(find.text('160 سم'), findsWidgets);
      expect(find.text('80 سم'), findsWidgets);
      expect(find.textContaining('2 قطعة'), findsWidgets);
    });
  });
}
