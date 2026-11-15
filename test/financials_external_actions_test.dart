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
    test(
      'paySupplierDebt is bidirectional: overpaying is allowed, creates an advance, and is logged for the statement',
      () {
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

        // 1. Overpayment beyond the due is now ALLOWED (fully bidirectional
        //    Pay/Collect): 500 paid vs 300 due -> 200 advance (claim) on the
        //    supplier; cash register debited by the full amount.
        expect(
          erp.paySupplierDebt(
            supplier: supplier,
            amount: 500.0, // greater than 300
            currency: AppCurrency.usd,
          ),
          isTrue,
        );
        expect(supplier.debtBalance, closeTo(-200.0, 0.001));
        expect(supplier.hasCredit, isTrue);
        expect(erp.mainCashBox, closeTo(500.0, 0.001));

        // The transaction is logged for the account statement.
        expect(supplier.payments.length, 1);
        expect(supplier.payments.last['direction'], 'pay');
        expect(supplier.payments.last['amount'], closeTo(500.0, 0.001));

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

        // 3. Collecting the surplus back closes the account and is logged
        //    with the opposite direction.
        expect(
          erp.collectFromSupplierCredit(
            supplier: supplier,
            amount: 200.0,
            currency: AppCurrency.usd,
          ),
          isTrue,
        );
        expect(supplier.debtBalance, closeTo(0.0, 0.001));
        expect(erp.mainCashBox, closeTo(700.0, 0.001));
        expect(supplier.payments.length, 2);
        expect(supplier.payments.last['direction'], 'collect');
      },
    );

    test(
      'collectCustomerPayment is bidirectional: overcollection creates a credit and the payout button settles it back',
      () {
        final erp = ERPProvider();
        final client = erp.clients.firstWhere(
          (c) => c.clientType == 'معتمد مصنع',
        );
        client.debtBalance = 250.0;
        erp.mainCashBox = 0.0;

        // 1. Overcollection is now ALLOWED: 400 collected vs 250 due ->
        //    150 credit (أمانة) for the client; cash register credited.
        expect(
          erp.collectCustomerPayment(
            client: client,
            paymentCurrency: AppCurrency.usd,
            paymentAmount: 400.0,
          ),
          isTrue,
        );
        expect(client.debtBalance, closeTo(-150.0, 0.001));
        expect(client.hasCredit, isTrue);
        expect(erp.mainCashBox, closeTo(400.0, 0.001));

        // 2. The "دفع" payout action settles the credit fully back out.
        expect(
          erp.payCustomerCredit(
            client: client,
            amount: 150.0,
            currency: AppCurrency.usd,
          ),
          isTrue,
        );
        expect(client.debtBalance, closeTo(0.0, 0.001));
        expect(erp.mainCashBox, closeTo(250.0, 0.001));

        // 3. Both directions are logged as statement rows.
        final payoutLogged = client.payments
            .where((p) => p['direction'] == 'payout')
            .toList();
        expect(payoutLogged.length, greaterThanOrEqualTo(1));
        expect(payoutLogged.last['amount'], closeTo(150.0, 0.001));
      },
    );

    test(
      'collectProjectPayment strictly prevents overcollection and settles project invoices',
      () {
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
      },
    );
  });

  group(
    'FinancialsScreen - UI External Buttons & Absence of Invoice-Level Buttons',
    () {
      testWidgets('renders external payment and collection buttons', (
        tester,
      ) async {
        final erp = ERPProvider();

        // Configure a supplier with debt
        erp.suppliers.first.debtBalance = 500.0;
        erp.clients = [
          ClientModel(
            id: 'factory-client',
            name: 'Factory client',
            clientType: 'معتمد مصنع',
            debtBalance: 100,
          ),
          ClientModel(
            id: 'workshop-client',
            name: 'Workshop client',
            clientType: 'زبون معمل',
            debtBalance: 200,
          ),
        ];

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

        // Verify BOTH external buttons ("دفع" & "تحصيل") are visible for
        // every supplier regardless of the balance direction.
        expect(find.text('دفع'), findsWidgets);
        expect(find.text('تحصيل'), findsWidgets);

        // Both branches share the approved clients category (index 3).
        await tester.tap(find.text('4. مالية المعتمدين'));
        await tester.pumpAndSettle();

        // Verify BOTH external "تحصيل" and "دفع" buttons exist for agents too.
        expect(find.text('تحصيل'), findsWidgets);
        expect(find.text('دفع'), findsWidgets);
        expect(find.text('المعتمد: Factory client'), findsOneWidget);
        expect(find.text('المعتمد: Workshop client'), findsOneWidget);

        expect(
          find.text('مالية المعتمدين (Approved Clients Financials)'),
          findsOneWidget,
        );
        expect(find.text('4. مالية معتمدي المصنع'), findsNothing);
        expect(find.text('5. مالية المعمل'), findsNothing);
        expect(find.textContaining('مالية المشاريع'), findsNothing);
      });
    },
  );
}
