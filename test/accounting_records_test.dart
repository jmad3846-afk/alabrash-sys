import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Opening entry detail records survive model serialization', () {
    final opening = OpeningEntryModel(
      fixedAssets: [
        FixedAssetModel(
          id: 'asset-1',
          category: 'أراضي',
          name: 'موقع المصنع',
          amount: 500,
          currency: AppCurrency.usd,
          description: 'أرض المصنع',
        ),
      ],
      openingStock: [
        OpeningStockItemModel(
          id: 'stock-1',
          category: 'بلوكات خام المصنع',
          typeName: 'رخام أبيض',
          quantity: 2,
          unitPrice: 150,
        ),
      ],
      legacyFinancials: [
        LegacyFinancialRecordModel(
          id: 'legacy-1',
          category: 'suppliers',
          name: 'مورد قديم',
          phone: '0912345678',
          currency: AppCurrency.syp,
          amount: 20000,
        ),
      ],
    );

    final restored = OpeningEntryModel.fromJson(opening.toJson());

    expect(restored.fixedAssets.single.name, 'موقع المصنع');
    expect(restored.fixedAssets.single.amount, 500);
    expect(restored.openingStock.single.totalPrice, 300);
    expect(restored.legacyFinancials.single.phone, '0912345678');
    expect(restored.legacyFinancials.single.currency, AppCurrency.syp);
  });

  test('Asset purchase and sale update cash and partner withdrawals', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.mainCashBox = 100;

    final purchased = erp.purchaseFixedAsset(
      category: 'آلات ومعدات',
      name: 'منشار',
      amount: 100,
      currency: AppCurrency.usd,
      description: 'منشار رئيسي',
    );

    expect(purchased, isTrue);
    expect(erp.mainCashBox, 0);
    final asset = erp.openingEntry.fixedAssets.firstWhere(
      (item) => item.name == 'منشار',
    );
    final sold = erp.sellFixedAsset(
      assetId: asset.id,
      saleAmount: 120,
      currency: AppCurrency.usd,
      partnerTransfers: {
        erp.partners[0].id: true,
        erp.partners[1].id: true,
        erp.partners[2].id: false,
      },
    );

    expect(sold, isTrue);
    expect(asset.isSold, isTrue);
    expect(asset.saleAmount, 120);
    expect(erp.mainCashBox, closeTo(80, 0.001));
    expect(erp.partners[2].totalWithdrawn, closeTo(40, 0.001));
  });

  test('Factory sales return reduces customer debt and restores stock', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final invoice = erp.factoryInvoices.single;
    final stock = erp.factoryWarehouse.firstWhere((item) => item.id == 'fw1');
    final startingQuantity = stock.availableQty;
    final startingDebt = erp.clients
        .firstWhere((item) => item.id == 'cli1')
        .debtBalance;
    final startingDue = invoice.remainingBalance;

    final posted = erp.addAdjustmentInvoice(
      AdjustmentInvoiceModel(
        id: 'return-sales-1',
        invoiceNo: 'RET-1',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        itemId: 'fw1',
        itemDescription: 'رخام كاردينال 2سم',
        partyName: invoice.partyName,
        description: 'مرتجع جزئي',
        amount: 100,
        quantity: 1,
        paymentAction: 'تخفيض دين',
        currency: invoice.currency,
      ),
    );

    expect(posted, isTrue);
    expect(stock.availableQty, closeTo(startingQuantity + 2, 0.001));
    expect(
      erp.clients.firstWhere((item) => item.id == 'cli1').debtBalance,
      closeTo(startingDebt - 100, 0.001),
    );
    expect(invoice.remainingBalance, closeTo(startingDue - 100, 0.001));
    expect(erp.adjustmentInvoices.single.quantity, 1);
  });

  test(
    'Supplier purchase return receives cash and removes returned blocks',
    () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      final invoice = FactoryInvoiceModel(
        id: 'purchase-adjustment-target',
        invoiceNo: 'PUR-1',
        date: DateTime.now(),
        partyId: 'sup1',
        partyName: erp.suppliers.first.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: '',
            description: 'رخام كاردينال',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            quantity: 10,
            unitPrice: 120,
            unitCost: 100,
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);
      final startingCash = erp.mainCashBox;
      final startingBlocks = erp.factoryBlocks
          .where(
            (block) =>
                block.typeName == 'رخام كاردينال' && block.grade == 'درجة أولى',
          )
          .fold<double>(0, (sum, block) => sum + block.weightTons);

      final posted = erp.addAdjustmentInvoice(
        AdjustmentInvoiceModel(
          id: 'return-purchase-1',
          invoiceNo: 'RET-PUR-1',
          module: 'factory',
          kind: 'purchase_return',
          targetInvoiceId: invoice.id,
          targetInvoiceNo: invoice.invoiceNo,
          itemDescription: 'رخام كاردينال',
          partyName: invoice.partyName,
          description: 'مرتجع للمورد',
          amount: 100,
          quantity: 2,
          paymentAction: 'استرداد نقدي للصندوق الرئيسي',
          currency: AppCurrency.usd,
        ),
      );

      final remainingBlocks = erp.factoryBlocks
          .where(
            (block) =>
                block.typeName == 'رخام كاردينال' && block.grade == 'درجة أولى',
          )
          .fold<double>(0, (sum, block) => sum + block.weightTons);
      expect(posted, isTrue);
      expect(erp.mainCashBox, closeTo(startingCash + 100, 0.001));
      expect(remainingBlocks, closeTo(startingBlocks - 2, 0.001));
      expect(
        invoice.remainingBalance,
        closeTo(invoice.grandTotal - 100, 0.001),
      );
    },
  );

  test('Adjustment rejects excess return quantity without side effects', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final invoice = erp.factoryInvoices.single;
    final stock = erp.factoryWarehouse.firstWhere((item) => item.id == 'fw1');
    final startingQuantity = stock.availableQty;
    final startingDebt = erp.clients
        .firstWhere((item) => item.id == 'cli1')
        .debtBalance;

    final posted = erp.addAdjustmentInvoice(
      AdjustmentInvoiceModel(
        id: 'return-sales-invalid',
        invoiceNo: 'RET-INVALID',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        itemId: 'fw1',
        itemDescription: 'رخام كاردينال 2سم',
        partyName: invoice.partyName,
        description: 'كمية زائدة',
        amount: 100,
        quantity: 11,
        paymentAction: 'تخفيض دين',
        currency: invoice.currency,
      ),
    );

    expect(posted, isFalse);
    expect(stock.availableQty, startingQuantity);
    expect(
      erp.clients.firstWhere((item) => item.id == 'cli1').debtBalance,
      startingDebt,
    );
    expect(erp.adjustmentInvoices, isEmpty);
  });

  test('Legacy return cash flow credits supplier returns and debits client returns', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final startingCash = erp.mainCashBox;
    final supplierDebt = erp.suppliers.first.debtBalance;
    final customerDebt = erp.clients.first.debtBalance;

    final supplierReturn = erp.processReturnInvoice(
      ReturnInvoiceModel(
        id: 'legacy-supplier-return',
        returnNo: 'RET-SUP-1',
        date: DateTime.now(),
        returnType: 'مرتجع مشتريات مورد',
        partyName: erp.suppliers.first.name,
        itemDescription: 'رخام كاردينال',
        quantity: 1,
        refundAmount: 50,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
      ),
    );
    final customerReturn = erp.processReturnInvoice(
      ReturnInvoiceModel(
        id: 'legacy-customer-return',
        returnNo: 'RET-CLI-1',
        date: DateTime.now(),
        returnType: 'مرتجع مبيعات مصنع',
        partyName: erp.clients.first.name,
        itemDescription: 'رخام كاردينال',
        quantity: 1,
        refundAmount: 25,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
      ),
    );

    expect(supplierReturn, isTrue);
    expect(customerReturn, isTrue);
    expect(erp.mainCashBox, closeTo(startingCash + 25, 0.001));
    expect(erp.suppliers.first.debtBalance, closeTo(supplierDebt - 50, 0.001));
    expect(erp.clients.first.debtBalance, closeTo(customerDebt - 25, 0.001));
  });

  testWidgets('Accounting and asset screens are available in the sidebar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ERPProvider(),
        child: const MarbleGraniteERPApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('دليل الحسابات'));
    await tester.pumpAndSettle();
    expect(find.text('الميزانية العمومية الحالية • مباشرة'), findsOneWidget);

    await tester.tap(find.text('إدارة الأصول الثابتة'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة وشراء'), findsOneWidget);

    await tester.tap(find.text('المصروفات'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة نوع مصروف'), findsOneWidget);

    await tester.tap(find.text('مرتجعات ومسموحات الفواتير'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة فاتورة جديدة'), findsOneWidget);

    await tester.tap(find.text('المصنع').first);
    await tester.pumpAndSettle();
    expect(find.text('10. المرتجعات والمسموحات'), findsOneWidget);

    await tester.tap(find.text('المعمل').first);
    await tester.pumpAndSettle();
    expect(find.text('8. مرتجعات ومسموحات المبيعات'), findsOneWidget);
  });
}
