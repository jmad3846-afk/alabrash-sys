import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ERPProvider erp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    erp = ERPProvider();

    // Clear initial demo records to test with clean state
    erp.workshopStock.clear();
    erp.simpleTailorings.clear();
    erp.complexTailorings.clear();
    erp.scrapItems.clear();
    erp.wasteLogs.clear();
  });

  group('Workshop Waste Product Linking & Inventory Deduction Tests', () {
    test('1. Deducts waste from Workshop Materials (مواد المعمل) and routes cost to Abnormal Waste Losses', () {
      final stockItem = WorkshopStockModel(
        id: 'ws_stock_1',
        typeName: 'مرمر أبيض',
        grade: 'نخب أول',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 25.0,
        netCostPerUnit: 40.0,
        recommendedSalePrice: 65.0,
      );
      erp.workshopStock.add(stockItem);

      final initialLoss = erp.totalUnnaturalWasteLossesOf('USD');
      expect(initialLoss, 0.0);

      // Record 5 meters of waste from workshop stock
      final success = erp.recordWorkshopWaste(
        sourceSection: 'مواد المعمل',
        sourceItemId: 'ws_stock_1',
        quantity: 5.0,
        cost: 200.0, // 5 * 40
        wasteType: 'هدر غير طبيعي',
        destructionVoucherNo: 'VOUCH-001',
        currency: 'USD',
      );

      expect(success, isTrue);
      // Stock deducted from 25.0 to 20.0
      expect(stockItem.availableQty, 20.0);

      // Waste log added with correct metadata
      expect(erp.wasteLogs.length, 1);
      final log = erp.wasteLogs.first;
      expect(log.wasteType, 'هدر غير طبيعي');
      expect(log.quantity, 5.0);
      expect(log.cost, 200.0);
      expect(log.sourceSection, 'مواد المعمل');
      expect(log.sourceItemId, 'ws_stock_1');
      expect(log.unit, 'متر مربع');
      expect(log.destructionVoucherNo, 'VOUCH-001');

      // Routed to Abnormal Waste Losses in Income Summary
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 200.0);
      expect(erp.totalDirectExpensesOf('USD'), greaterThanOrEqualTo(200.0));
    });

    test('2. Deducts waste from Simple Details (قسم التفصيل البسيط) in meters', () {
      final simpleTailoring = WorkshopTailoringModel(
        id: 'tailor_simple_1',
        name: 'عتبات رخام كرارة',
        complexity: 'بسيط',
        rawMaterialDescription: 'كرارة إيطالي',
        lengthCm: 120.0,
        widthCm: 30.0,
        unitCategory: 'متر مربع',
        quantity: 15.0, // 15 meters
        materialNetCost: 450.0,
        sellingPrice: 45.0,
      );
      erp.simpleTailorings.add(simpleTailoring);

      // Record 3 meters of waste from simple tailoring
      erp.recordWorkshopWaste(
        sourceSection: 'قسم التفصيل البسيط',
        sourceItemId: 'tailor_simple_1',
        quantity: 3.0,
        cost: 90.0,
        wasteType: 'هدر غير طبيعي',
        destructionVoucherNo: 'VOUCH-002',
        currency: 'USD',
      );

      // Tailoring quantity deducted from 15.0 to 12.0 meters
      expect(simpleTailoring.quantity, 12.0);
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 90.0);
    });

    test('3. Deducts waste from Complex Details (قسم التفصيل المعقد) in pieces', () {
      final complexTailoring = WorkshopTailoringModel(
        id: 'tailor_complex_1',
        name: 'مغسل رخام معقدة',
        complexity: 'معقد',
        rawMaterialDescription: 'ترافرتينو',
        unitCategory: 'قطعة',
        quantity: 6.0, // 6 pieces
        materialNetCost: 600.0,
        sellingPrice: 150.0,
      );
      erp.complexTailorings.add(complexTailoring);

      // Record 2 pieces of waste from complex tailoring
      erp.recordWorkshopWaste(
        sourceSection: 'قسم التفصيل المعقد',
        sourceItemId: 'tailor_complex_1',
        quantity: 2.0,
        cost: 200.0,
        wasteType: 'هدر غير طبيعي',
        destructionVoucherNo: 'VOUCH-003',
        currency: 'USD',
      );

      // Complex tailoring quantity deducted from 6 to 4 pieces
      expect(complexTailoring.quantity, 4.0);
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 200.0);
    });

    test('4. Deducts waste from Surplus Section (قسم الزيادات) and marks consumed when exhausted', () {
      final scrap = ScrapItemModel(
        id: 'scrap_1',
        description: 'قطعة غرانيت أسود أسواني زائدة',
        baseCost: 90.0,
        sellingPrice: 150.0,
        currency: 'USD',
        quantity: 3.0, // 3 surplus pieces
      );
      erp.scrapItems.add(scrap);

      // Record 1 piece waste
      erp.recordWorkshopWaste(
        sourceSection: 'قسم الزيادات',
        sourceItemId: 'scrap_1',
        quantity: 1.0,
        cost: 30.0,
        wasteType: 'هدر غير طبيعي',
        destructionVoucherNo: 'VOUCH-004',
        currency: 'USD',
      );

      expect(scrap.quantity, 2.0);
      expect(scrap.isSold, isFalse);
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 30.0);

      // Record remaining 2 pieces
      erp.recordWorkshopWaste(
        sourceSection: 'قسم الزيادات',
        sourceItemId: 'scrap_1',
        quantity: 2.0,
        cost: 60.0,
        wasteType: 'هدر غير طبيعي',
        destructionVoucherNo: 'VOUCH-005',
        currency: 'USD',
      );

      expect(scrap.quantity, 0.0);
      expect(scrap.isSold, isTrue); // Marked consumed / sold
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 90.0);
    });

    test('5. Rejects waste when quantity exceeds available stock or is non-positive', () {
      final stockItem = WorkshopStockModel(
        id: 'ws_stock_err',
        typeName: 'بازلت أسود',
        grade: 'نخب أول',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 10.0,
        netCostPerUnit: 25.0,
        recommendedSalePrice: 40.0,
      );
      erp.workshopStock.add(stockItem);

      // 1. Exceeding quantity
      expect(
        () => erp.recordWorkshopWaste(
          sourceSection: 'مواد المعمل',
          sourceItemId: 'ws_stock_err',
          quantity: 15.0, // > 10.0
          cost: 375.0,
        ),
        throwsArgumentError,
      );
      expect(stockItem.availableQty, 10.0); // Stock unchanged

      // 2. Zero or negative quantity
      expect(
        () => erp.recordWorkshopWaste(
          sourceSection: 'مواد المعمل',
          sourceItemId: 'ws_stock_err',
          quantity: 0.0,
          cost: 0.0,
        ),
        throwsArgumentError,
      );

      // 3. Non-existent item
      expect(
        () => erp.recordWorkshopWaste(
          sourceSection: 'مواد المعمل',
          sourceItemId: 'unknown_item_id',
          quantity: 1.0,
          cost: 25.0,
        ),
        throwsArgumentError,
      );
    });

    test('6. Deleting waste log restores deducted stock and reverses abnormal waste loss', () {
      final stockItem = WorkshopStockModel(
        id: 'ws_stock_restore',
        typeName: 'ترافرتين أصفر',
        grade: 'نخب ثاني',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 30.0,
        netCostPerUnit: 35.0,
        recommendedSalePrice: 50.0,
      );
      erp.workshopStock.add(stockItem);

      erp.recordWorkshopWaste(
        sourceSection: 'مواد المعمل',
        sourceItemId: 'ws_stock_restore',
        quantity: 10.0,
        cost: 350.0,
        wasteType: 'هدر غير طبيعي',
      );

      expect(stockItem.availableQty, 20.0);
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 350.0);
      final logId = erp.wasteLogs.first.id;

      // Delete the waste log
      erp.deleteWasteLog(logId);

      expect(erp.wasteLogs.isEmpty, isTrue);
      expect(stockItem.availableQty, 30.0); // Restored!
      expect(erp.totalUnnaturalWasteLossesOf('USD'), 0.0); // Reversed!
    });
  });
}
