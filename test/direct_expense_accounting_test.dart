import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Direct Expense & Cash-Basis Expense Recognition Model Tests', () {
    test('1. Block purchase payment immediately routes to Block Purchase Expense', () {
      final erp = ERPProvider();
      final initialBlockExpense = erp.totalBlockPurchaseExpenses;
      final initialProfit = erp.netOperatingProfit;
      final initialBlocksCount = erp.factoryBlocks.length;

      final supplier = erp.suppliers.first;
      const paymentAmount = 2000.0;

      // Add cash/advance purchase invoice
      final invoice = FactoryInvoiceModel(
        id: 'test_fi_pur',
        invoiceNo: 'PUR-TEST-001',
        date: DateTime.now(),
        partyId: supplier.id,
        partyName: supplier.name,
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'blk_test',
            description: 'كتلة رخام تجريبية',
            typeName: 'رخام أبيض',
            grade: 'نخب أول',
            quantity: 20.0,
            unitPrice: 250.0,
            unitCost: 250.0,
            isGranite: false,
          ),
        ],
        advancePayment: paymentAmount,
        currency: AppCurrency.usd,
      );

      final ok = erp.addSupplierPurchaseInvoice(invoice);
      expect(ok, isTrue);

      // Verify physical block inventory is tracked
      expect(erp.factoryBlocks.length, initialBlocksCount + 1);

      // Verify immediate expense routing
      expect(erp.totalBlockPurchaseExpenses - initialBlockExpense, paymentAmount);

      // Verify Net Profit decreases by the direct expense without waiting for sales
      expect(erp.netOperatingProfit, closeTo(initialProfit - paymentAmount, 0.01));
    });

    test('2. Supplier debt payment immediately routes to Block Purchase Expense', () {
      final erp = ERPProvider();
      final supplier = erp.suppliers.first;
      supplier.debtBalance = 3000.0;

      final initialBlockExpense = erp.totalBlockPurchaseExpenses;
      final initialProfit = erp.netOperatingProfit;
      const payAmount = 1200.0;

      final ok = erp.paySupplierDebt(
        supplier: supplier,
        amount: payAmount,
        currency: AppCurrency.usd,
      );
      expect(ok, isTrue);

      // Verify immediate expense routing in ledger
      expect(erp.totalBlockPurchaseExpenses - initialBlockExpense, payAmount);

      // Verify net profit updates instantly
      expect(erp.netOperatingProfit, closeTo(initialProfit - payAmount, 0.01));
    });

    test('3. Block cutting fee (7%, 8%, 9%) routes immediately to Cutting Expenses', () {
      final erp = ERPProvider();
      final initialCuttingExpense = erp.totalCuttingExpenses;
      final initialProfit = erp.netOperatingProfit;

      // Ensure raw block exists
      erp.factoryBlocks.add(
        FactoryBlockModel(
          id: 'test_blk_cut',
          blockCode: 'BLK-CUT-01',
          typeName: 'رخام تركي',
          grade: 'ممتاز',
          supplierId: 'sup1',
          supplierName: 'مورد تجريبي',
          weightTons: 10.0,
          tonCost: 200.0, // total base cost = 2000 USD
        ),
      );

      // Execute staged cutting at 8% cutting fee
      const feePercent = 0.08;
      const inputTons = 10.0;
      const avgTonCost = 200.0;
      const expectedFee = inputTons * avgTonCost * feePercent; // 160.0 USD

      erp.executeStagedCutting(
        conversions: [
          StagedCutConversion(
            typeName: 'رخام تركي',
            grade: 'ممتاز',
            isGranite: false,
            inputTons: inputTons,
            avgTonCost: avgTonCost,
            feePercent: feePercent,
            thicknessCm: 2.0,
            category: 'متر مربع',
            outputQty: 80.0,
            netCost: 27.0,
            salePrice: 35.0,
          ),
        ],
        wasteValue: 0.0,
      );

      // Verify Cutting Expense increased immediately by exact percentage of ton price
      expect(erp.totalCuttingExpenses - initialCuttingExpense, closeTo(expectedFee, 0.01));

      // Verify Net Profit reduced immediately by cutting fee without waiting for sales
      expect(erp.netOperatingProfit, closeTo(initialProfit - expectedFee, 0.01));

      // Verify warehouse physical inventory is updated
      final whMatches = erp.factoryWarehouse.where((w) => w.typeName == 'رخام تركي');
      expect(whMatches.isNotEmpty, isTrue);
      expect(whMatches.first.availableQty, greaterThanOrEqualTo(80.0));
    });

    test('4. Single cutting operation routes cutting fee (9%) immediately to Cutting Expenses', () {
      final erp = ERPProvider();
      final initialCuttingExpense = erp.totalCuttingExpenses;

      final testBlock = FactoryBlockModel(
        id: 'test_blk_single',
        blockCode: 'BLK-S-01',
        typeName: 'غرانيت هندي',
        grade: 'نخب أول',
        supplierId: 'sup1',
        supplierName: 'مورد تجريبي',
        weightTons: 15.0,
        tonCost: 300.0, // Total cost = 4500 USD
        isGranite: true,
      );
      erp.factoryBlocks.add(testBlock);

      const feePercent = 0.09;
      const expectedFee = 15.0 * 300.0 * 0.09; // 405.0 USD

      erp.executeCuttingOperation(
        selectedBlocks: [testBlock],
        cuttingFeePercent: feePercent,
        targetTypeName: 'غرانيت هندي',
        targetGrade: 'نخب أول',
        thicknessCm: 3.0,
        category: 'متر مربع',
        totalOutputArea: 100.0,
        wasteValue: 0.0,
        recommendedSalePrice: 50.0,
        isGranite: true,
      );

      expect(erp.totalCuttingExpenses - initialCuttingExpense, closeTo(expectedFee, 0.01));
    });

    test('5. Decoupled COGS: Sales accumulate revenue without deferred inventory locking', () {
      final erp = ERPProvider();
      final initialProfit = erp.netOperatingProfit;
      final initialRevenues = erp.totalRevenues;

      // Sell meters to client
      const saleQuantity = 20.0;
      const saleUnitPrice = 45.0; // Total revenue = 900 USD
      const unitCost = 25.0; // Old COGS = 500 USD

      erp.factoryInvoices.add(
        FactoryInvoiceModel(
          id: 'pos_sale_1',
          invoiceNo: 'POS-001',
          date: DateTime.now(),
          partyId: 'client_1',
          partyName: 'عميل معتمد',
          invoiceType: 'بيع_معتمد',
          items: [
            FactoryInvoiceItem(
              itemId: 'fw_item',
              description: 'ألواح رخام',
              quantity: saleQuantity,
              unitPrice: saleUnitPrice,
              unitCost: unitCost,
            ),
          ],
          advancePayment: 900.0,
        ),
      );

      // Verify Revenue increases by full sale amount (900 USD)
      expect(erp.totalRevenues - initialRevenues, closeTo(900.0, 0.01));

      // Under Direct Expense model, Net Profit increases by the full revenue from sale (900 USD)
      // because block cost was recognized at purchase/payment and cutting fee at cutting time.
      expect(erp.netOperatingProfit - initialProfit, closeTo(900.0, 0.01));

      // Verify Net Profit Formula: Net Profit = Total Revenues - Total Direct Expenses
      expect(
        erp.netOperatingProfit,
        closeTo(erp.totalRevenues - erp.totalDirectExpenses, 0.01),
      );
    });
  });
}
