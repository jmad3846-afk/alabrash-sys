import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Factory Returns Logic (مرتجعات المصنع)', () {
    test('Block purchase return routes strictly in tons to Block Stock (مخزون مصنع)', () {
      final erp = ERPProvider();
      final supplier = erp.suppliers.first;

      // Add a block purchase invoice (Tons)
      final invoice = FactoryInvoiceModel(
        id: 'fac-pur-block-1',
        invoiceNo: 'PUR-BLK-101',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'fb_test_1',
            description: 'كتلة رخام كاردينال',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            quantity: 15.0, // 15 Tons
            unitPrice: 120.0,
            unitCost: 120.0,
            itemCategory: 'block',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Ensure block is in stock
      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'fb_test_1',
          blockCode: 'BLK-TEST-1',
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 15.0,
          tonCost: 120.0,
          tonSellingPrice: 150.0,
        ),
      );

      final startingBlocks = erp.factoryBlocks
          .where((b) => b.typeName == 'رخام كاردينال' && b.supplierId == supplier.id)
          .fold<double>(0.0, (sum, b) => sum + b.weightTons);

      // Process purchase return of 5 tons
      final success = erp.addAdjustmentInvoice(
        AdjustmentInvoiceModel(
          id: 'adj-pur-block-1',
          invoiceNo: 'RET-BLK-1',
          module: 'factory',
          kind: 'purchase_return',
          targetInvoiceId: invoice.id,
          targetInvoiceNo: invoice.invoiceNo,
          partyName: supplier.name,
          description: 'إرجاع 5 طن بلوك للمورد',
          amount: 600.0,
          currency: AppCurrency.usd,
          paymentAction: 'تخفيض دين',
          lines: [
            AdjustmentLineModel(
              itemId: 'fb_test_1',
              itemIndex: 0,
              description: 'كتلة رخام كاردينال',
              unit: 'طن',
              quantity: 5.0,
              unitPrice: 120.0,
              amount: 600.0,
            ),
          ],
        ),
      );

      expect(success, isTrue);
      final remainingBlocks = erp.factoryBlocks
          .where((b) => b.typeName == 'رخام كاردينال' && b.supplierId == supplier.id)
          .fold<double>(0.0, (sum, b) => sum + b.weightTons);
      expect(remainingBlocks, closeTo(startingBlocks - 5.0, 0.001));

      // Adjustment invoice record retains native unit 'طن'
      final savedDoc = erp.adjustmentInvoices.firstWhere((a) => a.id == 'adj-pur-block-1');
      expect(savedDoc.lines.first.unit, 'طن');
    });

    test('Approved Dealers sales return routes meters to Factory Warehouse splitting m² vs m³', () {
      final erp = ERPProvider();
      final client = erp.clients.first;

      // Existing warehouse stock: one m² slab and one m³ cube
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'fw_m2_test',
          typeName: 'رخام موغلا تركي',
          grade: 'درجة أولى',
          thicknessCm: 2.0,
          category: 'متر مربع',
          availableQty: 50.0,
          netCostPerUnit: 15.0,
          recommendedSalePrice: 25.0,
        ),
      );
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'fw_m3_test',
          typeName: 'رخام موغلا تركي',
          grade: 'درجة أولى',
          thicknessCm: 20.0,
          category: 'متر مكعب',
          availableQty: 10.0,
          netCostPerUnit: 150.0,
          recommendedSalePrice: 250.0,
        ),
      );

      final startingM2 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_m2_test').availableQty;
      final startingM3 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_m3_test').availableQty;

      // Sales Invoice with 2 items: 1 m² item and 1 m³ item
      final invoice = FactoryInvoiceModel(
        id: 'fac-sale-mixed-1',
        invoiceNo: 'FAC-SALE-101',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'fw_m2_test',
            description: 'رخام موغلا تركي 2سم',
            typeName: 'رخام موغلا تركي',
            grade: 'درجة أولى',
            thicknessCm: 2.0,
            itemCategory: 'meter',
            meterUnit: 'متر مربع',
            quantity: 8.0, // 8 m²
            unitPrice: 25.0,
            unitCost: 15.0,
          ),
          FactoryInvoiceItem(
            itemId: 'fw_m3_test',
            description: 'كتل مقصوصة موغلا تركي 20سم',
            typeName: 'رخام موغلا تركي',
            grade: 'درجة أولى',
            thicknessCm: 20.0,
            itemCategory: 'meter',
            meterUnit: 'متر مكعب',
            quantity: 3.0, // 3 m³
            unitPrice: 250.0,
            unitCost: 150.0,
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Return 2 m² from item 0 and 1 m³ from item 1
      final success = erp.addAdjustmentInvoice(
        AdjustmentInvoiceModel(
          id: 'adj-sale-mixed-1',
          invoiceNo: 'RET-FAC-1',
          module: 'factory',
          kind: 'sales_return',
          targetInvoiceId: invoice.id,
          targetInvoiceNo: invoice.invoiceNo,
          partyName: client.name,
          description: 'مرتجع مبيعات معتمدين متنوع',
          amount: (2.0 * 25.0) + (1.0 * 250.0), // 50 + 250 = 300
          currency: AppCurrency.usd,
          paymentAction: 'تخفيض دين',
          lines: [
            AdjustmentLineModel(
              itemId: 'fw_m2_test',
              itemIndex: 0,
              description: 'رخام موغلا تركي 2سم',
              unit: 'متر مربع',
              quantity: 2.0,
              unitPrice: 25.0,
              amount: 50.0,
            ),
            AdjustmentLineModel(
              itemId: 'fw_m3_test',
              itemIndex: 1,
              description: 'كتل مقصوصة موغلا تركي 20سم',
              unit: 'متر مكعب',
              quantity: 1.0,
              unitPrice: 250.0,
              amount: 250.0,
            ),
          ],
        ),
      );

      expect(success, isTrue);

      final updatedM2 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_m2_test');
      final updatedM3 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_m3_test');

      // Verify routing into exact sub-sections without cross contamination
      expect(updatedM2.availableQty, closeTo(startingM2 + 2.0, 0.001));
      expect(updatedM2.category, 'متر مربع');

      expect(updatedM3.availableQty, closeTo(startingM3 + 1.0, 0.001));
      expect(updatedM3.category, 'متر مكعب');

      // Check stored line units
      final savedDoc = erp.adjustmentInvoices.firstWhere((a) => a.id == 'adj-sale-mixed-1');
      expect(savedDoc.lines[0].unit, 'متر مربع');
      expect(savedDoc.lines[1].unit, 'متر مكعب');
    });

    test('Approved Dealers sales return strictly resolves units to m² or m³ (never Ton) even with legacy block category and routes to Factory Warehouse', () {
      final erp = ERPProvider();
      final client = erp.clients.first;

      // Existing warehouse stock
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'fw_legacy_m2',
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          thicknessCm: 2.0,
          category: 'متر مربع',
          availableQty: 100.0,
          netCostPerUnit: 14.5,
          recommendedSalePrice: 22.0,
        ),
      );
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'fw_legacy_m3',
          typeName: 'رخام كاردينال مكعب',
          grade: 'درجة أولى',
          thicknessCm: 10.0,
          category: 'متر مكعب',
          availableQty: 25.0,
          netCostPerUnit: 80.0,
          recommendedSalePrice: 120.0,
        ),
      );

      final startingM2 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_legacy_m2').availableQty;
      final startingM3 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_legacy_m3').availableQty;
      final startingBlocksCount = erp.factoryBlocks.length;

      // Approved dealer invoice where items have legacy itemCategory: 'block' or default
      final m2Item = FactoryInvoiceItem(
        itemId: 'fw_legacy_m2',
        description: 'رخام كاردينال 2سم ألواح',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        lengthCm: 200,
        widthCm: 100,
        quantity: 10, // 10 slabs = 20 m²
        unitPrice: 22.0,
        unitCost: 14.5,
        itemCategory: 'block', // legacy default!
        thicknessCm: 2.0,
        meterUnit: 'متر مربع',
      );

      final m3Item = FactoryInvoiceItem(
        itemId: 'fw_legacy_m3',
        description: 'رخام كاردينال مكعب 10سم',
        typeName: 'رخام كاردينال مكعب',
        grade: 'درجة أولى',
        lengthCm: 100,
        widthCm: 100,
        heightCm: 10,
        quantity: 5,
        unitPrice: 120.0,
        unitCost: 80.0,
        itemCategory: 'block', // legacy default!
        thicknessCm: 10.0,
        meterUnit: 'متر مكعب',
      );

      final invoice = FactoryInvoiceModel(
        id: 'fac-dealer-sale-legacy',
        invoiceNo: 'FAC-DEALER-2026',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        currency: AppCurrency.usd,
        items: [m2Item, m3Item],
      );
      erp.factoryInvoices.add(invoice);

      // Verify factoryLineUnit resolution
      expect(erp.factoryLineUnit(m2Item, parent: invoice), 'متر مربع');
      expect(erp.factoryLineUnit(m3Item, parent: invoice), 'متر مكعب');
      expect(erp.factoryLineUnit(m2Item, parent: invoice), isNot('طن'));
      expect(erp.factoryLineUnit(m3Item, parent: invoice), isNot('طن'));

      // Process a sales return
      final success = erp.addAdjustmentInvoice(
        AdjustmentInvoiceModel(
          id: 'ret-fac-dealer-1',
          invoiceNo: 'RET-FAC-DEALER-1',
          module: 'factory',
          kind: 'sales_return',
          targetInvoiceId: invoice.id,
          targetInvoiceNo: invoice.invoiceNo,
          partyName: client.name,
          description: 'مرتجع معتمدين',
          amount: (2 * (2.0 * 22.0)) + (1 * (0.1 * 120.0)),
          currency: AppCurrency.usd,
          paymentAction: 'تخفيض دين',
          lines: [
            AdjustmentLineModel(
              itemId: 'fw_legacy_m2',
              itemIndex: 0,
              description: 'رخام كاردينال 2سم ألواح',
              unit: erp.factoryLineUnit(m2Item, parent: invoice),
              quantity: 2.0, // 2 slabs = 4 m²
              unitPrice: 44.0,
              amount: 88.0,
            ),
            AdjustmentLineModel(
              itemId: 'fw_legacy_m3',
              itemIndex: 1,
              description: 'رخام كاردينال مكعب 10سم',
              unit: erp.factoryLineUnit(m3Item, parent: invoice),
              quantity: 1.0, // 1 cube = 0.1 m³
              unitPrice: 12.0,
              amount: 12.0,
            ),
          ],
        ),
      );

      expect(success, isTrue);

      // Verify returned items were routed strictly to Factory Warehouse, NOT Factory Blocks
      expect(erp.factoryBlocks.length, startingBlocksCount); // No block was added!
      final updatedM2 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_legacy_m2');
      final updatedM3 = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_legacy_m3');
      expect(updatedM2.availableQty, closeTo(startingM2 + 4.0, 0.001)); // 2 slabs * 2.0 m²
      expect(updatedM3.availableQty, closeTo(startingM3 + 0.1, 0.001)); // 1 cube * 0.1 m³

      // Verify the saved return invoice line units are strictly m² and m³
      final savedDoc = erp.adjustmentInvoices.firstWhere((a) => a.id == 'ret-fac-dealer-1');
      expect(savedDoc.lines[0].unit, 'متر مربع');
      expect(savedDoc.lines[1].unit, 'متر مكعب');
      expect(savedDoc.lines[0].unit, isNot('طن'));
      expect(savedDoc.lines[1].unit, isNot('طن'));
    });
  });

  group('Workshop Returns Logic (مرتجعات المعمل - Multi-Department)', () {
    test('Inspects and routes each mixed line item independently to its designated department and native unit', () {
      final erp = ERPProvider();
      final client = erp.clients.first;

      // 1. Raw Materials in workshopStock (m² and m³)
      erp.workshopStock.add(
        WorkshopStockModel(
          id: 'ws_raw_m2',
          typeName: 'ألواح بيانكو خام',
          grade: 'درجة أولى',
          thicknessCm: 2.0,
          category: 'متر مربع',
          availableQty: 40.0,
          netCostPerUnit: 20.0,
          recommendedSalePrice: 35.0,
        ),
      );
      erp.workshopStock.add(
        WorkshopStockModel(
          id: 'ws_raw_m3',
          typeName: 'كتل بيانكو خام',
          grade: 'درجة أولى',
          thicknessCm: 15.0,
          category: 'متر مكعب',
          availableQty: 8.0,
          netCostPerUnit: 180.0,
          recommendedSalePrice: 280.0,
        ),
      );

      // 2. Simple Tailoring in simpleTailorings (m²)
      erp.simpleTailorings.add(
        WorkshopTailoringModel(
          id: 'tl_simple_1',
          name: 'درج بيانكو مشطوف',
          complexity: 'بسيط',
          rawMaterialDescription: 'ألواح بيانكو خام',
          quantity: 25.0, // m²
          materialNetCost: 22.0,
          unitCategory: 'متر مربع',
          sellingPrice: 40.0,
        ),
      );

      // 3. Complex Tailoring in complexTailorings (Pieces)
      erp.complexTailorings.add(
        WorkshopTailoringModel(
          id: 'tl_complex_1',
          name: 'مغسلة حجرية منحوتة',
          complexity: 'معقد',
          rawMaterialDescription: 'كتلة بيانكو',
          quantity: 4.0, // 4 Pieces
          materialNetCost: 150.0,
          unitCategory: 'قطعة',
          sellingPrice: 320.0,
        ),
      );

      // 4. Surplus Parts in scrapItems
      erp.scrapItems.add(
        ScrapItemModel(
          id: 'sc_surplus_1',
          description: 'قطعة زائدة بيانكو 120×40',
          baseCost: 12.0,
          sellingPrice: 25.0,
          isSold: true, // currently sold
          currency: AppCurrency.usd,
        ),
      );

      // Multi-item Workshop Invoice containing:
      // Line 0: Workshop raw material (m²)
      // Line 1: Workshop raw material (m³)
      // Line 2: Simple tailoring (m²)
      // Line 3: Complex tailoring (pieces)
      // Line 4: Surplus part (isSold was true)
      final invoice = WorkshopInvoiceModel(
        id: 'wrk-inv-mixed-1',
        invoiceNo: 'WRK-2026-MIX',
        date: DateTime.now(),
        clientName: client.name,
        sourceType: 'مصادر متعددة',
        agreedPrice: 0.0, // calculated from items
        depositDeducted: 0.0,
        cashPaidNow: 0.0,
        netCost: 0.0,
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'wi_1',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: 'ws_raw_m2',
            description: 'ألواح بيانكو خام',
            quantity: 5.0, // 5 m²
            unitCategory: 'متر مربع',
            agreedPrice: 175.0,
            netCost: 100.0,
          ),
          WorkshopInvoiceItem(
            id: 'wi_2',
            sourceType: 'بيع مواد خام من المعمل',
            sourceId: 'ws_raw_m3',
            description: 'كتل بيانكو خام',
            quantity: 2.0, // 2 m³
            unitCategory: 'متر مكعب',
            agreedPrice: 560.0,
            netCost: 360.0,
          ),
          WorkshopInvoiceItem(
            id: 'wi_3',
            sourceType: 'بيع خياطة بسيطة',
            sourceId: 'tl_simple_1',
            description: 'درج بيانكو مشطوف',
            quantity: 6.0, // 6 m²
            unitCategory: 'متر مربع',
            agreedPrice: 240.0,
            netCost: 132.0,
          ),
          WorkshopInvoiceItem(
            id: 'wi_4',
            sourceType: 'بيع خياطة معقدة',
            sourceId: 'tl_complex_1',
            description: 'مغسلة حجرية منحوتة',
            quantity: 2.0, // 2 Pieces
            unitCategory: 'قطعة',
            agreedPrice: 640.0,
            netCost: 300.0,
          ),
          WorkshopInvoiceItem(
            id: 'wi_5',
            sourceType: 'بيع قطع إضافية',
            sourceId: 'sc_surplus_1',
            description: 'قطعة زائدة بيانكو 120×40',
            quantity: 1.0,
            unitCategory: 'قطعة',
            agreedPrice: 25.0,
            netCost: 12.0,
          ),
        ],
      );
      erp.workshopInvoices.add(invoice);

      // Snapshot starting state
      final startRawM2 = erp.workshopStock.firstWhere((w) => w.id == 'ws_raw_m2').availableQty;
      final startRawM3 = erp.workshopStock.firstWhere((w) => w.id == 'ws_raw_m3').availableQty;
      final startSimple = erp.simpleTailorings.firstWhere((t) => t.id == 'tl_simple_1').quantity;
      final startComplex = erp.complexTailorings.firstWhere((t) => t.id == 'tl_complex_1').quantity;
      final startSurplusSold = erp.scrapItems.firstWhere((s) => s.id == 'sc_surplus_1').isSold;
      expect(startSurplusSold, isTrue);

      // Now create a multi-item return invoice returning:
      // 2 m² raw material (ws_raw_m2)
      // 1 m³ raw material (ws_raw_m3)
      // 3 m² simple tailoring (tl_simple_1)
      // 1 Piece complex tailoring (tl_complex_1)
      // 1 surplus item (sc_surplus_1)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-wrk-mixed-doc-1',
        invoiceNo: 'RET-WRK-001',
        module: 'workshop',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'مرتجع معمل متعدد الأقسام والأصناف',
        amount: (2.0 * 35.0) + (1.0 * 280.0) + (3.0 * 40.0) + (1.0 * 320.0) + 25.0,
        currency: AppCurrency.usd,
        paymentAction: 'تخفيض دين',
        lines: [
          AdjustmentLineModel(
            itemId: 'ws_raw_m2',
            itemIndex: 0,
            description: 'ألواح بيانكو خام',
            unit: 'متر مربع',
            quantity: 2.0,
            unitPrice: 35.0,
            amount: 70.0,
            sourceType: 'بيع مواد خام من المعمل',
          ),
          AdjustmentLineModel(
            itemId: 'ws_raw_m3',
            itemIndex: 1,
            description: 'كتل بيانكو خام',
            unit: 'متر مكعب',
            quantity: 1.0,
            unitPrice: 280.0,
            amount: 280.0,
            sourceType: 'بيع مواد خام من المعمل',
          ),
          AdjustmentLineModel(
            itemId: 'tl_simple_1',
            itemIndex: 2,
            description: 'درج بيانكو مشطوف',
            unit: 'متر مربع',
            quantity: 3.0,
            unitPrice: 40.0,
            amount: 120.0,
            sourceType: 'بيع خياطة بسيطة',
          ),
          AdjustmentLineModel(
            itemId: 'tl_complex_1',
            itemIndex: 3,
            description: 'مغسلة حجرية منحوتة',
            unit: 'قطعة',
            quantity: 1.0, // Strictly piece
            unitPrice: 320.0,
            amount: 320.0,
            sourceType: 'بيع خياطة معقدة',
          ),
          AdjustmentLineModel(
            itemId: 'sc_surplus_1',
            itemIndex: 4,
            description: 'قطعة زائدة بيانكو 120×40',
            unit: 'قطعة',
            quantity: 1.0,
            unitPrice: 25.0,
            amount: 25.0,
            sourceType: 'بيع قطع إضافية',
          ),
        ],
      );

      final posted = erp.addAdjustmentInvoice(returnDoc);
      expect(posted, isTrue);

      // 1. Verify Workshop Raw Materials (m² vs m³ stock)
      final endRawM2 = erp.workshopStock.firstWhere((w) => w.id == 'ws_raw_m2');
      final endRawM3 = erp.workshopStock.firstWhere((w) => w.id == 'ws_raw_m3');
      expect(endRawM2.availableQty, closeTo(startRawM2 + 2.0, 0.001));
      expect(endRawM2.category, 'متر مربع');
      expect(endRawM3.availableQty, closeTo(startRawM3 + 1.0, 0.001));
      expect(endRawM3.category, 'متر مكعب');

      // 2. Verify Simple Details returned strictly to simpleTailorings (m²)
      final endSimple = erp.simpleTailorings.firstWhere((t) => t.id == 'tl_simple_1');
      expect(endSimple.quantity, closeTo(startSimple + 3.0, 0.001));
      expect(endSimple.unitCategory, 'متر مربع');

      // 3. Verify Complex Details returned strictly by piece to complexTailorings
      final endComplex = erp.complexTailorings.firstWhere((t) => t.id == 'tl_complex_1');
      expect(endComplex.quantity, closeTo(startComplex + 1.0, 0.001));
      expect(endComplex.unitCategory, 'قطعة');

      // 4. Verify Surplus Part returned to scrapItems with isSold restored to false
      final endSurplus = erp.scrapItems.firstWhere((s) => s.id == 'sc_surplus_1');
      expect(endSurplus.isSold, isFalse);

      // 5. Verify the return invoice lines recorded exact units and source types
      final savedReturn = erp.adjustmentInvoices.firstWhere((a) => a.id == 'ret-wrk-mixed-doc-1');
      expect(savedReturn.lines.length, 5);
      expect(savedReturn.lines[0].unit, 'متر مربع');
      expect(savedReturn.lines[1].unit, 'متر مكعب');
      expect(savedReturn.lines[2].unit, 'متر مربع');
      expect(savedReturn.lines[3].unit, 'قطعة');
      expect(savedReturn.lines[4].unit, 'قطعة');
    });
  });
}
