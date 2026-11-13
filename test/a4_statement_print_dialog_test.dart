import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_invoice_print_dialog.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';
import 'package:abaad/widgets/a4_statement_invoice_selection_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('statement invoice details render the printable invoice table', (
    tester,
  ) async {
    final lineItem = A4StatementLineItem(
      index: 1,
      date: DateTime(2026, 10, 24),
      documentNo: 'INV-001',
      description: 'رخام للمطبخ',
      currency: AppCurrency.usd,
      totalAmount: 120,
      paidAmount: 0,
      remainingAmount: 120,
      status: 'مستحق التحصيل',
      details: const [
        A4InvoiceLineItem(
          index: 1,
          description: 'رخام موغلا',
          gradeAndSpecs: 'درجة أولى (جرانيت)',
          dimensionsText: '200 × 60 سم',
          lengthCm: 200,
          widthCm: 60,
          quantityText: '1.2 م²\n(1 قطعة)',
          unitPrice: 90,
          servicesText: 'قص: 12 \$',
          lineTotal: 120,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: A4StatementInvoiceDetails(lineItem: lineItem),
            ),
          ),
        ),
      ),
    );

    // The statement must show the exact invoice print table headers.
    for (final label in [
      '#',
      'البيان والمادة',
      'المواصفات والنوع',
      'الطول (سم)',
      'العرض (سم)',
      'الكمية / الأمتار (م²)',
      'سعر المتر / الوحدة',
      'الخدمات الملحقة وحسابها',
      'الإجمالي',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final value in [
      'رخام موغلا',
      'درجة أولى (جرانيت)',
      '200 سم',
      '60 سم',
      'قص: 12 \$',
      '90 \$',
      '120 \$',
    ]) {
      expect(find.text(value), findsWidgets);
    }
  });

  test('factory and workshop invoices populate complete item details', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final client = ClientModel(
      id: 'client-1',
      name: 'عميل الاختبار',
      clientType: 'معتمد مصنع',
    );
    erp.factoryInvoices = [
      FactoryInvoiceModel(
        id: 'factory-invoice-1',
        invoiceNo: 'F-001',
        date: DateTime(2026, 10, 24),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item-1',
            description: 'بيان الحجر',
            typeName: 'رخام موغلا',
            grade: 'درجة أولى',
            lengthCm: 200,
            widthCm: 60,
            quantity: 1,
            unitPrice: 90,
            unitCost: 60,
            isGranite: true,
            services: [ServiceAttachment(serviceName: 'قص', price: 12)],
          ),
        ],
      ),
    ];

    final factoryDetails = A4StatementData.fromAccreditedAgent(
      client: client,
      erp: erp,
    ).items.single.details.single;

    // Must match A4InvoiceData.fromFactoryInvoice (the printed invoice table).
    expect(factoryDetails.description, 'رخام موغلا');
    expect(factoryDetails.gradeAndSpecs, 'درجة أولى (جرانيت)');
    expect(factoryDetails.lengthCm, 200);
    expect(factoryDetails.widthCm, 60);
    expect(factoryDetails.lengthDisplay, '200 سم');
    expect(factoryDetails.widthDisplay, '60 سم');
    expect(factoryDetails.quantityText, '1.2 م²\n(1 قطعة)');
    expect(factoryDetails.unitPrice, 90);
    expect(factoryDetails.servicesText, 'قص: 12\$');
    expect(factoryDetails.lineTotal, 120);

    erp.workshopInvoices = [
      WorkshopInvoiceModel(
        id: 'workshop-invoice-1',
        invoiceNo: 'W-001',
        date: DateTime(2026, 10, 24),
        clientName: client.name,
        agreedPrice: 90,
        depositDeducted: 0,
        cashPaidNow: 0,
        netCost: 60,
        items: [
          WorkshopInvoiceItem(
            id: 'workshop-item-1',
            sourceType: 'تفصيل بسيط',
            description: 'مغسلة رخام',
            quantity: 1.2,
            unitCategory: 'متر مربع',
            unitPrice: 75,
            agreedPrice: 90,
            lengthCm: 200,
            widthCm: 60,
            heightCm: 2,
            services: [ServiceAttachment(serviceName: 'تلميع', price: 10)],
          ),
        ],
      ),
    ];

    final workshopDetails = A4StatementData.fromCustomer(
      client: client,
      erp: erp,
    ).items.singleWhere((i) => i.documentNo == 'W-001').details.single;

    // Must match A4InvoiceData.fromWorkshopInvoice (the printed invoice table).
    expect(workshopDetails.description, 'مغسلة رخام');
    expect(workshopDetails.gradeAndSpecs, 'تفصيل بسيط');
    expect(workshopDetails.dimensionsText, '200 × 60 سم');
    expect(workshopDetails.quantityText, '1.2 م²');
    expect(workshopDetails.unitPrice, 75);
    expect(workshopDetails.servicesText, 'تلميع (10\$)');
    expect(workshopDetails.lineTotal, 100);
  });

  testWidgets(
    'statement selection binds linked return invoices and prevents independent exclusion',
    (tester) async {
      final masterItem = A4StatementLineItem(
        index: 1,
        date: DateTime(2026, 10, 24),
        documentNo: 'F-001',
        description: 'فاتورة بيع أصلية',
        category: 'فاتورة بيع',
        currency: AppCurrency.usd,
        totalAmount: 1000,
        paidAmount: 500,
        remainingAmount: 500,
        status: 'مستحق التحصيل',
      );
      final returnItem = A4StatementLineItem(
        index: 2,
        date: DateTime(2026, 10, 25),
        documentNo: 'RET-001',
        parentInvoiceNo: 'F-001',
        description: 'إشعار مرتجع',
        category: 'مرتجع مبيعات',
        currency: AppCurrency.usd,
        totalAmount: 200,
        paidAmount: 0,
        remainingAmount: 0,
        status: 'مرتجع مسوى',
        isReturn: true,
      );

      final statementData = A4StatementData(
        type: AccountStatementType.accreditedAgent,
        statementNo: 'ST-001',
        issueDate: DateTime(2026, 10, 26),
        accountId: 'client-1',
        accountName: 'عميل الاختبار',
        currentBalanceUsd: 300,
        currentBalanceSyp: 0,
        items: [masterItem, returnItem],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A4StatementInvoiceSelectionDialog(data: statementData),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkboxes: 1 select-all + 2 items
      expect(find.byType(CheckboxListTile), findsNWidgets(3));

      // Return item tile displays the binding badge
      expect(find.textContaining('مرتبطة بالفاتورة #F-001'), findsOneWidget);

      // Attempt to tap the return item's checkbox to uncheck it
      final returnTile = find.byWidgetPredicate(
        (w) =>
            w is CheckboxListTile &&
            w.title is Row &&
            (w.title as Row).children.any(
              (c) =>
                  c is Expanded &&
                  c.child is Text &&
                  ((c.child as Text).data?.contains('RET-001') ?? false),
            ),
      );
      expect(returnTile, findsOneWidget);
      await tester.tap(returnTile);
      await tester.pump();

      // Verify snackbar is shown explaining it cannot be excluded
      expect(
        find.textContaining('لا يمكن استبعاد فاتورة المرتجع (RET-001)'),
        findsOneWidget,
      );

      // Verify return item is still selected
      final returnCheckbox = tester.widget<CheckboxListTile>(returnTile);
      expect(returnCheckbox.value, isTrue);
    },
  );
}
