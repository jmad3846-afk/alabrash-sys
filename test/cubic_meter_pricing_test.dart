import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Automated Cubic Meter (m³) Dimension & Pricing Logic Tests', () {
    late ERPProvider erp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      erp = ERPProvider();

      // Factory warehouse stock:
      // Material A (رخام تركي) available in both m² and m³
      erp.factoryWarehouse = [
        FactoryWarehouseModel(
          id: 'fw_1',
          typeName: 'رخام تركي أبيض',
          grade: 'نخب أول',
          thicknessCm: 3.0,
          category: 'متر مربع',
          availableQty: 120.0,
          netCostPerUnit: 25.0,
          recommendedSalePrice: 35.0,
          isGranite: false,
        ),
        FactoryWarehouseModel(
          id: 'fw_2_cube',
          typeName: 'رخام تركي أبيض',
          grade: 'نخب أول',
          thicknessCm: 3.0,
          category: 'متر مكعب',
          availableQty: 10.0,
          netCostPerUnit: 600.0,
          recommendedSalePrice: 900.0,
          isGranite: false,
        ),
        // Material B (غرانيت أسود) thickness 2.5cm
        FactoryWarehouseModel(
          id: 'fw_3',
          typeName: 'غرانيت أسود أسواني',
          grade: 'نخب ممتاز',
          thicknessCm: 2.5,
          category: 'متر مربع',
          availableQty: 80.0,
          netCostPerUnit: 40.0,
          recommendedSalePrice: 55.0,
          isGranite: true,
        ),
        FactoryWarehouseModel(
          id: 'fw_4_cube',
          typeName: 'غرانيت أسود أسواني',
          grade: 'نخب ممتاز',
          thicknessCm: 2.5,
          category: 'متر مكعب',
          availableQty: 5.0,
          netCostPerUnit: 1200.0,
          recommendedSalePrice: 1800.0,
          isGranite: true,
        ),
      ];

      // Workshop stock items:
      erp.workshopStock = [
        WorkshopStockModel(
          id: 'ws_1',
          typeName: 'رخام تركي أبيض',
          grade: 'نخب أول',
          thicknessCm: 3.0,
          category: 'متر مربع',
          availableQty: 50.0,
          netCostPerUnit: 28.0,
          recommendedSalePrice: 38.0,
          isGranite: false,
        ),
        WorkshopStockModel(
          id: 'ws_2_cube',
          typeName: 'رخام تركي أبيض',
          grade: 'نخب أول',
          thicknessCm: 3.0,
          category: 'متر مكعب',
          availableQty: 8.0,
          netCostPerUnit: 620.0,
          recommendedSalePrice: 950.0,
          isGranite: false,
        ),
        WorkshopStockModel(
          id: 'ws_3',
          typeName: 'رخام روزا برتغالي',
          grade: 'نخب تجاري',
          thicknessCm: 4.0,
          category: 'متر مربع',
          availableQty: 30.0,
          netCostPerUnit: 35.0,
          recommendedSalePrice: 50.0,
          isGranite: false,
        ),
        WorkshopStockModel(
          id: 'ws_4_cube',
          typeName: 'رخام روزا برتغالي',
          grade: 'نخب تجاري',
          thicknessCm: 4.0,
          category: 'متر مكعب',
          availableQty: 4.0,
          netCostPerUnit: 800.0,
          recommendedSalePrice: 1200.0,
          isGranite: false,
        ),
      ];
    });

    test('1. Factory Warehouse: Automated Height = Thickness and Unit Price = Cubic Selling Price', () {
      final material = erp.factoryWarehouse.firstWhere((w) => w.id == 'fw_1');
      expect(material.thicknessCm, 3.0);

      // Lookup cubic selling price for material
      double lookupFactoryCubicSellingPrice(FactoryWarehouseModel wh) {
        if (wh.category == 'متر مكعب' && wh.recommendedSalePrice > 0) return wh.recommendedSalePrice;
        final matches = erp.factoryWarehouse.where((w) => w.typeName.trim() == wh.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0).toList();
        if (matches.isNotEmpty) return matches.first.recommendedSalePrice;
        return wh.recommendedSalePrice;
      }

      final cubicPrice = lookupFactoryCubicSellingPrice(material);
      expect(cubicPrice, 900.0);

      // Automated Height Population: Height = Thickness
      final autoHeight = material.thicknessCm;
      expect(autoHeight, 3.0);

      // Dimensions: Length = 200cm, Width = 100cm, Height = Thickness = 3cm, Quantity = 5 pieces
      const lengthCm = 200.0;
      const widthCm = 100.0;
      final heightCm = autoHeight;
      const quantity = 5.0;

      // Formula: Total Volume (m³) = (Length/100) * (Width/100) * (Height/100) * Quantity
      // (200/100) * (100/100) * (3/100) * 5 = 2.0 * 1.0 * 0.03 * 5 = 0.3 m³
      final expectedVolume = (lengthCm / 100.0) * (widthCm / 100.0) * (heightCm / 100.0) * quantity;
      expect(expectedVolume, closeTo(0.3, 0.0001));

      // Formula: Line Total = Total Volume (m³) * Cubic Meter Selling Price
      // 0.3 * 900 = 270.0
      final expectedLineTotal = expectedVolume * cubicPrice;
      expect(expectedLineTotal, closeTo(270.0, 0.0001));

      // Build FactoryInvoiceItem with meterUnit = 'متر مكعب'
      final item = FactoryInvoiceItem(
        itemId: material.id,
        typeName: material.typeName,
        grade: material.grade,
        description: '${material.typeName} ${material.grade}',
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
        thicknessCm: heightCm,
        quantity: quantity,
        unitPrice: cubicPrice,
        unitCost: material.netCostPerUnit,
        isGranite: material.isGranite,
        meterUnit: 'متر مكعب',
      );

      expect(item.isCubicMeter, isTrue);
      expect(item.calculatedArea, closeTo(0.3, 0.0001));
      expect(item.grandTotal, closeTo(270.0, 0.0001));
    });

    test('2. Workshop Warehouse: Automated Height = Thickness and Unit Price = Cubic Selling Price', () {
      final stockItem = erp.workshopStock.firstWhere((w) => w.id == 'ws_3');
      expect(stockItem.thicknessCm, 4.0);

      // Workshop cubic selling price lookup
      double getWorkshopCubicSellingPrice(ERPProvider erp, WorkshopStockModel w) {
        if (w.category == 'متر مكعب' && w.recommendedSalePrice > 0) return w.recommendedSalePrice;
        final exactWorkshop = erp.workshopStock.where((s) => s.typeName.trim() == w.typeName.trim() && s.grade.trim() == w.grade.trim() && s.category == 'متر مكعب' && s.recommendedSalePrice > 0).toList();
        if (exactWorkshop.isNotEmpty) return exactWorkshop.first.recommendedSalePrice;
        final matches = erp.workshopStock.where((s) => s.typeName.trim() == w.typeName.trim() && s.category == 'متر مكعب' && s.recommendedSalePrice > 0).toList();
        if (matches.isNotEmpty) return matches.first.recommendedSalePrice;
        final facMatches = erp.factoryWarehouse.where((f) => f.typeName.trim() == w.typeName.trim() && f.category == 'متر مكعب' && f.recommendedSalePrice > 0).toList();
        if (facMatches.isNotEmpty) return facMatches.first.recommendedSalePrice;
        return w.recommendedSalePrice > 0 ? w.recommendedSalePrice : (w.netCostPerUnit * 1.3);
      }

      final cubicPrice = getWorkshopCubicSellingPrice(erp, stockItem);
      expect(cubicPrice, 1200.0);

      // Automated Height Population: Height = Thickness
      final autoHeight = stockItem.thicknessCm;
      expect(autoHeight, 4.0);

      // Dimensions: Length = 150cm, Width = 80cm, Height = Thickness = 4cm, Count = 10 pieces
      const lengthCm = 150.0;
      const widthCm = 80.0;
      final heightCm = autoHeight;
      const count = 10.0;

      // Formula: Total Volume (m³) = (150/100) * (80/100) * (4/100) * 10
      // = 1.5 * 0.8 * 0.04 * 10 = 0.48 m³
      final expectedVolume = (lengthCm / 100.0) * (widthCm / 100.0) * (heightCm / 100.0) * count;
      expect(expectedVolume, closeTo(0.48, 0.0001));

      // Formula: Line Total = 0.48 * 1200 = 576.0
      final expectedLineTotal = expectedVolume * cubicPrice;
      expect(expectedLineTotal, closeTo(576.0, 0.0001));

      // Build WorkshopInvoiceItem with unitCategory = 'متر مكعب'
      final item = WorkshopInvoiceItem(
        id: 'wii_1',
        sourceType: 'بيع مواد خام من المعمل',
        sourceId: stockItem.id,
        description: '${stockItem.typeName} ${stockItem.grade}',
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
        quantity: count,
        unitCategory: 'متر مكعب',
        unitPrice: cubicPrice,
        agreedPrice: expectedLineTotal,
        netCost: expectedVolume * stockItem.netCostPerUnit,
      );

      expect(item.isCubicMeter, isTrue);
      expect(item.thicknessCm, 4.0);
      expect(item.calculatedVolume, closeTo(0.48, 0.0001));
      expect(item.calculatedArea, closeTo(0.48, 0.0001));
      expect(item.grandTotal, closeTo(576.0, 0.0001));
    });

    test('3. Strict volume calculation applied even when thickness/height <= 5cm', () {
      // Prior implementation defaulted to square meters when height <= 5cm.
      // With our fix, when meterUnit/unitCategory == 'متر مكعب', volume calculation is strictly applied!
      final factoryItemThin = FactoryInvoiceItem(
        itemId: 'fw_thin',
        typeName: 'مرمر أبيض',
        grade: 'نخب أول',
        description: 'مرمر أبيض 2سم',
        lengthCm: 200.0,
        widthCm: 100.0,
        heightCm: 2.0, // 2cm <= 5cm
        thicknessCm: 2.0,
        quantity: 1.0,
        unitPrice: 1000.0,
        unitCost: 600.0,
        meterUnit: 'متر مكعب',
      );

      // (200/100) * (100/100) * (2/100) * 1 = 2.0 * 1.0 * 0.02 * 1 = 0.04 m³
      expect(factoryItemThin.isCubicMeter, isTrue);
      expect(factoryItemThin.calculatedArea, closeTo(0.04, 0.0001));
      expect(factoryItemThin.grandTotal, closeTo(40.0, 0.0001)); // 0.04 * 1000 = 40.0

      final workshopItemThin = WorkshopInvoiceItem(
        id: 'wii_thin',
        sourceType: 'بيع مواد خام من المعمل',
        description: 'مرمر أبيض 2سم',
        lengthCm: 200.0,
        widthCm: 100.0,
        heightCm: 2.0, // 2cm <= 5cm
        quantity: 1.0,
        unitCategory: 'متر مكعب',
        unitPrice: 1000.0,
        agreedPrice: 40.0,
      );

      expect(workshopItemThin.isCubicMeter, isTrue);
      expect(workshopItemThin.calculatedVolume, closeTo(0.04, 0.0001));
      expect(workshopItemThin.calculatedArea, closeTo(0.04, 0.0001));
    });

    test('4. Dynamic switching: Switching draft item unit from m² to m³ updates thickness, cubic price and line total', () {
      final stock = erp.workshopStock.firstWhere((w) => w.id == 'ws_1');
      // Initially, m² item
      var item = WorkshopInvoiceItem(
        id: 'wii_switch',
        sourceType: 'بيع مواد خام من المعمل',
        sourceId: stock.id,
        description: '${stock.typeName} ${stock.grade}',
        lengthCm: 250.0,
        widthCm: 120.0,
        heightCm: 0.0,
        quantity: 3.0, // 3 pieces: (2.5 * 1.2) * 3 = 9.0 m²
        unitCategory: 'متر مربع',
        unitPrice: stock.recommendedSalePrice, // 38.0
        agreedPrice: 9.0 * 38.0, // 342.0
      );

      expect(item.isCubicMeter, isFalse);
      expect(item.agreedPrice, 342.0);

      // Now simulate user switching unit type to 'متر مكعب' in edit modal:
      // 1. Height automatically populates with predefined thickness (3.0 cm)
      final autoHeight = stock.thicknessCm;
      expect(autoHeight, 3.0);

      // 2. Unit price automatically populates with Cubic Meter Selling Price (950.0)
      final cubicMatches = erp.workshopStock.where((s) => s.typeName == stock.typeName && s.category == 'متر مكعب').toList();
      final cubicPrice = cubicMatches.first.recommendedSalePrice;
      expect(cubicPrice, 950.0);

      // 3. Recalculate Volume and Line Total:
      // (250/100) * (120/100) * (3/100) * 3 = 2.5 * 1.2 * 0.03 * 3 = 0.27 m³
      const l = 250.0;
      const w = 120.0;
      final h = autoHeight;
      const count = 3.0;
      final updatedVolume = (l / 100.0) * (w / 100.0) * (h / 100.0) * count;
      final updatedLineTotal = updatedVolume * cubicPrice;

      expect(updatedVolume, closeTo(0.27, 0.0001));
      expect(updatedLineTotal, closeTo(256.5, 0.0001)); // 0.27 * 950 = 256.5

      final updatedItem = item.copyWith(
        unitCategory: 'متر مكعب',
        heightCm: h,
        quantity: count,
        unitPrice: cubicPrice,
        agreedPrice: updatedLineTotal,
      );

      expect(updatedItem.isCubicMeter, isTrue);
      expect(updatedItem.heightCm, 3.0);
      expect(updatedItem.unitPrice, 950.0);
      expect(updatedItem.agreedPrice, closeTo(256.5, 0.0001));
      expect(updatedItem.calculatedVolume, closeTo(0.27, 0.0001));
    });

    test('5. Both Standard Sales Invoices and Cash Sales Invoices correctly store and compute cubic meter items', () {
      final client = ClientModel(id: 'cl_1', name: 'زبون تجريبي', clientType: 'زبون معمل');
      erp.clients = [client];

      // Standard Sales Invoice with Cubic Line Item
      final standardItem = WorkshopInvoiceItem(
        id: 'wii_std',
        sourceType: 'بيع مواد خام من المعمل',
        description: 'رخام تركي أبيض نخب أول 3سم',
        lengthCm: 200.0,
        widthCm: 100.0,
        heightCm: 3.0,
        quantity: 5.0, // 5 pieces -> (2.0 * 1.0 * 0.03 * 5) = 0.3 m³
        unitCategory: 'متر مكعب',
        unitPrice: 950.0,
        agreedPrice: 285.0, // 0.3 * 950
      );

      expect(standardItem.calculatedVolume, closeTo(0.3, 0.0001));

      final standardInvoice = WorkshopInvoiceModel(
        id: 'winv_std',
        invoiceNo: 'WS-INV-001',
        clientName: client.name,
        currency: AppCurrency.usd,
        date: DateTime.now(),
        items: [standardItem],
        agreedPrice: 285.0,
        depositDeducted: 0.0,
        cashPaidNow: 0.0,
        netCost: 180.0,
        isCashInvoice: false,
      );

      expect(standardInvoice.items.first.isCubicMeter, isTrue);
      expect(standardInvoice.grandTotal, 285.0);
      expect(standardInvoice.isCashInvoice, isFalse);
      expect(standardInvoice.remainingBalance, 285.0);

      // Cash Sales Invoice with Cubic Line Item
      final cashItem = WorkshopInvoiceItem(
        id: 'wii_cash',
        sourceType: 'بيع مواد خام من المعمل',
        description: 'غرانيت أسود أسواني 2.5سم',
        lengthCm: 200.0,
        widthCm: 100.0,
        heightCm: 2.5,
        quantity: 5.0, // 5 pieces -> (2.0 * 1.0 * 0.025 * 5) = 0.25 m³
        unitCategory: 'متر مكعب',
        unitPrice: 1800.0,
        agreedPrice: 450.0, // 0.25 * 1800
      );

      expect(cashItem.calculatedVolume, closeTo(0.25, 0.0001));

      final cashInvoice = WorkshopInvoiceModel(
        id: 'winv_cash',
        invoiceNo: 'WS-CASH-001',
        clientName: client.name,
        currency: AppCurrency.usd,
        date: DateTime.now(),
        items: [cashItem],
        agreedPrice: 450.0,
        depositDeducted: 0.0,
        cashPaidNow: 450.0,
        netCost: 300.0,
        isCashInvoice: true,
      );

      expect(cashInvoice.items.first.isCubicMeter, isTrue);
      expect(cashInvoice.grandTotal, 450.0);
      expect(cashInvoice.isCashInvoice, isTrue);
      expect(cashInvoice.remainingBalance, 0.0);

      // Factory Standard & Cash Invoices
      final factoryCubicItem = FactoryInvoiceItem(
        itemId: 'fw_2_cube',
        typeName: 'رخام تركي أبيض',
        grade: 'نخب أول',
        description: 'رخام تركي أبيض 3سم',
        lengthCm: 200.0,
        widthCm: 100.0,
        heightCm: 3.0,
        thicknessCm: 3.0,
        quantity: 5.0, // 5 pieces -> 0.3 m³
        unitPrice: 900.0,
        unitCost: 600.0,
        meterUnit: 'متر مكعب',
      );

      final factoryStdInvoice = FactoryInvoiceModel(
        id: 'finv_1',
        invoiceNo: 'FAC-INV-001',
        date: DateTime.now(),
        partyId: 'client_1',
        partyName: 'معتمد مصنع تجريبي',
        invoiceType: 'بيع_معتمد',
        items: [factoryCubicItem],
        isCashInvoice: false,
        advancePayment: 0.0,
      );

      expect(factoryStdInvoice.items.first.isCubicMeter, isTrue);
      expect(factoryStdInvoice.grandTotal, closeTo(270.0, 0.0001));
      expect(factoryStdInvoice.isCashInvoice, isFalse);
      expect(factoryStdInvoice.remainingBalance, closeTo(270.0, 0.0001));

      final factoryCashInvoice = FactoryInvoiceModel(
        id: 'finv_2',
        invoiceNo: 'FAC-CASH-001',
        date: DateTime.now(),
        partyId: 'client_1',
        partyName: 'معتمد مصنع تجريبي',
        invoiceType: 'بيع_معتمد',
        items: [factoryCubicItem],
        isCashInvoice: true,
        advancePayment: 270.0,
      );

      expect(factoryCashInvoice.items.first.isCubicMeter, isTrue);
      expect(factoryCashInvoice.grandTotal, closeTo(270.0, 0.0001));
      expect(factoryCashInvoice.isCashInvoice, isTrue);
      expect(factoryCashInvoice.remainingBalance, closeTo(0.0, 0.0001));
    });
  });
}
