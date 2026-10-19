import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

  /// Takes cash from a box fund when the balance covers it.
  bool takeCash(String box, String? currency, double amount) {
    if (amount <= 0) return false;
    final syp = AppCurrency.isSyp(currency);
    switch (box) {
      case 'scrap':
        if (syp) {
          if (scrapCashBoxSyp + 0.0001 < amount) return false;
          scrapCashBoxSyp -= amount;
        } else {
          if (scrapCashBox + 0.0001 < amount) return false;
          scrapCashBox -= amount;
        }
        return true;
      case 'order':
        if (syp) {
          if (orderCashBoxSyp + 0.0001 < amount) return false;
          orderCashBoxSyp -= amount;
        } else {
          if (orderCashBox + 0.0001 < amount) return false;
          orderCashBox -= amount;
        }
        return true;
      default:
        if (syp) {
          if (mainCashBoxSyp + 0.0001 < amount) return false;
          mainCashBoxSyp -= amount;
        } else {
          if (mainCashBox + 0.0001 < amount) return false;
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
  late DateTime activeWorkweekStart;

  // Returns Log
  List<ReturnInvoiceModel> returnInvoices = [];
  List<ExpenseTypeModel> expenseTypes = [];
  List<ExpenseRecordModel> expenseRecords = [];
  List<AdjustmentInvoiceModel> adjustmentInvoices = [];
  CenterInfoModel centerInfo = const CenterInfoModel();

  ERPProvider() {
    _initDefaultSeedData();
    loadFromDisk();
  }

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

  // -------------------------------------------------------------
  // REAL-TIME FINANCIAL METRICS & CALCULATIONS
  // -------------------------------------------------------------
  double get totalCurrentEquity => openingEntry.totalEquity;
  double get totalCurrentEquitySyp => openingEntry.totalEquitySyp;

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

  void addExpenseRecord(ExpenseRecordModel expense) {
    if (expense.amount <= 0 ||
        expense.personShare < 0 ||
        expense.personShare > expense.amount) {
      throw ArgumentError('Expense and share amounts are invalid.');
    }
    expenseRecords.add(expense);
    refresh();
  }

  bool addAdjustmentInvoice(AdjustmentInvoiceModel invoice) {
    const kinds = {
      'purchase_return',
      'sales_return',
      'purchase_allowance',
      'sales_allowance',
    };
    if (!kinds.contains(invoice.kind) ||
        (invoice.module != 'factory' && invoice.module != 'workshop') ||
        !invoice.amount.isFinite ||
        invoice.amount <= 0 ||
        !invoice.quantity.isFinite ||
        invoice.quantity < 0 ||
        (invoice.kind.endsWith('return') && invoice.quantity <= 0) ||
        invoice.invoiceNo.trim().isEmpty) {
      return false;
    }

    final isFactory = invoice.module == 'factory';
    final factoryInvoice = isFactory
        ? factoryInvoices.where((item) => item.id == invoice.targetInvoiceId)
        : <FactoryInvoiceModel>[];
    final workshopInvoice = isFactory
        ? <WorkshopInvoiceModel>[]
        : workshopInvoices.where((item) => item.id == invoice.targetInvoiceId);
    if ((isFactory && factoryInvoice.isEmpty) ||
        (!isFactory && workshopInvoice.isEmpty)) {
      return false;
    }

    final original = isFactory ? factoryInvoice.first : null;
    final workshopOriginal = isFactory ? null : workshopInvoice.first;
    final purchase = invoice.kind.startsWith('purchase');
    if (invoice.targetInvoiceNo !=
            (original?.invoiceNo ?? workshopOriginal!.invoiceNo) ||
        invoice.partyName !=
            (original?.partyName ?? workshopOriginal!.clientName) ||
        (isFactory && (original!.invoiceType == 'شراء_مورد') != purchase)) {
      return false;
    }
    if (!isFactory && purchase) return false;
    if (!isFactory &&
        invoice.kind == 'sales_return' &&
        (workshopOriginal!.sourceType == 'تفصيل بسيط' ||
            workshopOriginal.sourceType == 'تفصيل معقد')) {
      final priorTailoringReturns = adjustmentInvoices
          .where(
            (item) =>
                item.module == 'workshop' &&
                item.targetInvoiceId == invoice.targetInvoiceId &&
                item.kind == 'sales_return',
          )
          .fold<double>(0, (sum, item) => sum + item.quantity);
      if (invoice.quantity >
          workshopOriginal.sourceQuantity - priorTailoringReturns + 0.0001) {
        return false;
      }
    }

    final originalTotal = original?.grandTotal ?? workshopOriginal!.grandTotal;
    final priorAmount = adjustmentInvoices
        .where(
          (item) =>
              item.module == invoice.module &&
              item.targetInvoiceId == invoice.targetInvoiceId,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    if (invoice.currency !=
            (original?.currency ?? workshopOriginal!.currency) ||
        invoice.amount > originalTotal - priorAmount + 0.0001) {
      return false;
    }

    FactoryInvoiceItem? factoryItem;
    if (invoice.kind.endsWith('return')) {
      if (isFactory) {
        if (invoice.itemIndex >= 0) {
          if (invoice.itemIndex >= original!.items.length) return false;
          factoryItem = original.items[invoice.itemIndex];
          if (factoryItem.description != invoice.itemDescription) return false;
        } else {
          final matches = original!.items.where(
            (item) => invoice.itemId.isNotEmpty
                ? item.itemId == invoice.itemId
                : item.description == invoice.itemDescription,
          );
          if (matches.isEmpty) return false;
          factoryItem = matches.first;
        }
        final alreadyReturned = adjustmentInvoices
            .where(
              (item) =>
                  item.module == invoice.module &&
                  item.targetInvoiceId == invoice.targetInvoiceId &&
                  item.kind.endsWith('return') &&
                  (invoice.itemIndex >= 0 && item.itemIndex >= 0
                      ? item.itemIndex == invoice.itemIndex
                      : item.itemId.isNotEmpty
                      ? item.itemId == invoice.itemId
                      : item.itemDescription == invoice.itemDescription),
            )
            .fold<double>(0, (sum, item) => sum + item.quantity);
        if (factoryItem.quantity - alreadyReturned + 0.0001 <
            invoice.quantity) {
          return false;
        }
      } else if (invoice.itemDescription != workshopOriginal!.itemDescription) {
        return false;
      }

      if (invoice.kind == 'purchase_return') {
        final line = factoryItem!;
        if (line.isMeterItem) {
          final typeName = line.typeName.isNotEmpty
              ? line.typeName
              : line.description;
          final grade = line.grade.isNotEmpty ? line.grade : 'درجة أولى';
          final available = factoryWarehouse
              .where(
                (item) =>
                    (line.itemId.isNotEmpty ? item.id == line.itemId : true) &&
                    item.typeName == typeName &&
                    (line.grade.isEmpty || item.grade == grade),
              )
              .fold<double>(0, (sum, item) => sum + item.availableQty);
          if (available + 0.0001 < invoice.quantity) return false;
        } else {
          final typeName = line.typeName.isNotEmpty
              ? line.typeName
              : line.description;
          final grade = line.grade.isNotEmpty ? line.grade : 'درجة أولى';
          final available = factoryBlocks
              .where(
                (block) =>
                    block.supplierId == original!.partyId &&
                    block.typeName == typeName &&
                    block.grade == grade,
              )
              .fold<double>(0, (sum, block) => sum + block.weightTons);
          if (available + 0.0001 < invoice.quantity) return false;
        }
      } else if (invoice.module == 'factory') {
        final line = factoryItem!;
        if (!factoryWarehouse.any(
          (item) => line.itemId.isNotEmpty
              ? item.id == line.itemId
              : item.typeName == line.typeName ||
                    item.typeName == line.description,
        )) {
          return false;
        }
      } else if (workshopOriginal!.sourceType == 'مواد خام') {
        final sourceId = workshopOriginal.sourceId;
        if (!workshopStock.any(
          (item) =>
              (sourceId.isNotEmpty && item.id == sourceId) ||
              item.typeName == invoice.itemDescription,
        )) {
          return false;
        }
      }
    }

    final supplierAdjustment = purchase;
    if (invoice.paymentAction == 'استرداد نقدي للصندوق الرئيسي') {
      if (!supplierAdjustment &&
          cashOf('main', invoice.currency) + 0.0001 < invoice.amount) {
        return false;
      }
    } else if (invoice.paymentAction != 'تخفيض دين' ||
        !_canReduceAdjustmentDebt(
          supplier: supplierAdjustment,
          partyName: original?.partyName ?? workshopOriginal!.clientName,
          partyId: original?.partyId ?? '',
          currency: invoice.currency,
          amount: invoice.amount,
        )) {
      return false;
    }

    if (invoice.paymentAction == 'استرداد نقدي للصندوق الرئيسي') {
      if (supplierAdjustment) {
        addCash('main', invoice.currency, invoice.amount);
      } else if (!takeCash('main', invoice.currency, invoice.amount)) {
        return false;
      }
      final availableDebt = _adjustmentDebtBalance(
        supplier: supplierAdjustment,
        partyName: original?.partyName ?? workshopOriginal!.clientName,
        partyId: original?.partyId ?? '',
        currency: invoice.currency,
      );
      if (availableDebt > 0) {
        _reduceAdjustmentDebt(
          supplier: supplierAdjustment,
          partyName: original?.partyName ?? workshopOriginal!.clientName,
          partyId: original?.partyId ?? '',
          currency: invoice.currency,
          amount: invoice.amount < availableDebt
              ? invoice.amount
              : availableDebt,
        );
      }
    } else {
      _reduceAdjustmentDebt(
        supplier: supplierAdjustment,
        partyName: original?.partyName ?? workshopOriginal!.clientName,
        partyId: original?.partyId ?? '',
        currency: invoice.currency,
        amount: invoice.amount,
      );
    }

    if (invoice.kind.endsWith('return')) {
      if (invoice.kind == 'purchase_return') {
        final line = factoryItem!;
        if (line.isMeterItem) {
          final typeName = line.typeName.isNotEmpty
              ? line.typeName
              : line.description;
          final grade = line.grade.isNotEmpty ? line.grade : 'درجة أولى';
          final warehouseMatches = factoryWarehouse.where(
            (item) =>
                (line.itemId.isNotEmpty ? item.id == line.itemId : false) ||
                (item.typeName == typeName &&
                    (line.grade.isEmpty || item.grade == grade)),
          );
          if (warehouseMatches.isNotEmpty) {
            final whItem = warehouseMatches.first;
            whItem.availableQty = (whItem.availableQty - invoice.quantity).clamp(
              0.0,
              double.infinity,
            );
          }
        } else {
          var remaining = invoice.quantity;
          final blocks = factoryBlocks
              .where(
                (block) =>
                    block.supplierId == original!.partyId &&
                    block.typeName ==
                        (line.typeName.isNotEmpty
                            ? line.typeName
                            : line.description) &&
                    block.grade ==
                        (line.grade.isNotEmpty ? line.grade : 'درجة أولى'),
              )
              .toList();
          for (final block in blocks) {
            if (remaining <= 0) break;
            final returned = remaining < block.weightTons
                ? remaining
                : block.weightTons;
            block.weightTons -= returned;
            remaining -= returned;
          }
        }
      } else if (invoice.module == 'factory') {
        final line = factoryItem!;
        final warehouseItem = factoryWarehouse.firstWhere(
          (item) => line.itemId.isNotEmpty
              ? item.id == line.itemId
              : item.typeName == line.typeName ||
                    item.typeName == line.description,
        );
        final unitQuantity = line.quantity > 0
            ? line.calculatedArea / line.quantity
            : 1.0;
        warehouseItem.availableQty += invoice.quantity * unitQuantity;
      } else if (workshopOriginal!.sourceType == 'مواد خام') {
        final sourceId = workshopOriginal.sourceId;
        final stock = workshopStock.firstWhere(
          (item) =>
              (sourceId.isNotEmpty && item.id == sourceId) ||
              item.typeName == invoice.itemDescription,
        );
        stock.availableQty += invoice.quantity;
      } else if (workshopOriginal.sourceType == 'تفصيل بسيط' ||
          workshopOriginal.sourceType == 'تفصيل معقد') {
        final products = workshopOriginal.sourceType == 'تفصيل بسيط'
            ? simpleTailorings
            : complexTailorings;
        final product = _firstOrNull(
          products.where((item) => item.id == workshopOriginal.sourceId),
        );
        if (product != null) product.quantity += invoice.quantity;
      }
    }

    if (original != null) {
      original.adjustmentsAmount += invoice.amount;
      original.paymentStatus = original.remainingBalance > 0.01
          ? 'مستحق الدفع'
          : 'مدفوعة';
    } else {
      workshopOriginal!.adjustmentsAmount += invoice.amount;
    }
    adjustmentInvoices.add(invoice);
    refresh();
    return true;
  }

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
    required Map<String, bool> partnerTransfers,
  }) {
    final asset = openingEntry.fixedAssets.firstWhere(
      (item) => item.id == assetId,
      orElse: () => throw StateError('Fixed asset was not found.'),
    );
    if (asset.isSold ||
        saleAmount <= 0 ||
        asset.currency != AppCurrency.normalize(currency)) {
      return false;
    }
    if (partners.length != 3) {
      throw StateError(
        'Asset sale distribution requires exactly three partners.',
      );
    }
    final share = saleAmount / 3;
    final c = AppCurrency.normalize(currency);
    final retained = partners.fold<double>(
      0,
      (sum, partner) =>
          sum + (partnerTransfers[partner.id] == true ? share : 0),
    );
    for (final partner in partners) {
      if (partnerTransfers[partner.id] != true) {
        if (c == AppCurrency.syp) {
          partner.totalWithdrawnSyp += share;
        } else {
          partner.totalWithdrawn += share;
        }
      }
    }
    asset.isSold = true;
    asset.saleAmount = saleAmount;
    addCash('main', c, retained);
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
      netGraniteProfitOf(currency) * 0.50; // 50% split
  double get accountantGraniteShare =>
      accountantGraniteShareOf(AppCurrency.usd);
  double get accountantGraniteShareSyp =>
      accountantGraniteShareOf(AppCurrency.syp);

  // Income Statement (P&L) Calculations — per currency
  double totalFactoryRevenueOf(String? currency) => factoryInvoices
      .where(
        (i) =>
            i.invoiceType == 'بيع_معتمد' &&
            i.currency == AppCurrency.normalize(currency),
      )
      .fold(0.0, (s, i) => s + i.grandTotal);
  double totalWorkshopRevenueOf(String? currency) => workshopInvoices
      .where((i) => i.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, i) => s + i.grandTotal);
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

  double factoryServiceRevenueOf(String? currency) => factoryInvoices
      .where(
        (invoice) =>
            invoice.invoiceType == 'بيع_معتمد' &&
            invoice.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(
        0,
        (sum, invoice) =>
            sum + invoice.servicesTotal + invoice.itemsServicesTotal,
      );

  double workshopServiceRevenueOf(String? currency) => workshopInvoices
      .where((invoice) => invoice.currency == AppCurrency.normalize(currency))
      .fold<double>(0, (sum, invoice) => sum + invoice.servicesTotal);

  double factorySalesDiscountOf(String? currency) => factoryInvoices
      .where(
        (invoice) =>
            invoice.invoiceType == 'بيع_معتمد' &&
            invoice.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, invoice) => sum + invoice.discountAmount);

  double workshopSalesDiscountOf(String? currency) => workshopInvoices
      .where((invoice) => invoice.currency == AppCurrency.normalize(currency))
      .fold<double>(0, (sum, invoice) => sum + invoice.salesDiscount);

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

  double assetSaleRevenueOf(String? currency) => openingEntry.fixedAssets
      .where(
        (asset) =>
            asset.isSold && asset.currency == AppCurrency.normalize(currency),
      )
      .fold<double>(0, (sum, asset) => sum + asset.saleAmount);

  double expenseRecordsTotalOf(String? currency) => expenseRecords
      .where((expense) =>
          !expense.isInformational &&
          expense.currency == AppCurrency.normalize(currency))
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double totalRevenuesOf(String? currency) =>
      totalFactoryRevenueOf(currency) +
      totalWorkshopRevenueOf(currency) +
      totalScrapRevenueOf(currency) +
      totalKeptDepositsRevenueOf(currency) +
      salesDiscountsOf(currency) +
      adjustmentTotalOf('purchase_return', currency) +
      adjustmentTotalOf('purchase_allowance', currency) +
      supplierDiscountsOf(currency) +
      assetSaleRevenueOf(currency);
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

  double netOperatingProfitOf(String? currency) {
    final c = AppCurrency.normalize(currency);
    return totalRevenuesOf(c) -
        totalCOGSOf(c) -
        totalOperationalExpensesOf(c) -
        totalUnnaturalWasteLossesOf(c) -
        totalSurplusInitialCostOf(c) -
        accountantGraniteShareOf(c) -
        expenseRecordsTotalOf(c) -
        salesReturnsAndAllowancesOf(c) -
        salesDiscountsOf(c);
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
  void lockOpeningEntry() {
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
              null) {
        throw StateError(
          'Register the meter type before approving opening stock: ${item.typeName}.',
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
              supplierName: item.supplierName,
              weightTons: item.quantity,
              tonCost: item.unitPrice,
              isGranite: type.isGranite,
            ),
          );
          break;
        case 'أمتار المصنع':
        case 'أمتار المعمل':
          final type = _firstOrNull(
            meterTypes.where(
              (candidate) =>
                  (item.typeId.isNotEmpty && candidate.id == item.typeId) ||
                  candidate.typeName == item.typeName,
            ),
          )!;
          if (item.category == 'أمتار المصنع') {
            factoryWarehouse.add(
              FactoryWarehouseModel(
                id: item.id,
                typeName: type.typeName,
                grade: type.grade,
                thicknessCm: type.thicknessCm,
                category: type.category,
                availableQty: item.quantity,
                netCostPerUnit: item.unitPrice,
                recommendedSalePrice: item.unitPrice,
                isGranite: type.isGranite,
              ),
            );
          } else {
            workshopStock.add(
              WorkshopStockModel(
                id: item.id,
                typeName: type.typeName,
                grade: type.grade,
                thicknessCm: type.thicknessCm,
                category: type.category,
                availableQty: item.quantity,
                netCostPerUnit: item.unitPrice,
                recommendedSalePrice: item.unitPrice,
                isGranite: type.isGranite,
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
          break;
        case 'قطع زائدة وخردة':
          scrapItems.add(
            ScrapItemModel(
              id: item.id,
              description: item.typeName,
              baseCost: item.totalPrice,
              sellingPrice: item.unitPrice,
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
  void injectNewPartnerCapital(double newAmount, [String? currency]) {
    if (newAmount <= 0) return;
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    if (partners.length != 3) {
      throw StateError('Capital allocation requires exactly three partners.');
    }
    if (c == AppCurrency.syp) {
      for (final partner in partners) {
        partner.injectedCapitalSyp += newAmount * partner.ratio;
      }
    } else {
      final totalOldCapital = partners.fold<double>(
        0,
        (sum, partner) => sum + partner.injectedCapital,
      );
      final totalNewCapital = totalOldCapital + newAmount;
      for (final partner in partners) {
        partner.injectedCapital += newAmount * partner.ratio;
        partner.ratio = partner.injectedCapital / totalNewCapital;
      }
      openingEntry.hassanRatio = partners[0].ratio;
      openingEntry.adnanRatio = partners[1].ratio;
      openingEntry.abdelMoeenRatio = partners[2].ratio;
    }

    addCash('main', c, newAmount);

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
    if (inv.isCashInvoice &&
        (inv.invoiceType != 'بيع_معتمد' || inv.remainingBalance > 0.01)) {
      return false;
    }
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    factoryInvoices.add(inv);
    if (inv.advancePayment > 0) {
      addCash('main', inv.currency, inv.advancePayment);
    }

    if (inv.remainingBalance > 0 && clients.isNotEmpty) {
      var client = clients.firstWhere(
        (c) => c.id == inv.partyId,
        orElse: () => clients.first,
      );
      client.addDebt(inv.currency, inv.remainingBalance);
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
  void createWorkshopOrder(WorkshopOrderModel order) {
    workshopOrders.add(order);
    if (order.depositAmount > 0) {
      // CRITICAL ACCOUNTING RULE: Down payment stored in isolated Order Cash Box
      addCash('order', order.currency, order.depositAmount);
    }
    notifyListeners();
    saveToDisk();
  }

  void assignOrderToInvoice(WorkshopOrderModel order, double cashPaidNow) {
    order.status = 'مكتملة ومرحلة';

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

    notifyListeners();
    saveToDisk();
  }

  void cancelWorkshopOrder(WorkshopOrderModel order, bool isSpecialRefund) {
    order.status = 'ملغاة';
    order.isSpecialRefund = isSpecialRefund;

    if (isSpecialRefund) {
      // Special case: refund deposit back to customer from Order Cash Box
      takeCash('order', order.currency, order.depositAmount);
    } else {
      // Default rule: deposit is non-refundable and kept as profit.
    }
    notifyListeners();
    saveToDisk();
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
    if (inv.isCashInvoice && inv.remainingBalance > 0.01) return false;

    // Multi-item path
    if (inv.items.isNotEmpty) {
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
            return false;
          }
          final items = isSimple ? simpleTailorings : complexTailorings;
          final matches = items.where((t) => t.id == item.sourceId).toList();
          if (matches.isEmpty || item.quantity <= 0 || matches.first.quantity + 0.0001 < item.quantity) {
            return false;
          }
        } else if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
          if (item.sourceId.isNotEmpty) {
            final stock = workshopStock.where((w) => w.id == item.sourceId).toList();
            if (stock.isEmpty || stock.first.availableQty + 0.0001 < item.quantity) {
              return false;
            }
          }
        } else if (item.sourceType == 'طلب معمل' || item.sourceType == 'طلبية معمل') {
          if (item.depositAmount > 0 && item.sourceId.isNotEmpty) {
            final orders = workshopOrders.where((o) => o.id == item.sourceId).toList();
            if (orders.isNotEmpty && cashOf('order', inv.currency) + 0.0001 < item.depositAmount) {
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
          );
          clients.add(client);
        } else {
          client = existingClient;
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
        );
        clients.add(client);
      } else {
        client = existingClient;
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
  void createFactoryOrder(FactoryOrderModel order) {
    factoryOrders.add(order);
    if (order.depositAmount > 0) {
      addCash('order', order.currency, order.depositAmount);
    }
    notifyListeners();
    saveToDisk();
  }

  void assignFactoryOrderToInvoice(
    FactoryOrderModel order,
    double cashPaidNow, {
    List<ServiceAttachment> services = const [],
  }) {
    order.status = 'مكتملة ومرحلة';
    if (order.depositAmount > 0) {
      takeCash('order', order.currency, order.depositAmount);
    }
    addFactoryPOSInvoice(
      FactoryInvoiceModel(
        id: 'fi_ord_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNo: 'FAC-ORD-${factoryInvoices.length + 101}',
        date: DateTime.now(),
        partyId: '',
        partyName: order.clientName,
        invoiceType: 'بيع_معتمد',
        items: [
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
        isGoodsDelivered: true,
        advancePayment: order.depositAmount + cashPaidNow,
        photoUrl: order.photoPath,
        currency: order.currency,
      ),
    );
    // addFactoryPOSInvoice already moved (deposit + cash) into Main Cash Box.
    notifyListeners();
    saveToDisk();
  }

  void cancelFactoryOrder(FactoryOrderModel order, bool isSpecialRefund) {
    order.status = 'ملغاة';
    order.isSpecialRefund = isSpecialRefund;
    if (isSpecialRefund) {
      takeCash('order', order.currency, order.depositAmount);
    }
    notifyListeners();
    saveToDisk();
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

  /// Pays a supplier purchase invoice (we pay them): advances the invoice,
  /// reduces the supplier debt and the Main Cash Box (invoice currency).
  bool paySupplierInvoice(FactoryInvoiceModel inv, double amount) {
    if (amount <= 0) return false;
    final pay = amount.clamp(0.0, inv.remainingBalance).toDouble();
    if (pay <= 0) return false;
    if (!takeCash('main', inv.currency, pay)) return false;
    inv.advancePayment += pay;
    inv.paymentStatus = inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة';
    final matches = suppliers.where((s) => s.id == inv.partyId).toList();
    if (matches.isNotEmpty) {
      matches.first.reduceDebt(inv.currency, pay);
    }
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// Collects a factory sale invoice (they pay us) — invoice currency.
  bool collectFactoryInvoice(FactoryInvoiceModel inv, double amount) {
    if (amount <= 0) return false;
    final take = amount.clamp(0.0, inv.remainingBalance).toDouble();
    if (take <= 0) return false;
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
    if (amount <= 0) return false;
    final take = amount.clamp(0.0, inv.remainingBalance).toDouble();
    if (take <= 0) return false;
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

  /// Collects a retail/approved client balance not tied to a single invoice.
  /// [currency] selects which fund/debt (USD default; pass SYP for ل.س).
  bool collectClientDebt(
    ClientModel client,
    double amount, [
    String? currency,
  ]) {
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    if (amount <= 0) return false;
    final take = amount.clamp(0.0, client.debtOf(c)).toDouble();
    if (take <= 0) return false;
    client.reduceDebt(c, take);
    addCash('main', c, take);
    notifyListeners();
    saveToDisk();
    return true;
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
  void addSupplier(SupplierModel s) {
    suppliers.add(s);
    notifyListeners();
    saveToDisk();
  }

  void addClient(ClientModel c) {
    clients.add(c);
    notifyListeners();
    saveToDisk();
  }

  void addBlockType(BlockTypeModel bt) {
    blockTypes.add(bt);
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
    if ((stf.category == 'عمال' || stf.category == 'إداريين') &&
        !staffTypes.any(
          (type) => type.id == stf.typeId && type.category == stf.category,
        )) {
      throw ArgumentError('A valid worker or administrative staff type is required.');
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

    // 2. Reset isolated cash registers (both USD and SYP funds).
    mainCashBox = 0.0;
    scrapCashBox = 0.0;
    orderCashBox = 0.0;
    mainCashBoxSyp = 0.0;
    scrapCashBoxSyp = 0.0;
    orderCashBoxSyp = 0.0;

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
        'adjustmentInvoices',
        jsonEncode(adjustmentInvoices.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'centerInfo',
        jsonEncode(centerInfo.toJson()),
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

      if (openingEntry.isLocked &&
          openingEntry.openingStock.isNotEmpty &&
          !openingEntry.openingStockApplied) {
        _applyOpeningStockToOperationalInventory();
        await saveToDisk();
      }
      notifyListeners();
    } catch (_) {}
  }
}

class MutableWrapper<T> {
  T value;
  MutableWrapper(this.value);
}
