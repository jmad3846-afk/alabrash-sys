import 'support/stocked_factory_invoice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accrual sales revenue and collection isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Unpaid dealer delivery recognizes full revenue and COGS', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      final client = ClientModel(
        id: 'client_credit_1',
        name: 'عميل آجل تجريبي',
        phone: '0911000000',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'fi_credit_1',
        invoiceNo: 'POS-CREDIT-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1',
            description: 'رخام تركي',
            quantity: 20.0,
            unitPrice: 50.0, // Total = 1000 USD
            unitCost: 30.0,
          ),
        ],
        advancePayment: 0.0, // Unpaid
        currency: AppCurrency.usd,
      );

      postStockedFactoryInvoice(erp, invoice);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 1000.0);

      expect(erp.netOperatingProfitOf(AppCurrency.usd) - initialProfit, 400.0);

      expect(client.debtOf(AppCurrency.usd), 1000.0);
    });

    test('2. Partial cash invoice recognizes full revenue and COGS', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      final client = ClientModel(
        id: 'client_partial_1',
        name: 'عميل دفعة جزئية',
        phone: '0911000001',
        location: 'حمص',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'fi_partial_1',
        invoiceNo: 'POS-PARTIAL-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1',
            description: 'ألواح غرانيت',
            quantity: 10.0,
            unitPrice: 100.0, // Total = 1000 USD
            unitCost: 50.0,
          ),
        ],
        advancePayment: 350.0, // Paid now
        currency: AppCurrency.usd,
      );

      postStockedFactoryInvoice(erp, invoice);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 1000.0);

      expect(erp.netOperatingProfitOf(AppCurrency.usd) - initialProfit, 500.0);

      expect(client.debtOf(AppCurrency.usd), 650.0);
    });

    test('3. Factory order delivery recognizes the full invoice', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalFactoryRevenueOf(AppCurrency.usd);

      final order = FactoryOrderModel(
        id: 'fo_test_1',
        orderNo: 'ORD-101',
        date: DateTime.now(),
        partyId: 'cli1',
        clientName: 'شركة العمران للمقاولات',
        warehouseItemId: 'fw1',
        itemDescription: 'رخام كاردينال',
        quantity: 10.0,
        unitPrice: 100.0, // Grand total = 1000 USD
        depositAmount: 200.0, // Deposit already held
        currency: AppCurrency.usd,
      );
      erp.factoryOrders.add(order);

      erp.assignFactoryOrderToInvoice(order, 300.0);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 1000.0);

      final inv = erp.factoryInvoices.firstWhere((i) => i.id == order.assignedInvoiceId);
      expect(inv.advancePayment, 500.0);
      expect(inv.remainingBalance, 500.0);
    });

    test('4. Workshop invoice recognizes full revenue independently of deposits', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalWorkshopRevenueOf(AppCurrency.usd);

      final order = WorkshopOrderModel(
        id: 'wo_test_1',
        orderNo: 'WRK-ORD-101',
        date: DateTime.now(),
        clientName: 'عميل معمل تجريبي',
        clientPhone: '0933000000',
        customDimensionsText: 'تفصيل مغسلة رخام',
        agreedPrice: 800.0,
        depositAmount: 150.0,
        currency: AppCurrency.usd,
      );
      erp.workshopOrders.add(order);

      final invoice = WorkshopInvoiceModel(
        id: 'wi_test_1',
        invoiceNo: 'WRK-INV-101',
        date: DateTime.now(),
        clientName: order.clientName,
        sourceType: 'طلبية معمل',
        sourceId: order.id,
        itemDescription: order.customDimensionsText,
        agreedPrice: 800.0,
        depositDeducted: 150.0,
        cashPaidNow: 250.0,
        netCost: 400.0,
        currency: AppCurrency.usd,
      );

      final ok = erp.createWorkshopInvoice(invoice);
      expect(ok, isTrue);

      expect(erp.totalWorkshopRevenueOf(AppCurrency.usd) - initialRevenue, 800.0);
      expect(invoice.remainingBalance, 400.0);
    });

    test('5. Subsequent collections do not recognize sales a second time', () {
      final erp = ERPProvider();

      final invoice = FactoryInvoiceModel(
        id: 'fi_subseq_1',
        invoiceNo: 'POS-SUBSEQ-001',
        date: DateTime.now(),
        partyId: 'cli1',
        partyName: 'شركة العمران للمقاولات',
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1',
            description: 'درج رخام',
            quantity: 10.0,
            unitPrice: 100.0, // 1000 USD
            unitCost: 50.0,
          ),
        ],
        advancePayment: 0.0,
        currency: AppCurrency.usd,
      );
      postStockedFactoryInvoice(erp, invoice);

      final revenueBeforePayment = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final profitBeforePayment = erp.netOperatingProfitOf(AppCurrency.usd);

      final collected = erp.collectFactoryInvoice(invoice, 400.0);
      expect(collected, isTrue);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBeforePayment, 0.0);

      expect(erp.netOperatingProfitOf(AppCurrency.usd) - profitBeforePayment, 0.0);

      expect(invoice.remainingBalance, 600.0);
    });

    test('6. FIFO collection settles receivables without changing revenue', () {
      final erp = ERPProvider();

      final client = ClientModel(
        id: 'cli_fifo_1',
        name: 'معتمد الفيفو',
        phone: '0922334455',
        location: 'اللاذقية',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      final inv1 = FactoryInvoiceModel(
        id: 'fi_fifo_1',
        invoiceNo: 'FIFO-001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1',
            description: 'ألواح',
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 50.0,
          ),
        ],
        advancePayment: 0.0,
        currency: AppCurrency.usd,
      );
      postStockedFactoryInvoice(erp, inv1);

      final inv2 = FactoryInvoiceModel(
        id: 'fi_fifo_2',
        invoiceNo: 'FIFO-002',
        date: DateTime.now().subtract(const Duration(days: 1)),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_2',
            description: 'غرانيت',
            quantity: 7.0,
            unitPrice: 100.0,
            unitCost: 50.0,
          ),
        ],
        advancePayment: 0.0,
        currency: AppCurrency.usd,
      );
      postStockedFactoryInvoice(erp, inv2);

      expect(client.debtOf(AppCurrency.usd), 1200.0);

      final revenueBefore = erp.totalFactoryRevenueOf(AppCurrency.usd);

      final ok = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 600.0,
      );
      expect(ok, isTrue);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBefore, 0.0);

      expect(inv1.advancePayment, 500.0);
      expect(inv1.remainingBalance, 0.0);

      expect(inv2.advancePayment, 100.0);
      expect(inv2.remainingBalance, 600.0);

      expect(client.debtOf(AppCurrency.usd), 600.0);
    });

    test('7. Opening debt collection never becomes new sales revenue', () {
      final erp = ERPProvider();

      final client = ClientModel(
        id: 'cli_legacy_1',
        name: 'عميل رصيد افتتاحي قديم',
        phone: '0988776655',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 500.0,
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      final revenueBefore = erp.totalFactoryRevenueOf(AppCurrency.usd);

      final ok = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 300.0,
      );
      expect(ok, isTrue);

      expect(client.debtOf(AppCurrency.usd), 200.0);

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBefore, 0.0);
    });
  });
}
