import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/customer_collection_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Customer Account Classification (Factory & Workshop)', () {
    test('ClientModel classifies and serializes currency classification correctly', () {
      final sypClient = ClientModel(
        id: 'c1',
        name: 'عميل ليرة',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.syp,
        debtBalanceSyp: 500000,
      );
      expect(sypClient.currencyClassification, AppCurrency.syp);
      expect(sypClient.isSypCustomer, isTrue);
      expect(sypClient.isUsdCustomer, isFalse);
      expect(sypClient.currencyClassificationLabel, 'SYP Customer');

      final json = sypClient.toJson();
      final restored = ClientModel.fromJson(json);
      expect(restored.currencyClassification, AppCurrency.syp);
      expect(restored.isSypCustomer, isTrue);

      final usdClient = ClientModel(
        id: 'c2',
        name: 'عميل دولار',
        clientType: 'زبون معمل',
        currencyClassification: AppCurrency.usd,
        debtBalance: 1200,
      );
      expect(usdClient.currencyClassification, AppCurrency.usd);
      expect(usdClient.isUsdCustomer, isTrue);
      expect(usdClient.currencyClassificationLabel, 'USD Customer');
    });

    test('Factory POS invoice sets customer account classification based on invoice currency', () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();

      final client = ClientModel(
        id: 'agent_1',
        name: 'معتمد دمشق',
        clientType: 'معتمد مصنع',
      );
      erp.clients = [client];

      // Create an invoice in SYP
      final sypInvoice = FactoryInvoiceModel(
        id: 'fi_1',
        invoiceNo: 'FAC-POS-101',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [],
        advancePayment: 0,
        currency: AppCurrency.syp,
      );
      erp.addFactoryPOSInvoice(sypInvoice);

      // Customer account automatically inherits classification: SYP Customer
      expect(client.currencyClassification, AppCurrency.syp);
      expect(client.isSypCustomer, isTrue);
      expect(client.currencyClassificationLabel, 'SYP Customer');

      // Create a subsequent invoice in USD
      final usdInvoice = FactoryInvoiceModel(
        id: 'fi_2',
        invoiceNo: 'FAC-POS-102',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [],
        advancePayment: 0,
        currency: AppCurrency.usd,
      );
      erp.addFactoryPOSInvoice(usdInvoice);

      // Customer account now inherits classification: USD Customer
      expect(client.currencyClassification, AppCurrency.usd);
      expect(client.isUsdCustomer, isTrue);
      expect(client.currencyClassificationLabel, 'USD Customer');
    });

    test('Workshop invoice creation sets customer account classification based on invoice currency', () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();

      // Create Workshop Invoice in USD
      final usdInvoice = WorkshopInvoiceModel(
        id: 'wi_1',
        invoiceNo: 'WRK-INV-101',
        date: DateTime.now(),
        clientName: 'أحمد النجار',
        sourceType: 'بيع مواد خام من المعمل',
        itemDescription: 'رخام تركي',
        sourceQuantity: 1,
        agreedPrice: 500,
        depositDeducted: 0.0,
        cashPaidNow: 100, // 400 remaining debt
        netCost: 300,
        currency: AppCurrency.usd,
      );
      final created = erp.createWorkshopInvoice(usdInvoice);
      expect(created, isTrue);

      final client = erp.clients.firstWhere((c) => c.name == 'أحمد النجار');
      expect(client.currencyClassification, AppCurrency.usd);
      expect(client.currencyClassificationLabel, 'USD Customer');
      expect(client.debtBalance, 400);

      // Create another invoice for a different customer in SYP
      final sypInvoice = WorkshopInvoiceModel(
        id: 'wi_2',
        invoiceNo: 'WRK-INV-102',
        date: DateTime.now(),
        clientName: 'خالد السعيد',
        sourceType: 'بيع مواد خام من المعمل',
        itemDescription: 'غرانيت أسود',
        sourceQuantity: 1,
        agreedPrice: 3000000,
        depositDeducted: 0.0,
        cashPaidNow: 1000000,
        netCost: 2000000,
        currency: AppCurrency.syp,
      );
      final createdSyp = erp.createWorkshopInvoice(sypInvoice);
      expect(createdSyp, isTrue);

      final sypCustomer = erp.clients.firstWhere((c) => c.name == 'خالد السعيد');
      expect(sypCustomer.currencyClassification, AppCurrency.syp);
      expect(sypCustomer.currencyClassificationLabel, 'SYP Customer');
      expect(sypCustomer.debtBalanceSyp, 2000000);
    });
  });

  group('2. Collection & Payment Mechanism: Case A (Direct Same-Currency Payment)', () {
    test('USD Customer paying in USD directly deducts USD account and adds to Main Safe USD Vault', () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 1000.0; // initial USD vault
      erp.mainCashBoxSyp = 5000000.0; // initial SYP vault

      final client = ClientModel(
        id: 'c_usd',
        name: 'زبون دولار',
        clientType: 'زبون معمل',
        currencyClassification: AppCurrency.usd,
        debtBalance: 350.0,
      );
      erp.clients = [client];

      // Pay $150 USD
      final success = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 150.0,
      );

      expect(success, isTrue);
      // Customer Account (USD): deducted by 150
      expect(client.debtBalance, 200.0);
      // Main Safe (USD Vault): increased by 150
      expect(erp.mainCashBox, 1150.0);
      // SYP Vault unaffected
      expect(erp.mainCashBoxSyp, 5000000.0);
    });

    test('SYP Customer paying in SYP directly deducts SYP account and adds to Main Safe SYP Vault', () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 500.0;
      erp.mainCashBoxSyp = 1000000.0;

      final client = ClientModel(
        id: 'c_syp',
        name: 'زبون ليرة',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.syp,
        debtBalanceSyp: 800000.0,
      );
      erp.clients = [client];

      // Pay 300,000 SYP
      final success = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.syp,
        paymentAmount: 300000.0,
      );

      expect(success, isTrue);
      // Customer Account (SYP): deducted by 300,000
      expect(client.debtBalanceSyp, 500000.0);
      // Main Safe (SYP Vault): increased by 300,000
      expect(erp.mainCashBoxSyp, 1300000.0);
      // USD Vault unaffected
      expect(erp.mainCashBox, 500.0);
    });
  });

  group('3. Business Logic & Calculation Rules: Case B (Cross-Currency Payment)', () {
    test('Scenario 1: USD Customer Paying in SYP', () {
      // Inputs:
      // Amount in SYP = 1,500,000 SYP
      // Exchange Rate = 15,000 SYP per USD
      // Calculation: Converted USD Amount = 1,500,000 / 15,000 = 100 USD
      // Accounting Effect:
      // Customer Account (USD): Deduct 100 USD
      // Main Safe (SYP Vault): Deposit 1,500,000 SYP
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 2000.0;
      erp.mainCashBoxSyp = 3000000.0;

      final client = ClientModel(
        id: 'c_usd_cross',
        name: 'شركة البناء الحديث',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
        debtBalance: 250.0, // owes $250
      );
      erp.clients = [client];

      final success = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.syp,
        paymentAmount: 1500000.0, // amount_syp
        exchangeRate: 15000.0, // exchange_rate
      );

      expect(success, isTrue);
      // Customer Account (USD): 250 - 100 = 150 USD
      expect(client.debtBalance, 150.0);
      // Main Safe (SYP Vault): 3,000,000 + 1,500,000 = 4,500,000 SYP
      expect(erp.mainCashBoxSyp, 4500000.0);
      // Main Safe (USD Vault): Unchanged
      expect(erp.mainCashBox, 2000.0);
    });

    test('Scenario 2: SYP Customer Paying in USD', () {
      // Inputs:
      // Amount in USD = 200 USD
      // Exchange Rate = 15,000 SYP per USD
      // Calculation: Converted SYP Amount = 200 * 15,000 = 3,000,000 SYP
      // Accounting Effect:
      // Customer Account (SYP): Deduct 3,000,000 SYP
      // Main Safe (USD Vault): Deposit 200 USD
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 100.0;
      erp.mainCashBoxSyp = 500000.0;

      final client = ClientModel(
        id: 'c_syp_cross',
        name: 'مؤسسة النور',
        clientType: 'زبون معمل',
        currencyClassification: AppCurrency.syp,
        debtBalanceSyp: 4500000.0, // owes 4,500,000 SYP
      );
      erp.clients = [client];

      final success = erp.collectCustomerPayment(
        client: client,
        paymentCurrency: AppCurrency.usd,
        paymentAmount: 200.0, // amount_usd
        exchangeRate: 15000.0, // exchange_rate
      );

      expect(success, isTrue);
      // Customer Account (SYP): 4,500,000 - 3,000,000 = 1,500,000 SYP
      expect(client.debtBalanceSyp, 1500000.0);
      // Main Safe (USD Vault): 100 + 200 = 300 USD
      expect(erp.mainCashBox, 300.0);
      // Main Safe (SYP Vault): Unchanged
      expect(erp.mainCashBoxSyp, 500000.0);
    });

    test('Cross-currency payment rejects invalid or zero exchange rates', () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();

      final client = ClientModel(
        id: 'c1',
        name: 'عميل اختبار',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
        debtBalance: 100.0,
      );

      // Null rate
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.syp,
          paymentAmount: 50000.0,
          exchangeRate: null,
        ),
        isFalse,
      );

      // Zero rate
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.syp,
          paymentAmount: 50000.0,
          exchangeRate: 0.0,
        ),
        isFalse,
      );

      // Negative amount
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.syp,
          paymentAmount: -100.0,
          exchangeRate: 15000.0,
        ),
        isFalse,
      );
    });
  });

  group('4. UI & Widget Tests for Customer Collection Dialog', () {
    testWidgets('CustomerClassificationBadge renders correctly for both currencies', (tester) async {
      final usdClient = ClientModel(
        id: 'c1',
        name: 'زبون دولار',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
      );
      final sypClient = ClientModel(
        id: 'c2',
        name: 'زبون ليرة',
        clientType: 'زبون معمل',
        currencyClassification: AppCurrency.syp,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CustomerClassificationBadge(client: usdClient),
                CustomerClassificationBadge(client: sypClient),
              ],
            ),
          ),
        ),
      );

      expect(find.text('USD Customer'), findsOneWidget);
      expect(find.text('SYP Customer'), findsOneWidget);
    });

    testWidgets('CustomerCollectionDialog displays account classification and allows direct payment', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 500.0;

      final client = ClientModel(
        id: 'c_ui_usd',
        name: 'أحمد خليل',
        clientType: 'معتمد مصنع',
        currencyClassification: AppCurrency.usd,
        debtBalance: 200.0,
      );
      erp.clients = [client];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CustomerCollectionDialog.show(
                  ctx,
                  client: client,
                  erp: erp,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify Customer Classification is displayed
      expect(find.textContaining('USD Customer'), findsWidgets);
      expect(find.text('تحصيل دفعة: أحمد خليل'), findsOneWidget);

      // Confirm direct payment
      await tester.tap(find.text('تأكيد التحصيل (Confirm)'));
      await tester.pumpAndSettle();

      // Customer account debt balance reduced to 0
      expect(client.debtBalance, 0.0);
      // Main Safe USD vault increased by 200
      expect(erp.mainCashBox, 700.0);
    });

    testWidgets('CustomerCollectionDialog dynamically renders cross-currency inputs and calculates conversion', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 0.0;
      erp.mainCashBoxSyp = 1000000.0;

      final client = ClientModel(
        id: 'c_ui_cross',
        name: 'سامر الحلبي',
        clientType: 'زبون معمل',
        currencyClassification: AppCurrency.usd,
        debtBalance: 100.0, // owes $100
      );
      erp.clients = [client];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CustomerCollectionDialog.show(
                  ctx,
                  client: client,
                  erp: erp,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Switch payment currency to SYP
      await tester.tap(find.text('ليرة سورية (SYP ل.س)'));
      await tester.pumpAndSettle();

      // Conditional fields should appear
      expect(find.textContaining('amount_syp'), findsOneWidget);
      expect(find.textContaining('daily_exchange_rate'), findsOneWidget);

      // Enter payment amount: 1500000 SYP
      final amountField = find.widgetWithText(TextField, 'المبلغ الفعلي المدفوع بالليرة السورية (amount_syp)');
      await tester.enterText(amountField, '1500000');

      // Enter exchange rate: 15000
      final rateField = find.widgetWithText(TextField, 'سعر الصرف المعتمد اليوم (daily_exchange_rate)');
      await tester.enterText(rateField, '15000');
      await tester.pumpAndSettle();

      // Live automated calculation verifies: 1500000 / 15000 = 100 $
      expect(find.textContaining('100'), findsWidgets);

      // Confirm payment
      await tester.tap(find.text('تأكيد التحصيل (Confirm)'));
      await tester.pumpAndSettle();

      // Customer account USD debt reduced by 100 -> 0
      expect(client.debtBalance, 0.0);
      // Main Safe SYP vault deposited with 1,500,000 -> 2,500,000
      expect(erp.mainCashBoxSyp, 2500000.0);
    });
  });
}
