import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/main.dart';
import 'package:marble_granite_erp/screens/factory_workspace_screen.dart';
import 'package:marble_granite_erp/screens/workshop_workspace_screen.dart';

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

  test(
    'Legacy return cash flow credits supplier returns and debits client returns',
    () {
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
      expect(
        erp.suppliers.first.debtBalance,
        closeTo(supplierDebt - 50, 0.001),
      );
      expect(erp.clients.first.debtBalance, closeTo(customerDebt - 25, 0.001));
    },
  );

  test(
    'Opening inventory requires registered block types and posts to stock',
    () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      erp.openingEntry.isLocked = false;
      erp.blockTypes.clear();
      final stockItem = OpeningStockItemModel(
        id: 'opening-block-test',
        category: 'بلوكات خام المصنع',
        typeName: 'رخام اختبار',
        typeId: 'block-type-test',
        grade: 'درجة أولى',
        quantity: 4,
        unitPrice: 125,
        supplierName: 'مورد افتتاحي',
      );

      expect(() => erp.addOpeningStockItem(stockItem), throwsArgumentError);

      erp.addBlockType(
        BlockTypeModel(
          id: 'block-type-test',
          typeName: 'رخام اختبار',
          grade: 'درجة أولى',
        ),
      );
      erp.addOpeningStockItem(stockItem);
      erp.lockOpeningEntry();

      final block = erp.factoryBlocks.singleWhere(
        (item) => item.id == 'opening-block-test',
      );
      expect(block.weightTons, 4);
      expect(block.tonCost, 125);
      expect(block.supplierName, 'مورد افتتاحي');
    },
  );

  test('Approved factory meters can be sold or transferred to workshop', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.openingEntry.isLocked = false;
    final meterType = erp.meterTypes.first;
    erp.addOpeningStockItem(
      OpeningStockItemModel(
        id: 'opening-meter-test',
        category: 'أمتار المصنع',
        typeName: meterType.typeName,
        typeId: meterType.id,
        grade: meterType.grade,
        thicknessCm: meterType.thicknessCm,
        quantity: 8,
        unitPrice: 10,
      ),
    );
    erp.lockOpeningEntry();

    final meter = erp.factoryWarehouse.singleWhere(
      (item) => item.id == 'opening-meter-test',
    );
    final workshopQuantityBefore = erp.workshopStock.fold<double>(
      0,
      (sum, item) => sum + item.availableQty,
    );
    erp.transferFactoryToWorkshop(meter, 3);
    expect(meter.availableQty, 5);
    expect(
      erp.workshopStock.fold<double>(0, (sum, item) => sum + item.availableQty),
      closeTo(workshopQuantityBefore + 3, 0.001),
    );

    erp.addFactoryPOSInvoice(
      FactoryInvoiceModel(
        id: 'opening-meter-sale',
        invoiceNo: 'OPEN-METER-1',
        date: DateTime.now(),
        partyId: '',
        partyName: 'عميل',
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: meter.id,
            description: meter.typeName,
            quantity: 1,
            unitPrice: 20,
            unitCost: 10,
          ),
        ],
      ),
    );
    expect(meter.availableQty, 4);
  });

  test('Factory cash sales are collected in full and flagged as cash', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final item = erp.factoryWarehouse.first;
    final startingCash = erp.mainCashBox;
    final startingQty = item.availableQty;
    const saleTotal = 75.0;
    final invoice = FactoryInvoiceModel(
      id: 'cash-factory-sale',
      invoiceNo: 'FAC-CASH-SALE-1',
      date: DateTime.now(),
      partyId: '',
      partyName: 'عميل نقدي',
      invoiceType: 'بيع_معتمد',
      items: [
        FactoryInvoiceItem(
          itemId: item.id,
          description: item.typeName,
          quantity: 1,
          unitPrice: saleTotal,
          unitCost: 20,
        ),
      ],
      advancePayment: saleTotal,
      isCashInvoice: true,
    );

    expect(erp.addFactoryPOSInvoice(invoice), isTrue);
    expect(erp.mainCashBox, closeTo(startingCash + saleTotal, 0.001));
    expect(item.availableQty, closeTo(startingQty - 1, 0.001));
    expect(invoice.remainingBalance, 0);
    expect(
      FactoryInvoiceModel.fromJson(invoice.toJson()).isCashInvoice,
      isTrue,
    );
  });

  test('Factory cash purchases require enough cash and post paid stock', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.mainCashBox = 100;
    final supplier = erp.suppliers.first;
    final blockType = erp.blockTypes.first;
    final invoice = FactoryInvoiceModel(
      id: 'cash-factory-purchase',
      invoiceNo: 'FAC-CASH-PUR-1',
      date: DateTime.now(),
      partyId: supplier.id,
      partyName: supplier.name,
      invoiceType: 'شراء_مورد',
      items: [
        FactoryInvoiceItem(
          itemId: '',
          description: blockType.typeName,
          typeName: blockType.typeName,
          grade: blockType.grade,
          quantity: 2,
          unitPrice: 20,
          unitCost: 20,
        ),
      ],
      advancePayment: 40,
      isCashInvoice: true,
    );

    expect(erp.addSupplierPurchaseInvoice(invoice), isTrue);
    expect(erp.mainCashBox, closeTo(60, 0.001));
    expect(erp.factoryBlocks.last.weightTons, 2);
    expect(invoice.remainingBalance, 0);
    expect(
      erp.addSupplierPurchaseInvoice(
        FactoryInvoiceModel(
          id: 'cash-factory-purchase-too-expensive',
          invoiceNo: 'FAC-CASH-PUR-2',
          date: DateTime.now(),
          partyId: supplier.id,
          partyName: supplier.name,
          invoiceType: 'شراء_مورد',
          items: [
            FactoryInvoiceItem(
              itemId: '',
              description: blockType.typeName,
              typeName: blockType.typeName,
              grade: blockType.grade,
              quantity: 5,
              unitPrice: 20,
              unitCost: 20,
            ),
          ],
          advancePayment: 100,
          isCashInvoice: true,
        ),
      ),
      isFalse,
    );
    expect(erp.mainCashBox, closeTo(60, 0.001));
    expect(
      erp.factoryInvoices.any(
        (candidate) => candidate.id == 'cash-factory-purchase-too-expensive',
      ),
      isFalse,
    );
  });

  test('Workshop cash sales settle fully into the cash box', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final startingCash = erp.mainCashBox;
    final invoice = WorkshopInvoiceModel(
      id: 'cash-workshop-sale',
      invoiceNo: 'WRK-CASH-SALE-1',
      date: DateTime.now(),
      clientName: 'عميل نقدي',
      sourceType: 'مواد خام',
      itemDescription: 'بيع نقدي',
      agreedPrice: 125,
      depositDeducted: 0,
      cashPaidNow: 125,
      netCost: 50,
      isCashInvoice: true,
    );

    expect(erp.createWorkshopInvoice(invoice), isTrue);
    expect(erp.mainCashBox, closeTo(startingCash + 125, 0.001));
    expect(invoice.remainingBalance, 0);
    expect(
      WorkshopInvoiceModel.fromJson(invoice.toJson()).isCashInvoice,
      isTrue,
    );
  });

  test('Tailoring inventory migrates legacy pieces to square/cubic meters', () {
    final legacySimple = WorkshopTailoringModel.fromJson({
      'id': 'legacy-simple',
      'name': 'درج قديم',
      'complexity': 'بسيط',
      'rawMaterialDescription': 'رخام',
      'lengthCm': 120,
      'widthCm': 30,
      'heightCm': 0,
      'quantity': 5,
      'materialNetCost': 0,
      'laborCostPerPiece': 2,
      'sellingPrice': 60,
      'isGranite': false,
    });
    final measuredComplex = WorkshopTailoringModel(
      id: 'measured-complex',
      name: 'مغسلة',
      complexity: 'معقد',
      rawMaterialDescription: 'رخام',
      lengthCm: 100,
      widthCm: 50,
      heightCm: 20,
      unitCategory: 'متر مكعب',
      measurementCount: 3,
      quantity: 0.3,
      materialNetCost: 0,
      sellingPrice: 500,
    );
    final restored = WorkshopTailoringModel.fromJson(measuredComplex.toJson());

    expect(legacySimple.unitCategory, 'متر مربع');
    expect(legacySimple.quantity, closeTo(1.8, 0.0001));
    expect(legacySimple.laborCostPerMeter, closeTo(5.5556, 0.001));
    expect(legacySimple.sellingPrice, closeTo(166.6667, 0.001));
    expect(restored.quantity, closeTo(0.3, 0.0001));
    expect(restored.measurementPerCount, closeTo(0.1, 0.0001));
    expect(restored.unitSymbol, 'م³');
  });

  test(
    'Tailoring sales deduct requested square meters from available stock',
    () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      final product = WorkshopTailoringModel(
        id: 'meter-tailoring-sale',
        name: 'درج بالمتر',
        complexity: 'بسيط',
        rawMaterialDescription: 'رخام',
        unitCategory: 'متر مربع',
        quantity: 1.2,
        materialNetCost: 0,
        sellingPrice: 20,
      );
      erp.simpleTailorings.add(product);
      final invoice = WorkshopInvoiceModel(
        id: 'meter-tailoring-invoice',
        invoiceNo: 'TAILOR-METER-1',
        date: DateTime.now(),
        clientName: 'زبون',
        sourceType: 'تفصيل بسيط',
        sourceId: product.id,
        itemDescription: product.name,
        sourceQuantity: 0.25,
        sourceUnitCategory: product.unitCategory,
        agreedPrice: 5,
        depositDeducted: 0,
        cashPaidNow: 5,
        netCost: 0,
      );

      expect(erp.createWorkshopInvoice(invoice), isTrue);
      expect(product.quantity, closeTo(0.95, 0.0001));
      expect(invoice.remainingBalance, 0);
      expect(
        erp.createWorkshopInvoice(
          WorkshopInvoiceModel(
            id: 'meter-tailoring-invoice-too-large',
            invoiceNo: 'TAILOR-METER-2',
            date: DateTime.now(),
            clientName: 'زبون',
            sourceType: 'تفصيل بسيط',
            sourceId: product.id,
            itemDescription: product.name,
            sourceQuantity: 1,
            agreedPrice: 20,
            depositDeducted: 0,
            cashPaidNow: 20,
            netCost: 0,
          ),
        ),
        isFalse,
      );
      expect(product.quantity, closeTo(0.95, 0.0001));
    },
  );

  testWidgets('Factory and Workshop cash invoice sections are available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final erp = ERPProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: erp,
        child: MaterialApp(
          home: FactoryWorkspaceScreen(onNavigateToCutting: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final factoryCashTab = find.text('11. الفواتير النقدية');
    await tester.ensureVisible(factoryCashTab);
    await tester.pumpAndSettle();
    await tester.tap(factoryCashTab);
    await tester.pumpAndSettle();
    expect(find.text('مبيعات نقدية'), findsOneWidget);
    expect(find.text('مشتريات نقدية'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: erp,
        child: const MaterialApp(home: WorkshopWorkspaceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final workshopCashTab = find.text('9. فواتير المبيعات النقدية');
    await tester.ensureVisible(workshopCashTab);
    await tester.pumpAndSettle();
    await tester.tap(workshopCashTab);
    await tester.pumpAndSettle();
    expect(find.text('[إضافة فاتورة بيع نقدية]'), findsOneWidget);
  });

  test(
    'Sales discounts are shown as expenses without distorting net profit',
    () {
      SharedPreferences.setMockInitialValues({});
      final erp = ERPProvider();
      final startingProfit = erp.netOperatingProfit;
      final startingSales = erp.totalFactoryRevenueOf(AppCurrency.usd);
      final startingDiscount = erp.factorySalesDiscountOf(AppCurrency.usd);
      erp.factoryInvoices.add(
        FactoryInvoiceModel(
          id: 'discounted-sale',
          invoiceNo: 'SALE-DISCOUNT-1',
          date: DateTime.now(),
          partyId: '',
          partyName: 'عميل',
          invoiceType: 'بيع_معتمد',
          items: [
            FactoryInvoiceItem(
              itemId: '',
              description: 'رخام',
              quantity: 1,
              unitPrice: 100,
              unitCost: 30,
            ),
          ],
          discountAmount: 10,
        ),
      );

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - startingSales, 90);
      expect(
        erp.factorySalesDiscountOf(AppCurrency.usd) - startingDiscount,
        10,
      );
      expect(erp.netOperatingProfit - startingProfit, 60);
    },
  );

  test('Opening approval allocates capital shares in both currencies', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    erp.openingEntry = OpeningEntryModel(
      landValue: 0,
      buildingsValue: 0,
      machineryValue: 0,
      vehiclesValue: 0,
      furnitureValue: 0,
      mainCashValue: 100,
      scrapCashValue: 0,
      orderCashValue: 0,
      mainCashValueSyp: 1000,
      scrapCashValueSyp: 0,
      orderCashValueSyp: 0,
      inventoryValue: 0,
      customerDebtsValue: 0,
      supplierPayablesValue: 0,
      workerSalariesValue: 0,
      isLocked: false,
    );

    erp.lockOpeningEntry();

    expect(erp.partners[0].injectedCapital, closeTo(42, 0.001));
    expect(erp.partners[1].injectedCapitalSyp, closeTo(350, 0.001));
    expect(erp.partners[2].injectedCapitalSyp, closeTo(230, 0.001));
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

    await tester.tap(find.text('الميزانية العمومية'));
    await tester.pumpAndSettle();
    expect(find.text('مدين • الحساب'), findsOneWidget);

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
