// ==========================================
// 0. CURRENCY HELPER (dual-currency: USD $ / SYP ل.س)
// Every cash box, debt and invoice/order carries a currency.
// No conversion is applied — USD and SYP ledgers stay separate.
// ==========================================
class AppCurrency {
  static const String usd = 'USD';
  static const String syp = 'SYP';

  static String normalize(String? c) => c == syp ? syp : usd;
  static bool isSyp(String? c) => normalize(c) == syp;
  static bool isUsd(String? c) => normalize(c) == usd;
  static String symbol(String? c) => isSyp(c) ? 'ل.س' : '\$';
  static String label(String? c) => isSyp(c) ? 'ليرة سورية' : 'دولار';

  /// Smart number format: whole numbers print WITHOUT a trailing ".0"
  /// (200 -> "200"), while real decimals are kept (9.5 -> "9.5",
  /// 44.70 -> "44.7"). Up to [maxFractionDigits] decimals are shown.
  static String fmt(num v, [int maxFractionDigits = 2]) {
    final d = v.toDouble();
    if (!d.isFinite) return '0';
    var s = d.toStringAsFixed(maxFractionDigits);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    if (s == '-0') s = '0';
    return s;
  }

  /// Rounds a monetary value to exactly 2 decimal places so USD / SYP
  /// totals never drift because of binary floating point accumulation.
  static double money(num value) {
    final d = value.toDouble();
    if (!d.isFinite) return 0.0;
    return (d * 100).roundToDouble() / 100;
  }

  /// "12.5 $ • 30000 ل.س" — used for every dual statistic.
  static String dual(double usdValue, double sypValue) {
    return '${fmt(usdValue)} \$ • ${fmt(sypValue)} ل.س';
  }

  static String single(double value, String? currency) {
    final c = normalize(currency);
    return '${fmt(value)} ${c == syp ? 'ل.س' : '\$'}';
  }
}

/// Extension so any number can be printed smartly:
/// `200.0.fmt` -> "200", `9.5.fmt` -> "9.5".
extension SmartNumberFormat on num {
  String get fmt => AppCurrency.fmt(this);
}

// ==========================================
// 1. OPENING ENTRY MODEL
// ==========================================
class OpeningEntryModel {
  // Fixed Assets
  double landValue;
  double buildingsValue;
  double machineryValue;
  double vehiclesValue;
  double furnitureValue;

  // Current Assets (USD fund + SYP fund for cash boxes)
  double mainCashValue;
  double scrapCashValue;
  double orderCashValue;
  double mainCashValueSyp;
  double scrapCashValueSyp;
  double orderCashValueSyp;
  double inventoryValue;
  double customerDebtsValue;

  // Current Liabilities
  double supplierPayablesValue;
  double workerSalariesValue;
  final List<FixedAssetModel> fixedAssets;
  final List<OpeningStockItemModel> openingStock;
  final List<LegacyFinancialRecordModel> legacyFinancials;

  // Partner equity initial setup ratios: Hassan 42%, Adnan 35%, AbdelMoeen 23%
  double hassanRatio;
  double adnanRatio;
  double abdelMoeenRatio;

  bool isLocked;
  DateTime? lockedAt;
  bool openingStockApplied;

  OpeningEntryModel({
    this.landValue = 120000.0,
    this.buildingsValue = 85000.0,
    this.machineryValue = 95000.0,
    this.vehiclesValue = 35000.0,
    this.furnitureValue = 0.0,
    this.mainCashValue = 45000.0,
    this.scrapCashValue = 8500.0,
    this.orderCashValue = 3200.0,
    this.mainCashValueSyp = 0.0,
    this.scrapCashValueSyp = 0.0,
    this.orderCashValueSyp = 0.0,
    this.inventoryValue = 110000.0,
    this.customerDebtsValue = 28000.0,
    this.supplierPayablesValue = 42000.0,
    this.workerSalariesValue = 9500.0,
    List<FixedAssetModel>? fixedAssets,
    List<OpeningStockItemModel>? openingStock,
    List<LegacyFinancialRecordModel>? legacyFinancials,
    this.hassanRatio = 0.42,
    this.adnanRatio = 0.35,
    this.abdelMoeenRatio = 0.23,
    this.isLocked = true,
    this.lockedAt,
    this.openingStockApplied = false,
  }) : fixedAssets = fixedAssets ?? [],
       openingStock = openingStock ?? [],
       legacyFinancials = legacyFinancials ?? [];

  double get totalFixedAssets => (fixedAssets.isEmpty
      ? landValue +
            buildingsValue +
            machineryValue +
            vehiclesValue +
            furnitureValue
      : fixedAssets
            .where(
              (asset) => !asset.isSold && asset.currency == AppCurrency.usd,
            )
            .fold(0.0, (sum, asset) => sum + asset.amount));

  double totalFixedAssetsOf(String? currency) => fixedAssets.isEmpty
      ? (AppCurrency.isSyp(currency) ? 0 : totalFixedAssets)
      : fixedAssets
            .where(
              (asset) =>
                  !asset.isSold &&
                  asset.currency == AppCurrency.normalize(currency),
            )
            .fold(0.0, (sum, asset) => sum + asset.amount);

  double totalOpeningStockOf(String? currency) => openingStock
      .where((item) => item.currency == AppCurrency.normalize(currency))
      .fold(0.0, (sum, item) => sum + item.totalPrice);

  double get totalCurrentAssets =>
      mainCashValue +
      scrapCashValue +
      orderCashValue +
      inventoryValue +
      customerDebtsValue;

  double get totalAssets => totalFixedAssets + totalCurrentAssets;

  double get totalLiabilities => supplierPayablesValue + workerSalariesValue;

  double get totalAssetsSyp =>
      totalFixedAssetsOf(AppCurrency.syp) +
      mainCashValueSyp +
      scrapCashValueSyp +
      orderCashValueSyp +
      totalOpeningStockOf(AppCurrency.syp) +
      legacyFinancials
          .where(
            (record) =>
                record.category == 'clients' &&
                record.currency == AppCurrency.syp,
          )
          .fold(0.0, (sum, record) => sum + record.amount);

  double get totalLiabilitiesSyp => legacyFinancials
      .where(
        (record) =>
            (record.category == 'suppliers' ||
                record.category == 'employees') &&
            record.currency == AppCurrency.syp,
      )
      .fold(0.0, (sum, record) => sum + record.amount);

  double get totalEquity => totalAssets - totalLiabilities;
  double get totalEquitySyp => totalAssetsSyp - totalLiabilitiesSyp;

  double get hassanCapital => totalEquity * hassanRatio;
  double get adnanCapital => totalEquity * adnanRatio;
  double get abdelMoeenCapital => totalEquity * abdelMoeenRatio;

  bool get isBalanced =>
      (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;

  Map<String, dynamic> toJson() => {
    'landValue': landValue,
    'buildingsValue': buildingsValue,
    'machineryValue': machineryValue,
    'vehiclesValue': vehiclesValue,
    'furnitureValue': furnitureValue,
    'mainCashValue': mainCashValue,
    'scrapCashValue': scrapCashValue,
    'orderCashValue': orderCashValue,
    'mainCashValueSyp': mainCashValueSyp,
    'scrapCashValueSyp': scrapCashValueSyp,
    'orderCashValueSyp': orderCashValueSyp,
    'inventoryValue': inventoryValue,
    'customerDebtsValue': customerDebtsValue,
    'supplierPayablesValue': supplierPayablesValue,
    'workerSalariesValue': workerSalariesValue,
    'fixedAssets': fixedAssets.map((asset) => asset.toJson()).toList(),
    'openingStock': openingStock.map((item) => item.toJson()).toList(),
    'legacyFinancials': legacyFinancials
        .map((record) => record.toJson())
        .toList(),
    'hassanRatio': hassanRatio,
    'adnanRatio': adnanRatio,
    'abdelMoeenRatio': abdelMoeenRatio,
    'isLocked': isLocked,
    'lockedAt': lockedAt?.toIso8601String(),
    'openingStockApplied': openingStockApplied,
  };

  factory OpeningEntryModel.fromJson(Map<String, dynamic> json) =>
      OpeningEntryModel(
        landValue: (json['landValue'] ?? 0.0).toDouble(),
        buildingsValue: (json['buildingsValue'] ?? 0.0).toDouble(),
        machineryValue: (json['machineryValue'] ?? 0.0).toDouble(),
        vehiclesValue: (json['vehiclesValue'] ?? 0.0).toDouble(),
        furnitureValue: (json['furnitureValue'] ?? 0.0).toDouble(),
        mainCashValue: (json['mainCashValue'] ?? 0.0).toDouble(),
        scrapCashValue: (json['scrapCashValue'] ?? 0.0).toDouble(),
        orderCashValue: (json['orderCashValue'] ?? 0.0).toDouble(),
        mainCashValueSyp: (json['mainCashValueSyp'] ?? 0.0).toDouble(),
        scrapCashValueSyp: (json['scrapCashValueSyp'] ?? 0.0).toDouble(),
        orderCashValueSyp: (json['orderCashValueSyp'] ?? 0.0).toDouble(),
        inventoryValue: (json['inventoryValue'] ?? 0.0).toDouble(),
        customerDebtsValue: (json['customerDebtsValue'] ?? 0.0).toDouble(),
        supplierPayablesValue: (json['supplierPayablesValue'] ?? 0.0)
            .toDouble(),
        workerSalariesValue: (json['workerSalariesValue'] ?? 0.0).toDouble(),
        fixedAssets: (json['fixedAssets'] as List? ?? [])
            .map((item) => FixedAssetModel.fromJson(item))
            .toList(),
        openingStock: (json['openingStock'] as List? ?? [])
            .map((item) => OpeningStockItemModel.fromJson(item))
            .toList(),
        legacyFinancials: (json['legacyFinancials'] as List? ?? [])
            .map((item) => LegacyFinancialRecordModel.fromJson(item))
            .toList(),
        hassanRatio: (json['hassanRatio'] ?? 0.42).toDouble(),
        adnanRatio: (json['adnanRatio'] ?? 0.35).toDouble(),
        abdelMoeenRatio: (json['abdelMoeenRatio'] ?? 0.23).toDouble(),
        isLocked: json['isLocked'] ?? false,
        lockedAt: json['lockedAt'] != null
            ? DateTime.parse(json['lockedAt'])
            : null,
        openingStockApplied: json['openingStockApplied'] ?? false,
      );
}

class FixedAssetModel {
  final String id;
  final String category;
  final String name;
  final double amount;
  final String description;
  final String currency;
  bool isSold;
  double saleAmount;

  FixedAssetModel({
    required this.id,
    required this.category,
    required this.name,
    required this.amount,
    this.description = '',
    this.currency = AppCurrency.usd,
    this.isSold = false,
    this.saleAmount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'amount': amount,
    'description': description,
    'currency': currency,
    'isSold': isSold,
    'saleAmount': saleAmount,
  };

  factory FixedAssetModel.fromJson(Map<String, dynamic> json) =>
      FixedAssetModel(
        id: json['id'],
        category: json['category'],
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] ?? '',
        currency: AppCurrency.normalize(json['currency']),
        isSold: json['isSold'] ?? false,
        saleAmount: (json['saleAmount'] ?? 0).toDouble(),
      );
}

class AssetSaleRecordModel {
  final String id;
  final String assetId;
  final String assetName;
  final String category;
  final double registeredPrice; // Initial registered price in system (book value)
  final double salePrice;       // Actual sale price collected to safe
  final String currency;
  final DateTime saleDate;
  final String description;

  AssetSaleRecordModel({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.category,
    required this.registeredPrice,
    required this.salePrice,
    this.currency = AppCurrency.usd,
    DateTime? saleDate,
    this.description = '',
  }) : saleDate = saleDate ?? DateTime.now();

  /// Subtraction process: (Selling Price - Initial Registered Price)
  double get profitOrLoss => salePrice - registeredPrice;

  /// If Selling Price > Registered Price -> Profit/Gain
  double get gain =>
      salePrice > registeredPrice ? (salePrice - registeredPrice) : 0.0;

  /// If Selling Price < Registered Price -> Loss = (Registered Price - Selling Price)
  double get loss =>
      registeredPrice > salePrice ? (registeredPrice - salePrice) : 0.0;

  bool get isGain => salePrice > registeredPrice;
  bool get isLoss => salePrice < registeredPrice;
  bool get isBreakEven => (salePrice - registeredPrice).abs() < 0.0001;

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'assetName': assetName,
    'category': category,
    'registeredPrice': registeredPrice,
    'salePrice': salePrice,
    'currency': currency,
    'saleDate': saleDate.toIso8601String(),
    'description': description,
  };

  factory AssetSaleRecordModel.fromJson(Map<String, dynamic> json) =>
      AssetSaleRecordModel(
        id: json['id'] ?? '',
        assetId: json['assetId'] ?? '',
        assetName: json['assetName'] ?? '',
        category: json['category'] ?? '',
        registeredPrice: (json['registeredPrice'] ?? 0.0).toDouble(),
        salePrice: (json['salePrice'] ?? 0.0).toDouble(),
        currency: AppCurrency.normalize(json['currency']),
        saleDate: json['saleDate'] != null
            ? DateTime.parse(json['saleDate'])
            : DateTime.now(),
        description: json['description'] ?? '',
      );
}

class OpeningStockItemModel {
  final String id;
  final String category;
  final String typeName;
  final String typeId;
  final String grade;
  final bool isGranite;
  final double thicknessCm;
  final String supplierName;
  double quantity;
  final double unitPrice;
  final double sellingPrice;
  final String description;
  final String currency;

  OpeningStockItemModel({
    required this.id,
    required this.category,
    required this.typeName,
    this.typeId = '',
    this.grade = '',
    this.isGranite = false,
    this.thicknessCm = 0,
    this.supplierName = '',
    required this.quantity,
    required this.unitPrice,
    this.sellingPrice = 0.0,
    this.description = '',
    this.currency = AppCurrency.usd,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'typeName': typeName,
    'typeId': typeId,
    'grade': grade,
    'isGranite': isGranite,
    'thicknessCm': thicknessCm,
    'supplierName': supplierName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'sellingPrice': sellingPrice,
    'description': description,
    'currency': currency,
  };

  factory OpeningStockItemModel.fromJson(Map<String, dynamic> json) =>
      OpeningStockItemModel(
        id: json['id'],
        category: json['category'],
        typeName: json['typeName'],
        typeId: json['typeId'] ?? '',
        grade: json['grade'] ?? '',
        isGranite: json['isGranite'] ?? false,
        thicknessCm: (json['thicknessCm'] ?? 0).toDouble(),
        supplierName: json['supplierName'] ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] ?? '',
        currency: AppCurrency.normalize(json['currency']),
      );
}

class LegacyFinancialRecordModel {
  final String id;
  final String category;
  final String name;
  final String phone;
  final String currency;
  double amount;
  final String description;

  LegacyFinancialRecordModel({
    required this.id,
    required this.category,
    required this.name,
    this.phone = '',
    required this.currency,
    required this.amount,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'phone': phone,
    'currency': currency,
    'amount': amount,
    'description': description,
  };

  factory LegacyFinancialRecordModel.fromJson(Map<String, dynamic> json) =>
      LegacyFinancialRecordModel(
        id: json['id'],
        category: json['category'],
        name: json['name'],
        phone: json['phone'] ?? '',
        currency: AppCurrency.normalize(json['currency']),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] ?? '',
      );
}

class ExpenseTypeModel {
  final String id;
  final String name;
  final String description;

  ExpenseTypeModel({
    required this.id,
    required this.name,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };

  factory ExpenseTypeModel.fromJson(Map<String, dynamic> json) =>
      ExpenseTypeModel(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
      );
}

class ExpenseRecordModel {
  final String id;
  final String typeId;
  final double amount;
  final String currency;
  final String personName;
  final String? staffId;
  final double personShare;
  final String description;
  final DateTime date;
  final bool isInformational;
  final String cashBox;

  ExpenseRecordModel({
    required this.id,
    required this.typeId,
    required this.amount,
    required this.currency,
    this.personName = '',
    this.staffId,
    this.personShare = 0,
    this.description = '',
    DateTime? date,
    this.isInformational = false,
    this.cashBox = 'main',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeId': typeId,
    'amount': amount,
    'currency': currency,
    'personName': personName,
    'staffId': staffId,
    'personShare': personShare,
    'description': description,
    'date': date.toIso8601String(),
    'isInformational': isInformational,
    'cashBox': cashBox,
  };

  factory ExpenseRecordModel.fromJson(Map<String, dynamic> json) =>
      ExpenseRecordModel(
        id: json['id'],
        typeId: json['typeId'],
        amount: (json['amount'] as num).toDouble(),
        currency: AppCurrency.normalize(json['currency']),
        personName: json['personName'] ?? '',
        staffId: json['staffId'],
        personShare: (json['personShare'] ?? 0).toDouble(),
        description: json['description'] ?? '',
        date: json['date'] != null ? DateTime.parse(json['date']) : null,
        isInformational: json['isInformational'] ?? false,
        cashBox: json['cashBox'] ?? 'main',
      );
}

/// One returned line inside a return invoice.
/// `unitPrice` is the ORIGINAL unit price taken from the parent invoice,
/// expressed per the line's own counting unit (m², m³, tons, pieces…).
/// `amount` is always `round2(quantity * unitPrice)`.
class AdjustmentLineModel {
  final String itemId; // parent invoice line id (warehouse / block / source id)
  final int itemIndex; // index inside the parent invoice items list
  final String description;
  final String unit; // measurement unit label (متر مربع، متر مكعب، طن، قطعة…)
  final double quantity; // returned quantity in the line's own unit
  final double unitPrice; // original unit price from the parent invoice
  final double amount; // quantity * unitPrice (rounded to 2 decimals)
  final String sourceType; // workshop source classification when applicable
  final String sourceLineItemId; // tailoring line item when applicable

  AdjustmentLineModel({
    required this.itemId,
    this.itemIndex = -1,
    required this.description,
    this.unit = '',
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.sourceType = '',
    this.sourceLineItemId = '',
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'itemIndex': itemIndex,
    'description': description,
    'unit': unit,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'amount': amount,
    'sourceType': sourceType,
    'sourceLineItemId': sourceLineItemId,
  };

  factory AdjustmentLineModel.fromJson(Map<String, dynamic> json) =>
      AdjustmentLineModel(
        itemId: json['itemId'] ?? '',
        itemIndex: json['itemIndex'] ?? -1,
        description: json['description'] ?? '',
        unit: json['unit'] ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        sourceType: json['sourceType'] ?? '',
        sourceLineItemId: json['sourceLineItemId'] ?? '',
      );
}

class AdjustmentInvoiceModel {
  final String id;
  final String invoiceNo;
  final String module;
  final String kind;
  final String targetInvoiceId;
  final String targetInvoiceNo;
  final String itemId;
  final String itemDescription;
  final int itemIndex;
  final String partyName;
  final String description;
  final double amount;
  final double quantity;
  final String paymentAction;
  final String currency;
  final DateTime date;
  /// Every line of this document (multi-line returns). Legacy single-item
  /// records simply carry an empty list and use the scalar fields above.
  final List<AdjustmentLineModel> lines;

  AdjustmentInvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.module,
    required this.kind,
    required this.targetInvoiceId,
    required this.targetInvoiceNo,
    this.itemId = '',
    this.itemDescription = '',
    this.itemIndex = -1,
    required this.partyName,
    required this.description,
    required this.amount,
    this.quantity = 0,
    this.paymentAction = 'تخفيض دين',
    required this.currency,
    DateTime? date,
    this.lines = const [],
  }) : date = date ?? DateTime.now();

  bool get isReturn => kind.endsWith('return');
  bool get isPurchase => kind.startsWith('purchase');

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNo': invoiceNo,
    'module': module,
    'kind': kind,
    'targetInvoiceId': targetInvoiceId,
    'targetInvoiceNo': targetInvoiceNo,
    'itemId': itemId,
    'itemDescription': itemDescription,
    'itemIndex': itemIndex,
    'partyName': partyName,
    'description': description,
    'amount': amount,
    'quantity': quantity,
    'paymentAction': paymentAction,
    'currency': currency,
    'date': date.toIso8601String(),
    'lines': lines.map((line) => line.toJson()).toList(),
  };

  factory AdjustmentInvoiceModel.fromJson(Map<String, dynamic> json) =>
      AdjustmentInvoiceModel(
        id: json['id'],
        invoiceNo: json['invoiceNo'],
        module: json['module'],
        kind: json['kind'],
        targetInvoiceId: json['targetInvoiceId'],
        targetInvoiceNo: json['targetInvoiceNo'],
        itemId: json['itemId'] ?? '',
        itemDescription: json['itemDescription'] ?? '',
        itemIndex: json['itemIndex'] ?? -1,
        partyName: json['partyName'],
        description: json['description'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        quantity: (json['quantity'] ?? 0).toDouble(),
        paymentAction: json['paymentAction'] ?? 'تخفيض دين',
        currency: AppCurrency.normalize(json['currency']),
        date: DateTime.parse(json['date']),
        lines: json['lines'] != null
            ? (json['lines'] as List)
                  .map((line) => AdjustmentLineModel.fromJson(line))
                  .toList()
            : const [],
      );
}

// ==========================================
// 2. PARTNER MODEL
// ==========================================
class PartnerModel {
  final String id;
  final String name;
  double ratio; // e.g. 0.42
  double injectedCapital;
  double totalWithdrawn;
  double injectedCapitalSyp;
  double totalWithdrawnSyp;

  PartnerModel({
    required this.id,
    required this.name,
    required this.ratio,
    required this.injectedCapital,
    this.totalWithdrawn = 0.0,
    this.injectedCapitalSyp = 0.0,
    this.totalWithdrawnSyp = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ratio': ratio,
    'injectedCapital': injectedCapital,
    'totalWithdrawn': totalWithdrawn,
    'injectedCapitalSyp': injectedCapitalSyp,
    'totalWithdrawnSyp': totalWithdrawnSyp,
  };

  factory PartnerModel.fromJson(Map<String, dynamic> json) => PartnerModel(
    id: json['id'],
    name: json['name'],
    ratio: (json['ratio'] as num).toDouble(),
    injectedCapital: (json['injectedCapital'] as num).toDouble(),
    totalWithdrawn: (json['totalWithdrawn'] as num).toDouble(),
    injectedCapitalSyp: (json['injectedCapitalSyp'] ?? 0).toDouble(),
    totalWithdrawnSyp: (json['totalWithdrawnSyp'] ?? 0).toDouble(),
  );
}

class CapitalInjectionRecordModel {
  final String id;
  final String partnerId;
  final String partnerName;
  final double amount;
  final String currency;
  final String destinationSafe;
  final DateTime date;
  final String notes;
  final double oldTotalCapital;
  final double newTotalCapital;
  final double oldPartnerShare;
  final double newPartnerShare;
  final double oldRatio;
  final double newRatio;

  CapitalInjectionRecordModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.amount,
    this.currency = AppCurrency.usd,
    this.destinationSafe = 'main',
    DateTime? date,
    this.notes = '',
    this.oldTotalCapital = 0.0,
    this.newTotalCapital = 0.0,
    this.oldPartnerShare = 0.0,
    this.newPartnerShare = 0.0,
    this.oldRatio = 0.0,
    this.newRatio = 0.0,
  }) : date = date ?? DateTime.now();

  /// Standard transaction log entry required by specification:
  /// Capital Injection - Partner: [Partner Name] - Amount: [A] [Currency]
  String get logEntryTitle =>
      'Capital Injection - Partner: $partnerName - Amount: ${amount.fmt} ${AppCurrency.symbol(currency)}';

  String get logEntryTitleAr =>
      'حقن رأس مال - الشريك: $partnerName - المبلغ: ${amount.fmt} ${AppCurrency.symbol(currency)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'amount': amount,
    'currency': currency,
    'destinationSafe': destinationSafe,
    'date': date.toIso8601String(),
    'notes': notes,
    'oldTotalCapital': oldTotalCapital,
    'newTotalCapital': newTotalCapital,
    'oldPartnerShare': oldPartnerShare,
    'newPartnerShare': newPartnerShare,
    'oldRatio': oldRatio,
    'newRatio': newRatio,
  };

  factory CapitalInjectionRecordModel.fromJson(Map<String, dynamic> json) =>
      CapitalInjectionRecordModel(
        id: json['id'] ?? '',
        partnerId: json['partnerId'] ?? '',
        partnerName: json['partnerName'] ?? '',
        amount: (json['amount'] ?? 0.0).toDouble(),
        currency: AppCurrency.normalize(json['currency']),
        destinationSafe: json['destinationSafe'] ?? 'main',
        date: json['date'] != null
            ? DateTime.parse(json['date'])
            : DateTime.now(),
        notes: json['notes'] ?? '',
        oldTotalCapital: (json['oldTotalCapital'] ?? 0.0).toDouble(),
        newTotalCapital: (json['newTotalCapital'] ?? 0.0).toDouble(),
        oldPartnerShare: (json['oldPartnerShare'] ?? 0.0).toDouble(),
        newPartnerShare: (json['newPartnerShare'] ?? 0.0).toDouble(),
        oldRatio: (json['oldRatio'] ?? 0.0).toDouble(),
        newRatio: (json['newRatio'] ?? 0.0).toDouble(),
      );
}

// ==========================================
// 3. SUPPLIER & CLIENT MODELS
// ==========================================
class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final String location;
  double debtBalance; // USD — Us to Supplier (علينا للمورد)
  double debtBalanceSyp; // SYP — same person can hold both currencies

  SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    this.debtBalance = 0.0,
    this.debtBalanceSyp = 0.0,
  });

  double debtOf(String? currency) =>
      AppCurrency.isSyp(currency) ? debtBalanceSyp : debtBalance;

  void addDebt(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      debtBalanceSyp += amount;
    } else {
      debtBalance += amount;
    }
  }

  void reduceDebt(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      debtBalanceSyp = (debtBalanceSyp - amount).clamp(0.0, double.infinity);
    } else {
      debtBalance = (debtBalance - amount).clamp(0.0, double.infinity);
    }
  }

  String get dualDebt => AppCurrency.dual(debtBalance, debtBalanceSyp);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'location': location,
    'debtBalance': debtBalance,
    'debtBalanceSyp': debtBalanceSyp,
  };

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: json['id'],
    name: json['name'],
    phone: json['phone'] ?? '',
    location: json['location'] ?? '',
    debtBalance: (json['debtBalance'] ?? 0.0).toDouble(),
    debtBalanceSyp: (json['debtBalanceSyp'] ?? 0.0).toDouble(),
  );
}

class ClientModel {
  final String id;
  final String name;
  final String phone;
  final String location;
  final String clientType; // 'معتمد مصنع' | 'زبون معمل' | 'مشروع معمل'
  final String description;
  double debtBalance; // USD — Client to us (لنا على الزبون)
  double debtBalanceSyp; // SYP — same person can hold both currencies
  String? _currencyClassification;

  ClientModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.location = '',
    required this.clientType,
    this.description = '',
    this.debtBalance = 0.0,
    this.debtBalanceSyp = 0.0,
    String? currencyClassification,
  }) : _currencyClassification = (currencyClassification != null && currencyClassification.isNotEmpty)
            ? AppCurrency.normalize(currencyClassification)
            : null;

  String get currencyClassification {
    if (_currencyClassification != null && _currencyClassification!.isNotEmpty) {
      return _currencyClassification!;
    }
    return debtBalanceSyp > 0.01 && debtBalance <= 0.01 ? AppCurrency.syp : AppCurrency.usd;
  }

  set currencyClassification(String? value) {
    if (value != null && value.isNotEmpty) {
      _currencyClassification = AppCurrency.normalize(value);
    }
  }

  bool get isSypCustomer => AppCurrency.isSyp(currencyClassification);
  bool get isUsdCustomer => !isSypCustomer;

  String get currencyClassificationLabel =>
      isSypCustomer ? 'SYP Customer' : 'USD Customer';

  String get currencyClassificationLabelAr =>
      isSypCustomer ? 'زبون ليرة سورية' : 'زبون دولار';

  double debtOf(String? currency) =>
      AppCurrency.isSyp(currency) ? debtBalanceSyp : debtBalance;

  void addDebt(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      debtBalanceSyp += amount;
    } else {
      debtBalance += amount;
    }
  }

  void reduceDebt(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      debtBalanceSyp = (debtBalanceSyp - amount).clamp(0.0, double.infinity);
    } else {
      debtBalance = (debtBalance - amount).clamp(0.0, double.infinity);
    }
  }

  String get dualDebt => AppCurrency.dual(debtBalance, debtBalanceSyp);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'location': location,
    'clientType': clientType,
    'description': description,
    'debtBalance': debtBalance,
    'debtBalanceSyp': debtBalanceSyp,
    'currencyClassification': currencyClassification,
  };

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'],
    name: json['name'],
    phone: json['phone'] ?? '',
    location: json['location'] ?? '',
    clientType: json['clientType'] ?? 'زبون معمل',
    description: json['description'] ?? '',
    debtBalance: (json['debtBalance'] ?? 0.0).toDouble(),
    debtBalanceSyp: (json['debtBalanceSyp'] ?? 0.0).toDouble(),
    currencyClassification: json['currencyClassification'],
  );
}

// ==========================================
// 4. BLOCK TYPES & METER TYPES
// ==========================================
class BlockTypeModel {
  final String id;
  final String typeName; // e.g. "رخام كاردينال", "غرانيت أسود جالكسي"
  final String grade; // "درجة أولى", "درجة ثانية", "ممتاز"
  final bool isGranite;

  BlockTypeModel({
    required this.id,
    required this.typeName,
    required this.grade,
    this.isGranite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeName': typeName,
    'grade': grade,
    'isGranite': isGranite,
  };

  factory BlockTypeModel.fromJson(Map<String, dynamic> json) => BlockTypeModel(
    id: json['id'],
    typeName: json['typeName'],
    grade: json['grade'] ?? 'درجة أولى',
    isGranite: json['isGranite'] ?? false,
  );
}

class MeterTypeModel {
  final String id;
  final String typeName;
  final String grade;
  final double thicknessCm;
  final String category; // 'متر مربع' (<=5cm) | 'متر مكعب' (>5cm)
  final bool isGranite;

  MeterTypeModel({
    required this.id,
    required this.typeName,
    required this.grade,
    required this.thicknessCm,
    required this.category,
    this.isGranite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeName': typeName,
    'grade': grade,
    'thicknessCm': thicknessCm,
    'category': category,
    'isGranite': isGranite,
  };

  factory MeterTypeModel.fromJson(Map<String, dynamic> json) => MeterTypeModel(
    id: json['id'],
    typeName: json['typeName'],
    grade: json['grade'] ?? 'درجة أولى',
    thicknessCm: (json['thicknessCm'] as num).toDouble(),
    category: json['category'] ?? 'متر مربع',
    isGranite: json['isGranite'] ?? false,
  );
}

// ==========================================
// 5. FACTORY BLOCK STOCK
// ==========================================
class FactoryBlockModel {
  final String id;
  final String blockCode;
  final String typeName;
  final String grade;
  final String supplierId;
  final String supplierName;
  double weightTons;
  double tonCost;
  double tonSellingPrice;
  final bool isGranite;

  FactoryBlockModel({
    required this.id,
    required this.blockCode,
    required this.typeName,
    required this.grade,
    required this.supplierId,
    required this.supplierName,
    required this.weightTons,
    required this.tonCost,
    this.tonSellingPrice = 0.0,
    this.isGranite = false,
  });

  double get totalCost => weightTons * tonCost;

  Map<String, dynamic> toJson() => {
    'id': id,
    'blockCode': blockCode,
    'typeName': typeName,
    'grade': grade,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'weightTons': weightTons,
    'tonCost': tonCost,
    'tonSellingPrice': tonSellingPrice,
    'isGranite': isGranite,
  };

  factory FactoryBlockModel.fromJson(Map<String, dynamic> json) =>
      FactoryBlockModel(
        id: json['id'],
        blockCode: json['blockCode'],
        typeName: json['typeName'],
        grade: json['grade'],
        supplierId: json['supplierId'],
        supplierName: json['supplierName'],
        weightTons: (json['weightTons'] as num).toDouble(),
        tonCost: (json['tonCost'] as num).toDouble(),
        tonSellingPrice: (json['tonSellingPrice'] as num?)?.toDouble() ?? 0.0,
        isGranite: json['isGranite'] ?? false,
      );
}

// ==========================================
// 6. FACTORY WAREHOUSE ITEM (Slabs & Cubes)
// ==========================================
class FactoryWarehouseModel {
  final String id;
  final String typeName;
  final String grade;
  final double thicknessCm;
  final String category; // 'متر مربع' (<=5cm) or 'متر مكعب' (>5cm)
  double availableQty; // m² or m³
  double netCostPerUnit;
  double recommendedSalePrice;
  final bool isGranite;

  FactoryWarehouseModel({
    required this.id,
    required this.typeName,
    required this.grade,
    required this.thicknessCm,
    required this.category,
    required this.availableQty,
    required this.netCostPerUnit,
    required this.recommendedSalePrice,
    this.isGranite = false,
  });

  double get totalInventoryValue => availableQty * netCostPerUnit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeName': typeName,
    'grade': grade,
    'thicknessCm': thicknessCm,
    'category': category,
    'availableQty': availableQty,
    'netCostPerUnit': netCostPerUnit,
    'recommendedSalePrice': recommendedSalePrice,
    'isGranite': isGranite,
  };

  factory FactoryWarehouseModel.fromJson(Map<String, dynamic> json) =>
      FactoryWarehouseModel(
        id: json['id'],
        typeName: json['typeName'],
        grade: json['grade'],
        thicknessCm: (json['thicknessCm'] as num).toDouble(),
        category: json['category'],
        availableQty: (json['availableQty'] as num).toDouble(),
        netCostPerUnit: (json['netCostPerUnit'] as num).toDouble(),
        recommendedSalePrice: (json['recommendedSalePrice'] as num).toDouble(),
        isGranite: json['isGranite'] ?? false,
      );
}

// ==========================================
// 7. CUTTING OPERATION LOG
// ==========================================
class CuttingOperationModel {
  final String id;
  final DateTime timestamp;
  final double inputTons;
  final double baseTonCost;
  final double cuttingFeePercentage; // 0.07, 0.08, or 0.09
  final String targetTypeName;
  final String targetGrade;
  final double thicknessCm;
  final String category; // 'متر مربع' or 'متر مكعب'
  final double totalOutputArea; // m² or m³
  final double netCostPerUnit;
  final double recommendedSalePrice;
  final double wasteValue;
  final bool isGranite;

  CuttingOperationModel({
    required this.id,
    required this.timestamp,
    required this.inputTons,
    required this.baseTonCost,
    required this.cuttingFeePercentage,
    required this.targetTypeName,
    required this.targetGrade,
    required this.thicknessCm,
    required this.category,
    required this.totalOutputArea,
    required this.netCostPerUnit,
    required this.recommendedSalePrice,
    required this.wasteValue,
    this.isGranite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'inputTons': inputTons,
    'baseTonCost': baseTonCost,
    'cuttingFeePercentage': cuttingFeePercentage,
    'targetTypeName': targetTypeName,
    'targetGrade': targetGrade,
    'thicknessCm': thicknessCm,
    'category': category,
    'totalOutputArea': totalOutputArea,
    'netCostPerUnit': netCostPerUnit,
    'recommendedSalePrice': recommendedSalePrice,
    'wasteValue': wasteValue,
    'isGranite': isGranite,
  };

  factory CuttingOperationModel.fromJson(Map<String, dynamic> json) =>
      CuttingOperationModel(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        inputTons: (json['inputTons'] as num).toDouble(),
        baseTonCost: (json['baseTonCost'] as num).toDouble(),
        cuttingFeePercentage: (json['cuttingFeePercentage'] as num).toDouble(),
        targetTypeName: json['targetTypeName'],
        targetGrade: json['targetGrade'],
        thicknessCm: (json['thicknessCm'] as num).toDouble(),
        category: json['category'],
        totalOutputArea: (json['totalOutputArea'] as num).toDouble(),
        netCostPerUnit: (json['netCostPerUnit'] as num).toDouble(),
        recommendedSalePrice: (json['recommendedSalePrice'] as num).toDouble(),
        wasteValue: (json['wasteValue'] as num).toDouble(),
        isGranite: json['isGranite'] ?? false,
      );
}

// ==========================================
// 8. FACTORY INVOICES (Purchase & POS Sales)
// ==========================================
class FactoryInvoiceItem {
  final String itemId; // warehouse or block ID
  final String description;
  final String typeName; // block type (e.g. بازلت)
  final String grade; // block grade (e.g. درجة أولى)
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final bool isGranite;
  final List<ServiceAttachment> services; // services attached to this line item
  final String itemCategory; // 'block' | 'meter'
  final double thicknessCm;
  final String meterUnit; // 'متر مربع' | 'متر طولي' | 'متر مكعب'

  FactoryInvoiceItem({
    required this.itemId,
    required this.description,
    this.typeName = '',
    this.grade = '',
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    this.isGranite = false,
    this.services = const [],
    this.itemCategory = 'block',
    this.thicknessCm = 0.0,
    this.meterUnit = 'متر مربع',
  });

  bool get isCubicMeter =>
      meterUnit == 'متر مكعب' ||
      itemCategory == 'متر مكعب' ||
      (heightCm > 5.0 && meterUnit != 'متر مربع' && meterUnit != 'متر طولي');

  bool get isMeterItem =>
      itemCategory == 'meter' ||
      itemCategory == 'متر' ||
      itemCategory == 'متر مربع' ||
      itemCategory == 'متر مكعب' ||
      itemId.startsWith('fw') ||
      (itemCategory != 'block' &&
          itemCategory != 'tailoring' &&
          (meterUnit == 'متر مكعب' ||
              meterUnit == 'متر طولي' ||
              thicknessCm > 0 ||
              (lengthCm > 0 && widthCm > 0 && !itemId.startsWith('fb'))));

  bool get isTailoringItem =>
      itemCategory == 'tailoring' ||
      itemCategory == 'تفصيل' ||
      itemId.startsWith('tailoring_');

  double get calculatedArea {
    if (isCubicMeter || (heightCm > 0 && meterUnit != 'متر مربع' && meterUnit != 'متر طولي' && heightCm > 5.0)) {
      // Volume m³: Length(m) * Width(m) * Height(m) * Quantity
      if (lengthCm > 0 && widthCm > 0 && heightCm > 0) {
        return (lengthCm / 100.0) *
            (widthCm / 100.0) *
            (heightCm / 100.0) *
            quantity;
      }
      return quantity;
    } else if (lengthCm > 0 && widthCm > 0) {
      // Area m²: Length(m) * Width(m) * Quantity
      return (lengthCm / 100.0) * (widthCm / 100.0) * quantity;
    }
    return quantity; // Default unit quantity (e.g. Tons, meters, or pcs)
  }

  double get totalPrice => calculatedArea * unitPrice;
  double get subtotal => totalPrice;
  double get totalCost => calculatedArea * unitCost;
  double get servicesTotal => services.fold(0.0, (sum, s) => sum + s.price);
  double get grandTotal => totalPrice + servicesTotal;

  FactoryInvoiceItem copyWith({
    String? itemId,
    String? description,
    String? typeName,
    String? grade,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    double? quantity,
    double? unitPrice,
    double? unitCost,
    bool? isGranite,
    List<ServiceAttachment>? services,
    String? itemCategory,
    double? thicknessCm,
    String? meterUnit,
  }) =>
      FactoryInvoiceItem(
        itemId: itemId ?? this.itemId,
        description: description ?? this.description,
        typeName: typeName ?? this.typeName,
        grade: grade ?? this.grade,
        lengthCm: lengthCm ?? this.lengthCm,
        widthCm: widthCm ?? this.widthCm,
        heightCm: heightCm ?? this.heightCm,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        unitCost: unitCost ?? this.unitCost,
        isGranite: isGranite ?? this.isGranite,
        services: services ?? List.of(this.services),
        itemCategory: itemCategory ?? this.itemCategory,
        thicknessCm: thicknessCm ?? this.thicknessCm,
        meterUnit: meterUnit ?? this.meterUnit,
      );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'description': description,
    'typeName': typeName,
    'grade': grade,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'unitCost': unitCost,
    'isGranite': isGranite,
    'services': services.map((s) => s.toJson()).toList(),
    'itemCategory': itemCategory,
    'thicknessCm': thicknessCm,
    'meterUnit': meterUnit,
  };

  factory FactoryInvoiceItem.fromJson(Map<String, dynamic> json) =>
      FactoryInvoiceItem(
        itemId: json['itemId'] ?? '',
        description: json['description'] ?? '',
        typeName: json['typeName'] ?? json['description'] ?? '',
        grade: json['grade'] ?? '',
        lengthCm: (json['lengthCm'] ?? 0.0).toDouble(),
        widthCm: (json['widthCm'] ?? 0.0).toDouble(),
        heightCm: (json['heightCm'] ?? 0.0).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        unitCost: (json['unitCost'] as num).toDouble(),
        isGranite: json['isGranite'] ?? false,
        services: json['services'] != null
            ? (json['services'] as List)
                  .map((s) => ServiceAttachment.fromJson(s))
                  .toList()
            : [],
        itemCategory: json['itemCategory'] ?? (json['isMeter'] == true ? 'meter' : 'block'),
        thicknessCm: (json['thicknessCm'] ?? 0.0).toDouble(),
        meterUnit: json['meterUnit'] ?? 'متر مربع',
      );
}

class ServiceAttachment {
  final String serviceName;
  final double price;
  final String notes;

  ServiceAttachment({
    required this.serviceName,
    required this.price,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'price': price,
    'notes': notes,
  };

  factory ServiceAttachment.fromJson(Map<String, dynamic> json) =>
      ServiceAttachment(
        serviceName: json['serviceName'],
        price: (json['price'] as num).toDouble(),
        notes: json['notes'] ?? '',
      );
}

class FactoryInvoiceModel {
  final String id;
  final String invoiceNo;
  final DateTime date;
  final String partyId; // Supplier ID or Client ID
  final String partyName;
  final String invoiceType; // 'شراء_مورد' | 'بيع_معتمد'
  final List<FactoryInvoiceItem> items;
  final List<ServiceAttachment> services;
  final double shippingFee; // Noulon / Delivery fee
  final bool isGoodsDelivered; // Shipping toggle
  double advancePayment; // mutable: grows as dues are paid / collected
  final double discountAmount;
  double adjustmentsAmount;
  final String photoUrl;
  final bool isCashInvoice;
  String paymentStatus; // 'مستحق الدفع' | 'مدفوعة'
  final String
  currency; // AppCurrency.usd ('USD' $) | AppCurrency.syp ('SYP' ل.س)

  FactoryInvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.partyId,
    required this.partyName,
    required this.invoiceType,
    required this.items,
    this.services = const [],
    this.shippingFee = 0.0,
    this.isGoodsDelivered = true,
    this.advancePayment = 0.0,
    this.discountAmount = 0.0,
    this.adjustmentsAmount = 0.0,
    this.photoUrl = '',
    this.isCashInvoice = false,
    this.paymentStatus = 'تم الدفع',
    this.currency = AppCurrency.usd,
  });

  String get currencySymbol => AppCurrency.symbol(currency);

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get itemsServicesTotal =>
      items.fold(0.0, (sum, item) => sum + item.servicesTotal);
  double get servicesTotal => services.fold(0.0, (sum, s) => sum + s.price);
  double get grandTotal {
    if (invoiceType == 'شراء_مورد') {
      return (subtotal +
              itemsServicesTotal +
              servicesTotal -
              discountAmount)
          .clamp(0.0, double.infinity);
    }
    return (subtotal +
            itemsServicesTotal +
            servicesTotal +
            shippingFee -
            discountAmount)
        .clamp(0.0, double.infinity);
  }
  double get remainingBalance =>
      grandTotal - advancePayment - adjustmentsAmount;

  /// Due (مستحق الدفع) when any balance remains, otherwise Paid (مدفوعة).
  bool get isDue => remainingBalance > 0.01;

  double get totalCOGS => items.fold(0.0, (sum, item) => sum + item.totalCost);

  bool get containsGranite => items.any((i) => i.isGranite);

  double get graniteProfit {
    double rev = 0.0;
    double cogs = 0.0;
    for (var item in items) {
      if (item.isGranite) {
        rev += item.totalPrice;
        cogs += item.totalCost;
      }
    }
    return rev - cogs;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNo': invoiceNo,
    'date': date.toIso8601String(),
    'partyId': partyId,
    'partyName': partyName,
    'invoiceType': invoiceType,
    'items': items.map((i) => i.toJson()).toList(),
    'services': services.map((s) => s.toJson()).toList(),
    'shippingFee': shippingFee,
    'isGoodsDelivered': isGoodsDelivered,
    'advancePayment': advancePayment,
    'discountAmount': discountAmount,
    'adjustmentsAmount': adjustmentsAmount,
    'photoUrl': photoUrl,
    'isCashInvoice': isCashInvoice,
    'paymentStatus': paymentStatus,
    'currency': currency,
  };

  factory FactoryInvoiceModel.fromJson(Map<String, dynamic> json) =>
      FactoryInvoiceModel(
        id: json['id'],
        invoiceNo: json['invoiceNo'],
        date: DateTime.parse(json['date']),
        partyId: json['partyId'],
        partyName: json['partyName'],
        invoiceType: json['invoiceType'],
        items: (json['items'] as List)
            .map((i) => FactoryInvoiceItem.fromJson(i))
            .toList(),
        services: json['services'] != null
            ? (json['services'] as List)
                  .map((s) => ServiceAttachment.fromJson(s))
                  .toList()
            : [],
        shippingFee: (json['shippingFee'] ?? 0.0).toDouble(),
        isGoodsDelivered: json['isGoodsDelivered'] ?? true,
        advancePayment: (json['advancePayment'] ?? 0.0).toDouble(),
        discountAmount: (json['discountAmount'] ?? 0.0).toDouble(),
        adjustmentsAmount: (json['adjustmentsAmount'] ?? 0.0).toDouble(),
        photoUrl: json['photoUrl'] ?? '',
        isCashInvoice: json['isCashInvoice'] ?? false,
        paymentStatus: json['paymentStatus'] ?? 'تم الدفع',
        currency: AppCurrency.normalize(json['currency']),
      );
}

// ==========================================
// 9. WORKSHOP STOCK & TAILORING ITEMS
// ==========================================
class WorkshopStockModel {
  final String id;
  final String typeName;
  final String grade;
  final double thicknessCm;
  final String category; // 'متر مربع' or 'متر مكعب'
  double availableQty;
  double netCostPerUnit;
  double recommendedSalePrice;
  final bool isGranite;

  WorkshopStockModel({
    required this.id,
    required this.typeName,
    required this.grade,
    required this.thicknessCm,
    required this.category,
    required this.availableQty,
    required this.netCostPerUnit,
    required this.recommendedSalePrice,
    this.isGranite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeName': typeName,
    'grade': grade,
    'thicknessCm': thicknessCm,
    'category': category,
    'availableQty': availableQty,
    'netCostPerUnit': netCostPerUnit,
    'recommendedSalePrice': recommendedSalePrice,
    'isGranite': isGranite,
  };

  factory WorkshopStockModel.fromJson(Map<String, dynamic> json) =>
      WorkshopStockModel(
        id: json['id'],
        typeName: json['typeName'],
        grade: json['grade'],
        thicknessCm: (json['thicknessCm'] as num).toDouble(),
        category: json['category'],
        availableQty: (json['availableQty'] as num).toDouble(),
        netCostPerUnit: (json['netCostPerUnit'] as num).toDouble(),
        recommendedSalePrice: (json['recommendedSalePrice'] as num).toDouble(),
        isGranite: json['isGranite'] ?? false,
      );
}

/// One material line inside a tailored piece (materials or scrap source).
class TailoringLineItem {
  final String id;
  final String source; // 'materials' | 'scrap'
  final String stockId; // workshopStock id or scrap id
  final String typeName;
  final String grade;
  final double thicknessCm;
  final String category; // 'متر مربع' | 'متر مكعب'
  double lengthCm;
  double widthCm;
  double heightCm;
  double quantity;
  double netCostPerMeter;
  double sellingPricePerMeter;
  double laborPerMeter;
  final List<ServiceAttachment> services;

  TailoringLineItem({
    required this.id,
    required this.source,
    required this.stockId,
    required this.typeName,
    required this.grade,
    required this.thicknessCm,
    required this.category,
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    required this.quantity,
    required this.netCostPerMeter,
    required this.sellingPricePerMeter,
    this.laborPerMeter = 0.0,
    this.services = const [],
  });

  double get area {
    if (category == 'متر مكعب') {
      if (lengthCm <= 0 || widthCm <= 0 || heightCm <= 0 || quantity <= 0) {
        return 0.0;
      }
      return (lengthCm / 100.0) *
          (widthCm / 100.0) *
          (heightCm / 100.0) *
          quantity;
    }
    if (lengthCm <= 0 || widthCm <= 0 || quantity <= 0) return 0.0;
    return (lengthCm / 100.0) * (widthCm / 100.0) * quantity;
  }

  double get materialCost => area * netCostPerMeter;
  double get servicesTotal => services.fold(0.0, (s, e) => s + e.price);
  double get netCostPerMeterAfterServices =>
      area > 0 ? (materialCost + servicesTotal) / area : netCostPerMeter;
  double get lineTotal =>
      (area * sellingPricePerMeter) + (laborPerMeter * area) + servicesTotal;
  String get description =>
      typeName.isNotEmpty ? '$typeName $grade'.trim() : 'بند تفصيل';

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'stockId': stockId,
    'typeName': typeName,
    'grade': grade,
    'thicknessCm': thicknessCm,
    'category': category,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'quantity': quantity,
    'netCostPerMeter': netCostPerMeter,
    'sellingPricePerMeter': sellingPricePerMeter,
    'laborPerMeter': laborPerMeter,
    'services': services.map((s) => s.toJson()).toList(),
  };

  factory TailoringLineItem.fromJson(Map<String, dynamic> json) =>
      TailoringLineItem(
        id: json['id'],
        source: json['source'] ?? 'materials',
        stockId: json['stockId'] ?? '',
        typeName: json['typeName'] ?? '',
        grade: json['grade'] ?? '',
        thicknessCm: (json['thicknessCm'] ?? 0.0).toDouble(),
        category: json['category'] ?? 'متر مربع',
        lengthCm: (json['lengthCm'] ?? 0.0).toDouble(),
        widthCm: (json['widthCm'] ?? 0.0).toDouble(),
        heightCm: (json['heightCm'] ?? 0.0).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        netCostPerMeter: (json['netCostPerMeter'] ?? 0.0).toDouble(),
        sellingPricePerMeter: (json['sellingPricePerMeter'] ?? 0.0).toDouble(),
        laborPerMeter: json['laborPerMeter'] != null
            ? (json['laborPerMeter'] as num).toDouble()
            : _legacyLaborPerMeter(json),
        services: json['services'] != null
            ? (json['services'] as List)
                  .map((s) => ServiceAttachment.fromJson(s))
                  .toList()
            : [],
      );
}

class WorkshopTailoringModel {
  final String id;
  final String name;
  final String complexity; // 'بسيط' | 'معقد' | 'جاهزة'
  final String rawMaterialDescription;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final String unitCategory;
  final double measurementCount;
  double quantity;
  final double materialNetCost;
  final double laborCostPerMeter;
  final List<ServiceAttachment> attachedServices;
  final List<TailoringLineItem> lineItems;
  final String photoPath;
  double sellingPrice;
  final bool isGranite;

  WorkshopTailoringModel({
    required this.id,
    required this.name,
    required this.complexity,
    required this.rawMaterialDescription,
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    this.unitCategory = 'متر مربع',
    this.measurementCount = 1.0,
    required this.quantity,
    required this.materialNetCost,
    this.laborCostPerMeter = 0.0,
    this.attachedServices = const [],
    this.lineItems = const [],
    this.photoPath = '',
    required this.sellingPrice,
    this.isGranite = false,
  });

  double get totalLaborCost => laborCostPerMeter * quantity;
  double get measurementPerCount {
    if (lengthCm <= 0 || widthCm <= 0) return 0;
    final area = (lengthCm / 100) * (widthCm / 100);
    return unitCategory == 'متر مكعب'
        ? heightCm <= 0
              ? 0
              : area * (heightCm / 100)
        : area;
  }

  String get unitSymbol => unitCategory == 'متر مكعب' ? 'م³' : 'م²';
  double get totalServicesCost =>
      attachedServices.fold(0.0, (s, e) => s + e.price) +
      lineItems.fold(0.0, (s, l) => s + l.servicesTotal);
  double get linesMaterialCost =>
      lineItems.fold(0.0, (s, l) => s + l.materialCost);
  double get totalNetCost =>
      materialNetCost + linesMaterialCost + totalLaborCost + totalServicesCost;
  double get costPerMeterAfterServices =>
      quantity > 0 ? (totalNetCost / quantity) : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'complexity': complexity,
    'rawMaterialDescription': rawMaterialDescription,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'unitCategory': unitCategory,
    'measurementCount': measurementCount,
    'quantity': quantity,
    'materialNetCost': materialNetCost,
    'laborCostPerMeter': laborCostPerMeter,
    'attachedServices': attachedServices.map((s) => s.toJson()).toList(),
    'lineItems': lineItems.map((l) => l.toJson()).toList(),
    'photoPath': photoPath,
    'sellingPrice': sellingPrice,
    'isGranite': isGranite,
  };

  factory WorkshopTailoringModel.fromJson(Map<String, dynamic> json) {
    final legacyQuantity = (json['quantity'] as num).toDouble();
    final lengthCm = (json['lengthCm'] ?? 0.0).toDouble();
    final widthCm = (json['widthCm'] ?? 0.0).toDouble();
    final heightCm = (json['heightCm'] ?? 0.0).toDouble();
    final legacyUnit = heightCm > 0 ? 'متر مكعب' : 'متر مربع';
    final hasMeterUnit = json['unitCategory'] != null;
    final unitCategory = json['unitCategory'] ?? legacyUnit;
    final measurePerItem = _tailoredMeasure(
      unitCategory,
      lengthCm,
      widthCm,
      heightCm,
    );
    final legacyLabor = (json['laborCostPerPiece'] ?? 0.0).toDouble();
    final legacySellingPrice = (json['sellingPrice'] as num).toDouble();
    return WorkshopTailoringModel(
      id: json['id'],
      name: json['name'],
      complexity: json['complexity'] ?? 'بسيط',
      rawMaterialDescription: json['rawMaterialDescription'] ?? '',
      lengthCm: lengthCm,
      widthCm: widthCm,
      heightCm: heightCm,
      unitCategory: unitCategory,
      measurementCount: (json['measurementCount'] ?? legacyQuantity).toDouble(),
      quantity: hasMeterUnit || measurePerItem <= 0
          ? legacyQuantity
          : legacyQuantity * measurePerItem,
      materialNetCost: (json['materialNetCost'] as num).toDouble(),
      laborCostPerMeter: json['laborCostPerMeter'] != null
          ? (json['laborCostPerMeter'] as num).toDouble()
          : measurePerItem > 0
          ? legacyLabor / measurePerItem
          : legacyLabor,
      attachedServices: json['attachedServices'] != null
          ? (json['attachedServices'] as List)
                .map((s) => ServiceAttachment.fromJson(s))
                .toList()
          : [],
      lineItems: json['lineItems'] != null
          ? (json['lineItems'] as List)
                .map((l) => TailoringLineItem.fromJson(l))
                .toList()
          : [],
      photoPath: json['photoPath'] ?? '',
      sellingPrice: hasMeterUnit || measurePerItem <= 0
          ? legacySellingPrice
          : legacySellingPrice / measurePerItem,
      isGranite: json['isGranite'] ?? false,
    );
  }

  static double _tailoredMeasure(
    String unit,
    double lengthCm,
    double widthCm,
    double heightCm,
  ) {
    if (lengthCm <= 0 || widthCm <= 0) return 0;
    final area = (lengthCm / 100) * (widthCm / 100);
    if (unit == 'متر مكعب') {
      return heightCm <= 0 ? 0 : area * (heightCm / 100);
    }
    return area;
  }
}

double _legacyLaborPerMeter(Map<String, dynamic> json) {
  final oldRate = (json['laborPerPiece'] ?? 0.0).toDouble();
  final length = (json['lengthCm'] ?? 0.0).toDouble();
  final width = (json['widthCm'] ?? 0.0).toDouble();
  final height = (json['heightCm'] ?? 0.0).toDouble();
  final unit = json['category'] ?? 'متر مربع';
  if (length <= 0 || width <= 0) return oldRate;
  var measure = (length / 100) * (width / 100);
  if (unit == 'متر مكعب') {
    if (height <= 0) return oldRate;
    measure *= height / 100;
  }
  return measure > 0 ? oldRate / measure : oldRate;
}

// ==========================================
// 10. SCRAP & EXTRA ITEMS (صندوق الزيادات)
// ==========================================
class ScrapItemModel {
  final String id;
  final String description;
  // Initial price (التكلفة الأولية). Mutable so later surplus costs can adjust it.
  // When 0/empty => 100% profit margin (no cost breakdown required).
  double baseCost;
  final double sellingPrice;
  final String photoPath;
  bool isSold;
  final String currency; // AppCurrency.usd | AppCurrency.syp

  ScrapItemModel({
    required this.id,
    required this.description,
    required this.baseCost,
    required this.sellingPrice,
    this.photoPath = '',
    this.isSold = false,
    this.currency = AppCurrency.usd,
  });

  /// Profit if sold: selling price minus initial cost.
  double get profit => sellingPrice - baseCost;

  /// Profit margin 0..1+. When baseCost is 0 => 100% margin (1.0) by rule.
  double get profitMargin => sellingPrice <= 0
      ? 0.0
      : (baseCost <= 0 ? 1.0 : (sellingPrice - baseCost) / sellingPrice);

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'baseCost': baseCost,
    'sellingPrice': sellingPrice,
    'photoPath': photoPath,
    'isSold': isSold,
    'currency': currency,
  };

  factory ScrapItemModel.fromJson(Map<String, dynamic> json) => ScrapItemModel(
    id: json['id'],
    description: json['description'],
    baseCost: (json['baseCost'] as num).toDouble(),
    sellingPrice: (json['sellingPrice'] as num).toDouble(),
    photoPath: json['photoPath'] ?? '',
    isSold: json['isSold'] ?? false,
    currency: AppCurrency.normalize(json['currency']),
  );
}

// ==========================================
// 10b. SURPLUS COST LEDGER (مالية الزيادات)
// One row per worker wage or general expense linked to a surplus item.
// kind: 'worker' (أجرة شخص/عامل) | 'expense' (مصروف: مواد، كهرباء، ماء...)
// Settlement is paid ONLY from the Surplus Fund (scrapCashBox).
// ==========================================
class SurplusCostModel {
  final String id;
  final String surplusItemId;
  final String surplusDescription;
  final String kind; // 'worker' | 'expense'
  final String beneficiaryName; // person name or expense description
  final String? staffId; // linked staff id when the worker exists in staffList
  double amountDue; // incurred cost (part of the initial price)
  double amountPaid; // settled so far from the Surplus Fund
  final DateTime date;
  final String notes;
  final String currency; // AppCurrency.usd | AppCurrency.syp

  SurplusCostModel({
    required this.id,
    required this.surplusItemId,
    required this.surplusDescription,
    required this.kind,
    required this.beneficiaryName,
    this.staffId,
    required this.amountDue,
    this.amountPaid = 0.0,
    DateTime? date,
    this.notes = '',
    this.currency = AppCurrency.usd,
  }) : date = date ?? DateTime.now();

  double get remaining => (amountDue - amountPaid).clamp(0.0, double.infinity);
  bool get isPaid => remaining <= 0.01;
  String get kindLabel => kind == 'worker' ? 'أجرة عامل/شخص' : 'مصروف';

  Map<String, dynamic> toJson() => {
    'id': id,
    'surplusItemId': surplusItemId,
    'surplusDescription': surplusDescription,
    'kind': kind,
    'beneficiaryName': beneficiaryName,
    'staffId': staffId,
    'amountDue': amountDue,
    'amountPaid': amountPaid,
    'date': date.toIso8601String(),
    'notes': notes,
    'currency': currency,
  };

  factory SurplusCostModel.fromJson(Map<String, dynamic> json) =>
      SurplusCostModel(
        id: json['id'],
        surplusItemId: json['surplusItemId'] ?? '',
        surplusDescription: json['surplusDescription'] ?? '',
        kind: json['kind'] ?? 'expense',
        beneficiaryName: json['beneficiaryName'] ?? '',
        staffId: json['staffId'],
        amountDue: (json['amountDue'] as num).toDouble(),
        amountPaid: (json['amountPaid'] ?? 0.0).toDouble(),
        date: json['date'] != null ? DateTime.parse(json['date']) : null,
        notes: json['notes'] ?? '',
        currency: AppCurrency.normalize(json['currency']),
      );
}

// ==========================================
// 11. WASTE LOG (هدر طبيعي وهدر غير طبيعي)
// ==========================================
class WasteLogModel {
  final String id;
  final DateTime date;
  final String wasteType; // 'هدر طبيعي' | 'هدر غير طبيعي'
  final String itemDescription;
  final double quantity;
  final double cost;
  final String destructionVoucherNo; // سند إتلاف for unnatural waste
  final String currency; // AppCurrency.usd | AppCurrency.syp

  WasteLogModel({
    required this.id,
    required this.date,
    required this.wasteType,
    required this.itemDescription,
    required this.quantity,
    required this.cost,
    this.destructionVoucherNo = '',
    this.currency = AppCurrency.usd,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'wasteType': wasteType,
    'itemDescription': itemDescription,
    'quantity': quantity,
    'cost': cost,
    'destructionVoucherNo': destructionVoucherNo,
    'currency': currency,
  };

  factory WasteLogModel.fromJson(Map<String, dynamic> json) => WasteLogModel(
    id: json['id'],
    date: DateTime.parse(json['date']),
    wasteType: json['wasteType'],
    itemDescription: json['itemDescription'],
    quantity: (json['quantity'] as num).toDouble(),
    cost: (json['cost'] as num).toDouble(),
    destructionVoucherNo: json['destructionVoucherNo'] ?? '',
    currency: AppCurrency.normalize(json['currency']),
  );
}

// ==========================================
// 12. WORKSHOP CUSTOM ORDERS (صندوق الطلبيات)
// ==========================================
class WorkshopOrderModel {
  final String id;
  final String orderNo;
  final DateTime date;
  final String clientName;
  final String clientPhone;
  final String customDimensionsText;
  final double agreedPrice;
  final double
  depositAmount; // Stored in Isolated Order Cash Box (صندوق الطلبيات)
  final String photoPath;
  String status; // 'قيد التنفيذ' | 'مكتملة ومرحلة' | 'ملغاة'
  bool isCompleted;
  bool isSpecialRefund;
  final String
  currency; // AppCurrency.usd | AppCurrency.syp — invoice inherits it
  final List<WorkshopInvoiceItem> items;

  WorkshopOrderModel({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.clientName,
    required this.clientPhone,
    required this.customDimensionsText,
    required this.agreedPrice,
    required this.depositAmount,
    this.photoPath = '',
    this.status = 'قيد التنفيذ',
    this.isCompleted = false,
    this.isSpecialRefund = false,
    this.currency = AppCurrency.usd,
    this.items = const [],
  });

  String get currencySymbol => AppCurrency.symbol(currency);

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNo': orderNo,
    'date': date.toIso8601String(),
    'clientName': clientName,
    'clientPhone': clientPhone,
    'customDimensionsText': customDimensionsText,
    'agreedPrice': agreedPrice,
    'depositAmount': depositAmount,
    'photoPath': photoPath,
    'status': status,
    'isCompleted': isCompleted,
    'isSpecialRefund': isSpecialRefund,
    'currency': currency,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory WorkshopOrderModel.fromJson(Map<String, dynamic> json) =>
      WorkshopOrderModel(
        id: json['id'],
        orderNo: json['orderNo'],
        date: DateTime.parse(json['date']),
        clientName: json['clientName'],
        clientPhone: json['clientPhone'] ?? '',
        customDimensionsText: json['customDimensionsText'] ?? '',
        agreedPrice: (json['agreedPrice'] as num).toDouble(),
        depositAmount: (json['depositAmount'] as num).toDouble(),
        photoPath: json['photoPath'] ?? '',
        status: json['status'] ?? 'قيد التنفيذ',
        isCompleted: json['isCompleted'] ?? false,
        isSpecialRefund: json['isSpecialRefund'] ?? false,
        currency: AppCurrency.normalize(json['currency']),
        items: json['items'] != null
            ? (json['items'] as List)
                .map((i) => WorkshopInvoiceItem.fromJson(i))
                .toList()
            : [],
      );
}

// ==========================================
// 12c. WORKSHOP ORDER CANCELLATION RAW MATERIAL ASSIGNMENT
// ==========================================
class RawMaterialTailoringAssignment {
  final String itemId;
  final String rawMaterialName;
  final double quantity;
  final String unitCategory;
  final bool isSimpleTailoring; // true = simple, false = complex
  final String? existingTailoringId; // if assigning to existing tailoring record
  final String? newTailoringName; // if creating a new tailoring type/name on the fly
  final double sellingPrice;

  const RawMaterialTailoringAssignment({
    required this.itemId,
    required this.rawMaterialName,
    required this.quantity,
    this.unitCategory = 'متر مربع',
    this.isSimpleTailoring = true,
    this.existingTailoringId,
    this.newTailoringName,
    this.sellingPrice = 0.0,
  });
}

// ==========================================
// 12b. WORKSHOP INVOICE ITEM (بند فاتورة المعمل)
// Each line item belongs to a specific source and has its own dedicated services.
// ==========================================
class WorkshopInvoiceItem {
  final String id;
  final String sourceType; // 'طلب معمل' | 'بيع خياطة بسيطة' | 'بيع خياطة معقدة' | 'بيع قطع إضافية' | 'بيع مواد خام من المعمل'
  final String sourceId; // order / tailoring / scrap / stock id
  final String sourceLineItemId; // specific line item id inside tailoring if applicable
  final String description;
  final double quantity;
  final String unitCategory; // 'متر مربع' | 'متر مكعب' | 'قطعة' | etc.
  final double unitPrice;
  final double agreedPrice; // subtotal for the item itself
  final double netCost;
  final double depositAmount; // deposit from order if applicable
  final bool isGranite;
  final List<ServiceAttachment> services; // dedicated services for this line item
  final String photoPath;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double count;

  WorkshopInvoiceItem({
    required this.id,
    required this.sourceType,
    this.sourceId = '',
    this.sourceLineItemId = '',
    required this.description,
    this.quantity = 1.0,
    this.unitCategory = 'متر مربع',
    this.unitPrice = 0.0,
    required this.agreedPrice,
    this.netCost = 0.0,
    this.depositAmount = 0.0,
    this.isGranite = false,
    this.services = const [],
    this.photoPath = '',
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    this.count = 0.0,
  });

  bool get isCubicMeter => unitCategory == 'متر مكعب';

  double get thicknessCm => heightCm;

  double get effectiveCount {
    if (count > 0) return count;
    if (lengthCm > 0 && widthCm > 0) {
      final pieceArea = isCubicMeter && heightCm > 0
          ? (lengthCm / 100.0) * (widthCm / 100.0) * (heightCm / 100.0)
          : (lengthCm / 100.0) * (widthCm / 100.0);
      if (pieceArea > 0.000001 && quantity > 0) {
        final calc = quantity / pieceArea;
        if ((calc - calc.round()).abs() < 0.01) {
          return calc.roundToDouble();
        }
        return calc;
      }
    }
    return quantity > 0 ? quantity : 1.0;
  }

  double get calculatedVolume {
    if (lengthCm > 0 && widthCm > 0 && heightCm > 0) {
      return (lengthCm / 100.0) *
          (widthCm / 100.0) *
          (heightCm / 100.0) *
          effectiveCount;
    }
    return quantity;
  }

  double get calculatedArea {
    if (isCubicMeter) {
      return calculatedVolume;
    }
    if (lengthCm > 0 && widthCm > 0) {
      return (lengthCm / 100.0) * (widthCm / 100.0) * effectiveCount;
    }
    return quantity;
  }

  double get servicesTotal => services.fold(0.0, (s, e) => s + e.price);
  double get grandTotal => agreedPrice + servicesTotal;

  WorkshopInvoiceItem copyWith({
    String? id,
    String? sourceType,
    String? sourceId,
    String? sourceLineItemId,
    String? description,
    double? quantity,
    String? unitCategory,
    double? unitPrice,
    double? agreedPrice,
    double? netCost,
    double? depositAmount,
    bool? isGranite,
    List<ServiceAttachment>? services,
    String? photoPath,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    double? count,
  }) =>
      WorkshopInvoiceItem(
        id: id ?? this.id,
        sourceType: sourceType ?? this.sourceType,
        sourceId: sourceId ?? this.sourceId,
        sourceLineItemId: sourceLineItemId ?? this.sourceLineItemId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitCategory: unitCategory ?? this.unitCategory,
        unitPrice: unitPrice ?? this.unitPrice,
        agreedPrice: agreedPrice ?? this.agreedPrice,
        netCost: netCost ?? this.netCost,
        depositAmount: depositAmount ?? this.depositAmount,
        isGranite: isGranite ?? this.isGranite,
        services: services ?? this.services,
        photoPath: photoPath ?? this.photoPath,
        lengthCm: lengthCm ?? this.lengthCm,
        widthCm: widthCm ?? this.widthCm,
        heightCm: heightCm ?? this.heightCm,
        count: count ?? this.count,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'sourceLineItemId': sourceLineItemId,
    'description': description,
    'quantity': quantity,
    'unitCategory': unitCategory,
    'unitPrice': unitPrice,
    'agreedPrice': agreedPrice,
    'netCost': netCost,
    'depositAmount': depositAmount,
    'isGranite': isGranite,
    'services': services.map((s) => s.toJson()).toList(),
    'photoPath': photoPath,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'count': count,
  };

  factory WorkshopInvoiceItem.fromJson(Map<String, dynamic> json) =>
      WorkshopInvoiceItem(
        id: json['id'] ?? '',
        sourceType: json['sourceType'] ?? 'طلبية معمل',
        sourceId: json['sourceId'] ?? '',
        sourceLineItemId: json['sourceLineItemId'] ?? '',
        description: json['description'] ?? '',
        quantity: (json['quantity'] ?? 1.0).toDouble(),
        unitCategory: json['unitCategory'] ?? 'متر مربع',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
        netCost: (json['netCost'] as num?)?.toDouble() ?? 0.0,
        depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
        isGranite: json['isGranite'] ?? false,
        services: json['services'] != null
            ? (json['services'] as List)
                .map((s) => ServiceAttachment.fromJson(s))
                .toList()
            : [],
        photoPath: json['photoPath'] ?? '',
        lengthCm: (json['lengthCm'] as num?)?.toDouble() ?? 0.0,
        widthCm: (json['widthCm'] as num?)?.toDouble() ?? 0.0,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0.0,
        count: (json['count'] as num?)?.toDouble() ?? 0.0,
      );
}

// ==========================================
// 13. WORKSHOP INVOICE
// Supports multiple line items from multiple sources, each with dedicated services.
// ==========================================
class WorkshopInvoiceModel {
  final String id;
  final String invoiceNo;
  final DateTime date;
  final String clientName;
  final List<WorkshopInvoiceItem> items; // multiple items from multiple sources
  final String sourceType; // 'طلبية معمل' | 'تفصيل بسيط' | 'تفصيل معقد' | 'قطع زائدة' | 'مواد خام' | 'مصادر متعددة'
  final String sourceId; // order / tailoring / scrap / stock id when applicable
  final String projectId; // workshop project id when the invoice belongs to a project
  final String itemDescription;
  final double sourceQuantity;
  final String sourceUnitCategory;
  final double agreedPrice;
  final double depositDeducted;
  final double cashPaidNow;
  final double netCost;
  final double salesDiscount;
  double adjustmentsAmount;
  final List<ServiceAttachment> services;
  final String photoPath;
  final bool isGranite;
  final bool isCashInvoice;
  final String currency; // AppCurrency.usd | AppCurrency.syp

  WorkshopInvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.clientName,
    this.items = const [],
    this.sourceType = 'طلبية معمل',
    this.sourceId = '',
    this.projectId = '',
    this.itemDescription = '',
    this.sourceQuantity = 1.0,
    this.sourceUnitCategory = 'متر مربع',
    required this.agreedPrice,
    required this.depositDeducted,
    required this.cashPaidNow,
    required this.netCost,
    this.salesDiscount = 0.0,
    this.adjustmentsAmount = 0.0,
    this.services = const [],
    this.photoPath = '',
    this.isGranite = false,
    this.isCashInvoice = false,
    this.currency = AppCurrency.usd,
  });

  String get currencySymbol => AppCurrency.symbol(currency);

  double get itemsSubtotal => items.isNotEmpty
      ? items.fold(0.0, (s, e) => s + e.agreedPrice)
      : agreedPrice;

  double get servicesTotal => items.isNotEmpty
      ? items.fold(0.0, (s, e) => s + e.servicesTotal)
      : services.fold(0.0, (s, e) => s + e.price);

  double get grandTotal =>
      (itemsSubtotal + servicesTotal - salesDiscount).clamp(0.0, double.infinity);

  double get remainingBalance =>
      grandTotal - depositDeducted - cashPaidNow - adjustmentsAmount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNo': invoiceNo,
    'date': date.toIso8601String(),
    'clientName': clientName,
    'items': items.map((i) => i.toJson()).toList(),
    'sourceType': sourceType,
    'sourceId': sourceId,
    'projectId': projectId,
    'itemDescription': itemDescription,
    'sourceQuantity': sourceQuantity,
    'sourceUnitCategory': sourceUnitCategory,
    'agreedPrice': agreedPrice,
    'depositDeducted': depositDeducted,
    'cashPaidNow': cashPaidNow,
    'netCost': netCost,
    'salesDiscount': salesDiscount,
    'adjustmentsAmount': adjustmentsAmount,
    'services': services.isNotEmpty
        ? services.map((s) => s.toJson()).toList()
        : items.expand((i) => i.services).map((s) => s.toJson()).toList(),
    'photoPath': photoPath,
    'isGranite': isGranite,
    'isCashInvoice': isCashInvoice,
    'currency': currency,
  };

  factory WorkshopInvoiceModel.fromJson(Map<String, dynamic> json) {
    List<WorkshopInvoiceItem> parsedItems = [];
    if (json['items'] != null && (json['items'] as List).isNotEmpty) {
      parsedItems = (json['items'] as List)
          .map((i) => WorkshopInvoiceItem.fromJson(i))
          .toList();
    } else {
      final legacyServices = json['services'] != null
          ? (json['services'] as List)
              .map((s) => ServiceAttachment.fromJson(s))
              .toList()
          : <ServiceAttachment>[];
      parsedItems = [
        WorkshopInvoiceItem(
          id: 'item_1',
          sourceType: json['sourceType'] ?? 'طلبية معمل',
          sourceId: json['sourceId'] ?? '',
          description: json['itemDescription'] ?? '',
          quantity: (json['sourceQuantity'] ?? 1.0).toDouble(),
          unitCategory: json['sourceUnitCategory'] ?? 'متر مربع',
          unitPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
          agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
          netCost: (json['netCost'] as num?)?.toDouble() ?? 0.0,
          depositAmount: (json['depositDeducted'] as num?)?.toDouble() ?? 0.0,
          isGranite: json['isGranite'] ?? false,
          services: legacyServices,
          photoPath: json['photoPath'] ?? '',
        )
      ];
    }

    final rawServices = json['services'] != null
        ? (json['services'] as List)
            .map((s) => ServiceAttachment.fromJson(s))
            .toList()
        : parsedItems.expand((e) => e.services).toList();

    return WorkshopInvoiceModel(
      id: json['id'],
      invoiceNo: json['invoiceNo'],
      date: DateTime.parse(json['date']),
      clientName: json['clientName'],
      items: parsedItems,
      sourceType: json['sourceType'] ?? (parsedItems.isNotEmpty ? parsedItems.first.sourceType : 'طلبية معمل'),
      sourceId: json['sourceId'] ?? (parsedItems.isNotEmpty ? parsedItems.first.sourceId : ''),
      projectId: json['projectId'] ?? '',
      itemDescription: json['itemDescription'] ?? (parsedItems.map((e) => e.description).join(' + ')),
      sourceQuantity: (json['sourceQuantity'] ?? (parsedItems.isNotEmpty ? parsedItems.fold(0.0, (s, e) => s + e.quantity) : 1.0)).toDouble(),
      sourceUnitCategory: json['sourceUnitCategory'] ?? 'متر مربع',
      agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? parsedItems.fold(0.0, (s, e) => s + e.agreedPrice),
      depositDeducted: (json['depositDeducted'] as num?)?.toDouble() ?? 0.0,
      cashPaidNow: (json['cashPaidNow'] as num?)?.toDouble() ?? 0.0,
      netCost: (json['netCost'] as num?)?.toDouble() ?? parsedItems.fold(0.0, (s, e) => s + e.netCost),
      salesDiscount: (json['salesDiscount'] ?? 0.0).toDouble(),
      adjustmentsAmount: (json['adjustmentsAmount'] ?? 0.0).toDouble(),
      services: rawServices,
      photoPath: json['photoPath'] ?? '',
      isGranite: json['isGranite'] ?? false,
      isCashInvoice: json['isCashInvoice'] ?? false,
      currency: AppCurrency.normalize(json['currency']),
    );
  }
}

// ==========================================
// 13b. WORKSHOP PROJECT (مشروع معمل)
// Status is derived from its invoices: pending while any balance remains,
// completed once everything is collected.
// ==========================================
class WorkshopProjectModel {
  final String id;
  String name;
  String clientName;
  String phone;
  String description;
  String photoPath;
  final DateTime createdAt;

  WorkshopProjectModel({
    required this.id,
    required this.name,
    this.clientName = '',
    this.phone = '',
    this.description = '',
    this.photoPath = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'clientName': clientName,
    'phone': phone,
    'description': description,
    'photoPath': photoPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkshopProjectModel.fromJson(Map<String, dynamic> json) =>
      WorkshopProjectModel(
        id: json['id'],
        name: json['name'],
        clientName: json['clientName'] ?? '',
        phone: json['phone'] ?? '',
        description: json['description'] ?? '',
        photoPath: json['photoPath'] ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
      );
}

// ==========================================
// 13c. FACTORY CUSTOM ORDERS (طلبية مصنع)
// An order mirrors an invoice's fields; it is "In Progress" until it is
// assigned to an invoice and becomes "Completed".
// ==========================================
class FactoryOrderModel {
  final String id;
  final String orderNo;
  final DateTime date;
  final String partyId;
  final String clientName;
  final String clientPhone;
  final List<FactoryInvoiceItem> items;
  final List<ServiceAttachment> services;
  final double shippingFee;
  final bool isGoodsDelivered;
  final double discountAmount;
  final double depositAmount;
  final String photoPath;
  String status; // 'قيد التنفيذ' | 'مكتملة ومرحلة' | 'ملغاة (مكتملة)' | 'ملغاة (غير مكتملة)' | 'ملغاة'
  bool isCompleted;
  bool isSpecialRefund;
  final String currency; // AppCurrency.usd | AppCurrency.syp
  String assignedInvoiceId;
  String assignedInvoiceNo;

  FactoryOrderModel({
    required this.id,
    required this.orderNo,
    required this.date,
    this.partyId = '',
    required this.clientName,
    this.clientPhone = '',
    List<FactoryInvoiceItem> items = const [],
    this.services = const [],
    this.shippingFee = 0.0,
    this.isGoodsDelivered = true,
    this.discountAmount = 0.0,
    required this.depositAmount,
    this.photoPath = '',
    this.status = 'قيد التنفيذ',
    this.isCompleted = false,
    this.isSpecialRefund = false,
    this.currency = AppCurrency.usd,
    this.assignedInvoiceId = '',
    this.assignedInvoiceNo = '',
    // Legacy support parameters:
    String? warehouseItemId,
    String? itemDescription,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    double? quantity,
    double? unitPrice,
    double? agreedPrice,
  }) : items = List.of(items) {
    // If items were empty but legacy single-item fields were passed, populate items
    if (this.items.isEmpty && (warehouseItemId != null && warehouseItemId.isNotEmpty || itemDescription != null && itemDescription.isNotEmpty)) {
      this.items.add(
        FactoryInvoiceItem(
          itemId: warehouseItemId ?? '',
          description: itemDescription ?? '',
          lengthCm: lengthCm ?? 0.0,
          widthCm: widthCm ?? 0.0,
          heightCm: heightCm ?? 0.0,
          quantity: quantity ?? 1.0,
          unitPrice: unitPrice ?? 0.0,
          unitCost: unitPrice ?? 0.0,
        ),
      );
    }
  }

  String get currencySymbol => AppCurrency.symbol(currency);

  // Backward compatibility getters
  String get warehouseItemId => items.isNotEmpty ? items.first.itemId : '';
  String get itemDescription => items.isNotEmpty ? items.first.description : '';
  double get lengthCm => items.isNotEmpty ? items.first.lengthCm : 0.0;
  double get widthCm => items.isNotEmpty ? items.first.widthCm : 0.0;
  double get heightCm => items.isNotEmpty ? items.first.heightCm : 0.0;
  double get quantity => items.fold(0.0, (s, i) => s + i.quantity);
  double get unitPrice => items.isNotEmpty ? items.first.unitPrice : 0.0;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get itemsServicesTotal =>
      items.fold(0.0, (sum, item) => sum + item.servicesTotal);
  double get totalServices => services.fold(0.0, (sum, s) => sum + s.price);

  double get grandTotal =>
      (subtotal + itemsServicesTotal + totalServices + shippingFee - discountAmount)
          .clamp(0.0, double.infinity);

  double get agreedPrice => grandTotal;

  double get totalArea => items.fold(0.0, (s, i) => s + i.calculatedArea);
  double get area => totalArea;

  double get remainingBalance =>
      (grandTotal - depositAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNo': orderNo,
    'date': date.toIso8601String(),
    'partyId': partyId,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'items': items.map((i) => i.toJson()).toList(),
    'services': services.map((s) => s.toJson()).toList(),
    'shippingFee': shippingFee,
    'isGoodsDelivered': isGoodsDelivered,
    'discountAmount': discountAmount,
    'depositAmount': depositAmount,
    'photoPath': photoPath,
    'status': status,
    'isCompleted': isCompleted,
    'isSpecialRefund': isSpecialRefund,
    'currency': currency,
    'assignedInvoiceId': assignedInvoiceId,
    'assignedInvoiceNo': assignedInvoiceNo,
    // Redundant legacy fields for safe cross-version reads:
    'warehouseItemId': warehouseItemId,
    'itemDescription': itemDescription,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'agreedPrice': agreedPrice,
  };

  factory FactoryOrderModel.fromJson(Map<String, dynamic> json) {
    List<FactoryInvoiceItem> parsedItems = [];
    if (json['items'] is List && (json['items'] as List).isNotEmpty) {
      parsedItems = (json['items'] as List)
          .map((i) => FactoryInvoiceItem.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    } else if (json['warehouseItemId'] != null &&
        json['warehouseItemId'].toString().isNotEmpty) {
      parsedItems.add(
        FactoryInvoiceItem(
          itemId: json['warehouseItemId'] ?? '',
          description: json['itemDescription'] ?? '',
          lengthCm: (json['lengthCm'] ?? 0.0).toDouble(),
          widthCm: (json['widthCm'] ?? 0.0).toDouble(),
          heightCm: (json['heightCm'] ?? 0.0).toDouble(),
          quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
          unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
          unitCost: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    return FactoryOrderModel(
      id: json['id'] ?? '',
      orderNo: json['orderNo'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      partyId: json['partyId'] ?? '',
      clientName: json['clientName'] ?? '',
      clientPhone: json['clientPhone'] ?? '',
      items: parsedItems,
      services: json['services'] != null
          ? (json['services'] as List)
              .map((s) => ServiceAttachment.fromJson(Map<String, dynamic>.from(s)))
              .toList()
          : [],
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0.0,
      isGoodsDelivered: json['isGoodsDelivered'] ?? true,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
      photoPath: json['photoPath'] ?? '',
      status: json['status'] ?? 'قيد التنفيذ',
      isCompleted: json['isCompleted'] ?? false,
      isSpecialRefund: json['isSpecialRefund'] ?? false,
      currency: AppCurrency.normalize(json['currency']),
      assignedInvoiceId: json['assignedInvoiceId'] ?? '',
      assignedInvoiceNo: json['assignedInvoiceNo'] ?? '',
    );
  }
}


// ==========================================
// 14. SERVICES CENTER ITEM
// ==========================================
class ServiceItemModel {
  final String id;
  final String
  name; // e.g. "جلي وتلميع", "شطف حواف وتفريز", "نقل وتوصيل", "قص وزوايا معقدة", "ثقب وتفريغ مغاسل"
  final double unitRate;
  final String description;

  ServiceItemModel({
    required this.id,
    required this.name,
    required this.unitRate,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unitRate': unitRate,
    'description': description,
  };

  factory ServiceItemModel.fromJson(Map<String, dynamic> json) =>
      ServiceItemModel(
        id: json['id'],
        name: json['name'],
        unitRate: (json['unitRate'] as num).toDouble(),
        description: json['description'] ?? '',
      );
}

// ==========================================
// 15. WORKFORCE & PAYROLL
// ==========================================
class StaffTypeModel {
  final String id;
  final String category; // 'عمال' | 'إداريين'
  final String name;
  final double dailyRate;

  StaffTypeModel({
    required this.id,
    required this.category,
    required this.name,
    required this.dailyRate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'dailyRate': dailyRate,
  };

  factory StaffTypeModel.fromJson(Map<String, dynamic> json) => StaffTypeModel(
    id: json['id'],
    category: json['category'],
    name: json['name'],
    dailyRate: (json['dailyRate'] as num).toDouble(),
  );
}

class StaffModel {
  final String id;
  final String name;
  final String category; // 'عمال' | 'معلمين' | 'إداريين'
  final String phone;
  final String location;
  String typeId;
  double totalEarned; // USD
  double cashAdvancesDisbursed; // USD — Disbursed from Main Cash Box
  double totalEarnedSyp; // SYP
  double cashAdvancesDisbursedSyp; // SYP

  StaffModel({
    required this.id,
    required this.name,
    required this.category,
    required this.phone,
    this.location = '',
    this.typeId = '',
    this.totalEarned = 0.0,
    this.cashAdvancesDisbursed = 0.0,
    this.totalEarnedSyp = 0.0,
    this.cashAdvancesDisbursedSyp = 0.0,
  });

  double get netRemainingBalance => totalEarned - cashAdvancesDisbursed;
  double get netRemainingBalanceSyp =>
      totalEarnedSyp - cashAdvancesDisbursedSyp;

  double netOf(String? currency) => AppCurrency.isSyp(currency)
      ? netRemainingBalanceSyp
      : netRemainingBalance;

  void addEarning(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      totalEarnedSyp += amount;
    } else {
      totalEarned += amount;
    }
  }

  void removeEarning(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      totalEarnedSyp = (totalEarnedSyp - amount).clamp(0.0, double.infinity);
    } else {
      totalEarned = (totalEarned - amount).clamp(0.0, double.infinity);
    }
  }

  void addAdvance(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      cashAdvancesDisbursedSyp += amount;
    } else {
      cashAdvancesDisbursed += amount;
    }
  }

  void reduceAdvance(String? currency, double amount) {
    if (AppCurrency.isSyp(currency)) {
      cashAdvancesDisbursedSyp =
          (cashAdvancesDisbursedSyp - amount).clamp(0.0, double.infinity);
    } else {
      cashAdvancesDisbursed =
          (cashAdvancesDisbursed - amount).clamp(0.0, double.infinity);
    }
  }

  String get dualNet =>
      AppCurrency.dual(netRemainingBalance, netRemainingBalanceSyp);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'phone': phone,
    'location': location,
    'typeId': typeId,
    'totalEarned': totalEarned,
    'cashAdvancesDisbursed': cashAdvancesDisbursed,
    'totalEarnedSyp': totalEarnedSyp,
    'cashAdvancesDisbursedSyp': cashAdvancesDisbursedSyp,
  };

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    phone: json['phone'] ?? '',
    location: json['location'] ?? '',
    typeId: json['typeId'] ?? '',
    totalEarned: (json['totalEarned'] as num).toDouble(),
    cashAdvancesDisbursed: (json['cashAdvancesDisbursed'] as num).toDouble(),
    totalEarnedSyp: (json['totalEarnedSyp'] ?? 0.0).toDouble(),
    cashAdvancesDisbursedSyp: (json['cashAdvancesDisbursedSyp'] ?? 0.0)
        .toDouble(),
  );
}

class AdvanceRepaymentModel {
  final String id;
  final String staffId;
  final String staffName;
  final String staffCategory;
  final String originalCurrency;
  final String collectedCurrency;
  final double collectedAmount;
  final double deductedAmount;
  final double exchangeRate;
  final DateTime date;
  final String note;

  AdvanceRepaymentModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffCategory,
    required this.originalCurrency,
    required this.collectedCurrency,
    required this.collectedAmount,
    required this.deductedAmount,
    this.exchangeRate = 1.0,
    DateTime? date,
    this.note = '',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'staffId': staffId,
    'staffName': staffName,
    'staffCategory': staffCategory,
    'originalCurrency': originalCurrency,
    'collectedCurrency': collectedCurrency,
    'collectedAmount': collectedAmount,
    'deductedAmount': deductedAmount,
    'exchangeRate': exchangeRate,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory AdvanceRepaymentModel.fromJson(Map<String, dynamic> json) => AdvanceRepaymentModel(
    id: json['id'],
    staffId: json['staffId'] ?? '',
    staffName: json['staffName'] ?? '',
    staffCategory: json['staffCategory'] ?? '',
    originalCurrency: AppCurrency.normalize(json['originalCurrency']),
    collectedCurrency: AppCurrency.normalize(json['collectedCurrency']),
    collectedAmount: (json['collectedAmount'] as num).toDouble(),
    deductedAmount: (json['deductedAmount'] as num).toDouble(),
    exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
    date: DateTime.parse(json['date']),
    note: json['note'] ?? '',
  );
}

class StaffAttendanceModel {
  final String id;
  final DateTime date;
  final String staffId;
  final double dailyRate;
  final String currency;

  StaffAttendanceModel({
    required this.id,
    required this.date,
    required this.staffId,
    required this.dailyRate,
    this.currency = AppCurrency.usd,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'staffId': staffId,
    'dailyRate': dailyRate,
    'currency': currency,
  };

  factory StaffAttendanceModel.fromJson(Map<String, dynamic> json) =>
      StaffAttendanceModel(
        id: json['id'],
        date: DateTime.parse(json['date']),
        staffId: json['staffId'],
        dailyRate: (json['dailyRate'] as num).toDouble(),
        currency: AppCurrency.normalize(json['currency']),
      );
}

class WorkdayEntryModel {
  final String id;
  final DateTime date;
  final List<String> staffNames;
  final String staffId;
  final String workDescription;
  final String rateType; // 'حساب يومية' | 'حساب مقطوع'
  final double agreedAmountPerPerson;
  final String currency; // AppCurrency.usd | AppCurrency.syp

  WorkdayEntryModel({
    required this.id,
    required this.date,
    required this.staffNames,
    this.staffId = '',
    required this.workDescription,
    required this.rateType,
    required this.agreedAmountPerPerson,
    this.currency = AppCurrency.usd,
  });

  double get grandTotal => staffNames.length * agreedAmountPerPerson;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'staffNames': staffNames,
    'staffId': staffId,
    'workDescription': workDescription,
    'rateType': rateType,
    'agreedAmountPerPerson': agreedAmountPerPerson,
    'currency': currency,
  };

  factory WorkdayEntryModel.fromJson(Map<String, dynamic> json) =>
      WorkdayEntryModel(
        id: json['id'],
        date: DateTime.parse(json['date']),
        staffNames: List<String>.from(json['staffNames'] ?? []),
        staffId: json['staffId'] ?? '',
        workDescription: json['workDescription'] ?? '',
        rateType: json['rateType'] ?? 'حساب يومية',
        agreedAmountPerPerson: (json['agreedAmountPerPerson'] as num)
            .toDouble(),
        currency: AppCurrency.normalize(json['currency']),
      );
}

// ==========================================
// 16. RETURN INVOICE MODEL
// ==========================================
class ReturnInvoiceModel {
  final String id;
  final String returnNo;
  final DateTime date;
  final String
  returnType; // 'مرتجع مشتريات مورد' | 'مرتجع مبيعات مصنع' | 'مرتجع مبيعات معمل'
  final String partyName;
  final String itemDescription;
  final double quantity;
  final double refundAmount;
  final String paymentAction; // 'تخفيض دين' | 'استرداد نقدي للصندوق الرئيسي'
  final String currency; // AppCurrency.usd | AppCurrency.syp
  /// Clean link back to the master invoice this return was issued against.
  final String parentInvoiceId;
  final String parentInvoiceNo;
  final String unit; // measurement unit of [quantity]
  /// Cash actually moved through the main safe for this document.
  /// `null` = legacy record (cash = full amount when settled in cash).
  final double? cashAmount;

  ReturnInvoiceModel({
    required this.id,
    required this.returnNo,
    required this.date,
    required this.returnType,
    required this.partyName,
    required this.itemDescription,
    required this.quantity,
    required this.refundAmount,
    required this.paymentAction,
    this.currency = AppCurrency.usd,
    this.parentInvoiceId = '',
    this.parentInvoiceNo = '',
    this.unit = '',
    this.cashAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'returnNo': returnNo,
    'date': date.toIso8601String(),
    'returnType': returnType,
    'partyName': partyName,
    'itemDescription': itemDescription,
    'quantity': quantity,
    'refundAmount': refundAmount,
    'paymentAction': paymentAction,
    'currency': currency,
    'parentInvoiceId': parentInvoiceId,
    'parentInvoiceNo': parentInvoiceNo,
    'unit': unit,
    'cashAmount': cashAmount,
  };

  factory ReturnInvoiceModel.fromJson(Map<String, dynamic> json) =>
      ReturnInvoiceModel(
        id: json['id'],
        returnNo: json['returnNo'],
        date: DateTime.parse(json['date']),
        returnType: json['returnType'],
        partyName: json['partyName'],
        itemDescription: json['itemDescription'],
        quantity: (json['quantity'] as num).toDouble(),
        refundAmount: (json['refundAmount'] as num).toDouble(),
        paymentAction: json['paymentAction'],
        currency: AppCurrency.normalize(json['currency']),
        parentInvoiceId: json['parentInvoiceId'] ?? '',
        parentInvoiceNo: json['parentInvoiceNo'] ?? '',
        unit: json['unit'] ?? '',
        cashAmount: (json['cashAmount'] as num?)?.toDouble(),
      );
}

// ==========================================
// 17. CUTTING BATCH (Inventory aggregation -> Cutting)
// ==========================================

/// One picked lot from the factory inventory for the cutting aggregation.
class CuttingBatchSelection {
  final String blockId;
  final String supplierName;
  final double tons;
  final double tonCost;

  CuttingBatchSelection({
    required this.blockId,
    required this.supplierName,
    required this.tons,
    required this.tonCost,
  });

  double get totalPrice => tons * tonCost;
}

/// Aggregated tons of a single type+grade picked from one or more suppliers.
/// Arithmetic mean: total price of supplier tons / total number of tons.
class CuttingBatchInput {
  final String typeName;
  final String grade;
  final bool isGranite;
  final double totalTons;
  final double avgTonCost;
  final List<CuttingBatchSelection> selections;

  CuttingBatchInput({
    required this.typeName,
    required this.grade,
    required this.isGranite,
    required this.totalTons,
    required this.avgTonCost,
    required this.selections,
  });
}

/// One thickness conversion inside the staged cutting plan.
class StagedCutConversion {
  final String typeName;
  final String grade;
  final bool isGranite;
  final double inputTons;
  final double avgTonCost;
  final double feePercent;
  final double thicknessCm;
  final String category; // 'متر مربع' (<=5cm) | 'متر مكعب' (>5cm)
  final double outputQty;
  final double netCost;
  final double salePrice;

  StagedCutConversion({
    required this.typeName,
    required this.grade,
    required this.isGranite,
    required this.inputTons,
    required this.avgTonCost,
    required this.feePercent,
    required this.thicknessCm,
    required this.category,
    required this.outputQty,
    required this.netCost,
    required this.salePrice,
  });
}

/// Center / Sawmill official information for invoice headers and printing.
class CenterInfoModel {
  final String centerName;
  final String ownerName;
  final String phone1;
  final String phone2;
  final String commercialRegNo;
  final String taxId;
  final String logoPath;
  final String address;
  final String slogan;

  const CenterInfoModel({
    this.centerName = 'مركز ومنشار الأبرش للرخام والجرانيت',
    this.ownerName = 'إدارة منشار الأبرش',
    this.phone1 = '+963 933 123 456',
    this.phone2 = '+963 11 456 7890',
    this.commercialRegNo = '104820',
    this.taxId = '300294819',
    this.logoPath = '',
    this.address = 'المنطقة الصناعية - ريف دمشق / سوريا',
    this.slogan = 'لأعمال الرخام والجرانيت وحجر البناء وقص وتفصيل البلوكات وتوريد المستودعات',
  });

  Map<String, dynamic> toJson() => {
        'centerName': centerName,
        'ownerName': ownerName,
        'phone1': phone1,
        'phone2': phone2,
        'commercialRegNo': commercialRegNo,
        'taxId': taxId,
        'logoPath': logoPath,
        'address': address,
        'slogan': slogan,
      };

  factory CenterInfoModel.fromJson(Map<String, dynamic> json) =>
      CenterInfoModel(
        centerName: json['centerName'] ?? 'مركز ومنشار الأبرش للرخام والجرانيت',
        ownerName: json['ownerName'] ?? 'إدارة منشار الأبرش',
        phone1: json['phone1'] ?? '+963 933 123 456',
        phone2: json['phone2'] ?? '+963 11 456 7890',
        commercialRegNo: json['commercialRegNo'] ?? '104820',
        taxId: json['taxId'] ?? '300294819',
        logoPath: json['logoPath'] ?? '',
        address: json['address'] ?? 'المنطقة الصناعية - ريف دمشق / سوريا',
        slogan: json['slogan'] ??
            'لأعمال الرخام والجرانيت وحجر البناء وقص وتفصيل البلوكات وتوريد المستودعات',
      );
}

/// Model for accountant profit withdrawals from the granite business.
class AccountantWithdrawalModel {
  final String id;
  final DateTime date;
  final double amount;
  final String currency; // AppCurrency.usd | AppCurrency.syp
  final String cashBox; // 'main' | 'order' | 'scrap' | 'direct'
  final String notes;
  final String recipient;

  AccountantWithdrawalModel({
    required this.id,
    required this.date,
    required this.amount,
    this.currency = AppCurrency.usd,
    this.cashBox = 'main',
    this.notes = '',
    this.recipient = 'محاسب الغرانيت',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'currency': currency,
        'cashBox': cashBox,
        'notes': notes,
        'recipient': recipient,
      };

  factory AccountantWithdrawalModel.fromJson(Map<String, dynamic> json) =>
      AccountantWithdrawalModel(
        id: json['id'] ?? '',
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: AppCurrency.normalize(json['currency']),
        cashBox: json['cashBox'] ?? 'main',
        notes: json['notes'] ?? '',
        recipient: json['recipient'] ?? 'محاسب الغرانيت',
      );
}

// ==========================================
// 19. DAILY COMPREHENSIVE REPORT MODEL (التقرير اليومي الشامل)
// ==========================================

class DailyReportInvoiceSummary {
  final String invoiceNo;
  final String module; // 'المصنع' | 'المعمل' | 'مرتجع'
  final String type; // 'مبيعات' | 'مشتريات' | 'مرتجع'
  final String paymentType; // 'عادية' | 'نقدية'
  final String partyName; // Client or Supplier name
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String currency;
  final String itemsSummary;
  final DateTime time;

  DailyReportInvoiceSummary({
    required this.invoiceNo,
    required this.module,
    required this.type,
    required this.paymentType,
    required this.partyName,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.currency,
    required this.itemsSummary,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'invoiceNo': invoiceNo,
        'module': module,
        'type': type,
        'paymentType': paymentType,
        'partyName': partyName,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'currency': currency,
        'itemsSummary': itemsSummary,
        'time': time.toIso8601String(),
      };

  factory DailyReportInvoiceSummary.fromJson(Map<String, dynamic> json) =>
      DailyReportInvoiceSummary(
        invoiceNo: json['invoiceNo'] ?? '',
        module: json['module'] ?? '',
        type: json['type'] ?? '',
        paymentType: json['paymentType'] ?? '',
        partyName: json['partyName'] ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] ?? 'USD',
        itemsSummary: json['itemsSummary'] ?? '',
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      );
}

class DailyReportExpenseSummary {
  final String category;
  final String description;
  final String beneficiary;
  final double amount;
  final String currency;
  final String cashBox;
  final DateTime time;

  DailyReportExpenseSummary({
    required this.category,
    required this.description,
    required this.beneficiary,
    required this.amount,
    required this.currency,
    required this.cashBox,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'beneficiary': beneficiary,
        'amount': amount,
        'currency': currency,
        'cashBox': cashBox,
        'time': time.toIso8601String(),
      };

  factory DailyReportExpenseSummary.fromJson(Map<String, dynamic> json) =>
      DailyReportExpenseSummary(
        category: json['category'] ?? '',
        description: json['description'] ?? '',
        beneficiary: json['beneficiary'] ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] ?? 'USD',
        cashBox: json['cashBox'] ?? 'main',
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      );
}

class DailyReportCashMovementSummary {
  final String type; // 'قبض مبيعات' | 'سداد مشتريات' | 'مصاريف' | 'سحب أرباح' | 'تحويل عملات' | 'استرداد مرتجع'
  final String description;
  final String cashBox;
  final double amount;
  final String currency;
  final DateTime time;

  DailyReportCashMovementSummary({
    required this.type,
    required this.description,
    required this.cashBox,
    required this.amount,
    required this.currency,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'cashBox': cashBox,
        'amount': amount,
        'currency': currency,
        'time': time.toIso8601String(),
      };

  factory DailyReportCashMovementSummary.fromJson(Map<String, dynamic> json) =>
      DailyReportCashMovementSummary(
        type: json['type'] ?? '',
        description: json['description'] ?? '',
        cashBox: json['cashBox'] ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] ?? 'USD',
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      );
}

class DailyReportModel {
  final String id;
  final String reportNo;
  final DateTime reportDate; // Day covered
  final DateTime generatedAt; // Compile timestamp
  String notes;

  // Aggregated financials for that day
  final double totalSalesUsd;
  final double totalSalesSyp;
  final double totalPurchasesUsd;
  final double totalPurchasesSyp;
  final double totalExpensesUsd;
  final double totalExpensesSyp;
  final double totalCashInUsd;
  final double totalCashInSyp;
  final double totalCashOutUsd;
  final double totalCashOutSyp;

  // Cash balances at time of compilation
  final double mainCashUsd;
  final double mainCashSyp;
  final double scrapCashUsd;
  final double scrapCashSyp;
  final double orderCashUsd;
  final double orderCashSyp;

  // Granular item lists
  final List<DailyReportInvoiceSummary> salesInvoices;
  final List<DailyReportInvoiceSummary> purchaseInvoices;
  final List<DailyReportInvoiceSummary> returnInvoices;
  final List<DailyReportExpenseSummary> expenses;
  final List<DailyReportCashMovementSummary> cashMovements;

  // Operation counts
  final int cuttingOperationsCount;
  final int attendanceCount;

  DailyReportModel({
    required this.id,
    required this.reportNo,
    required this.reportDate,
    required this.generatedAt,
    this.notes = '',
    required this.totalSalesUsd,
    required this.totalSalesSyp,
    required this.totalPurchasesUsd,
    required this.totalPurchasesSyp,
    required this.totalExpensesUsd,
    required this.totalExpensesSyp,
    required this.totalCashInUsd,
    required this.totalCashInSyp,
    required this.totalCashOutUsd,
    required this.totalCashOutSyp,
    required this.mainCashUsd,
    required this.mainCashSyp,
    required this.scrapCashUsd,
    required this.scrapCashSyp,
    required this.orderCashUsd,
    required this.orderCashSyp,
    required this.salesInvoices,
    required this.purchaseInvoices,
    required this.returnInvoices,
    required this.expenses,
    required this.cashMovements,
    this.cuttingOperationsCount = 0,
    this.attendanceCount = 0,
  });

  double get netCashFlowUsd => totalCashInUsd - totalCashOutUsd;
  double get netCashFlowSyp => totalCashInSyp - totalCashOutSyp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportNo': reportNo,
        'reportDate': reportDate.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'notes': notes,
        'totalSalesUsd': totalSalesUsd,
        'totalSalesSyp': totalSalesSyp,
        'totalPurchasesUsd': totalPurchasesUsd,
        'totalPurchasesSyp': totalPurchasesSyp,
        'totalExpensesUsd': totalExpensesUsd,
        'totalExpensesSyp': totalExpensesSyp,
        'totalCashInUsd': totalCashInUsd,
        'totalCashInSyp': totalCashInSyp,
        'totalCashOutUsd': totalCashOutUsd,
        'totalCashOutSyp': totalCashOutSyp,
        'mainCashUsd': mainCashUsd,
        'mainCashSyp': mainCashSyp,
        'scrapCashUsd': scrapCashUsd,
        'scrapCashSyp': scrapCashSyp,
        'orderCashUsd': orderCashUsd,
        'orderCashSyp': orderCashSyp,
        'salesInvoices': salesInvoices.map((i) => i.toJson()).toList(),
        'purchaseInvoices': purchaseInvoices.map((i) => i.toJson()).toList(),
        'returnInvoices': returnInvoices.map((i) => i.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'cashMovements': cashMovements.map((c) => c.toJson()).toList(),
        'cuttingOperationsCount': cuttingOperationsCount,
        'attendanceCount': attendanceCount,
      };

  factory DailyReportModel.fromJson(Map<String, dynamic> json) =>
      DailyReportModel(
        id: json['id'] ?? '',
        reportNo: json['reportNo'] ?? '',
        reportDate: DateTime.tryParse(json['reportDate'] ?? '') ?? DateTime.now(),
        generatedAt: DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
        notes: json['notes'] ?? '',
        totalSalesUsd: (json['totalSalesUsd'] as num?)?.toDouble() ?? 0.0,
        totalSalesSyp: (json['totalSalesSyp'] as num?)?.toDouble() ?? 0.0,
        totalPurchasesUsd: (json['totalPurchasesUsd'] as num?)?.toDouble() ?? 0.0,
        totalPurchasesSyp: (json['totalPurchasesSyp'] as num?)?.toDouble() ?? 0.0,
        totalExpensesUsd: (json['totalExpensesUsd'] as num?)?.toDouble() ?? 0.0,
        totalExpensesSyp: (json['totalExpensesSyp'] as num?)?.toDouble() ?? 0.0,
        totalCashInUsd: (json['totalCashInUsd'] as num?)?.toDouble() ?? 0.0,
        totalCashInSyp: (json['totalCashInSyp'] as num?)?.toDouble() ?? 0.0,
        totalCashOutUsd: (json['totalCashOutUsd'] as num?)?.toDouble() ?? 0.0,
        totalCashOutSyp: (json['totalCashOutSyp'] as num?)?.toDouble() ?? 0.0,
        mainCashUsd: (json['mainCashUsd'] as num?)?.toDouble() ?? 0.0,
        mainCashSyp: (json['mainCashSyp'] as num?)?.toDouble() ?? 0.0,
        scrapCashUsd: (json['scrapCashUsd'] as num?)?.toDouble() ?? 0.0,
        scrapCashSyp: (json['scrapCashSyp'] as num?)?.toDouble() ?? 0.0,
        orderCashUsd: (json['orderCashUsd'] as num?)?.toDouble() ?? 0.0,
        orderCashSyp: (json['orderCashSyp'] as num?)?.toDouble() ?? 0.0,
        salesInvoices: (json['salesInvoices'] as List? ?? [])
            .map((i) => DailyReportInvoiceSummary.fromJson(
                Map<String, dynamic>.from(i)))
            .toList(),
        purchaseInvoices: (json['purchaseInvoices'] as List? ?? [])
            .map((i) => DailyReportInvoiceSummary.fromJson(
                Map<String, dynamic>.from(i)))
            .toList(),
        returnInvoices: (json['returnInvoices'] as List? ?? [])
            .map((i) => DailyReportInvoiceSummary.fromJson(
                Map<String, dynamic>.from(i)))
            .toList(),
        expenses: (json['expenses'] as List? ?? [])
            .map((e) => DailyReportExpenseSummary.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        cashMovements: (json['cashMovements'] as List? ?? [])
            .map((c) => DailyReportCashMovementSummary.fromJson(
                Map<String, dynamic>.from(c)))
            .toList(),
        cuttingOperationsCount: json['cuttingOperationsCount'] ?? 0,
        attendanceCount: json['attendanceCount'] ?? 0,
      );
}


