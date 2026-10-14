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
  List<StaffModel> staffList = [];
  List<WorkdayEntryModel> workdayEntries = [];

  // Returns Log
  List<ReturnInvoiceModel> returnInvoices = [];
  List<ExpenseTypeModel> expenseTypes = [];
  List<ExpenseRecordModel> expenseRecords = [];
  List<AdjustmentInvoiceModel> adjustmentInvoices = [];

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
        quantity: 15,
        materialNetCost: 124.7,
        laborCostPerPiece: 5.0,
        attachedServices: [
          ServiceAttachment(serviceName: 'جلي وتلميع', price: 45.0),
        ],
        sellingPrice: 320.0,
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
        quantity: 1,
        materialNetCost: 160.0,
        laborCostPerPiece: 60.0,
        attachedServices: [
          ServiceAttachment(serviceName: 'ثقب وتفريغ مغاسل', price: 30.0),
        ],
        sellingPrice: 450.0,
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
        totalEarned: 850.0,
        cashAdvancesDisbursed: 200.0,
      ),
      StaffModel(
        id: 'stf3',
        name: 'المحاسب نزار (إداري)',
        category: 'إداريين',
        phone: '0955333444',
        totalEarned: 2100.0,
        cashAdvancesDisbursed: 500.0,
      ),
    ];

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
    openingEntry.openingStock.add(item);
    openingEntry.inventoryValue = openingEntry.openingStock.fold(
      0.0,
      (sum, row) =>
          sum + (row.currency == AppCurrency.usd ? row.totalPrice : 0),
    );
    refresh();
  }

  void addOpeningFinancialRecord(LegacyFinancialRecordModel record) {
    if (openingEntry.isLocked) {
      throw StateError('The opening entry is locked.');
    }
    openingEntry.legacyFinancials.add(record);
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
    final retained = partners.fold<double>(
      0,
      (sum, partner) =>
          sum + (partnerTransfers[partner.id] == true ? share : 0),
    );
    for (final partner in partners) {
      if (partnerTransfers[partner.id] != true) {
        partner.totalWithdrawn += share;
      }
    }
    asset.isSold = true;
    asset.saleAmount = saleAmount;
    addCash('main', currency, retained);
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

  double totalRevenuesOf(String? currency) =>
      totalFactoryRevenueOf(currency) +
      totalWorkshopRevenueOf(currency) +
      totalScrapRevenueOf(currency) +
      totalKeptDepositsRevenueOf(currency);
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
      .where((w) => w.currency == AppCurrency.normalize(currency))
      .fold(0.0, (s, w) => s + w.grandTotal);
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
        accountantGraniteShareOf(c);
  }

  double get netOperatingProfit => netOperatingProfitOf(AppCurrency.usd);
  double get netOperatingProfitSyp => netOperatingProfitOf(AppCurrency.syp);

  // -------------------------------------------------------------
  // ACTIONS & TRANSACTIONS (ACID Lock Simulation)
  // -------------------------------------------------------------

  // 1. Opening Entry Lock
  void lockOpeningEntry() {
    openingEntry.isLocked = true;
    openingEntry.lockedAt = DateTime.now();
    isOpeningEntryCompleted = true;
    mainCashBox = openingEntry.mainCashValue;
    scrapCashBox = openingEntry.scrapCashValue;
    orderCashBox = openingEntry.orderCashValue;
    mainCashBoxSyp = openingEntry.mainCashValueSyp;
    scrapCashBoxSyp = openingEntry.scrapCashValueSyp;
    orderCashBoxSyp = openingEntry.orderCashValueSyp;
    notifyListeners();
    saveToDisk();
  }

  // 2. Partner Management Actions
  void injectNewPartnerCapital(double newAmount, [String? currency]) {
    if (newAmount <= 0) return;
    final c = AppCurrency.normalize(currency ?? AppCurrency.usd);
    // Calculate total capital before & after
    double totalOldCap = partners.fold(0.0, (s, p) => s + p.injectedCapital);
    double totalNewCap = totalOldCap + newAmount;

    // Split injected capital proportionately or add to primary
    partners[0].injectedCapital += newAmount * 0.42;
    partners[1].injectedCapital += newAmount * 0.35;
    partners[2].injectedCapital += newAmount * 0.23;

    // Recalculate ratios
    for (var p in partners) {
      p.ratio = p.injectedCapital / totalNewCap;
    }

    openingEntry.hassanRatio = partners[0].ratio;
    openingEntry.adnanRatio = partners[1].ratio;
    openingEntry.abdelMoeenRatio = partners[2].ratio;

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
    double partnerProfitShare = net * p.ratio;
    if (amount > (partnerProfitShare - p.totalWithdrawn)) {
      outWarning.value =
          "تحذير الأمان: المبلغ المطلوب ($amount${AppCurrency.symbol(c)}) يتجاوز حصة الشريك من الأرباح الصافية (${partnerProfitShare.fmt}${AppCurrency.symbol(c)})!";
    }

    p.totalWithdrawn += amount;
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
  void addSupplierPurchaseInvoice(FactoryInvoiceModel inv) {
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

    // Add items to block stock grouped later by Type + Grade + supplier price.
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
      final double effectiveTonCost =
          item.unitCost +
          (item.quantity > 0 ? shippingShare / item.quantity : 0.0);
      factoryBlocks.add(
        FactoryBlockModel(
          id: 'fb_${DateTime.now().millisecondsSinceEpoch}_${factoryBlocks.length}',
          blockCode: 'BLK-${factoryBlocks.length + 101}',
          typeName: item.typeName.isNotEmpty ? item.typeName : item.description,
          grade: item.grade.isNotEmpty ? item.grade : 'درجة أولى',
          supplierId: inv.partyId,
          supplierName: inv.partyName,
          weightTons: item.quantity,
          tonCost: effectiveTonCost,
          isGranite: item.isGranite,
        ),
      );
    }
    notifyListeners();
    saveToDisk();
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

  // 6. POS Factory Invoice Sale (multi-item, Pending/Paid split)
  void addFactoryPOSInvoice(FactoryInvoiceModel inv) {
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

    // Deduct stock from Factory Warehouse
    if (factoryWarehouse.isNotEmpty) {
      for (var item in inv.items) {
        var wh = factoryWarehouse.firstWhere(
          (w) => w.id == item.itemId || w.typeName == item.description,
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
        laborCostPerPiece: 0.0,
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
  void createWorkshopInvoice(
    WorkshopInvoiceModel inv, {
    String deductStockId = '',
    double deductQty = 0.0,
  }) {
    workshopInvoices.add(inv);
    if (inv.sourceType == 'قطع زائدة') {
      if (inv.sourceId.isNotEmpty) {
        final matches = scrapItems.where((s) => s.id == inv.sourceId).toList();
        if (matches.isNotEmpty) matches.first.isSold = true;
      }
      addCash('scrap', inv.currency, inv.cashPaidNow + inv.depositDeducted);
    } else {
      addCash('main', inv.currency, inv.cashPaidNow);
      if (inv.depositDeducted > 0) {
        if (inv.sourceType == 'طلبية معمل' && inv.sourceId.isNotEmpty) {
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
    notifyListeners();
    saveToDisk();
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
    if (inv.sourceType == 'قطع زائدة') {
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
        sourceType: old.sourceType,
        sourceId: old.sourceId,
        projectId: old.projectId,
        itemDescription: old.itemDescription,
        agreedPrice: old.agreedPrice,
        depositDeducted: old.depositDeducted,
        cashPaidNow: old.cashPaidNow + take,
        netCost: old.netCost,
        salesDiscount: old.salesDiscount,
        adjustmentsAmount: old.adjustmentsAmount,
        services: old.services,
        photoPath: old.photoPath,
        isGranite: old.isGranite,
        currency: old.currency,
      );
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

  void addService(ServiceItemModel srv) {
    services.add(srv);
    notifyListeners();
    saveToDisk();
  }

  void addStaff(StaffModel stf) {
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
    staffList.clear();
    workdayEntries.clear();
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
        'factoryBlocks',
        jsonEncode(factoryBlocks.map((b) => b.toJson()).toList()),
      );
      await prefs.setString(
        'factoryWarehouse',
        jsonEncode(factoryWarehouse.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        'workshopStock',
        jsonEncode(workshopStock.map((w) => w.toJson()).toList()),
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
        'staffList',
        jsonEncode(staffList.map((s) => s.toJson()).toList()),
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

      notifyListeners();
    } catch (_) {}
  }
}

class MutableWrapper<T> {
  T value;
  MutableWrapper(this.value);
}
