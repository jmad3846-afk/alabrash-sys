import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  test('granite returns reverse proportional margin and route accountant revenue without cash', () async {
    SharedPreferences.setMockInitialValues({});
    final erp = ERPProvider();
    await erp.loadFuture;
    erp.factoryInvoices.clear();
    erp.workshopInvoices.clear();
    erp.adjustmentInvoices.clear();
    erp.graniteAccountantPercentage = 50;
    final item = FactoryInvoiceItem(itemId: 'g', description: 'granite', quantity: 10, unitPrice: 100, unitCost: 60, isGranite: true);
    final inv = FactoryInvoiceModel(id: 'sale', invoiceNo: 'S1', date: DateTime.now(), partyId: 'customer', partyName: 'customer', invoiceType: 'بيع_معتمد', items: [item]);
    erp.factoryInvoices.add(inv);
    final profit = erp.netGraniteProfit;
    expect(profit, greaterThan(0));
    final cash = erp.mainCashBox;
    final revenue = erp.totalRevenues;
    AdjustmentInvoiceModel returned(String id, double qty) => AdjustmentInvoiceModel(id: id, invoiceNo: id, module: 'factory', kind: 'sales_return', targetInvoiceId: inv.id, targetInvoiceNo: inv.invoiceNo, partyName: inv.partyName, description: 'return', amount: qty * 100, quantity: qty, paymentAction: 'تخفيض دين', currency: AppCurrency.usd, lines: [AdjustmentLineModel(itemId: 'g', itemIndex: 0, description: 'granite', quantity: qty, unitPrice: 100, amount: qty * 100)]);
    erp.adjustmentInvoices.add(returned('partial', 2));
    expect(erp.netGraniteProfit, closeTo(profit * .8, .001));
    expect(erp.graniteReturnAccountantRevenueOf(AppCurrency.usd), closeTo(profit * .1, .001));
    expect(erp.totalRevenues, closeTo(revenue + profit * .1, .001));
    expect(erp.mainCashBox, cash);
    erp.adjustmentInvoices.add(returned('remaining', 8));
    expect(erp.netGraniteProfit, 0);
    expect(erp.accountantGraniteShare, 0);
    expect(erp.graniteReturnAccountantRevenueOf(AppCurrency.usd), closeTo(profit * .5, .001));
    erp.dispose();
  });
}