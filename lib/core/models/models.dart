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
        date: DateTime.parse(json['date']),
        isInformational: json['isInformational'] ?? false,
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
  }) : date = date ?? DateTime.now();

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

  ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.clientType,
    this.description = '',
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
    'clientType': clientType,
    'description': description,
    'debtBalance': debtBalance,
    'debtBalanceSyp': debtBalanceSyp,
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

  bool get isMeterItem => itemCategory == 'meter' || itemCategory == 'متر';

  double get calculatedArea {
    if (isMeterItem) {
      return quantity;
    }
    if (heightCm > 5.0) {
      // Volume m³
      return (lengthCm / 100.0) *
          (widthCm / 100.0) *
          (heightCm / 100.0) *
          quantity;
    } else if (lengthCm > 0 && widthCm > 0) {
      // Area m²
      return (lengthCm / 100.0) * (widthCm / 100.0) * quantity;
    }
    return quantity; // Default unit quantity (e.g. Tons or pcs)
  }

  double get totalPrice => calculatedArea * unitPrice;
  double get totalCost => calculatedArea * unitCost;
  double get servicesTotal => services.fold(0.0, (sum, s) => sum + s.price);
  double get grandTotal => totalPrice + servicesTotal;

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
  final double netCostPerMeter;
  final double sellingPricePerMeter;
  final double laborPerMeter;
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
  double get lineTotal =>
      (area * sellingPricePerMeter) + (laborPerMeter * area) + servicesTotal;

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
  bool isSpecialRefund;
  final String
  currency; // AppCurrency.usd | AppCurrency.syp — invoice inherits it

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
    this.isSpecialRefund = false,
    this.currency = AppCurrency.usd,
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
    'isSpecialRefund': isSpecialRefund,
    'currency': currency,
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
        isSpecialRefund: json['isSpecialRefund'] ?? false,
        currency: AppCurrency.normalize(json['currency']),
      );
}

// ==========================================
// 12b. WORKSHOP INVOICE ITEM (بند فاتورة المعمل)
// Each line item belongs to a specific source and has its own dedicated services.
// ==========================================
class WorkshopInvoiceItem {
  final String id;
  final String sourceType; // 'طلبية معمل' | 'تفصيل بسيط' | 'تفصيل معقد' | 'قطع زائدة' | 'مواد خام'
  final String sourceId; // order / tailoring / scrap / stock id
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

  WorkshopInvoiceItem({
    required this.id,
    required this.sourceType,
    this.sourceId = '',
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
  });

  double get servicesTotal => services.fold(0.0, (s, e) => s + e.price);
  double get grandTotal => agreedPrice + servicesTotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'sourceId': sourceId,
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
  };

  factory WorkshopInvoiceItem.fromJson(Map<String, dynamic> json) =>
      WorkshopInvoiceItem(
        id: json['id'] ?? '',
        sourceType: json['sourceType'] ?? 'طلبية معمل',
        sourceId: json['sourceId'] ?? '',
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
  final String clientName;
  final String clientPhone;
  final String warehouseItemId;
  final String itemDescription;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double quantity;
  final double unitPrice;
  final double agreedPrice;
  final double depositAmount;
  final String photoPath;
  String status; // 'قيد التنفيذ' | 'مكتملة ومرحلة' | 'ملغاة'
  bool isSpecialRefund;
  final String
  currency; // AppCurrency.usd | AppCurrency.syp — invoice inherits it

  FactoryOrderModel({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.clientName,
    required this.clientPhone,
    required this.warehouseItemId,
    required this.itemDescription,
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    required this.quantity,
    required this.unitPrice,
    required this.agreedPrice,
    required this.depositAmount,
    this.photoPath = '',
    this.status = 'قيد التنفيذ',
    this.isSpecialRefund = false,
    this.currency = AppCurrency.usd,
  });

  String get currencySymbol => AppCurrency.symbol(currency);

  double get area {
    if (heightCm > 5.0) {
      if (lengthCm <= 0 || widthCm <= 0 || quantity <= 0) return 0.0;
      return (lengthCm / 100.0) *
          (widthCm / 100.0) *
          (heightCm / 100.0) *
          quantity;
    }
    if (lengthCm <= 0 || widthCm <= 0 || quantity <= 0) return 0.0;
    return (lengthCm / 100.0) * (widthCm / 100.0) * quantity;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNo': orderNo,
    'date': date.toIso8601String(),
    'clientName': clientName,
    'clientPhone': clientPhone,
    'warehouseItemId': warehouseItemId,
    'itemDescription': itemDescription,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'agreedPrice': agreedPrice,
    'depositAmount': depositAmount,
    'photoPath': photoPath,
    'status': status,
    'isSpecialRefund': isSpecialRefund,
    'currency': currency,
  };

  factory FactoryOrderModel.fromJson(Map<String, dynamic> json) =>
      FactoryOrderModel(
        id: json['id'],
        orderNo: json['orderNo'],
        date: DateTime.parse(json['date']),
        clientName: json['clientName'],
        clientPhone: json['clientPhone'] ?? '',
        warehouseItemId: json['warehouseItemId'] ?? '',
        itemDescription: json['itemDescription'] ?? '',
        lengthCm: (json['lengthCm'] ?? 0.0).toDouble(),
        widthCm: (json['widthCm'] ?? 0.0).toDouble(),
        heightCm: (json['heightCm'] ?? 0.0).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        agreedPrice: (json['agreedPrice'] as num).toDouble(),
        depositAmount: (json['depositAmount'] as num).toDouble(),
        photoPath: json['photoPath'] ?? '',
        status: json['status'] ?? 'قيد التنفيذ',
        isSpecialRefund: json['isSpecialRefund'] ?? false,
        currency: AppCurrency.normalize(json['currency']),
      );
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

  String get dualNet =>
      AppCurrency.dual(netRemainingBalance, netRemainingBalanceSyp);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'phone': phone,
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
    typeId: json['typeId'] ?? '',
    totalEarned: (json['totalEarned'] as num).toDouble(),
    cashAdvancesDisbursed: (json['cashAdvancesDisbursed'] as num).toDouble(),
    totalEarnedSyp: (json['totalEarnedSyp'] ?? 0.0).toDouble(),
    cashAdvancesDisbursedSyp: (json['cashAdvancesDisbursedSyp'] ?? 0.0)
        .toDouble(),
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
