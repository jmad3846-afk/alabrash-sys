import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

/// Regression: after the opening entry (القيد الافتتاحي) is approved ONCE and
/// then reopened for editing, NEW meter-type opening stock items must still
/// be materialized into the operational inventory (factory warehouse /
/// workshop stock) when the entry is approved again. Previously the global
/// one-shot flag silently skipped the entire pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  OpeningStockItemModel factoryMeter(String id, {double qty = 50}) =>
      OpeningStockItemModel(
        id: id,
        category: 'أمتار المصنع',
        typeName: 'بيج أوردو',
        typeId: 'type_ordo',
        grade: 'نخب أول',
        thicknessCm: 3.5,
        quantity: qty,
        unitPrice: 25,
        sellingPrice: 40,
        currency: AppCurrency.usd,
      );

  ERPProvider seededErp() {
    final erp = ERPProvider();
    erp.addBlockType(
      BlockTypeModel(
        id: 'type_ordo',
        typeName: 'بيج أوردو',
        grade: 'نخب أول',
        isGranite: false,
      ),
    );
    return erp;
  }

  group('Opening stock incremental application', () {
    test('meter item added after re-approval lands in the factory warehouse',
        () {
      final erp = seededErp();

      // First approval with one meter line.
      erp.openingEntry.openingStock.add(factoryMeter('open_meter_a'));
      erp.lockOpeningEntry();
      expect(
        erp.factoryWarehouse.where((w) => w.id == 'open_meter_a').length,
        1,
      );

      // Reopen for editing, add a NEW meter type line, approve again.
      erp.unlockOpeningEntryForEditing();
      erp.openingEntry.openingStock.add(factoryMeter('open_meter_b', qty: 30));
      erp.lockOpeningEntry();

      // Lot rows are consolidated by their natural key (type/grade/thickness/
      // currency) on save, so the new quantity may merge into the existing
      // lot — what must never happen is the line silently vanishing. The
      // total available for the type must be 50 + 30 = 80.
      final lots = erp.factoryWarehouse
          .where((w) => w.typeName == 'بيج أوردو' && w.grade == 'نخب أول')
          .toList();
      final totalQty = lots.fold<double>(0.0, (s, w) => s + w.availableQty);
      expect(
        totalQty,
        closeTo(80.0, 0.001),
        reason: 'new opening meter line must be materialized',
      );
      expect(lots.first.thicknessCm, 3.5);
      expect(lots.first.category, 'متر مربع');

      // The previously applied line must NOT be duplicated.
      expect(
        erp.factoryWarehouse.where((w) => w.id == 'open_meter_a').length,
        1,
      );
      expect(
        erp.openingEntry.appliedOpeningStockIds,
        containsAll(['open_meter_a', 'open_meter_b']),
      );
    });

    test('workshop meter item added after re-approval lands in workshop stock',
        () {
      final erp = seededErp();

      erp.openingEntry.openingStock.add(
        OpeningStockItemModel(
          id: 'open_ws_a',
          category: 'أمتار المعمل',
          typeName: 'بيج أوردو',
          typeId: 'type_ordo',
          grade: 'نخب أول',
          thicknessCm: 2,
          quantity: 20,
          unitPrice: 30,
          currency: AppCurrency.usd,
        ),
      );
      erp.lockOpeningEntry();
      expect(
        erp.workshopStock.where((w) => w.id == 'open_ws_a').length,
        1,
      );

      erp.unlockOpeningEntryForEditing();
      erp.openingEntry.openingStock.add(
        OpeningStockItemModel(
          id: 'open_ws_b',
          category: 'أمتار المعمل',
          typeName: 'بيج أوردو',
          typeId: 'type_ordo',
          grade: 'نخب أول',
          thicknessCm: 2,
          quantity: 15,
          unitPrice: 30,
          currency: AppCurrency.usd,
        ),
      );
      erp.lockOpeningEntry();

      expect(
        erp.workshopStock.where((w) => w.id == 'open_ws_b').length,
        1,
      );
      expect(
        erp.workshopStock.where((w) => w.id == 'open_ws_a').length,
        1,
      );
    });

    test('re-approval with no new lines changes nothing', () {
      final erp = seededErp();
      erp.openingEntry.openingStock.add(factoryMeter('open_meter_c'));
      erp.lockOpeningEntry();
      final warehouseCount = erp.factoryWarehouse.length;

      erp.unlockOpeningEntryForEditing();
      erp.lockOpeningEntry();

      expect(erp.factoryWarehouse.length, warehouseCount);
      expect(
        erp.factoryWarehouse.where((w) => w.id == 'open_meter_c').length,
        1,
      );
    });

    test('applied ledger survives the JSON round-trip', () {
      final erp = seededErp();
      erp.openingEntry.openingStock.add(factoryMeter('open_meter_d'));
      erp.lockOpeningEntry();
      final json = erp.openingEntry.toJson();
      final restored = OpeningEntryModel.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(restored.appliedOpeningStockIds, contains('open_meter_d'));
    });

    test('legacy flag-only save: materialized lines not duplicated, lost lines repaired',
        () {
      final erp = seededErp();

      // Simulate a legacy approved save (flag true, no per-item ledger):
      // line 'legacy_a' WAS materialized (warehouse row exists), line
      // 'legacy_b' was added afterwards during the bug era and never got
      // into the warehouse.
      erp.openingEntry.openingStock.addAll([
        factoryMeter('legacy_a', qty: 50),
        factoryMeter('legacy_b', qty: 30),
      ]);
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: 'legacy_a',
          typeName: 'بيج أوردو',
          grade: 'نخب أول',
          thicknessCm: 3.5,
          category: 'متر مربع',
          availableQty: 50,
          netCostPerUnit: 25,
          recommendedSalePrice: 40,
          currency: AppCurrency.usd,
        ),
      );
      erp.openingEntry.openingStockApplied = true;

      // Any approval pass now migrates the ledger by evidence and applies
      // only the lost line.
      erp.lockOpeningEntry();

      final rows = erp.factoryWarehouse
          .where((w) => w.typeName == 'بيج أوردو' && w.grade == 'نخب أول')
          .toList();
      final totalQty = rows.fold<double>(0.0, (s, w) => s + w.availableQty);
      expect(
        totalQty,
        closeTo(80.0, 0.001),
        reason: 'legacy_b repaired without duplicating legacy_a',
      );
      expect(
        erp.openingEntry.appliedOpeningStockIds,
        containsAll(['legacy_a', 'legacy_b']),
      );
    });

    test('fully applied ledger stays untouched on startup pass', () {
      final erp = seededErp();
      erp.openingEntry.openingStock.add(factoryMeter('legacy_c'));
      erp.lockOpeningEntry();
      final count = erp.factoryWarehouse.length;
      final ids = [...erp.openingEntry.appliedOpeningStockIds];

      erp.unlockOpeningEntryForEditing();
      erp.lockOpeningEntry();

      expect(erp.factoryWarehouse.length, count);
      expect(erp.openingEntry.appliedOpeningStockIds, ids);
    });
  });
}
