import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'support/stocked_factory_invoice.dart';

/// Multi-currency Down Payment / Cash Collected (الدفعة الأولى / النقد المحصل)
/// across Workshop Invoice, Factory Invoice, Factory Order & Workshop Order:
/// invoice/order totals stay USD-denominated; SYP receipts convert at
/// قيمة الدولار اليوم (USD Equivalent = Collected SYP ÷ Exchange Rate),
/// the equivalent is deducted from the USD balance and the real SYP notes
/// land in the SYP Cash Register / Order Box SYP fund.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ERPProvider freshErp() {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.mainCashBox = 1000.0;
    erp.mainCashBoxSyp = 0.0;
    erp.orderCashBox = 500.0;
    erp.orderCashBoxSyp = 0.0;
    erp.scrapCashBox = 0.0;
    erp.scrapCashBoxSyp = 0.0;
    erp.clients = [];
    erp.factoryInvoices = [];
    erp.workshopInvoices = [];
    erp.factoryOrders = [];
    erp.workshopOrders = [];
    erp.factoryWarehouse = [];
    return erp;
  }

  group('1. Workshop Order deposit in SYP', () {
    test('SYP deposit lands in the Order Box SYP fund, order stays USD', () {
      final erp = freshErp();
      final order = WorkshopOrderModel(
        id: 'order_syp_1',
        orderNo: 'ORD-SYP-1',
        date: DateTime.now(),
        clientName: 'زبون سوري',
        clientPhone: '',
        customDimensionsText: 'تفصيل خاص',
        agreedPrice: 500.0, // USD total
        depositAmount: 100.0, // USD equivalent (1,000,000 ÷ 10,000)
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );
      erp.createWorkshopOrder(order);

      expect(erp.orderCashBoxSyp, 1000000.0); // real notes in SYP fund
      expect(erp.orderCashBox, 500.0); // USD fund untouched
      expect(order.agreedPrice, 500.0); // total remains USD
      expect(order.depositAmount, 100.0); // USD equivalent deducted

      // JSON round-trip keeps the receipt log data.
      final restored = WorkshopOrderModel.fromJson(order.toJson());
      expect(restored.depositPaymentCurrency, AppCurrency.syp);
      expect(restored.depositCollectedSyp, 1000000.0);
      expect(restored.depositExchangeRate, 10000.0);
    });

    test('Cancellation refunds the deposit in its original SYP fund', () {
      final erp = freshErp();
      final order = WorkshopOrderModel(
        id: 'order_syp_2',
        orderNo: 'ORD-SYP-2',
        date: DateTime.now(),
        clientName: 'زبون سوري',
        clientPhone: '',
        customDimensionsText: '',
        agreedPrice: 500.0,
        depositAmount: 100.0,
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
        items: [],
      );
      erp.createWorkshopOrder(order);
      expect(erp.orderCashBoxSyp, 1000000.0);

      erp.cancelWorkshopOrderWorkflow(order: order, isCompleted: false);
      expect(erp.orderCashBoxSyp, 0.0); // refunded in SYP
      expect(erp.orderCashBox, 500.0); // USD fund untouched
    });
  });

  group('2. Factory Order deposit in SYP + rollover into invoice', () {
    test('SYP deposit enters the Order Box SYP fund', () {
      final erp = freshErp();
      final order = FactoryOrderModel(
        id: 'fo_syp_1',
        orderNo: 'FORD-SYP-1',
        date: DateTime.now(),
        clientName: 'معتمد سوري',
        items: [],
        depositAmount: 200.0, // USD equivalent
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 2000000.0,
        depositExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );
      erp.createFactoryOrder(order);
      expect(erp.orderCashBoxSyp, 2000000.0);
      expect(erp.orderCashBox, 500.0);

      final restored = FactoryOrderModel.fromJson(order.toJson());
      expect(restored.depositPaymentCurrency, AppCurrency.syp);
      expect(restored.depositCollectedSyp, 2000000.0);
    });

    test('POS invoice rolls the SYP deposit + SYP till cash into Main SYP', () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_f1',
        name: 'معتمد سوري',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      final order = FactoryOrderModel(
        id: 'fo_syp_2',
        orderNo: 'FORD-SYP-2',
        date: DateTime.now(),
        partyId: client.id,
        clientName: client.name,
        items: [],
        depositAmount: 100.0, // USD equivalent of 1,000,000 @ 10,000
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );
      erp.createFactoryOrder(order);

      // Invoice total 1000 USD, paid: 100 rolled SYP deposit + fresh
      // 50 USD equivalent collected today as 500,000 SYP @ 10,000.
      final item = FactoryInvoiceItem(
        itemId: 'item_f1',
        description: 'رخام',
        quantity: 20.0,
        unitPrice: 50.0,
        unitCost: 30.0,
        itemCategory: 'meter',
      );
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'item_f1',
          typeName: 'رخام',
          grade: '',
          thicknessCm: 0.0,
          category: 'متر مربع',
          availableQty: 120.0,
          netCostPerUnit: 30.0,
          recommendedSalePrice: 50.0,
          currency: AppCurrency.usd,
        ),
      );
      final invoice = FactoryInvoiceModel(
        id: 'fi_syp_1',
        invoiceNo: 'FAC-POS-SYP-1',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [item],
        advancePayment: 150.0, // USD total: 100 deposit + 50 till
        depositAmount: 100.0,
        depositCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
        advancePaymentCurrency: AppCurrency.syp,
        advanceCollectedSyp: 500000.0,
        advanceExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );

      final ok = erp.assignFactoryOrderToPOSInvoice(order, invoice);
      expect(ok, isTrue);

      // 1,500,000 SYP notes (deposit + till) now sit in the MAIN SYP register.
      expect(erp.mainCashBoxSyp, 1500000.0);
      // The USD register received nothing for SYP receipts.
      expect(erp.mainCashBox, 1000.0);
      // The Order Box SYP fund was emptied by the rollover.
      expect(erp.orderCashBoxSyp, 0.0);
      // Only the USD equivalent (150) was deducted from the USD balance.
      expect(invoice.remainingBalance, 850.0);
      expect(client.debtBalance, 850.0);
      expect(client.debtBalanceSyp, 0.0);

      final restored = FactoryInvoiceModel.fromJson(invoice.toJson());
      expect(restored.advancePaymentCurrency, AppCurrency.syp);
      expect(restored.advanceCollectedSyp, 500000.0);
      expect(restored.advanceExchangeRate, 10000.0);
      expect(restored.depositCollectedSyp, 1000000.0);
    });
  });

  group('3. Factory Invoice POS down payment in SYP', () {
    test('SYP cash goes to SYP register; USD balance reduced by equivalent', () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_f2',
        name: 'معتمد الدفع السوري',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);

      // 1,000 USD invoice paid 200 USD-equivalent, collected as
      // 2,000,000 SYP at قيمة الدولار اليوم = 10,000.
      final invoice = FactoryInvoiceModel(
        id: 'fi_syp_2',
        invoiceNo: 'FAC-POS-SYP-2',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_f2',
            description: 'غرانيت',
            quantity: 20.0,
            unitPrice: 50.0,
            unitCost: 30.0,
          ),
        ],
        advancePayment: 200.0, // USD Equivalent = 2,000,000 ÷ 10,000
        advancePaymentCurrency: AppCurrency.syp,
        advanceCollectedSyp: 2000000.0,
        advanceExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );
      expect(postStockedFactoryInvoice(erp, invoice), isTrue);

      expect(erp.mainCashBoxSyp, 2000000.0); // notes in the SYP box
      expect(erp.mainCashBox, 1000.0); // USD register untouched
      expect(invoice.remainingBalance, 800.0); // USD balance deducted
      expect(client.debtBalance, 800.0);
      expect(client.debtBalanceSyp, 0.0);
    });

    test('USD selection keeps the classic behaviour', () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_f3',
        name: 'معتمد الدولار',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);
      final invoice = FactoryInvoiceModel(
        id: 'fi_usd_1',
        invoiceNo: 'FAC-POS-USD-1',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_f3',
            description: 'بازلت',
            quantity: 20.0,
            unitPrice: 50.0,
            unitCost: 30.0,
          ),
        ],
        advancePayment: 600.0,
        advancePaymentCurrency: AppCurrency.usd, // classic USD
        currency: AppCurrency.usd,
      );
      expect(postStockedFactoryInvoice(erp, invoice), isTrue);
      expect(erp.mainCashBox, 1600.0); // full advance in USD register
      expect(erp.mainCashBoxSyp, 0.0); // SYP register untouched
    });
  });

  group('4. Workshop Invoice cash + deposit in SYP', () {
    test('SYP cash and rolled SYP order deposit land in the SYP registers', () {
      final erp = freshErp();
      // Order whose deposit was collected in SYP (1,000,000 @ 10,000 = 100 USD)
      final order = WorkshopOrderModel(
        id: 'order_syp_3',
        orderNo: 'ORD-SYP-3',
        date: DateTime.now(),
        clientName: 'زبون المعمل السوري',
        clientPhone: '',
        customDimensionsText: '',
        agreedPrice: 500.0,
        depositAmount: 100.0,
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
        items: [],
      );
      erp.createWorkshopOrder(order);

      // Invoice 500 USD: 100 rolled deposit (USD equivalent) + 50 USD
      // equivalent collected now as 500,000 SYP @ 10,000.
      final invoice = WorkshopInvoiceModel(
        id: 'wi_syp_1',
        invoiceNo: 'WRK-INV-SYP-1',
        date: DateTime.now(),
        clientName: order.clientName,
        sourceType: 'طلب معمل',
        sourceId: order.id,
        itemDescription: 'تفصيل',
        sourceQuantity: 1,
        agreedPrice: 500.0,
        depositDeducted: 100.0,
        cashPaidNow: 50.0, // USD equivalent
        netCost: 300.0,
        currency: AppCurrency.usd,
        cashPaymentCurrency: AppCurrency.syp,
        cashCollectedSyp: 500000.0,
        cashExchangeRate: 10000.0,
        depositPaymentCurrency: AppCurrency.syp,
        depositCollectedSyp: 1000000.0,
        depositExchangeRate: 10000.0,
      );
      expect(erp.createWorkshopInvoice(invoice), isTrue);

      // Deposit (1,000,000) + cash (500,000) = 1,500,000 in Main SYP register
      expect(erp.mainCashBoxSyp, 1500000.0);
      expect(erp.mainCashBox, 1000.0); // USD register untouched
      expect(erp.orderCashBoxSyp, 0.0); // Order Box emptied by the rollover
      // Only the USD equivalents (150) reduced the 500 USD total.
      expect(invoice.remainingBalance, 350.0);
      final client = erp.clients.firstWhere((c) => c.name == order.clientName);
      expect(client.debtBalance, 350.0);
      expect(client.debtBalanceSyp, 0.0);

      final restored = WorkshopInvoiceModel.fromJson(invoice.toJson());
      expect(restored.cashPaymentCurrency, AppCurrency.syp);
      expect(restored.cashCollectedSyp, 500000.0);
      expect(restored.cashExchangeRate, 10000.0);
      expect(restored.depositCollectedSyp, 1000000.0);
    });

    test('USD down payment keeps classic USD register behaviour', () {
      final erp = freshErp();
      final invoice = WorkshopInvoiceModel(
        id: 'wi_usd_1',
        invoiceNo: 'WRK-INV-USD-1',
        date: DateTime.now(),
        clientName: 'زبون دولار',
        sourceType: 'بيع مواد خام من المعمل',
        itemDescription: 'رخام',
        sourceQuantity: 1,
        agreedPrice: 500.0,
        depositDeducted: 0.0,
        cashPaidNow: 100.0,
        netCost: 300.0,
        currency: AppCurrency.usd,
      );
      expect(erp.createWorkshopInvoice(invoice), isTrue);
      expect(erp.mainCashBox, 1100.0); // classic USD register
      expect(erp.mainCashBoxSyp, 0.0);
    });
  });

  group('5. Daily report logging keeps both currencies', () {
    test('SYP receipts appear as SYP cash-ins with the rate in the log', () {
      final erp = freshErp();
      final client = ClientModel(
        id: 'cli_f4',
        name: 'معتمد التقرير',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      erp.clients.add(client);
      final invoice = FactoryInvoiceModel(
        id: 'fi_syp_rep',
        invoiceNo: 'FAC-POS-SYP-REP',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_f4',
            description: 'رخام',
            quantity: 20.0,
            unitPrice: 50.0,
            unitCost: 30.0,
          ),
        ],
        advancePayment: 200.0,
        advancePaymentCurrency: AppCurrency.syp,
        advanceCollectedSyp: 2000000.0,
        advanceExchangeRate: 10000.0,
        currency: AppCurrency.usd,
      );
      expect(postStockedFactoryInvoice(erp, invoice), isTrue);

      final report = erp.compileDailyReportForDate(DateTime.now());
      final cashMovement = report.cashMovements.firstWhere(
        (m) => m.currency == AppCurrency.syp,
      );
      expect(cashMovement.amount, 2000000.0);
      expect(cashMovement.description, contains('10000'));
      expect(cashMovement.description, contains('ل.س'));
      expect(report.totalCashInSyp, 2000000.0);
      expect(report.totalCashInUsd, 0.0);
    });
  });
}
