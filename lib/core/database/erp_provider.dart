import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ERPProvider extends ChangeNotifier {
  // Opening Entry
  late OpeningEntryModel openingEntry;

  // System Factory Reset bookkeeping
  // Incremented every time a full wipe is executed so the UI can redirect.
  int factoryResetTick = 0;
  // Mirrors the Opening Entry lock state (is_opening_entry_completed).
  bool isOpeningEntryCompleted = true;

  // Partners
  List<PartnerModel> partners = [];

  // Granite Accountant Profit Percentage & Withdrawals
  double graniteAccountantPercentage = 50.0;
  List<AccountantWithdrawalModel> accountantWithdrawals = [];

  // Isolated Cash Registers — each box holds TWO funds:
  // a Dollar fund ($) and a Syrian fund (SYP ل.س). Legacy fields are USD.
  double mainCashBox = 45000.0;
  double scrapCashBox = 8500.0;
  double orderCashBox = 3200.0;
  double mainCashBoxSyp = 0.0;
  double scrapCashBoxSyp = 0.0;
  double orderCashBoxSyp = 0.0;

  /// Balance of a box ('main' | 'scrap' | 'order') in the given currency.
  double cashOf(String box, String? currency) {
    final syp = AppCurrency.isSyp(currency);
    switch (box) {
      case 'scrap':
        return syp ? scrapCashBoxSyp : scrapCashBox;
      case 'order':
        return syp ? orderCashBoxSyp : orderCashBox;
      default:
        return syp ? mainCashBoxSyp : mainCashBox;
    }
  }

  /// Adds cash to a box fund. Amount must be > 0.
  void addCash(String box, String? currency, double amount) {
    if (amount <= 0) return;
    final syp = AppCurrency.isSyp(currency);
    switch (box) {
      case 'scrap':
        if (syp) {
          scrapCashBoxSyp += amount;
        } else {
          scrapCashBox += amount;
        }
        break;
      case 'order':
        if (syp) {
          orderCashBoxSyp += amount;
        } else {
          orderCashBox += amount;
        }
        break;
      default:
        if (syp) {
          mainCashBoxSyp += amount;
        } else {
          mainCashBox += amount;
        }
    }
  }

  /// Takes cash from a box fund when the balance covers it, or when [allowNegative]
  /// is true (strictly for Sidebar Expenses and Supplier Payments overdraft).
  bool takeCash(String box, String? currency, double amount, {bool allowNegative = false}) {
    if (amount <= 0) return false;
    final syp = AppCurrency.isSyp(currency);
    switch (box) {
      case 'scrap':
        if (syp) {
          if (!allowNegative && scrapCashBoxSyp + 0.0001 < amount) return false;
          scrapCashBoxSyp -= amount;
        } else {
          if (!allowNegative && scrapCashBox + 0.0001 < amount) return false;
          scrapCashBox -= amount;
        }
        return true;
      case 'order':
        if (syp) {
          if (!allowNegative && orderCashBoxSyp + 0.0001 < amount) return false;
          orderCashBoxSyp -= amount;
        } else {
          if (!allowNegative && orderCashBox + 0.0001 < amount) return false;
          orderCashBox -= amount;
        }
        return true;
      default:
        if (syp) {
          if (!allowNegative && mainCashBoxSyp + 0.0001 < amount) return false;
          mainCashBoxSyp -= amount;
        } else {
          if (!allowNegative && mainCashBox + 0.0001 < amount) return false;
          mainCashBox -= amount;
        }
        return true;
    }
  }

  String get dualMainCash => AppCurrency.dual(mainCashBox, mainCashBoxSyp);
  String get dualScrapCash => AppCurrency.dual(scrapCashBox, scrapCashBoxSyp);
  String get dualOrderCash => AppCurrency.dual(orderCashBox, orderCashBoxSyp);

  /// Direct transfer between cash boxes of the same currency.
  /// [fromBox] and [toBox] are 'main' | 'scrap' | 'order'.
  bool transferCash({
    required String fromBox,
    required String toBox,
    required String currency,
    required double amount,
  }) {
    if (amount <= 0 || fromBox == toBox) return false;
    if (!takeCash(fromBox, currency, amount)) return false;
    addCash(toBox, currency, amount);
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Converts currency between funds/cash boxes.
  /// [fromCurrency]: 'USD' or 'SYP'
  /// If [fromCurrency] == 'USD', converts to SYP: converted = amount * exchangeRate.
  /// If [fromCurrency] == 'SYP', converts to USD: converted = amount / exchangeRate.
  bool convertCurrency({
    required String fromBox,
    required String toBox,
    required String fromCurrency,
    required double amount,
    required double exchangeRate,
  }) {
    if (amount <= 0 || exchangeRate <= 0) return false;
    final toCurrency =
        AppCurrency.isSyp(fromCurrency) ? AppCurrency.usd : AppCurrency.syp;
    final double convertedAmount = AppCurrency.isSyp(fromCurrency)
        ? (amount / exchangeRate)
        : (amount * exchangeRate);

    if (!takeCash(fromBox, fromCurrency, amount)) return false;
    addCash(toBox, toCurrency, convertedAmount);
    notifyListeners();
    saveToDisk();
    return true;
  }

  // Printer Status
  bool isThermalPrinterConnected = true;
  String printerName = "Xprinter XP-N160II (Esc/POS Thermal)";

  // Entities lists
  List<SupplierModel> suppliers = [];
  List<ClientModel> clients = [];
  List<BlockTypeModel> blockTypes = [];
  List<MeterTypeModel> meterTypes = [];
  List<FactoryBlockModel> factoryBlocks = [];
  List<FactoryWarehouseModel> factoryWarehouse = [];
  List<CuttingOperationModel> cuttingOperations = [];
  List<FactoryInvoiceModel> factoryInvoices = [];
  List<FactoryOrderModel> factoryOrders = [];

  // Workshop Workspace lists
  List<WorkshopStockModel> workshopStock = [];
  List<WorkshopTailoringModel> simpleTailorings = [];
  List<WorkshopTailoringModel> complexTailorings = [];
  List<ScrapItemModel> scrapItems = [];
  // Surplus Financials ledger: worker wages + general expenses per surplus item.
  // Settled ONLY from the Surplus Fund (scrapCashBox).
  List<SurplusCostModel> surplusCosts = [];
  List<WasteLogModel> wasteLogs = [];
  List<WorkshopOrderModel> workshopOrders = [];
  List<WorkshopInvoiceModel> workshopInvoices = [];
  List<WorkshopProjectModel> workshopProjects = [];

  // Services Center
  List<ServiceItemModel> services = [];

  // Staff & Workdays
  List<StaffTypeModel> staffTypes = [];
  List<StaffModel> staffList = [];
  List<StaffAttendanceModel> staffAttendance = [];
  List<WorkdayEntryModel> workdayEntries = [];
  List<AdvanceRepaymentModel> advanceRepayments = [];
  late DateTime activeWorkweekStart;

  // Returns Log
  List<ReturnInvoiceModel> returnInvoices = [];
  List<ExpenseTypeModel> expenseTypes = [];
  List<ExpenseRecordModel> expenseRecords = [];
  List<AssetSaleRecordModel> assetSaleRecords = [];
  List<CapitalInjectionRecordModel> capitalInjections = [];
  List<AdjustmentInvoiceModel> adjustmentInvoices = [];
  CenterInfoModel centerInfo = const CenterInfoModel();

  // Daily Reports Archive
  List<DailyReportModel> dailyReports = [];

  static const String blockPurchaseExpenseTypeId = 'block_purchases_expense';
  static const String cuttingExpenseTypeId = 'cutting_processing_expense';

  // Realized Cash-Collected Revenue: unallocated debt settlements (opening / historical customer balances)
  double unallocatedFactoryCollectionsUsd = 0.0;
  double unallocatedFactoryCollectionsSyp = 0.0;
  double unallocatedWorkshopCollectionsUsd = 0.0;
  double unallocatedWorkshopCollectionsSyp = 0.0;

  ERPProvider() {
    _initDefaultSeedData();
    loadFromDisk();
  }

  // -------------------------------------------------------------
  // SEED DATA INITIALIZATION
  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // SEED DATA INITIALIZATION
  // -------------------------------------------------------------
  void _initDefaultSeedData() {
    openingEntry = OpeningEntryModel(
      landValue: 120000.0,
      buildingsValue: 85000.0,
      machineryValue: 95000.0,
      vehiclesValue: 35000.0,
      mainCashValue: 45000.0,
      scrapCashValue: 8500.0,
      inventoryValue: 110000.0,
      customerDebtsValue: 28000.0,
      supplierPayablesValue: 42000.0,
      workerSalariesValue: 9500.0,
      hassanRatio: 0.42,
      adnanRatio: 0.35,
      abdelMoeenRatio: 0.23,
      isLocked: true,
    );

    partners = [
      PartnerModel(
        id: 'p1',
        name: 'الشريك حسان',
        ratio: 0.42,
        injectedCapital: 168000.0,
      ),
      PartnerModel(
        id: 'p2',
        name: 'الشريك عدنان',
        ratio: 0.35,
        injectedCapital: 140000.0,
      ),
      PartnerModel(
        id: 'p3',
        name: 'الشريك عبد المعين',
        ratio: 0.23,
        injectedCapital: 92000.0,
      ),
    ];

    suppliers = [
      SupplierModel(
        id: 'sup1',
        name: 'شركة مقالع الرخام الوطنية',
        phone: '0944112233',
        location: 'اللاذقية',
        debtBalance: 25000.0,
      ),
      SupplierModel(
        id: 'sup2',
        name: 'مؤسسة الغرانيت المستورد',
        phone: '0933556677',
        location: 'طرطوس',
        debtBalance: 17000.0,
      ),
      SupplierModel(
        id: 'sup3',
        name: 'مورد البلوكات التركية',
        phone: '0955889900',
        location: 'حلب',
        debtBalance: 0.0,
      ),
    ];

    clients = [
      ClientModel(
        id: 'cli1',
        name: 'شركة العمران للمقاولات',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 18500.0,
      ),
      ClientModel(
        id: 'cli2',
        name: 'المتعهد أحمد الشيخ',
        phone: '0922334455',
        location: 'حمص',
        clientType: 'مشروع معمل',
        debtBalance: 9500.0,
      ),
      ClientModel(
        id: 'cli3',
        name: 'الزبون سامر المحمود',
        phone: '0966778899',
        location: 'دمشق',
        clientType: 'زبون معمل',
        debtBalance: 0.0,
      ),
    ];

    blockTypes = [
      BlockTypeModel(
        id: 'bt1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        isGranite: false,
      ),
      BlockTypeModel(
        id: 'bt2',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        isGranite: true,
      ),
      BlockTypeModel(
        id: 'bt3',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة ثانية',
        isGranite: false,
      ),
      BlockTypeModel(
        id: 'bt4',
        typeName: 'غرانيت روزا بيتا',
        grade: 'درجة أولى',
        isGranite: true,
      ),
    ];

    meterTypes = [
      MeterTypeModel(
        id: 'mt1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        isGranite: false,
      ),
      MeterTypeModel(
        id: 'mt2',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 3.0,
        category: 'متر مربع',
        isGranite: false,
      ),
      MeterTypeModel(
        id: 'mt3',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        isGranite: true,
      ),
      MeterTypeModel(
        id: 'mt4',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة أولى',
        thicknessCm: 10.0,
        category: 'متر مكعب',
        isGranite: false,
      ),
    ];

    factoryBlocks = [
      FactoryBlockModel(
        id: 'fb1',
        blockCode: 'BLK-101',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        supplierId: 'sup1',
        supplierName: 'شركة مقالع الرخام الوطنية',
        weightTons: 24.5,
        tonCost: 110.0,
        isGranite: false,
      ),
      FactoryBlockModel(
        id: 'fb2',
        blockCode: 'BLK-102',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        supplierId: 'sup2',
        supplierName: 'مؤسسة الغرانيت المستورد',
        weightTons: 18.0,
        tonCost: 220.0,
        isGranite: true,
      ),
      FactoryBlockModel(
        id: 'fb3',
        blockCode: 'BLK-103',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة ثانية',
        supplierId: 'sup1',
        supplierName: 'شركة مقالع الرخام الوطنية',
        weightTons: 30.0,
        tonCost: 95.0,
        isGranite: false,
      ),
    ];

    factoryWarehouse = [
      FactoryWarehouseModel(
        id: 'fw1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 450.0,
        netCostPerUnit: 14.5,
        recommendedSalePrice: 22.0,
        isGranite: false,
      ),
      FactoryWarehouseModel(
        id: 'fw2',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 320.0,
        netCostPerUnit: 21.0,
        recommendedSalePrice: 30.0,
        isGranite: false,
      ),
      FactoryWarehouseModel(
        id: 'fw3',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 180.0,
        netCostPerUnit: 35.0,
        recommendedSalePrice: 55.0,
        isGranite: true,
      ),
      FactoryWarehouseModel(
        id: 'fw4',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة أولى',
        thicknessCm: 8.0,
        category: 'متر مكعب',
        availableQty: 45.0,
        netCostPerUnit: 120.0,
        recommendedSalePrice: 180.0,
        isGranite: false,
      ),
    ];

    cuttingOperations = [
      CuttingOperationModel(
        id: 'cut1',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        inputTons: 20.0,
        baseTonCost: 110.0,
        cuttingFeePercentage: 0.08,
        targetTypeName: 'رخام كاردينال',
        targetGrade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        totalOutputArea: 160.0,
        netCostPerUnit: 14.85,
        recommendedSalePrice: 22.0,
        wasteValue: 45.0,
        isGranite: false,
      ),
    ];

    factoryInvoices = [
      FactoryInvoiceModel(
        id: 'fi1',
        invoiceNo: 'FAC-2026-001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        partyId: 'cli1',
        partyName: 'شركة العمران للمقاولات',
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'fw1',
            description: 'رخام كاردينال 2سم',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            lengthCm: 200,
            widthCm: 100,
            quantity: 10,
            unitPrice: 22.0,
            unitCost: 14.5,
            isGranite: false,
          ),
          FactoryInvoiceItem(
            itemId: 'fw3',
            description: 'غرانيت أسود جالكسي 3سم',
            typeName: 'غرانيت أسود جالكسي',
            grade: 'ممتاز',
            lengthCm: 150,
            widthCm: 80,
            quantity: 5,
            unitPrice: 55.0,
            unitCost: 35.0,
            isGranite: true,
          ),
        ],
        services: [
          ServiceAttachment(
            serviceName: 'شطف حواف وتفريز',
            price: 120.0,
            notes: 'شطف دبل',
          ),
        ],
        shippingFee: 150.0,
        isGoodsDelivered: true,
        advancePayment: 500.0,
        paymentStatus: 'يجب تحصيل دفعة',
      ),
    ];

    workshopStock = [
      WorkshopStockModel(
        id: 'ws1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 85.0,
        netCostPerUnit: 14.5,
        recommendedSalePrice: 24.0,
        isGranite: false,
      ),
      WorkshopStockModel(
        id: 'ws2',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 40.0,
        netCostPerUnit: 35.0,
        recommendedSalePrice: 60.0,
        isGranite: true,
      ),
    ];

    simpleTailorings = [
      WorkshopTailoringModel(
        id: 'st1',
        name: 'درج كاردينال مع قائم',
        complexity: 'بسيط',
        rawMaterialDescription: 'رخام كاردينال 3سم',
        lengthCm: 120,
        widthCm: 33,
        quantity: 5.94,
        materialNetCost: 124.7,
        unitCategory: 'متر مربع',
        measurementCount: 15,
        laborCostPerMeter: 12.6262626263,
        attachedServices: [
          ServiceAttachment(serviceName: 'جلي وتلميع', price: 45.0),
        ],
        sellingPrice: 808.0808080808,
        isGranite: false,
      ),
    ];

    complexTailorings = [
      WorkshopTailoringModel(
        id: 'ct1',
        name: 'مغسلة رخام كاردينال محفورة',
        complexity: 'معقد',
        rawMaterialDescription: 'كتلة رخام كاردينال 10سم',
        lengthCm: 100,
        widthCm: 50,
        heightCm: 15,
        quantity: 0.075,
        materialNetCost: 160.0,
        unitCategory: 'متر مكعب',
        measurementCount: 1,
        laborCostPerMeter: 800.0,
        attachedServices: [
          ServiceAttachment(serviceName: 'ثقب وتفريغ مغاسل', price: 30.0),
        ],
        sellingPrice: 6000.0,
        isGranite: false,
      ),
    ];

    scrapItems = [
      ScrapItemModel(
        id: 'sc1',
        description: 'قصاصات مغاسل كاردينال (25*40سم)',
        baseCost: 15.0,
        sellingPrice: 40.0,
        isSold: false,
      ),
      ScrapItemModel(
        id: 'sc2',
        description: 'قطع غرانيت سوداء لزوايا العتب',
        baseCost: 20.0,
        sellingPrice: 55.0,
        isSold: false,
      ),
    ];

    wasteLogs = [
      WasteLogModel(
        id: 'wl1',
        date: DateTime.now().subtract(const Duration(days: 4)),
        wasteType: 'هدر طبيعي',
        itemDescription: 'كسور حواف أثناء التقطيع',
        quantity: 2.5,
        cost: 35.0,
      ),
      WasteLogModel(
        id: 'wl2',
        date: DateTime.now().subtract(const Duration(days: 1)),
        wasteType: 'هدر غير طبيعي',
        itemDescription: 'سقوط ألواح من الرافعة',
        quantity: 1.0,
        cost: 210.0,
        destructionVoucherNo: 'VOUCH-8821',
      ),
    ];

    workshopOrders = [
      WorkshopOrderModel(
        id: 'wo1',
        orderNo: 'ORD-901',
        date: DateTime.now().subtract(const Duration(days: 1)),
        clientName: 'الدكتور طارق العلي',
        clientPhone: '0944887766',
        customDimensionsText: 'طاولة غرانيت أسود 220*110سم مع حفر بروفايل',
        agreedPrice: 750.0,
        depositAmount: 300.0,
        status: 'قيد التنفيذ',
      ),
    ];

    workshopInvoices = [
      WorkshopInvoiceModel(
        id: 'wi1',
        invoiceNo: 'WRK-2026-001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        clientName: 'المهندس رامي زريق',
        sourceType: 'تفصيل بسيط',
        itemDescription: 'درج كاردينال 120سم (10 درجات)',
        agreedPrice: 280.0,
        depositDeducted: 50.0,
        cashPaidNow: 230.0,
        netCost: 160.0,
        isGranite: false,
      ),
    ];

    services = [
      ServiceItemModel(
        id: 'srv1',
        name: 'جلي وتلميع رخام',
        unitRate: 4.0,
        description: 'حساب للمتر المربع',
      ),
      ServiceItemModel(
        id: 'srv2',
        name: 'شطف حواف وتفريز',
        unitRate: 3.5,
        description: 'حساب للمتر الطولي',
      ),
      ServiceItemModel(
        id: 'srv3',
        name: 'نقل وتوصيل بالكرين',
        unitRate: 75.0,
        description: 'حساب للرحلة',
      ),
      ServiceItemModel(
        id: 'srv4',
        name: 'قص وزوايا معقدة',
        unitRate: 8.0,
        description: 'حساب للقطعة',
      ),
      ServiceItemModel(
        id: 'srv5',
        name: 'ثقب وتفريغ مغاسل',
        unitRate: 15.0,
        description: 'حساب للفتحة',
      ),
    ];

    staffList = [
      StaffModel(
        id: 'stf1',
        name: 'المعلم أبو حيدر (قصاص)',
        category: 'معلمين',
        phone: '0933111222',
        totalEarned: 1450.0,
        cashAdvancesDisbursed: 400.0,
      ),
      StaffModel(
        id: 'stf2',
        name: 'العامل ياسين (تحميل وتنزيل)',
        category: 'عمال',
        phone: '0944222333',
        typeId: 'staff_type_worker_general',
        totalEarned: 850.0,
        cashAdvancesDisbursed: 200.0,
      ),
      StaffModel(
        id: 'stf3',
        name: 'المحاسب نزار (إداري)',
        category: 'إداريين',
        phone: '0955333444',
        typeId: 'staff_type_admin_general',
        totalEarned: 2100.0,
        cashAdvancesDisbursed: 500.0,
      ),
    ];

    staffTypes = [
      StaffTypeModel(
        id: 'staff_type_worker_general',
        category: 'عمال',
        name: 'عمال عامون',
        dailyRate: 45,
      ),
      StaffTypeModel(
        id: 'staff_type_admin_general',
        category: 'إداريين',
        name: 'إداريون عامون',
        dailyRate: 45,
      ),
    ];
    activeWorkweekStart = _startOfWorkweek(DateTime.now());

    workdayEntries = [
      WorkdayEntryModel(
        id: 'wde1',
        date: DateTime.now(),
        staffNames: ['المعلم أبو حيدر (قصاص)', 'العامل ياسين (تحميل وتنزيل)'],
        workDescription: 'قص 3 بلوكات كاردينال وتنزيل ألواح المعمل',
        rateType: 'حساب يومية',
        agreedAmountPerPerson: 45.0,
      ),
    ];

    returnInvoices = [
      ReturnInvoiceModel(
        id: 'ret1',
        returnNo: 'RET-001',
        date: DateTime.now().subtract(const Duration(days: 5)),
        returnType: 'مرتجع مشتريات مورد',
        partyName: 'شركة مقالع الرخام الوطنية',
        itemDescription: 'بلوك كاردينال فيه تشققات سرية',
        quantity: 12.0,
        refundAmount: 1320.0,
        paymentAction: 'تخفيض دين',
      ),
    ];
  }

  /// Populates comprehensive test data across 100% of the software's interfaces
  /// including the Opening Entry (Fixed Assets, Opening Stock, Legacy Debts, Partners),
  /// Factory, Workshop, Accounting, Workforce, Operations, and Daily Reports.
  Future<void> populateComprehensiveSeedData({bool lockOpeningEntry = true}) async {
    _applyComprehensiveSeedData(lockOpeningEntry: lockOpeningEntry);
    await saveToDisk();
    notifyListeners();
  }

  void _applyComprehensiveSeedData({bool lockOpeningEntry = true}) {
    // 1. Master Catalogs (Block & Meter Types)
    blockTypes = [
      BlockTypeModel(
        id: 'bt1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        isGranite: false,
      ),
      BlockTypeModel(
        id: 'bt2',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        isGranite: true,
      ),
      BlockTypeModel(
        id: 'bt3',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة ثانية',
        isGranite: false,
      ),
      BlockTypeModel(
        id: 'bt4',
        typeName: 'غرانيت روزا بيتا',
        grade: 'درجة أولى',
        isGranite: true,
      ),
      BlockTypeModel(
        id: 'bt5',
        typeName: 'رخام بيانكو إيطالي',
        grade: 'نخب أول',
        isGranite: false,
      ),
    ];

    meterTypes = [
      MeterTypeModel(
        id: 'mt1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        isGranite: false,
      ),
      MeterTypeModel(
        id: 'mt2',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 3.0,
        category: 'متر مربع',
        isGranite: false,
      ),
      MeterTypeModel(
        id: 'mt3',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        isGranite: true,
      ),
      MeterTypeModel(
        id: 'mt4',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة أولى',
        thicknessCm: 10.0,
        category: 'متر مكعب',
        isGranite: false,
      ),
      MeterTypeModel(
        id: 'mt5',
        typeName: 'رخام بيانكو إيطالي',
        grade: 'نخب أول',
        thicknessCm: 2.0,
        category: 'متر مربع',
        isGranite: false,
      ),
    ];

    // 2. Workshop Tailoring Catalogs (needed for Opening Stock cross-referencing)
    simpleTailorings = [
      WorkshopTailoringModel(
        id: 'st1',
        name: 'درج كاردينال مع قائم',
        complexity: 'بسيط',
        rawMaterialDescription: 'رخام كاردينال 3سم',
        lengthCm: 120,
        widthCm: 33,
        quantity: 5.94,
        materialNetCost: 124.7,
        unitCategory: 'متر مربع',
        measurementCount: 15,
        laborCostPerMeter: 12.6,
        attachedServices: [
          ServiceAttachment(serviceName: 'جلي وتلميع', price: 45.0),
        ],
        sellingPrice: 800.0,
        isGranite: false,
      ),
      WorkshopTailoringModel(
        id: 'st2',
        name: 'نعلات مشطوفة رخام كاردينال',
        complexity: 'بسيط',
        rawMaterialDescription: 'رخام كاردينال 2سم',
        lengthCm: 100,
        widthCm: 10,
        quantity: 12.0,
        materialNetCost: 48.0,
        unitCategory: 'متر طولي',
        measurementCount: 20,
        laborCostPerMeter: 3.5,
        attachedServices: [
          ServiceAttachment(serviceName: 'شطف حواف وتفريز', price: 25.0),
        ],
        sellingPrice: 180.0,
        isGranite: false,
      ),
    ];

    complexTailorings = [
      WorkshopTailoringModel(
        id: 'ct1',
        name: 'مغسلة رخام كاردينال محفورة',
        complexity: 'معقد',
        rawMaterialDescription: 'كتلة رخام كاردينال 10سم',
        lengthCm: 100,
        widthCm: 50,
        heightCm: 15,
        quantity: 0.075,
        materialNetCost: 160.0,
        unitCategory: 'متر مكعب',
        measurementCount: 1,
        laborCostPerMeter: 800.0,
        attachedServices: [
          ServiceAttachment(serviceName: 'ثقب وتفريغ مغاسل', price: 30.0),
        ],
        sellingPrice: 420.0,
        isGranite: false,
      ),
    ];

    // 3. Opening Entry (القيد الافتتاحي المتكامل)
    final fixedAssetsList = [
      FixedAssetModel(
        id: 'fa_1',
        category: 'أراضي',
        name: 'أرض المصنع والمستودع الرئيسي',
        amount: 120000.0,
        description: 'مساحة 5000 متر مربع في المنطقة الصناعية',
        currency: AppCurrency.usd,
      ),
      FixedAssetModel(
        id: 'fa_2',
        category: 'مباني',
        name: 'هنغار الإنتاج والمكاتب الإدارية',
        amount: 85000.0,
        description: 'هنغار معدني معزول ومبنى إدارة طابقين',
        currency: AppCurrency.usd,
      ),
      FixedAssetModel(
        id: 'fa_3',
        category: 'آلات ومعدات',
        name: 'جلاية إيطالية ماركة سيميوني',
        amount: 55000.0,
        description: 'جلاية خط أوتوماتيكية 16 رأس',
        currency: AppCurrency.usd,
      ),
      FixedAssetModel(
        id: 'fa_4',
        category: 'آلات ومعدات',
        name: 'رافعة جسرية علوية 25 طن',
        amount: 40000.0,
        description: 'رافعة تفريغ وتحميل كتل الرخام الكبيرة',
        currency: AppCurrency.usd,
      ),
      FixedAssetModel(
        id: 'fa_5',
        category: 'سيارات وآليات',
        name: 'شاحنة كيا فوتون مجهزة بحامل رخام',
        amount: 35000.0,
        description: 'شاحنة نقل للألواح والطلبيات',
        currency: AppCurrency.usd,
      ),
      FixedAssetModel(
        id: 'fa_6',
        category: 'أثاث ومفروشات',
        name: 'تجهيزات مكتبية ومكيفات الإدارة',
        amount: 15000.0,
        description: 'مكاتب خشبية، حواسب، ومكيفات صالة العرض',
        currency: AppCurrency.usd,
      ),
    ];

    final openingStockList = [
      OpeningStockItemModel(
        id: 'os_1',
        category: 'بلوكات خام المصنع',
        typeName: 'رخام كاردينال',
        typeId: 'bt1',
        grade: 'درجة أولى',
        isGranite: false,
        supplierName: 'شركة مقالع الرخام الوطنية',
        quantity: 24.5,
        unitPrice: 110.0,
        sellingPrice: 160.0,
        currency: AppCurrency.usd,
        description: 'كتلة رخام كاردينال نخب أول',
      ),
      OpeningStockItemModel(
        id: 'os_2',
        category: 'بلوكات خام المصنع',
        typeName: 'غرانيت أسود جالكسي',
        typeId: 'bt2',
        grade: 'ممتاز',
        isGranite: true,
        supplierName: 'مؤسسة الغرانيت المستورد',
        quantity: 18.0,
        unitPrice: 220.0,
        sellingPrice: 310.0,
        currency: AppCurrency.usd,
        description: 'كتلة غرانيت أسود جالكسي هندي',
      ),
      OpeningStockItemModel(
        id: 'os_3',
        category: 'أمتار المصنع',
        typeName: 'رخام كاردينال',
        typeId: 'mt1',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        isGranite: false,
        quantity: 450.0,
        unitPrice: 14.5,
        sellingPrice: 22.0,
        currency: AppCurrency.usd,
        description: 'ألواح رخام كاردينال سماكة 2سم جاهزة',
      ),
      OpeningStockItemModel(
        id: 'os_4',
        category: 'أمتار المصنع',
        typeName: 'رخام كاردينال',
        typeId: 'mt2',
        grade: 'درجة أولى',
        thicknessCm: 3.0,
        isGranite: false,
        quantity: 320.0,
        unitPrice: 21.0,
        sellingPrice: 30.0,
        currency: AppCurrency.usd,
        description: 'ألواح رخام كاردينال سماكة 3سم جاهزة',
      ),
      OpeningStockItemModel(
        id: 'os_5',
        category: 'أمتار المصنع',
        typeName: 'غرانيت أسود جالكسي',
        typeId: 'mt3',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        isGranite: true,
        quantity: 180.0,
        unitPrice: 35.0,
        sellingPrice: 55.0,
        currency: AppCurrency.usd,
        description: 'ألواح غرانيت أسود جالكسي سماكة 3سم',
      ),
      OpeningStockItemModel(
        id: 'os_6',
        category: 'أمتار المعمل',
        typeName: 'رخام كاردينال',
        typeId: 'mt1',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        isGranite: false,
        quantity: 85.0,
        unitPrice: 14.5,
        sellingPrice: 24.0,
        currency: AppCurrency.usd,
        description: 'ألواح مخصصة لورشة المعمل',
      ),
      OpeningStockItemModel(
        id: 'os_7',
        category: 'تفصيل بسيط',
        typeName: 'درج كاردينال مع قائم',
        typeId: 'st1',
        quantity: 15.0,
        unitPrice: 25.0,
        sellingPrice: 45.0,
        currency: AppCurrency.usd,
        description: 'درجات جاهزة للتسليم مع القائم',
      ),
      OpeningStockItemModel(
        id: 'os_8',
        category: 'تفصيل معقد',
        typeName: 'مغسلة رخام كاردينال محفورة',
        typeId: 'ct1',
        quantity: 2.0,
        unitPrice: 250.0,
        sellingPrice: 420.0,
        currency: AppCurrency.usd,
        description: 'مغاسل رخامية محفورة يدوي مع عزل',
      ),
      OpeningStockItemModel(
        id: 'os_9',
        category: 'قطع زائدة وخردة',
        typeName: 'قصاصات مغاسل كاردينال (25*40سم)',
        quantity: 20.0,
        unitPrice: 15.0,
        sellingPrice: 35.0,
        currency: AppCurrency.usd,
        description: 'قصاصات صالحة لأعمال الديكور والعتب',
      ),
    ];

    final legacyFinancialsList = [
      LegacyFinancialRecordModel(
        id: 'leg_c1',
        category: 'clients',
        name: 'شركة العمران للمقاولات',
        phone: '0911223344',
        currency: AppCurrency.usd,
        amount: 18500.0,
        description: 'رصيد سابق مدور من العام الماضي',
      ),
      LegacyFinancialRecordModel(
        id: 'leg_c2',
        category: 'clients',
        name: 'المتعهد أحمد الشيخ',
        phone: '0922334455',
        currency: AppCurrency.syp,
        amount: 12000000.0,
        description: 'ذمة سابقة لأعمال أبراج الياسمين',
      ),
      LegacyFinancialRecordModel(
        id: 'leg_s1',
        category: 'suppliers',
        name: 'شركة مقالع الرخام الوطنية',
        phone: '0944112233',
        currency: AppCurrency.usd,
        amount: 25000.0,
        description: 'مستحقات توريد كتل سابقة',
      ),
      LegacyFinancialRecordModel(
        id: 'leg_s2',
        category: 'suppliers',
        name: 'مؤسسة الغرانيت المستورد',
        phone: '0933556677',
        currency: AppCurrency.usd,
        amount: 17000.0,
        description: 'دفعات حاويات غرانيت مؤجلة',
      ),
      LegacyFinancialRecordModel(
        id: 'leg_e1',
        category: 'employees',
        name: 'مستحقات نهاية خدمة عمال سابقة',
        phone: '',
        currency: AppCurrency.usd,
        amount: 9500.0,
        description: 'مخصصات عمال مدورة',
      ),
    ];

    openingEntry = OpeningEntryModel(
      landValue: 120000.0,
      buildingsValue: 85000.0,
      machineryValue: 95000.0,
      vehiclesValue: 35000.0,
      furnitureValue: 15000.0,
      mainCashValue: 45000.0,
      scrapCashValue: 8500.0,
      orderCashValue: 4200.0,
      mainCashValueSyp: 15000000.0,
      scrapCashValueSyp: 2500000.0,
      orderCashValueSyp: 3000000.0,
      inventoryValue: 110000.0,
      customerDebtsValue: 28000.0,
      supplierPayablesValue: 42000.0,
      workerSalariesValue: 9500.0,
      fixedAssets: fixedAssetsList,
      openingStock: openingStockList,
      legacyFinancials: legacyFinancialsList,
      hassanRatio: 0.42,
      adnanRatio: 0.35,
      abdelMoeenRatio: 0.23,
      isLocked: lockOpeningEntry,
      lockedAt: lockOpeningEntry ? DateTime.now() : null,
      openingStockApplied: lockOpeningEntry,
    );
    isOpeningEntryCompleted = lockOpeningEntry;

    // 4. Partner Setup matching Opening Equity
    final totalEquity = openingEntry.totalEquity;
    final totalEquitySyp = openingEntry.totalEquitySyp;

    partners = [
      PartnerModel(
        id: 'p1',
        name: 'الشريك حسان',
        ratio: 0.42,
        injectedCapital: totalEquity * 0.42,
        injectedCapitalSyp: totalEquitySyp * 0.42,
      ),
      PartnerModel(
        id: 'p2',
        name: 'الشريك عدنان',
        ratio: 0.35,
        injectedCapital: totalEquity * 0.35,
        injectedCapitalSyp: totalEquitySyp * 0.35,
      ),
      PartnerModel(
        id: 'p3',
        name: 'الشريك عبد المعين',
        ratio: 0.23,
        injectedCapital: totalEquity * 0.23,
        injectedCapitalSyp: totalEquitySyp * 0.23,
      ),
    ];

    // 5. Dual-Currency Cash Boxes
    mainCashBox = 45000.0;
    scrapCashBox = 8500.0;
    orderCashBox = 4200.0;
    mainCashBoxSyp = 15000000.0;
    scrapCashBoxSyp = 2500000.0;
    orderCashBoxSyp = 3000000.0;
    graniteAccountantPercentage = 0.05;
    accountantWithdrawals = [];

    // 6. External Parties (Suppliers & Clients)
    suppliers = [
      SupplierModel(
        id: 'sup1',
        name: 'شركة مقالع الرخام الوطنية',
        phone: '0944112233',
        location: 'اللاذقية',
        debtBalance: 25000.0,
      ),
      SupplierModel(
        id: 'sup2',
        name: 'مؤسسة الغرانيت المستورد',
        phone: '0933556677',
        location: 'طرطوس',
        debtBalance: 17000.0,
      ),
      SupplierModel(
        id: 'sup3',
        name: 'مورد البلوكات التركية',
        phone: '0955889900',
        location: 'حلب',
        debtBalance: 0.0,
      ),
    ];

    clients = [
      ClientModel(
        id: 'cli1',
        name: 'شركة العمران للمقاولات',
        phone: '0911223344',
        location: 'دمشق',
        clientType: 'معتمد مصنع',
        debtBalance: 18500.0,
        currencyClassification: AppCurrency.usd,
      ),
      ClientModel(
        id: 'cli2',
        name: 'المتعهد أحمد الشيخ',
        phone: '0922334455',
        location: 'حمص',
        clientType: 'مشروع معمل',
        debtBalance: 9500.0,
        currencyClassification: AppCurrency.usd,
      ),
      ClientModel(
        id: 'cli3',
        name: 'المهندس رامي زريق',
        phone: '0944887766',
        location: 'ريف دمشق',
        clientType: 'مشروع معمل',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.usd,
      ),
      ClientModel(
        id: 'cli4',
        name: 'الزبون سامر المحمود',
        phone: '0966778899',
        location: 'دمشق',
        clientType: 'زبون معمل',
        debtBalance: 0.0,
        currencyClassification: AppCurrency.syp,
      ),
    ];

    // 7. Factory Physical Inventory
    factoryBlocks = [
      FactoryBlockModel(
        id: 'fb1',
        blockCode: 'BLK-101',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        supplierId: 'sup1',
        supplierName: 'شركة مقالع الرخام الوطنية',
        weightTons: 24.5,
        tonCost: 110.0,
        isGranite: false,
      ),
      FactoryBlockModel(
        id: 'fb2',
        blockCode: 'BLK-102',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        supplierId: 'sup2',
        supplierName: 'مؤسسة الغرانيت المستورد',
        weightTons: 18.0,
        tonCost: 220.0,
        isGranite: true,
      ),
      FactoryBlockModel(
        id: 'fb3',
        blockCode: 'BLK-103',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة ثانية',
        supplierId: 'sup1',
        supplierName: 'شركة مقالع الرخام الوطنية',
        weightTons: 30.0,
        tonCost: 95.0,
        isGranite: false,
      ),
    ];

    factoryWarehouse = [
      FactoryWarehouseModel(
        id: 'fw1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 450.0,
        netCostPerUnit: 14.5,
        recommendedSalePrice: 22.0,
        isGranite: false,
      ),
      FactoryWarehouseModel(
        id: 'fw2',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 320.0,
        netCostPerUnit: 21.0,
        recommendedSalePrice: 30.0,
        isGranite: false,
      ),
      FactoryWarehouseModel(
        id: 'fw3',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 180.0,
        netCostPerUnit: 35.0,
        recommendedSalePrice: 55.0,
        isGranite: true,
      ),
      FactoryWarehouseModel(
        id: 'fw4',
        typeName: 'رخام أبيض ترافنتينو',
        grade: 'درجة أولى',
        thicknessCm: 8.0,
        category: 'متر مكعب',
        availableQty: 45.0,
        netCostPerUnit: 120.0,
        recommendedSalePrice: 180.0,
        isGranite: false,
      ),
    ];

    cuttingOperations = [
      CuttingOperationModel(
        id: 'cut1',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        inputTons: 20.0,
        baseTonCost: 110.0,
        cuttingFeePercentage: 0.08,
        targetTypeName: 'رخام كاردينال',
        targetGrade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        totalOutputArea: 160.0,
        netCostPerUnit: 14.85,
        recommendedSalePrice: 22.0,
        wasteValue: 45.0,
        isGranite: false,
      ),
    ];

    factoryInvoices = [
      FactoryInvoiceModel(
        id: 'fi_pur1',
        invoiceNo: 'PUR-2026-001',
        date: DateTime.now().subtract(const Duration(days: 6)),
        partyId: 'sup1',
        partyName: 'شركة مقالع الرخام الوطنية',
        invoiceType: 'شراء_مورد',
        items: [
          FactoryInvoiceItem(
            itemId: 'fb1',
            description: 'كتلة رخام كاردينال 24.5 طن',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            quantity: 24.5,
            unitPrice: 110.0,
            unitCost: 110.0,
            isGranite: false,
          ),
        ],
        advancePayment: 1500.0,
        isGoodsDelivered: true,
        paymentStatus: 'جزئي',
        currency: AppCurrency.usd,
      ),
      FactoryInvoiceModel(
        id: 'fi1',
        invoiceNo: 'FAC-2026-001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        partyId: 'cli1',
        partyName: 'شركة العمران للمقاولات',
        invoiceType: 'بيع_معتمد',
        items: [
          FactoryInvoiceItem(
            itemId: 'fw1',
            description: 'رخام كاردينال 2سم ألواح مقصوصة',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            lengthCm: 200,
            widthCm: 100,
            quantity: 10,
            unitPrice: 22.0,
            unitCost: 14.5,
            isGranite: false,
          ),
          FactoryInvoiceItem(
            itemId: 'fw3',
            description: 'غرانيت أسود جالكسي 3سم مع درج',
            typeName: 'غرانيت أسود جالكسي',
            grade: 'ممتاز',
            lengthCm: 150,
            widthCm: 80,
            quantity: 5,
            unitPrice: 55.0,
            unitCost: 35.0,
            isGranite: true,
          ),
        ],
        services: [
          ServiceAttachment(
            serviceName: 'شطف حواف وتفريز',
            price: 120.0,
            notes: 'شطف دبل',
          ),
        ],
        shippingFee: 150.0,
        isGoodsDelivered: true,
        advancePayment: 500.0,
        paymentStatus: 'يجب تحصيل دفعة',
        currency: AppCurrency.usd,
      ),
      FactoryInvoiceModel(
        id: 'fi_cash1',
        invoiceNo: 'CSH-2026-001',
        date: DateTime.now().subtract(const Duration(days: 1)),
        partyId: 'cli4',
        partyName: 'الزبون سامر المحمود',
        invoiceType: 'بيع_معتمد',
        isCashInvoice: true,
        items: [
          FactoryInvoiceItem(
            itemId: 'fw2',
            description: 'رخام كاردينال 3سم عتبات شبابيك',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            lengthCm: 120,
            widthCm: 25,
            quantity: 6,
            unitPrice: 30.0,
            unitCost: 21.0,
            isGranite: false,
          ),
        ],
        advancePayment: 54.0,
        isGoodsDelivered: true,
        paymentStatus: 'خالصة',
        currency: AppCurrency.usd,
      ),
    ];

    factoryOrders = [
      FactoryOrderModel(
        id: 'fo1',
        orderNo: 'FORD-2026-001',
        date: DateTime.now().subtract(const Duration(days: 1)),
        partyId: 'cli1',
        clientName: 'شركة العمران للمقاولات',
        clientPhone: '0911223344',
        items: [
          FactoryInvoiceItem(
            itemId: 'fw1',
            description: 'رخام كاردينال 2سم ألواح مقصوصة',
            typeName: 'رخام كاردينال',
            grade: 'درجة أولى',
            lengthCm: 220,
            widthCm: 110,
            quantity: 15,
            unitPrice: 24.0,
            unitCost: 14.5,
            isGranite: false,
          ),
        ],
        services: [
          ServiceAttachment(serviceName: 'شطف حواف وتفريز', price: 80.0),
        ],
        shippingFee: 100.0,
        depositAmount: 400.0,
        status: 'قيد التنفيذ',
        isCompleted: false,
        currency: AppCurrency.usd,
      ),
      FactoryOrderModel(
        id: 'fo2',
        orderNo: 'FORD-2026-002',
        date: DateTime.now().subtract(const Duration(days: 4)),
        partyId: 'cli2',
        clientName: 'المتعهد أحمد الشيخ',
        clientPhone: '0922334455',
        items: [
          FactoryInvoiceItem(
            itemId: 'fw3',
            description: 'غرانيت أسود جالكسي 3سم مع درج',
            typeName: 'غرانيت أسود جالكسي',
            grade: 'ممتاز',
            lengthCm: 180,
            widthCm: 90,
            quantity: 8,
            unitPrice: 60.0,
            unitCost: 35.0,
            isGranite: true,
          ),
        ],
        depositAmount: 500.0,
        status: 'مكتملة ومرحلة',
        isCompleted: true,
        currency: AppCurrency.usd,
      ),
    ];

    // 8. Workshop Inventory & Operations
    workshopStock = [
      WorkshopStockModel(
        id: 'ws1',
        typeName: 'رخام كاردينال',
        grade: 'درجة أولى',
        thicknessCm: 2.0,
        category: 'متر مربع',
        availableQty: 85.0,
        netCostPerUnit: 14.5,
        recommendedSalePrice: 24.0,
        isGranite: false,
      ),
      WorkshopStockModel(
        id: 'ws2',
        typeName: 'غرانيت أسود جالكسي',
        grade: 'ممتاز',
        thicknessCm: 3.0,
        category: 'متر مربع',
        availableQty: 40.0,
        netCostPerUnit: 35.0,
        recommendedSalePrice: 60.0,
        isGranite: true,
      ),
    ];

    scrapItems = [
      ScrapItemModel(
        id: 'sc1',
        description: 'قصاصات مغاسل كاردينال (25*40سم)',
        baseCost: 15.0,
        sellingPrice: 40.0,
        isSold: false,
        currency: AppCurrency.usd,
      ),
      ScrapItemModel(
        id: 'sc2',
        description: 'قطع غرانيت سوداء لزوايا العتب',
        baseCost: 20.0,
        sellingPrice: 55.0,
        isSold: false,
        currency: AppCurrency.usd,
      ),
    ];

    surplusCosts = [
      SurplusCostModel(
        id: 'scost1',
        surplusItemId: 'sc1',
        surplusDescription: 'بقايا قص ألواح روزا برتغالي قابلة للتدوير',
        kind: 'expense',
        beneficiaryName: 'مشتريات مستلزمات المعالجة',
        amountDue: 90.0,
        amountPaid: 90.0,
        currency: AppCurrency.usd,
        notes: 'مادة لاصقة إيبوكسي مستوردة لعلاج التشققات الشعرية',
      ),
      SurplusCostModel(
        id: 'scost2',
        surplusItemId: 'sc2',
        surplusDescription: 'قطع غرانيت سوداء لزوايا العتب',
        kind: 'worker',
        beneficiaryName: 'المعلم كمال صقل',
        staffId: 'stf3',
        amountDue: 140.0,
        amountPaid: 70.0,
        currency: AppCurrency.usd,
        notes: 'أقراص جلخ وتلميع إيطالية وأجرة تلميع زوايا',
      ),
    ];

    wasteLogs = [
      WasteLogModel(
        id: 'wl1',
        date: DateTime.now().subtract(const Duration(days: 4)),
        wasteType: 'هدر طبيعي',
        itemDescription: 'كسور حواف أثناء التقطيع',
        quantity: 2.5,
        cost: 35.0,
      ),
      WasteLogModel(
        id: 'wl2',
        date: DateTime.now().subtract(const Duration(days: 1)),
        wasteType: 'هدر غير طبيعي',
        itemDescription: 'سقوط ألواح من الرافعة',
        quantity: 1.0,
        cost: 210.0,
        destructionVoucherNo: 'VOUCH-8821',
      ),
    ];

    workshopOrders = [
      WorkshopOrderModel(
        id: 'wo1',
        orderNo: 'ORD-901',
        date: DateTime.now().subtract(const Duration(days: 1)),
        clientName: 'الدكتور طارق العلي',
        clientPhone: '0944887766',
        customDimensionsText: 'طاولة غرانيت أسود 220*110سم مع حفر بروفايل',
        agreedPrice: 750.0,
        depositAmount: 300.0,
        status: 'قيد التنفيذ',
      ),
    ];

    workshopInvoices = [
      WorkshopInvoiceModel(
        id: 'wi1',
        invoiceNo: 'WRK-2026-001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        clientName: 'المهندس رامي زريق',
        sourceType: 'تفصيل بسيط',
        itemDescription: 'درج كاردينال 120سم (10 درجات)',
        agreedPrice: 280.0,
        depositDeducted: 50.0,
        cashPaidNow: 230.0,
        netCost: 160.0,
        isGranite: false,
      ),
    ];

    workshopProjects = [
      WorkshopProjectModel(
        id: 'wp1',
        name: 'مشروع فيلا يعفور السكنية',
        clientName: 'الدكتور طارق العلي',
        phone: '0944887766',
        description: 'تفصيل وتوريد درج رخام كاردينال ومغاسل غرانيت أسود مع التركيب',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      WorkshopProjectModel(
        id: 'wp2',
        name: 'مجمع النرجس التجاري',
        clientName: 'المتعهد فهد القاسم',
        phone: '0933445566',
        description: 'واجهات رخام ترافنتينو مع شطف وتفريز وسكراب مداخل',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      WorkshopProjectModel(
        id: 'wp3',
        name: 'فندق قاسيون السياحي',
        clientName: 'شركة الإعمار والضيافة',
        phone: '0955667788',
        description: 'أرضيات بهو فندقي رخام بيانكو إيطالي ومغاسل معقدة',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];

    // 9. Services
    services = [
      ServiceItemModel(
        id: 'srv1',
        name: 'جلي وتلميع رخام',
        unitRate: 4.0,
        description: 'حساب للمتر المربع',
      ),
      ServiceItemModel(
        id: 'srv2',
        name: 'شطف حواف وتفريز',
        unitRate: 3.5,
        description: 'حساب للمتر الطولي',
      ),
      ServiceItemModel(
        id: 'srv3',
        name: 'نقل وتوصيل بالكرين',
        unitRate: 75.0,
        description: 'حساب للرحلة',
      ),
      ServiceItemModel(
        id: 'srv4',
        name: 'قص وزوايا معقدة',
        unitRate: 8.0,
        description: 'حساب للقطعة',
      ),
      ServiceItemModel(
        id: 'srv5',
        name: 'ثقب وتفريغ مغاسل',
        unitRate: 15.0,
        description: 'حساب للفتحة',
      ),
    ];

    // 10. Workforce & Workdays
    staffTypes = [
      StaffTypeModel(
        id: 'staff_type_worker_general',
        category: 'عمال',
        name: 'عمال عامون',
        dailyRate: 45,
      ),
      StaffTypeModel(
        id: 'staff_type_admin_general',
        category: 'إداريين',
        name: 'إداريون عامون',
        dailyRate: 50,
      ),
      StaffTypeModel(
        id: 'staff_type_master_cut',
        category: 'معلمين',
        name: 'معلمو قص وتفصيل',
        dailyRate: 70,
      ),
    ];

    staffList = [
      StaffModel(
        id: 'stf1',
        name: 'المعلم أبو حيدر (قصاص)',
        category: 'معلمين',
        phone: '0933111222',
        typeId: 'staff_type_master_cut',
        totalEarned: 1450.0,
        cashAdvancesDisbursed: 400.0,
      ),
      StaffModel(
        id: 'stf2',
        name: 'العامل ياسين (تحميل وتنزيل)',
        category: 'عمال',
        phone: '0944222333',
        typeId: 'staff_type_worker_general',
        totalEarned: 850.0,
        cashAdvancesDisbursed: 200.0,
      ),
      StaffModel(
        id: 'stf3',
        name: 'المحاسب نزار (إداري)',
        category: 'إداريين',
        phone: '0955333444',
        typeId: 'staff_type_admin_general',
        totalEarned: 2100.0,
        cashAdvancesDisbursed: 500.0,
      ),
    ];

    activeWorkweekStart = _startOfWorkweek(DateTime.now());

    staffAttendance = [
      StaffAttendanceModel(
        id: 'att1',
        date: DateTime.now().subtract(const Duration(days: 2)),
        staffId: 'stf2',
        dailyRate: 45.0,
        currency: AppCurrency.usd,
      ),
      StaffAttendanceModel(
        id: 'att2',
        date: DateTime.now().subtract(const Duration(days: 1)),
        staffId: 'stf2',
        dailyRate: 45.0,
        currency: AppCurrency.usd,
      ),
      StaffAttendanceModel(
        id: 'att3',
        date: DateTime.now(),
        staffId: 'stf3',
        dailyRate: 50.0,
        currency: AppCurrency.usd,
      ),
    ];

    workdayEntries = [
      WorkdayEntryModel(
        id: 'wde1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        staffNames: ['المعلم أبو حيدر (قصاص)', 'العامل ياسين (تحميل وتنزيل)'],
        workDescription: 'قص 3 بلوكات كاردينال وتنزيل ألواح المعمل',
        rateType: 'حساب يومية',
        agreedAmountPerPerson: 45.0,
        currency: AppCurrency.usd,
      ),
    ];

    advanceRepayments = [
      AdvanceRepaymentModel(
        id: 'ar1',
        staffId: 'stf1',
        staffName: 'المعلم أبو حيدر (قصاص)',
        staffCategory: 'معلمين',
        originalCurrency: AppCurrency.usd,
        collectedCurrency: AppCurrency.usd,
        collectedAmount: 100.0,
        deductedAmount: 100.0,
        exchangeRate: 1.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        note: 'تسديد سلفة المعلم أبو حيدر عند قبض مستحقاته',
      ),
    ];

    // 11. Returns, Expenses & Adjustments
    returnInvoices = [
      ReturnInvoiceModel(
        id: 'ret1',
        returnNo: 'RET-001',
        date: DateTime.now().subtract(const Duration(days: 5)),
        returnType: 'مرتجع مشتريات مورد',
        partyName: 'شركة مقالع الرخام الوطنية',
        itemDescription: 'بلوك كاردينال فيه تشققات سرية',
        quantity: 12.0,
        refundAmount: 1320.0,
        paymentAction: 'تخفيض دين',
      ),
    ];

    expenseTypes = [
      ExpenseTypeModel(
        id: blockPurchaseExpenseTypeId,
        name: 'مشتريات البلوكات (Block Purchases)',
        description: 'دفعات ومشتريات كتل الرخام والغرانيت من الموردين',
      ),
      ExpenseTypeModel(
        id: cuttingExpenseTypeId,
        name: 'مصاريف القص والتصنيع (Cutting Expenses)',
        description: 'أجور ونسب قص وتصنيع كتل الرخام والغرانيت',
      ),
      ExpenseTypeModel(
        id: 'et1',
        name: 'محروقات ومازوت للمولدات',
        description: 'وقود تشغيل المناشير والرافعات',
      ),
      ExpenseTypeModel(
        id: 'et2',
        name: 'صيانة وإصلاحات ميكانيكية',
        description: 'قطع غيار شفرات وزيوت هيدروليك',
      ),
      ExpenseTypeModel(
        id: 'et3',
        name: 'كهرباء ومياه صناعية',
        description: 'فواتير الخدمات الشهرية للمنشأة',
      ),
      ExpenseTypeModel(
        id: 'et4',
        name: 'ضيافة ونثريات إدارية',
        description: 'مستلزمات الضيافة والمكتب',
      ),
    ];

    expenseRecords = [
      ExpenseRecordModel(
        id: 'er_seed_pur1',
        typeId: blockPurchaseExpenseTypeId,
        amount: 1500.0,
        currency: AppCurrency.usd,
        personName: 'شركة مقالع الرخام الوطنية',
        description: 'دفعة شراء بلوكات - فاتورة رقم PUR-2026-001',
        date: DateTime.now().subtract(const Duration(days: 6)),
      ),
      ExpenseRecordModel(
        id: 'er_seed_cut1',
        typeId: cuttingExpenseTypeId,
        amount: 176.0,
        currency: AppCurrency.usd,
        personName: 'قسم القص والتصنيع',
        description: 'أجرة قص وتصنيع: رخام كاردينال (درجة أولى) - نسبة 8%',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ExpenseRecordModel(
        id: 'er1',
        typeId: 'et1',
        amount: 350.0,
        currency: AppCurrency.usd,
        personName: 'السائق أبو خالد',
        description: 'تعبئة مازوت 500 ليتر لمولد المولدات الكبيرة',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ExpenseRecordModel(
        id: 'er2',
        typeId: 'et2',
        amount: 180.0,
        currency: AppCurrency.usd,
        personName: 'فني الصيانة جهاد',
        description: 'تبديل زيت هيدروليك وفلاتر لجلاية سيميوني',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ExpenseRecordModel(
        id: 'er3',
        typeId: 'et3',
        amount: 1500000.0,
        currency: AppCurrency.syp,
        personName: 'المحاسب نزار',
        description: 'تسديد فاتورة الكهرباء الصناعية للمصنع',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    adjustmentInvoices = [
      AdjustmentInvoiceModel(
        id: 'adj1',
        invoiceNo: 'ADJ-2026-001',
        module: 'المصنع',
        kind: 'تسوية_مستودع',
        targetInvoiceId: 'fw1',
        targetInvoiceNo: 'FW-001',
        partyName: 'المستودع الرئيسي',
        description: 'تسوية زيادة ناتجة عن إعادة فرز ألواح',
        itemDescription: 'رخام كاردينال 2سم (فروقات جرد دوري)',
        amount: 72.5,
        quantity: 5.0,
        currency: AppCurrency.usd,
        date: DateTime.now().subtract(const Duration(days: 6)),
      ),
    ];

    // 12. Center Information
    centerInfo = const CenterInfoModel(
      centerName: 'مجمع أبعاد لتجارة وتصنيع الرخام والغرانيت',
      ownerName: 'إدارة مجمع أبعاد',
      phone1: '0944112233',
      phone2: '0933556677',
      address: 'سوريا - ريف دمشق - المنطقة الصناعية',
      commercialRegNo: 'CR-54120',
      taxId: 'TAX-982134',
      slogan: 'الجودة والدقة في كافة أعمال الرخام الطبيعي والغرانيت المستورد',
    );

    // 13. Daily Reports Archive
    dailyReports = [
      compileDailyReportForDate(
        DateTime.now().subtract(const Duration(days: 2)),
        notes: 'تقرير مبيعات وعمليات المصنع التجريبية التأسيسية',
      ),
    ];
  }

  // -------------------------------------------------------------
  // REAL-TIME FINANCIAL METRICS & CALCULATIONS
  // -------------------------------------------------------------
  double get totalCurrentEquity {
    final capital = partners.fold<double>(
      0.0,
      (sum, p) => sum + p.injectedCapital,
    );
    if (capital > 0) return capital;
    return openingEntry.totalEquity;
  }
  double get totalCurrentEquitySyp {
    final capital = partners.fold<double>(
      0.0,
      (sum, p) => sum + p.injectedCapitalSyp,
    );
    if (capital > 0) return capital;
    return openingEntry.totalEquitySyp;
  }

  double get fixedAssetsBookValue => openingEntry.fixedAssets
      .where((asset) => !asset.isSold)
      .fold(0.0, (sum, asset) => sum + asset.amount);

  void addOpeningFixedAsset(FixedAssetModel asset) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.fixedAssets.add(asset);
    _syncOpeningAssetTotals();
    refresh();
  }

  void updateOpeningFixedAsset(FixedAssetModel asset) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    final index = openingEntry.fixedAssets.indexWhere(
      (item) => item.id == asset.id,
    );
    if (index < 0) throw StateError('Opening asset was not found.');
    openingEntry.fixedAssets[index] = asset;
    _syncOpeningAssetTotals();
    refresh();
  }

  void deleteOpeningFixedAsset(String id) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.fixedAssets.removeWhere((item) => item.id == id);
    _syncOpeningAssetTotals();
    refresh();
  }

  void _syncOpeningAssetTotals() {
    final assets = openingEntry.fixedAssets;
    if (assets.isEmpty) return;
    openingEntry.landValue = assets
        .where(
          (a) =>
              !a.isSold &&
              a.category == 'أراضي' &&
              a.currency == AppCurrency.usd,
        )
        .fold(0, (s, a) => s + a.amount);
    openingEntry.buildingsValue = assets
        .where(
          (a) =>
              !a.isSold &&
              a.category == 'مباني وعقارات' &&
              a.currency == AppCurrency.usd,
        )
        .fold(0, (s, a) => s + a.amount);
    openingEntry.machineryValue = assets
        .where(
          (a) =>
              !a.isSold &&
              a.category == 'آلات ومعدات' &&
              a.currency == AppCurrency.usd,
        )
        .fold(0, (s, a) => s + a.amount);
    openingEntry.vehiclesValue = assets
        .where(
          (a) =>
              !a.isSold &&
              a.category == 'آليات ونقل' &&
              a.currency == AppCurrency.usd,
        )
        .fold(0, (s, a) => s + a.amount);
    openingEntry.furnitureValue = assets
        .where(
          (a) =>
              !a.isSold &&
              a.category == 'أثاث' &&
              a.currency == AppCurrency.usd,
        )
        .fold(0, (s, a) => s + a.amount);
  }

  void addOpeningStockItem(OpeningStockItemModel item) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    _validateOpeningStockType(item);
    openingEntry.openingStock.add(item);
    openingEntry.inventoryValue = openingEntry.openingStock.fold(
      0.0,
      (sum, row) =>
          sum + (row.currency == AppCurrency.usd ? row.totalPrice : 0),
    );
    refresh();
  }

  void updateOpeningStockItem(OpeningStockItemModel item) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    final index = openingEntry.openingStock.indexWhere(
      (existing) => existing.id == item.id,
    );
    if (index < 0) throw StateError('Opening stock item was not found.');
    _validateOpeningStockType(item);
    openingEntry.openingStock[index] = item;
    _syncOpeningInventoryTotal();
    refresh();
  }

  void deleteOpeningStockItem(String id) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.openingStock.removeWhere((item) => item.id == id);
    _syncOpeningInventoryTotal();
    refresh();
  }

  void _syncOpeningInventoryTotal() {
    openingEntry.inventoryValue = openingEntry.openingStock
        .where((item) => item.currency == AppCurrency.usd)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void _validateOpeningStockType(OpeningStockItemModel item) {
    final typeExists = switch (item.category) {
      'بلوكات خام المصنع' => blockTypes.any(
        (type) =>
            (item.typeId.isNotEmpty && type.id == item.typeId) ||
            (type.typeName == item.typeName &&
                (item.grade.isEmpty || type.grade == item.grade)),
      ),
      'أمتار المصنع' || 'أمتار المعمل' => meterTypes.any(
        (type) =>
            (item.typeId.isNotEmpty && type.id == item.typeId) ||
            type.typeName == item.typeName,
      ),
      'تفصيل بسيط' => simpleTailorings.any(
        (type) =>
            (item.typeId.isNotEmpty && type.id == item.typeId) ||
            type.name == item.typeName,
      ),
      'تفصيل معقد' => complexTailorings.any(
        (type) =>
            (item.typeId.isNotEmpty && type.id == item.typeId) ||
            type.name == item.typeName,
      ),
      'قطع زائدة وخردة' => true,
      _ => false,
    };
    if (!typeExists) {
      throw ArgumentError(
        'Choose a registered type before adding opening inventory: ${item.typeName}.',
      );
    }
  }

  void addOpeningFinancialRecord(LegacyFinancialRecordModel record) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.legacyFinancials.add(record);
    _syncOpeningFinancialTotals();
    refresh();
  }

  void updateOpeningFinancialRecord(LegacyFinancialRecordModel record) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    final index = openingEntry.legacyFinancials.indexWhere(
      (existing) => existing.id == record.id,
    );
    if (index < 0) throw StateError('Opening financial record was not found.');
    openingEntry.legacyFinancials[index] = record;
    _syncOpeningFinancialTotals();
    refresh();
  }

  void deleteOpeningFinancialRecord(String id) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.legacyFinancials.removeWhere((record) => record.id == id);
    _syncOpeningFinancialTotals();
    refresh();
  }

  void _syncOpeningFinancialTotals() {
    final records = openingEntry.legacyFinancials;
    openingEntry.customerDebtsValue = records
        .where((r) => r.category == 'clients' && r.currency == AppCurrency.usd)
        .fold(0.0, (sum, r) => sum + r.amount);
    openingEntry.supplierPayablesValue = records
        .where(
          (r) => r.category == 'suppliers' && r.currency == AppCurrency.usd,
        )
        .fold(0.0, (sum, r) => sum + r.amount);
    openingEntry.workerSalariesValue = records
        .where(
          (r) => r.category == 'employees' && r.currency == AppCurrency.usd,
        )
        .fold(0.0, (sum, r) => sum + r.amount);
  }

  void addExpenseType(ExpenseTypeModel type) {
    expenseTypes.add(type);
    refresh();
  }

  void addExpenseRecord(ExpenseRecordModel expense, {String? box}) {
    if (expense.amount <= 0 ||
        expense.personShare < 0 ||
        expense.personShare > expense.amount) {
      throw ArgumentError('Expense and share amounts are invalid.');
    }
    final targetBox = box ?? expense.cashBox;
    // Deduct cash from safe, permitting negative overdraft
    takeCash(targetBox, expense.currency, expense.amount, allowNegative: true);
    expenseRecords.add(expense);
    refresh();
  }

  // -------------------------------------------------------------
  // RETURNS & ALLOWANCES ENGINE (مرتجعات ومسموحات الفواتير)
  // -------------------------------------------------------------
  /// Rounds money to exactly 2 decimals so USD / SYP totals never drift.
  static double _money(num value) => AppCurrency.money(value);

  /// Candidate identities of one line inside a master invoice. Several keys
  /// are produced so records written by older versions still match.
  static Set<String> _lineKeys({
    required int index,
    required String itemId,
    required String description,
  }) {
    final keys = <String>{};
    if (index >= 0) keys.add('idx:$index');
    if (itemId.trim().isNotEmpty) keys.add('id:${itemId.trim()}');
    if (description.trim().isNotEmpty) {
      keys.add('desc:${description.trim()}');
    }
    return keys;
  }

  /// Quantity of a master-invoice line already returned by earlier documents.
  double _alreadyReturnedQty({
    required String module,
    required String targetInvoiceId,
    required Set<String> keys,
  }) {
    var total = 0.0;
    for (final doc in adjustmentInvoices) {
      if (doc.module != module ||
          doc.targetInvoiceId != targetInvoiceId ||
          !doc.isReturn) {
        continue;
      }
      final source = doc.lines.isNotEmpty
          ? doc.lines
          : [
              AdjustmentLineModel(
                itemId: doc.itemId,
                itemIndex: doc.itemIndex,
                description: doc.itemDescription,
                quantity: doc.quantity,
                unitPrice: 0,
                amount: doc.amount,
              ),
            ];
      for (final line in source) {
        final lineKeys = _lineKeys(
          index: line.itemIndex,
          itemId: line.itemId,
          description: line.description,
        );
        if (lineKeys.any(keys.contains)) total += line.quantity;
      }
    }
    return total;
  }

  /// Materialized lines of a workshop invoice. Legacy invoices keep their
  /// data in the scalar fields instead of an items list.
  List<WorkshopInvoiceItem> _workshopInvoiceLines(WorkshopInvoiceModel inv) {
    if (inv.items.isNotEmpty) return List.of(inv.items);
    final quantity = inv.sourceQuantity > 0 ? inv.sourceQuantity : 1.0;
    return [
      WorkshopInvoiceItem(
        id: 'legacy_line',
        sourceType: inv.sourceType,
        sourceId: inv.sourceId,
        description: inv.itemDescription,
        quantity: quantity,
        unitCategory: inv.sourceUnitCategory,
        agreedPrice: inv.agreedPrice,
        netCost: inv.netCost,
      ),
    ];
  }

  static String _factoryLineUnit(
    FactoryInvoiceItem item, {
    FactoryInvoiceModel? parent,
  }) {
    if (item.itemCategory == 'tailoring' ||
        item.itemId.startsWith('tailoring_') ||
        item.isTailoringItem) {
      return 'قطعة';
    }
    final isDealerSales = parent?.invoiceType == 'بيع_معتمد';
    final isCube = item.isCubicMeter ||
        item.meterUnit == 'متر مكعب' ||
        item.itemCategory == 'متر مكعب' ||
        item.thicknessCm > 5.0 ||
        item.heightCm > 5.0 ||
        item.description.contains('مكعب') ||
        item.description.contains('م³') ||
        item.typeName.contains('مكعب') ||
        item.typeName.contains('م³');

    if (isDealerSales || item.isMeterItem) {
      return isCube ? 'متر مكعب' : 'متر مربع';
    }
    return 'طن';
  }

  String factoryLineUnit(
    FactoryInvoiceItem item, {
    FactoryInvoiceModel? parent,
  }) =>
      _factoryLineUnit(item, parent: parent);

  static String _workshopLineUnit(WorkshopInvoiceItem item) {
    final st = item.sourceType;
    if (st == 'بيع خياطة معقدة' ||
        st == 'تفصيل معقد' ||
        st == 'complex_tailoring') {
      return 'قطعة';
    }
    if (st == 'بيع خياطة بسيطة' ||
        st == 'تفصيل بسيط' ||
        st == 'simple_tailoring') {
      return (item.unitCategory == 'متر مكعب' || item.isCubicMeter)
          ? 'متر مكعب'
          : 'متر مربع';
    }
    if (st == 'بيع مواد خام من المعمل' ||
        st == 'مواد خام' ||
        st == 'raw_materials') {
      return (item.unitCategory == 'متر مكعب' || item.isCubicMeter)
          ? 'متر مكعب'
          : 'متر مربع';
    }
    if (st == 'بيع قطع إضافية' ||
        st == 'قطع زائدة' ||
        st == 'scrap' ||
        st == 'surplus') {
      if (item.unitCategory == 'متر مكعب' || item.isCubicMeter) return 'متر مكعب';
      if (item.unitCategory == 'قطعة') return 'قطعة';
      return 'متر مربع';
    }
    if (item.unitCategory.isNotEmpty) return item.unitCategory;
    return 'متر مربع';
  }

  /// Builds the stored record for one master-invoice line.
  /// `unitPrice` is always derived from the parent invoice (never trusted
  /// from the caller) so `amount == quantity * original unit price`.
  _ResolvedReturnLine _describeFactoryLine(
    FactoryInvoiceModel parent,
    int index,
    double quantity,
  ) {
    final item = parent.items[index];
    final unitQty = item.quantity > 0
        ? item.calculatedArea / item.quantity
        : 1.0;
    final unitPrice = _money(item.unitPrice * unitQty);
    return _ResolvedReturnLine(
      line: AdjustmentLineModel(
        itemId: item.itemId,
        itemIndex: index,
        description: item.description,
        unit: _factoryLineUnit(item, parent: parent),
        quantity: quantity,
        unitPrice: unitPrice,
        amount: _money(quantity * unitPrice),
      ),
      factoryItem: item,
      unitQty: unitQty,
    );
  }

  _ResolvedReturnLine _describeWorkshopLine(
    List<WorkshopInvoiceItem> lines,
    int index,
    double quantity,
  ) {
    final item = lines[index];
    final unitPrice = _money(
      item.quantity > 0 ? item.agreedPrice / item.quantity : item.agreedPrice,
    );
    return _ResolvedReturnLine(
      line: AdjustmentLineModel(
        itemId: item.sourceId,
        itemIndex: index,
        description: item.description,
        unit: _workshopLineUnit(item),
        quantity: quantity,
        unitPrice: unitPrice,
        amount: _money(quantity * unitPrice),
        sourceType: item.sourceType,
        sourceLineItemId: item.sourceLineItemId,
      ),
      workshopItem: item,
      unitQty: 1.0,
    );
  }

  // --- Inventory routing: matchers -----------------------------------
  FactoryWarehouseModel? _matchFactoryWarehouse(FactoryInvoiceItem item) {
    final isCube = item.isCubicMeter ||
        item.meterUnit == 'متر مكعب' ||
        item.itemCategory == 'متر مكعب' ||
        item.thicknessCm > 5.0 ||
        item.heightCm > 5.0 ||
        item.description.contains('مكعب') ||
        item.description.contains('م³') ||
        item.typeName.contains('مكعب') ||
        item.typeName.contains('م³');
    final category = isCube ? 'متر مكعب' : 'متر مربع';
    if (item.itemId.isNotEmpty) {
      final byId = factoryWarehouse
          .where((w) => w.id == item.itemId && w.category == category)
          .toList();
      if (byId.isNotEmpty) return byId.first;
      final anyById = factoryWarehouse.where((w) => w.id == item.itemId).toList();
      if (anyById.isNotEmpty) return anyById.first;
    }
    final typeName = item.typeName.isNotEmpty ? item.typeName : item.description;
    if (typeName.trim().isEmpty) return null;
    final grade = item.grade.isNotEmpty ? item.grade : 'درجة أولى';
    final thickness = item.thicknessCm > 0 ? item.thicknessCm : (isCube ? 10.0 : 2.0);
    final exact = factoryWarehouse
        .where(
          (w) =>
              w.typeName == typeName &&
              w.grade == grade &&
              (w.thicknessCm - thickness).abs() < 0.01 &&
              w.category == category,
        )
        .toList();
    if (exact.isNotEmpty) return exact.first;
    final byNameAndCategory = factoryWarehouse
        .where((w) => w.typeName == typeName && w.category == category)
        .toList();
    if (byNameAndCategory.isNotEmpty) return byNameAndCategory.first;
    return null;
  }

  List<FactoryBlockModel> _matchFactoryBlocks(
    FactoryInvoiceModel parent,
    FactoryInvoiceItem item, {
    required bool strictSupplier,
  }) {
    final typeName = item.typeName.isNotEmpty ? item.typeName : item.description;
    final grade = item.grade.isNotEmpty ? item.grade : 'درجة أولى';
    if (strictSupplier) {
      return factoryBlocks
          .where(
            (b) =>
                b.supplierId == parent.partyId &&
                b.typeName == typeName &&
                b.grade == grade,
          )
          .toList();
    }
    final bySupplier = factoryBlocks
        .where(
          (b) =>
              b.supplierId.isNotEmpty &&
              b.supplierId == parent.partyId &&
              b.typeName == typeName &&
              b.grade == grade,
        )
        .toList();
    if (bySupplier.isNotEmpty) return bySupplier;
    return factoryBlocks
        .where((b) => b.typeName == typeName && b.grade == grade)
        .toList();
  }

  WorkshopTailoringModel? _matchFactoryTailoring(FactoryInvoiceItem item) {
    final all = [...simpleTailorings, ...complexTailorings];
    for (final candidate in all) {
      for (final lineItem in candidate.lineItems) {
        if (item.itemId == 'tailoring_${candidate.id}_${lineItem.id}' ||
            item.itemId == lineItem.id) {
          return candidate;
        }
      }
      if (item.itemId == candidate.id) return candidate;
    }
    if (item.description.trim().isEmpty) return null;
    final byName = all
        .where(
          (t) =>
              t.name == item.description ||
              t.rawMaterialDescription == item.description,
        )
        .toList();
    return byName.isNotEmpty ? byName.first : null;
  }

  WorkshopStockModel? _matchWorkshopStock(WorkshopInvoiceItem item) {
    final category = (item.unitCategory == 'متر مكعب' || item.isCubicMeter)
        ? 'متر مكعب'
        : 'متر مربع';
    if (item.sourceId.isNotEmpty) {
      final byId = workshopStock
          .where((w) => w.id == item.sourceId && w.category == category)
          .toList();
      if (byId.isNotEmpty) return byId.first;
      final anyById = workshopStock.where((w) => w.id == item.sourceId).toList();
      if (anyById.isNotEmpty) return anyById.first;
    }
    if (item.description.trim().isEmpty) return null;
    final exact = workshopStock
        .where(
          (w) =>
              (w.typeName == item.description ||
                  item.description.contains(w.typeName) ||
                  w.typeName.contains(item.description)) &&
              w.category == category,
        )
        .toList();
    if (exact.isNotEmpty) return exact.first;
    final byName = workshopStock
        .where(
          (w) =>
              w.typeName == item.description ||
              item.description.contains(w.typeName) ||
              w.typeName.contains(item.description),
        )
        .toList();
    return byName.isNotEmpty ? byName.first : null;
  }

  // --- Inventory routing: feasibility --------------------------------
  bool _canRouteReturn({
    required String module,
    required bool purchase,
    required List<_ResolvedReturnLine> lines,
    required FactoryInvoiceModel? original,
    required WorkshopInvoiceModel? workshopOriginal,
  }) {
    for (final resolved in lines) {
      if (module == 'factory') {
        final item = resolved.factoryItem!;
        final isDealerSales = original?.invoiceType == 'بيع_معتمد';
        final isMeter = item.isMeterItem || isDealerSales;
        if (isMeter) {
          final warehouse = _matchFactoryWarehouse(item);
          if (warehouse == null) {
            final label = item.typeName.isNotEmpty
                ? item.typeName
                : item.description;
            if (purchase || label.trim().isEmpty) return false;
          } else if (purchase &&
              warehouse.availableQty + 0.0001 < resolved.line.quantity) {
            return false;
          }
        } else if (item.itemCategory == 'tailoring' ||
            item.itemId.startsWith('tailoring_') ||
            item.isTailoringItem) {
          if (_matchFactoryTailoring(item) == null && purchase) return false;
        } else {
          final blocks = _matchFactoryBlocks(
            original!,
            item,
            strictSupplier: purchase,
          );
          if (blocks.isEmpty) {
            final label = item.typeName.isNotEmpty
                ? item.typeName
                : item.description;
            if (purchase || label.trim().isEmpty) return false;
          } else if (purchase) {
            final available = blocks.fold<double>(
              0.0,
              (sum, block) => sum + block.weightTons,
            );
            if (available + 0.0001 < resolved.line.quantity) return false;
          }
        }
      } else {
        final item = resolved.workshopItem!;
        final st = item.sourceType;
        if (st == 'بيع مواد خام من المعمل' ||
            st == 'مواد خام' ||
            st == 'raw_materials') {
          if (purchase && _matchWorkshopStock(item) == null) return false;
        }
      }
    }
    return true;
  }

  // --- Inventory routing: application --------------------------------
  /// Routes a returned line to its stock page.
  /// Factory meters → مستودع المصنع, blocks → مخزون مصنع,
  /// workshop simple/complex detail, raw materials (مواد معمل) and surplus
  /// (الزيادة) each go to their own page.
  void _applyReturnRouting({
    required String module,
    required bool purchase,
    required List<_ResolvedReturnLine> lines,
    required FactoryInvoiceModel? original,
    required WorkshopInvoiceModel? workshopOriginal,
  }) {
    for (final resolved in lines) {
      if (module == 'factory') {
        _applyFactoryReturnRouting(
          resolved: resolved,
          purchase: purchase,
          parent: original!,
        );
      } else {
        _applyWorkshopReturnRouting(resolved: resolved);
      }
    }
  }

  void _applyFactoryReturnRouting({
    required _ResolvedReturnLine resolved,
    required bool purchase,
    required FactoryInvoiceModel parent,
  }) {
    final item = resolved.factoryItem!;
    final line = resolved.line;
    final returnedArea = line.quantity * resolved.unitQty;

    final isDealerSales = parent.invoiceType == 'بيع_معتمد';
    final isMeter = item.isMeterItem || isDealerSales;

    if (isMeter) {
      // مستودع المصنع (Factory Warehouse — slabs & cubes)
      final warehouse = _matchFactoryWarehouse(item);
      if (warehouse != null) {
        warehouse.availableQty = purchase
            ? (warehouse.availableQty - line.quantity).clamp(
                0.0,
                double.infinity,
              )
            : warehouse.availableQty + returnedArea;
        return;
      }
      if (purchase) return;
      final typeName = item.typeName.isNotEmpty
          ? item.typeName
          : item.description;
      if (typeName.trim().isEmpty) return;
      final isCube = item.isCubicMeter ||
          item.meterUnit == 'متر مكعب' ||
          item.itemCategory == 'متر مكعب' ||
          item.thicknessCm > 5.0 ||
          item.heightCm > 5.0 ||
          item.description.contains('مكعب') ||
          item.description.contains('م³') ||
          item.typeName.contains('مكعب') ||
          item.typeName.contains('م³');
      factoryWarehouse.add(
        FactoryWarehouseModel(
          id:
              'fw_${DateTime.now().microsecondsSinceEpoch}_${factoryWarehouse.length}',
          typeName: typeName,
          grade: item.grade.isNotEmpty ? item.grade : 'درجة أولى',
          thicknessCm: item.thicknessCm > 0
              ? item.thicknessCm
              : (isCube ? 10.0 : 2.0),
          category: isCube ? 'متر مكعب' : 'متر مربع',
          availableQty: returnedArea,
          netCostPerUnit: item.unitCost,
          recommendedSalePrice: item.unitPrice,
          isGranite: item.isGranite,
        ),
      );
      return;
    }

    if (item.itemCategory == 'tailoring' ||
        item.itemId.startsWith('tailoring_')) {
      // Detail products sold through the factory POS.
      final tailoring = _matchFactoryTailoring(item);
      if (tailoring != null) {
        tailoring.quantity = (tailoring.quantity + (purchase
            ? -line.quantity
            : returnedArea)).clamp(0.0, double.infinity);
        return;
      }
      if (purchase) return;
      final isComplex = complexTailorings.any(
        (t) => t.id == item.itemId || t.name == item.description,
      );
      final target = isComplex ? complexTailorings : simpleTailorings;
      target.add(
        WorkshopTailoringModel(
          id: item.itemId.isNotEmpty
              ? item.itemId
              : 'rt_${DateTime.now().microsecondsSinceEpoch}',
          name: item.description.isNotEmpty
              ? item.description
              : 'مرتجع فاتورة ${parent.invoiceNo}',
          complexity: isComplex ? 'معقد' : 'بسيط',
          rawMaterialDescription: item.description,
          quantity: returnedArea,
          materialNetCost: item.unitCost,
          unitCategory: item.isCubicMeter ? 'متر مكعب' : 'متر مربع',
          sellingPrice: item.unitPrice,
          isGranite: item.isGranite,
        ),
      );
      return;
    }

    // مخزون مصنع (Block / Factory Stock)
    final blocks = _matchFactoryBlocks(parent, item, strictSupplier: purchase);
    if (purchase) {
      var remaining = line.quantity;
      for (final block in blocks) {
        if (remaining <= 0) break;
        final taken = remaining < block.weightTons
            ? remaining
            : block.weightTons;
        block.weightTons = (block.weightTons - taken).clamp(
          0.0,
          double.infinity,
        );
        remaining -= taken;
      }
      return;
    }
    if (blocks.isNotEmpty) {
      blocks.first.weightTons += line.quantity;
      return;
    }
    final typeName = item.typeName.isNotEmpty ? item.typeName : item.description;
    if (typeName.trim().isEmpty) return;
    factoryBlocks.add(
      FactoryBlockModel(
        id:
            'fb_${DateTime.now().microsecondsSinceEpoch}_${factoryBlocks.length}',
        blockCode: 'BLK-${factoryBlocks.length + 101}',
        typeName: typeName,
        grade: item.grade.isNotEmpty ? item.grade : 'درجة أولى',
        supplierId: parent.partyId,
        supplierName: parent.partyName,
        weightTons: line.quantity,
        tonCost: item.unitCost,
        tonSellingPrice: item.unitPrice,
        isGranite: item.isGranite,
      ),
    );
  }

  void _applyWorkshopReturnRouting({required _ResolvedReturnLine resolved}) {
    final item = resolved.workshopItem!;
    final quantity = resolved.line.quantity;
    final sourceType = item.sourceType;

    if (sourceType == 'بيع خياطة بسيطة' ||
        sourceType == 'تفصيل بسيط' ||
        sourceType == 'simple_tailoring') {
      // تفصيل بسيط → Simple Detail Inventory Page (m² or m³)
      final category = (item.unitCategory == 'متر مكعب' || item.isCubicMeter)
          ? 'متر مكعب'
          : 'متر مربع';
      final matches = item.sourceId.isNotEmpty
          ? simpleTailorings.where((t) => t.id == item.sourceId).toList()
          : simpleTailorings
              .where((t) =>
                  (t.name == item.description ||
                      item.description.contains(t.name)) &&
                  t.unitCategory == category)
              .toList();
      if (matches.isEmpty) {
        simpleTailorings.add(
          WorkshopTailoringModel(
            id: item.sourceId.isNotEmpty
                ? item.sourceId
                : 'tailoring_s_${DateTime.now().microsecondsSinceEpoch}_${simpleTailorings.length}',
            name: item.description.isNotEmpty
                ? item.description
                : 'تفصيل بسيط مرتجع',
            complexity: 'بسيط',
            rawMaterialDescription: item.description,
            quantity: quantity,
            materialNetCost: item.netCost,
            unitCategory: category,
            sellingPrice: item.agreedPrice,
            isGranite: item.isGranite,
            photoPath: item.photoPath,
          ),
        );
        return;
      }
      final product = matches.first;
      product.quantity = (product.quantity + quantity).clamp(
        0.0,
        double.infinity,
      );
      if (item.sourceLineItemId.isNotEmpty) {
        final lineItem = product.lineItems
            .where((li) => li.id == item.sourceLineItemId)
            .firstOrNull;
        if (lineItem != null) {
          final pieceArea = (lineItem.lengthCm > 0 && lineItem.widthCm > 0)
              ? (lineItem.lengthCm / 100.0) *
                    (lineItem.widthCm / 100.0) *
                    (lineItem.category == 'متر مكعب' &&
                            lineItem.heightCm > 0
                        ? lineItem.heightCm / 100.0
                        : 1.0)
              : 0.0;
          lineItem.quantity = (lineItem.quantity +
                  (pieceArea > 0 ? quantity / pieceArea : quantity))
              .clamp(0.0, double.infinity);
        }
      }
      return;
    }

    if (sourceType == 'بيع خياطة معقدة' ||
        sourceType == 'تفصيل معقد' ||
        sourceType == 'complex_tailoring') {
      // تفصيل معقد → Complex Detail Inventory Page (Strictly Pieces)
      final matches = item.sourceId.isNotEmpty
          ? complexTailorings.where((t) => t.id == item.sourceId).toList()
          : complexTailorings
              .where((t) =>
                  t.name == item.description ||
                  item.description.contains(t.name))
              .toList();
      if (matches.isEmpty) {
        complexTailorings.add(
          WorkshopTailoringModel(
            id: item.sourceId.isNotEmpty
                ? item.sourceId
                : 'tailoring_c_${DateTime.now().microsecondsSinceEpoch}_${complexTailorings.length}',
            name: item.description.isNotEmpty
                ? item.description
                : 'تفصيل معقد مرتجع',
            complexity: 'معقد',
            rawMaterialDescription: item.description,
            quantity: quantity,
            materialNetCost: item.netCost,
            unitCategory: 'قطعة',
            sellingPrice: item.agreedPrice,
            isGranite: item.isGranite,
            photoPath: item.photoPath,
          ),
        );
        return;
      }
      matches.first.quantity = (matches.first.quantity + quantity).clamp(
        0.0,
        double.infinity,
      );
      return;
    }

    if (sourceType == 'بيع مواد خام من المعمل' ||
        sourceType == 'مواد خام' ||
        sourceType == 'raw_materials') {
      // مواد خام → Workshop Materials Page (مواد معمل) (m² or m³)
      final stock = _matchWorkshopStock(item);
      if (stock != null) {
        stock.availableQty = (stock.availableQty + quantity).clamp(
          0.0,
          double.infinity,
        );
        return;
      }
      final category = (item.unitCategory == 'متر مكعب' || item.isCubicMeter)
          ? 'متر مكعب'
          : 'متر مربع';
      workshopStock.add(
        WorkshopStockModel(
          id: item.sourceId.isNotEmpty
              ? item.sourceId
              : 'ws_${DateTime.now().microsecondsSinceEpoch}_${workshopStock.length}',
          typeName: item.description.isNotEmpty
              ? item.description
              : 'مادة خام معمل',
          grade: 'درجة أولى',
          thicknessCm: item.thicknessCm > 0
              ? item.thicknessCm
              : (category == 'متر مكعب' ? 10.0 : 2.0),
          category: category,
          availableQty: quantity,
          netCostPerUnit: item.netCost,
          recommendedSalePrice:
              item.unitPrice > 0 ? item.unitPrice : item.agreedPrice,
          isGranite: item.isGranite,
        ),
      );
      return;
    }

    if (sourceType == 'بيع قطع إضافية' ||
        sourceType == 'قطع زائدة' ||
        sourceType == 'scrap' ||
        sourceType == 'surplus') {
      // قطع زائدة → Surplus Page (الزيادة)
      final matches = item.sourceId.isNotEmpty
          ? scrapItems.where((s) => s.id == item.sourceId).toList()
          : scrapItems
              .where((s) =>
                  s.description == item.description && s.isSold)
              .toList();
      if (matches.isNotEmpty) {
        matches.first.isSold = false;
        return;
      }
      scrapItems.add(
        ScrapItemModel(
          id: item.sourceId.isNotEmpty
              ? item.sourceId
              : 'sc_${DateTime.now().microsecondsSinceEpoch}_${scrapItems.length}',
          description: item.description.isNotEmpty
              ? item.description
              : 'قطعة زائدة مرتجعة',
          baseCost: item.netCost,
          sellingPrice: item.agreedPrice,
          isSold: false,
          photoPath: item.photoPath,
          currency: AppCurrency.usd,
        ),
      );
      return;
    }

    // Orders (طلبية معمل) carry no stock page — financial settlement only.
  }

  /// Next sequential return document number (RET-001, RET-102 …).
  String _nextReturnNo() {
    var max = 100;
    for (final ret in returnInvoices) {
      final match = RegExp(r'(\d+)$').firstMatch(ret.returnNo.trim());
      final value = match != null ? int.tryParse(match.group(1)!) : null;
      if (value != null && value > max) max = value;
    }
    return 'RET-${(max + 1).toString().padLeft(3, '0')}';
  }

  /// Creates a return / allowance document against a master invoice.
  ///
  /// * Returns are built from per-line `lines` (quantity × original unit
  ///   price, auto calculated) and are validated so a line can never be
  ///   returned more often than it was invoiced.
  /// * Allowances never touch inventory — only the financial ledger.
  /// * Settlement is either account adjustment (تسوية حساب) or cash through
  ///   the main safe (إلى / من الصندوق); cash only covers the part that is
  ///   not already offset by the party's outstanding balance.
  bool addAdjustmentInvoice(AdjustmentInvoiceModel invoice) {
    const kinds = {
      'purchase_return',
      'sales_return',
      'purchase_allowance',
      'sales_allowance',
    };
    if (!kinds.contains(invoice.kind) ||
        (invoice.module != 'factory' && invoice.module != 'workshop') ||
        invoice.invoiceNo.trim().isEmpty ||
        !invoice.amount.isFinite ||
        !invoice.quantity.isFinite ||
        invoice.quantity < 0) {
      return false;
    }

    final isFactory = invoice.module == 'factory';
    final purchase = invoice.kind.startsWith('purchase');
    final isReturn = invoice.kind.endsWith('return');

    // 1. Resolve and validate the master invoice.
    FactoryInvoiceModel? original;
    WorkshopInvoiceModel? workshopOriginal;
    if (isFactory) {
      final matches = factoryInvoices
          .where((item) => item.id == invoice.targetInvoiceId)
          .toList();
      if (matches.isEmpty) return false;
      original = matches.first;
      if (original.invoiceNo != invoice.targetInvoiceNo ||
          original.partyName != invoice.partyName ||
          (original.invoiceType == 'شراء_مورد') != purchase) {
        return false;
      }
    } else {
      if (purchase) return false;
      final matches = workshopInvoices
          .where((item) => item.id == invoice.targetInvoiceId)
          .toList();
      if (matches.isEmpty) return false;
      workshopOriginal = matches.first;
      if (workshopOriginal.invoiceNo != invoice.targetInvoiceNo ||
          workshopOriginal.clientName != invoice.partyName) {
        return false;
      }
    }

    final partyName = original?.partyName ?? workshopOriginal!.clientName;
    final partyId = original?.partyId ?? '';
    final parentCurrency = AppCurrency.normalize(
      original?.currency ?? workshopOriginal!.currency,
    );
    if (invoice.currency != parentCurrency) return false;

    final originalTotal =
        original?.grandTotal ?? workshopOriginal!.grandTotal;
    final priorAmount = adjustmentInvoices
        .where(
          (doc) =>
              doc.module == invoice.module &&
              doc.targetInvoiceId == invoice.targetInvoiceId,
        )
        .fold<double>(0, (sum, doc) => sum + doc.amount);
    final capacity = originalTotal - priorAmount;

    // 2. Build the document lines.
    final resolved = <_ResolvedReturnLine>[];
    var totalAmount = 0.0;
    var totalQuantity = 0.0;

    if (isReturn) {
      final List<AdjustmentLineModel> rawLines;
      if (invoice.lines.isNotEmpty) {
        rawLines = invoice.lines;
      } else {
        rawLines = [
          AdjustmentLineModel(
            itemId: invoice.itemId,
            itemIndex: invoice.itemIndex,
            description: invoice.itemDescription,
            quantity: invoice.quantity,
            unitPrice: 0,
            amount: 0,
          ),
        ];
      }
      if (rawLines.isEmpty) return false;

      final workshopLines = isFactory
          ? const <WorkshopInvoiceItem>[]
          : _workshopInvoiceLines(workshopOriginal!);

      for (final raw in rawLines) {
        if (!raw.quantity.isFinite || raw.quantity <= 0) return false;

        if (isFactory) {
          final items = original!.items;
          var index = raw.itemIndex;
          if (index < 0 || index >= items.length) {
            index = -1;
            for (var i = 0; i < items.length; i++) {
              final item = items[i];
              final idHit = raw.itemId.isNotEmpty &&
                  item.itemId == raw.itemId;
              final descHit = raw.description.isNotEmpty &&
                  item.description.trim() == raw.description.trim();
              if (idHit || descHit) {
                index = i;
                break;
              }
            }
            if (index < 0) return false;
          }
          if (raw.description.isNotEmpty &&
              items[index].description.trim() != raw.description.trim()) {
            return false;
          }
          resolved.add(_describeFactoryLine(original, index, raw.quantity));
        } else {
          var index = raw.itemIndex;
          if (index < 0 || index >= workshopLines.length) {
            index = -1;
            for (var i = 0; i < workshopLines.length; i++) {
              final item = workshopLines[i];
              final idHit = raw.itemId.isNotEmpty &&
                  item.sourceId == raw.itemId;
              final descHit = raw.description.isNotEmpty &&
                  item.description.trim() == raw.description.trim();
              if (idHit || descHit) {
                index = i;
                break;
              }
            }
            if (index < 0) return false;
          }
          if (raw.description.isNotEmpty &&
              workshopLines[index].description.trim() !=
                  raw.description.trim()) {
            return false;
          }
          resolved.add(_describeWorkshopLine(workshopLines, index, raw.quantity));
        }
      }

      if (invoice.lines.isEmpty && invoice.amount > 0 && resolved.length == 1) {
        final single = resolved.first;
        final explicitPrice = single.line.quantity > 0
            ? _money(invoice.amount / single.line.quantity)
            : invoice.amount;
        resolved[0] = _ResolvedReturnLine(
          line: AdjustmentLineModel(
            itemId: single.line.itemId,
            itemIndex: single.line.itemIndex,
            description: single.line.description,
            unit: single.line.unit,
            quantity: single.line.quantity,
            unitPrice: explicitPrice,
            amount: invoice.amount,
            sourceType: single.line.sourceType,
            sourceLineItemId: single.line.sourceLineItemId,
          ),
          factoryItem: single.factoryItem,
          workshopItem: single.workshopItem,
          unitQty: single.unitQty,
        );
      }

      // 3. Validate every line against the invoiced quantity.
      for (final entry in resolved) {
        final keys = _lineKeys(
          index: entry.line.itemIndex,
          itemId: entry.line.itemId,
          description: entry.line.description,
        );
        final alreadyReturned = _alreadyReturnedQty(
          module: invoice.module,
          targetInvoiceId: invoice.targetInvoiceId,
          keys: keys,
        );
        final invoicedQuantity = isFactory
            ? entry.factoryItem!.quantity
            : entry.workshopItem!.quantity;
        if (invoicedQuantity - alreadyReturned + 0.0001 <
            entry.line.quantity) {
          return false;
        }
        if (entry.line.amount < 0) return false;
        totalAmount = _money(totalAmount + entry.line.amount);
        totalQuantity = _money(totalQuantity + entry.line.quantity);
      }
      if (resolved.isEmpty || totalAmount <= 0) return false;
    } else {
      // Allowance: read-only snapshot of the master invoice lines.
      totalAmount = _money(invoice.amount);
      if (totalAmount <= 0) return false;
      if (isFactory) {
        final parent = original!;
        for (var i = 0; i < parent.items.length; i++) {
          resolved.add(_describeFactoryLine(parent, i, 0));
        }
      } else {
        final lines = _workshopInvoiceLines(workshopOriginal!);
        for (var i = 0; i < lines.length; i++) {
          resolved.add(_describeWorkshopLine(lines, i, 0));
        }
      }
    }

    if (totalAmount > capacity + 0.0001) return false;

    // 4. Inventory routing feasibility (returns only).
    if (isReturn &&
        !_canRouteReturn(
          module: invoice.module,
          purchase: purchase,
          lines: resolved,
          original: original,
          workshopOriginal: workshopOriginal,
        )) {
      return false;
    }

    // 5. Financial settlement.
    const cashAction = 'استرداد نقدي للصندوق الرئيسي';
    const debtAction = 'تخفيض دين';
    final action = invoice.paymentAction;
    if (action != cashAction && action != debtAction) return false;

    var debtPortion = 0.0;
    var cashPortion = 0.0;
    if (action == debtAction) {
      if (!_canReduceAdjustmentDebt(
        supplier: purchase,
        partyName: partyName,
        partyId: partyId,
        currency: invoice.currency,
        amount: totalAmount,
      )) {
        return false;
      }
      debtPortion = totalAmount;
    } else {
      cashPortion = totalAmount;
      if (cashPortion > 0 &&
          !purchase &&
          cashOf('main', invoice.currency) + 0.0001 < cashPortion) {
        return false;
      }
    }

    if (cashPortion > 0) {
      if (purchase) {
        addCash('main', invoice.currency, cashPortion);
      } else if (!takeCash('main', invoice.currency, cashPortion)) {
        return false;
      }
    }
    if (debtPortion > 0) {
      _reduceAdjustmentDebt(
        supplier: purchase,
        partyName: partyName,
        partyId: partyId,
        currency: invoice.currency,
        amount: debtPortion,
      );
    }

    // 6. Route the goods back into their stock pages (returns only).
    if (isReturn) {
      _applyReturnRouting(
        module: invoice.module,
        purchase: purchase,
        lines: resolved,
        original: original,
        workshopOriginal: workshopOriginal,
      );
    }

    // 7. Reduce the master invoice balance by the returned / allowed amount.
    if (original != null) {
      original.adjustmentsAmount = _money(
        original.adjustmentsAmount + totalAmount,
      );
      original.paymentStatus = original.remainingBalance > 0.01
          ? 'مستحق الدفع'
          : 'مدفوعة';
    } else {
      workshopOriginal!.adjustmentsAmount = _money(
        workshopOriginal.adjustmentsAmount + totalAmount,
      );
    }

    // 8. Persist the document (clean link back to the master invoice).
    final stored = AdjustmentInvoiceModel(
      id: invoice.id,
      invoiceNo: invoice.invoiceNo,
      module: invoice.module,
      kind: invoice.kind,
      targetInvoiceId: invoice.targetInvoiceId,
      targetInvoiceNo: invoice.targetInvoiceNo,
      itemId: resolved.isNotEmpty ? resolved.first.line.itemId : invoice.itemId,
      itemDescription: resolved.isNotEmpty
          ? resolved
                .map((entry) => entry.line.description)
                .where((text) => text.trim().isNotEmpty)
                .join(' + ')
            : invoice.itemDescription,
      itemIndex: resolved.isNotEmpty ? resolved.first.line.itemIndex : -1,
      partyName: partyName,
      description: invoice.description,
      amount: totalAmount,
      quantity: totalQuantity,
      paymentAction: action,
      currency: invoice.currency,
      date: invoice.date,
      lines: [for (final entry in resolved) entry.line],
    );
    adjustmentInvoices.add(stored);

    // 9. Mirror returns into the printable / reportable return register.
    if (isReturn) {
      final returnType = purchase
          ? 'مرتجع مشتريات مورد'
          : isFactory
          ? 'مرتجع مبيعات مصنع'
          : 'مرتجع مبيعات معمل';
      final units = resolved
          .map((entry) => entry.line.unit)
          .where((unit) => unit.trim().isNotEmpty)
          .toSet()
          .join(' / ');
      returnInvoices.add(
        ReturnInvoiceModel(
          id: 'ret_${DateTime.now().microsecondsSinceEpoch}',
          returnNo: _nextReturnNo(),
          date: stored.date,
          returnType: returnType,
          partyName: partyName,
          itemDescription: stored.itemDescription,
          quantity: totalQuantity,
          refundAmount: totalAmount,
          paymentAction: action,
          currency: invoice.currency,
          parentInvoiceId: invoice.targetInvoiceId,
          parentInvoiceNo: invoice.targetInvoiceNo,
          unit: units,
          cashAmount: cashPortion,
        ),
      );
    }

    refresh();
    return true;
  }

  /// Quantity of one master-invoice line that has already been returned.
  /// Used by the UI to cap the "returned quantity" input per line.
  double returnedQuantityOf({
    required String module,
    required String targetInvoiceId,
    required int lineIndex,
    required String itemId,
    required String description,
  }) => _alreadyReturnedQty(
    module: module,
    targetInvoiceId: targetInvoiceId,
    keys: _lineKeys(
      index: lineIndex,
      itemId: itemId,
      description: description,
    ),
  );

  /// Outstanding balance of a party (supplier or client) used by the returns
  /// engine to split a settlement between the safe and the account.
  double partyAdjustmentBalanceOf({
    required bool supplier,
    required String partyName,
    required String partyId,
    required String currency,
  }) => _adjustmentDebtBalance(
    supplier: supplier,
    partyName: partyName,
    partyId: partyId,
    currency: currency,
  );

  /// Materialized line items of a workshop invoice (legacy invoices keep
  /// their data in the scalar fields instead of an items list).
  List<WorkshopInvoiceItem> workshopInvoiceLines(WorkshopInvoiceModel inv) =>
      _workshopInvoiceLines(inv);

  bool _canReduceAdjustmentDebt({
    required bool supplier,
    required String partyName,
    required String partyId,
    required String currency,
    required double amount,
  }) =>
      _adjustmentDebtBalance(
            supplier: supplier,
            partyName: partyName,
            partyId: partyId,
            currency: currency,
          ) +
          0.0001 >=
      amount;

  double _adjustmentDebtBalance({
    required bool supplier,
    required String partyName,
    required String partyId,
    required String currency,
  }) {
    final liveBalance = supplier
        ? suppliers
              .where(
                (item) =>
                    (partyId.isNotEmpty && item.id == partyId) ||
                    item.name == partyName,
              )
              .fold<double>(0, (sum, item) => sum + item.debtOf(currency))
        : clients
              .where(
                (item) =>
                    (partyId.isNotEmpty && item.id == partyId) ||
                    item.name == partyName,
              )
              .fold<double>(0, (sum, item) => sum + item.debtOf(currency));
    final category = supplier ? 'suppliers' : 'clients';
    final historicalBalance = openingEntry.legacyFinancials
        .where(
          (item) =>
              item.category == category &&
              item.name == partyName &&
              item.currency == AppCurrency.normalize(currency),
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    return liveBalance + historicalBalance;
  }

  void _reduceAdjustmentDebt({
    required bool supplier,
    required String partyName,
    required String partyId,
    required String currency,
    required double amount,
  }) {
    var remaining = amount;
    if (supplier) {
      for (final account in suppliers.where(
        (item) =>
            (partyId.isNotEmpty && item.id == partyId) ||
            item.name == partyName,
      )) {
        if (remaining <= 0) break;
        final take = account.debtOf(currency).clamp(0.0, remaining).toDouble();
        account.reduceDebt(currency, take);
        remaining -= take;
      }
    } else {
      for (final account in clients.where(
        (item) =>
            (partyId.isNotEmpty && item.id == partyId) ||
            item.name == partyName,
      )) {
        if (remaining <= 0) break;
        final take = account.debtOf(currency).clamp(0.0, remaining).toDouble();
        account.reduceDebt(currency, take);
        remaining -= take;
      }
    }

    final category = supplier ? 'suppliers' : 'clients';
    final historicalAccounts = openingEntry.legacyFinancials
        .where(
          (item) =>
              item.category == category &&
              item.name == partyName &&
              item.currency == AppCurrency.normalize(currency),
        )
        .toList();
    for (final account in historicalAccounts) {
      if (remaining <= 0) break;
      final take = account.amount.clamp(0.0, remaining).toDouble();
      account.amount -= take;
      remaining -= take;
    }
    _syncOpeningFinancialTotals();
  }

  bool purchaseFixedAsset({
    required String category,
    required String name,
    required double amount,
    required String currency,
    required String description,
  }) {
    if (amount <= 0 ||
        name.trim().isEmpty ||
        !takeCash('main', currency, amount)) {
      return false;
    }
    _materializeLegacyFixedAssets();
    openingEntry.fixedAssets.add(
      FixedAssetModel(
        id: 'asset_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        name: name.trim(),
        amount: amount,
        currency: AppCurrency.normalize(currency),
        description: description,
      ),
    );
    notifyListeners();
    saveToDisk();
    return true;
  }

  void _materializeLegacyFixedAssets() {
    if (openingEntry.fixedAssets.isNotEmpty) return;
    final legacy = [
      (
        'land',
        'أراضي',
        'أصول افتتاحية غير مفصلة • أراضي',
        openingEntry.landValue,
      ),
      (
        'buildings',
        'مباني وعقارات',
        'أصول افتتاحية غير مفصلة • مبانٍ',
        openingEntry.buildingsValue,
      ),
      (
        'machinery',
        'آلات ومعدات',
        'أصول افتتاحية غير مفصلة • آلات',
        openingEntry.machineryValue,
      ),
      (
        'vehicles',
        'آليات ونقل',
        'أصول افتتاحية غير مفصلة • آليات',
        openingEntry.vehiclesValue,
      ),
      (
        'furniture',
        'أثاث',
        'أصول افتتاحية غير مفصلة • أثاث',
        openingEntry.furnitureValue,
      ),
    ];
    for (final (id, category, name, amount) in legacy) {
      if (amount <= 0) continue;
      openingEntry.fixedAssets.add(
        FixedAssetModel(
          id: 'legacy_asset_$id',
          category: category,
          name: name,
          amount: amount,
          description: 'قيمة افتتاحية سابقة دون تفاصيل فردية.',
          currency: AppCurrency.usd,
        ),
      );
    }
  }

  bool sellFixedAsset({
    required String assetId,
    required double saleAmount,
    required String currency,
    Map<String, bool>? partnerTransfers,
  }) {
    final assetIndex = openingEntry.fixedAssets.indexWhere(
      (item) => item.id == assetId,
    );
    if (assetIndex < 0) return false;
    final asset = openingEntry.fixedAssets[assetIndex];

    final c = AppCurrency.normalize(currency);
    if (saleAmount <= 0 || asset.currency != c) {
      return false;
    }

    // 1. The full amount enters the Main Safe
    addCash('main', c, saleAmount);

    // 2. Subtraction process:
    // When Selling Price > Initial Registered Price:
    // (Selling Price - Initial Registered Price) goes to Profits/Gains in Income Summary.
    // When Selling Price < Initial Registered Price:
    // (Initial Registered Price - Selling Price) goes to Losses in Income Summary.
    // When Selling Price == Initial Registered Price:
    // Gain/Loss is 0.
    final record = AssetSaleRecordModel(
      id: 'asset_sale_${DateTime.now().microsecondsSinceEpoch}',
      assetId: asset.id,
      assetName: asset.name,
      category: asset.category,
      registeredPrice: asset.amount,
      salePrice: saleAmount,
      currency: c,
      saleDate: DateTime.now(),
      description: asset.description,
    );
    assetSaleRecords.add(record);

    // 3. The fixed asset is completely removed / deleted
    openingEntry.fixedAssets.removeAt(assetIndex);
    _syncOpeningAssetTotals();

    // 4. Capital balance remains as originally entered and is not affected.

    notifyListeners();
    saveToDisk();
    return true;
  }

  bool settleLegacyFinancialRecord(
    String recordId,
    double amount,
    String cashBox,
  ) {
    final record = openingEntry.legacyFinancials.firstWhere(
      (item) => item.id == recordId,
      orElse: () => throw StateError('Historical balance was not found.'),
    );
    if (amount <= 0 || amount > record.amount) return false;
    if (record.category == 'clients') {
      addCash(cashBox, record.currency, amount);
    } else if (!takeCash(cashBox, record.currency, amount)) {
      return false;
    }
    record.amount -= amount;
    _syncOpeningFinancialTotals();
    notifyListeners();
    saveToDisk();
    return true;
  }

  // ---- Per-person debts, split by currency (one account holds both) ----
  double get clientsTotalDebts =>
      clients.fold(0.0, (s, c) => s + c.debtBalance);
  double get clientsTotalDebtsSyp =>
      clients.fold(0.0, (s, c) => s + c.debtBalanceSyp);
  double get suppliersTotalDebts =>
      suppliers.fold(0.0, (s, sup) => s + sup.debtBalance);
  double get suppliersTotalDebtsSyp =>
      suppliers.fold(0.0, (s, sup) => s + sup.debtBalanceSyp);
  double get workersTotalDebts =>
      staffList.fold(0.0, (s, stf) => s + stf.netRemainingBalance);
  double get workersTotalDebtsSyp =>
      staffList.fold(0.0, (s, stf) => s + stf.netRemainingBalanceSyp);
  double get clientsRetailDebts => clients
      .where((c) => c.clientType == 'زبون معمل')
      .fold(0.0, (s, c) => s + c.debtBalance);
  double get clientsRetailDebtsSyp => clients
      .where((c) => c.clientType == 'زبون معمل')
      .fold(0.0, (s, c) => s + c.debtBalanceSyp);
  double get clientsProjectDebts => clients
      .where((c) => c.clientType == 'مشروع معمل')
      .fold(0.0, (s, c) => s + c.debtBalance);
  double get clientsProjectDebtsSyp => clients
      .where((c) => c.clientType == 'مشروع معمل')
      .fold(0.0, (s, c) => s + c.debtBalanceSyp);
  double clientsApprovedDebtsOf(String? currency) => clients
      .where((c) => c.clientType == 'معتمد مصنع')
      .fold(0.0, (s, c) => s + c.debtOf(currency));

  // Granite 50% Accountant Net Profit Ledger Calculation (per currency)
  double graniteTotalRevenueOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    double total = 0.0;
    for (var inv in factoryInvoices.where((i) => i.currency == c)) {
      for (var item in inv.items) {
        if (item.isGranite) total += item.totalPrice;
      }
    }
    for (var inv in workshopInvoices.where((i) => i.currency == c)) {
      if (inv.isGranite) total += inv.agreedPrice;
    }
    return total;
  }

  double graniteTotalCOGSOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    double total = 0.0;
    for (var inv in factoryInvoices.where((i) => i.currency == c)) {
      for (var item in inv.items) {
        if (item.isGranite) total += item.totalCost;
      }
    }
    for (var inv in workshopInvoices.where((i) => i.currency == c)) {
      if (inv.isGranite) total += inv.netCost;
    }
    return total;
  }

  double get graniteTotalRevenue => graniteTotalRevenueOf(AppCurrency.usd);
  double get graniteTotalRevenueSyp => graniteTotalRevenueOf(AppCurrency.syp);
  double get graniteTotalCOGS => graniteTotalCOGSOf(AppCurrency.usd);
  double get graniteTotalCOGSSyp => graniteTotalCOGSOf(AppCurrency.syp);

  double netGraniteProfitOf(String? currency) =>
      (graniteTotalRevenueOf(currency) - graniteTotalCOGSOf(currency)).clamp(
        0.0,
        double.infinity,
      );
  double get netGraniteProfit => netGraniteProfitOf(AppCurrency.usd);
  double get netGraniteProfitSyp => netGraniteProfitOf(AppCurrency.syp);

  double accountantGraniteShareOf(String? currency) =>
      netGraniteProfitOf(currency) * (graniteAccountantPercentage / 100.0);
  double get accountantGraniteShare =>
      accountantGraniteShareOf(AppCurrency.usd);
  double get accountantGraniteShareSyp =>
      accountantGraniteShareOf(AppCurrency.syp);

  double accountantTotalWithdrawnOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return accountantWithdrawals
        .where((w) => w.currency == c)
        .fold(0.0, (s, w) => s + w.amount);
  }

  double get accountantTotalWithdrawnUsd =>
      accountantTotalWithdrawnOf(AppCurrency.usd);
  double get accountantTotalWithdrawnSyp =>
      accountantTotalWithdrawnOf(AppCurrency.syp);

  double accountantAvailableBalanceOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return accountantGraniteShareOf(c) - accountantTotalWithdrawnOf(c);
  }

  double get accountantAvailableBalanceUsd =>
      accountantAvailableBalanceOf(AppCurrency.usd);
  double get accountantAvailableBalanceSyp =>
      accountantAvailableBalanceOf(AppCurrency.syp);

  void setGraniteAccountantPercentage(double pct) {
    graniteAccountantPercentage = pct.clamp(0.0, 100.0);
    notifyListeners();
    saveToDisk();
  }

  bool withdrawAccountantProfit({
    required double amount,
    required String currency,
    required String cashBox,
    String notes = '',
    String recipient = 'محاسب الغرانيت',
    MutableWrapper<String?>? outWarning,
  }) {
    final c = AppCurrency.normalize(currency);
    if (amount <= 0) {
      outWarning?.value = 'يرجى إدخال مبلغ صحيح أكبر من الصفر.';
      return false;
    }
    final available = accountantAvailableBalanceOf(c);
    if (amount > available + 0.0001) {
      outWarning?.value =
          'المبلغ المطلوب (${amount.fmt} ${AppCurrency.symbol(c)}) يتجاوز رصيد الأرباح المتبقي والمتاح للسحب (${available.fmt} ${AppCurrency.symbol(c)})!';
      return false;
    }
    if (cashBox != 'direct') {
      if (cashOf(cashBox, c) + 0.0001 < amount) {
        outWarning?.value =
            'رصيد الصندوق المحدد لا يكفي لتغطية مبلغ السحب المطلوب!';
        return false;
      }
      takeCash(cashBox, c, amount);
    }
    final withdrawal = AccountantWithdrawalModel(
      id: 'WDR-ACC-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      amount: amount,
      currency: c,
      cashBox: cashBox,
      notes: notes,
      recipient: recipient,
    );
    accountantWithdrawals.insert(0, withdrawal);
    notifyListeners();
    saveToDisk();
    return true;
  }

  bool deleteAccountantWithdrawal(String id) {
    final idx = accountantWithdrawals.indexWhere((w) => w.id == id);
    if (idx == -1) return false;
    final w = accountantWithdrawals[idx];
    if (w.cashBox != 'direct') {
      addCash(w.cashBox, w.currency, w.amount);
    }
    accountantWithdrawals.removeAt(idx);
    notifyListeners();
    saveToDisk();
    return true;
  }

  // Income Statement (P&L) Calculations — Cash-Collected Revenue Model (per currency)
  double totalFactoryRevenueOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    final invoiceCollections = factoryInvoices
        .where(
          (i) =>
              i.invoiceType == 'بيع_معتمد' &&
              i.currency == c,
        )
        .fold(0.0, (s, i) => s + i.advancePayment.clamp(0.0, i.grandTotal));
    final unallocated = c == AppCurrency.usd
        ? unallocatedFactoryCollectionsUsd
        : unallocatedFactoryCollectionsSyp;
    return invoiceCollections + unallocated;
  }

  double totalWorkshopRevenueOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    final invoiceCollections = workshopInvoices
        .where((i) => i.currency == c)
        .fold(
          0.0,
          (s, i) =>
              s +
              (i.depositDeducted + i.cashPaidNow).clamp(0.0, i.grandTotal),
        );
    final unallocated = c == AppCurrency.usd
        ? unallocatedWorkshopCollectionsUsd
        : unallocatedWorkshopCollectionsSyp;
    return invoiceCollections + unallocated;
  }

  double totalScrapRevenueOf(String? currency) => scrapItems
      .where((i) => i.isSold && i.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, i) => s + i.sellingPrice);
  double totalKeptDepositsRevenueOf(String? currency) => workshopOrders
      .where(
        (o) =>
            o.status == 'ملغاة' &&
            !o.isSpecialRefund &&
            o.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (s, o) => s + o.depositAmount);

  double get totalFactoryRevenue => totalFactoryRevenueOf(AppCurrency.usd);
  double get totalFactoryRevenueSyp => totalFactoryRevenueOf(AppCurrency.syp);
  double get totalWorkshopRevenue => totalWorkshopRevenueOf(AppCurrency.usd);
  double get totalWorkshopRevenueSyp => totalWorkshopRevenueOf(AppCurrency.syp);
  double get totalScrapRevenue => totalScrapRevenueOf(AppCurrency.usd);
  double get totalScrapRevenueSyp => totalScrapRevenueOf(AppCurrency.syp);
  double get totalKeptDepositsRevenue =>
      totalKeptDepositsRevenueOf(AppCurrency.usd);
  double get totalKeptDepositsRevenueSyp =>
      totalKeptDepositsRevenueOf(AppCurrency.syp);

  double serviceRevenueOf(String? currency) {
    return factoryServiceRevenueOf(currency) +
        workshopServiceRevenueOf(currency);
  }

  double factoryServiceRevenueOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return factoryInvoices
        .where(
          (invoice) =>
              invoice.invoiceType == 'بيع_معتمد' &&
              invoice.currency == c,
        )
        .fold<double>(
          0.0,
          (sum, invoice) {
            final services =
                invoice.servicesTotal + invoice.itemsServicesTotal;
            if (services <= 0) return sum;
            final ratio = invoice.grandTotal > 0.0001
                ? (invoice.advancePayment.clamp(0.0, invoice.grandTotal) /
                        invoice.grandTotal)
                    .clamp(0.0, 1.0)
                : 0.0;
            return sum + (services * ratio);
          },
        );
  }

  double workshopServiceRevenueOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return workshopInvoices
        .where((invoice) => invoice.currency == c)
        .fold<double>(
          0.0,
          (sum, invoice) {
            final services = invoice.servicesTotal;
            if (services <= 0) return sum;
            final paid = (invoice.depositDeducted + invoice.cashPaidNow)
                .clamp(0.0, invoice.grandTotal);
            final ratio = invoice.grandTotal > 0.0001
                ? (paid / invoice.grandTotal).clamp(0.0, 1.0)
                : 0.0;
            return sum + (services * ratio);
          },
        );
  }

  double factorySalesDiscountOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return factoryInvoices
        .where(
          (invoice) =>
              invoice.invoiceType == 'بيع_معتمد' &&
              invoice.currency == c,
        )
        .fold<double>(
          0.0,
          (sum, invoice) {
            final discount = invoice.discountAmount;
            if (discount <= 0) return sum;
            final ratio = invoice.grandTotal > 0.0001
                ? (invoice.advancePayment.clamp(0.0, invoice.grandTotal) /
                        invoice.grandTotal)
                    .clamp(0.0, 1.0)
                : 0.0;
            return sum + (discount * ratio);
          },
        );
  }

  double workshopSalesDiscountOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return workshopInvoices
        .where((invoice) => invoice.currency == c)
        .fold<double>(
          0.0,
          (sum, invoice) {
            final discount = invoice.salesDiscount;
            if (discount <= 0) return sum;
            final paid = (invoice.depositDeducted + invoice.cashPaidNow)
                .clamp(0.0, invoice.grandTotal);
            final ratio = invoice.grandTotal > 0.0001
                ? (paid / invoice.grandTotal).clamp(0.0, 1.0)
                : 0.0;
            return sum + (discount * ratio);
          },
        );
  }

  double get salesDiscounts => salesDiscountsOf(AppCurrency.usd);
  double get salesDiscountsSyp => salesDiscountsOf(AppCurrency.syp);
  double salesDiscountsOf(String? currency) =>
      factorySalesDiscountOf(currency) + workshopSalesDiscountOf(currency);

  double adjustmentTotalOf(String kind, String? currency) => adjustmentInvoices
      .where(
        (invoice) =>
            invoice.kind == kind &&
            invoice.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, invoice) => sum + invoice.amount);

  double get purchaseReturnsAndAllowances =>
      adjustmentTotalOf('purchase_return', AppCurrency.usd) +
      adjustmentTotalOf('purchase_allowance', AppCurrency.usd);
  double get purchaseReturnsAndAllowancesSyp =>
      adjustmentTotalOf('purchase_return', AppCurrency.syp) +
      adjustmentTotalOf('purchase_allowance', AppCurrency.syp);
  double get salesReturnsAndAllowances =>
      adjustmentTotalOf('sales_return', AppCurrency.usd) +
      adjustmentTotalOf('sales_allowance', AppCurrency.usd);
  double get salesReturnsAndAllowancesSyp =>
      adjustmentTotalOf('sales_return', AppCurrency.syp) +
      adjustmentTotalOf('sales_allowance', AppCurrency.syp);
  double supplierDiscountsOf(String? currency) => factoryInvoices
      .where(
        (invoice) =>
            invoice.invoiceType == 'شراء_مورد' &&
            invoice.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, invoice) => sum + invoice.discountAmount);

  double assetSaleGainsOf(String? currency) => assetSaleRecords
      .where(
        (record) =>
            record.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, record) => sum + record.gain);
  double get assetSaleGains => assetSaleGainsOf(AppCurrency.usd);
  double get assetSaleGainsSyp => assetSaleGainsOf(AppCurrency.syp);

  double assetSaleLossesOf(String? currency) => assetSaleRecords
      .where(
        (record) =>
            record.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, record) => sum + record.loss);
  double get assetSaleLosses => assetSaleLossesOf(AppCurrency.usd);
  double get assetSaleLossesSyp => assetSaleLossesOf(AppCurrency.syp);

  double assetSaleRevenueOf(String? currency) => assetSaleGainsOf(currency);

  double expenseRecordsTotalOf(String? currency) => expenseRecords
      .where((expense) =>
          !expense.isInformational &&
          expense.currency == AppCurrency.normalize(currency))
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double totalAdvanceRepaymentsRevenueOf(String? currency) =>
      advanceRepayments
          .where((r) => r.collectedCurrency == AppCurrency.normalize(currency))
          .fold<double>(0.0, (sum, r) => sum + r.collectedAmount);
  double get totalAdvanceRepaymentsRevenue =>
      totalAdvanceRepaymentsRevenueOf(AppCurrency.usd);
  double get totalAdvanceRepaymentsRevenueSyp =>
      totalAdvanceRepaymentsRevenueOf(AppCurrency.syp);

  double totalRevenuesOf(String? currency) =>
      totalFactoryRevenueOf(currency) +
      totalWorkshopRevenueOf(currency) +
      totalScrapRevenueOf(currency) +
      totalKeptDepositsRevenueOf(currency) +
      salesDiscountsOf(currency) +
      adjustmentTotalOf('purchase_return', currency) +
      adjustmentTotalOf('purchase_allowance', currency) +
      supplierDiscountsOf(currency) +
      assetSaleRevenueOf(currency) +
      totalAdvanceRepaymentsRevenueOf(currency);
  double get totalRevenues => totalRevenuesOf(AppCurrency.usd);
  double get totalRevenuesSyp => totalRevenuesOf(AppCurrency.syp);

  double totalFactoryCOGSOf(String? currency) => factoryInvoices
      .where(
        (i) =>
            i.invoiceType == 'بيع_معتمد' &&
            i.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (s, i) => s + i.totalCOGS);
  double totalWorkshopCOGSOf(String? currency) => workshopInvoices
      .where((i) => i.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, i) => s + i.netCost);
  double get totalFactoryCOGS => totalFactoryCOGSOf(AppCurrency.usd);
  double get totalFactoryCOGSSyp => totalFactoryCOGSOf(AppCurrency.syp);
  double get totalWorkshopCOGS => totalWorkshopCOGSOf(AppCurrency.usd);
  double get totalWorkshopCOGSSyp => totalWorkshopCOGSOf(AppCurrency.syp);
  double totalCOGSOf(String? currency) =>
      totalFactoryCOGSOf(currency) + totalWorkshopCOGSOf(currency);
  double get totalCOGS => totalCOGSOf(AppCurrency.usd);
  double get totalCOGSSyp => totalCOGSOf(AppCurrency.syp);

  double totalUnnaturalWasteLossesOf(String? currency) => wasteLogs
      .where(
        (w) =>
            w.wasteType == 'هدر غير طبيعي' &&
            w.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (s, w) => s + w.cost);
  double totalOperationalExpensesOf(String? currency) => workdayEntries
      .where(
        (entry) =>
            entry.staffId.isEmpty &&
            entry.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (sum, entry) => sum + entry.grandTotal);
  double get totalUnnaturalWasteLosses =>
      totalUnnaturalWasteLossesOf(AppCurrency.usd);
  double get totalUnnaturalWasteLossesSyp =>
      totalUnnaturalWasteLossesOf(AppCurrency.syp);
  double get totalOperationalExpenses =>
      totalOperationalExpensesOf(AppCurrency.usd);
  double get totalOperationalExpensesSyp =>
      totalOperationalExpensesOf(AppCurrency.syp);

  // -------------------------------------------------------------
  // SURPLUS FINANCIALS (مالية الزيادات) — isolated Surplus Fund loop:
  // expenses are paid FROM the Surplus Fund, sales revenues go INTO it.
  // -------------------------------------------------------------
  /// Alias: the Surplus Fund IS the isolated scrap cash box (USD fund).
  double get surplusFundBalance => scrapCashBox;
  double get surplusFundBalanceSyp => scrapCashBoxSyp;

  /// Sum of initial prices across all surplus items (incurred cost).
  /// 0/empty initial price => 100% margin item (no cost rows required).
  double totalSurplusInitialCostOf(String? currency) => scrapItems
      .where((i) => i.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, i) => s + i.baseCost);
  double get totalSurplusInitialCost =>
      totalSurplusInitialCostOf(AppCurrency.usd);
  double get totalSurplusInitialCostSyp =>
      totalSurplusInitialCostOf(AppCurrency.syp);

  /// Cash revenue from direct surplus sales (sold items at selling price).
  double surplusSoldItemsRevenueOf(String? currency) => scrapItems
      .where((i) => i.isSold && i.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, i) => s + i.sellingPrice);
  double get surplusSoldItemsRevenue =>
      surplusSoldItemsRevenueOf(AppCurrency.usd);
  double get surplusSoldItemsRevenueSyp =>
      surplusSoldItemsRevenueOf(AppCurrency.syp);

  /// Cash revenue from surplus workshop invoices NOT linked to a stock item
  /// (linked invoices already flip the item to sold, so their cash is
  /// represented by the sold-items revenue above — excluded to avoid double).
  double surplusInvoicesRevenueOf(String? currency) => workshopInvoices
      .where(
        (i) =>
            i.sourceType == 'قطع زائدة' &&
            i.currency == AppCurrency.normalize(currency) &&
            (i.sourceId.isEmpty ||
                !scrapItems.any((sc) => sc.id == i.sourceId)),
      )
      .fold(0.0, (s, i) => s + i.cashPaidNow + i.depositDeducted);
  double get surplusInvoicesRevenue =>
      surplusInvoicesRevenueOf(AppCurrency.usd);
  double get surplusInvoicesRevenueSyp =>
      surplusInvoicesRevenueOf(AppCurrency.syp);

  double totalSurplusRevenueOf(String? currency) =>
      surplusSoldItemsRevenueOf(currency) + surplusInvoicesRevenueOf(currency);
  double get totalSurplusRevenue => totalSurplusRevenueOf(AppCurrency.usd);
  double get totalSurplusRevenueSyp => totalSurplusRevenueOf(AppCurrency.syp);

  double totalSurplusCostDueOf(String? currency) => surplusCosts
      .where((c) => c.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, c) => s + c.amountDue);
  double totalSurplusCostPaidOf(String? currency) => surplusCosts
      .where((c) => c.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, c) => s + c.amountPaid);
  double totalSurplusCostRemainingOf(String? currency) => surplusCosts
      .where((c) => c.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, c) => s + c.remaining);
  double get totalSurplusCostDue => totalSurplusCostDueOf(AppCurrency.usd);
  double get totalSurplusCostDueSyp => totalSurplusCostDueOf(AppCurrency.syp);
  double get totalSurplusCostPaid => totalSurplusCostPaidOf(AppCurrency.usd);
  double get totalSurplusCostPaidSyp => totalSurplusCostPaidOf(AppCurrency.syp);
  double get totalSurplusCostRemaining =>
      totalSurplusCostRemainingOf(AppCurrency.usd);
  double get totalSurplusCostRemainingSyp =>
      totalSurplusCostRemainingOf(AppCurrency.syp);
  double get totalSurplusWorkerDue => surplusCosts
      .where((c) => c.kind == 'worker' && c.currency == AppCurrency.usd)
      .fold(0.0, (s, c) => s + c.amountDue);
  double get totalSurplusWorkerDueSyp => surplusCosts
      .where((c) => c.kind == 'worker' && c.currency == AppCurrency.syp)
      .fold(0.0, (s, c) => s + c.amountDue);
  double get totalSurplusExpenseDue => surplusCosts
      .where((c) => c.kind == 'expense' && c.currency == AppCurrency.usd)
      .fold(0.0, (s, c) => s + c.amountDue);
  double get totalSurplusExpenseDueSyp => surplusCosts
      .where((c) => c.kind == 'expense' && c.currency == AppCurrency.syp)
      .fold(0.0, (s, c) => s + c.amountDue);

  /// Net surplus profit: revenues minus incurred initial cost.
  double netSurplusProfitOf(String? currency) =>
      totalSurplusRevenueOf(currency) - totalSurplusInitialCostOf(currency);
  double get netSurplusProfit => netSurplusProfitOf(AppCurrency.usd);
  double get netSurplusProfitSyp => netSurplusProfitOf(AppCurrency.syp);

  List<SurplusCostModel> surplusCostsForItem(String surplusItemId) =>
      surplusCosts.where((c) => c.surplusItemId == surplusItemId).toList();

  double surplusItemPaid(String surplusItemId) =>
      surplusCostsForItem(surplusItemId).fold(0.0, (s, c) => s + c.amountPaid);

  double surplusItemRemaining(String surplusItemId) =>
      surplusCostsForItem(surplusItemId).fold(0.0, (s, c) => s + c.remaining);

  ExpenseTypeModel ensureBlockPurchaseExpenseType() {
    final matching = expenseTypes
        .where(
          (t) =>
              t.id == blockPurchaseExpenseTypeId ||
              t.name.trim() == 'مشتريات البلوكات' ||
              t.name.contains('Block Purchase') ||
              t.name.contains('مشتريات البلوكات'),
        )
        .toList();
    if (matching.isNotEmpty) return matching.first;
    final newType = ExpenseTypeModel(
      id: blockPurchaseExpenseTypeId,
      name: 'مشتريات البلوكات (Block Purchases)',
      description: 'دفعات ومشتريات كتل الرخام والغرانيت من الموردين',
    );
    expenseTypes.add(newType);
    return newType;
  }

  ExpenseTypeModel ensureCuttingExpenseType() {
    final matching = expenseTypes
        .where(
          (t) =>
              t.id == cuttingExpenseTypeId ||
              t.name.trim() == 'مصاريف القص والتصنيع' ||
              t.name.contains('Cutting Expenses') ||
              t.name.contains('مصاريف القص والتصنيع') ||
              t.name.contains('أجور القص'),
        )
        .toList();
    if (matching.isNotEmpty) return matching.first;
    final newType = ExpenseTypeModel(
      id: cuttingExpenseTypeId,
      name: 'مصاريف القص والتصنيع (Cutting Expenses)',
      description: 'أجور ونسب قص وتصنيع كتل الرخام والغرانيت',
    );
    expenseTypes.add(newType);
    return newType;
  }

  void recordBlockPurchaseExpense({
    required double amount,
    required String currency,
    required String supplierName,
    required String note,
    DateTime? date,
  }) {
    if (amount <= 0.0001) return;
    final type = ensureBlockPurchaseExpenseType();
    expenseRecords.add(
      ExpenseRecordModel(
        id: 'exp_blk_${DateTime.now().microsecondsSinceEpoch}',
        typeId: type.id,
        amount: amount,
        currency: AppCurrency.normalize(currency),
        personName: supplierName,
        description: note,
        date: date ?? DateTime.now(),
      ),
    );
  }

  void recordCuttingExpense({
    required double amount,
    required String currency,
    required String typeName,
    required String grade,
    required double feePercent,
    DateTime? date,
  }) {
    if (amount <= 0.0001) return;
    final type = ensureCuttingExpenseType();
    expenseRecords.add(
      ExpenseRecordModel(
        id: 'exp_cut_${DateTime.now().microsecondsSinceEpoch}',
        typeId: type.id,
        amount: amount,
        currency: AppCurrency.normalize(currency),
        personName: 'قسم القص والتصنيع',
        description:
            'أجرة قص وتصنيع: $typeName ($grade) - نسبة ${(feePercent * 100).fmt}%',
        date: date ?? DateTime.now(),
      ),
    );
  }

  double totalBlockPurchaseExpensesOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return expenseRecords
        .where(
          (e) =>
              !e.isInformational &&
              (e.typeId == blockPurchaseExpenseTypeId ||
                  e.typeId == 'block_purchase_expense' ||
                  e.description.contains('شراء بلوكات') ||
                  e.description.contains('مشتريات بلوكات')) &&
              e.currency == c,
        )
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get totalBlockPurchaseExpenses =>
      totalBlockPurchaseExpensesOf(AppCurrency.usd);
  double get totalBlockPurchaseExpensesSyp =>
      totalBlockPurchaseExpensesOf(AppCurrency.syp);

  double totalCuttingExpensesOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return expenseRecords
        .where(
          (e) =>
              !e.isInformational &&
              (e.typeId == cuttingExpenseTypeId ||
                  e.typeId == 'cutting_expenses' ||
                  e.description.contains('قص وتصنيع') ||
                  e.description.contains('أجرة قص')) &&
              e.currency == c,
        )
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get totalCuttingExpenses => totalCuttingExpensesOf(AppCurrency.usd);
  double get totalCuttingExpensesSyp => totalCuttingExpensesOf(AppCurrency.syp);

  double totalDirectExpensesOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return expenseRecordsTotalOf(c) +
        totalOperationalExpensesOf(c) +
        totalUnnaturalWasteLossesOf(c) +
        totalSurplusInitialCostOf(c) +
        accountantGraniteShareOf(c) +
        salesReturnsAndAllowancesOf(c) +
        salesDiscountsOf(c) +
        assetSaleLossesOf(c);
  }

  double get totalDirectExpenses => totalDirectExpensesOf(AppCurrency.usd);
  double get totalDirectExpensesSyp => totalDirectExpensesOf(AppCurrency.syp);

  double netOperatingProfitOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return totalRevenuesOf(c) - totalDirectExpensesOf(c);
  }

  double salesReturnsAndAllowancesOf(String? currency) =>
      adjustmentTotalOf('sales_return', currency) +
      adjustmentTotalOf('sales_allowance', currency);

  double get netOperatingProfit => netOperatingProfitOf(AppCurrency.usd);
  double get netOperatingProfitSyp => netOperatingProfitOf(AppCurrency.syp);

  // -------------------------------------------------------------
  // ACTIONS & TRANSACTIONS (ACID Lock Simulation)
  // -------------------------------------------------------------

  // 1. Opening Entry Lock
  /// Sets the initial ownership percentage (0-100) of a partner during the
  /// opening entry draft. Only allowed before the entry is approved.
  void setOpeningPartnerPercent(String partnerId, double percent) {
    if (openingEntry.isLocked) return;
    final index = partners.indexWhere((p) => p.id == partnerId);
    if (index < 0) return;
    partners[index].ratio = (percent < 0 ? 0 : percent) / 100.0;
    if (partners.isNotEmpty) openingEntry.hassanRatio = partners[0].ratio;
    if (partners.length > 1) openingEntry.adnanRatio = partners[1].ratio;
    if (partners.length > 2) openingEntry.abdelMoeenRatio = partners[2].ratio;
    notifyListeners();
    saveToDisk();
  }

  double get partnersRatioTotalPercent =>
      partners.fold<double>(0.0, (sum, p) => sum + p.ratio) * 100.0;

  bool get partnersRatiosValid =>
      partners.isNotEmpty && (partnersRatioTotalPercent - 100.0).abs() < 0.01;

  void lockOpeningEntry() {
    if (!partnersRatiosValid) {
      throw StateError('يجب أن يكون مجموع نسب الشركاء 100% قبل اعتماد القيد الافتتاحي.');
    }
    _applyOpeningStockToOperationalInventory();
    openingEntry.isLocked = true;
    openingEntry.lockedAt = DateTime.now();
    isOpeningEntryCompleted = true;
    mainCashBox = openingEntry.mainCashValue;
    scrapCashBox = openingEntry.scrapCashValue;
    orderCashBox = openingEntry.orderCashValue;
    mainCashBoxSyp = openingEntry.mainCashValueSyp;
    scrapCashBoxSyp = openingEntry.scrapCashValueSyp;
    orderCashBoxSyp = openingEntry.orderCashValueSyp;
    for (final partner in partners) {
      partner.injectedCapital = openingEntry.totalEquity * partner.ratio;
      partner.injectedCapitalSyp = openingEntry.totalEquitySyp * partner.ratio;
    }
    notifyListeners();
    saveToDisk();
  }

  void _applyOpeningStockToOperationalInventory() {
    if (openingEntry.openingStockApplied) return;
    for (final item in openingEntry.openingStock) {
      if (!const {
        'بلوكات خام المصنع',
        'أمتار المصنع',
        'أمتار المعمل',
        'تفصيل بسيط',
        'تفصيل معقد',
        'قطع زائدة وخردة',
      }.contains(item.category)) {
        throw StateError(
          'Unsupported opening stock category: ${item.category}.',
        );
      }
      if (item.category == 'بلوكات خام المصنع' &&
          _firstOrNull(
                blockTypes.where(
                  (candidate) =>
                      (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                      (candidate.typeName == item.typeName &&
                          (item.grade.isEmpty ||
                              candidate.grade == item.grade)),
                ),
              ) ==
              null) {
        throw StateError(
          'Register the factory block type before approving opening stock: ${item.typeName}.',
        );
      }
      if ((item.category == 'أمتار المصنع' ||
              item.category == 'أمتار المعمل') &&
          _firstOrNull(
                meterTypes.where(
                  (candidate) =>
                      (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                      candidate.typeName == item.typeName,
                ),
              ) ==
              null &&
          _firstOrNull(
                blockTypes.where(
                  (candidate) =>
                      (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                      candidate.typeName == item.typeName,
                ),
              ) ==
              null) {
        throw StateError(
          'Register the item type before approving opening stock: ${item.typeName}.',
        );
      }
      if ((item.category == 'تفصيل بسيط' || item.category == 'تفصيل معقد') &&
          _firstOrNull(
                (item.category == 'تفصيل بسيط'
                        ? simpleTailorings
                        : complexTailorings)
                    .where(
                      (candidate) =>
                          (item.typeId.isNotEmpty &&
                              candidate.id == item.typeId) ||
                          candidate.name == item.typeName,
                    ),
              ) ==
              null) {
        throw StateError(
          'Create the tailored item before approving opening stock: ${item.typeName}.',
        );
      }
    }
    for (final item in openingEntry.openingStock) {
      switch (item.category) {
        case 'بلوكات خام المصنع':
          final type = _firstOrNull(
            blockTypes.where(
              (candidate) =>
                  (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                  (candidate.typeName == item.typeName &&
                      (item.grade.isEmpty || candidate.grade == item.grade)),
            ),
          )!;
          final supplier = _firstOrNull(
            suppliers.where((candidate) => candidate.name == item.supplierName),
          );
          factoryBlocks.add(
            FactoryBlockModel(
              id: item.id,
              blockCode: 'OPEN-${item.id}',
              typeName: type.typeName,
              grade: type.grade,
              supplierId: supplier?.id ?? '',
              supplierName: item.supplierName.isNotEmpty
                  ? item.supplierName
                  : 'رصيد افتتاحي',
              weightTons: item.quantity,
              tonCost: item.unitPrice,
              tonSellingPrice: item.sellingPrice,
              isGranite: type.isGranite,
            ),
          );
          break;
        case 'أمتار المصنع':
        case 'أمتار المعمل':
          final meterType = _firstOrNull(
            meterTypes.where(
              (candidate) =>
                  (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                  candidate.typeName == item.typeName,
            ),
          );
          final blockType = meterType == null
              ? _firstOrNull(
                  blockTypes.where(
                    (candidate) =>
                        (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                        candidate.typeName == item.typeName,
                  ),
                )
              : null;
          final typeName = item.typeName.isNotEmpty
              ? item.typeName
              : (meterType?.typeName ?? blockType?.typeName ?? '');
          final grade = item.grade.isNotEmpty
              ? item.grade
              : (meterType?.grade ?? blockType?.grade ?? 'درجة أولى');
          final isGranite = item.isGranite || (meterType?.isGranite ?? blockType?.isGranite ?? false);
          final thickness = item.thicknessCm > 0
              ? item.thicknessCm
              : (meterType?.thicknessCm ?? 2.0);
          final category = thickness <= 5 ? 'متر مربع' : 'متر مكعب';
          final salePrice =
              item.sellingPrice > 0 ? item.sellingPrice : item.unitPrice;
          if (item.category == 'أمتار المصنع') {
            factoryWarehouse.add(
              FactoryWarehouseModel(
                id: item.id,
                typeName: typeName,
                grade: grade,
                thicknessCm: thickness,
                category: category,
                availableQty: item.quantity,
                netCostPerUnit: item.unitPrice,
                recommendedSalePrice: salePrice,
                isGranite: isGranite,
              ),
            );
          } else {
            workshopStock.add(
              WorkshopStockModel(
                id: item.id,
                typeName: typeName,
                grade: grade,
                thicknessCm: thickness,
                category: category,
                availableQty: item.quantity,
                netCostPerUnit: item.unitPrice,
                recommendedSalePrice: salePrice,
                isGranite: isGranite,
              ),
            );
          }
          break;
        case 'تفصيل بسيط':
        case 'تفصيل معقد':
          final tailoringItems = item.category == 'تفصيل بسيط'
              ? simpleTailorings
              : complexTailorings;
          final product = _firstOrNull(
            tailoringItems.where(
              (candidate) =>
                  (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                  candidate.name == item.typeName,
            ),
          )!;
          product.quantity += item.quantity;
          if (item.sellingPrice > 0) {
            product.sellingPrice = item.sellingPrice;
          }
          break;
        case 'قطع زائدة وخردة':
          scrapItems.add(
            ScrapItemModel(
              id: item.id,
              description: item.typeName,
              baseCost: item.totalPrice,
              sellingPrice:
                  item.sellingPrice > 0 ? item.sellingPrice : item.unitPrice,
              currency: item.currency,
            ),
          );
          break;
        default:
          throw StateError(
            'Unsupported opening stock category: ${item.category}.',
          );
      }
    }
    openingEntry.openingStockApplied = true;
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  // 2. Partner Management Actions
  double get totalCapitalUsd =>
      partners.fold<double>(0.0, (sum, p) => sum + p.injectedCapital);

  double get totalCapitalSyp =>
      partners.fold<double>(0.0, (sum, p) => sum + p.injectedCapitalSyp);

  double totalCapitalOf(String? currency) =>
      AppCurrency.isSyp(currency) ? totalCapitalSyp : totalCapitalUsd;

  /// Injects additional capital for a specific individual partner (حقن رأس مال لشريك منفرد).
  /// Dynamically updates total company capital, the contributing partner's equity value,
  /// recalculates ownership ratios (dilution for others), adds cash to destination safe,
  /// and logs the transaction.
  bool injectPartnerCapital({
    required String partnerId,
    required double amount,
    String currency = AppCurrency.usd,
    String destinationSafe = 'main',
    DateTime? date,
    String notes = '',
  }) {
    if (amount <= 0) return false;
    final c = AppCurrency.normalize(currency);
    final partnerIndex = partners.indexWhere((p) => p.id == partnerId);
    if (partnerIndex == -1) return false;
    final partner = partners[partnerIndex];

    final isSyp = AppCurrency.isSyp(c);
    double oldTotalCapital = partners.fold<double>(
      0.0,
      (sum, p) => sum + (isSyp ? p.injectedCapitalSyp : p.injectedCapital),
    );

    // If monetary shares have not been initialized, backfill from opening equity
    if (oldTotalCapital <= 0) {
      final equity =
          isSyp ? openingEntry.totalEquitySyp : openingEntry.totalEquity;
      if (equity > 0) {
        for (final p in partners) {
          if (isSyp) {
            p.injectedCapitalSyp = equity * p.ratio;
          } else {
            p.injectedCapital = equity * p.ratio;
          }
        }
        oldTotalCapital = equity;
      }
    }

    final double oldPartnerShare =
        isSyp ? partner.injectedCapitalSyp : partner.injectedCapital;
    final double oldRatio = partner.ratio;

    // 1. Calculate New Total Capital: C_new = C_old + A
    final double newTotalCapital = oldTotalCapital + amount;

    // 2. Update Contributing Partner's Monetary Share: V_k,new = V_k,old + A
    if (isSyp) {
      partner.injectedCapitalSyp += amount;
    } else {
      partner.injectedCapital += amount;
    }
    final double newPartnerShare =
        isSyp ? partner.injectedCapitalSyp : partner.injectedCapital;

    // 3. Recalculate all partners' ownership percentages (dilution for non-contributing partners)
    if (newTotalCapital > 0) {
      for (final p in partners) {
        final currentVal = isSyp ? p.injectedCapitalSyp : p.injectedCapital;
        p.ratio = currentVal / newTotalCapital;
      }
    }

    // Floating-point validation: ensure sum of ratios is exactly 1.0
    final double ratioSum =
        partners.fold<double>(0.0, (sum, p) => sum + p.ratio);
    if (ratioSum > 0 && (ratioSum - 1.0).abs() > 0.000001) {
      partner.ratio += (1.0 - ratioSum);
    }

    // Safely sync legacy openingEntry ratios without assuming exactly 3 partners
    if (partners.isNotEmpty) openingEntry.hassanRatio = partners[0].ratio;
    if (partners.length > 1) openingEntry.adnanRatio = partners[1].ratio;
    if (partners.length > 2) openingEntry.abdelMoeenRatio = partners[2].ratio;

    // 4. Financial & Accounting Routing:
    // Increase selected safe balance by +A under chosen currency
    addCash(destinationSafe, c, amount);

    // 5. Transaction Logging: Record entry
    final injectionRecord = CapitalInjectionRecordModel(
      id: 'cap_inj_${DateTime.now().millisecondsSinceEpoch}',
      partnerId: partner.id,
      partnerName: partner.name,
      amount: amount,
      currency: c,
      destinationSafe: destinationSafe,
      date: date ?? DateTime.now(),
      notes: notes,
      oldTotalCapital: oldTotalCapital,
      newTotalCapital: newTotalCapital,
      oldPartnerShare: oldPartnerShare,
      newPartnerShare: newPartnerShare,
      oldRatio: oldRatio,
      newRatio: partner.ratio,
    );
    capitalInjections.add(injectionRecord);

    notifyListeners();
    saveToDisk();
    return true;
  }

  void injectNewPartnerCapital(double newAmount, [String? currency]) {
    if (newAmount <= 0) return;
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    final isSyp = AppCurrency.isSyp(c);
    final totalOldCapital = partners.fold<double>(
      0,
      (sum, partner) =>
          sum + (isSyp ? partner.injectedCapitalSyp : partner.injectedCapital),
    );
    final totalNewCapital = totalOldCapital + newAmount;
    for (final partner in partners) {
      if (isSyp) {
        partner.injectedCapitalSyp += newAmount * partner.ratio;
      } else {
        partner.injectedCapital += newAmount * partner.ratio;
        partner.ratio = partner.injectedCapital / totalNewCapital;
      }
    }
    if (partners.isNotEmpty) openingEntry.hassanRatio = partners[0].ratio;
    if (partners.length > 1) openingEntry.adnanRatio = partners[1].ratio;
    if (partners.length > 2) openingEntry.abdelMoeenRatio = partners[2].ratio;

    addCash('main', c, newAmount);

    capitalInjections.add(
      CapitalInjectionRecordModel(
        id: 'cap_inj_all_${DateTime.now().millisecondsSinceEpoch}',
        partnerId: 'all',
        partnerName: 'جميع الشركاء (توزيع نسبي)',
        amount: newAmount,
        currency: c,
        destinationSafe: 'main',
        oldTotalCapital: totalOldCapital,
        newTotalCapital: totalNewCapital,
        notes: 'حقن رأس مال عام موزع حسب النسب السابقة',
      ),
    );

    notifyListeners();
    saveToDisk();
  }

  bool withdrawPartnerProfit(
    String partnerId,
    double amount,
    outWarning, [
    String? currency,
  ]) {
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    var p = partners.firstWhere((element) => element.id == partnerId);
    final net = netOperatingProfitOf(c);
    final partnerProfitShare = net * p.ratio;
    final alreadyWithdrawn = c == AppCurrency.syp
        ? p.totalWithdrawnSyp
        : p.totalWithdrawn;
    if (amount <= 0 ||
        amount > (partnerProfitShare - alreadyWithdrawn) ||
        cashOf('main', c) < amount) {
      outWarning.value = amount > (partnerProfitShare - alreadyWithdrawn)
          ? "تحذير الأمان: المبلغ المطلوب ($amount${AppCurrency.symbol(c)}) يتجاوز حصة الشريك من الأرباح الصافية (${partnerProfitShare.fmt}${AppCurrency.symbol(c)})!"
          : 'رصيد الصندوق الرئيسي لا يكفي للسحب.';
      return false;
    }

    if (c == AppCurrency.syp) {
      p.totalWithdrawnSyp += amount;
    } else {
      p.totalWithdrawn += amount;
    }
    takeCash('main', c, amount);
    notifyListeners();
    saveToDisk();
    return true;
  }

  // 3. Factory Block Purchase Invoice (multi-item, Due/Paid split)
  //
  // Shipping rule: when the shipment has NOT arrived, the shipping fee is
  // combined with the invoice capital cost and distributed over the stone
  // items proportionally to each item's capital cost.
  bool addSupplierPurchaseInvoice(FactoryInvoiceModel inv) {
    if (inv.advancePayment < 0 || inv.advancePayment > inv.grandTotal + 0.001) {
      return false;
    }
    if (inv.isCashInvoice &&
        (inv.invoiceType != 'شراء_مورد' ||
            inv.remainingBalance > 0.01 ||
            cashOf('main', inv.currency) + 0.0001 < inv.grandTotal)) {
      return false;
    }
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    factoryInvoices.add(inv);
    if (inv.advancePayment > 0) {
      takeCash('main', inv.currency, inv.advancePayment);
      recordBlockPurchaseExpense(
        amount: inv.advancePayment,
        currency: inv.currency,
        supplierName: inv.partyName,
        note:
            'دفعة شراء بلوكات - فاتورة رقم ${inv.invoiceNo} للمورد ${inv.partyName}',
        date: inv.date,
      );
    }
    // Update supplier debt if remaining (same currency as the invoice)
    if (inv.remainingBalance > 0.01 && suppliers.isNotEmpty) {
      var sup = suppliers.firstWhere(
        (s) => s.id == inv.partyId,
        orElse: () => suppliers.first,
      );
      sup.addDebt(inv.currency, inv.remainingBalance);
    }

    // Capital cost base per item (quantity tons * unitCost).
    final double itemsCapital = inv.items.fold(
      0.0,
      (s, it) => s + (it.quantity * it.unitCost),
    );

    // If the shipment has not arrived and shipping costs were entered,
    // record an informational expense entry under "Shipping and Transportation Costs"
    // (allocated to material capital costs, not charged to the supplier).
    if (!inv.isGoodsDelivered && inv.shippingFee > 0) {
      final matchingTypes = expenseTypes
          .where(
            (t) =>
                t.name.trim() == 'تكاليف الشحن والنقل' ||
                t.name.contains('Shipping and Transportation Costs') ||
                t.name.contains('الشحن والنقل'),
          )
          .toList();

      final String typeId;
      if (matchingTypes.isNotEmpty) {
        typeId = matchingTypes.first.id;
      } else {
        typeId = 'shipping_transport_costs';
        expenseTypes.add(
          ExpenseTypeModel(
            id: typeId,
            name: 'تكاليف الشحن والنقل (Shipping and Transportation Costs)',
            description: 'أجور وتكاليف شحن ونقل المواد والبضائع المشتراة',
          ),
        );
      }

      expenseRecords.add(
        ExpenseRecordModel(
          id: 'exp_ship_${DateTime.now().microsecondsSinceEpoch}',
          typeId: typeId,
          amount: inv.shippingFee,
          currency: inv.currency,
          personName: 'شحن مشتريات - ${inv.partyName}',
          description:
              'قيد إعلامي: تكاليف شحن ونقل موزعة على التكلفة الرأسمالية لمواد الفاتورة رقم ${inv.invoiceNo} (غير محملة على المورد)',
          date: inv.date,
          isInformational: true,
        ),
      );
    }

    // Add items to stock: meters affect Factory Warehouse Inventory, blocks affect Factory Block Inventory.
    for (var item in inv.items) {
      final double itemCapital = item.quantity * item.unitCost;
      double shippingShare = 0.0;
      if (!inv.isGoodsDelivered && inv.shippingFee > 0 && item.quantity > 0) {
        if (itemsCapital > 0) {
          shippingShare = (itemCapital / itemsCapital) * inv.shippingFee;
        } else {
          shippingShare = inv.shippingFee / inv.items.length;
        }
      }
      final double effectiveUnitCost =
          item.unitCost +
          (item.quantity > 0 ? shippingShare / item.quantity : 0.0);

      if (item.isMeterItem) {
        final category = item.meterUnit.isNotEmpty
            ? item.meterUnit
            : (item.thicknessCm > 5 ? 'متر مكعب' : 'متر مربع');
        final targetTypeName =
            item.typeName.isNotEmpty ? item.typeName : item.description;
        final targetGrade = item.grade.isNotEmpty ? item.grade : 'درجة أولى';
        final targetThickness = item.thicknessCm > 0 ? item.thicknessCm : 2.0;

        final existingMatches = factoryWarehouse
            .where(
              (w) =>
                  w.typeName == targetTypeName &&
                  w.grade == targetGrade &&
                  (w.thicknessCm - targetThickness).abs() < 0.01 &&
                  w.category == category,
            )
            .toList();

        if (existingMatches.isNotEmpty) {
          final w = existingMatches.first;
          final double mergedQty = w.availableQty + item.quantity;
          final double mergedCost = mergedQty > 0
              ? ((w.availableQty * w.netCostPerUnit) +
                    (item.quantity * effectiveUnitCost)) /
                mergedQty
              : effectiveUnitCost;
          w.availableQty = mergedQty;
          w.netCostPerUnit = mergedCost;
        } else {
          factoryWarehouse.add(
            FactoryWarehouseModel(
              id:
                  'fw_${DateTime.now().millisecondsSinceEpoch}_${factoryWarehouse.length}',
              typeName: targetTypeName,
              grade: targetGrade,
              thicknessCm: targetThickness,
              category: category,
              availableQty: item.quantity,
              netCostPerUnit: effectiveUnitCost,
              recommendedSalePrice: effectiveUnitCost * 1.25,
              isGranite: item.isGranite,
            ),
          );
        }
      } else {
        factoryBlocks.add(
          FactoryBlockModel(
            id:
                'fb_${DateTime.now().millisecondsSinceEpoch}_${factoryBlocks.length}',
            blockCode: 'BLK-${factoryBlocks.length + 101}',
            typeName:
                item.typeName.isNotEmpty ? item.typeName : item.description,
            grade: item.grade.isNotEmpty ? item.grade : 'درجة أولى',
            supplierId: inv.partyId,
            supplierName: inv.partyName,
            weightTons: item.quantity,
            tonCost: effectiveUnitCost,
            isGranite: item.isGranite,
          ),
        );
      }
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  // Staged cutting batch coming from the Factory Inventory aggregation step.
  List<CuttingBatchInput> pendingCuttingBatch = [];

  void setPendingCuttingBatch(List<CuttingBatchInput> batch) {
    pendingCuttingBatch = batch;
    notifyListeners();
  }

  void clearPendingCuttingBatch() {
    pendingCuttingBatch = [];
    notifyListeners();
  }

  /// Executes the staged multi-type cutting plan:
  /// deducts the input tons from factory blocks (FIFO per type+grade),
  /// merges every conversion output into the factory warehouse, and logs
  /// one cutting operation per type+grade stamped with the transfer time.
  void executeStagedCutting({
    required List<StagedCutConversion> conversions,
    required double wasteValue,
  }) {
    if (conversions.isEmpty) return;
    final now = DateTime.now();

    // Group conversions per type+grade to deduct input tons once.
    final Map<String, List<StagedCutConversion>> byType = {};
    for (final c in conversions) {
      byType.putIfAbsent('${c.typeName}||${c.grade}', () => []).add(c);
    }

    byType.forEach((key, list) {
      final first = list.first;
      double tonsToDeduct = list.fold(0.0, (s, c) => s + c.inputTons);
      // FIFO deduction from matching raw blocks.
      final matching = factoryBlocks
          .where((b) => b.typeName == first.typeName && b.grade == first.grade)
          .toList();
      for (final b in matching) {
        if (tonsToDeduct <= 0) break;
        final take = tonsToDeduct >= b.weightTons ? b.weightTons : tonsToDeduct;
        b.weightTons -= take;
        tonsToDeduct -= take;
      }
      factoryBlocks.removeWhere(
        (b) =>
            b.typeName == first.typeName &&
            b.grade == first.grade &&
            b.weightTons <= 0.001,
      );

      final double totalInputCost = list.fold(
        0.0,
        (s, c) => s + (c.inputTons * c.avgTonCost),
      );
      final double totalCostWithFee = list.fold(
        0.0,
        (s, c) => s + (c.inputTons * c.avgTonCost * (1.0 + c.feePercent)),
      );
      final double totalOutput = list.fold(0.0, (s, c) => s + c.outputQty);

      // Merge every conversion output into the warehouse.
      for (final c in list) {
        if (c.outputQty <= 0) continue;
        final existing = factoryWarehouse
            .where(
              (w) =>
                  w.typeName == c.typeName &&
                  w.grade == c.grade &&
                  w.thicknessCm == c.thicknessCm,
            )
            .toList();
        if (existing.isEmpty) {
          factoryWarehouse.add(
            FactoryWarehouseModel(
              id: 'fw_${now.millisecondsSinceEpoch}_${factoryWarehouse.length}',
              typeName: c.typeName,
              grade: c.grade,
              thicknessCm: c.thicknessCm,
              category: c.category,
              availableQty: c.outputQty,
              netCostPerUnit: c.netCost,
              recommendedSalePrice: c.salePrice,
              isGranite: c.isGranite,
            ),
          );
        } else {
          final w = existing.first;
          final double mergedQty = w.availableQty + c.outputQty;
          final double mergedCost = mergedQty > 0
              ? ((w.availableQty * w.netCostPerUnit) +
                        (c.outputQty * c.netCost)) /
                    mergedQty
              : c.netCost;
          w.availableQty = mergedQty;
          w.netCostPerUnit = mergedCost;
          if (c.salePrice > 0) w.recommendedSalePrice = c.salePrice;
        }
      }

      final double inputTons = list.fold(0.0, (s, c) => s + c.inputTons);
      final double batchCuttingFee = list.fold(
        0.0,
        (s, c) => s + (c.inputTons * c.avgTonCost * c.feePercent),
      );
      if (batchCuttingFee > 0) {
        recordCuttingExpense(
          amount: batchCuttingFee,
          currency: AppCurrency.usd,
          typeName: first.typeName,
          grade: first.grade,
          feePercent: list.first.feePercent,
          date: now,
        );
      }
      cuttingOperations.add(
        CuttingOperationModel(
          id: 'cut_${now.millisecondsSinceEpoch}_${cuttingOperations.length}',
          timestamp: now,
          inputTons: inputTons,
          baseTonCost: inputTons > 0 ? totalInputCost / inputTons : 0.0,
          cuttingFeePercentage: list.first.feePercent,
          targetTypeName: first.typeName,
          targetGrade: first.grade,
          thicknessCm: list.first.thicknessCm,
          category: list.first.category,
          totalOutputArea: totalOutput,
          netCostPerUnit: totalOutput > 0
              ? totalCostWithFee / totalOutput
              : 0.0,
          recommendedSalePrice: list.first.salePrice,
          wasteValue: wasteValue,
          isGranite: first.isGranite,
        ),
      );
    });

    pendingCuttingBatch = [];
    notifyListeners();
    saveToDisk();
  }

  // 4. Cutting Operation & Warehouse Conversion
  void executeCuttingOperation({
    required List<FactoryBlockModel> selectedBlocks,
    required double cuttingFeePercent, // 0.07, 0.08, 0.09
    required String targetTypeName,
    required String targetGrade,
    required double thicknessCm,
    required String category, // 'متر مربع' or 'متر مكعب'
    required double totalOutputArea,
    required double wasteValue,
    required double recommendedSalePrice,
    required bool isGranite,
  }) {
    if (selectedBlocks.isEmpty || totalOutputArea <= 0) return;

    double totalTons = selectedBlocks.fold(0.0, (s, b) => s + b.weightTons);
    double totalTonCostSum = selectedBlocks.fold(
      0.0,
      (s, b) => s + b.totalCost,
    );

    double weightedAvgTonCost = totalTonCostSum / totalTons;
    double netCostPerUnit =
        (totalTonCostSum * (1.0 + cuttingFeePercent)) / totalOutputArea;

    // Remove selected blocks from raw stock
    for (var b in selectedBlocks) {
      factoryBlocks.removeWhere((item) => item.id == b.id);
    }

    // Add to Factory Warehouse
    var existingWh = factoryWarehouse.firstWhere(
      (w) =>
          w.typeName == targetTypeName &&
          w.grade == targetGrade &&
          w.thicknessCm == thicknessCm,
      orElse: () {
        var newWh = FactoryWarehouseModel(
          id: 'fw_${DateTime.now().millisecondsSinceEpoch}',
          typeName: targetTypeName,
          grade: targetGrade,
          thicknessCm: thicknessCm,
          category: category,
          availableQty: 0.0,
          netCostPerUnit: netCostPerUnit,
          recommendedSalePrice: recommendedSalePrice,
          isGranite: isGranite,
        );
        factoryWarehouse.add(newWh);
        return newWh;
      },
    );

    existingWh.availableQty += totalOutputArea;
    existingWh.netCostPerUnit = netCostPerUnit;

    final double cuttingFeeAmount = totalTonCostSum * cuttingFeePercent;
    if (cuttingFeeAmount > 0) {
      recordCuttingExpense(
        amount: cuttingFeeAmount,
        currency: AppCurrency.usd,
        typeName: targetTypeName,
        grade: targetGrade,
        feePercent: cuttingFeePercent,
        date: DateTime.now(),
      );
    }

    // Log cutting operation
    cuttingOperations.add(
      CuttingOperationModel(
        id: 'cut_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        inputTons: totalTons,
        baseTonCost: weightedAvgTonCost,
        cuttingFeePercentage: cuttingFeePercent,
        targetTypeName: targetTypeName,
        targetGrade: targetGrade,
        thicknessCm: thicknessCm,
        category: category,
        totalOutputArea: totalOutputArea,
        netCostPerUnit: netCostPerUnit,
        recommendedSalePrice: recommendedSalePrice,
        wasteValue: wasteValue,
        isGranite: isGranite,
      ),
    );

    notifyListeners();
    saveToDisk();
  }

  // 5. Transfer Stock to Workshop Stock
  void transferFactoryToWorkshop(FactoryWarehouseModel whItem, double qty) {
    if (whItem.availableQty < qty) return;
    whItem.availableQty -= qty;

    var existingWs = workshopStock.firstWhere(
      (ws) =>
          ws.typeName == whItem.typeName &&
          ws.grade == whItem.grade &&
          ws.thicknessCm == whItem.thicknessCm,
      orElse: () {
        var newWs = WorkshopStockModel(
          id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
          typeName: whItem.typeName,
          grade: whItem.grade,
          thicknessCm: whItem.thicknessCm,
          category: whItem.category,
          availableQty: 0.0,
          netCostPerUnit: whItem.netCostPerUnit,
          recommendedSalePrice: whItem.recommendedSalePrice,
          isGranite: whItem.isGranite,
        );
        workshopStock.add(newWs);
        return newWs;
      },
    );
    existingWs.availableQty += qty;
    notifyListeners();
    saveToDisk();
  }

  // Transfer Stock back from Workshop to Factory
  bool transferWorkshopToFactory(WorkshopStockModel wsItem, double qty) {
    if (qty <= 0 || wsItem.availableQty + 0.0001 < qty) return false;
    wsItem.availableQty =
        (wsItem.availableQty - qty).clamp(0.0, double.infinity);

    var existingWh = factoryWarehouse.firstWhere(
      (wh) =>
          wh.typeName == wsItem.typeName &&
          wh.grade == wsItem.grade &&
          wh.thicknessCm == wsItem.thicknessCm,
      orElse: () {
        var newWh = FactoryWarehouseModel(
          id: 'wh_${DateTime.now().millisecondsSinceEpoch}',
          typeName: wsItem.typeName,
          grade: wsItem.grade,
          thicknessCm: wsItem.thicknessCm,
          category: wsItem.category,
          availableQty: 0.0,
          netCostPerUnit: wsItem.netCostPerUnit,
          recommendedSalePrice: wsItem.recommendedSalePrice,
          isGranite: wsItem.isGranite,
        );
        factoryWarehouse.add(newWh);
        return newWh;
      },
    );
    existingWh.availableQty += qty;
    notifyListeners();
    saveToDisk();
    return true;
  }

  // Update recommended selling price for factory warehouse item
  void updateFactoryWarehouseSalePrice(String whId, double newPrice) {
    final idx = factoryWarehouse.indexWhere((w) => w.id == whId);
    if (idx != -1 && newPrice >= 0) {
      factoryWarehouse[idx].recommendedSalePrice = newPrice;
      notifyListeners();
      saveToDisk();
    }
  }

  // Update center/sawmill official info
  void updateCenterInfo(CenterInfoModel newInfo) {
    centerInfo = newInfo;
    notifyListeners();
    saveToDisk();
  }

  // 6. POS Factory Invoice Sale (multi-item, Pending/Paid split)
  bool addFactoryPOSInvoice(FactoryInvoiceModel inv) {
    if (inv.advancePayment < 0 || inv.advancePayment > inv.grandTotal + 0.001) {
      return false;
    }
    if (inv.isCashInvoice &&
        (inv.invoiceType != 'بيع_معتمد' || inv.remainingBalance > 0.01)) {
      return false;
    }
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    factoryInvoices.add(inv);
    if (inv.advancePayment > 0) {
      addCash('main', inv.currency, inv.advancePayment);
    }

    if (clients.isNotEmpty) {
      final clientMatches = clients.where(
        (c) => c.id == inv.partyId || c.name.trim() == inv.partyName.trim(),
      ).toList();
      final client = clientMatches.isNotEmpty ? clientMatches.first : clients.first;
      client.currencyClassification = inv.currency;
      if (inv.remainingBalance > 0) {
        client.addDebt(inv.currency, inv.remainingBalance);
      }
    }

    // Deduct stock from Factory Warehouse or Tailoring
    for (var item in inv.items) {
      if (item.itemCategory == 'tailoring' || item.itemId.startsWith('tailoring_')) {
        final allTailorings = [...simpleTailorings, ...complexTailorings];
        WorkshopTailoringModel? tailoring;
        TailoringLineItem? lineItem;
        for (final t in allTailorings) {
          for (final li in t.lineItems) {
            if (item.itemId == 'tailoring_${t.id}_${li.id}' || item.itemId == li.id) {
              tailoring = t;
              lineItem = li;
              break;
            }
          }
          if (tailoring != null) break;
          if (item.itemId == t.id) {
            tailoring = t;
            break;
          }
        }
        if (tailoring != null) {
          tailoring.quantity = (tailoring.quantity - item.calculatedArea).clamp(
            0.0,
            double.infinity,
          );
          if (lineItem != null) {
            lineItem.quantity = (lineItem.quantity - item.quantity).clamp(
              0.0,
              double.infinity,
            );
          }
        }
      } else if (factoryWarehouse.isNotEmpty) {
        FactoryWarehouseModel? wh;
        for (final warehouseItem in factoryWarehouse) {
          if (warehouseItem.id == item.itemId) {
            wh = warehouseItem;
            break;
          }
        }
        wh ??= factoryWarehouse.firstWhere(
          (warehouseItem) => warehouseItem.typeName == item.description,
          orElse: () => factoryWarehouse.first,
        );
        wh.availableQty = (wh.availableQty - item.calculatedArea).clamp(
          0.0,
          double.infinity,
        );
      }
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  // 7. Workshop Order & Isolated Order Cash Box
  // The order carries its currency (SYP/$); the invoice created from it
  // inherits that currency directly.
  void _deductWorkshopOrderItemStock(WorkshopInvoiceItem item) {
    if (item.sourceType == 'بيع خياطة بسيطة' || item.sourceType == 'تفصيل بسيط') {
      final matches = simpleTailorings.where((t) => t.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        final t = matches.first;
        t.quantity = (t.quantity - item.quantity).clamp(0.0, double.infinity);
        if (item.sourceLineItemId.isNotEmpty) {
          final liMatches = t.lineItems.where((li) => li.id == item.sourceLineItemId).toList();
          if (liMatches.isNotEmpty) {
            final li = liMatches.first;
            final pieceArea = (li.lengthCm > 0 && li.widthCm > 0)
                ? (li.lengthCm / 100.0) * (li.widthCm / 100.0) * (li.category == 'متر مكعب' && li.heightCm > 0 ? li.heightCm / 100.0 : 1.0)
                : 0.0;
            if (pieceArea > 0) {
              li.quantity = (li.quantity - (item.quantity / pieceArea)).clamp(0.0, double.infinity);
            } else {
              li.quantity = (li.quantity - item.quantity).clamp(0.0, double.infinity);
            }
          }
        }
      }
    } else if (item.sourceType == 'بيع خياطة معقدة' || item.sourceType == 'تفصيل معقد') {
      final matches = complexTailorings.where((t) => t.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        matches.first.quantity = (matches.first.quantity - item.quantity).clamp(0.0, double.infinity);
      }
    } else if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
      if (item.sourceId.isNotEmpty) {
        final matches = workshopStock.where((w) => w.id == item.sourceId).toList();
        if (matches.isNotEmpty) {
          matches.first.availableQty = (matches.first.availableQty - item.quantity).clamp(0.0, double.infinity);
        }
      }
    } else if (item.sourceType == 'بيع قطع إضافية' || item.sourceType == 'قطع زائدة') {
      if (item.sourceId.isNotEmpty) {
        final matches = scrapItems.where((s) => s.id == item.sourceId).toList();
        if (matches.isNotEmpty) matches.first.isSold = true;
      }
    }
  }

  void _restoreWorkshopOrderItemStock(WorkshopInvoiceItem item) {
    if (item.sourceType == 'بيع خياطة بسيطة' || item.sourceType == 'تفصيل بسيط') {
      final matches = simpleTailorings.where((t) => t.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        final t = matches.first;
        t.quantity += item.quantity;
        if (item.sourceLineItemId.isNotEmpty) {
          final liMatches = t.lineItems.where((li) => li.id == item.sourceLineItemId).toList();
          if (liMatches.isNotEmpty) {
            final li = liMatches.first;
            final pieceArea = (li.lengthCm > 0 && li.widthCm > 0)
                ? (li.lengthCm / 100.0) * (li.widthCm / 100.0) * (li.category == 'متر مكعب' && li.heightCm > 0 ? li.heightCm / 100.0 : 1.0)
                : 0.0;
            if (pieceArea > 0) {
              li.quantity += (item.quantity / pieceArea);
            } else {
              li.quantity += item.quantity;
            }
          }
        }
      } else {
        simpleTailorings.add(
          WorkshopTailoringModel(
            id: item.sourceId.isNotEmpty ? item.sourceId : 'st_${DateTime.now().microsecondsSinceEpoch}',
            name: item.description,
            complexity: 'بسيط',
            rawMaterialDescription: item.description,
            quantity: item.quantity,
            materialNetCost: item.netCost,
            unitCategory: item.unitCategory,
            sellingPrice: item.agreedPrice,
            isGranite: item.isGranite,
            photoPath: item.photoPath,
          ),
        );
      }
    } else if (item.sourceType == 'بيع خياطة معقدة' || item.sourceType == 'تفصيل معقد') {
      final matches = complexTailorings.where((t) => t.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        matches.first.quantity += item.quantity;
      } else {
        complexTailorings.add(
          WorkshopTailoringModel(
            id: item.sourceId.isNotEmpty ? item.sourceId : 'ct_${DateTime.now().microsecondsSinceEpoch}',
            name: item.description,
            complexity: 'معقد',
            rawMaterialDescription: item.description,
            quantity: item.quantity,
            materialNetCost: item.netCost,
            unitCategory: item.unitCategory,
            sellingPrice: item.agreedPrice,
            isGranite: item.isGranite,
            photoPath: item.photoPath,
          ),
        );
      }
    } else if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
      final matches = workshopStock.where((w) => w.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        matches.first.availableQty += item.quantity;
      } else {
        final byName = workshopStock.where((w) => item.description.contains(w.typeName)).toList();
        if (byName.isNotEmpty) {
          byName.first.availableQty += item.quantity;
        } else if (workshopStock.isNotEmpty) {
          workshopStock.first.availableQty += item.quantity;
        }
      }
    } else if (item.sourceType == 'بيع قطع إضافية' || item.sourceType == 'قطع زائدة') {
      final matches = scrapItems.where((s) => s.id == item.sourceId).toList();
      if (matches.isNotEmpty) {
        matches.first.isSold = false;
      } else {
        scrapItems.add(
          ScrapItemModel(
            id: item.sourceId.isNotEmpty ? item.sourceId : 'sc_${DateTime.now().microsecondsSinceEpoch}',
            description: item.description,
            baseCost: item.netCost,
            sellingPrice: item.agreedPrice,
            isSold: false,
            photoPath: item.photoPath,
          ),
        );
      }
    }
  }

  void createWorkshopOrder(WorkshopOrderModel order) {
    workshopOrders.add(order);
    if (order.depositAmount > 0) {
      // CRITICAL ACCOUNTING RULE: Down payment stored in isolated Order Cash Box
      addCash('order', order.currency, order.depositAmount);
    }
    // Deduct stock for all order line items consumed
    for (final it in order.items) {
      _deductWorkshopOrderItemStock(it);
    }
    notifyListeners();
    saveToDisk();
  }

  bool assignOrderToInvoice(WorkshopOrderModel order, double cashPaidNow) {
    if (cashPaidNow < 0 ||
        (order.depositAmount + cashPaidNow) > order.agreedPrice + 0.001) {
      return false;
    }
    order.status = 'مكتملة ومرحلة';
    order.isCompleted = true;

    // Transfer deposit from isolated Order Cash Box to Main Cash Box (same currency)
    if (order.depositAmount > 0) {
      if (takeCash('order', order.currency, order.depositAmount)) {
        addCash('main', order.currency, order.depositAmount);
      }
    }
    addCash('main', order.currency, cashPaidNow);

    workshopInvoices.add(
      WorkshopInvoiceModel(
        id: 'wi_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNo: 'WRK-INV-${workshopInvoices.length + 101}',
        date: DateTime.now(),
        clientName: order.clientName,
        sourceType: 'طلبية معمل',
        itemDescription: order.customDimensionsText,
        sourceQuantity: 1,
        agreedPrice: order.agreedPrice,
        depositDeducted: order.depositAmount,
        cashPaidNow: cashPaidNow,
        netCost: order.agreedPrice * 0.60,
        currency: order.currency,
      ),
    );

    final remaining = (order.agreedPrice - order.depositAmount - cashPaidNow).clamp(0.0, double.infinity);
    if (order.clientName.trim().isNotEmpty) {
      final existingClient = clients
          .where((c) =>
              c.name.trim() == order.clientName.trim() &&
              c.clientType == 'زبون معمل')
          .firstOrNull;
      final ClientModel client;
      if (existingClient == null) {
        client = ClientModel(
          id: 'cli_wrk_${DateTime.now().millisecondsSinceEpoch}',
          name: order.clientName.trim(),
          phone: '',
          location: '',
          clientType: 'زبون معمل',
          debtBalance: 0.0,
          debtBalanceSyp: 0.0,
          currencyClassification: order.currency,
        );
        clients.add(client);
      } else {
        client = existingClient;
        client.currencyClassification = order.currency;
      }
      if (remaining > 0.01) {
        client.addDebt(order.currency, remaining);
      }
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Comprehensive Workshop Order Cancellation Workflow:
  /// Option A (isCompleted == false):
  ///   - Refund deposit from isolated Order Safe to customer.
  ///   - Return all consumed materials/line items back to exact original locations (including raw stock).
  /// Option B (isCompleted == true):
  ///   - Retain deposit in isolated Order Safe as profit (no refund).
  ///   - Return standard line items (simple/complex tailoring, extras) back to their respective inventories.
  ///   - Convert raw material line items into tailored stock (simple or complex tailoring) based on user assignments.
  void cancelWorkshopOrderWorkflow({
    required WorkshopOrderModel order,
    required bool isCompleted,
    List<RawMaterialTailoringAssignment>? rawMaterialAssignments,
  }) {
    order.isCompleted = isCompleted;
    order.status = isCompleted ? 'ملغاة (مكتملة)' : 'ملغاة (غير مكتملة)';
    order.isSpecialRefund = !isCompleted;

    if (!isCompleted) {
      // -------------------------------------------------------------
      // OPTION A: ORDER IS NOT COMPLETED
      // -------------------------------------------------------------
      // 1. Financial handling: Refund the Deposit (العربون) to the customer from Order Safe
      if (order.depositAmount > 0) {
        takeCash('order', order.currency, order.depositAmount);
      }

      // 2. Inventory rollback: Return all consumed materials back to exact original locations
      for (final item in order.items) {
        _restoreWorkshopOrderItemStock(item);
      }
    } else {
      // -------------------------------------------------------------
      // OPTION B: ORDER IS COMPLETED
      // -------------------------------------------------------------
      // 1. Financial handling: Do NOT refund deposit. Retained in Order Safe as profit.

      // 2. Inventory rollback:
      if (order.items.isEmpty) {
        // Fallback for orders created without explicit line items
        convertCancelledOrderToTailoring(order);
      } else {
        for (final item in order.items) {
          final isRaw = item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام';
          if (!isRaw) {
            // Standard line items (Simple Tailoring, Complex Tailoring, Extras)
            _restoreWorkshopOrderItemStock(item);
          } else {
            // Raw Material line items: Must convert to tailored stock instead of returning as raw material
            final assign = rawMaterialAssignments?.where(
              (a) =>
                  a.itemId == item.id ||
                  a.itemId == item.sourceId ||
                  (a.rawMaterialName == item.description && a.quantity == item.quantity),
            ).firstOrNull;

            final toSimple = assign?.isSimpleTailoring ?? true;
            final existingId = assign?.existingTailoringId;
            final newName = assign?.newTailoringName?.trim();

            if (toSimple) {
              WorkshopTailoringModel? target;
              if (existingId != null && existingId.isNotEmpty) {
                target = simpleTailorings.where((t) => t.id == existingId).firstOrNull;
              }
              if (target != null) {
                target.quantity += item.quantity;
              } else {
                final createdName = (newName != null && newName.isNotEmpty)
                    ? newName
                    : 'تفصيل من طلبية ملغاة ${order.orderNo} (${item.description})';
                simpleTailorings.add(
                  WorkshopTailoringModel(
                    id: 'st_c_${DateTime.now().microsecondsSinceEpoch}',
                    name: createdName,
                    complexity: 'بسيط',
                    rawMaterialDescription: item.description,
                    lengthCm: item.lengthCm,
                    widthCm: item.widthCm,
                    heightCm: item.heightCm,
                    unitCategory: item.unitCategory.isNotEmpty ? item.unitCategory : 'متر مربع',
                    quantity: item.quantity,
                    materialNetCost: item.netCost,
                    laborCostPerMeter: 0.0,
                    photoPath: item.photoPath.isNotEmpty ? item.photoPath : order.photoPath,
                    sellingPrice: (assign != null && assign.sellingPrice > 0)
                        ? assign.sellingPrice
                        : (item.agreedPrice > 0 ? item.agreedPrice : item.unitPrice),
                    isGranite: item.isGranite,
                  ),
                );
              }
            } else {
              // Assign to Complex Tailoring
              WorkshopTailoringModel? target;
              if (existingId != null && existingId.isNotEmpty) {
                target = complexTailorings.where((t) => t.id == existingId).firstOrNull;
              }
              if (target != null) {
                target.quantity += item.quantity;
              } else {
                final createdName = (newName != null && newName.isNotEmpty)
                    ? newName
                    : 'تفصيل معقد من طلبية ملغاة ${order.orderNo} (${item.description})';
                complexTailorings.add(
                  WorkshopTailoringModel(
                    id: 'ct_c_${DateTime.now().microsecondsSinceEpoch}',
                    name: createdName,
                    complexity: 'معقد',
                    rawMaterialDescription: item.description,
                    lengthCm: item.lengthCm,
                    widthCm: item.widthCm,
                    heightCm: item.heightCm,
                    unitCategory: item.unitCategory.isNotEmpty ? item.unitCategory : 'متر مربع',
                    quantity: item.quantity,
                    materialNetCost: item.netCost,
                    laborCostPerMeter: 0.0,
                    photoPath: item.photoPath.isNotEmpty ? item.photoPath : order.photoPath,
                    sellingPrice: (assign != null && assign.sellingPrice > 0)
                        ? assign.sellingPrice
                        : (item.agreedPrice > 0 ? item.agreedPrice : item.unitPrice),
                    isGranite: item.isGranite,
                  ),
                );
              }
            }
          }
        }
      }
    }

    notifyListeners();
    saveToDisk();
  }

  void cancelWorkshopOrder(WorkshopOrderModel order, bool isSpecialRefund) {
    cancelWorkshopOrderWorkflow(
      order: order,
      isCompleted: !isSpecialRefund,
    );
    order.status = 'ملغاة';
  }

  /// Converts a cancelled order's ready work into a tailored piece and keeps
  /// the deposit as profit (unless it was specially refunded).
  void convertCancelledOrderToTailoring(WorkshopOrderModel order) {
    if (order.status != 'ملغاة' || order.isSpecialRefund) return;
    simpleTailorings.add(
      WorkshopTailoringModel(
        id: 'st_${DateTime.now().millisecondsSinceEpoch}',
        name: 'قطعة جاهزة من طلبية ملغاة ${order.orderNo}',
        complexity: 'جاهزة',
        rawMaterialDescription: order.customDimensionsText,
        quantity: 1,
        materialNetCost: order.agreedPrice * 0.60,
        unitCategory: 'متر مربع',
        laborCostPerMeter: 0.0,
        photoPath: order.photoPath,
        sellingPrice: order.agreedPrice,
      ),
    );
    notifyListeners();
    saveToDisk();
  }

  /// Creates a workshop invoice from any source with correct cash routing:
  /// scrap sales go to the Scrap Cash Box, everything else to Main Cash Box.
  /// When assigned from an order, the isolated deposit moves to Main Cash Box.
  /// Supports multiple line items and multiple sources per invoice.
  bool createWorkshopInvoice(
    WorkshopInvoiceModel inv, {
    String deductStockId = '',
    double deductQty = 0.0,
  }) {
    if (inv.depositDeducted < 0 ||
        inv.cashPaidNow < 0 ||
        (inv.depositDeducted + inv.cashPaidNow) > inv.grandTotal + 0.001) {
      return false;
    }
    if (inv.isCashInvoice && inv.remainingBalance > 0.01) return false;

    // Multi-item path
    if (inv.items.isNotEmpty) {
      final linkedOrders = inv.sourceId.isNotEmpty
          ? workshopOrders.where((o) => o.id == inv.sourceId && o.status == 'قيد التنفيذ').toList()
          : <WorkshopOrderModel>[];
      if (linkedOrders.isNotEmpty) {
        for (final it in linkedOrders.first.items) {
          _restoreWorkshopOrderItemStock(it);
        }
      }

      // 1. Validation phase
      for (final item in inv.items) {
        if (item.sourceType == 'بيع خياطة بسيطة' ||
            item.sourceType == 'تفصيل بسيط' ||
            item.sourceType == 'بيع خياطة معقدة' ||
            item.sourceType == 'تفصيل معقد') {
          final isSimple = item.sourceType == 'بيع خياطة بسيطة' || item.sourceType == 'تفصيل بسيط';
          final category = isSimple ? 'تفصيل بسيط' : 'تفصيل معقد';
          final isOpeningStockItem = openingEntry.openingStock.any(
            (o) => o.category == category && o.typeId == item.sourceId,
          );
          if (isOpeningStockItem &&
              (!openingEntry.isLocked || !openingEntry.openingStockApplied)) {
            if (linkedOrders.isNotEmpty) {
              for (final it in linkedOrders.first.items) {
                _deductWorkshopOrderItemStock(it);
              }
            }
            return false;
          }
          final items = isSimple ? simpleTailorings : complexTailorings;
          final matches = items.where((t) => t.id == item.sourceId).toList();
          if (matches.isEmpty || item.quantity <= 0 || matches.first.quantity + 0.0001 < item.quantity) {
            if (linkedOrders.isNotEmpty) {
              for (final it in linkedOrders.first.items) {
                _deductWorkshopOrderItemStock(it);
              }
            }
            return false;
          }
        } else if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
          if (item.sourceId.isNotEmpty) {
            final stock = workshopStock.where((w) => w.id == item.sourceId).toList();
            if (stock.isEmpty || stock.first.availableQty + 0.0001 < item.quantity) {
              if (linkedOrders.isNotEmpty) {
                for (final it in linkedOrders.first.items) {
                  _deductWorkshopOrderItemStock(it);
                }
              }
              return false;
            }
          }
        } else if (item.sourceType == 'طلب معمل' || item.sourceType == 'طلبية معمل') {
          if (item.depositAmount > 0 && item.sourceId.isNotEmpty) {
            final orders = workshopOrders.where((o) => o.id == item.sourceId).toList();
            if (orders.isNotEmpty && cashOf('order', inv.currency) + 0.0001 < item.depositAmount) {
              if (linkedOrders.isNotEmpty) {
                for (final it in linkedOrders.first.items) {
                  _deductWorkshopOrderItemStock(it);
                }
              }
              return false;
            }
          }
        }
      }

      // 2. Perform deductions and status updates
      double totalScrapValue = 0.0;
      for (final item in inv.items) {
        if (item.sourceType == 'بيع خياطة بسيطة' || item.sourceType == 'تفصيل بسيط') {
          final matches = simpleTailorings.where((t) => t.id == item.sourceId).toList();
          if (matches.isNotEmpty) {
            final t = matches.first;
            t.quantity = (t.quantity - item.quantity).clamp(0.0, double.infinity);
            if (item.sourceLineItemId.isNotEmpty) {
              final liMatches = t.lineItems.where((li) => li.id == item.sourceLineItemId).toList();
              if (liMatches.isNotEmpty) {
                final li = liMatches.first;
                final pieceArea = (li.lengthCm > 0 && li.widthCm > 0)
                    ? (li.lengthCm / 100.0) * (li.widthCm / 100.0) * (li.category == 'متر مكعب' && li.heightCm > 0 ? li.heightCm / 100.0 : 1.0)
                    : 0.0;
                if (pieceArea > 0) {
                  li.quantity = (li.quantity - (item.quantity / pieceArea)).clamp(0.0, double.infinity);
                } else {
                  li.quantity = (li.quantity - item.quantity).clamp(0.0, double.infinity);
                }
              }
            }
          }
        } else if (item.sourceType == 'بيع خياطة معقدة' || item.sourceType == 'تفصيل معقد') {
          final matches = complexTailorings.where((t) => t.id == item.sourceId).toList();
          if (matches.isNotEmpty) {
            matches.first.quantity = (matches.first.quantity - item.quantity).clamp(0.0, double.infinity);
          }
        } else if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
          if (item.sourceId.isNotEmpty) {
            final matches = workshopStock.where((w) => w.id == item.sourceId).toList();
            if (matches.isNotEmpty) {
              matches.first.availableQty = (matches.first.availableQty - item.quantity).clamp(0.0, double.infinity);
            }
          }
        } else if (item.sourceType == 'بيع قطع إضافية' || item.sourceType == 'قطع زائدة') {
          if (item.sourceId.isNotEmpty) {
            final matches = scrapItems.where((s) => s.id == item.sourceId).toList();
            if (matches.isNotEmpty) matches.first.isSold = true;
          }
          totalScrapValue += item.grandTotal;
        } else if (item.sourceType == 'طلب معمل' || item.sourceType == 'طلبية معمل') {
          if (item.sourceId.isNotEmpty) {
            final orders = workshopOrders.where((o) => o.id == item.sourceId).toList();
            if (orders.isNotEmpty) {
              orders.first.status = 'مكتملة ومرحلة';
            }
          }
        }
      }

      // Complete any associated order linked via inv.sourceId or by client
      if (inv.sourceId.isNotEmpty) {
        final orders = workshopOrders.where((o) => o.id == inv.sourceId).toList();
        if (orders.isNotEmpty) {
          orders.first.status = 'مكتملة ومرحلة';
        }
      }

      // Transfer deposit from Orders Safe to Main Safe
      if (inv.depositDeducted > 0) {
        takeCash('order', inv.currency, inv.depositDeducted);
        addCash('main', inv.currency, inv.depositDeducted);
      }

      if (deductStockId.isNotEmpty && deductQty > 0) {
        final matches = workshopStock.where((w) => w.id == deductStockId).toList();
        if (matches.isNotEmpty) {
          matches.first.availableQty = (matches.first.availableQty - deductQty).clamp(0.0, double.infinity);
        }
      }

      workshopInvoices.add(inv);

      // Route cash
      if (totalScrapValue > 0) {
        final scrapTake = inv.cashPaidNow.clamp(0.0, totalScrapValue);
        final mainTake = (inv.cashPaidNow - scrapTake).clamp(0.0, double.infinity);
        if (scrapTake > 0) addCash('scrap', inv.currency, scrapTake);
        if (mainTake > 0) addCash('main', inv.currency, mainTake);
      } else {
        addCash('main', inv.currency, inv.cashPaidNow);
      }

      // Ensure client account appears in Financials under Factory Financials - Customers
      if (inv.clientName.trim().isNotEmpty) {
        final existingClient = clients
            .where((c) =>
                c.name.trim() == inv.clientName.trim() &&
                c.clientType == 'زبون معمل')
            .firstOrNull;
        final ClientModel client;
        if (existingClient == null) {
          client = ClientModel(
            id: 'cli_wrk_${DateTime.now().millisecondsSinceEpoch}',
            name: inv.clientName.trim(),
            phone: '',
            location: '',
            clientType: 'زبون معمل',
            debtBalance: 0.0,
            debtBalanceSyp: 0.0,
            currencyClassification: inv.currency,
          );
          clients.add(client);
        } else {
          client = existingClient;
          client.currencyClassification = inv.currency;
        }
        if (inv.remainingBalance > 0.01) {
          client.addDebt(inv.currency, inv.remainingBalance);
        }
      }

      notifyListeners();
      saveToDisk();
      return true;
    }

    // Legacy single-item fallback
    WorkshopTailoringModel? tailoringItem;
    final isSimple = inv.sourceType == 'بيع خياطة بسيطة' || inv.sourceType == 'تفصيل بسيط';
    final isComplex = inv.sourceType == 'بيع خياطة معقدة' || inv.sourceType == 'تفصيل معقد';
    if (inv.sourceId.isNotEmpty && (isSimple || isComplex)) {
      final category = isSimple ? 'تفصيل بسيط' : 'تفصيل معقد';
      final isOpeningStockItem = openingEntry.openingStock.any(
        (item) => item.category == category && item.typeId == inv.sourceId,
      );
      if (isOpeningStockItem &&
          (!openingEntry.isLocked || !openingEntry.openingStockApplied)) {
        return false;
      }
      final items = isSimple ? simpleTailorings : complexTailorings;
      final matches = items.where((item) => item.id == inv.sourceId).toList();
      if (matches.isEmpty ||
          inv.sourceQuantity <= 0 ||
          matches.first.quantity + 0.0001 < inv.sourceQuantity) {
        return false;
      }
      tailoringItem = matches.first;
    }
    if (deductStockId.isNotEmpty) {
      final stock = workshopStock
          .where((item) => item.id == deductStockId)
          .toList();
      if (stock.isEmpty || stock.first.availableQty < deductQty) return false;
    }
    final isOrd = inv.sourceType == 'طلب معمل' || inv.sourceType == 'طلبية معمل';
    if (isOrd &&
        inv.depositDeducted > 0 &&
        inv.sourceId.isNotEmpty) {
      final orders = workshopOrders
          .where((order) => order.id == inv.sourceId)
          .toList();
      if (orders.isNotEmpty &&
          cashOf('order', inv.currency) + 0.0001 < inv.depositDeducted) {
        return false;
      }
    }
    workshopInvoices.add(inv);
    if (tailoringItem != null) {
      tailoringItem.quantity = (tailoringItem.quantity - inv.sourceQuantity).clamp(0.0, double.infinity);
    }
    if (inv.sourceType == 'بيع قطع إضافية' || inv.sourceType == 'قطع زائدة') {
      if (inv.sourceId.isNotEmpty) {
        final matches = scrapItems.where((s) => s.id == inv.sourceId).toList();
        if (matches.isNotEmpty) matches.first.isSold = true;
      }
      addCash('scrap', inv.currency, inv.cashPaidNow + inv.depositDeducted);
    } else {
      addCash('main', inv.currency, inv.cashPaidNow);
      if (inv.depositDeducted > 0) {
        if (isOrd && inv.sourceId.isNotEmpty) {
          final orders = workshopOrders
              .where((o) => o.id == inv.sourceId)
              .toList();
          if (orders.isNotEmpty) {
            orders.first.status = 'مكتملة ومرحلة';
            takeCash('order', inv.currency, inv.depositDeducted);
          }
        }
        addCash('main', inv.currency, inv.depositDeducted);
      }
    }
    if (deductStockId.isNotEmpty && deductQty > 0) {
      final matches = workshopStock
          .where((w) => w.id == deductStockId)
          .toList();
      if (matches.isNotEmpty) {
        matches.first.availableQty = (matches.first.availableQty - deductQty)
            .clamp(0.0, double.infinity);
      }
    }

    if (inv.clientName.trim().isNotEmpty) {
      final existingClient = clients
          .where((c) =>
              c.name.trim() == inv.clientName.trim() &&
              c.clientType == 'زبون معمل')
          .firstOrNull;
      final ClientModel client;
      if (existingClient == null) {
        client = ClientModel(
          id: 'cli_wrk_${DateTime.now().millisecondsSinceEpoch}',
          name: inv.clientName.trim(),
          phone: '',
          location: '',
          clientType: 'زبون معمل',
          debtBalance: 0.0,
          debtBalanceSyp: 0.0,
          currencyClassification: inv.currency,
        );
        clients.add(client);
      } else {
        client = existingClient;
        client.currencyClassification = inv.currency;
      }
      if (inv.remainingBalance > 0.01) {
        client.addDebt(inv.currency, inv.remainingBalance);
      }
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  // 7b. Factory Custom Orders (mirror the workshop deposit-box rules)
  void _deductFactoryOrderItemStock(FactoryInvoiceItem item) {
    if (factoryWarehouse.isEmpty) return;
    FactoryWarehouseModel? wh;
    for (final warehouseItem in factoryWarehouse) {
      if (warehouseItem.id == item.itemId) {
        wh = warehouseItem;
        break;
      }
    }
    wh ??= factoryWarehouse.firstWhere(
      (warehouseItem) =>
          warehouseItem.typeName == item.description ||
          warehouseItem.typeName == item.typeName,
      orElse: () => factoryWarehouse.first,
    );
    wh.availableQty = (wh.availableQty - item.calculatedArea).clamp(
      0.0,
      double.infinity,
    );
  }

  void _restoreFactoryOrderItemStock(FactoryInvoiceItem item) {
    if (factoryWarehouse.isEmpty) return;
    FactoryWarehouseModel? wh;
    for (final warehouseItem in factoryWarehouse) {
      if (warehouseItem.id == item.itemId) {
        wh = warehouseItem;
        break;
      }
    }
    wh ??= factoryWarehouse.firstWhere(
      (warehouseItem) =>
          warehouseItem.typeName == item.description ||
          warehouseItem.typeName == item.typeName,
      orElse: () => factoryWarehouse.first,
    );
    wh.availableQty += item.calculatedArea;
  }

  void createFactoryOrder(FactoryOrderModel order) {
    factoryOrders.add(order);
    if (order.depositAmount > 0) {
      addCash('order', order.currency, order.depositAmount);
    }
    // Deduct stock consumed in order line items from Factory Warehouse
    for (final it in order.items) {
      _deductFactoryOrderItemStock(it);
    }
    notifyListeners();
    saveToDisk();
  }

  void cancelFactoryOrder({
    required FactoryOrderModel order,
    required bool isCompleted,
    required bool refundDeposit,
  }) {
    order.status = isCompleted ? 'ملغاة (مكتملة)' : 'ملغاة (غير مكتملة)';
    order.isCompleted = isCompleted;
    order.isSpecialRefund = refundDeposit;

    // If not completed and refund requested: refund deposit to customer from Order Safe
    if (!isCompleted && refundDeposit && order.depositAmount > 0) {
      takeCash('order', order.currency, order.depositAmount);
    }
    // If completed: deposit is NOT refunded and remains in the Orders Safe.
    // If not completed and refundDeposit == false: deposit remains in Orders Safe.

    // In BOTH cases: exact meters consumed in order line items returned to Factory Warehouse
    for (final it in order.items) {
      _restoreFactoryOrderItemStock(it);
    }

    notifyListeners();
    saveToDisk();
  }

  void cancelFactoryOrderLegacy(FactoryOrderModel order, bool isSpecialRefund) {
    cancelFactoryOrder(
      order: order,
      isCompleted: !isSpecialRefund,
      refundDeposit: isSpecialRefund,
    );
  }

  bool assignFactoryOrderToPOSInvoice(
    FactoryOrderModel order,
    FactoryInvoiceModel invoice,
  ) {
    if (invoice.advancePayment < order.depositAmount - 0.001 ||
        invoice.advancePayment > invoice.grandTotal + 0.001) {
      return false;
    }

    // 1. Reconcile stock: restore original order reserved stock so addFactoryPOSInvoice deducts final edited items
    for (final it in order.items) {
      _restoreFactoryOrderItemStock(it);
    }

    // 2. Transfer deposit out of isolated Order Cash Box (it enters Main Cash Box via invoice.advancePayment)
    if (order.depositAmount > 0) {
      takeCash('order', order.currency, order.depositAmount);
    }

    // 3. Mark the order as completed & link invoice
    order.status = 'مكتملة ومرحلة';
    order.isCompleted = true;
    order.assignedInvoiceId = invoice.id;
    order.assignedInvoiceNo = invoice.invoiceNo;

    // 4. Add the POS invoice
    final success = addFactoryPOSInvoice(invoice);

    notifyListeners();
    saveToDisk();
    return success;
  }

  void assignFactoryOrderToInvoice(
    FactoryOrderModel order,
    double cashPaidNow, {
    List<ServiceAttachment> services = const [],
  }) {
    final invoice = FactoryInvoiceModel(
      id: 'fi_ord_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNo: 'FAC-ORD-${factoryInvoices.length + 101}',
      date: DateTime.now(),
      partyId: order.partyId,
      partyName: order.clientName,
      invoiceType: 'بيع_معتمد',
      items: order.items.isNotEmpty
          ? List.of(order.items)
          : [
              FactoryInvoiceItem(
                itemId: order.warehouseItemId,
                description: order.itemDescription,
                lengthCm: order.lengthCm,
                widthCm: order.widthCm,
                heightCm: order.heightCm,
                quantity: order.quantity,
                unitPrice: order.unitPrice,
                unitCost: order.unitPrice,
                services: services,
              ),
            ],
      isGoodsDelivered: order.isGoodsDelivered,
      shippingFee: order.shippingFee,
      discountAmount: order.discountAmount,
      advancePayment: order.depositAmount + cashPaidNow,
      photoUrl: order.photoPath,
      currency: order.currency,
    );
    assignFactoryOrderToPOSInvoice(order, invoice);
  }

  /// Workshop stock helpers for tailoring line items.
  bool deductWorkshopStock(String stockId, double qty) {
    final matches = workshopStock.where((w) => w.id == stockId).toList();
    if (matches.isEmpty || qty <= 0) return false;
    if (matches.first.availableQty + 0.0001 < qty) return false;
    matches.first.availableQty -= qty;
    notifyListeners();
    saveToDisk();
    return true;
  }

  void restoreWorkshopStock(String stockId, double qty) {
    final matches = workshopStock.where((w) => w.id == stockId).toList();
    if (matches.isEmpty || qty <= 0) return;
    matches.first.availableQty += qty;
    notifyListeners();
    saveToDisk();
  }

  /// Factory warehouse helpers for tailoring replenishment and stock adjustments.
  bool deductFactoryWarehouseStock(String whId, double qty) {
    final matches = factoryWarehouse.where((w) => w.id == whId).toList();
    if (matches.isEmpty || qty <= 0) return false;
    if (matches.first.availableQty + 0.0001 < qty) return false;
    matches.first.availableQty -= qty;
    notifyListeners();
    saveToDisk();
    return true;
  }

  void restoreFactoryWarehouseStock(String whId, double qty) {
    final matches = factoryWarehouse.where((w) => w.id == whId).toList();
    if (matches.isEmpty || qty <= 0) return;
    matches.first.availableQty += qty;
    notifyListeners();
    saveToDisk();
  }

  // 8. Add Scrap & Sell Scrap (exclusively routes to Scrap Cash Box)
  // When baseCost is 0/empty => 100% margin, no cost rows required.
  // When baseCost > 0 => it MUST be broken down into worker/expense rows
  // recorded under Surplus Financials (see addScrapItemWithCosts).
  void addScrapItem(ScrapItemModel item) {
    scrapItems.add(item);
    notifyListeners();
    saveToDisk();
  }

  /// Adds a surplus item together with its initial-price breakdown.
  /// The sum of [costs] should equal [item.baseCost]; when baseCost is 0,
  /// [costs] must be empty (100% margin rule).
  void addScrapItemWithCosts(
    ScrapItemModel item,
    List<SurplusCostModel> costs,
  ) {
    scrapItems.add(item);
    for (final c in costs) {
      surplusCosts.add(
        SurplusCostModel(
          id: c.id,
          surplusItemId: item.id,
          surplusDescription: item.description,
          kind: c.kind,
          beneficiaryName: c.beneficiaryName,
          staffId: c.staffId,
          amountDue: c.amountDue,
          amountPaid: 0.0,
          date: c.date,
          notes: c.notes,
          currency: item.currency,
        ),
      );
    }
    notifyListeners();
    saveToDisk();
  }

  void sellScrapItem(ScrapItemModel item) {
    item.isSold = true;
    // CRITICAL ACCOUNTING RULE: All sales from Scrap route directly to Scrap Cash Box (Surplus Fund)
    addCash('scrap', item.currency, item.sellingPrice);
    notifyListeners();
    saveToDisk();
  }

  // 8b. Surplus Financials ledger — paid ONLY from the Surplus Fund.
  void addSurplusCost(SurplusCostModel cost) {
    surplusCosts.add(cost);
    // Keep the item's initial price in sync with its ledger rows.
    final matches = scrapItems
        .where((s) => s.id == cost.surplusItemId)
        .toList();
    if (matches.isNotEmpty) {
      matches.first.baseCost += cost.amountDue;
    }
    notifyListeners();
    saveToDisk();
  }

  /// Pays a surplus worker/expense from the Surplus Fund (same currency).
  bool paySurplusCost(String costId, double amount) {
    final matches = surplusCosts.where((c) => c.id == costId).toList();
    if (matches.isEmpty || amount <= 0) return false;
    final c = matches.first;
    final pay = amount.clamp(0.0, c.remaining).toDouble();
    if (pay <= 0) return false;
    if (!takeCash('scrap', c.currency, pay)) return false;
    c.amountPaid += pay;
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Settles the full remaining balance of a surplus cost from the Surplus Fund.
  bool settleSurplusCost(String costId) {
    final matches = surplusCosts.where((c) => c.id == costId).toList();
    if (matches.isEmpty) return false;
    return paySurplusCost(costId, matches.first.remaining);
  }

  bool deleteSurplusCost(String costId) {
    final matches = surplusCosts.where((c) => c.id == costId).toList();
    if (matches.isEmpty || matches.first.amountPaid > 0.01) return false;
    final c = matches.first;
    surplusCosts.removeWhere((x) => x.id == costId);
    final items = scrapItems.where((s) => s.id == c.surplusItemId).toList();
    if (items.isNotEmpty) {
      items.first.baseCost = (items.first.baseCost - c.amountDue).clamp(
        0.0,
        double.infinity,
      );
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  // 9. Add Waste Log
  void addWasteLog(WasteLogModel log) {
    wasteLogs.add(log);
    notifyListeners();
    saveToDisk();
  }

  /// Records waste linked to a specific workshop section/inventory item,
  /// deducts the wasted quantity from the selected inventory source,
  /// and logs an abnormal waste entry so that its financial cost is routed
  /// to the Income Summary under "Abnormal Waste Losses" (خسائر الهدر غير الطبيعي).
  bool recordWorkshopWaste({
    required String sourceSection, // 'مواد المعمل' | 'قسم التفصيل البسيط' | 'قسم التفصيل المعقد' | 'قسم الزيادات' | 'يدوي'
    required String sourceItemId,
    required double quantity,
    required double cost,
    String wasteType = 'هدر غير طبيعي',
    String destructionVoucherNo = '',
    String currency = AppCurrency.usd,
    String? customDescription,
  }) {
    if (quantity <= 0) {
      throw ArgumentError('يجب أن تكون الكمية المهدرة أكبر من الصفر');
    }

    String itemDesc = customDescription?.trim() ?? '';
    String unit = '';

    final sec = sourceSection.trim();
    if (sec == 'مواد المعمل' || sec == 'workshop_material') {
      final matches = workshopStock.where((w) => w.id == sourceItemId).toList();
      if (matches.isEmpty) {
        throw ArgumentError('المادة المحددة غير موجودة في مواد المعمل');
      }
      final stock = matches.first;
      if (quantity > stock.availableQty) {
        throw ArgumentError('الكمية المهدرة ($quantity) تتجاوز الرصيد المتاح (${stock.availableQty}) في مواد المعمل');
      }
      stock.availableQty = (stock.availableQty - quantity).clamp(0.0, double.infinity);
      unit = stock.category;
      if (itemDesc.isEmpty) {
        itemDesc = '${stock.typeName} (${stock.grade}) - مواد المعمل';
      }
    } else if (sec == 'قسم التفصيل البسيط' || sec == 'simple_tailoring' || sec == 'تفصيل بسيط') {
      final matches = simpleTailorings.where((t) => t.id == sourceItemId).toList();
      if (matches.isEmpty) {
        throw ArgumentError('البند المحدد غير موجود في قسم التفصيل البسيط');
      }
      final tailoring = matches.first;
      if (quantity > tailoring.quantity) {
        throw ArgumentError('الكمية المهدرة ($quantity) تتجاوز الرصيد المتاح (${tailoring.quantity}) في التفصيل البسيط');
      }
      tailoring.quantity = (tailoring.quantity - quantity).clamp(0.0, double.infinity);
      unit = tailoring.unitSymbol;
      if (itemDesc.isEmpty) {
        itemDesc = '${tailoring.name} - قسم التفصيل البسيط';
      }
    } else if (sec == 'قسم التفصيل المعقد' || sec == 'complex_tailoring' || sec == 'تفصيل معقد') {
      final matches = complexTailorings.where((t) => t.id == sourceItemId).toList();
      if (matches.isEmpty) {
        throw ArgumentError('البند المحدد غير موجود في قسم التفصيل المعقد');
      }
      final tailoring = matches.first;
      if (quantity > tailoring.quantity) {
        throw ArgumentError('الكمية المهدرة ($quantity) تتجاوز عدد القطع المتاحة (${tailoring.quantity.toInt()}) في التفصيل المعقد');
      }
      tailoring.quantity = (tailoring.quantity - quantity).clamp(0.0, double.infinity);
      unit = 'قطعة';
      if (itemDesc.isEmpty) {
        itemDesc = '${tailoring.name} - قسم التفصيل المعقد';
      }
    } else if (sec == 'قسم الزيادات' || sec == 'scrap_item' || sec == 'الزيادات') {
      final matches = scrapItems.where((s) => s.id == sourceItemId).toList();
      if (matches.isEmpty) {
        throw ArgumentError('القطعة الزائدة غير موجودة في قسم الزيادات');
      }
      final scrap = matches.first;
      if (scrap.isSold || quantity > scrap.quantity) {
        throw ArgumentError('الكمية المهدرة ($quantity) تتجاوز الرصيد المتاح (${scrap.quantity}) في قسم الزيادات');
      }
      scrap.quantity = (scrap.quantity - quantity).clamp(0.0, double.infinity);
      if (scrap.quantity <= 0.0001) {
        scrap.quantity = 0.0;
        scrap.isSold = true;
      }
      unit = 'قطعة';
      if (itemDesc.isEmpty) {
        itemDesc = '${scrap.description} - قسم الزيادات';
      }
    } else {
      // Direct / Manual
      if (itemDesc.isEmpty) {
        itemDesc = 'هدر ورشة مباشر';
      }
      unit = 'وحدة';
    }

    final voucher = destructionVoucherNo.trim().isNotEmpty
        ? destructionVoucherNo.trim()
        : 'إتلاف-${DateTime.now().millisecondsSinceEpoch}';

    final log = WasteLogModel(
      id: 'wl_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      wasteType: wasteType,
      itemDescription: itemDesc,
      quantity: quantity,
      cost: cost,
      destructionVoucherNo: voucher,
      currency: AppCurrency.normalize(currency),
      sourceSection: sec,
      sourceItemId: sourceItemId,
      unit: unit,
    );

    wasteLogs.add(log);
    notifyListeners();
    saveToDisk();
    return true;
  }

  void deleteWasteLog(String id) {
    final idx = wasteLogs.indexWhere((w) => w.id == id);
    if (idx != -1) {
      final log = wasteLogs[idx];
      _restoreWasteStock(log);
      wasteLogs.removeAt(idx);
      notifyListeners();
      saveToDisk();
    }
  }

  void _restoreWasteStock(WasteLogModel log) {
    if (log.sourceSection.isEmpty || log.sourceItemId.isEmpty) return;
    final sec = log.sourceSection.trim();
    if (sec == 'مواد المعمل' || sec == 'workshop_material') {
      final matches = workshopStock.where((w) => w.id == log.sourceItemId).toList();
      if (matches.isNotEmpty) {
        matches.first.availableQty += log.quantity;
      }
    } else if (sec == 'قسم التفصيل البسيط' || sec == 'simple_tailoring' || sec == 'تفصيل بسيط') {
      final matches = simpleTailorings.where((t) => t.id == log.sourceItemId).toList();
      if (matches.isNotEmpty) {
        matches.first.quantity += log.quantity;
      }
    } else if (sec == 'قسم التفصيل المعقد' || sec == 'complex_tailoring' || sec == 'تفصيل معقد') {
      final matches = complexTailorings.where((t) => t.id == log.sourceItemId).toList();
      if (matches.isNotEmpty) {
        matches.first.quantity += log.quantity;
      }
    } else if (sec == 'قسم الزيادات' || sec == 'scrap_item' || sec == 'الزيادات') {
      final matches = scrapItems.where((s) => s.id == log.sourceItemId).toList();
      if (matches.isNotEmpty) {
        final sc = matches.first;
        sc.quantity += log.quantity;
        if (sc.quantity > 0) {
          sc.isSold = false;
        }
      }
    }
  }

  // 10. Staff Workday Execution & Advances (per currency)
  void recordWorkdayExecution(WorkdayEntryModel entry) {
    workdayEntries.add(entry);
    // Add earnings to selected staff ledger (same currency as the entry)
    for (var staffName in entry.staffNames) {
      var staff = staffList.firstWhere(
        (s) => s.name == staffName,
        orElse: () => staffList.first,
      );
      staff.addEarning(entry.currency, entry.agreedAmountPerPerson);
    }
    notifyListeners();
    saveToDisk();
  }

  static DateTime _startOfWorkweek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  bool addStaffType(StaffTypeModel type) {
    if ((type.category != 'عمال' && type.category != 'إداريين') ||
        type.name.trim().isEmpty ||
        !type.dailyRate.isFinite ||
        type.dailyRate <= 0 ||
        staffTypes.any(
          (item) =>
              item.category == type.category &&
              item.name.trim().toLowerCase() == type.name.trim().toLowerCase(),
        )) {
      return false;
    }
    staffTypes.add(type);
    notifyListeners();
    saveToDisk();
    return true;
  }

  bool setStaffAttendance({
    required StaffModel staff,
    required DateTime date,
    required bool present,
  }) {
    if (staff.category != 'عمال' && staff.category != 'إداريين') return false;
    final day = DateTime(date.year, date.month, date.day);
    final existing = staffAttendance.where(
      (entry) =>
          entry.staffId == staff.id &&
          entry.date.year == day.year &&
          entry.date.month == day.month &&
          entry.date.day == day.day,
    );
    if (present && existing.isNotEmpty) return true;
    if (!present && existing.isEmpty) return true;

    if (present) {
      final matchingTypes = staffTypes.where(
        (type) => type.id == staff.typeId && type.category == staff.category,
      );
      if (matchingTypes.isEmpty) return false;
      final rate = matchingTypes.first.dailyRate;
      final attendance = StaffAttendanceModel(
        id: 'attendance_${staff.id}_${day.toIso8601String()}',
        date: day,
        staffId: staff.id,
        dailyRate: rate,
      );
      staffAttendance.add(attendance);
      staff.addEarning(attendance.currency, rate);
    } else {
      final attendanceEntries = existing.toList();
      if (attendanceEntries.any(
        (entry) =>
            staff.netOf(entry.currency) + 0.0001 < entry.dailyRate,
      )) {
        return false;
      }
      for (final attendance in attendanceEntries) {
        staff.removeEarning(attendance.currency, attendance.dailyRate);
        staffAttendance.remove(attendance);
      }
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  void openNextWorkweek() {
    activeWorkweekStart = activeWorkweekStart.add(const Duration(days: 7));
    notifyListeners();
    saveToDisk();
  }

  bool recordTechnicianWorkday(WorkdayEntryModel entry) {
    if (entry.staffNames.length != 1 ||
        !entry.agreedAmountPerPerson.isFinite ||
        entry.agreedAmountPerPerson <= 0) {
      return false;
    }
    final staffMatches = staffList
        .where(
          (staff) =>
              (entry.staffId.isNotEmpty
                  ? staff.id == entry.staffId
                  : staff.name == entry.staffNames.single) &&
              staff.category == 'معلمين',
        )
        .toList();
    if (staffMatches.isEmpty) return false;
    final staff = staffMatches.first;
    workdayEntries.add(entry);
    staff.addEarning(entry.currency, entry.agreedAmountPerPerson);
    notifyListeners();
    saveToDisk();
    return true;
  }

  void disburseCashAdvance(
    StaffModel staff,
    double amount, [
    String? currency,
  ]) {
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    if (amount <= 0) return;
    if (!takeCash('main', c, amount)) return;
    staff.addAdvance(c, amount);
    notifyListeners();
    saveToDisk();
  }

  // 11. Add Return Invoice Engine (sales returns also restore stock)
  bool processReturnInvoice(ReturnInvoiceModel ret) {
    final supplierReturn = ret.returnType == 'مرتجع مشتريات مورد';
    if (ret.partyName.trim().isEmpty ||
        !ret.refundAmount.isFinite ||
        ret.refundAmount <= 0 ||
        !ret.quantity.isFinite ||
        ret.quantity <= 0) {
      return false;
    }
    if (ret.paymentAction == 'استرداد نقدي للصندوق الرئيسي') {
      if (!supplierReturn &&
          cashOf('main', ret.currency) + 0.0001 < ret.refundAmount) {
        return false;
      }
    } else if (ret.paymentAction != 'تخفيض دين') {
      return false;
    }

    returnInvoices.add(ret);
    if (ret.paymentAction == 'استرداد نقدي للصندوق الرئيسي') {
      if (supplierReturn) {
        addCash('main', ret.currency, ret.refundAmount);
      } else {
        takeCash('main', ret.currency, ret.refundAmount);
      }
      final availableDebt = _adjustmentDebtBalance(
        supplier: supplierReturn,
        partyName: ret.partyName,
        partyId: '',
        currency: ret.currency,
      );
      if (availableDebt > 0) {
        _reduceAdjustmentDebt(
          supplier: supplierReturn,
          partyName: ret.partyName,
          partyId: '',
          currency: ret.currency,
          amount: ret.refundAmount < availableDebt
              ? ret.refundAmount
              : availableDebt,
        );
      }
    } else {
      _reduceAdjustmentDebt(
        supplier: supplierReturn,
        partyName: ret.partyName,
        partyId: '',
        currency: ret.currency,
        amount: ret.refundAmount,
      );
    }
    // Restore returned goods to the matching stock.
    if (ret.returnType == 'مرتجع مبيعات مصنع' && ret.quantity > 0) {
      final matches = factoryWarehouse
          .where(
            (w) =>
                ret.itemDescription.contains(w.typeName) ||
                w.typeName.contains(ret.itemDescription),
          )
          .toList();
      if (matches.isNotEmpty) matches.first.availableQty += ret.quantity;
    } else if (ret.returnType == 'مرتجع مبيعات معمل' && ret.quantity > 0) {
      final matches = workshopStock
          .where(
            (w) =>
                ret.itemDescription.contains(w.typeName) ||
                w.typeName.contains(ret.itemDescription),
          )
          .toList();
      if (matches.isNotEmpty) matches.first.availableQty += ret.quantity;
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Notifies listeners and persists (for direct list mutations from UI).
  void refresh() {
    notifyListeners();
    saveToDisk();
  }

  // -------------------------------------------------------------
  // FINANCIALS: payments, collections, projects, staff settlement
  // -------------------------------------------------------------

  /// Pays a factory supplier's outstanding debt directly from the Main Cash Box.
  /// [currency]: currency to pay in (USD or SYP).
  /// Strictly prevents paying more than the supplier's due balance or available cash.
  /// Settles the supplier's open purchase invoices in that currency FIFO.
  bool paySupplierDebt({
    required SupplierModel supplier,
    required double amount,
    required String currency,
  }) {
    if (amount <= 0) return false;
    final c = AppCurrency.normalize(currency);
    final due = supplier.debtOf(c);
    if (amount > due + 0.001) return false;
    final pay = amount.clamp(0.0, due).toDouble();
    if (pay <= 0) return false;
    if (!takeCash('main', c, pay, allowNegative: true)) return false;

    supplier.reduceDebt(c, pay);

    // Settle supplier open invoices FIFO in that currency
    double remainingToSettle = pay;
    final openInvs = factoryInvoices
        .where(
          (i) =>
              i.invoiceType == 'شراء_مورد' &&
              (i.partyId == supplier.id || i.partyName == supplier.name) &&
              AppCurrency.normalize(i.currency) == c &&
              i.remainingBalance > 0.01,
        )
        .toList();

    for (final inv in openInvs) {
      if (remainingToSettle <= 0.001) break;
      final settlePart =
          remainingToSettle.clamp(0.0, inv.remainingBalance).toDouble();
      inv.advancePayment += settlePart;
      inv.paymentStatus =
          inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
      remainingToSettle -= settlePart;
    }

    recordBlockPurchaseExpense(
      amount: pay,
      currency: c,
      supplierName: supplier.name,
      note: 'تسديد دفعة للمورد ${supplier.name} عن مشتريات بلوكات',
    );

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Pays a supplier purchase invoice (we pay them): advances the invoice,
  /// reduces the supplier debt and the Main Cash Box (invoice currency).
  bool paySupplierInvoice(FactoryInvoiceModel inv, double amount) {
    if (amount <= 0 || amount > inv.remainingBalance + 0.001) return false;
    final pay = amount;
    if (!takeCash('main', inv.currency, pay, allowNegative: true)) return false;
    inv.advancePayment += pay;
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    final matches = suppliers.where((s) => s.id == inv.partyId).toList();
    if (matches.isNotEmpty) {
      matches.first.reduceDebt(inv.currency, pay);
    }
    recordBlockPurchaseExpense(
      amount: pay,
      currency: inv.currency,
      supplierName: inv.partyName,
      note:
          'تسديد دفعة فاتورة شراء بلوكات رقم ${inv.invoiceNo} للمورد ${inv.partyName}',
    );
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Collects a factory sale invoice (they pay us) — invoice currency.
  bool collectFactoryInvoice(FactoryInvoiceModel inv, double amount) {
    if (amount <= 0 || amount > inv.remainingBalance + 0.001) return false;
    final take = amount;
    inv.advancePayment += take;
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    addCash('main', inv.currency, take);
    final matches = clients.where((c) => c.id == inv.partyId).toList();
    if (matches.isNotEmpty) {
      matches.first.reduceDebt(inv.currency, take);
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Collects a workshop invoice. Scrap-sourced invoices route to the
  /// Scrap Cash Box, everything else to the Main Cash Box.
  bool collectWorkshopInvoice(WorkshopInvoiceModel inv, double amount) {
    if (amount <= 0 || amount > inv.remainingBalance + 0.001) return false;
    final take = amount;
    // Route the cash, then record the collection by raising cashPaidNow
    // (invoice fields are immutable, so the entry is replaced).
    final hasOnlyScrap = inv.items.isNotEmpty
        ? inv.items.every((i) => i.sourceType == 'قطع زائدة')
        : inv.sourceType == 'قطع زائدة';
    if (hasOnlyScrap) {
      addCash('scrap', inv.currency, take);
    } else {
      addCash('main', inv.currency, take);
    }
    final idx = workshopInvoices.indexWhere((i) => i.id == inv.id);
    if (idx >= 0) {
      final old = workshopInvoices[idx];
      workshopInvoices[idx] = WorkshopInvoiceModel(
        id: old.id,
        invoiceNo: old.invoiceNo,
        date: old.date,
        clientName: old.clientName,
        items: old.items,
        sourceType: old.sourceType,
        sourceId: old.sourceId,
        projectId: old.projectId,
        itemDescription: old.itemDescription,
        sourceQuantity: old.sourceQuantity,
        sourceUnitCategory: old.sourceUnitCategory,
        agreedPrice: old.agreedPrice,
        depositDeducted: old.depositDeducted,
        cashPaidNow: old.cashPaidNow + take,
        netCost: old.netCost,
        salesDiscount: old.salesDiscount,
        adjustmentsAmount: old.adjustmentsAmount,
        services: old.services,
        photoPath: old.photoPath,
        isGranite: old.isGranite,
        isCashInvoice: old.isCashInvoice,
        currency: old.currency,
      );
    }
    final client = clients.where((c) => c.name.trim() == inv.clientName.trim() && c.clientType == 'زبون معمل').firstOrNull;
    if (client != null) {
      client.reduceDebt(inv.currency, take);
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Multi-currency customer debt collection method.
  /// Supports direct payment (same currency) and cross-currency payment with exchange rate.
  /// Accurate double-entry accounting between Customer Account and Main Safe vaults.
  /// Strictly prevents overcollection beyond due debt balance and settles invoices FIFO.
  bool collectCustomerPayment({
    required ClientModel client,
    required String paymentCurrency,
    required double paymentAmount,
    double? exchangeRate,
  }) {
    if (paymentAmount <= 0) return false;
    final payCurr = AppCurrency.normalize(paymentCurrency);
    final acctCurr = AppCurrency.normalize(client.currencyClassification);
    final currentDebt = client.debtOf(acctCurr);

    double convertedAcctAmount = 0.0;

    if (payCurr == acctCurr) {
      // Case A: Direct Payment (Same Currency)
      if (paymentAmount > currentDebt + 0.001) return false;
      final take = paymentAmount.clamp(0.0, currentDebt).toDouble();
      if (take <= 0) return false;
      client.reduceDebt(acctCurr, take);
      addCash('main', payCurr, take);
      convertedAcctAmount = take;
    } else {
      // Case B: Cross-Currency Payment (Different Currency)
      if (exchangeRate == null || exchangeRate <= 0) return false;

      if (acctCurr == AppCurrency.usd && payCurr == AppCurrency.syp) {
        // Scenario 1: USD Customer Paying in SYP
        // Converted USD Amount = amount_syp / exchange_rate
        final amountSyp = paymentAmount;
        final convertedUsd = amountSyp / exchangeRate;
        if (convertedUsd <= 0) return false;
        if (convertedUsd > currentDebt + 0.001) return false;

        client.reduceDebt(AppCurrency.usd, convertedUsd);
        addCash('main', AppCurrency.syp, amountSyp);
        convertedAcctAmount = convertedUsd;
      } else if (acctCurr == AppCurrency.syp && payCurr == AppCurrency.usd) {
        // Scenario 2: SYP Customer Paying in USD
        // Converted SYP Amount = amount_usd * exchange_rate
        final amountUsd = paymentAmount;
        final convertedSyp = amountUsd * exchangeRate;
        if (convertedSyp <= 0) return false;
        if (convertedSyp > currentDebt + 0.001) return false;

        client.reduceDebt(AppCurrency.syp, convertedSyp);
        addCash('main', AppCurrency.usd, amountUsd);
        convertedAcctAmount = convertedSyp;
      } else {
        return false;
      }
    }

    // Settle open invoices for this client FIFO
    // 1. Factory Sale Invoices (if Factory Agent)
    if (client.clientType == 'معتمد مصنع') {
      double remainingToSettle = convertedAcctAmount;
      final agentInvs = factoryInvoices
          .where(
            (i) =>
                i.invoiceType == 'بيع_معتمد' &&
                (i.partyId == client.id || i.partyName == client.name) &&
                AppCurrency.normalize(i.currency) == acctCurr &&
                i.remainingBalance > 0.01,
          )
          .toList();

      for (final inv in agentInvs) {
        if (remainingToSettle <= 0.001) break;
        final settlePart =
            remainingToSettle.clamp(0.0, inv.remainingBalance).toDouble();
        inv.advancePayment += settlePart;
        inv.paymentStatus =
            inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
        remainingToSettle -= settlePart;
      }
      if (remainingToSettle > 0.001) {
        if (acctCurr == AppCurrency.usd) {
          unallocatedFactoryCollectionsUsd += remainingToSettle;
        } else {
          unallocatedFactoryCollectionsSyp += remainingToSettle;
        }
      }
    }

    // 2. Workshop Retail Invoices (if Retail Customer)
    if (client.clientType == 'زبون معمل' || client.clientType == 'زبون عادي') {
      double remainingToSettle = convertedAcctAmount;
      final retailInvs = workshopInvoices
          .where(
            (i) =>
                i.projectId.isEmpty &&
                i.clientName.trim() == client.name.trim() &&
                AppCurrency.normalize(i.currency) == acctCurr &&
                i.remainingBalance > 0.01,
          )
          .toList();

      for (final inv in retailInvs) {
        if (remainingToSettle <= 0.001) break;
        final settlePart =
            remainingToSettle.clamp(0.0, inv.remainingBalance).toDouble();
        final idx = workshopInvoices.indexWhere((x) => x.id == inv.id);
        if (idx >= 0) {
          final old = workshopInvoices[idx];
          workshopInvoices[idx] = WorkshopInvoiceModel(
            id: old.id,
            invoiceNo: old.invoiceNo,
            date: old.date,
            clientName: old.clientName,
            items: old.items,
            sourceType: old.sourceType,
            sourceId: old.sourceId,
            projectId: old.projectId,
            itemDescription: old.itemDescription,
            sourceQuantity: old.sourceQuantity,
            sourceUnitCategory: old.sourceUnitCategory,
            agreedPrice: old.agreedPrice,
            depositDeducted: old.depositDeducted,
            cashPaidNow: old.cashPaidNow + settlePart,
            netCost: old.netCost,
            salesDiscount: old.salesDiscount,
            adjustmentsAmount: old.adjustmentsAmount,
            services: old.services,
            photoPath: old.photoPath,
            isGranite: old.isGranite,
            isCashInvoice: old.isCashInvoice,
            currency: old.currency,
          );
        }
        remainingToSettle -= settlePart;
      }
      if (remainingToSettle > 0.001) {
        if (acctCurr == AppCurrency.usd) {
          unallocatedWorkshopCollectionsUsd += remainingToSettle;
        } else {
          unallocatedWorkshopCollectionsSyp += remainingToSettle;
        }
      }
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Collects a payment directly on a workshop project.
  /// [currency]: currency collected (USD or SYP).
  /// Strictly prevents collecting more than the project's remaining due in that currency.
  /// Settles open workshop invoices for this project FIFO, updates the project client's debt,
  /// and deposits the cash into the Main Cash Box (or Scrap Box if scrap-only).
  bool collectProjectPayment({
    required String projectId,
    required double amount,
    required String currency,
  }) {
    if (amount <= 0) return false;
    final c = AppCurrency.normalize(currency);
    final due = projectDueOf(projectId, c);
    if (amount > due + 0.001) return false;
    final take = amount.clamp(0.0, due).toDouble();
    if (take <= 0) return false;

    // Apply FIFO to project invoices in that currency
    double remainingToSettle = take;
    final projInvs = workshopInvoices
        .where(
          (i) =>
              i.projectId == projectId &&
              AppCurrency.normalize(i.currency) == c &&
              i.remainingBalance > 0.01,
        )
        .toList();

    for (final inv in projInvs) {
      if (remainingToSettle <= 0.001) break;
      final settlePart =
          remainingToSettle.clamp(0.0, inv.remainingBalance).toDouble();
      final hasOnlyScrap = inv.items.isNotEmpty
          ? inv.items.every((i) => i.sourceType == 'قطع زائدة')
          : inv.sourceType == 'قطع زائدة';
      if (hasOnlyScrap) {
        addCash('scrap', c, settlePart);
      } else {
        addCash('main', c, settlePart);
      }

      final idx = workshopInvoices.indexWhere((x) => x.id == inv.id);
      if (idx >= 0) {
        final old = workshopInvoices[idx];
        workshopInvoices[idx] = WorkshopInvoiceModel(
          id: old.id,
          invoiceNo: old.invoiceNo,
          date: old.date,
          clientName: old.clientName,
          items: old.items,
          sourceType: old.sourceType,
          sourceId: old.sourceId,
          projectId: old.projectId,
          itemDescription: old.itemDescription,
          sourceQuantity: old.sourceQuantity,
          sourceUnitCategory: old.sourceUnitCategory,
          agreedPrice: old.agreedPrice,
          depositDeducted: old.depositDeducted,
          cashPaidNow: old.cashPaidNow + settlePart,
          netCost: old.netCost,
          salesDiscount: old.salesDiscount,
          adjustmentsAmount: old.adjustmentsAmount,
          services: old.services,
          photoPath: old.photoPath,
          isGranite: old.isGranite,
          isCashInvoice: old.isCashInvoice,
          currency: old.currency,
        );
      }
      remainingToSettle -= settlePart;
    }
    if (remainingToSettle > 0.001) {
      if (c == AppCurrency.usd) {
        unallocatedWorkshopCollectionsUsd += remainingToSettle;
      } else {
        unallocatedWorkshopCollectionsSyp += remainingToSettle;
      }
    }

    // Also reduce client debt if matching client exists
    final proj = workshopProjects.where((p) => p.id == projectId).firstOrNull;
    if (proj != null) {
      final client = clients
          .where((cl) => cl.name.trim() == proj.clientName.trim())
          .firstOrNull;
      if (client != null) {
        client.reduceDebt(c, take);
      }
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Collects a retail/approved client balance not tied to a single invoice.
  /// [currency] selects which fund/debt (defaults to customer's account currency).
  bool collectClientDebt(
    ClientModel client,
    double amount, [
    String? currency,
  ]) {
    return collectCustomerPayment(
      client: client,
      paymentCurrency: currency ?? client.currencyClassification,
      paymentAmount: amount,
    );
  }

  /// Settles everything owed to a staff member from the Main Cash Box.
  /// [currency] selects which fund/ledger (USD default; pass SYP for ل.س).
  bool settleStaffDue(StaffModel staff, [String? currency]) {
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    final due = staff.netOf(c);
    if (due <= 0.01) return false;
    if (!takeCash('main', c, due)) return false;
    staff.addAdvance(c, due);
    const defaultWageTypeId = 'workforce_wages_expense';
    final matchingWageTypes = expenseTypes
        .where(
          (type) =>
              type.id == defaultWageTypeId || type.name.trim() == 'أجور العمال',
        )
        .toList();
    final wageTypeId = matchingWageTypes.isEmpty
        ? defaultWageTypeId
        : matchingWageTypes.first.id;
    if (matchingWageTypes.isEmpty) {
      expenseTypes.add(
        ExpenseTypeModel(
          id: wageTypeId,
          name: 'أجور العمال',
          description: 'تسديد مستحقات العمال والمعلمين والإداريين',
        ),
      );
    }
    expenseRecords.add(
      ExpenseRecordModel(
        id: 'wage_payment_${DateTime.now().microsecondsSinceEpoch}',
        typeId: wageTypeId,
        amount: due,
        currency: c,
        personName: staff.name,
        staffId: staff.id,
        description: 'تسديد مستحقات ${staff.name}',
      ),
    );
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// 1. Pay Staff Wages:
  /// Allows paying worker's wage with currency selection (USD or SYP).
  /// Routed to Expenses under 'الرواتب والأجور' (Salaries & Wages)
  /// and deducted from Main Safe.
  bool payStaffWages(
    StaffModel staff,
    double amount,
    String currency, {
    String note = '',
  }) {
    final c = AppCurrency.normalize(currency);
    if (amount <= 0.0001) return false;
    if (cashOf('main', c) < amount) return false;
    if (!takeCash('main', c, amount)) return false;

    const defaultWageTypeId = 'salaries_and_wages_expense';
    final matchingWageTypes = expenseTypes
        .where(
          (type) =>
              type.id == defaultWageTypeId ||
              type.name.trim() == 'الرواتب والأجور' ||
              type.name.trim() == 'الرواتب والأجور (Salaries & Wages)' ||
              type.name.trim() == 'أجور العمال',
        )
        .toList();
    final wageTypeId = matchingWageTypes.isEmpty
        ? defaultWageTypeId
        : matchingWageTypes.first.id;
    if (matchingWageTypes.isEmpty) {
      expenseTypes.add(
        ExpenseTypeModel(
          id: wageTypeId,
          name: 'الرواتب والأجور (Salaries & Wages)',
          description: 'رواتب وأجور العمال والمعلمين والإداريين',
        ),
      );
    }
    expenseRecords.add(
      ExpenseRecordModel(
        id: 'wage_exp_${DateTime.now().microsecondsSinceEpoch}',
        typeId: wageTypeId,
        amount: amount,
        currency: c,
        personName: staff.name,
        staffId: staff.id,
        description: note.isNotEmpty
            ? note
            : 'دفع أجور (${staff.category}): ${staff.name}',
      ),
    );
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// 2. Pay Staff Advance:
  /// Issues advance payment with currency selection (USD or SYP).
  /// Routed to Expenses under 'السُلف' (Advances) category,
  /// deducted from Main Safe, and added to staff advance balance.
  bool payStaffAdvance(
    StaffModel staff,
    double amount,
    String currency, {
    String note = '',
  }) {
    final c = AppCurrency.normalize(currency);
    if (amount <= 0.0001) return false;
    if (cashOf('main', c) < amount) return false;
    if (!takeCash('main', c, amount)) return false;

    staff.addAdvance(c, amount);

    const defaultAdvTypeId = 'advances_expense';
    final matchingAdvTypes = expenseTypes
        .where(
          (type) =>
              type.id == defaultAdvTypeId ||
              type.name.trim() == 'السُلف' ||
              type.name.trim() == 'السلف' ||
              type.name.trim() == 'السُلف (Advances)',
        )
        .toList();
    final advTypeId = matchingAdvTypes.isEmpty
        ? defaultAdvTypeId
        : matchingAdvTypes.first.id;
    if (matchingAdvTypes.isEmpty) {
      expenseTypes.add(
        ExpenseTypeModel(
          id: advTypeId,
          name: 'السُلف (Advances)',
          description: 'سُلف العمال والمعلمين والإداريين',
        ),
      );
    }
    expenseRecords.add(
      ExpenseRecordModel(
        id: 'adv_exp_${DateTime.now().microsecondsSinceEpoch}',
        typeId: advTypeId,
        amount: amount,
        currency: c,
        personName: staff.name,
        staffId: staff.id,
        description: note.isNotEmpty
            ? note
            : 'سلفة نقدية لـ (${staff.category}): ${staff.name}',
      ),
    );
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// 3. Collect/Repay Staff Advance:
  /// Repays portion or all of advance balance.
  /// Collected amount enters Main Safe.
  /// Deducted amount reduces staff advance balance in original currency.
  /// Recorded under Revenues section.
  bool collectStaffAdvance({
    required StaffModel staff,
    required String originalCurrency,
    required String collectedCurrency,
    required double collectedAmount,
    required double deductedAmount,
    double exchangeRate = 1.0,
    String note = '',
  }) {
    final origC = AppCurrency.normalize(originalCurrency);
    final collC = AppCurrency.normalize(collectedCurrency);
    if (collectedAmount <= 0.0001 || deductedAmount <= 0.0001) return false;

    addCash('main', collC, collectedAmount);
    staff.reduceAdvance(origC, deductedAmount);

    advanceRepayments.add(
      AdvanceRepaymentModel(
        id: 'adv_repay_${DateTime.now().microsecondsSinceEpoch}',
        staffId: staff.id,
        staffName: staff.name,
        staffCategory: staff.category,
        originalCurrency: origC,
        collectedCurrency: collC,
        collectedAmount: collectedAmount,
        deductedAmount: deductedAmount,
        exchangeRate: exchangeRate,
        date: DateTime.now(),
        note: note.isNotEmpty
            ? note
            : 'تحصيل سلفة (${staff.category}): ${staff.name}',
      ),
    );

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Outstanding balance of a project across its invoices, per currency.
  double projectDueOf(String projectId, String? currency) => workshopInvoices
      .where(
        (i) =>
            i.projectId == projectId &&
            i.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (s, i) => s + i.remainingBalance);

  // Workshop projects CRUD.
  void addProject(WorkshopProjectModel p) {
    workshopProjects.add(p);
    notifyListeners();
    saveToDisk();
  }

  void deleteProject(String id) {
    workshopProjects.removeWhere((p) => p.id == id);
    notifyListeners();
    saveToDisk();
  }

  /// Outstanding balance of a project across its invoices (legacy: USD).
  double projectDue(String projectId) =>
      projectDueOf(projectId, AppCurrency.usd);
  double projectDueSyp(String projectId) =>
      projectDueOf(projectId, AppCurrency.syp);

  bool projectHasInvoices(String projectId) =>
      workshopInvoices.any((i) => i.projectId == projectId);

  /// Pending: has dues in EITHER currency or no invoices yet.
  /// Completed: invoiced & fully paid in BOTH currencies.
  List<WorkshopProjectModel> get pendingProjects => workshopProjects
      .where(
        (p) =>
            projectDue(p.id) > 0.01 ||
            projectDueSyp(p.id) > 0.01 ||
            !projectHasInvoices(p.id),
      )
      .toList();

  List<WorkshopProjectModel> get completedProjects => workshopProjects
      .where(
        (p) =>
            projectHasInvoices(p.id) &&
            projectDue(p.id) <= 0.01 &&
            projectDueSyp(p.id) <= 0.01,
      )
      .toList();

  // 12. Add Inline Entities
  /// Checks whether a person name already exists in Suppliers or Clients (case-insensitive & trimmed).
  bool isPersonNameExists(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final inSuppliers = suppliers.any((s) => s.name.trim().toLowerCase() == clean);
    final inClients = clients.any((c) => c.name.trim().toLowerCase() == clean);
    return inSuppliers || inClients;
  }

  bool addSupplier(SupplierModel s) {
    final clean = s.name.trim();
    if (clean.isEmpty) return false;
    if (isPersonNameExists(clean)) return false;
    suppliers.add(s);
    notifyListeners();
    saveToDisk();
    return true;
  }

  bool addClient(ClientModel c) {
    final clean = c.name.trim();
    if (clean.isEmpty) return false;
    if (isPersonNameExists(clean)) return false;
    clients.add(c);
    notifyListeners();
    saveToDisk();
    return true;
  }

  void addBlockType(BlockTypeModel bt) {
    blockTypes.add(bt);
    notifyListeners();
    saveToDisk();
  }

  void updateBlockType(BlockTypeModel updated) {
    final index = blockTypes.indexWhere((type) => type.id == updated.id);
    if (index < 0) throw StateError('Block type was not found.');
    final previous = blockTypes[index];
    blockTypes[index] = updated;

    // Cascade name/grade/granite changes to blocks in stock
    for (var i = 0; i < factoryBlocks.length; i++) {
      final block = factoryBlocks[i];
      if (block.typeName == previous.typeName && block.grade == previous.grade) {
        factoryBlocks[i] = FactoryBlockModel(
          id: block.id,
          blockCode: block.blockCode,
          typeName: updated.typeName,
          grade: updated.grade,
          supplierId: block.supplierId,
          supplierName: block.supplierName,
          weightTons: block.weightTons,
          tonCost: block.tonCost,
          tonSellingPrice: block.tonSellingPrice,
          isGranite: updated.isGranite,
        );
      }
    }

    // Also cascade to matching meterTypes entry if exists
    final meterIdx = meterTypes.indexWhere((mt) =>
        mt.typeName == previous.typeName && mt.grade == previous.grade);
    if (meterIdx >= 0) {
      final prevMt = meterTypes[meterIdx];
      meterTypes[meterIdx] = MeterTypeModel(
        id: prevMt.id,
        typeName: updated.typeName,
        grade: updated.grade,
        thicknessCm: prevMt.thicknessCm,
        category: prevMt.category,
        isGranite: updated.isGranite,
      );
    }

    notifyListeners();
    saveToDisk();
  }

  void addMeterType(MeterTypeModel mt) {
    meterTypes.add(mt);
    notifyListeners();
    saveToDisk();
  }

  void updateMeterType(MeterTypeModel updated) {
    final index = meterTypes.indexWhere((type) => type.id == updated.id);
    if (index < 0) throw StateError('Meter type was not found.');
    final previous = meterTypes[index];
    meterTypes[index] = updated;
    for (var i = 0; i < factoryWarehouse.length; i++) {
      final item = factoryWarehouse[i];
      if (item.typeName == previous.typeName && item.grade == previous.grade) {
        factoryWarehouse[i] = FactoryWarehouseModel(
          id: item.id,
          typeName: updated.typeName,
          grade: updated.grade,
          thicknessCm: updated.thicknessCm,
          category: updated.category,
          availableQty: item.availableQty,
          netCostPerUnit: item.netCostPerUnit,
          recommendedSalePrice: item.recommendedSalePrice,
          isGranite: updated.isGranite,
        );
      }
    }
    for (var i = 0; i < workshopStock.length; i++) {
      final item = workshopStock[i];
      if (item.typeName == previous.typeName && item.grade == previous.grade) {
        workshopStock[i] = WorkshopStockModel(
          id: item.id,
          typeName: updated.typeName,
          grade: updated.grade,
          thicknessCm: updated.thicknessCm,
          category: updated.category,
          availableQty: item.availableQty,
          netCostPerUnit: item.netCostPerUnit,
          recommendedSalePrice: item.recommendedSalePrice,
          isGranite: updated.isGranite,
        );
      }
    }
    refresh();
  }

  void addService(ServiceItemModel srv) {
    services.add(srv);
    notifyListeners();
    saveToDisk();
  }

  void addStaff(StaffModel stf) {
    if (stf.name.trim().isEmpty) {
      throw ArgumentError('Staff name cannot be empty.');
    }
    staffList.add(stf);
    notifyListeners();
    saveToDisk();
  }

  // -------------------------------------------------------------
  // SYSTEM FACTORY RESET & DATA WIPER
  // -------------------------------------------------------------
  /// Destructive: wipes every operational table, resets all cash registers
  /// and resets the Opening Entry back to an unlocked, blank state.
  /// Mirrors a fresh installation. Cannot be undone.
  Future<void> systemFactoryReset() async {
    // 1. Truncate operational tables (lists cleared -> auto-increment
    //    sequences restart from 1 since lengths reset to zero).
    suppliers.clear();
    clients.clear();
    blockTypes.clear();
    meterTypes.clear();
    factoryBlocks.clear();
    factoryWarehouse.clear();
    cuttingOperations.clear();
    factoryInvoices.clear();
    factoryOrders.clear();
    workshopStock.clear();
    simpleTailorings.clear();
    complexTailorings.clear();
    scrapItems.clear();
    surplusCosts.clear();
    wasteLogs.clear();
    workshopOrders.clear();
    workshopInvoices.clear();
    services.clear();
    staffTypes.clear();
    staffList.clear();
    staffAttendance.clear();
    workdayEntries.clear();
    activeWorkweekStart = _startOfWorkweek(DateTime.now());
    workshopProjects.clear();
    returnInvoices.clear();
    expenseTypes.clear();
    expenseRecords.clear();
    adjustmentInvoices.clear();
    dailyReports.clear();
    advanceRepayments.clear();

    // 2. Reset isolated cash registers (both USD and SYP funds).
    mainCashBox = 0.0;
    scrapCashBox = 0.0;
    orderCashBox = 0.0;
    mainCashBoxSyp = 0.0;
    scrapCashBoxSyp = 0.0;
    orderCashBoxSyp = 0.0;
    unallocatedFactoryCollectionsUsd = 0.0;
    unallocatedFactoryCollectionsSyp = 0.0;
    unallocatedWorkshopCollectionsUsd = 0.0;
    unallocatedWorkshopCollectionsSyp = 0.0;

    // 3. Reset partner capital & withdrawals (keep identities/ratios so the
    //    equity engine stays stable and the user can rebuild the balance sheet).
    partners = [
      PartnerModel(
        id: 'p1',
        name: 'الشريك حسان',
        ratio: 0.42,
        injectedCapital: 0.0,
      ),
      PartnerModel(
        id: 'p2',
        name: 'الشريك عدنان',
        ratio: 0.35,
        injectedCapital: 0.0,
      ),
      PartnerModel(
        id: 'p3',
        name: 'الشريك عبد المعين',
        ratio: 0.23,
        injectedCapital: 0.0,
      ),
    ];

    // 4. Reset Opening Entry to a blank slate and UNLOCK it
    //    (is_opening_entry_completed = false).
    openingEntry = OpeningEntryModel(
      landValue: 0.0,
      buildingsValue: 0.0,
      machineryValue: 0.0,
      vehiclesValue: 0.0,
      mainCashValue: 0.0,
      scrapCashValue: 0.0,
      orderCashValue: 0.0,
      mainCashValueSyp: 0.0,
      scrapCashValueSyp: 0.0,
      orderCashValueSyp: 0.0,
      inventoryValue: 0.0,
      customerDebtsValue: 0.0,
      supplierPayablesValue: 0.0,
      workerSalariesValue: 0.0,
      hassanRatio: 0.42,
      adnanRatio: 0.35,
      abdelMoeenRatio: 0.23,
      isLocked: false,
      lockedAt: null,
    );
    isOpeningEntryCompleted = false;

    // 5. Purge all cached local persistence.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // 6. Purge locally uploaded temporary files / photos.
    await _purgeTempUploads();

    // 7. Re-persist the clean baseline.
    await saveToDisk();

    // 8. Signal the UI to redirect to the Opening Entry screen.
    factoryResetTick++;
    notifyListeners();
  }

  Future<void> _purgeTempUploads() async {
    try {
      final tempDir = Directory.systemTemp;
      if (!await tempDir.exists()) return;
      await for (final entity in tempDir.list()) {
        final path = entity.path.toLowerCase();
        if (path.contains('marble_granite_erp') ||
            path.contains('erp_uploads') ||
            path.contains('erp_photos') ||
            path.contains('erp_receipts')) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // LOCAL STORAGE (SharedPreferences JSON Persistence)
  // -------------------------------------------------------------
  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('opening_entry', jsonEncode(openingEntry.toJson()));
      await prefs.setString(
        'partners',
        jsonEncode(partners.map((p) => p.toJson()).toList()),
      );
      await prefs.setDouble('mainCashBox', mainCashBox);
      await prefs.setDouble('scrapCashBox', scrapCashBox);
      await prefs.setDouble('orderCashBox', orderCashBox);
      await prefs.setDouble('mainCashBoxSyp', mainCashBoxSyp);
      await prefs.setDouble('scrapCashBoxSyp', scrapCashBoxSyp);
      await prefs.setDouble('orderCashBoxSyp', orderCashBoxSyp);
      await prefs.setString(
        'suppliers',
        jsonEncode(suppliers.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'clients',
        jsonEncode(clients.map((c) => c.toJson()).toList()),
      );
      await prefs.setString(
        'blockTypes',
        jsonEncode(blockTypes.map((b) => b.toJson()).toList()),
      );
      await prefs.setString(
        'meterTypes',
        jsonEncode(meterTypes.map((m) => m.toJson()).toList()),
      );
      await prefs.setString(
        'factoryBlocks',
        jsonEncode(factoryBlocks.map((b) => b.toJson()).toList()),
      );
      await prefs.setString(
        'factoryWarehouse',
        jsonEncode(factoryWarehouse.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'factoryInvoices',
        jsonEncode(factoryInvoices.map((invoice) => invoice.toJson()).toList()),
      );
      await prefs.setString(
        'workshopInvoices',
        jsonEncode(
          workshopInvoices.map((invoice) => invoice.toJson()).toList(),
        ),
      );
      await prefs.setString(
        'workshopStock',
        jsonEncode(workshopStock.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'simpleTailorings',
        jsonEncode(simpleTailorings.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'complexTailorings',
        jsonEncode(complexTailorings.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'scrapItems',
        jsonEncode(scrapItems.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'surplusCosts',
        jsonEncode(surplusCosts.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'wasteLogs',
        jsonEncode(wasteLogs.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'workshopOrders',
        jsonEncode(workshopOrders.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'factoryOrders',
        jsonEncode(factoryOrders.map((o) => o.toJson()).toList()),
      );
      await prefs.setString(
        'workshopProjects',
        jsonEncode(workshopProjects.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        'staffTypes',
        jsonEncode(staffTypes.map((type) => type.toJson()).toList()),
      );
      await prefs.setString(
        'staffList',
        jsonEncode(staffList.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'staffAttendance',
        jsonEncode(staffAttendance.map((entry) => entry.toJson()).toList()),
      );
      await prefs.setString(
        'workdayEntries',
        jsonEncode(workdayEntries.map((entry) => entry.toJson()).toList()),
      );
      await prefs.setString(
        'activeWorkweekStart',
        activeWorkweekStart.toIso8601String(),
      );
      await prefs.setString(
        'services',
        jsonEncode(services.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'expenseTypes',
        jsonEncode(expenseTypes.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'expenseRecords',
        jsonEncode(expenseRecords.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'assetSaleRecords',
        jsonEncode(assetSaleRecords.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'capitalInjections',
        jsonEncode(capitalInjections.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'advanceRepayments',
        jsonEncode(advanceRepayments.map((a) => a.toJson()).toList()),
      );
      await prefs.setString(
        'adjustmentInvoices',
        jsonEncode(adjustmentInvoices.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'centerInfo',
        jsonEncode(centerInfo.toJson()),
      );
      await prefs.setDouble(
        'graniteAccountantPercentage',
        graniteAccountantPercentage,
      );
      await prefs.setString(
        'accountantWithdrawals',
        jsonEncode(accountantWithdrawals.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'cuttingOperations',
        jsonEncode(cuttingOperations.map((c) => c.toJson()).toList()),
      );
      await prefs.setString(
        'returnInvoices',
        jsonEncode(returnInvoices.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        'dailyReports',
        jsonEncode(dailyReports.map((r) => r.toJson()).toList()),
      );
      await prefs.setDouble(
        'unallocatedFactoryCollectionsUsd',
        unallocatedFactoryCollectionsUsd,
      );
      await prefs.setDouble(
        'unallocatedFactoryCollectionsSyp',
        unallocatedFactoryCollectionsSyp,
      );
      await prefs.setDouble(
        'unallocatedWorkshopCollectionsUsd',
        unallocatedWorkshopCollectionsUsd,
      );
      await prefs.setDouble(
        'unallocatedWorkshopCollectionsSyp',
        unallocatedWorkshopCollectionsSyp,
      );
    } catch (_) {}
  }

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final openingStr = prefs.getString('opening_entry');
      if (openingStr != null) {
        openingEntry = OpeningEntryModel.fromJson(jsonDecode(openingStr));
        isOpeningEntryCompleted = openingEntry.isLocked;
      }
      final centerInfoJson = prefs.getString('centerInfo');
      if (centerInfoJson != null) {
        try {
          centerInfo = CenterInfoModel.fromJson(jsonDecode(centerInfoJson));
        } catch (_) {}
      }
      final partnersJson = prefs.getString('partners');
      if (partnersJson != null) {
        partners = (jsonDecode(partnersJson) as List)
            .map((item) => PartnerModel.fromJson(item))
            .toList();
      }
      final suppliersJson = prefs.getString('suppliers');
      if (suppliersJson != null) {
        suppliers = (jsonDecode(suppliersJson) as List)
            .map((item) => SupplierModel.fromJson(item))
            .toList();
      }
      final clientsJson = prefs.getString('clients');
      if (clientsJson != null) {
        clients = (jsonDecode(clientsJson) as List)
            .map((item) => ClientModel.fromJson(item))
            .toList();
      }
      final blockTypesJson = prefs.getString('blockTypes');
      if (blockTypesJson != null) {
        blockTypes = (jsonDecode(blockTypesJson) as List)
            .map((item) => BlockTypeModel.fromJson(item))
            .toList();
      }
      final meterTypesJson = prefs.getString('meterTypes');
      if (meterTypesJson != null) {
        meterTypes = (jsonDecode(meterTypesJson) as List)
            .map((item) => MeterTypeModel.fromJson(item))
            .toList();
      }
      final factoryBlocksJson = prefs.getString('factoryBlocks');
      if (factoryBlocksJson != null) {
        factoryBlocks = (jsonDecode(factoryBlocksJson) as List)
            .map((item) => FactoryBlockModel.fromJson(item))
            .toList();
      }
      final factoryWarehouseJson = prefs.getString('factoryWarehouse');
      if (factoryWarehouseJson != null) {
        factoryWarehouse = (jsonDecode(factoryWarehouseJson) as List)
            .map((item) => FactoryWarehouseModel.fromJson(item))
            .toList();
      }
      final cuttingOpsJson = prefs.getString('cuttingOperations');
      if (cuttingOpsJson != null) {
        try {
          cuttingOperations = (jsonDecode(cuttingOpsJson) as List)
              .map((item) => CuttingOperationModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final factoryInvoicesJson = prefs.getString('factoryInvoices');
      if (factoryInvoicesJson != null) {
        factoryInvoices = (jsonDecode(factoryInvoicesJson) as List)
            .map((item) => FactoryInvoiceModel.fromJson(item))
            .toList();
      }
      final workshopInvoicesJson = prefs.getString('workshopInvoices');
      if (workshopInvoicesJson != null) {
        workshopInvoices = (jsonDecode(workshopInvoicesJson) as List)
            .map((item) => WorkshopInvoiceModel.fromJson(item))
            .toList();
      }

      // Sync customer currency classifications from invoices if not explicitly stored
      for (final client in clients) {
        final facInvs = factoryInvoices
            .where((i) => i.partyId == client.id || i.partyName.trim() == client.name.trim())
            .toList();
        final wrkInvs = workshopInvoices
            .where((i) => i.clientName.trim() == client.name.trim())
            .toList();
        if (facInvs.isNotEmpty) {
          client.currencyClassification = facInvs.last.currency;
        } else if (wrkInvs.isNotEmpty) {
          client.currencyClassification = wrkInvs.last.currency;
        }
      }
      final workshopProjectsJson = prefs.getString('workshopProjects');
      if (workshopProjectsJson != null) {
        try {
          workshopProjects = (jsonDecode(workshopProjectsJson) as List)
              .map((item) => WorkshopProjectModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final workshopOrdersJson = prefs.getString('workshopOrders');
      if (workshopOrdersJson != null) {
        try {
          workshopOrders = (jsonDecode(workshopOrdersJson) as List)
              .map((item) => WorkshopOrderModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final factoryOrdersJson = prefs.getString('factoryOrders');
      if (factoryOrdersJson != null) {
        try {
          factoryOrders = (jsonDecode(factoryOrdersJson) as List)
              .map((item) => FactoryOrderModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final servicesJson = prefs.getString('services');
      if (servicesJson != null) {
        try {
          services = (jsonDecode(servicesJson) as List)
              .map((item) => ServiceItemModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final wasteLogsJson = prefs.getString('wasteLogs');
      if (wasteLogsJson != null) {
        try {
          wasteLogs = (jsonDecode(wasteLogsJson) as List)
              .map((item) => WasteLogModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final workshopStockJson = prefs.getString('workshopStock');
      if (workshopStockJson != null) {
        workshopStock = (jsonDecode(workshopStockJson) as List)
            .map((item) => WorkshopStockModel.fromJson(item))
            .toList();
      }
      final simpleTailoringsJson = prefs.getString('simpleTailorings');
      if (simpleTailoringsJson != null) {
        simpleTailorings = (jsonDecode(simpleTailoringsJson) as List)
            .map((item) => WorkshopTailoringModel.fromJson(item))
            .toList();
      }
      final complexTailoringsJson = prefs.getString('complexTailorings');
      if (complexTailoringsJson != null) {
        complexTailorings = (jsonDecode(complexTailoringsJson) as List)
            .map((item) => WorkshopTailoringModel.fromJson(item))
            .toList();
      }
      final returnInvoicesJson = prefs.getString('returnInvoices');
      if (returnInvoicesJson != null) {
        try {
          returnInvoices = (jsonDecode(returnInvoicesJson) as List)
              .map((item) => ReturnInvoiceModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final expenseTypesJson = prefs.getString('expenseTypes');
      if (expenseTypesJson != null) {
        expenseTypes = (jsonDecode(expenseTypesJson) as List)
            .map((item) => ExpenseTypeModel.fromJson(item))
            .toList();
      }
      final expenseRecordsJson = prefs.getString('expenseRecords');
      if (expenseRecordsJson != null) {
        expenseRecords = (jsonDecode(expenseRecordsJson) as List)
            .map((item) => ExpenseRecordModel.fromJson(item))
            .toList();
      }
      final assetSaleRecordsJson = prefs.getString('assetSaleRecords');
      if (assetSaleRecordsJson != null) {
        try {
          assetSaleRecords = (jsonDecode(assetSaleRecordsJson) as List)
              .map((item) => AssetSaleRecordModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final capitalInjectionsJson = prefs.getString('capitalInjections');
      if (capitalInjectionsJson != null) {
        try {
          capitalInjections = (jsonDecode(capitalInjectionsJson) as List)
              .map((item) => CapitalInjectionRecordModel.fromJson(item))
              .toList();
        } catch (_) {}
      }
      final soldLegacy = openingEntry.fixedAssets.where((a) => a.isSold).toList();
      for (final a in soldLegacy) {
        if (!assetSaleRecords.any((r) => r.assetId == a.id)) {
          assetSaleRecords.add(
            AssetSaleRecordModel(
              id: 'legacy_sale_${a.id}',
              assetId: a.id,
              assetName: a.name,
              category: a.category,
              registeredPrice: a.amount,
              salePrice: a.saleAmount > 0 ? a.saleAmount : a.amount,
              currency: a.currency,
              saleDate: DateTime.now(),
              description: a.description,
            ),
          );
        }
      }
      openingEntry.fixedAssets.removeWhere((a) => a.isSold);
      final advanceRepaymentsJson = prefs.getString('advanceRepayments');
      if (advanceRepaymentsJson != null) {
        advanceRepayments = (jsonDecode(advanceRepaymentsJson) as List)
            .map((item) => AdvanceRepaymentModel.fromJson(item))
            .toList();
      }
      final adjustmentInvoicesJson = prefs.getString('adjustmentInvoices');
      if (adjustmentInvoicesJson != null) {
        adjustmentInvoices = (jsonDecode(adjustmentInvoicesJson) as List)
            .map((item) => AdjustmentInvoiceModel.fromJson(item))
            .toList();
      }
      final staffTypesJson = prefs.getString('staffTypes');
      if (staffTypesJson != null) {
        staffTypes = (jsonDecode(staffTypesJson) as List)
            .map((item) => StaffTypeModel.fromJson(item))
            .toList();
      }
      final staffListJson = prefs.getString('staffList');
      if (staffListJson != null) {
        staffList = (jsonDecode(staffListJson) as List)
            .map((item) => StaffModel.fromJson(item))
            .toList();
        for (final staff in staffList) {
          if (staff.category != 'معلمين' && staff.typeId.isEmpty) {
            final matchingTypes = staffTypes.where(
              (type) => type.category == staff.category,
            );
            if (matchingTypes.isNotEmpty) {
              staff.typeId = matchingTypes.first.id;
            }
          }
        }
      }
      final staffAttendanceJson = prefs.getString('staffAttendance');
      if (staffAttendanceJson != null) {
        staffAttendance = (jsonDecode(staffAttendanceJson) as List)
            .map((item) => StaffAttendanceModel.fromJson(item))
            .toList();
      }
      final workdayEntriesJson = prefs.getString('workdayEntries');
      if (workdayEntriesJson != null) {
        workdayEntries = (jsonDecode(workdayEntriesJson) as List)
            .map((item) => WorkdayEntryModel.fromJson(item))
            .toList();
      }
      final activeWeek = prefs.getString('activeWorkweekStart');
      if (activeWeek != null) {
        activeWorkweekStart = DateTime.parse(activeWeek);
      }
      final mainCash = prefs.getDouble('mainCashBox');
      if (mainCash != null) mainCashBox = mainCash;

      final scrapCash = prefs.getDouble('scrapCashBox');
      if (scrapCash != null) scrapCashBox = scrapCash;

      final orderCash = prefs.getDouble('orderCashBox');
      if (orderCash != null) orderCashBox = orderCash;

      final mainCashSyp = prefs.getDouble('mainCashBoxSyp');
      if (mainCashSyp != null) mainCashBoxSyp = mainCashSyp;
      final scrapCashSyp = prefs.getDouble('scrapCashBoxSyp');
      if (scrapCashSyp != null) scrapCashBoxSyp = scrapCashSyp;
      final orderCashSyp = prefs.getDouble('orderCashBoxSyp');
      if (orderCashSyp != null) orderCashBoxSyp = orderCashSyp;

      final uFacUsd = prefs.getDouble('unallocatedFactoryCollectionsUsd');
      if (uFacUsd != null) unallocatedFactoryCollectionsUsd = uFacUsd;
      final uFacSyp = prefs.getDouble('unallocatedFactoryCollectionsSyp');
      if (uFacSyp != null) unallocatedFactoryCollectionsSyp = uFacSyp;
      final uWrkUsd = prefs.getDouble('unallocatedWorkshopCollectionsUsd');
      if (uWrkUsd != null) unallocatedWorkshopCollectionsUsd = uWrkUsd;
      final uWrkSyp = prefs.getDouble('unallocatedWorkshopCollectionsSyp');
      if (uWrkSyp != null) unallocatedWorkshopCollectionsSyp = uWrkSyp;

      final surplusStr = prefs.getString('surplusCosts');
      if (surplusStr != null) {
        try {
          surplusCosts = (jsonDecode(surplusStr) as List)
              .map((e) => SurplusCostModel.fromJson(e))
              .toList();
        } catch (_) {}
      }
      final scrapStr = prefs.getString('scrapItems');
      if (scrapStr != null) {
        try {
          scrapItems = (jsonDecode(scrapStr) as List)
              .map((e) => ScrapItemModel.fromJson(e))
              .toList();
        } catch (_) {}
      }

      final pct = prefs.getDouble('graniteAccountantPercentage');
      if (pct != null) graniteAccountantPercentage = pct;

      final accWithStr = prefs.getString('accountantWithdrawals');
      if (accWithStr != null) {
        try {
          accountantWithdrawals = (jsonDecode(accWithStr) as List)
              .map((e) => AccountantWithdrawalModel.fromJson(e))
              .toList();
        } catch (_) {}
      }

      final dailyReportsJson = prefs.getString('dailyReports');
      if (dailyReportsJson != null) {
        try {
          dailyReports = (jsonDecode(dailyReportsJson) as List)
              .map((item) => DailyReportModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        } catch (_) {}
      }

      if (openingEntry.isLocked &&
          openingEntry.openingStock.isNotEmpty &&
          !openingEntry.openingStockApplied) {
        _applyOpeningStockToOperationalInventory();
        await saveToDisk();
      }
      notifyListeners();
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // COMPREHENSIVE BACKUP & RESTORE SYSTEM
  // -------------------------------------------------------------

  /// Exports 100% of the entire ERP software data into a structured backup map.
  Map<String, dynamic> exportFullBackupData() {
    return {
      'metadata': {
        'systemName': 'Abaad ERP (برنامج أبعاد)',
        'systemIdentifier': 'abaad_marble_granite_erp',
        'backupVersion': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'centerName': centerInfo.centerName,
        'centerPhone': centerInfo.phone1,
        'graniteAccountantPercentage': graniteAccountantPercentage,
      },
      'financials': {
        'mainCashBox': mainCashBox,
        'scrapCashBox': scrapCashBox,
        'orderCashBox': orderCashBox,
        'mainCashBoxSyp': mainCashBoxSyp,
        'scrapCashBoxSyp': scrapCashBoxSyp,
        'orderCashBoxSyp': orderCashBoxSyp,
        'graniteAccountantPercentage': graniteAccountantPercentage,
        'accountantWithdrawals':
            accountantWithdrawals.map((w) => w.toJson()).toList(),
        'partners': partners.map((p) => p.toJson()).toList(),
        'openingEntry': openingEntry.toJson(),
        'assetSaleRecords': assetSaleRecords.map((w) => w.toJson()).toList(),
        'capitalInjections':
            capitalInjections.map((w) => w.toJson()).toList(),
      },
      'factory': {
        'suppliers': suppliers.map((s) => s.toJson()).toList(),
        'clients': clients.map((c) => c.toJson()).toList(),
        'blockTypes': blockTypes.map((b) => b.toJson()).toList(),
        'meterTypes': meterTypes.map((m) => m.toJson()).toList(),
        'factoryBlocks': factoryBlocks.map((b) => b.toJson()).toList(),
        'factoryWarehouse': factoryWarehouse.map((w) => w.toJson()).toList(),
        'cuttingOperations':
            cuttingOperations.map((c) => c.toJson()).toList(),
        'factoryInvoices': factoryInvoices.map((inv) => inv.toJson()).toList(),
        'factoryOrders': factoryOrders.map((o) => o.toJson()).toList(),
      },
      'workshop': {
        'workshopStock': workshopStock.map((w) => w.toJson()).toList(),
        'simpleTailorings': simpleTailorings.map((t) => t.toJson()).toList(),
        'complexTailorings': complexTailorings.map((t) => t.toJson()).toList(),
        'scrapItems': scrapItems.map((s) => s.toJson()).toList(),
        'surplusCosts': surplusCosts.map((s) => s.toJson()).toList(),
        'wasteLogs': wasteLogs.map((w) => w.toJson()).toList(),
        'workshopOrders': workshopOrders.map((o) => o.toJson()).toList(),
        'workshopInvoices':
            workshopInvoices.map((inv) => inv.toJson()).toList(),
        'workshopProjects':
            workshopProjects.map((p) => p.toJson()).toList(),
      },
      'staff': {
        'staffTypes': staffTypes.map((t) => t.toJson()).toList(),
        'staffList': staffList.map((s) => s.toJson()).toList(),
        'staffAttendance': staffAttendance.map((a) => a.toJson()).toList(),
        'workdayEntries': workdayEntries.map((w) => w.toJson()).toList(),
        'activeWorkweekStart': activeWorkweekStart.toIso8601String(),
      },
      'operations': {
        'returnInvoices': returnInvoices.map((r) => r.toJson()).toList(),
        'expenseTypes': expenseTypes.map((e) => e.toJson()).toList(),
        'expenseRecords': expenseRecords.map((e) => e.toJson()).toList(),
        'advanceRepayments':
            advanceRepayments.map((a) => a.toJson()).toList(),
        'adjustmentInvoices':
            adjustmentInvoices.map((a) => a.toJson()).toList(),
        'services': services.map((s) => s.toJson()).toList(),
        'dailyReports': dailyReports.map((d) => d.toJson()).toList(),
      },
      'centerInfo': centerInfo.toJson(),
    };
  }

  /// Restores and distributes all data back to its correct places across all screens and sections.
  Future<Map<String, dynamic>> importFullBackupData(
      Map<String, dynamic> raw) async {
    // 1. Resolve sections with fallback to root keys if present
    final fin = (raw['financials'] is Map)
        ? raw['financials'] as Map<String, dynamic>
        : raw;
    final fac = (raw['factory'] is Map)
        ? raw['factory'] as Map<String, dynamic>
        : raw;
    final wrk = (raw['workshop'] is Map)
        ? raw['workshop'] as Map<String, dynamic>
        : raw;
    final stf = (raw['staff'] is Map)
        ? raw['staff'] as Map<String, dynamic>
        : raw;
    final ops = (raw['operations'] is Map)
        ? raw['operations'] as Map<String, dynamic>
        : raw;

    // Financials
    if (fin['openingEntry'] != null) {
      try {
        openingEntry = OpeningEntryModel.fromJson(
            Map<String, dynamic>.from(fin['openingEntry']));
        isOpeningEntryCompleted = openingEntry.isLocked;
      } catch (_) {}
    }
    if (fin['partners'] is List) {
      partners = (fin['partners'] as List)
          .map((item) => PartnerModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fin['mainCashBox'] != null) {
      mainCashBox = (fin['mainCashBox'] as num).toDouble();
    }
    if (fin['scrapCashBox'] != null) {
      scrapCashBox = (fin['scrapCashBox'] as num).toDouble();
    }
    if (fin['orderCashBox'] != null) {
      orderCashBox = (fin['orderCashBox'] as num).toDouble();
    }
    if (fin['mainCashBoxSyp'] != null) {
      mainCashBoxSyp = (fin['mainCashBoxSyp'] as num).toDouble();
    }
    if (fin['scrapCashBoxSyp'] != null) {
      scrapCashBoxSyp = (fin['scrapCashBoxSyp'] as num).toDouble();
    }
    if (fin['orderCashBoxSyp'] != null) {
      orderCashBoxSyp = (fin['orderCashBoxSyp'] as num).toDouble();
    }
    if (fin['graniteAccountantPercentage'] != null) {
      graniteAccountantPercentage =
          (fin['graniteAccountantPercentage'] as num).toDouble();
    }
    if (fin['accountantWithdrawals'] is List) {
      accountantWithdrawals = (fin['accountantWithdrawals'] as List)
          .map((item) => AccountantWithdrawalModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fin['assetSaleRecords'] is List) {
      assetSaleRecords = (fin['assetSaleRecords'] as List)
          .map((item) => AssetSaleRecordModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fin['capitalInjections'] is List) {
      capitalInjections = (fin['capitalInjections'] as List)
          .map((item) => CapitalInjectionRecordModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    }

    // Factory
    if (fac['suppliers'] is List) {
      suppliers = (fac['suppliers'] as List)
          .map((item) => SupplierModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['clients'] is List) {
      clients = (fac['clients'] as List)
          .map((item) => ClientModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['blockTypes'] is List) {
      blockTypes = (fac['blockTypes'] as List)
          .map((item) => BlockTypeModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['meterTypes'] is List) {
      meterTypes = (fac['meterTypes'] as List)
          .map((item) => MeterTypeModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['factoryBlocks'] is List) {
      factoryBlocks = (fac['factoryBlocks'] as List)
          .map((item) =>
              FactoryBlockModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['factoryWarehouse'] is List) {
      factoryWarehouse = (fac['factoryWarehouse'] as List)
          .map((item) =>
              FactoryWarehouseModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['cuttingOperations'] is List) {
      cuttingOperations = (fac['cuttingOperations'] as List)
          .map((item) =>
              CuttingOperationModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['factoryInvoices'] is List) {
      factoryInvoices = (fac['factoryInvoices'] as List)
          .map((item) =>
              FactoryInvoiceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (fac['factoryOrders'] is List) {
      factoryOrders = (fac['factoryOrders'] as List)
          .map((item) =>
              FactoryOrderModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Workshop
    if (wrk['workshopStock'] is List) {
      workshopStock = (wrk['workshopStock'] as List)
          .map((item) =>
              WorkshopStockModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['simpleTailorings'] is List) {
      simpleTailorings = (wrk['simpleTailorings'] as List)
          .map((item) =>
              WorkshopTailoringModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['complexTailorings'] is List) {
      complexTailorings = (wrk['complexTailorings'] as List)
          .map((item) =>
              WorkshopTailoringModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['scrapItems'] is List) {
      scrapItems = (wrk['scrapItems'] as List)
          .map((item) => ScrapItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['surplusCosts'] is List) {
      surplusCosts = (wrk['surplusCosts'] as List)
          .map((item) =>
              SurplusCostModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['wasteLogs'] is List) {
      wasteLogs = (wrk['wasteLogs'] as List)
          .map((item) => WasteLogModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['workshopOrders'] is List) {
      workshopOrders = (wrk['workshopOrders'] as List)
          .map((item) =>
              WorkshopOrderModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['workshopInvoices'] is List) {
      workshopInvoices = (wrk['workshopInvoices'] as List)
          .map((item) =>
              WorkshopInvoiceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (wrk['workshopProjects'] is List) {
      workshopProjects = (wrk['workshopProjects'] as List)
          .map((item) =>
              WorkshopProjectModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Staff
    if (stf['staffTypes'] is List) {
      staffTypes = (stf['staffTypes'] as List)
          .map((item) => StaffTypeModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (stf['staffList'] is List) {
      staffList = (stf['staffList'] as List)
          .map((item) => StaffModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      for (final staff in staffList) {
        if (staff.category != 'معلمين' && staff.typeId.isEmpty) {
          final matchingTypes = staffTypes.where(
            (type) => type.category == staff.category,
          );
          if (matchingTypes.isNotEmpty) {
            staff.typeId = matchingTypes.first.id;
          }
        }
      }
    }
    if (stf['staffAttendance'] is List) {
      staffAttendance = (stf['staffAttendance'] as List)
          .map((item) =>
              StaffAttendanceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (stf['workdayEntries'] is List) {
      workdayEntries = (stf['workdayEntries'] as List)
          .map((item) =>
              WorkdayEntryModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (stf['activeWorkweekStart'] != null) {
      try {
        activeWorkweekStart = DateTime.parse(stf['activeWorkweekStart']);
      } catch (_) {}
    }

    // Operations
    if (ops['returnInvoices'] is List) {
      returnInvoices = (ops['returnInvoices'] as List)
          .map((item) =>
              ReturnInvoiceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['expenseTypes'] is List) {
      expenseTypes = (ops['expenseTypes'] as List)
          .map((item) =>
              ExpenseTypeModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['expenseRecords'] is List) {
      expenseRecords = (ops['expenseRecords'] as List)
          .map((item) =>
              ExpenseRecordModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['advanceRepayments'] is List) {
      advanceRepayments = (ops['advanceRepayments'] as List)
          .map((item) =>
              AdvanceRepaymentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } else if (raw['advanceRepayments'] is List) {
      advanceRepayments = (raw['advanceRepayments'] as List)
          .map((item) =>
              AdvanceRepaymentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['adjustmentInvoices'] is List) {
      adjustmentInvoices = (ops['adjustmentInvoices'] as List)
          .map((item) =>
              AdjustmentInvoiceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['services'] is List) {
      services = (ops['services'] as List)
          .map((item) =>
              ServiceItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (ops['dailyReports'] is List) {
      dailyReports = (ops['dailyReports'] as List)
          .map((item) =>
              DailyReportModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } else if (raw['dailyReports'] is List) {
      dailyReports = (raw['dailyReports'] as List)
          .map((item) =>
              DailyReportModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Settings
    if (raw['centerInfo'] != null) {
      try {
        centerInfo =
            CenterInfoModel.fromJson(Map<String, dynamic>.from(raw['centerInfo']));
      } catch (_) {}
    }

    // Persist to disk immediately
    await saveToDisk();

    // Notify all UI consumers to immediately re-render across all screens
    notifyListeners();

    return {
      'factoryInvoices': factoryInvoices.length,
      'workshopInvoices': workshopInvoices.length,
      'suppliers': suppliers.length,
      'clients': clients.length,
      'factoryBlocks': factoryBlocks.length,
      'factoryWarehouse': factoryWarehouse.length,
      'cuttingOperations': cuttingOperations.length,
      'workshopProjects': workshopProjects.length,
      'staffList': staffList.length,
      'dailyReports': dailyReports.length,
      'totalCashUsd': mainCashBox + scrapCashBox + orderCashBox,
      'totalCashSyp': mainCashBoxSyp + scrapCashBoxSyp + orderCashBoxSyp,
      'openingEntryStatus': openingEntry.isLocked ? 'معتمد ومرحل' : 'مسودة',
      'openingFixedAssets': openingEntry.fixedAssets.length,
      'openingStockItems': openingEntry.openingStock.length,
    };
  }

  // -------------------------------------------------------------
  // DAILY REPORT COMPILATION & GENERATION
  // -------------------------------------------------------------

  /// Compiles all transactions, invoices, expenses, cash movements, and stats
  /// for a specific target day into a comprehensive [DailyReportModel].
  DailyReportModel compileDailyReportForDate(DateTime targetDate, {String? notes}) {
    bool sameDay(DateTime d) =>
        d.year == targetDate.year &&
        d.month == targetDate.month &&
        d.day == targetDate.day;

    final dateStr = intl.DateFormat('yyyyMMdd').format(targetDate);
    final count = dailyReports.where((r) => sameDay(r.reportDate)).length + 1;
    final reportNo = 'DREP-$dateStr-${count.toString().padLeft(2, '0')}';

    final List<DailyReportInvoiceSummary> sales = [];
    final List<DailyReportInvoiceSummary> purchases = [];
    final List<DailyReportInvoiceSummary> returns = [];
    final List<DailyReportExpenseSummary> exps = [];
    final List<DailyReportCashMovementSummary> movements = [];

    double totalSalesUsd = 0.0;
    double totalSalesSyp = 0.0;
    double totalPurchasesUsd = 0.0;
    double totalPurchasesSyp = 0.0;
    double totalExpensesUsd = 0.0;
    double totalExpensesSyp = 0.0;
    double totalCashInUsd = 0.0;
    double totalCashInSyp = 0.0;
    double totalCashOutUsd = 0.0;
    double totalCashOutSyp = 0.0;

    // 1. Factory Invoices
    for (final inv in factoryInvoices.where((i) => sameDay(i.date))) {
      final isSyp = AppCurrency.isSyp(inv.currency);
      final isSales = inv.invoiceType == 'بيع_معتمد';
      final itemsSummary = inv.items
          .map((it) => '${it.description} (${it.quantity.fmt})')
          .join(' • ');

      final entry = DailyReportInvoiceSummary(
        invoiceNo: inv.invoiceNo,
        module: 'المصنع',
        type: isSales ? 'مبيعات' : 'مشتريات',
        paymentType: inv.isCashInvoice ? 'نقدية' : 'آجل',
        partyName: inv.partyName,
        totalAmount: inv.grandTotal,
        paidAmount: inv.advancePayment,
        remainingAmount: inv.remainingBalance,
        currency: inv.currency,
        itemsSummary: itemsSummary,
        time: inv.date,
      );

      if (isSales) {
        sales.add(entry);
        if (isSyp) {
          totalSalesSyp += inv.grandTotal;
          totalCashInSyp += inv.advancePayment;
        } else {
          totalSalesUsd += inv.grandTotal;
          totalCashInUsd += inv.advancePayment;
        }
        if (inv.advancePayment > 0) {
          movements.add(DailyReportCashMovementSummary(
            type: 'قبض مبيعات مصنع',
            description: 'فاتورة #${inv.invoiceNo} - ${entry.partyName}',
            cashBox: 'main',
            amount: inv.advancePayment,
            currency: inv.currency,
            time: inv.date,
          ));
        }
      } else {
        purchases.add(entry);
        if (isSyp) {
          totalPurchasesSyp += inv.grandTotal;
          totalCashOutSyp += inv.advancePayment;
        } else {
          totalPurchasesUsd += inv.grandTotal;
          totalCashOutUsd += inv.advancePayment;
        }
        if (inv.advancePayment > 0) {
          movements.add(DailyReportCashMovementSummary(
            type: 'سداد مشتريات مصنع',
            description: 'فاتورة توريد #${inv.invoiceNo} - ${entry.partyName}',
            cashBox: 'main',
            amount: inv.advancePayment,
            currency: inv.currency,
            time: inv.date,
          ));
        }
      }
    }

    // 2. Workshop Invoices
    for (final inv in workshopInvoices.where((i) => sameDay(i.date))) {
      final isSyp = AppCurrency.isSyp(inv.currency);
      final itemsSummary = inv.items.isNotEmpty
          ? inv.items
              .map((it) => '${it.description} (${it.quantity.fmt} ${it.unitCategory})')
              .join(' • ')
          : (inv.itemDescription.isNotEmpty
              ? '${inv.itemDescription} (${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory})'
              : 'أعمال تفصيل وطلبيات');

      final paidAmt = inv.depositDeducted + inv.cashPaidNow;

      final entry = DailyReportInvoiceSummary(
        invoiceNo: inv.invoiceNo,
        module: 'المعمل',
        type: 'مبيعات',
        paymentType: inv.isCashInvoice ? 'نقدية' : 'آجل',
        partyName: inv.clientName,
        totalAmount: inv.grandTotal,
        paidAmount: paidAmt,
        remainingAmount: inv.remainingBalance,
        currency: inv.currency,
        itemsSummary: itemsSummary,
        time: inv.date,
      );

      sales.add(entry);
      if (isSyp) {
        totalSalesSyp += inv.grandTotal;
        totalCashInSyp += paidAmt;
      } else {
        totalSalesUsd += inv.grandTotal;
        totalCashInUsd += paidAmt;
      }
      if (paidAmt > 0) {
        movements.add(DailyReportCashMovementSummary(
          type: 'قبض مبيعات معمل',
          description: 'فاتورة معمل #${inv.invoiceNo} - ${inv.clientName}',
          cashBox: 'order',
          amount: paidAmt,
          currency: inv.currency,
          time: inv.date,
        ));
      }
    }

    // 3. Return Invoices
    for (final ret in returnInvoices.where((r) => sameDay(r.date))) {
      final isSyp = AppCurrency.isSyp(ret.currency);
      final itemsSummary = '${ret.itemDescription} (${ret.quantity.fmt})';

      final entry = DailyReportInvoiceSummary(
        invoiceNo: ret.returnNo,
        module: ret.returnType,
        type: 'مرتجع',
        paymentType: ret.paymentAction,
        partyName: ret.partyName,
        totalAmount: ret.refundAmount,
        paidAmount: ret.refundAmount,
        remainingAmount: 0.0,
        currency: ret.currency,
        itemsSummary: itemsSummary,
        time: ret.date,
      );
      returns.add(entry);
      // Only cash-settled returns move money. A supplier purchase return
      // brings cash IN to the main safe, a sales return pays cash OUT.
      // Account settlements (تسوية حساب) never touch the cash boxes.
      final cashSettled =
          ret.paymentAction == 'استرداد نقدي للصندوق الرئيسي';
      final cashMoved =
          ret.cashAmount ?? (cashSettled ? ret.refundAmount : 0.0);
      if (cashMoved > 0) {
        final purchaseReturn = ret.returnType == 'مرتجع مشتريات مورد';
        if (purchaseReturn) {
          if (isSyp) {
            totalCashInSyp += cashMoved;
          } else {
            totalCashInUsd += cashMoved;
          }
        } else if (isSyp) {
          totalCashOutSyp += cashMoved;
        } else {
          totalCashOutUsd += cashMoved;
        }
        movements.add(DailyReportCashMovementSummary(
          type: purchaseReturn
              ? 'استرداد مرتجع مشتريات'
              : 'استرداد مرتجع مبيعات',
          description: 'مرتجع #${ret.returnNo} - ${ret.partyName}',
          cashBox: 'main',
          amount: cashMoved,
          currency: ret.currency,
          time: ret.date,
        ));
      }
    }

    // 4. Expense Records
    for (final exp in expenseRecords.where((e) => sameDay(e.date) && !e.isInformational)) {
      final isSyp = AppCurrency.isSyp(exp.currency);
      final catName = expenseTypes
          .firstWhere((t) => t.id == exp.typeId,
              orElse: () => ExpenseTypeModel(id: '', name: 'مصاريف تشغيلية'))
          .name;

      exps.add(DailyReportExpenseSummary(
        category: catName,
        description: exp.description,
        beneficiary: exp.personName,
        amount: exp.amount,
        currency: exp.currency,
        cashBox: 'main',
        time: exp.date,
      ));
      if (isSyp) {
        totalExpensesSyp += exp.amount;
        totalCashOutSyp += exp.amount;
      } else {
        totalExpensesUsd += exp.amount;
        totalCashOutUsd += exp.amount;
      }
      movements.add(DailyReportCashMovementSummary(
        type: 'مصاريف تشغيلية',
        description: '$catName: ${exp.description}',
        cashBox: 'main',
        amount: exp.amount,
        currency: exp.currency,
        time: exp.date,
      ));
    }

    // 5. Accountant Profit Withdrawals
    for (final w in accountantWithdrawals.where((w) => sameDay(w.date))) {
      final isSyp = AppCurrency.isSyp(w.currency);
      if (isSyp) {
        totalCashOutSyp += w.amount;
      } else {
        totalCashOutUsd += w.amount;
      }
      movements.add(DailyReportCashMovementSummary(
        type: 'سحب أرباح محاسب الجرانيت',
        description: w.notes.isNotEmpty ? w.notes : 'سحب أرباح المحاسب',
        cashBox: w.cashBox,
        amount: w.amount,
        currency: w.currency,
        time: w.date,
      ));
    }

    // 6. Surplus Costs (Settled worker wages / general surplus expenses)
    for (final sc in surplusCosts.where((c) => sameDay(c.date) && c.amountPaid > 0)) {
      final isSyp = AppCurrency.isSyp(sc.currency);
      exps.add(DailyReportExpenseSummary(
        category: sc.kind == 'worker' ? 'أجور عمال الفائض' : 'مصاريف الفائض',
        description: '${sc.surplusDescription} - ${sc.beneficiaryName}',
        beneficiary: sc.beneficiaryName,
        amount: sc.amountPaid,
        currency: sc.currency,
        cashBox: 'scrap',
        time: sc.date,
      ));
      if (isSyp) {
        totalExpensesSyp += sc.amountPaid;
        totalCashOutSyp += sc.amountPaid;
      } else {
        totalExpensesUsd += sc.amountPaid;
        totalCashOutUsd += sc.amountPaid;
      }
      movements.add(DailyReportCashMovementSummary(
        type: sc.kind == 'worker' ? 'صرف أجور عمال فائض' : 'مصاريف صندوق الفائض',
        description: '${sc.surplusDescription} - ${sc.beneficiaryName}',
        cashBox: 'scrap',
        amount: sc.amountPaid,
        currency: sc.currency,
        time: sc.date,
      ));
    }

    // 7. Operational Stats
    final cuttingCount =
        cuttingOperations.where((c) => sameDay(c.timestamp)).length;
    final attCount =
        staffAttendance.where((a) => sameDay(a.date)).length;

    final report = DailyReportModel(
      id: 'report_${DateTime.now().microsecondsSinceEpoch}',
      reportNo: reportNo,
      reportDate: targetDate,
      generatedAt: DateTime.now(),
      notes: notes ?? '',
      totalSalesUsd: totalSalesUsd,
      totalSalesSyp: totalSalesSyp,
      totalPurchasesUsd: totalPurchasesUsd,
      totalPurchasesSyp: totalPurchasesSyp,
      totalExpensesUsd: totalExpensesUsd,
      totalExpensesSyp: totalExpensesSyp,
      totalCashInUsd: totalCashInUsd,
      totalCashInSyp: totalCashInSyp,
      totalCashOutUsd: totalCashOutUsd,
      totalCashOutSyp: totalCashOutSyp,
      mainCashUsd: mainCashBox,
      mainCashSyp: mainCashBoxSyp,
      scrapCashUsd: scrapCashBox,
      scrapCashSyp: scrapCashBoxSyp,
      orderCashUsd: orderCashBox,
      orderCashSyp: orderCashBoxSyp,
      salesInvoices: sales,
      purchaseInvoices: purchases,
      returnInvoices: returns,
      expenses: exps,
      cashMovements: movements,
      cuttingOperationsCount: cuttingCount,
      attendanceCount: attCount,
    );

    // Replace or add report for this date
    final existingIdx = dailyReports.indexWhere((r) => sameDay(r.reportDate));
    if (existingIdx >= 0) {
      dailyReports[existingIdx] = report;
    } else {
      dailyReports.insert(0, report);
    }

    saveToDisk();
    notifyListeners();
    return report;
  }

  void deleteDailyReport(String id) {
    dailyReports.removeWhere((r) => r.id == id);
    saveToDisk();
    notifyListeners();
  }
}

class MutableWrapper<T> {
  T value;
  MutableWrapper(this.value);
}

/// One resolved master-invoice line inside a return / allowance document:
/// the record that gets stored plus the metadata needed to route the goods.
class _ResolvedReturnLine {
  final AdjustmentLineModel line;
  final FactoryInvoiceItem? factoryItem;
  final WorkshopInvoiceItem? workshopItem;
  final double unitQty;

  const _ResolvedReturnLine({
    required this.line,
    this.factoryItem,
    this.workshopItem,
    this.unitQty = 1.0,
  });
}
