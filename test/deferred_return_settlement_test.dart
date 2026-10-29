import 'package:flutter_test/flutter_test.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Deferred Income Summary Impact for Return Invoices with Account Settlement', () {
    test('1. Purchase Return with Account Settlement strictly defers Income Summary until cash collection', () {
      final erp = ERPProvider();
      erp.mainCashBox = 5000.0;
      final initialSafe = erp.mainCashBox;

      final supplier = SupplierModel(
        id: 'sup-defer-1',
        name: 'مورد تسوية الحساب',
        phone: '0911223344',
        location: 'اللاذقية',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'item-block-1',
          blockCode: 'BLK-DEF-1',
          typeName: 'بلوك مرمرة',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 10.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      // 1. Create a purchase invoice: $1,000 total, $400 advance payment (cash paid), $600 unpaid debt
      final inv = FactoryInvoiceModel(
        id: 'pinv-defer-1',
        invoiceNo: 'PINV-DEF-001',
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        date: DateTime(2026, 10, 1),
        advancePayment: 400.0,
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'item-block-1',
            typeName: 'بلوك مرمرة',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 100.0,
            description: 'كتل رخام مرمرة',
          ),
        ],
      );
      erp.factoryInvoices.add(inv);
      supplier.debtBalance += (inv.grandTotal - inv.advancePayment);
      expect(supplier.debtBalance, 600.0);

      final initialRevenues = erp.totalRevenuesOf(AppCurrency.usd);
      expect(erp.purchaseReturnsAndAllowances, 0.0);

      // 2. Return $700 worth of goods with Account Settlement (تخفيض دين / تسوية حساب)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-sup-defer-1',
        invoiceNo: 'PRET-DEF-001',
        module: 'factory',
        kind: 'purchase_return',
        partyName: supplier.name,
        targetInvoiceId: inv.id,
        targetInvoiceNo: inv.invoiceNo,
        description: 'إرجاع مشتريات مع تسوية حساب',
        amount: 700.0,
        quantity: 7.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 2),
        lines: [
          AdjustmentLineModel(
            itemId: 'item-block-1',
            itemIndex: 0,
            description: 'كتل رخام مرمرة',
            unit: 'طن',
            quantity: 7.0,
            unitPrice: 100.0,
            amount: 700.0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      // Rule 1: Party account balance is updated ($600 debt wiped, flips to -$100 credit)
      expect(supplier.debtBalance, -100.0);
      expect(supplier.hasCredit, isTrue);
      expect(supplier.creditOf(AppCurrency.usd), 100.0);

      // Safe was untouched
      expect(erp.mainCashBox, initialSafe);

      // Rule 1: Strictly prevent Income Summary impact at return time!
      expect(erp.purchaseReturnsAndAllowances, 0.0);
      expect(erp.totalRevenuesOf(AppCurrency.usd), initialRevenues);
      expect(erp.deferredAdjustmentTotalOf('purchase_return', AppCurrency.usd), 700.0);

      final storedAdj = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(storedAdj.isSettlementDeferred, isTrue);
      expect(storedAdj.deferredAmount, 700.0);
      expect(storedAdj.realizedAmount, 0.0);
      expect(storedAdj.isFullyRealized, isFalse);
      expect(storedAdj.pendingDeferredAmount, 700.0);

      // Rule 2: Execute cash collection from supplier credit ($100)
      final collectOk = erp.collectFromSupplierCredit(
        supplier: supplier,
        amount: 100.0,
        currency: AppCurrency.usd,
      );
      expect(collectOk, isTrue);

      // Safe gained $100 cash
      expect(erp.mainCashBox, initialSafe + 100.0);
      expect(supplier.debtBalance, 0.0);

      // Rule 2: Cash collection formally releases the deferred purchase return into Income Summary!
      expect(erp.purchaseReturnsAndAllowances, 100.0);
      expect(erp.totalRevenuesOf(AppCurrency.usd), initialRevenues + 100.0);
      expect(storedAdj.realizedAmount, 100.0);
      expect(storedAdj.pendingDeferredAmount, 600.0);
    });

    test('2. Sales Return with Account Settlement strictly defers Income Summary until cash payout', () {
      final erp = ERPProvider();
      erp.mainCashBox = 2000.0;
      final initialSafe = erp.mainCashBox;

      final client = ClientModel(
        id: 'cli-defer-1',
        name: 'معتمد تسوية المبيعات',
        phone: '0955667788',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      // 1. Sales invoice: $1,000 total, $400 advance payment (cash paid), $600 unpaid debt
      final inv = FactoryInvoiceModel(
        id: 'sinv-defer-1',
        invoiceNo: 'SINV-DEF-001',
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        date: DateTime(2026, 10, 1),
        advancePayment: 400.0,
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'item-slab-1',
            typeName: 'ألواح تركي',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 60.0,
            description: 'ألواح رخام تركي',
          ),
        ],
      );
      erp.factoryInvoices.add(inv);
      client.debtBalance += (inv.grandTotal - inv.advancePayment);
      expect(client.debtBalance, 600.0);

      final initialExpenses = erp.incomeSummaryExpensesOf(AppCurrency.usd);
      final initialNetProfit = erp.incomeSummaryNetProfitOf(AppCurrency.usd);
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 0.0);

      // 2. Full return ($1,000) with Account Settlement (تخفيض دين)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-cli-defer-1',
        invoiceNo: 'SRET-DEF-001',
        module: 'factory',
        kind: 'sales_return',
        partyName: client.name,
        targetInvoiceId: inv.id,
        targetInvoiceNo: inv.invoiceNo,
        description: 'إرجاع مبيعات مع تسوية حساب',
        amount: 1000.0,
        quantity: 10.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 2),
        lines: [
          AdjustmentLineModel(
            itemId: 'item-slab-1',
            itemIndex: 0,
            description: 'ألواح رخام تركي',
            unit: 'متر',
            quantity: 10.0,
            unitPrice: 100.0,
            amount: 1000.0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      // Rule 1: Client account balance is updated ($600 debt cleared, flips to -$400 credit)
      expect(client.debtBalance, -400.0);
      expect(client.hasCredit, isTrue);
      expect(client.creditOf(AppCurrency.usd), 400.0);

      // Safe untouched
      expect(erp.mainCashBox, initialSafe);

      // Rule 1: Strictly prevent Income Summary impact at return time!
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 0.0);
      expect(erp.incomeSummaryExpensesOf(AppCurrency.usd), initialExpenses);
      expect(erp.incomeSummaryNetProfitOf(AppCurrency.usd), initialNetProfit);
      expect(erp.deferredAdjustmentTotalOf('sales_return', AppCurrency.usd), 1000.0);

      final storedAdj = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(storedAdj.isSettlementDeferred, isTrue);
      expect(storedAdj.deferredAmount, 1000.0);
      expect(storedAdj.realizedAmount, 0.0);

      // Rule 2: Execute cash payout to customer for credit balance ($400)
      final payOk = erp.payCustomerCredit(
        client: client,
        amount: 400.0,
        currency: AppCurrency.usd,
      );
      expect(payOk, isTrue);

      // Safe decreased by $400
      expect(erp.mainCashBox, initialSafe - 400.0);
      expect(client.debtBalance, 0.0);

      // Rule 2: Cash payout formally releases $400 into Income Summary!
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 400.0);
      expect(erp.incomeSummaryExpensesOf(AppCurrency.usd), initialExpenses + 400.0);
      expect(erp.incomeSummaryNetProfitOf(AppCurrency.usd), initialNetProfit - 400.0);
      expect(storedAdj.realizedAmount, 400.0);
      expect(storedAdj.pendingDeferredAmount, 600.0);
    });

    test('3. Immediate Cash Refund return reflects immediately in Income Summary without deferral', () {
      final erp = ERPProvider();
      erp.mainCashBox = 3000.0;
      final initialSafe = erp.mainCashBox;

      final client = ClientModel(
        id: 'cli-cash-1',
        name: 'زبون نقدي',
        phone: '0933221100',
        location: 'حلب',
        clientType: 'زبون معمل',
      );
      erp.clients.add(client);

      final inv = FactoryInvoiceModel(
        id: 'sinv-cash-1',
        invoiceNo: 'SINV-CSH-001',
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        date: DateTime(2026, 10, 1),
        advancePayment: 500.0, // Fully paid cash deposit
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'item-csh-1',
            typeName: 'ألواح',
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 60.0,
            description: 'ألواح',
          ),
        ],
      );
      erp.factoryInvoices.add(inv);

      final initialExpenses = erp.incomeSummaryExpensesOf(AppCurrency.usd);

      // Return $200 with Cash Refund option
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-cash-1',
        invoiceNo: 'SRET-CSH-001',
        module: 'factory',
        kind: 'sales_return',
        partyName: client.name,
        targetInvoiceId: inv.id,
        targetInvoiceNo: inv.invoiceNo,
        description: 'إرجاع مع استرداد نقدي فوري',
        amount: 200.0,
        quantity: 2.0,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 2),
        lines: [
          AdjustmentLineModel(
            itemId: 'item-csh-1',
            itemIndex: 0,
            description: 'ألواح',
            unit: 'متر',
            quantity: 2.0,
            unitPrice: 100.0,
            amount: 200.0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      // Safe decreased by $200
      expect(erp.mainCashBox, initialSafe - 200.0);

      // Reflected immediately in Income Summary
      expect(erp.salesReturnsAndAllowancesOf(AppCurrency.usd), 200.0);
      expect(erp.incomeSummaryExpensesOf(AppCurrency.usd), initialExpenses + 200.0);

      final storedAdj = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(storedAdj.isSettlementDeferred, isFalse);
      expect(storedAdj.realizedAmount, 200.0);
      expect(storedAdj.isFullyRealized, isTrue);
    });

    test('4. Direct execution via processDeferredReturnExecution releases pending amount', () {
      final erp = ERPProvider();
      erp.mainCashBox = 1000.0;
      final initialSafe = erp.mainCashBox;

      final supplier = SupplierModel(
        id: 'sup-direct-1',
        name: 'مورد مباشر',
        phone: '0977889900',
        location: 'اللاذقية',
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'item-dir-1',
          blockCode: 'BLK-DIR-1',
          typeName: 'بلوك',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 5.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      final inv = FactoryInvoiceModel(
        id: 'pinv-dir-1',
        invoiceNo: 'PINV-DIR-001',
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        date: DateTime(2026, 10, 1),
        advancePayment: 500.0,
        currency: AppCurrency.usd,
        items: [
          FactoryInvoiceItem(
            itemId: 'item-dir-1',
            typeName: 'بلوك',
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 80.0,
            description: 'بلوك',
          ),
        ],
      );
      erp.factoryInvoices.add(inv);

      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-dir-1',
        invoiceNo: 'PRET-DIR-001',
        module: 'factory',
        kind: 'purchase_return',
        partyName: supplier.name,
        targetInvoiceId: inv.id,
        targetInvoiceNo: inv.invoiceNo,
        description: 'إرجاع تسوية',
        amount: 300.0,
        quantity: 3.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'item-dir-1',
            itemIndex: 0,
            description: 'بلوك',
            quantity: 3.0,
            unitPrice: 100.0,
            amount: 300.0,
          ),
        ],
      );
      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);
      expect(erp.purchaseReturnsAndAllowances, 0.0);

      // Process direct execution of $200 collection
      final execOk = erp.processDeferredReturnExecution(
        returnIdOrNo: returnDoc.id,
        amount: 200.0,
      );
      expect(execOk, isTrue);

      expect(erp.mainCashBox, initialSafe + 200.0);
      expect(erp.purchaseReturnsAndAllowances, 200.0);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.realizedAmount, 200.0);
      expect(stored.pendingDeferredAmount, 100.0);
    });
  });
}
