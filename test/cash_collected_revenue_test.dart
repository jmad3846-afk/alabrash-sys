import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cash-Collected Revenue Recognition Model Tests (Abaad ERP)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Unpaid credit factory sales invoice: 0 realized revenue, no profit inflation', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      // Create a client
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

      // Create a 100% credit sales invoice (advancePayment = 0.0)
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

      erp.addFactoryPOSInvoice(invoice);

      // 1. Revenue must NOT increase because no cash was collected
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 0.0);

      // 2. Net Operating Profit must NOT inflate
      expect(erp.netOperatingProfitOf(AppCurrency.usd) - initialProfit, 0.0);

      // 3. Customer debt must receive the full receivable (1000 USD)
      expect(client.debtOf(AppCurrency.usd), 1000.0);
    });

    test('2. Partial cash factory sales invoice: only collected cash enters Income Summary', () {
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

      // Total invoice = 1000 USD, Advance Payment collected now = 350 USD
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

      erp.addFactoryPOSInvoice(invoice);

      // 1. Revenue increases ONLY by collected amount (350 USD), not the gross 1000 USD
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 350.0);

      // 2. Net Profit increases strictly by the collected 350 USD
      expect(erp.netOperatingProfitOf(AppCurrency.usd) - initialProfit, 350.0);

      // 3. Customer debt receives only the unpaid remainder (650 USD)
      expect(client.debtOf(AppCurrency.usd), 650.0);
    });

    test('3. Factory order conversion: deposit + cash paid now enter Income Summary', () {
      final erp = ERPProvider();
      final initialRevenue = erp.totalFactoryRevenueOf(AppCurrency.usd);

      // Order with 200 USD deposit already received
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

      // Convert order to invoice with 300 USD cash paid now upon delivery
      // Total collected = 200 (deposit) + 300 (cash now) = 500 USD
      erp.assignFactoryOrderToInvoice(order, 300.0);

      // Realized revenue must be exactly 500 USD (deposit + cash paid now)
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - initialRevenue, 500.0);

      // Find the generated invoice
      final inv = erp.factoryInvoices.firstWhere((i) => i.id == order.assignedInvoiceId);
      expect(inv.advancePayment, 500.0);
      expect(inv.remainingBalance, 500.0);
    });

    test('4. Workshop order conversion: depositDeducted + cashPaidNow enter Income Summary', () {
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

      // Create workshop invoice from order: 150 deposit deducted + 250 cash paid now = 400 collected
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

      // Realized revenue must be exactly 400 USD
      expect(erp.totalWorkshopRevenueOf(AppCurrency.usd) - initialRevenue, 400.0);
      expect(invoice.remainingBalance, 400.0);
    });

    test('5. Subsequent collection on invoice immediately increases realized revenue', () {
      final erp = ERPProvider();

      // Create credit invoice (advancePayment = 0)
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
      erp.addFactoryPOSInvoice(invoice);

      final revenueBeforePayment = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final profitBeforePayment = erp.netOperatingProfitOf(AppCurrency.usd);

      // Customer makes partial payment of 400 USD later
      final collected = erp.collectFactoryInvoice(invoice, 400.0);
      expect(collected, isTrue);

      // Revenue immediately increases by 400 USD at collection timestamp
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBeforePayment, 400.0);

      // Net profit immediately reflects the 400 USD collected
      expect(erp.netOperatingProfitOf(AppCurrency.usd) - profitBeforePayment, 400.0);

      // Invoice remaining balance reduces to 600 USD
      expect(invoice.remainingBalance, 600.0);
    });

    test('6. Multi-currency FIFO customer debt collection updates realized revenue', () {
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

      // Invoice 1: 500 USD (credit)
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
      erp.addFactoryPOSInvoice(inv1);

      // Invoice 2: 700 USD (credit)
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
      erp.addFactoryPOSInvoice(inv2);

      expect(client.debtOf(AppCurrency.usd), 1200.0);

      final revenueBefore = erp.totalFactoryRevenueOf(AppCurrency.usd);

      // Customer pays 600 USD against total debt:
      // FIFO settles inv1 completely (500 USD) and 100 USD of inv2
      final ok = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 600.0,
      );
      expect(ok, isTrue);

      // Realized revenue increases by exactly 600 USD
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBefore, 600.0);

      // Inv1 is now fully paid (advancePayment = 500)
      expect(inv1.advancePayment, 500.0);
      expect(inv1.remainingBalance, 0.0);

      // Inv2 has 100 paid, 600 remaining
      expect(inv2.advancePayment, 100.0);
      expect(inv2.remainingBalance, 600.0);

      // Customer debt reduces to 600 USD
      expect(client.debtOf(AppCurrency.usd), 600.0);
    });

    test('7. Unallocated customer debt settlement (legacy balance) recognized in realized revenue', () {
      final erp = ERPProvider();

      // Customer has opening legacy debt of 500 USD (no open invoice in factoryInvoices)
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

      // Client pays 300 USD of legacy debt
      final ok = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 300.0,
      );
      expect(ok, isTrue);

      // Debt drops to 200 USD
      expect(client.debtOf(AppCurrency.usd), 200.0);

      // Realized revenue captures the unallocated cash collection
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - revenueBefore, 300.0);
    });
  });
}
