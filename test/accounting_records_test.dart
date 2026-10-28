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

  test(
      'Asset purchase and sale: higher, lower, and equal price rules with Income Summary and Capital',
      () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    final initialCapital = erp.totalCurrentEquity;
    erp.mainCashBox = 500;

    // --- Scenario 1: Sale price HIGHER than registered price ---
    final purchased1 = erp.purchaseFixedAsset(
      category: 'آلات ومعدات',
      name: 'منشار كبير',
      amount: 100,
      currency: AppCurrency.usd,
      description: 'منشار رئيسي',
    );
    expect(purchased1, isTrue);
    expect(erp.mainCashBox, 400);

    final asset1 = erp.openingEntry.fixedAssets.firstWhere(
      (item) => item.name == 'منشار كبير',
    );
    final soldHigher = erp.sellFixedAsset(
      assetId: asset1.id,
      saleAmount: 120, // 120 > 100 -> Gain = 20
      currency: AppCurrency.usd,
    );

    expect(soldHigher, isTrue);
    // 1. Full amount enters the Main Safe (400 + 120 = 520)
    expect(erp.mainCashBox, 520);
    // 2. The fixed asset is completely removed from items
    expect(
      erp.openingEntry.fixedAssets.any((item) => item.id == asset1.id),
      isFalse,
    );
    // 3. Subtraction (120 - 100 = 20) goes to Profits/Gains in Income Summary
    expect(erp.assetSaleGainsOf(AppCurrency.usd), 20);
    expect(erp.assetSaleLossesOf(AppCurrency.usd), 0);
    // 4. Capital balance remains unaffected
    expect(erp.totalCurrentEquity, initialCapital);

    // --- Scenario 2: Sale price LOWER than registered price ---
    final purchased2 = erp.purchaseFixedAsset(
      category: 'آليات ونقل',
      name: 'رافعة شوكية',
      amount: 200,
      currency: AppCurrency.usd,
      description: 'رافعة بضائع',
    );
    expect(purchased2, isTrue);
    expect(erp.mainCashBox, 320); // 520 - 200 = 320

    final asset2 = erp.openingEntry.fixedAssets.firstWhere(
      (item) => item.name == 'رافعة شوكية',
    );
    final soldLower = erp.sellFixedAsset(
      assetId: asset2.id,
      saleAmount: 150, // 150 < 200 -> Loss = 50
      currency: AppCurrency.usd,
    );

    expect(soldLower, isTrue);
    // 1. Full amount enters the Safe (320 + 150 = 470)
    expect(erp.mainCashBox, 470);
    // 2. The fixed asset is deleted
    expect(
      erp.openingEntry.fixedAssets.any((item) => item.id == asset2.id),
      isFalse,
    );
    // 3. Subtraction (200 - 150 = 50) goes to Losses in Income Summary
    expect(erp.assetSaleLossesOf(AppCurrency.usd), 50);
    expect(erp.assetSaleGainsOf(AppCurrency.usd), 20); // Still 20 from previous
    // 4. Capital balance remains unaffected
    expect(erp.totalCurrentEquity, initialCapital);

    // --- Scenario 3: Sale price EQUAL to registered price ---
    final purchased3 = erp.purchaseFixedAsset(
      category: 'أثاث',
      name: 'طاولة مكتب',
      amount: 80,
      currency: AppCurrency.usd,
      description: 'طاولة خشبية',
    );
    expect(purchased3, isTrue);
    expect(erp.mainCashBox, 390); // 470 - 80 = 390

    final asset3 = erp.openingEntry.fixedAssets.firstWhere(
      (item) => item.name == 'طاولة مكتب',
    );
    final soldEqual = erp.sellFixedAsset(
      assetId: asset3.id,
      saleAmount: 80, // 80 == 80 -> Gain = 0, Loss = 0
      currency: AppCurrency.usd,
    );

    expect(soldEqual, isTrue);
    // 1. Full amount is transferred to the Safe (390 + 80 = 470)
    expect(erp.mainCashBox, 470);
    // 2. The fixed asset is deleted from the items
    expect(
      erp.openingEntry.fixedAssets.any((item) => item.id == asset3.id),
      isFalse,
    );
    // 3. No new gains or losses
    expect(erp.assetSaleGainsOf(AppCurrency.usd), 20);
    expect(erp.assetSaleLossesOf(AppCurrency.usd), 50);
    // 4. Capital balance is not affected
    expect(erp.totalCurrentEquity, initialCapital);
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
        advancePayment: 100.0,
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
    final workshopCashTab = find.text('8. فواتير المبيعات النقدية');
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
          advancePayment: 90,
        ),
      );

      expect(erp.totalFactoryRevenueOf(AppCurrency.usd) - startingSales, 90);
      expect(
        erp.factorySalesDiscountOf(AppCurrency.usd) - startingDiscount,
        10,
      );
      expect(erp.netOperatingProfit - startingProfit, 90);
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
    expect(find.text('7. مرتجعات ومسموحات المبيعات'), findsOneWidget);
  });

  test('updateBlockType cascades changes to blocks and meter types', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();

    erp.addBlockType(
      BlockTypeModel(
        id: 'bt_test',
        typeName: 'مرمر يوناني',
        grade: 'درجة أولى',
        isGranite: false,
      ),
    );
    erp.addMeterType(
      MeterTypeModel(
        id: 'meter_bt_test',
        typeName: 'مرمر يوناني',
        grade: 'درجة أولى',
        thicknessCm: 0.0,
        category: 'متر مربع',
        isGranite: false,
      ),
    );
    erp.factoryBlocks.add(
      FactoryBlockModel(
        id: 'block_test',
        blockCode: 'BLK-001',
        typeName: 'مرمر يوناني',
        grade: 'درجة أولى',
        supplierId: 'sup1',
        supplierName: 'مورد الرخام',
        weightTons: 10,
        tonCost: 100,
        tonSellingPrice: 0,
        isGranite: false,
      ),
    );

    erp.updateBlockType(
      BlockTypeModel(
        id: 'bt_test',
        typeName: 'مرمر يوناني معدل',
        grade: 'نخب أول ممتاز',
        isGranite: true,
      ),
    );

    final updatedType = erp.blockTypes.firstWhere((b) => b.id == 'bt_test');
    expect(updatedType.typeName, 'مرمر يوناني معدل');
    expect(updatedType.grade, 'نخب أول ممتاز');
    expect(updatedType.isGranite, isTrue);

    final updatedBlock = erp.factoryBlocks.firstWhere((b) => b.id == 'block_test');
    expect(updatedBlock.typeName, 'مرمر يوناني معدل');
    expect(updatedBlock.grade, 'نخب أول ممتاز');
    expect(updatedBlock.isGranite, isTrue);

    final updatedMeterType = erp.meterTypes.firstWhere((m) => m.id == 'meter_bt_test');
    expect(updatedMeterType.typeName, 'مرمر يوناني معدل');
    expect(updatedMeterType.grade, 'نخب أول ممتاز');
    expect(updatedMeterType.isGranite, isTrue);
  });

  test('Opening meters inventory allows custom manual thickness and posts properly', () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();

    erp.addBlockType(
      BlockTypeModel(
        id: 'type_ordo',
        typeName: 'بيج أوردو',
        grade: 'نخب أول',
        isGranite: false,
      ),
    );

    // Create an opening meter item with custom 3.5cm thickness
    erp.openingEntry.openingStock.add(
      OpeningStockItemModel(
        id: 'open_meter_1',
        category: 'أمتار المصنع',
        typeName: 'بيج أوردو',
        typeId: 'type_ordo',
        grade: 'نخب أول',
        thicknessCm: 3.5,
        supplierName: '',
        quantity: 50,
        unitPrice: 25,
        sellingPrice: 40,
        currency: AppCurrency.usd,
      ),
    );

    erp.lockOpeningEntry();

    final addedStock = erp.factoryWarehouse.firstWhere((item) => item.id == 'open_meter_1');
    expect(addedStock.typeName, 'بيج أوردو');
    expect(addedStock.thicknessCm, 3.5);
    expect(addedStock.category, 'متر مربع');
    expect(addedStock.availableQty, 50);
    expect(addedStock.netCostPerUnit, 25);
    expect(addedStock.recommendedSalePrice, 40);
  });

  test(
      'Single-Partner Capital Injection: recalculates capital, partner share, ownership dilution, safe balance and transaction log',
      () {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();

    // Setup initial test scenario:
    // Partner A: $50,000 (50%), Partner B: $50,000 (50%). Total = $100,000.
    erp.partners = [
      PartnerModel(
        id: 'p_a',
        name: 'Partner A',
        ratio: 0.50,
        injectedCapital: 50000.0,
      ),
      PartnerModel(
        id: 'p_b',
        name: 'Partner B',
        ratio: 0.50,
        injectedCapital: 50000.0,
      ),
    ];
    erp.mainCashBox = 10000.0;

    // Verify Initial State
    expect(erp.totalCapitalUsd, 100000.0);
    expect(erp.partners[0].injectedCapital, 50000.0);
    expect(erp.partners[1].injectedCapital, 50000.0);
    expect(erp.partners[0].ratio, 0.50);
    expect(erp.partners[1].ratio, 0.50);

    // Action: Inject $50,000 for Partner A
    final success = erp.injectPartnerCapital(
      partnerId: 'p_a',
      amount: 50000.0,
      currency: AppCurrency.usd,
      destinationSafe: 'main',
      notes: 'Test Capital Injection',
    );

    expect(success, isTrue);

    // Expected Output Verification:
    // 1. Total Capital = $150,000
    expect(erp.totalCapitalUsd, 150000.0);

    // 2. Partner A Share = $100,000 -> 66.67%
    final partnerA = erp.partners.firstWhere((p) => p.id == 'p_a');
    expect(partnerA.injectedCapital, 100000.0);
    expect((partnerA.ratio * 100).toStringAsFixed(2), '66.67');

    // 3. Partner B Share = $50,000 -> 33.33% (Dilution)
    final partnerB = erp.partners.firstWhere((p) => p.id == 'p_b');
    expect(partnerB.injectedCapital, 50000.0);
    expect((partnerB.ratio * 100).toStringAsFixed(2), '33.33');

    // 4. Exact 100% sum validation rule
    expect(
      (double.parse((partnerA.ratio * 100).toStringAsFixed(2)) +
              double.parse((partnerB.ratio * 100).toStringAsFixed(2)))
          .toStringAsFixed(2),
      '100.00',
    );

    // 5. Main Safe increased by $50,000 (10,000 + 50,000 = 60,000)
    expect(erp.mainCashBox, 60000.0);

    // 6. Transaction Logging
    expect(erp.capitalInjections.isNotEmpty, isTrue);
    final log = erp.capitalInjections.last;
    expect(log.partnerName, 'Partner A');
    expect(log.amount, 50000.0);
    expect(log.currency, AppCurrency.usd);
    expect(log.destinationSafe, 'main');
    expect(
      log.logEntryTitle,
      'Capital Injection - Partner: Partner A - Amount: 50000 \$',
    );
  });
}

