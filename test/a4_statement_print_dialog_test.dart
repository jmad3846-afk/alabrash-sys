import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/widgets/a4_statement_print_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('statement invoice details show all requested fields', (
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
        A4StatementDetailLine(
          description: 'بيان الرخام',
          item: 'رخام موغلا',
          specifications: 'درجة أولى',
          type: 'تفصيل',
          length: '200 سم',
          width: '60 سم',
          quantityText: '1.2 متر مربع',
          unitPrice: 90,
          servicesText: 'قص: 12 \$',
          total: 120,
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

    for (final label in [
      'البيان / الوصف',
      'الصنف',
      'المواصفات',
      'النوع',
      'الطول',
      'العرض',
      'الكمية / الأمتار',
      'سعر المتر / الوحدة',
      'الخدمات',
      'السعر الإجمالي',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final value in [
      'بيان الرخام',
      'رخام موغلا',
      'درجة أولى',
      'تفصيل',
      '200 سم',
      '60 سم',
      '1.2 متر مربع',
      '90 \$',
      'قص: 12 \$',
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

    expect(factoryDetails.description, 'بيان الحجر');
    expect(factoryDetails.item, 'رخام موغلا');
    expect(factoryDetails.specifications, contains('درجة أولى'));
    expect(factoryDetails.specifications, contains('جرانيت'));
    expect(factoryDetails.type, 'بلوك');
    expect(factoryDetails.length, '200 سم');
    expect(factoryDetails.width, '60 سم');
    expect(factoryDetails.quantityText, '1.2 م² (1 قطعة)');
    expect(factoryDetails.unitPrice, 90);
    expect(factoryDetails.servicesText, contains('قص: 12 \$'));
    expect(factoryDetails.total, 120);

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
    ).items.single.details.single;

    expect(workshopDetails.description, 'مغسلة رخام');
    expect(workshopDetails.item, 'مغسلة رخام');
    expect(workshopDetails.specifications, contains('رخام'));
    expect(workshopDetails.specifications, contains('2 سم'));
    expect(workshopDetails.type, 'تفصيل بسيط');
    expect(workshopDetails.length, '200 سم');
    expect(workshopDetails.width, '60 سم');
    expect(workshopDetails.quantityText, '1.2 متر مربع');
    expect(workshopDetails.unitPrice, 75);
    expect(workshopDetails.servicesText, contains('تلميع: 10 \$'));
    expect(workshopDetails.total, 100);
  });
}
