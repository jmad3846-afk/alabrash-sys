import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marble_granite_erp/core/database/erp_provider.dart';
import 'package:marble_granite_erp/core/models/models.dart';

ERPProvider createERP() {
  final erp = ERPProvider();
  erp.mainCashBox = 0.0;
  erp.scrapCashBox = 0.0;
  erp.orderCashBox = 0.0;
  erp.factoryInvoices.clear();
  erp.workshopInvoices.clear();
  erp.suppliers.clear();
  erp.clients.clear();
  erp.adjustmentInvoices.clear();
  erp.returnInvoices.clear();
  erp.factoryBlocks.clear();
  return erp;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Earned Discounts (الخصم المكتسب - للموردين) on Purchase Invoices', () {
    test('1. Purchase invoice with earned discount: Safe Isolation & Zero False Income on unpaid transaction', () {
      final erp = createERP();
      erp.mainCashBox = 500.0;
      final supplier = SupplierModel(
        id: 'sup_test_1',
        name: 'شركة رخام الجبال',
        phone: '123456',
        location: 'دمشق',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      final purchaseInvoice = FactoryInvoiceModel(
        id: 'pi_disc_1',
        invoiceNo: 'PI-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1',
            typeName: 'بلوك كاردينال 1',
            description: 'بلوك كاردينال 1',
            quantity: 5, // 5 blocks
            unitPrice: 200, // 200 each = 1,000 gross
            unitCost: 200,
          ),
        ],
        discountAmount: 100.0, // 100 earned discount
        advancePayment: 0.0, // full credit (unpaid)
        currency: AppCurrency.usd,
      );

      // Verify gross, net, and discount multiplier
      expect(purchaseInvoice.grossTotal, 1000.0);
      expect(purchaseInvoice.grandTotal, 900.0);
      expect(purchaseInvoice.discountRatio, closeTo(0.9, 0.0001));
      expect(purchaseInvoice.hasDiscount, isTrue);

      final added = erp.addSupplierPurchaseInvoice(purchaseInvoice);
      expect(added, isTrue);

      // 1. Safe Isolation: creating discount on unpaid invoice produces 0 zero cash safe movement
      expect(erp.mainCashBox, 500.0);
      expect(erp.scrapCashBox, 0.0);

      // 2. Account Ledger: Supplier debt must strictly reflect discounted total ($900), not gross ($1,000)
      expect(supplier.debtOf(AppCurrency.usd), 900.0);

      // 3. Ledger balances
      expect(erp.supplierDiscountsOf(AppCurrency.usd), 100.0);
      expect(erp.activeSupplierDiscountsOf(AppCurrency.usd), 100.0);
      expect(erp.nominalSupplierDiscountsOf(AppCurrency.usd), 100.0);
      expect(erp.returnedSupplierDiscountsOf(AppCurrency.usd), 0.0);

      // 4. Zero False Income: Unpaid purchase discount MUST NOT produce fake cash revenue in P&L
      expect(erp.realizedSupplierDiscountsOf(AppCurrency.usd), 0.0);
      expect(erp.totalRevenuesOf(AppCurrency.usd), 0.0);
    });

    test('1b. Supplier payment realizes earned discount in P&L and updates safe accurately', () {
      final erp = createERP();
      erp.mainCashBox = 1000.0;
      final supplier = SupplierModel(
        id: 'sup_test_1b',
        name: 'شركة رخام الجبال',
        phone: '123456',
        location: 'دمشق',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      final purchaseInvoice = FactoryInvoiceModel(
        id: 'pi_disc_1b',
        invoiceNo: 'PI-001B',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'item_1b',
            typeName: 'بلوك كاردينال',
            description: 'بلوك كاردينال',
            quantity: 5,
            unitPrice: 200, // 1000 gross
            unitCost: 200,
          ),
        ],
        discountAmount: 100.0, // 100 earned discount -> Net is 900
        advancePayment: 0.0, // unpaid
        currency: AppCurrency.usd,
      );
      erp.addSupplierPurchaseInvoice(purchaseInvoice);

      expect(erp.mainCashBox, 1000.0); // 0 movement on invoice creation
      expect(erp.realizedSupplierDiscountsOf(AppCurrency.usd), 0.0); // 0 false revenue

      // Pay the net discounted debt ($900)
      final paid = erp.paySupplierInvoice(purchaseInvoice, 900.0);
      expect(paid, isTrue);

      // Safe strictly decrements by 900
      expect(erp.mainCashBox, 100.0);
      // Supplier debt cleared to 0
      expect(supplier.debtOf(AppCurrency.usd), 0.0);
      // Earned discount is now formally realized in Income Summary
      expect(erp.realizedSupplierDiscountsOf(AppCurrency.usd), 100.0);
      expect(erp.totalRevenuesOf(AppCurrency.usd), 100.0);
    });

    test('2. Purchase return with earned discount strictly uses net effective price (ratio) and reverses discount share', () {
      final erp = createERP();
      final supplier = SupplierModel(
        id: 'sup_test_2',
        name: 'شركة الحجر الممتاز',
        phone: '123456',
        location: 'اللاذقية',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk_test_2',
          blockCode: 'BLK-002',
          typeName: 'بلوك مرمر يوناني',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 10.0,
          tonCost: 100.0,
          tonSellingPrice: 100.0,
        ),
      );

      final purchaseInvoice = FactoryInvoiceModel(
        id: 'pi_disc_2',
        invoiceNo: 'PI-002',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'blk_test_2',
            typeName: 'بلوك مرمر يوناني',
            grade: 'درجة أولى',
            description: 'بلوك مرمر يوناني',
            quantity: 10,
            unitPrice: 100, // 10 * 100 = 1,000 gross
            unitCost: 100,
          ),
        ],
        discountAmount: 100.0, // 100 discount -> Net is 900 -> ratio = 0.9
        advancePayment: 0.0,
        currency: AppCurrency.usd,
      );
      erp.addSupplierPurchaseInvoice(purchaseInvoice);
      expect(supplier.debtOf(AppCurrency.usd), 900.0);

      // Return 2 blocks (gross value = 2 * 100 = 200).
      // Net effective return price MUST be 100 * 0.9 = $90 per block.
      // Total return amount MUST be 2 * $90 = $180, NEVER raw $200!
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_pi_2',
        invoiceNo: 'RET-PI-002',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: purchaseInvoice.id,
        targetInvoiceNo: purchaseInvoice.invoiceNo,
        partyName: supplier.name,
        description: 'إرجاع قطعتين معيبتين',
        amount: 0.0, // derived by engine
        quantity: 2.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'blk_test_2',
            itemIndex: 0,
            description: 'بلوك مرمر يوناني',
            quantity: 2,
            unitPrice: 0, // derived by engine
            amount: 0,
          ),
        ],
      );

      final processed = erp.addAdjustmentInvoice(returnDoc);
      expect(processed, isTrue);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.lines.first.rawUnitPrice, 100.0);
      expect(stored.lines.first.discountRatio, closeTo(0.9, 0.0001));
      expect(stored.lines.first.unitPrice, 90.0); // Effective net price!
      expect(stored.amount, 180.0); // 2 * 90 = 180!

      // Supplier debt: 900 - 180 = 720 (exactly matches the remaining 8 blocks at $90 each!)
      expect(supplier.debtOf(AppCurrency.usd), 720.0);

      // Earned Discount Ledger:
      // Original was $100.
      // Returned fraction: 180 / 900 = 20% of invoice returned.
      // Remaining active earned discount: 100 * (1 - 0.2) = $80!
      expect(erp.supplierDiscountsOf(AppCurrency.usd), 80.0);
      expect(erp.activeSupplierDiscountsOf(AppCurrency.usd), 80.0);
      expect(erp.returnedSupplierDiscountsOf(AppCurrency.usd), 20.0);
      expect(erp.nominalSupplierDiscountsOf(AppCurrency.usd), 100.0);
    });

    test('3. 100% full purchase return clears supplier debt to zero and completely reverses earned discount', () {
      final erp = createERP();
      final supplier = SupplierModel(
        id: 'sup_test_3',
        name: 'مقالع الشمال',
        phone: '123456',
        location: 'حلب',
        debtBalance: 0.0,
      );
      erp.suppliers.add(supplier);

      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'blk_test_3',
          blockCode: 'BLK-003',
          typeName: 'بلوك أسود بازلت',
          grade: 'درجة أولى',
          supplierId: supplier.id,
          supplierName: supplier.name,
          weightTons: 4.0,
          tonCost: 250.0,
          tonSellingPrice: 250.0,
        ),
      );

      final purchaseInvoice = FactoryInvoiceModel(
        id: 'pi_disc_3',
        invoiceNo: 'PI-003',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'blk_test_3',
            typeName: 'بلوك أسود بازلت',
            grade: 'درجة أولى',
            description: 'بلوك أسود بازلت',
            quantity: 4,
            unitPrice: 250, // 4 * 250 = 1,000 gross
            unitCost: 250,
          ),
        ],
        discountAmount: 200.0, // 200 discount -> Net is 800 -> ratio = 0.8
        advancePayment: 0.0,
        currency: AppCurrency.usd,
      );
      erp.addSupplierPurchaseInvoice(purchaseInvoice);
      expect(supplier.debtOf(AppCurrency.usd), 800.0);

      // Return all 4 blocks (gross = 1,000 -> net return = 1,000 * 0.8 = 800)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_pi_3',
        invoiceNo: 'RET-PI-003',
        module: 'factory',
        kind: 'purchase_return',
        targetInvoiceId: purchaseInvoice.id,
        targetInvoiceNo: purchaseInvoice.invoiceNo,
        partyName: supplier.name,
        description: 'إرجاع كامل الشحنة',
        amount: 0.0,
        quantity: 4.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'blk_test_3',
            itemIndex: 0,
            description: 'بلوك أسود بازلت',
            quantity: 4,
            unitPrice: 0,
            amount: 0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.amount, 800.0); // exactly matches net grandTotal
      expect(supplier.debtOf(AppCurrency.usd), 0.0); // clears debt 100%
      expect(erp.supplierDiscountsOf(AppCurrency.usd), 0.0); // fully reversed!
      expect(erp.returnedSupplierDiscountsOf(AppCurrency.usd), 200.0);
    });
  });

  group('Allowed Discounts (الخصم الممنوح - للمبيعات) on Sales Invoices', () {
    test('4. Dealer Sales invoice with allowed discount reflects net receivable and contra-revenue in P&L', () {
      final erp = createERP();
      final client = ClientModel(
        id: 'cli_dealer_1',
        name: 'معتمد حمص المعتمد',
        phone: '111111',
        location: 'حمص',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final saleInvoice = FactoryInvoiceModel(
        id: 'si_disc_1',
        invoiceNo: 'FAC-SALE-001',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'tile_1',
            typeName: 'ألواح رخام تركي 2سم',
            description: 'ألواح رخام تركي 2سم',
            lengthCm: 200,
            widthCm: 100,
            heightCm: 2,
            quantity: 10, // 20 m²
            unitPrice: 50, // 20 * 50 = 1,000 gross
            unitCost: 20,
          ),
        ],
        discountAmount: 100.0, // 100 discount -> Net = 900
        advancePayment: 450.0, // 50% paid now
        currency: AppCurrency.usd,
      );

      expect(saleInvoice.grossTotal, 1000.0);
      expect(saleInvoice.grandTotal, 900.0);
      expect(saleInvoice.discountRatio, closeTo(0.9, 0.0001));

      final added = erp.addFactoryPOSInvoice(saleInvoice);
      expect(added, isTrue);

      // Remaining receivable from client: 900 - 450 = 450
      expect(client.debtOf(AppCurrency.usd), 450.0);

      // Cash collected revenue = 450
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd), 450.0);

      // Allowed discount ledger records 100 active
      expect(erp.activeSalesDiscountsOf(AppCurrency.usd), 100.0);

      // Realized allowed discount proportional to 50% cash collected: 100 * 50% = 50
      expect(erp.factorySalesDiscountOf(AppCurrency.usd), 50.0);
    });

    test('4b. Unpaid credit sales invoice produces ZERO safe movement and records allowed discount immediately in ledger', () {
      final erp = createERP();
      erp.mainCashBox = 500.0;
      final client = ClientModel(
        id: 'cli_unpaid_1',
        name: 'معتمد اللاذقية',
        phone: '55555',
        location: 'اللاذقية',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final saleInvoice = FactoryInvoiceModel(
        id: 'si_unpaid_1',
        invoiceNo: 'FAC-UNPAID-01',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'tile_u1',
            typeName: 'رخام أبيض',
            description: 'رخام أبيض',
            quantity: 10,
            unitPrice: 100, // 1000 gross
            unitCost: 40,
          ),
        ],
        discountAmount: 150.0, // 150 allowed discount -> Net = 850
        advancePayment: 0.0, // 100% on credit (unpaid)
        currency: AppCurrency.usd,
      );

      final added = erp.addFactoryPOSInvoice(saleInvoice);
      expect(added, isTrue);

      // 1. Safe Isolation: ZERO safe movement on unpaid sale with discount
      expect(erp.mainCashBox, 500.0);

      // 2. Net Receivable: Client debt is strictly the discounted net amount ($850)
      expect(client.debtOf(AppCurrency.usd), 850.0);

      // 3. Allowed Discount Ledger: active allowed discount recorded immediately
      expect(erp.nominalSalesDiscountsOf(AppCurrency.usd), 150.0);
      expect(erp.activeSalesDiscountsOf(AppCurrency.usd), 150.0);
      expect(erp.returnedSalesDiscountsOf(AppCurrency.usd), 0.0);

      // 4. Zero cash collected revenue on unpaid sale
      expect(erp.totalFactoryRevenueOf(AppCurrency.usd), 0.0);
    });

    test('5. Sales return with allowed discount strictly uses net effective price to prevent financial leakage', () {
      final erp = createERP();
      final client = ClientModel(
        id: 'cli_dealer_2',
        name: 'معتمد طرطوس',
        phone: '222222',
        location: 'طرطوس',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final saleInvoice = FactoryInvoiceModel(
        id: 'si_disc_2',
        invoiceNo: 'FAC-SALE-002',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'tile_2',
            typeName: 'ألواح كاردينال مصقول',
            description: 'ألواح كاردينال مصقول',
            lengthCm: 100,
            widthCm: 100,
            heightCm: 2,
            quantity: 10, // 10 m²
            unitPrice: 100, // 10 * 100 = 1,000 gross
            unitCost: 40,
          ),
        ],
        discountAmount: 200.0, // $200 discount -> Net is $800 -> ratio = 0.8 (20% discount)
        advancePayment: 800.0, // Paid in full
        currency: AppCurrency.usd,
      );
      erp.addFactoryPOSInvoice(saleInvoice);
      expect(client.debtOf(AppCurrency.usd), 0.0);

      // Customer returns 4 m² (gross was 4 * 100 = $400).
      // Return price MUST be 100 * 0.8 = $80 per m²!
      // Total return amount MUST be 4 * $80 = $320, NEVER pre-discount $400!
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_sale_2',
        invoiceNo: 'RET-SALE-002',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: saleInvoice.id,
        targetInvoiceNo: saleInvoice.invoiceNo,
        partyName: client.name,
        description: 'إرجاع 4 أمتار مربعة',
        amount: 0.0,
        quantity: 4.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'tile_2',
            itemIndex: 0,
            description: 'ألواح كاردينال مصقول',
            quantity: 4,
            unitPrice: 0,
            amount: 0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.lines.first.rawUnitPrice, 100.0);
      expect(stored.lines.first.discountRatio, closeTo(0.8, 0.0001));
      expect(stored.lines.first.unitPrice, 80.0); // Effective net unit price!
      expect(stored.amount, 320.0); // 4 * 80 = 320!

      // Client had 0 debt, so return creates a credit balance for the client of $320 (client.debtBalance = -320)
      expect(client.debtOf(AppCurrency.usd), -320.0);

      // Income Summary Allowed Discount Reversal:
      // Total discount was $200.
      // Return was 320 / 800 = 40% of the sale.
      // Active non-returned sale: 60%.
      // Realized allowed discount must now be: 200 * 60% = $120 (the $80 share on returned goods is reversed!)
      expect(erp.factorySalesDiscountOf(AppCurrency.usd), 120.0);
      expect(erp.activeSalesDiscountsOf(AppCurrency.usd), 120.0);
      expect(erp.returnedSalesDiscountsOf(AppCurrency.usd), 80.0);
    });

    test('6. Workshop retail sales invoice with allowed discount applies proportional return correctly', () {
      final erp = createERP();
      final workshopInvoice = WorkshopInvoiceModel(
        id: 'wrk_inv_disc_1',
        invoiceNo: 'WRK-001',
        date: DateTime.now(),
        clientName: 'أبو أحمد الدمشقي',
        agreedPrice: 500.0, // 500 gross
        salesDiscount: 50.0, // 50 discount -> Net is 450 -> ratio = 0.9
        depositDeducted: 0.0,
        cashPaidNow: 450.0, // paid in full
        netCost: 200.0,
        sourceQuantity: 5.0, // 5 pieces at $100 gross
        currency: AppCurrency.usd,
        items: [
          WorkshopInvoiceItem(
            id: 'w_item_1',
            sourceType: 'تفصيل بسيط',
            description: 'مغاسل رخام مفصلة',
            quantity: 5.0,
            agreedPrice: 500.0,
            netCost: 200.0,
          ),
        ],
      );

      expect(workshopInvoice.grossTotal, 500.0);
      expect(workshopInvoice.grandTotal, 450.0);
      expect(workshopInvoice.discountRatio, closeTo(0.9, 0.0001));

      erp.workshopInvoices.add(workshopInvoice);

      // Return 2 pieces (gross 200 -> net return = 200 * 0.9 = 180)
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_wrk_1',
        invoiceNo: 'RET-WRK-001',
        module: 'workshop',
        kind: 'sales_return',
        targetInvoiceId: workshopInvoice.id,
        targetInvoiceNo: workshopInvoice.invoiceNo,
        partyName: workshopInvoice.clientName,
        description: 'إرجاع مغسلتين',
        amount: 0.0,
        quantity: 2.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'w_item_1',
            itemIndex: 0,
            description: 'مغاسل رخام مفصلة',
            quantity: 2,
            unitPrice: 0,
            amount: 0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.lines.first.rawUnitPrice, 100.0);
      expect(stored.lines.first.unitPrice, 90.0); // 100 * 0.9
      expect(stored.amount, 180.0);

      // Discount reversal:
      // Original discount was $50.
      // 40% returned (180 / 450 = 0.40).
      // Remaining active allowed discount: 50 * 0.60 = $30!
      expect(erp.workshopSalesDiscountOf(AppCurrency.usd), 30.0);
      expect(erp.activeSalesDiscountsOf(AppCurrency.usd), 30.0);
      expect(erp.returnedSalesDiscountsOf(AppCurrency.usd), 20.0);
    });

    test('7. Multi-line invoice with discount applies proportional ratio across every line item', () {
      final erp = createERP();
      final client = ClientModel(
        id: 'cli_multi',
        name: 'شركة الإعمار والتشييد',
        phone: '999999',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
      );
      erp.clients.add(client);

      // Multi-line invoice:
      // Line 1: 10 m² at $50 = $500
      // Line 2: 20 m² at $25 = $500
      // Total Gross = $1,000
      // Discount = $100 (10%) -> Net Total = $900 -> ratio = 0.9
      final saleInvoice = FactoryInvoiceModel(
        id: 'si_multi_disc',
        invoiceNo: 'FAC-MULTI-01',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'm_line_1',
            typeName: 'رخام روزا برتغالي',
            description: 'رخام روزا برتغالي',
            lengthCm: 100,
            widthCm: 100,
            heightCm: 2,
            quantity: 10,
            unitPrice: 50,
            unitCost: 20,
          ),
          FactoryInvoiceItem(
            itemId: 'm_line_2',
            typeName: 'درج كاردينال جاهز',
            description: 'درج كاردينال جاهز',
            lengthCm: 100,
            widthCm: 100,
            heightCm: 2,
            quantity: 20,
            unitPrice: 25,
            unitCost: 10,
          ),
        ],
        discountAmount: 100.0,
        advancePayment: 900.0,
        currency: AppCurrency.usd,
      );
      erp.addFactoryPOSInvoice(saleInvoice);

      // Return 2 m² from Line 1 (raw $50 -> net $45) and 4 m² from Line 2 (raw $25 -> net $22.50)
      // Line 1 return amount: 2 * 45 = 90
      // Line 2 return amount: 4 * 22.50 = 90
      // Total return amount: 180
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_multi_1',
        invoiceNo: 'RET-MULTI-01',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: saleInvoice.id,
        targetInvoiceNo: saleInvoice.invoiceNo,
        partyName: client.name,
        description: 'إرجاع بنود متعددة',
        amount: 0.0,
        quantity: 6.0,
        paymentAction: 'تخفيض دين',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'm_line_1',
            itemIndex: 0,
            description: 'رخام روزا برتغالي',
            quantity: 2,
            unitPrice: 0,
            amount: 0,
          ),
          AdjustmentLineModel(
            itemId: 'm_line_2',
            itemIndex: 1,
            description: 'درج كاردينال جاهز',
            quantity: 4,
            unitPrice: 0,
            amount: 0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.lines[0].unitPrice, 45.0);
      expect(stored.lines[0].amount, 90.0);
      expect(stored.lines[1].unitPrice, 22.5);
      expect(stored.lines[1].amount, 90.0);
      expect(stored.amount, 180.0);
    });

    test('8. Safe Isolation on Unpaid Return: return on unpaid invoice moves ZERO cash from safe and reduces debt', () {
      final erp = createERP();
      erp.mainCashBox = 500.0;
      final client = ClientModel(
        id: 'cli_ret_unpaid',
        name: 'معتمد دمشق',
        phone: '33333',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 0.0,
      );
      erp.clients.add(client);

      final saleInvoice = FactoryInvoiceModel(
        id: 'si_ret_unpaid',
        invoiceNo: 'FAC-RET-UNPAID',
        date: DateTime.now(),
        partyId: client.id,
        partyName: client.name,
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'tile_ret_1',
            typeName: 'رخام كريم مارفل',
            description: 'رخام كريم مارفل',
            quantity: 10,
            unitPrice: 100, // 1000 gross
            unitCost: 40,
          ),
        ],
        discountAmount: 200.0, // 200 discount -> 800 net -> ratio = 0.8
        advancePayment: 0.0, // Unpaid
        currency: AppCurrency.usd,
      );
      erp.addFactoryPOSInvoice(saleInvoice);
      expect(erp.mainCashBox, 500.0);
      expect(client.debtOf(AppCurrency.usd), 800.0);

      // Return 2 units even though user chose cashAction ('استرداد نقدي')
      // Strict cash cap ensures ZERO cash is refunded because 0 was deposited!
      final returnDoc = AdjustmentInvoiceModel(
        id: 'ret_unpaid_1',
        invoiceNo: 'RET-UNPAID-01',
        module: 'factory',
        kind: 'sales_return',
        targetInvoiceId: saleInvoice.id,
        targetInvoiceNo: saleInvoice.invoiceNo,
        partyName: client.name,
        description: 'إرجاع فاتورة غير مسددة',
        amount: 0.0,
        quantity: 2.0,
        paymentAction: 'استرداد نقدي للصندوق الرئيسي',
        currency: AppCurrency.usd,
        lines: [
          AdjustmentLineModel(
            itemId: 'tile_ret_1',
            itemIndex: 0,
            description: 'رخام كريم مارفل',
            quantity: 2,
            unitPrice: 0,
            amount: 0,
          ),
        ],
      );

      final ok = erp.addAdjustmentInvoice(returnDoc);
      expect(ok, isTrue);

      // Safe is strictly UNTOUCHED (0 zero movement)
      expect(erp.mainCashBox, 500.0);

      // Return net amount = 2 * (100 * 0.8) = 160
      final stored = erp.adjustmentInvoices.firstWhere((a) => a.id == returnDoc.id);
      expect(stored.amount, 160.0);
      expect(stored.cashAmount, 0.0); // 0 cash!
      expect(stored.deferredAmount, 160.0); // routed to debt reduction!

      // Client debt reduced: 800 - 160 = 640
      expect(client.debtOf(AppCurrency.usd), 640.0);

      // Real-time Income Summary & Ledger Sync:
      // Nominal was 200. Returned share is 20% (160 / 800) = 40.
      // Active non-returned allowed discount is now 160!
      expect(erp.activeSalesDiscountsOf(AppCurrency.usd), 160.0);
      expect(erp.returnedSalesDiscountsOf(AppCurrency.usd), 40.0);
    });
  });
}
