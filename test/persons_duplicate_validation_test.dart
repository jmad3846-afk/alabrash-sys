import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Factory Persons Section - Duplicate Name Prevention Tests', () {
    test('1. Prevents adding duplicate supplier name (exact & case/whitespace variation)', () {
      final erp = ERPProvider();
      final initialSupplierCount = erp.suppliers.length;

      // Add a new supplier
      final ok1 = erp.addSupplier(
        SupplierModel(
          id: 'sup_test_1',
          name: 'شركة الشهباء للرخام',
          phone: '0911222333',
          location: 'حلب',
        ),
      );
      expect(ok1, isTrue);
      expect(erp.suppliers.length, initialSupplierCount + 1);

      // Attempt A: Exact duplicate name -> Rejected
      final okDuplicate = erp.addSupplier(
        SupplierModel(
          id: 'sup_test_2',
          name: 'شركة الشهباء للرخام',
          phone: '0999888777',
          location: 'دمشق',
        ),
      );
      expect(okDuplicate, isFalse);
      expect(erp.suppliers.length, initialSupplierCount + 1);

      // Attempt B: Trimmed / spacing variation -> Rejected
      final okTrimmed = erp.addSupplier(
        SupplierModel(
          id: 'sup_test_3',
          name: '   شركة الشهباء للرخام   ',
          phone: '0999888777',
          location: 'حلب',
        ),
      );
      expect(okTrimmed, isFalse);
      expect(erp.suppliers.length, initialSupplierCount + 1);
    });

    test('2. Prevents adding duplicate client / approved dealer name', () {
      final erp = ERPProvider();
      final initialClientsCount = erp.clients.length;

      // Add an approved dealer
      final ok1 = erp.addClient(
        ClientModel(
          id: 'cli_test_1',
          name: 'مؤسسة الأمل للمقاولات',
          phone: '0944555666',
          location: 'حمص',
          clientType: 'معتمد مصنع',
        ),
      );
      expect(ok1, isTrue);
      expect(erp.clients.length, initialClientsCount + 1);

      // Attempt duplicate client name -> Rejected
      final okDuplicate = erp.addClient(
        ClientModel(
          id: 'cli_test_2',
          name: 'مؤسسة الأمل للمقاولات',
          phone: '0988777666',
          location: 'حمص',
          clientType: 'معتمد مصنع',
        ),
      );
      expect(okDuplicate, isFalse);
      expect(erp.clients.length, initialClientsCount + 1);
    });

    test('3. Cross-prevention: Prevents adding supplier with a name already used by a client', () {
      final erp = ERPProvider();

      // Ensure client exists
      erp.addClient(
        ClientModel(
          id: 'cli_cross_1',
          name: 'شركة النور للإعمار',
          phone: '0955111222',
          location: 'اللاذقية',
          clientType: 'معتمد مصنع',
        ),
      );

      // Attempt to add supplier with the exact same name -> Rejected
      final ok = erp.addSupplier(
        SupplierModel(
          id: 'sup_cross_1',
          name: 'شركة النور للإعمار',
          phone: '0955111222',
          location: 'اللاذقية',
        ),
      );
      expect(ok, isFalse);
    });

    test('4. Cross-prevention: Prevents adding client with a name already used by a supplier', () {
      final erp = ERPProvider();

      // Ensure supplier exists
      erp.addSupplier(
        SupplierModel(
          id: 'sup_cross_2',
          name: 'مقالع الشرقية',
          phone: '0933222111',
          location: 'تدمر',
        ),
      );

      // Attempt to add client with the exact same name -> Rejected
      final ok = erp.addClient(
        ClientModel(
          id: 'cli_cross_2',
          name: 'مقالع الشرقية',
          phone: '0933222111',
          location: 'تدمر',
          clientType: 'معتمد مصنع',
        ),
      );
      expect(ok, isFalse);
    });

    test('5. Valid distinct person names are accepted normally', () {
      final erp = ERPProvider();
      final initSuppliers = erp.suppliers.length;
      final initClients = erp.clients.length;

      expect(
        erp.addSupplier(
          SupplierModel(
            id: 'sup_valid_1',
            name: 'مورد متميز وفريد 2026',
            phone: '0912345678',
            location: 'طرطوس',
          ),
        ),
        isTrue,
      );
      expect(erp.suppliers.length, initSuppliers + 1);

      expect(
        erp.addClient(
          ClientModel(
            id: 'cli_valid_1',
            name: 'معتمد متميز وفريد 2026',
            phone: '0987654321',
            location: 'درعا',
            clientType: 'معتمد مصنع',
          ),
        ),
        isTrue,
      );
      expect(erp.clients.length, initClients + 1);
    });
  });
}
