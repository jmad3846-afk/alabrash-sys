import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';
import 'package:marble_granite_erp/widgets/a4_statement_print_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Return Engine & Financial Settlement (States 1-5)', () {
    late ERPProvider erp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      erp = ERPProvider();
      erp.mainCashBox = 1000.0;
      erp.mainCashBoxSyp = 0.0;
    });

    test('State 1: Credit purchase return reduces supplier debt without safe movement', () {
      final supplier = SupplierModel(
        id: 'sup-state1',
        name: 'مورد آجل',
        phone: '0911223344',
        location: 'دمشق',
        debtBalance: 1000.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk-1',
          blockCode: 'BLK-001',
          typeName: 'رخام كاردينال',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 10.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      final invoice = FactoryInvoiceModel(
        id: 'inv-sup-1',
        invoiceNo: 'PINV-001',
        date: DateTime.now(),
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        advancePayment: 0.0,
        items: [
          FactoryInvoiceItem(
            itemId: 'blk-1',
            typeName: 'رخام كاردينال',
            quantity: 10.0, // 10 tons
            unitPrice: 100.0,
            unitCost: 100.0,
            description: 'بلوك كاردينال',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      final initialSafe = erp.mainCashBox;

      // Return 3 tons on credit (debt reduction)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-1',
        invoiceNo: 'RET-001',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: supplier.name,
        description: 'مرتجع بلوكات',
        amount: 300.0,
        quantity: 3.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'blk-1',
            itemIndex: 0,
            description: 'بلوك كاردينال',
            unit: 'طن',
            quantity: 3.0,
            unitPrice: 100.0,
            amount: 300.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Debt reduced by 300
      expect(supplier.debtBalance, 700.0);
      // Safe untouched
      expect(erp.mainCashBox, initialSafe);
    });

    test('State 2a: Fully paid purchase return with cash refund deposits into main safe', () {
      final supplier = SupplierModel(
        id: 'sup-state2a',
        name: 'مورد مسدد كاش',
        phone: '0911223344',
        location: 'دمشق',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk-2',
          blockCode: 'BLK-002',
          typeName: 'رخام موغلا',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 5.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      final invoice = FactoryInvoiceModel(
        id: 'inv-sup-2a',
        invoiceNo: 'PINV-002A',
        date: DateTime.now(),
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        advancePayment: 500.0,
        items: [
          FactoryInvoiceItem(
            itemId: 'blk-2',
            typeName: 'رخام موغلا',
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 100.0,
            description: 'بلوك موغلا',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      final initialSafe = erp.mainCashBox;

      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-2a',
        invoiceNo: 'RET-002A',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: supplier.name,
        description: 'استرداد نقدي من المورد',
        amount: 200.0,
        quantity: 2.0,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'blk-2',
            itemIndex: 0,
            description: 'بلوك موغلا',
            unit: 'طن',
            quantity: 2.0,
            unitPrice: 100.0,
            amount: 200.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Safe increased by 200
      expect(erp.mainCashBox, initialSafe + 200.0);
      expect(supplier.debtBalance, 0.0);
    });

    test('State 2b: Fully paid purchase return converts to permanent credit balance', () {
      final supplier = SupplierModel(
        id: 'sup-state2b',
        name: 'مورد مسدد رصيد دائن',
        phone: '0911223344',
        location: 'دمشق',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk-2b',
          blockCode: 'BLK-002B',
          typeName: 'رخام بيانكو',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 5.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      final invoice = FactoryInvoiceModel(
        id: 'inv-sup-2b',
        invoiceNo: 'PINV-002B',
        date: DateTime.now(),
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        advancePayment: 500.0,
        items: [
          FactoryInvoiceItem(
            itemId: 'blk-2b',
            typeName: 'رخام بيانكو',
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 100.0,
            description: 'بلوك بيانكو',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      final initialSafe = erp.mainCashBox;

      // Settle on account (turning surplus into negative debt = credit balance for supplier)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-2b',
        invoiceNo: 'RET-002B',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: supplier.name,
        description: 'تسوية حساب رصيد دائن',
        amount: 200.0,
        quantity: 2.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'blk-2b',
            itemIndex: 0,
            description: 'بلوك بيانكو',
            unit: 'طن',
            quantity: 2.0,
            unitPrice: 100.0,
            amount: 200.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Debt became negative (-200 = credit balance for supplier)
      expect(supplier.debtBalance, -200.0);
      // Safe untouched
      expect(erp.mainCashBox, initialSafe);
    });

    test('State 3: Partial payment return <= remaining debt updates remaining balance', () {
      final client = ClientModel(
        id: 'cli-state3',
        name: 'عميل دفعة جزئية',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 600.0,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'inv-cli-3',
        invoiceNo: 'SINV-003',
        date: DateTime.now(),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 400.0,
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 50.0,
            description: 'ألواح كاردينال',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Grand total = 1000, advance = 400, remaining = 600
      // Return 300 on account (<= 600 remaining)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-3',
        invoiceNo: 'RET-003',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'مرتجع مبيعات جزئي',
        amount: 300.0,
        quantity: 3.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'ألواح كاردينال',
            unit: 'متر مربع',
            quantity: 3.0,
            unitPrice: 100.0,
            amount: 300.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      expect(client.debtBalance, 300.0);
      expect(invoice.adjustmentsAmount, 300.0);
      expect(invoice.remainingBalance, 300.0);
    });

    test('State 4: Partial payment return > remaining debt clears debt and turns surplus to credit balance', () {
      final client = ClientModel(
        id: 'cli-state4',
        name: 'عميل مرتجع فائض',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 300.0,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'inv-cli-4',
        invoiceNo: 'SINV-004',
        date: DateTime.now(),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 700.0,
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 50.0,
            description: 'ألواح كاردينال',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Total 1000, advance 700, remaining debt 300.
      // Return 500 on account (> 300 remaining)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-4',
        invoiceNo: 'RET-004',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'مرتجع يفيض عن الدين المتبقي',
        amount: 500.0,
        quantity: 5.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'ألواح كاردينال',
            unit: 'متر مربع',
            quantity: 5.0,
            unitPrice: 100.0,
            amount: 500.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Debt 300 - 500 = -200 (credit balance for client)
      expect(client.debtBalance, -200.0);
    });

    test('State 5: Full return with prior deposit neutralizes invoice and converts retained deposit to credit balance', () {
      final client = ClientModel(
        id: 'cli-state5',
        name: 'عميل عربون مرتجع بالكامل',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 600.0, // remaining balance before return
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'inv-cli-5',
        invoiceNo: 'SINV-005',
        date: DateTime.now(),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 400.0, // deposit
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 50.0,
            description: 'ألواح كاردينال',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Full return of 1000 on account clears invoice completely
      // Debt becomes: 600 - 1000 = -400 (retained deposit converted to customer credit balance!)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-5',
        invoiceNo: 'RET-005',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'إرجاع كامل الفاتورة',
        amount: 1000.0,
        quantity: 10.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'ألواح كاردينال',
            unit: 'متر مربع',
            quantity: 10.0,
            unitPrice: 100.0,
            amount: 1000.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      expect(invoice.remainingBalance, 0.0);
      expect(client.debtBalance, -400.0); // Exact retained deposit converted into credit balance!
    });

    test('Sales return cash refund allows safe overdraft', () {
      erp.mainCashBox = 50.0; // low cash balance

      final client = ClientModel(
        id: 'cli-overdraft',
        name: 'عميل كاش أوفر درافت',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'inv-cli-od',
        invoiceNo: 'SINV-OD',
        date: DateTime.now(),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 500.0,
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 5.0,
            unitPrice: 100.0,
            unitCost: 50.0,
            description: 'ألواح كاردينال',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-od',
        invoiceNo: 'RET-OD',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'استرداد نقدي مع سحب على المكشوف',
        amount: 200.0,
        quantity: 2.0,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'ألواح كاردينال',
            unit: 'متر مربع',
            quantity: 2.0,
            unitPrice: 100.0,
            amount: 200.0,
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Safe overdraft: 50 - 200 = -150
      expect(erp.mainCashBox, -150.0);
    });
  });

  group('Damaged Goods Routing (isDamaged flag)', () {
    late ERPProvider erp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      erp = ERPProvider();
    });

    test('Damaged goods bypass sellable stock and route directly to wasteLogs as abnormal waste', () {
      final initialWasteCount = erp.wasteLogs.length;
      final initialWarehouseQty = erp.factoryWarehouse.first.availableQty;

      final client = ClientModel(
        id: 'cli-dmg',
        name: 'عميل مرتجع تالف',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 100.0,
      );
      erp.clients.add(client);

      final invoice = FactoryInvoiceModel(
        id: 'inv-dmg',
        invoiceNo: 'SINV-DMG',
        date: DateTime.now(),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 0.0,
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 5.0,
            unitPrice: 20.0,
            unitCost: 10.0,
            description: 'رخام مستودع',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-dmg-1',
        invoiceNo: 'RET-DMG-01',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: client.name,
        description: 'مرتجع تالف متكسر أثناء الشحن',
        amount: 40.0,
        quantity: 2.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'رخام مستودع',
            unit: 'متر مربع',
            quantity: 2.0,
            unitPrice: 20.0,
            amount: 40.0,
            isDamaged: true, // Damaged flag set
          ),
        ],
      );

      final success = erp.addAdjustmentInvoice(returnDoc);
      expect(success, isTrue);

      // Sellable warehouse stock NOT increased
      expect(erp.factoryWarehouse.first.availableQty, initialWarehouseQty);

      // Logged into wasteLogs as abnormal waste
      expect(erp.wasteLogs.length, initialWasteCount + 1);
      final wasteEntry = erp.wasteLogs.last;
      expect(wasteEntry.wasteType, 'هدر غير طبيعي');
      expect(wasteEntry.destructionVoucherNo, contains('إتلاف-مرتجع'));
      expect(wasteEntry.sourceSection, contains('مستودع المصنع'));
    });
  });

  group('Statement of Account Engine & Reporting', () {
    late ERPProvider erp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      erp = ERPProvider();
    });

    test('Preserves immutable original invoice figures and creates independent return rows', () {
      final supplier = SupplierModel(
        id: 'sup-soa',
        name: 'مورد كشف الحساب',
        phone: '0911223344',
        location: 'دمشق',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk-soa',
          blockCode: 'BLK-SOA-1',
          typeName: 'رخام تركي',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 10.0,
          tonCost: 100.0,
          tonSellingPrice: 150.0,
        ),
      );

      final invoice = FactoryInvoiceModel(
        id: 'inv-sup-soa',
        invoiceNo: 'PINV-SOA-01',
        date: DateTime(2026, 10, 1),
        invoiceType: 'شراء_مورد',
        partyId: supplier.id,
        partyName: supplier.name,
        advancePayment: 0.0,
        items: [
          FactoryInvoiceItem(
            itemId: 'blk-soa',
            typeName: 'رخام تركي',
            quantity: 10.0,
            unitPrice: 100.0,
            unitCost: 100.0,
            description: 'بلوك تركي',
          ),
        ],
      );
      erp.factoryInvoices.add(invoice);

      // Full return of 1000 on account clears debt to 0
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret-soa-1',
        invoiceNo: 'RET-SOA-01',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: invoice.id,
        targetInvoiceNo: invoice.invoiceNo,
        partyName: supplier.name,
        description: 'إرجاع البلوك بالكامل',
        amount: 1000.0,
        quantity: 10.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 2),
        lines: [
          AdjustmentLineModel(
            itemId: 'blk-soa',
            itemIndex: 0,
            description: 'بلوك تركي',
            unit: 'طن',
            quantity: 10.0,
            unitPrice: 100.0,
            amount: 1000.0,
          ),
        ],
      );
      final addSuccess = erp.addAdjustmentInvoice(returnDoc);
      expect(addSuccess, isTrue);

      final statement = A4StatementData.fromSupplier(
        supplier: supplier,
        erp: erp,
      );

      // Statement should have 2 items: original invoice and return row
      expect(statement.items.length, 2);

      // Original invoice row maintains true historical remaining balance
      final invRow = statement.items.firstWhere((i) => !i.isReturn);
      expect(invRow.totalAmount, 1000.0);
      expect(invRow.paidAmount, 0.0);
      expect(invRow.remainingAmount, 1000.0); // True historical remaining balance before return!
      expect(invRow.status, 'مصفى بالمرتجعات');

      // Independent return row
      final retRow = statement.items.firstWhere((i) => i.isReturn);
      expect(retRow.totalAmount, 1000.0);
      expect(retRow.paidAmount, 0.0); // No cash moved
      expect(retRow.remainingAmount, 0.0);
      expect(retRow.status, 'مرتجع مسوى');

      // Account status displays 'مصفى بالمرتجعات'
      expect(statement.isClearedViaReturns, isTrue);
      expect(statement.totalReturnsUsd, 1000.0);
      expect(statement.totalPaidUsd, 0.0);
    });

    test('Statement of account reflects returns across accreditedAgent, customer, and project', () {
      final client = ClientModel(
        id: 'cli-multi',
        name: 'عميل شامل',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final factoryInv = FactoryInvoiceModel(
        id: 'f-inv-1',
        invoiceNo: 'F-INV-1',
        date: DateTime(2026, 10, 1),
        invoiceType: 'بيع_معتمد',
        partyId: client.id,
        partyName: client.name,
        advancePayment: 0.0,
        items: [
          FactoryInvoiceItem(
            itemId: erp.factoryWarehouse.first.id,
            typeName: erp.factoryWarehouse.first.typeName,
            quantity: 5.0,
            unitPrice: 50.0,
            unitCost: 30.0,
            description: 'ألواح مستودع',
          ),
        ],
      );
      erp.factoryInvoices.add(factoryInv);

      final retAdj = AdjustmentInvoiceModel(
        id: 'f-ret-1',
        invoiceNo: 'F-RET-1',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: factoryInv.id,
        targetInvoiceNo: factoryInv.invoiceNo,
        partyName: client.name,
        description: 'مرتجع معتمد',
        amount: 250.0,
        quantity: 5.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 2),
        lines: [
          AdjustmentLineModel(
            itemId: erp.factoryWarehouse.first.id,
            itemIndex: 0,
            description: 'ألواح مستودع',
            unit: 'متر مربع',
            quantity: 5.0,
            unitPrice: 50.0,
            amount: 250.0,
          ),
        ],
      );
      final ok1 = erp.addAdjustmentInvoice(retAdj);
      expect(ok1, isTrue);

      final agentStatement = A4StatementData.fromAccreditedAgent(
        client: client,
        erp: erp,
      );
      expect(agentStatement.items.any((i) => i.isReturn), isTrue);
      expect(agentStatement.isClearedViaReturns, isTrue);

      // Workshop customer statement
      final workshopInv = WorkshopInvoiceModel(
        id: 'w-inv-1',
        invoiceNo: 'W-INV-1',
        date: DateTime(2026, 10, 3),
        clientName: client.name,
        agreedPrice: 300.0,
        depositDeducted: 0.0,
        cashPaidNow: 0.0,
        netCost: 150.0,
        items: [
          WorkshopInvoiceItem(
            id: 'wi-1',
            sourceType: 'تفصيل بسيط',
            description: 'درج رخام',
            quantity: 3.0,
            unitPrice: 100.0,
            agreedPrice: 300.0,
          ),
        ],
      );
      erp.workshopInvoices.add(workshopInv);

      final wRetAdj = AdjustmentInvoiceModel(
        id: 'w-ret-1',
        invoiceNo: 'W-RET-1',
        module: 'workshop',
        kind: 'sales_return',
        targetInvoiceId: workshopInv.id,
        targetInvoiceNo: workshopInv.invoiceNo,
        partyName: client.name,
        description: 'مرتجع ورشة',
        amount: 300.0,
        quantity: 3.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        date: DateTime(2026, 10, 4),
        lines: [
          AdjustmentLineModel(
            itemId: 'wi-1',
            itemIndex: 0,
            description: 'درج رخام',
            unit: 'متر مربع',
            quantity: 3.0,
            unitPrice: 100.0,
            amount: 300.0,
          ),
        ],
      );
      final ok2 = erp.addAdjustmentInvoice(wRetAdj);
      expect(ok2, isTrue);

      final customerStatement = A4StatementData.fromCustomer(
        client: client,
        erp: erp,
      );
      expect(customerStatement.items.any((i) => i.isReturn), isTrue);
      expect(customerStatement.isClearedViaReturns, isTrue);
    });
  });
}
