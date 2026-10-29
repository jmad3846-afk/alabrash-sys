import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_invoice_print_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workshop Order Preview for Workshop Tests', () {
    test('A4InvoiceData.fromWorkshopOrder constructs fulfillment document correctly', () {
      final order = WorkshopOrderModel(
        id: 'wo_prev_1',
        orderNo: 'ORD-991',
        date: DateTime(2026, 3, 15),
        clientName: 'أبو أحمد',
        clientPhone: '0999123456',
        customDimensionsText: 'تفصيل مغسلة رخام ودرج',
        agreedPrice: 850.0,
        depositAmount: 300.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'item_1',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: 'ws1',
            description: 'رخام موغلا تركي نخب أول 2سم',
            quantity: 4.5,
            unitCategory: 'متر مربع',
            unitPrice: 50.0,
            agreedPrice: 225.0,
            lengthCm: 150,
            widthCm: 100,
            services: [
              ServiceAttachment(serviceName: 'جلي وتلميع', price: 25.0),
              ServiceAttachment(serviceName: 'شطف دبل', price: 15.0),
            ],
          ),
          WorkshopInvoiceItem(
            id: 'item_2',
            sourceType: 'بيع خياطة معقدة',
            sourceId: 'ct1',
            description: 'طاولة طعام دائرية مبرومة',
            quantity: 1.0,
            unitCategory: 'قطعة',
            unitPrice: 585.0,
            agreedPrice: 585.0,
          ),
        ],
      );

      final data = A4InvoiceData.fromWorkshopOrder(order);

      expect(data.invoiceNo, 'ORD-991');
      expect(data.partyName, 'أبو أحمد');
      expect(data.partyPhone, '0999123456');
      expect(data.currency, AppCurrency.usd);
      expect(data.grandTotal, 850.0);
      expect(data.paidAmount, 300.0);
      expect(data.remainingBalance, 550.0);
      expect(data.hasFulfillmentSection, isTrue);
      expect(data.fulfillmentTitle, contains('ورشة المعمل'));
      expect(data.items.length, 2);

      // Verify item 1
      expect(data.items[0].description, 'رخام موغلا تركي نخب أول 2سم');
      expect(data.items[0].dimensionsText, contains('150 × 100 سم'));
      expect(data.items[0].quantityText, contains('4.5 متر مربع'));
      expect(data.items[0].servicesText, contains('جلي وتلميع'));
      expect(data.items[0].servicesText, contains('شطف دبل'));

      // Verify item 2
      expect(data.items[1].description, 'طاولة طعام دائرية مبرومة');
      expect(data.items[1].quantityText, contains('1 قطعة'));
    });
  });

  group('Workshop Order Stock Deduction On Creation Tests', () {
    test('createWorkshopOrder deducts stock for all consumed line items and holds deposit', () {
      final erp = ERPProvider();
      final orderBoxBefore = erp.cashOf('order', AppCurrency.usd);

      // 1. Raw material stock before
      final rawStock = erp.workshopStock.first;
      rawStock.availableQty = 20.0;
      final rawQtyBefore = rawStock.availableQty;

      // 2. Simple tailoring before
      final simple = erp.simpleTailorings.first;
      simple.quantity = 10.0;
      final simpleQtyBefore = simple.quantity;

      // 3. Complex tailoring before
      final complex = erp.complexTailorings.first;
      complex.quantity = 5.0;
      final complexQtyBefore = complex.quantity;

      // 4. Scrap item before
      final scrap = erp.scrapItems.first;
      scrap.isSold = false;

      final order = WorkshopOrderModel(
        id: 'wo_test_deduct',
        orderNo: 'ORD-DED-01',
        date: DateTime.now(),
        clientName: 'خالد عبد الله',
        clientPhone: '0988000111',
        customDimensionsText: 'طلب معمل متنوع',
        agreedPrice: 1200.0,
        depositAmount: 400.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'it_raw',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: rawStock.id,
            description: rawStock.typeName,
            quantity: 3.0,
            unitCategory: 'متر مربع',
            agreedPrice: 300.0,
          ),
          WorkshopInvoiceItem(
            id: 'it_simple',
            sourceType: 'بيع خياطة بسيطة',
            sourceId: simple.id,
            description: simple.name,
            quantity: 2.0,
            unitCategory: 'متر مربع',
            agreedPrice: 200.0,
          ),
          WorkshopInvoiceItem(
            id: 'it_complex',
            sourceType: 'بيع خياطة معقدة',
            sourceId: complex.id,
            description: complex.name,
            quantity: 1.0,
            unitCategory: 'قطعة',
            agreedPrice: 500.0,
          ),
          WorkshopInvoiceItem(
            id: 'it_scrap',
            sourceType: 'بيع قطع إضافية',
            sourceId: scrap.id,
            description: scrap.description,
            quantity: 1.0,
            unitCategory: 'قطعة',
            agreedPrice: 100.0,
          ),
        ],
      );

      erp.createWorkshopOrder(order);

      // Verify deposit placed in isolated Order Safe
      expect(erp.cashOf('order', AppCurrency.usd), closeTo(orderBoxBefore + 400.0, 0.001));

      // Verify all inventory items deducted
      expect(rawStock.availableQty, closeTo(rawQtyBefore - 3.0, 0.001));
      expect(simple.quantity, closeTo(simpleQtyBefore - 2.0, 0.001));
      expect(complex.quantity, closeTo(complexQtyBefore - 1.0, 0.001));
      expect(scrap.isSold, isTrue);
    });
  });

  group('Option A: Order NOT Completed Cancellation Tests', () {
    test('refunds deposit to customer and rolls back all items to exact original locations', () {
      final erp = ERPProvider();
      final orderBoxStart = erp.cashOf('order', AppCurrency.usd);

      final rawStock = erp.workshopStock.first;
      final rawQtyStart = rawStock.availableQty;

      final simple = erp.simpleTailorings.first;
      final simpleQtyStart = simple.quantity;

      final scrap = erp.scrapItems.first;
      scrap.isSold = false;

      final order = WorkshopOrderModel(
        id: 'wo_not_comp',
        orderNo: 'ORD-NC-01',
        date: DateTime.now(),
        clientName: 'طارق الزعبي',
        clientPhone: '0955111222',
        customDimensionsText: 'طلب غير مكتمل',
        agreedPrice: 600.0,
        depositAmount: 250.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'it_raw',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: rawStock.id,
            description: rawStock.typeName,
            quantity: 4.0,
            unitCategory: 'متر مربع',
            agreedPrice: 350.0,
          ),
          WorkshopInvoiceItem(
            id: 'it_simple',
            sourceType: 'بيع خياطة بسيطة',
            sourceId: simple.id,
            description: simple.name,
            quantity: 1.5,
            unitCategory: 'متر مربع',
            agreedPrice: 150.0,
          ),
          WorkshopInvoiceItem(
            id: 'it_scrap',
            sourceType: 'بيع قطع إضافية',
            sourceId: scrap.id,
            description: scrap.description,
            quantity: 1.0,
            unitCategory: 'قطعة',
            agreedPrice: 100.0,
          ),
        ],
      );

      // 1. Create order
      erp.createWorkshopOrder(order);
      expect(erp.cashOf('order', AppCurrency.usd), closeTo(orderBoxStart + 250.0, 0.001));
      expect(rawStock.availableQty, closeTo(rawQtyStart - 4.0, 0.001));
      expect(simple.quantity, closeTo(simpleQtyStart - 1.5, 0.001));
      expect(scrap.isSold, isTrue);

      // 2. Cancel order with Option A (isCompleted = false)
      erp.cancelWorkshopOrderWorkflow(
        order: order,
        isCompleted: false,
      );

      // Verify financial handling: Deposit is refunded back to customer
      expect(erp.cashOf('order', AppCurrency.usd), closeTo(orderBoxStart, 0.001));
      expect(order.isSpecialRefund, isTrue);
      expect(order.isCompleted, isFalse);
      expect(order.status, 'ملغاة (غير مكتملة)');

      // Verify inventory rollback: Returned to exact original locations
      expect(rawStock.availableQty, closeTo(rawQtyStart, 0.001));
      expect(simple.quantity, closeTo(simpleQtyStart, 0.001));
      expect(scrap.isSold, isFalse);
    });
  });

  group('Option B: Order IS Completed Cancellation Tests', () {
    test('keeps deposit as profit, restores standard items, and converts raw materials into tailored stock', () {
      final erp = ERPProvider();
      final orderBoxStart = erp.cashOf('order', AppCurrency.usd);

      final rawStock = erp.workshopStock.first;
      final rawQtyStart = rawStock.availableQty;

      final simple = erp.simpleTailorings.first;
      final simpleQtyStart = simple.quantity;

      final complexCountBefore = erp.complexTailorings.length;

      final scrap = erp.scrapItems.first;
      scrap.isSold = false;

      final order = WorkshopOrderModel(
        id: 'wo_is_comp',
        orderNo: 'ORD-CMP-01',
        date: DateTime.now(),
        clientName: 'عمر الحلبي',
        clientPhone: '0933444555',
        customDimensionsText: 'طلب منجز لكن ملغى',
        agreedPrice: 1500.0,
        depositAmount: 500.0,
        currency: AppCurrency.usd,
        items: [
          // Raw Material 1: will be assigned to existing Simple Tailoring
          WorkshopInvoiceItem(
            id: 'raw_1',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: rawStock.id,
            description: 'رخام موغلا تركي 2سم',
            quantity: 5.0,
            unitCategory: 'متر مربع',
            agreedPrice: 400.0,
          ),
          // Raw Material 2: will be converted dynamically into a NEW Complex Tailoring
          WorkshopInvoiceItem(
            id: 'raw_2',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: rawStock.id,
            description: 'جرانيت اسود هندي 3سم',
            quantity: 2.0,
            unitCategory: 'متر مربع',
            agreedPrice: 300.0,
          ),
          // Standard Line Item: Simple Tailoring
          WorkshopInvoiceItem(
            id: 'std_simple',
            sourceType: 'بيع خياطة بسيطة',
            sourceId: simple.id,
            description: simple.name,
            quantity: 3.0,
            unitCategory: 'متر مربع',
            agreedPrice: 500.0,
          ),
          // Standard Line Item: Scrap
          WorkshopInvoiceItem(
            id: 'std_scrap',
            sourceType: 'بيع قطع إضافية',
            sourceId: scrap.id,
            description: scrap.description,
            quantity: 1.0,
            unitCategory: 'قطعة',
            agreedPrice: 100.0,
          ),
        ],
      );

      // 1. Create order
      erp.createWorkshopOrder(order);
      expect(erp.cashOf('order', AppCurrency.usd), closeTo(orderBoxStart + 500.0, 0.001));
      expect(rawStock.availableQty, closeTo(rawQtyStart - 7.0, 0.001));
      expect(simple.quantity, closeTo(simpleQtyStart - 3.0, 0.001));
      expect(scrap.isSold, isTrue);

      // 2. Cancel order with Option B (isCompleted = true)
      // Provide assignments for raw materials:
      // - raw_1 -> credit into existing simple tailoring
      // - raw_2 -> create new complex tailoring on the fly
      final assignments = [
        RawMaterialTailoringAssignment(
          itemId: 'raw_1',
          rawMaterialName: 'رخام موغلا تركي 2سم',
          quantity: 5.0,
          isSimpleTailoring: true,
          existingTailoringId: simple.id,
        ),
        RawMaterialTailoringAssignment(
          itemId: 'raw_2',
          rawMaterialName: 'جرانيت اسود هندي 3سم',
          quantity: 2.0,
          isSimpleTailoring: false,
          newTailoringName: 'مغسلة ديكور جرانيت جديدة على الطاير',
          sellingPrice: 350.0,
        ),
      ];

      erp.cancelWorkshopOrderWorkflow(
        order: order,
        isCompleted: true,
        rawMaterialAssignments: assignments,
      );

      // Financial Handling: Deposit NOT refunded, retained in Order Safe as profit
      expect(erp.cashOf('order', AppCurrency.usd), closeTo(orderBoxStart + 500.0, 0.001));
      expect(order.isSpecialRefund, isFalse);
      expect(order.isCompleted, isTrue);
      expect(order.status, 'ملغاة (مكتملة)');

      // Standard items rollback:
      // Simple tailoring received its 3.0 standard rollback + 5.0 from raw_1 conversion!
      expect(simple.quantity, closeTo(simpleQtyStart + 5.0, 0.001));
      // Scrap returned to unsold
      expect(scrap.isSold, isFalse);

      // Raw material stock is NOT credited as raw materials (they were shaped/cut)
      expect(rawStock.availableQty, closeTo(rawQtyStart - 7.0, 0.001));

      // Dynamic new tailoring creation: New complex tailoring was added!
      expect(erp.complexTailorings.length, complexCountBefore + 1);
      final newComplex = erp.complexTailorings.last;
      expect(newComplex.name, 'مغسلة ديكور جرانيت جديدة على الطاير');
      expect(newComplex.quantity, closeTo(2.0, 0.001));
      expect(newComplex.sellingPrice, closeTo(350.0, 0.001));
      expect(newComplex.complexity, 'معقد');
    });
  });
}
