import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/widgets/a4_statement_print_dialog.dart';

ERPProvider createERP() {
  final erp = ERPProvider();
  erp.mainCashBox = 0.0;
  erp.mainCashBoxSyp = 0.0;
  erp.scrapCashBox = 0.0;
  erp.orderCashBox = 0.0;
  erp.factoryInvoices.clear();
  erp.workshopInvoices.clear();
  erp.suppliers.clear();
  erp.clients.clear();
  erp.adjustmentInvoices.clear();
  erp.returnInvoices.clear();
  erp.factoryBlocks.clear();
  erp.expenseRecords.clear();
  erp.workdayEntries.clear();
  erp.wasteLogs.clear();
  erp.scrapItems.clear();
  erp.surplusCosts.clear();
  erp.assetSaleRecords.clear();
  return erp;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Standalone Sales Allowances (مسموحات مبيعات خارج الفاتورة)', () {
    test('1. Factory Customer: Zero inventory movement, customer debt credited, reflects in Account Statement & Income Summary', () {
      final erp = createERP();
      final client = ClientModel(
        id: 'cl_101',
        name: 'معتمد الأمل للرخام',
        phone: '0933111222',
        location: 'طرطوس',
        clientType: 'معتمد',
        debtBalance: 1000.0,
        debtBalanceSyp: 0.0,
      );
      erp.clients.add(client);

      // Add a block to factory to verify inventory is completely untouched
      final testBlock = FactoryBlockModel(
        id: 'blk_1',
        blockCode: 'BLK-001',
        typeName: 'كاردينال',
        grade: 'نخب أول',
        supplierId: 'sup_test',
        supplierName: 'مورد تجريبي',
        weightTons: 10.0,
        tonCost: 50.0,
      );
      erp.factoryBlocks.add(testBlock);

      // Initial baseline assertions
      expect(client.debtOf(AppCurrency.usd), 1000.0);
      expect(erp.factoryBlocks.first.weightTons, 10.0);
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 0.0);
      final initialExpenses = erp.totalDirectExpensesOf(AppCurrency.usd);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      // Create standalone sales allowance of 250 USD
      final allowance = AdjustmentInvoiceModel(
        id: 'adj_standalone_sales_1',
        invoiceNo: 'ALL-SLS-001',
        module: 'factory',
        kind: 'sales_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: client.name,
        description: 'سماح خاص بالجودة خارج الفاتورة',
        amount: 250.0,
        currency: AppCurrency.usd,
        paymentAction: 'تخفيض دين',
        lines: const [],
      );

      final success = erp.addAdjustmentInvoice(allowance);
      expect(success, isTrue);

      // Rule 1: No Inventory Movement
      expect(erp.factoryBlocks.first.weightTons, 10.0);

      // Rule 2: Account Statement Integration
      expect(client.debtOf(AppCurrency.usd), 750.0);

      final statement = A4StatementData.fromAccreditedAgent(
        client: client,
        erp: erp,
      );
      final allowanceItem = statement.items.firstWhere(
        (it) => it.documentNo == 'ALL-SLS-001',
      );
      expect(allowanceItem.category, 'مسموح مبيعات');
      expect(allowanceItem.parentInvoiceNo, 'خارج الفاتورة');
      expect(allowanceItem.totalAmount, 250.0);
      expect(allowanceItem.status, 'مسموح مسوى');
      expect(allowanceItem.isReturn, isTrue);
      expect(statement.currentBalanceUsd, 750.0);
      expect(statement.totalReturnsUsd, 250.0);

      // Rule 3: Income Summary Routing (Contra-Revenue)
      expect(erp.adjustmentTotalOf('sales_allowance', AppCurrency.usd), 250.0);
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 250.0);
      expect(erp.totalDirectExpensesOf(AppCurrency.usd), initialExpenses + 250.0);
      expect(erp.netOperatingProfitOf(AppCurrency.usd), initialProfit - 250.0);
    });

    test('2. Workshop Customer in SYP: Reduces client SYP debt, reflects in workshop customer statement', () {
      final erp = createERP();
      final client = ClientModel(
        id: 'cl_ws_1',
        name: 'ورشة الفردوس للديكور',
        phone: '0944000111',
        location: 'دمشق',
        clientType: 'زبون عادي',
        debtBalance: 0.0,
        debtBalanceSyp: 5000000.0,
      );
      erp.clients.add(client);

      final allowanceSyp = AdjustmentInvoiceModel(
        id: 'adj_standalone_sales_syp',
        invoiceNo: 'ALL-SLS-SYP-1',
        module: 'workshop',
        kind: 'sales_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: client.name,
        description: 'سماح مالي على حساب المعمل',
        amount: 1500000.0,
        currency: AppCurrency.syp,
        paymentAction: 'تخفيض دين',
      );

      final success = erp.addAdjustmentInvoice(allowanceSyp);
      expect(success, isTrue);

      expect(client.debtOf(AppCurrency.syp), 3500000.0);

      final statement = A4StatementData.fromCustomer(
        client: client,
        erp: erp,
      );
      final item = statement.items.firstWhere((it) => it.documentNo == 'ALL-SLS-SYP-1');
      expect(item.category, 'مسموح مبيعات معمل');
      expect(item.totalAmount, 1500000.0);
      expect(statement.currentBalanceSyp, 3500000.0);
      expect(statement.totalReturnsSyp, 1500000.0);

      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.syp), 1500000.0);
    });
  });

  group('Standalone Purchase Allowances (مسموحات مشتريات خارج الفاتورة)', () {
    test('3. Factory Supplier: Zero inventory movement, debits supplier account, reflects in Supplier Account Statement & Income Summary', () {
      final erp = createERP();
      final supplier = SupplierModel(
        id: 'sup_101',
        name: 'شركة محاجر البادية',
        phone: '0955222333',
        location: 'حمص',
        debtBalance: 2000.0,
        debtBalanceSyp: 0.0,
      );
      erp.suppliers.add(supplier);

      final testBlock = FactoryBlockModel(
        id: 'blk_sup_1',
        blockCode: 'BLK-002',
        typeName: 'ترافرتين',
        grade: 'تجاري',
        supplierId: supplier.id,
        supplierName: supplier.name,
        weightTons: 8.0,
        tonCost: 80.0,
      );
      erp.factoryBlocks.add(testBlock);

      expect(supplier.debtOf(AppCurrency.usd), 2000.0);
      expect(erp.factoryBlocks.first.weightTons, 8.0);
      final initialRevenues = erp.totalRevenuesOf(AppCurrency.usd);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      final allowance = AdjustmentInvoiceModel(
        id: 'adj_standalone_pur_1',
        invoiceNo: 'ALL-PUR-001',
        module: 'factory',
        kind: 'purchase_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: supplier.name,
        description: 'سماح ممنوح من المورد بسبب عيوب قص',
        amount: 400.0,
        currency: AppCurrency.usd,
        paymentAction: 'تخفيض دين',
      );

      final success = erp.addAdjustmentInvoice(allowance);
      expect(success, isTrue);

      // Rule 1: No Inventory Movement
      expect(erp.factoryBlocks.first.weightTons, 8.0);

      // Rule 2: Account Statement Integration
      expect(supplier.debtOf(AppCurrency.usd), 1600.0);

      final statement = A4StatementData.fromSupplier(
        supplier: supplier,
        erp: erp,
      );
      final allowanceItem = statement.items.firstWhere(
        (it) => it.documentNo == 'ALL-PUR-001',
      );
      expect(allowanceItem.category, 'مسموح مشتريات');
      expect(allowanceItem.parentInvoiceNo, 'خارج الفاتورة');
      expect(allowanceItem.totalAmount, 400.0);
      expect(allowanceItem.status, 'مسموح مسوى');
      expect(allowanceItem.isReturn, isTrue);
      expect(statement.currentBalanceUsd, 1600.0);
      expect(statement.totalReturnsUsd, 400.0);

      // Rule 3: Income Summary / Cost Routing (Earned Allowance / Contra-Cost)
      expect(erp.adjustmentTotalOf('purchase_allowance', AppCurrency.usd), 400.0);
      expect(erp.totalRevenuesOf(AppCurrency.usd), initialRevenues + 400.0);
      expect(erp.netOperatingProfitOf(AppCurrency.usd), initialProfit + 400.0);
    });

    test('4. Purchase allowance in SYP from supplier: Debits supplier SYP balance correctly', () {
      final erp = createERP();
      final supplier = SupplierModel(
        id: 'sup_syp_1',
        name: 'مقلع شهبا للبازلت',
        phone: '0966333444',
        location: 'السويداء',
        debtBalance: 0.0,
        debtBalanceSyp: 10000000.0,
      );
      erp.suppliers.add(supplier);

      final allowanceSyp = AdjustmentInvoiceModel(
        id: 'adj_standalone_pur_syp',
        invoiceNo: 'ALL-PUR-SYP-1',
        module: 'factory',
        kind: 'purchase_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: supplier.name,
        description: 'مسموح توريد مباشر',
        amount: 2500000.0,
        currency: AppCurrency.syp,
        paymentAction: 'تخفيض دين',
      );

      final success = erp.addAdjustmentInvoice(allowanceSyp);
      expect(success, isTrue);

      expect(supplier.debtOf(AppCurrency.syp), 7500000.0);

      final statement = A4StatementData.fromSupplier(
        supplier: supplier,
        erp: erp,
      );
      final item = statement.items.firstWhere((it) => it.documentNo == 'ALL-PUR-SYP-1');
      expect(item.category, 'مسموح مشتريات');
      expect(item.totalAmount, 2500000.0);
      expect(statement.currentBalanceSyp, 7500000.0);
      expect(statement.totalReturnsSyp, 2500000.0);

      expect(erp.adjustmentTotalOf('purchase_allowance', AppCurrency.syp), 2500000.0);
    });
  });

  group('Standalone Allowances Cash Settlements & Safe Isolation', () {
    test('5. Standalone Purchase Allowance with Cash Collection: Adds cash to Main Safe without altering supplier debt', () {
      final erp = createERP();
      erp.mainCashBox = 100.0;
      final supplier = SupplierModel(
        id: 'sup_cash_1',
        name: 'مورد نقدي',
        phone: '0911222333',
        location: 'اللاذقية',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      final allowance = AdjustmentInvoiceModel(
        id: 'adj_pur_cash_1',
        invoiceNo: 'ALL-PUR-CSH-1',
        module: 'factory',
        kind: 'purchase_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: supplier.name,
        description: 'تعويض نقدي مباشر من المورد',
        amount: 75.0,
        currency: AppCurrency.usd,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
      );

      final success = erp.addAdjustmentInvoice(allowance);
      expect(success, isTrue);

      // Safe updated
      expect(erp.mainCashBox, 175.0);
      // Supplier debt untouched
      expect(supplier.debtBalance, 0.0);
      // Recognized as earned allowance
      expect(erp.adjustmentTotalOf('purchase_allowance', AppCurrency.usd), 75.0);
    });

    test('6. Standalone Sales Allowance with Cash Payout: Disburses cash from Main Safe without altering client debt', () {
      final erp = createERP();
      erp.mainCashBox = 500.0;
      final client = ClientModel(
        id: 'cl_cash_1',
        name: 'زبون نقدي',
        phone: '0977888999',
        location: 'حلب',
        clientType: 'زبون عادي',
        debtBalance: 0.0,
      );
      erp.clients.add(client);
      final initialProfit = erp.netOperatingProfitOf(AppCurrency.usd);

      final allowance = AdjustmentInvoiceModel(
        id: 'adj_sls_cash_1',
        invoiceNo: 'ALL-SLS-CSH-1',
        module: 'factory',
        kind: 'sales_allowance',
        targetInvoiceId: 'standalone',
        targetInvoiceNo: 'خارج الفاتورة',
        partyName: client.name,
        description: 'صرف نقدي فوري لسماح مبيعات',
        amount: 120.0,
        currency: AppCurrency.usd,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
      );

      final success = erp.addAdjustmentInvoice(allowance);
      expect(success, isTrue);

      // Safe reduced
      expect(erp.mainCashBox, 380.0);
      // Client debt untouched
      expect(client.debtBalance, 0.0);
      // Recognized in Income Summary
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 120.0);
      expect(erp.netOperatingProfitOf(AppCurrency.usd), initialProfit - 120.0);
    });
  });
}
