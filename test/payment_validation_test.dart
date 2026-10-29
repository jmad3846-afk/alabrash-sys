import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Validation & Max-Limit Control Tests (Abaad ERP)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Upper Limit Enforcement on Direct Factory Sales Invoice Creation', () {
      final erp = ERPProvider();
      final client = ClientModel(
        id: 'client_val_1',
        name: 'عميل اختبار الحد الأقصى',
        phone: '0912345678',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      // Invoice grandTotal = 1000 USD
      final validItem = FactoryInvoiceItem(
        itemId: 'item_val_1',
        description: 'رخام تركي',
        quantity: 20.0,
        unitPrice: 50.0, // 20 * 50 = 1000
        unitCost: 30.0,
      );

      // A: Overpayment attempt (advancePayment = 1200 > grandTotal 1000) -> MUST BE REJECTED
      final overpaidInvoice = FactoryInvoiceModel(
        id: 'fi_overpaid_1',
        invoiceNo: 'POS-OVER-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [validItem],
        advancePayment: 1200.0, // Exceeds 1000
        currency: AppCurrency.usd,
      );
      expect(erp.addFactoryPOSInvoice(overpaidInvoice), isFalse);
      expect(erp.factoryInvoices.any((i) => i.id == 'fi_overpaid_1'), isFalse);

      // B: Negative payment attempt -> MUST BE REJECTED
      final negativeInvoice = FactoryInvoiceModel(
        id: 'fi_negative_1',
        invoiceNo: 'POS-NEG-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [validItem],
        advancePayment: -50.0,
        currency: AppCurrency.usd,
      );
      expect(erp.addFactoryPOSInvoice(negativeInvoice), isFalse);

      // C: Exact / partial payment -> MUST SUCCEED
      final validInvoice = FactoryInvoiceModel(
        id: 'fi_valid_1',
        invoiceNo: 'POS-OK-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [validItem],
        advancePayment: 600.0, // Valid partial
        currency: AppCurrency.usd,
      );
      expect(erp.addFactoryPOSInvoice(validInvoice), isTrue);
      expect(erp.factoryInvoices.any((i) => i.id == 'fi_valid_1'), isTrue);
    });

    test('2. Upper Limit Enforcement on Supplier Purchase Invoice Creation', () {
      final erp = ERPProvider();
      erp.addCash('main', AppCurrency.usd, 5000.0);

      final supplier = SupplierModel(
        id: 'sup_val_1',
        name: 'مورد اختبار التحقق',
        phone: '0988776655',
        location: 'اللاذقية',
      );
      erp.suppliers.add(supplier);

      final item = FactoryInvoiceItem(
        itemId: 'block_item_1',
        description: 'بلوك كرارة',
        quantity: 10.0,
        unitPrice: 100.0, // 10 * 100 = 1000
        unitCost: 100.0,
      );

      // A: Overpayment attempt (advancePayment = 1500 > grandTotal 1000) -> MUST BE REJECTED
      final overpaidPurchase = FactoryInvoiceModel(
        id: 'pur_over_1',
        invoiceNo: 'PUR-OVER-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [item],
        advancePayment: 1500.0,
        currency: AppCurrency.usd,
      );
      expect(erp.addSupplierPurchaseInvoice(overpaidPurchase), isFalse);

      // B: Valid advance payment (400 <= 1000) -> MUST SUCCEED
      final validPurchase = FactoryInvoiceModel(
        id: 'pur_ok_1',
        invoiceNo: 'PUR-OK-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [item],
        advancePayment: 400.0,
        currency: AppCurrency.usd,
      );
      expect(erp.addSupplierPurchaseInvoice(validPurchase), isTrue);
    });

    test('3. Order-to-Invoice Conversion & Deposit Limits (Factory Order)', () {
      final erp = ERPProvider();
      final initialOrderCash = erp.cashOf('order', AppCurrency.usd);
      final initialMainCash = erp.cashOf('main', AppCurrency.usd);

      final client = ClientModel(
        id: 'client_fac_ord',
        name: 'معتمد طلبيات مصنع',
        phone: '0911223344',
        location: 'حلب',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      // 1. Create a factory order with total = 1000 USD and deposit = 300 USD
      final orderItem = FactoryInvoiceItem(
        itemId: 'order_item_1',
        description: 'رخام موغلا',
        quantity: 20.0,
        unitPrice: 50.0, // 1000 USD
        unitCost: 30.0,
      );

      final order = FactoryOrderModel(
        id: 'fo_test_1',
        orderNo: 'FORD-TEST-1',
        date: DateTime.now(),
        partyId: client.id,
        clientName: client.name,
        clientPhone: client.phone,
        items: [orderItem],
        depositAmount: 300.0, // Deposit
        currency: AppCurrency.usd,
      );
      erp.createFactoryOrder(order);
      expect(erp.cashOf('order', AppCurrency.usd), initialOrderCash + 300.0);

      // Formula: Remaining Balance = 1000 - 300 = 700 USD.
      // Maximum allowed advance payment is 1000 USD (Deposit 300 + Max New Cash 700).

      // Attempt A: Overpayment conversion (advancePayment = 1100 > 1000) -> MUST BE REJECTED
      final overpaidInvoice = FactoryInvoiceModel(
        id: 'fi_conv_over',
        invoiceNo: 'FAC-POS-CONV-1',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [orderItem],
        advancePayment: 1100.0, // 300 deposit + 800 new payment = 1100 > 1000
        currency: AppCurrency.usd,
      );
      expect(erp.assignFactoryOrderToPOSInvoice(order, overpaidInvoice), isFalse);

      // Attempt B: Advance payment less than original deposit -> MUST BE REJECTED
      final underDepositInvoice = FactoryInvoiceModel(
        id: 'fi_conv_under',
        invoiceNo: 'FAC-POS-CONV-2',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [orderItem],
        advancePayment: 200.0, // Less than deposit 300
        currency: AppCurrency.usd,
      );
      expect(erp.assignFactoryOrderToPOSInvoice(order, underDepositInvoice), isFalse);

      // Attempt C: Valid conversion (Deposit 300 + New Cash 400 = advancePayment 700 <= 1000) -> MUST SUCCEED
      final validConvInvoice = FactoryInvoiceModel(
        id: 'fi_conv_valid',
        invoiceNo: 'FAC-POS-CONV-3',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [orderItem],
        advancePayment: 700.0, // 300 deposit + 400 new payment
        currency: AppCurrency.usd,
      );
      expect(erp.assignFactoryOrderToPOSInvoice(order, validConvInvoice), isTrue);

      // Verify accounting: Deposit moved to Main Cash Box (300) + New payment (400) = 700 in Main Safe
      expect(erp.cashOf('order', AppCurrency.usd), initialOrderCash);
      expect(erp.cashOf('main', AppCurrency.usd), initialMainCash + 700.0);
      expect(order.isCompleted, isTrue);
      expect(order.status, 'مكتملة ومرحلة');
    });

    test('4. Order-to-Invoice Conversion & Deposit Limits (Workshop Order)', () {
      final erp = ERPProvider();
      final initialOrderCash = erp.cashOf('order', AppCurrency.usd);
      final initialMainCash = erp.cashOf('main', AppCurrency.usd);

      // 1. Create a workshop order with agreedPrice = 800 USD, deposit = 200 USD
      final order = WorkshopOrderModel(
        id: 'wo_test_1',
        orderNo: 'WORD-TEST-1',
        date: DateTime.now(),
        clientName: 'عميل معمل تجريبي',
        clientPhone: '0911223344',
        customDimensionsText: 'تفصيل مغسلة رخام',
        agreedPrice: 800.0,
        depositAmount: 200.0,
        currency: AppCurrency.usd,
      );
      erp.createWorkshopOrder(order);
      expect(erp.cashOf('order', AppCurrency.usd), initialOrderCash + 200.0);

      // Remaining Balance = 800 - 200 = 600 USD.

      // Attempt A: Overpayment at conversion (deposit 200 + cash 700 = 900 > 800) -> MUST BE REJECTED
      final overpaidInvoice = WorkshopInvoiceModel(
        id: 'wi_conv_over',
        invoiceNo: 'WRK-INV-CONV-1',
        date: DateTime.now(),
        clientName: order.clientName,
        sourceType: 'طلبية معمل',
        sourceId: order.id,
        itemDescription: order.customDimensionsText,
        sourceQuantity: 1,
        agreedPrice: 800.0,
        depositDeducted: 200.0,
        cashPaidNow: 700.0, // Total = 900 > 800
        netCost: 400.0,
        currency: AppCurrency.usd,
      );
      expect(erp.createWorkshopInvoice(overpaidInvoice), isFalse);

      // Attempt B: Valid conversion (deposit 200 + cash 300 = 500 <= 800) -> MUST SUCCEED
      final validInvoice = WorkshopInvoiceModel(
        id: 'wi_conv_valid',
        invoiceNo: 'WRK-INV-CONV-2',
        date: DateTime.now(),
        clientName: order.clientName,
        sourceType: 'طلبية معمل',
        sourceId: order.id,
        itemDescription: order.customDimensionsText,
        sourceQuantity: 1,
        agreedPrice: 800.0,
        depositDeducted: 200.0,
        cashPaidNow: 300.0, // Total = 500 <= 800
        netCost: 400.0,
        currency: AppCurrency.usd,
      );
      expect(erp.createWorkshopInvoice(validInvoice), isTrue);

      // Verify accounting: Deposit moved to Main Cash Box (200) + New payment (300) = 500 in Main Safe
      expect(erp.cashOf('order', AppCurrency.usd), initialOrderCash);
      expect(erp.cashOf('main', AppCurrency.usd), initialMainCash + 500.0);
    });

    test('5. Subsequent Payments on Existing Factory Sales Invoices (دفعات لاحقة)', () {
      final erp = ERPProvider();
      final client = ClientModel(
        id: 'client_sub_1',
        name: 'عميل دفعات لاحقة',
        phone: '0955443322',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      // Create invoice: Total = 1000 USD, Paid = 400 USD, Remaining = 600 USD
      final invoice = FactoryInvoiceModel(
        id: 'fi_sub_1',
        invoiceNo: 'POS-SUB-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_sub_1',
            description: 'رخام روزا',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 60.0,
          ),
        ],
        advancePayment: 400.0,
        currency: AppCurrency.usd,
      );
      expect(erp.addFactoryPOSInvoice(invoice), isTrue);
      expect(invoice.remainingBalance, 600.0);
      expect(invoice.paymentStatus, 'مستحق الدفع');

      // Attempt A: Subsequent payment exceeding remaining balance (650 > 600) -> MUST BE REJECTED
      expect(erp.collectFactoryInvoice(invoice, 650.0), isFalse);
      expect(invoice.remainingBalance, 600.0); // Unchanged

      // Attempt B: Zero or negative payment -> MUST BE REJECTED
      expect(erp.collectFactoryInvoice(invoice, 0.0), isFalse);
      expect(erp.collectFactoryInvoice(invoice, -50.0), isFalse);

      // Attempt C: Partial payment of 250 (<= 600) -> MUST SUCCEED
      expect(erp.collectFactoryInvoice(invoice, 250.0), isTrue);
      expect(invoice.advancePayment, 650.0);
      expect(invoice.remainingBalance, 350.0);
      expect(invoice.paymentStatus, 'مستحق الدفع');

      // Attempt D: Final settlement of exact remaining 350 -> MUST SUCCEED & Mark Paid
      expect(erp.collectFactoryInvoice(invoice, 350.0), isTrue);
      expect(invoice.advancePayment, 1000.0);
      expect(invoice.remainingBalance, 0.0);
      expect(invoice.paymentStatus, 'مدفوعة');

      // Attempt E: Further payment on fully paid invoice -> MUST BE REJECTED
      expect(erp.collectFactoryInvoice(invoice, 50.0), isFalse);
    });

    test('6. Subsequent Payments on Existing Workshop Invoices (دفعات لاحقة)', () {
      final erp = ERPProvider();

      // Create workshop invoice: Total = 500 USD, Paid = 100 USD, Remaining = 400 USD
      final invoice = WorkshopInvoiceModel(
        id: 'wi_sub_1',
        invoiceNo: 'WRK-SUB-001',
        date: DateTime.now(),
        clientName: 'زبون معمل دفعات',
        sourceType: 'تفصيل بسيط',
        sourceQuantity: 1,
        agreedPrice: 500.0,
        depositDeducted: 0.0,
        cashPaidNow: 100.0,
        netCost: 200.0,
        currency: AppCurrency.usd,
      );
      expect(erp.createWorkshopInvoice(invoice), isTrue);
      expect(invoice.remainingBalance, 400.0);

      // Attempt A: Subsequent payment exceeding remaining balance (450 > 400) -> MUST BE REJECTED
      expect(erp.collectWorkshopInvoice(invoice, 450.0), isFalse);

      // Attempt B: Valid partial payment of 200 (<= 400) -> MUST SUCCEED
      expect(erp.collectWorkshopInvoice(invoice, 200.0), isTrue);
      final updatedInv = erp.workshopInvoices.firstWhere((i) => i.id == invoice.id);
      expect(updatedInv.cashPaidNow, 300.0);
      expect(updatedInv.remainingBalance, 200.0);

      // Attempt C: Settle remaining 200 -> MUST SUCCEED
      expect(erp.collectWorkshopInvoice(updatedInv, 200.0), isTrue);
      final fullyPaid = erp.workshopInvoices.firstWhere((i) => i.id == invoice.id);
      expect(fullyPaid.cashPaidNow, 500.0);
      expect(fullyPaid.remainingBalance, 0.0);

      // Attempt D: Further payment after zero balance -> MUST BE REJECTED
      expect(erp.collectWorkshopInvoice(fullyPaid, 10.0), isFalse);
    });

    test('7. Subsequent Payments on Supplier Purchase Invoices (تسديد للمورد)', () {
      final erp = ERPProvider();
      erp.addCash('main', AppCurrency.usd, 5000.0);

      final supplier = SupplierModel(
        id: 'sup_sub_1',
        name: 'مورد سداد لاحق',
        phone: '0977665544',
        location: 'طرطوس',
      );
      erp.suppliers.add(supplier);

      // Purchase invoice: GrandTotal = 2000 USD, Advance = 500 USD, Remaining = 1500 USD
      final purchase = FactoryInvoiceModel(
        id: 'pur_sub_1',
        invoiceNo: 'PUR-SUB-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'block_sub_1',
            description: 'بلوك يوناني',
            quantity: 20.0,
            unitPrice: 100.0,
            unitCost: 100.0,
          ),
        ],
        advancePayment: 500.0,
        currency: AppCurrency.usd,
      );
      expect(erp.addSupplierPurchaseInvoice(purchase), isTrue);
      expect(purchase.remainingBalance, 1500.0);

      // Attempt A: Overpayment to supplier (1600 > 1500) -> MUST BE REJECTED
      expect(erp.paySupplierInvoice(purchase, 1600.0), isFalse);
      expect(purchase.remainingBalance, 1500.0);

      // Attempt B: Partial payment of 500 -> MUST SUCCEED
      expect(erp.paySupplierInvoice(purchase, 500.0), isTrue);
      expect(purchase.advancePayment, 1000.0);
      expect(purchase.remainingBalance, 1000.0);

      // Attempt C: Full remaining payment of 1000 -> MUST SUCCEED & Mark Paid
      expect(erp.paySupplierInvoice(purchase, 1000.0), isTrue);
      expect(purchase.advancePayment, 2000.0);
      expect(purchase.remainingBalance, 0.0);
      expect(purchase.paymentStatus, 'مدفوعة');

      // Attempt D: Further payment attempt -> MUST BE REJECTED
      expect(erp.paySupplierInvoice(purchase, 50.0), isFalse);
    });
  });
}
