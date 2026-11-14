import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ERPProvider> seededErp() async {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    await erp.loadFuture;
    erp.clients = [
      ClientModel(id: 'c1', name: 'عميل قديم', clientType: 'معتمد مصنع'),
    ];
    erp.suppliers = [
      SupplierModel(id: 's1', name: 'مورد قديم', phone: '', location: ''),
    ];
    return erp;
  }

  test('collecting a client old debt increases the matching main cash box', () async {
    final erp = await seededErp();
    erp.openingEntry.legacyFinancials
      ..clear()
      ..add(
        LegacyFinancialRecordModel(
          id: 'old-client',
          category: 'clients',
          partyId: 'c1',
          name: 'عميل قديم',
          currency: AppCurrency.usd,
          amount: 100,
        ),
      );
    erp.mainCashBox = 500;
    erp.mainCashBoxSyp = 200000;

    final ok = erp.settleLegacyFinancialRecord('old-client', 40, 'main');

    expect(ok, isTrue);
    expect(erp.mainCashBox, closeTo(540, 0.001));
    expect(erp.mainCashBoxSyp, 200000);
    expect(
      erp.openingEntry.legacyFinancials.single.amount,
      closeTo(60, 0.001),
    );
  });

  test('paying a supplier old debt decreases the matching main cash box', () async {
    final erp = await seededErp();
    erp.openingEntry.legacyFinancials
      ..clear()
      ..add(
        LegacyFinancialRecordModel(
          id: 'old-supplier',
          category: 'suppliers',
          partyId: 's1',
          name: 'مورد قديم',
          currency: AppCurrency.syp,
          amount: 50000,
        ),
      );
    erp.mainCashBox = 500;
    erp.mainCashBoxSyp = 200000;

    final ok = erp.settleLegacyFinancialRecord('old-supplier', 30000, 'main');

    expect(ok, isTrue);
    expect(erp.mainCashBox, 500);
    expect(erp.mainCashBoxSyp, closeTo(170000, 0.001));
  });

  test('paying beyond the cash box balance is rejected and changes nothing', () async {
    final erp = await seededErp();
    erp.openingEntry.legacyFinancials
      ..clear()
      ..add(
        LegacyFinancialRecordModel(
          id: 'old-emp',
          category: 'employees',
          name: 'موظف قديم',
          currency: AppCurrency.usd,
          amount: 100,
        ),
      );
    erp.mainCashBox = 20;

    final ok = erp.settleLegacyFinancialRecord('old-emp', 50, 'main');

    expect(ok, isFalse);
    expect(erp.mainCashBox, 20);
    expect(
      erp.openingEntry.legacyFinancials.single.amount,
      closeTo(100, 0.001),
    );
  });
}
