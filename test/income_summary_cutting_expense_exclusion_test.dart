import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final currency in [AppCurrency.usd, AppCurrency.syp]) {
    for (final delivered in [true, false]) {
      test('freight posts cash and expenses independently ($currency, delivered=$delivered)', () async {
        final erp = ERPProvider();
        await erp.loadFuture;
        erp.mainCashBox = 1000;
        erp.mainCashBoxSyp = 1000;
        final supplier = erp.suppliers.first;
        final debt = supplier.debtOf(currency);
        final expenses = erp.incomeSummaryExpensesOf(currency);
        final records = erp.expenseRecords.length;
        final inv = FactoryInvoiceModel(id: 'freight', invoiceNo: 'F1', date: DateTime.now(), partyId: supplier.id, partyName: supplier.name, invoiceType: 'شراء_مورد', currency: currency, isGoodsDelivered: delivered, shippingFee: 30, advancePayment: 100, items: [FactoryInvoiceItem(itemId: 'freight-item', description: 'stone', quantity: 2, unitPrice: 100, unitCost: 100)]);
        expect(erp.addSupplierPurchaseInvoice(inv), isTrue);
        expect(erp.cashOf('main', currency), 870);
        expect(supplier.debtOf(currency), debt + 100);
        expect(erp.expenseRecords.length, records + 2);
        expect(erp.expenseRecords.last.isInformational, isFalse);
        expect(erp.incomeSummaryExpensesOf(currency), expenses + 130);
        expect(erp.factoryBlocks.last.tonCost, 115);
        expect(erp.addSupplierPurchaseInvoice(inv), isFalse);
        expect(erp.cashOf('main', currency), 870);
        erp.dispose();
      });
    }
  }
  test('insufficient cash rejects invoice before changing any records', () async {
    final erp = ERPProvider(); await erp.loadFuture;
    erp.mainCashBox = 20;
    final before = erp.factoryInvoices.length;
    final inv = FactoryInvoiceModel(id: 'short', invoiceNo: 'S', date: DateTime.now(), partyId: 'sup1', partyName: 'supplier', invoiceType: 'شراء_مورد', shippingFee: 30, items: []);
    expect(erp.addSupplierPurchaseInvoice(inv), isFalse);
    expect(erp.factoryInvoices.length, before);
    expect(erp.mainCashBox, 20);
    erp.dispose();
  });
  test('all expense page records including cutting and legacy entries enter P&L', () async {
    final erp = ERPProvider(); await erp.loadFuture;
    final before = erp.incomeSummaryExpenses;
    erp.expenseRecords.add(ExpenseRecordModel(id: 'cut', typeId: ERPProvider.cuttingExpenseTypeId, amount: 40, currency: AppCurrency.usd, personName: '', description: '', date: DateTime.now()));
    erp.expenseRecords.add(ExpenseRecordModel(id: 'legacy', typeId: 'other', amount: 10, currency: AppCurrency.usd, personName: '', description: '', date: DateTime.now(), isInformational: true));
    expect(erp.incomeSummaryExpenses, before + 50);
    expect(erp.incomeSummaryExpenses, erp.totalDirectExpenses);
    erp.dispose();
  });
}