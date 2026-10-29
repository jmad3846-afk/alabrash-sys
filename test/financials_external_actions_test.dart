import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:abaad/core/theme/app_theme.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/screens/financials_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ERPProvider - External Payments & Collections Logic', () {
    test('paySupplierDebt strictly prevents overpaying and settles invoices FIFO', () {
      final erp = ERPProvider();
      final supplier = erp.suppliers.first;
      supplier.debtBalance = 300.0;
      erp.mainCashBox = 1000.0;

      // Add two invoices: $100 and $200
      final inv1 = FactoryInvoiceModel(
        id: 'fi_sup_1',
        invoiceNo: 'SUP-INV-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        currency: AppCurrency.usd,
        items: [],
        advancePayment: 0.0,
      );
      final inv2 = FactoryInvoiceModel(
        id: 'fi_sup_2',
        invoiceNo: 'SUP-INV-002',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        currency: AppCurrency.usd,
        items: [],
        advancePayment: 0.0,
      );
      erp.factoryInvoices.addAll([inv1, inv2]);

      // 1. Strict overpayment prevention:
      expect(
        erp.paySupplierDebt(
          supplier: supplier,
          amount: 500.0, // greater than 300
          currency: AppCurrency.usd,
        ),
        isFalse,
      );
      // Supplier debt should remain untouched
      expect(supplier.debtBalance, closeTo(300.0, 0.001));

      // 2. Reject non-positive amounts
      expect(
        erp.paySupplierDebt(
          supplier: supplier,
          amount: 0.0,
          currency: AppCurrency.usd,
        ),
        isFalse,
      );
      expect(
        erp.paySupplierDebt(
          supplier: supplier,
          amount: -50.0,
          currency: AppCurrency.usd,
        ),
        isFalse,
      );

      // 3. Partial payment of $150
      expect(
        erp.paySupplierDebt(
          supplier: supplier,
          amount: 150.0,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(supplier.debtBalance, closeTo(150.0, 0.001));
      expect(erp.mainCashBox, closeTo(850.0, 0.001));
    });

    test('collectCustomerPayment strictly prevents overcollection and settles invoices FIFO', () {
      final erp = ERPProvider();
      final client = erp.clients.firstWhere((c) => c.clientType == 'معتمد مصنع');
      client.debtBalance = 250.0;
      erp.mainCashBox = 0.0;

      // 1. Strict overcollection prevention (Same Currency)
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.usd,
          paymentAmount: 400.0,
        ),
        isFalse,
      );
      expect(client.debtBalance, closeTo(250.0, 0.001));

      // 2. Exact or valid payment
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.usd,
          paymentAmount: 250.0,
        ),
        isTrue,
      );
      expect(client.debtBalance, closeTo(0.0, 0.001));
      expect(erp.mainCashBox, closeTo(250.0, 0.001));

      // 3. Further collection now rejected because debt is 0
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.usd,
          paymentAmount: 10.0,
        ),
        isFalse,
      );
    });

    test('collectProjectPayment strictly prevents overcollection and settles project invoices', () {
      final erp = ERPProvider();
      erp.mainCashBox = 100.0;

      final project = WorkshopProjectModel(
        id: 'proj_test_1',
        name: 'مشروع فيلا النرجس',
        clientName: 'أبو أحمد',
        phone: '0933111222',
        description: 'أعمال درج وأرضيات',
      );
      erp.workshopProjects.add(project);

      final inv = WorkshopInvoiceModel(
        id: 'wi_proj_1',
        invoiceNo: 'W-INV-001',
        date: DateTime.now(),
        clientName: 'أبو أحمد',
        projectId: project.id,
        itemDescription: 'رخام',
        sourceType: 'ورشة',
        sourceId: '',
        sourceQuantity: 10,
        sourceUnitCategory: 'متر',
        agreedPrice: 600.0,
        depositDeducted: 0.0,
        cashPaidNow: 100.0,
        netCost: 300.0,
        salesDiscount: 0.0,
        currency: AppCurrency.usd,
      );
      erp.workshopInvoices.add(inv);

      // Remaining due on project is 500 USD
      expect(erp.projectDue(project.id), closeTo(500.0, 0.001));

      // 1. Strict overcollection prevention:
      expect(
        erp.collectProjectPayment(
          projectId: project.id,
          amount: 600.0, // greater than 500
          currency: AppCurrency.usd,
        ),
        isFalse,
      );
      expect(erp.projectDue(project.id), closeTo(500.0, 0.001));

      // 2. Valid partial collection of $200:
      expect(
        erp.collectProjectPayment(
          projectId: project.id,
          amount: 200.0,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(erp.projectDue(project.id), closeTo(300.0, 0.001));
      expect(erp.mainCashBox, closeTo(300.0, 0.001));

      // 3. Settle remainder $300:
      expect(
        erp.collectProjectPayment(
          projectId: project.id,
          amount: 300.0,
          currency: AppCurrency.usd,
        ),
        isTrue,
      );
      expect(erp.projectDue(project.id), closeTo(0.0, 0.001));
    });
  });

  group('FinancialsScreen - UI External Buttons & Absence of Invoice-Level Buttons', () {
    testWidgets('renders external payment and collection buttons', (tester) async {
      final erp = ERPProvider();

      // Configure a supplier with debt
      erp.suppliers.first.debtBalance = 500.0;

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        ChangeNotifierProvider<ERPProvider>.value(
          value: erp,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: const Scaffold(body: FinancialsScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Factory Suppliers Tab (index 2)
      await tester.tap(find.textContaining('مالية موردي المصنع'));
      await tester.pumpAndSettle();

      // Verify the external "دفع للمورد" button exists
      expect(find.text('دفع للمورد'), findsWidgets);

      // Navigate to Factory Clients Tab (index 3)
      await tester.tap(find.textContaining('مالية معتمدي المصنع'));
      await tester.pumpAndSettle();

      // Verify the external "تحصيل" button exists
      expect(find.text('تحصيل'), findsWidgets);

      // Navigate to Workshop Finances Tab (index 4)
      await tester.tap(find.textContaining('مالية المعمل'));
      await tester.pumpAndSettle();

      // In Workshop Finances: Retail Customers are displayed directly, Project finances removed
      expect(find.textContaining('حسابات زبائن المعمل'), findsOneWidget);
      expect(find.textContaining('مالية المشاريع'), findsNothing);
    });
  });
}
