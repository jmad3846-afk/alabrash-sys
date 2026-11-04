import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/widgets/a4_statement_print_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('opening balance collection is dated without reducing debt twice', () {
    final erp = ERPProvider();
    final client = ClientModel(
      id: 'legacy-client',
      name: 'معتمد سابق',
      clientType: 'معتمد مصنع',
    );
    erp.clients = [client];
    erp.factoryInvoices.clear();
    erp.workshopInvoices.clear();
    erp.adjustmentInvoices.clear();
    erp.returnInvoices.clear();
    erp.openingEntry.legacyFinancials
      ..clear()
      ..add(
        LegacyFinancialRecordModel(
          id: 'old',
          category: 'clients',
          partyId: client.id,
          name: client.name,
          currency: AppCurrency.usd,
          amount: 100,
        ),
      );
    expect(erp.settleLegacyFinancialRecord('old', 25, 'main'), isTrue);
    final statement = A4StatementData.fromAccreditedAgent(
      client: client,
      erp: erp,
    );
    expect(
      statement.items
          .where((i) => i.category == 'قيد افتتاحي')
          .single
          .remainingAmount,
      100,
    );
    expect(
      statement.items.where((i) => i.category == 'دفعة قبض').single.paidAmount,
      25,
    );
    expect(statement.items.last.runningBalance, 75);
    expect(statement.currentBalanceUsd, 75);
  });

  test(
    'approved client receives workshop debt and dated payments in one ledger',
    () {
      final erp = ERPProvider();
      final client = ClientModel(
        id: 'approved',
        name: 'معتمد موحد',
        clientType: 'معتمد مصنع',
      );
      erp.clients = [client];
      erp.workshopInvoices.clear();
      erp.adjustmentInvoices.clear();
      erp.returnInvoices.clear();
      erp.openingEntry.legacyFinancials.clear();
      final factory = FactoryInvoiceModel(
        id: 'factory',
        invoiceNo: 'F-1',
        date: DateTime(2026, 1, 1, 9),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item',
            description: 'رخام',
            quantity: 1,
            unitPrice: 100,
            unitCost: 50,
          ),
        ],
      );
      erp.factoryInvoices = [factory];
      client.debtBalance = 100;
      expect(
        erp.createWorkshopInvoice(
          WorkshopInvoiceModel(
            id: 'workshop',
            invoiceNo: 'W-1',
            date: DateTime(2026, 1, 2, 9),
            clientName: client.name,
            sourceType: 'تفصيل بسيط',
            agreedPrice: 200,
            depositDeducted: 0,
            cashPaidNow: 0,
            netCost: 50,
          ),
        ),
        isTrue,
      );
      expect(erp.clients, hasLength(1));
      expect(client.debtBalance, 300);
      final paidAt = DateTime(2026, 1, 3, 14, 32, 18);
      expect(
        erp.collectCustomerPayment(
          client: client,
          paymentCurrency: AppCurrency.usd,
          paymentAmount: 150,
          transactionDate: paidAt,
        ),
        isTrue,
      );
      expect(factory.remainingBalance, 0);
      expect(erp.workshopInvoices.single.remainingBalance, 150);
      final restored = ClientModel.fromJson(client.toJson());
      expect(restored.payments.single['date'], paidAt.toIso8601String());
      final statement = A4StatementData.fromAccreditedAgent(
        client: restored,
        erp: erp,
      );
      expect(statement.items.map((i) => i.category), [
        'فاتورة مبيعات - مصنع',
        'فاتورة مبيعات - معمل',
        'دفعة قبض',
      ]);
      expect(statement.items.last.date, paidAt);
      expect(statement.items.map((i) => i.runningBalance), [100, 300, 150]);
      expect(statement.currentBalanceUsd, 150);
      expect(statement.totalPaidUsd, 150);
      final earlierPayment = paidAt.subtract(const Duration(seconds: 10));
      expect(
        erp.collectWorkshopInvoice(
          erp.workshopInvoices.single,
          25,
          transactionDate: earlierPayment,
        ),
        isTrue,
      );
      final updated = A4StatementData.fromAccreditedAgent(
        client: client,
        erp: erp,
      );
      expect(updated.items.map((i) => i.runningBalance), [100, 300, 275, 125]);
      expect(updated.items[2].date, earlierPayment);
      expect(updated.items.last.date, paidAt);
      expect(updated.totalPaidUsd, 175);
      expect(updated.currentBalanceUsd, 125);
    },
  );
}
