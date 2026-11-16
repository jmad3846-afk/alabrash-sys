import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/supplier_credit_collection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the Distributor/Agent (CustomerCollectionDialog) UI tests to prove
/// the Supplier "التحصيل من مورد" dialog is 100% identical in behaviour:
/// classification badge, same-currency direct collection and cross-currency
/// real-time conversion.
void main() {
  group('5. UI & Widget Tests for Supplier Collection Dialog', () {
    testWidgets('SupplierCreditCollectionDialog displays account classification and allows direct collection', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 500.0;

      final supplier = SupplierModel(
        id: 's_ui_usd',
        name: 'مورد الخليلي',
        phone: '',
        location: '',
        debtBalance: -200.0, // credit: supplier owes us $200
      );
      erp.suppliers = [supplier];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SupplierCreditCollectionDialog.show(
                  ctx,
                  supplier: supplier,
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

      // Verify Supplier Classification is displayed (identical badge layout)
      expect(find.textContaining('USD Supplier'), findsWidgets);
      expect(find.text('تحصيل دفعة: مورد الخليلي'), findsOneWidget);

      // Same field ordering as the distributor dialog
      expect(find.text('تصنيف حساب المورد في المالية:'), findsOneWidget);
      expect(find.text('الذمة المستحقة:'), findsOneWidget);
      expect(
        find.text('عملة الدفع الفعلية (Payment Currency):'),
        findsOneWidget,
      );
      expect(find.text('دفع مباشر بنفس عملة الحساب (دولار)'), findsOneWidget);
      expect(
        find.text('الأثر المحاسبي وفق القيد المزدوج (Double-Entry Impact):'),
        findsOneWidget,
      );

      // Confirm direct collection
      await tester.tap(find.text('تأكيد التحصيل (Confirm)'));
      await tester.pumpAndSettle();

      // Supplier credit consumed -> balance back to zero
      expect(supplier.debtBalance, 0.0);
      // Main Safe USD vault increased by 200
      expect(erp.mainCashBox, 700.0);
    });

    testWidgets('SupplierCreditCollectionDialog dynamically renders cross-currency inputs and calculates conversion', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 0.0;
      erp.mainCashBoxSyp = 1000000.0;

      final supplier = SupplierModel(
        id: 's_ui_cross',
        name: 'مورد الحلبي',
        phone: '',
        location: '',
        debtBalance: -100.0, // credit: supplier owes us $100
      );
      erp.suppliers = [supplier];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SupplierCreditCollectionDialog.show(
                  ctx,
                  supplier: supplier,
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

      // Switch payment currency to SYP (same option labels as distributor)
      await tester.tap(find.text('ليرة سورية (SYP ل.س)'));
      await tester.pumpAndSettle();

      // Conditional fields appear in the same order as the distributor dialog
      expect(find.text('تاريخ التحصيل'), findsOneWidget);
      expect(find.text('الوصف / ملاحظات (اختياري)'), findsOneWidget);
      expect(find.textContaining('amount_syp'), findsOneWidget);
      expect(find.textContaining('daily_exchange_rate'), findsOneWidget);
      expect(
        find.text(
          'حالة خاصة: مورد دولار يدفع بالليرة السورية (USD Supplier Paying in SYP)',
        ),
        findsOneWidget,
      );

      // Enter payment amount: 1500000 SYP
      final amountField = find.widgetWithText(
        TextField,
        'المبلغ الفعلي المدفوع بالليرة السورية (amount_syp)',
      );
      await tester.enterText(amountField, '1500000');

      // Enter exchange rate: 15000
      final rateField = find.widgetWithText(
        TextField,
        'سعر الصرف المعتمد اليوم (daily_exchange_rate)',
      );
      await tester.enterText(rateField, '15000');
      await tester.pumpAndSettle();

      // Live automated calculation: 1500000 / 15000 = 100 $
      expect(find.textContaining('100'), findsWidgets);
      expect(
        find.textContaining('Converted USD = amount_syp / exchange_rate'),
        findsOneWidget,
      );

      // Confirm collection
      await tester.tap(find.text('تأكيد التحصيل (Confirm)'));
      await tester.pumpAndSettle();

      // Supplier USD credit consumed by the converted equivalent
      expect(supplier.debtBalance, 0.0);
      // Main Safe SYP vault deposited with 1,500,000
      expect(erp.mainCashBoxSyp, 2500000.0);
      expect(erp.mainCashBox, 0.0);
    });

    testWidgets('SupplierCreditCollectionDialog requires an exchange rate for cross-currency collection', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.mainCashBox = 0.0;
      erp.mainCashBoxSyp = 0.0;

      final supplier = SupplierModel(
        id: 's_ui_rate',
        name: 'مورد بدون سعر صرف',
        phone: '',
        location: '',
        debtBalance: -100.0,
      );
      erp.suppliers = [supplier];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SupplierCreditCollectionDialog.show(
                  ctx,
                  supplier: supplier,
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

      await tester.tap(find.text('ليرة سورية (SYP ل.س)'));
      await tester.pumpAndSettle();

      final amountField = find.widgetWithText(
        TextField,
        'المبلغ الفعلي المدفوع بالليرة السورية (amount_syp)',
      );
      await tester.enterText(amountField, '1500000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('تأكيد التحصيل (Confirm)'));
      await tester.pumpAndSettle();

      // Same validation message as the distributor dialog
      expect(
        find.text(
          'يرجى إدخال سعر الصرف (قيمة الدولار اليوم) لإتمام التحصيل بعملة مختلفة.',
        ),
        findsOneWidget,
      );

      // Nothing changed
      expect(supplier.debtBalance, -100.0);
      expect(erp.mainCashBoxSyp, 0.0);
    });
  });
}
