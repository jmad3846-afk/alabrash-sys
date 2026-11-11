import 'package:flutter/material.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import 'app_image_attachment.dart';
import 'currency_selector.dart';

// ==========================================
// WORKSHOP INVOICE (فاتورة المعمل) — DUAL-PANE BUILDER
// ==========================================
// Left section : Item rows (one horizontal row per item with
//                [Length, Width, Height/Thickness, Quantity, Price] + services)
//                with the financial invoice summary pinned under the rows.
// Right section: (1) Client search & approved selection
//                (2) Batch / bulk blank-row creation and item-type assignment
//                (3) Additional fields (discount, deposits, payments, image)
//                (4) Save invoice button
// All financial formulas, calculation rules and validations from the previous
// builder are preserved here.

/// Shared workshop service-cost rule:
/// (Item Length × Item Quantity × Service Unit Price).
double workshopInvoiceServiceCost({
  required double lengthCm,
  required double quantity,
  required double unitRate,
}) {
  if (lengthCm > 0 && quantity > 0) {
    return (lengthCm / 100.0) * quantity * unitRate;
  }
  if (quantity > 0) return quantity * unitRate;
  return unitRate;
}

/// Resolves the cubic-meter selling price of a workshop stock material
/// (identical lookup chain as the previous invoice/order builders).
double workshopInvoiceCubicSellingPrice(
  ERPProvider erp,
  WorkshopStockModel w,
) {
  if (w.category == 'متر مكعب' && w.recommendedSalePrice > 0)
    return w.recommendedSalePrice;
  final exactWorkshop = erp.workshopStock
      .where(
        (s) =>
            s.typeName.trim() == w.typeName.trim() &&
            s.grade.trim() == w.grade.trim() &&
            s.category == 'متر مكعب' &&
            s.recommendedSalePrice > 0,
      )
      .toList();
  if (exactWorkshop.isNotEmpty)
    return exactWorkshop.first.recommendedSalePrice;
  final matches = erp.workshopStock
      .where(
        (s) =>
            s.typeName.trim() == w.typeName.trim() &&
            s.category == 'متر مكعب' &&
            s.recommendedSalePrice > 0,
      )
      .toList();
  if (matches.isNotEmpty) return matches.first.recommendedSalePrice;
  final exactFac = erp.factoryWarehouse
      .where(
        (f) =>
            f.typeName.trim() == w.typeName.trim() &&
            f.grade.trim() == w.grade.trim() &&
            f.category == 'متر مكعب' &&
            f.recommendedSalePrice > 0,
      )
      .toList();
  if (exactFac.isNotEmpty) return exactFac.first.recommendedSalePrice;
  final facMatches = erp.factoryWarehouse
      .where(
        (f) =>
            f.typeName.trim() == w.typeName.trim() &&
            f.category == 'متر مكعب' &&
            f.recommendedSalePrice > 0,
      )
      .toList();
  if (facMatches.isNotEmpty) return facMatches.first.recommendedSalePrice;
  return w.recommendedSalePrice > 0
      ? w.recommendedSalePrice
      : (w.netCostPerUnit * 1.3);
}

/// Mutable draft state of a single invoice line row (left section).
class _InvoiceRow {
  static int _seq = 0;
  final String id =
      'wii_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // Bulk-selection checkbox (used while the row is still blank).
  bool selected = false;

  // Whether an item/product type has been assigned to this row.
  bool assigned = false;

  String sourceType = '';
  String sourceId = '';
  String sourceLineItemId = '';

  final descCtrl = TextEditingController();
  final lenCtrl = TextEditingController();
  final widCtrl = TextEditingController();
  final heiCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController(text: '0');

  String unitCategory = 'متر مربع';
  bool isGranite = false;
  String photoPath = '';
  double depositAmount = 0.0;

  // Net cost data preserved from the bound record (per m²/m³/piece), or a
  // flat override used for imported order items / scrap base cost.
  double netCostPerUnit = 0.0;
  double flatNetCost = -1;

  // Item-level services.
  bool hasService = false;
  final List<ServiceAttachment> services = [];
  String? pickedServiceId;
  final svcPriceCtrl = TextEditingController();
  final svcNotesCtrl = TextEditingController();

  double get len => double.tryParse(lenCtrl.text) ?? 0.0;
  double get wid => double.tryParse(widCtrl.text) ?? 0.0;
  double get hei => double.tryParse(heiCtrl.text) ?? 0.0;
  double get qty => double.tryParse(qtyCtrl.text) ?? 0.0;
  double get price => double.tryParse(priceCtrl.text) ?? 0.0;
  bool get isCube => unitCategory == 'متر مكعب';
  bool get hasDims => len > 0 && wid > 0;

  bool get isRaw => sourceType == 'بيع مواد خام من المعمل';
  bool get isSimple => sourceType == 'بيع خياطة بسيطة';

  /// Area/volume in meters for a raw-material row (0 otherwise).
  double get rawArea {
    if (!isRaw || qty <= 0) return 0.0;
    if (isCube) return hei > 0 ? (len / 100) * (wid / 100) * (hei / 100) * qty : 0.0;
    return hasDims ? (len / 100) * (wid / 100) * qty : 0.0;
  }

  /// Quantity consumed from the bound stock record (same rule as before:
  /// raw sells meters, tailoring sells meters, complex/scrap/order sell pieces).
  double get consumedQuantity => isRaw ? rawArea : qty;

  double get agreedPrice {
    if (!assigned) return 0.0;
    if (isRaw) return rawArea * price;
    return qty * price;
  }

  double get servicesTotal => services.fold(0.0, (s, e) => s + e.price);

  String get effectiveDescription =>
      descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'بند فاتورة';

  WorkshopInvoiceItem toItem() {
    double net;
    double count;
    if (flatNetCost >= 0) {
      net = flatNetCost;
    } else if (sourceType == 'طلب معمل') {
      net = agreedPrice * 0.60;
    } else {
      net = consumedQuantity * netCostPerUnit;
    }

    switch (sourceType) {
      case 'بيع خياطة بسيطة':
        final pieceArea = hasDims ? (len / 100) * (wid / 100) : 0.0;
        count = pieceArea > 0 ? (qty / pieceArea).roundToDouble() : qty;
        if (count <= 0) count = 1.0;
        break;
      case 'بيع خياطة معقدة':
      case 'بيع قطع إضافية':
        count = qty > 0 ? qty : 1.0;
        break;
      case 'طلب معمل':
        count = qty > 0 ? qty : 1.0;
        break;
      default:
        count = qty; // raw: number of pieces
    }

    return WorkshopInvoiceItem(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceLineItemId: sourceLineItemId,
      description: effectiveDescription,
      quantity: isRaw ? rawArea : qty,
      unitCategory: unitCategory,
      unitPrice: price,
      agreedPrice: agreedPrice,
      netCost: net,
      depositAmount: depositAmount,
      isGranite: isGranite,
      services: List.of(services),
      photoPath: photoPath,
      lengthCm: len,
      widthCm: wid,
      heightCm: isCube ? hei : 0.0,
      count: count,
    );
  }
}

/// Opens the Workshop Invoice builder (فاتورة المعمل).
void showWorkshopInvoiceDialog(
  BuildContext context,
  ERPProvider erp, {
  String? presetClientName,
  bool cashInvoice = false,
}) {
  String invCurrency = AppCurrency.usd;
  final clientCtrl = TextEditingController(text: presetClientName ?? '');
  String approvedClientSearch = '';
  List<ClientModel> approvedClientOptions() => erp.clients
      .where(
        (c) =>
            c.clientType == 'معتمد مصنع' &&
            (c.name.toLowerCase().contains(
                  approvedClientSearch.trim().toLowerCase(),
                ) ||
                c.phone.contains(approvedClientSearch.trim())),
      )
      .toList();

  final salesDiscountCtrl = TextEditingController(text: '0');
  final depositCtrl = TextEditingController(text: '0');
  final cashCtrl = TextEditingController(text: '0');
  final photoCtrl = TextEditingController();
  String? formError;
  String? batchError;
  String? linkedOrderId; // ID of the order linked to this invoice if imported

  // The item rows of this invoice (blank rows until a type is assigned).
  final List<_InvoiceRow> rows = [];

  // --- Batch / bulk assignment panel state (right section) ---
  String assignType = 'طلب معمل';
  String? assignOrderClient;
  String? assignOrderId;
  String rawSearch = '';
  String? assignRecordId; // tailoring / scrap / raw stock id
  String? assignLineItemId; // specific line item inside a simple tailoring

  // --- Bulk service assignment panel state (right section) ---
  String? batchServiceId;
  final batchSvcPriceCtrl = TextEditingController();
  final batchSvcNotesCtrl = TextEditingController();
  String? batchSvcError;

  double getAvailableStockForRaw(WorkshopStockModel w) {
    final used = rows
        .where((r) => r.assigned && r.isRaw && r.sourceId == w.id)
        .fold<double>(0.0, (s, r) => s + r.rawArea);
    return (w.availableQty - used).clamp(0.0, double.infinity);
  }

  double getAvailableForTailoring(WorkshopTailoringModel t) {
    final used = rows
        .where(
          (r) =>
              r.assigned &&
              (r.isSimple || r.sourceType == 'بيع خياطة معقدة') &&
              r.sourceId == t.id,
        )
        .fold<double>(0.0, (s, r) => s + r.qty);
    return (t.quantity - used).clamp(0.0, double.infinity);
  }

  void recomputeInvoiceFinancials() {
    final itemsTotal = rows
        .where((r) => r.assigned)
        .fold<double>(0.0, (s, r) => s + r.agreedPrice);
    final servicesTotal = rows
        .where((r) => r.assigned)
        .fold<double>(0.0, (s, r) => s + r.servicesTotal);
    final totalOrderDeposits = rows
        .where((r) => r.assigned)
        .fold<double>(0.0, (s, r) => s + r.depositAmount);
    if (linkedOrderId != null && totalOrderDeposits <= 0) {
      // If order linked, depositCtrl is kept as set by order
    } else if (totalOrderDeposits > 0) {
      depositCtrl.text = totalOrderDeposits.fmt;
    }

    final disc = double.tryParse(salesDiscountCtrl.text) ?? 0.0;
    final curDeposit = double.tryParse(depositCtrl.text) ?? 0.0;
    final grandTotal = (itemsTotal + servicesTotal - disc).clamp(
      0.0,
      double.infinity,
    );

    if (cashInvoice) {
      cashCtrl.text = (grandTotal - curDeposit)
          .clamp(0.0, double.infinity)
          .fmt;
    } else {
      if (cashCtrl.text.isEmpty || cashCtrl.text == '0') {
        cashCtrl.text = (grandTotal - curDeposit)
            .clamp(0.0, double.infinity)
            .fmt;
      }
    }
  }

  void resetBatchPickers() {
    assignOrderClient = null;
    assignOrderId = null;
    assignRecordId = null;
    assignLineItemId = null;
    rawSearch = '';
    batchError = null;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final dialogWidth = MediaQuery.of(ctx).size.width - 32;
        final dialogHeight = MediaQuery.of(ctx).size.height - 32;

        // Active orders grouped by customer name (excludes already-bound ones)
        final activeOrders = erp.workshopOrders
            .where((o) => o.status == 'قيد التنفيذ')
            .where(
              (o) =>
                  !rows.any((r) => r.assigned && r.sourceId == o.id) &&
                  linkedOrderId != o.id,
            )
            .toList();

        final Map<String, List<WorkshopOrderModel>> ordersByClient = {};
        for (final o in activeOrders) {
          final cName = o.clientName.trim().isEmpty
              ? 'عميل بدون اسم'
              : o.clientName.trim();
          ordersByClient.putIfAbsent(cName, () => []).add(o);
        }

        // Raw stock items
        final rawFiltered = erp.workshopStock
            .where((w) => getAvailableStockForRaw(w) > 0)
            .where(
              (w) =>
                  rawSearch.isEmpty ||
                  '${w.typeName} ${w.grade}'.contains(rawSearch),
            )
            .toList();
        final rawValue = rawFiltered.any((w) => w.id == assignRecordId)
            ? assignRecordId
            : null;

        final servicesFiltered = erp.services.toList();

        final blankRows = rows.where((r) => !r.assigned).toList();
        final selectedBlankRows = blankRows.where((r) => r.selected).toList();
        final assignedCount = rows.length - blankRows.length;
        final selectedAssignedRows = rows
            .where((r) => r.assigned && r.selected)
            .toList();

        // ---------- Batch assignment logic ----------
        void assignTypeToSelectedRows() {
          if (selectedBlankRows.isEmpty) {
            setSt(
              () => batchError =
                  'يرجى تحديد صفوف فارغة (☑) من يساراً قبل تعيين النوع.',
            );
            return;
          }
          if (assignType == 'طلب معمل') {
            if (assignOrderId == null) {
              setSt(() => batchError = 'يرجى اختيار الطلبية المراد إدراجها.');
              return;
            }
            final ord = erp.workshopOrders.firstWhere(
              (x) => x.id == assignOrderId,
            );
            linkedOrderId = ord.id;
            clientCtrl.text = ord.clientName;
            invCurrency = ord.currency;
            depositCtrl.text = ord.depositAmount.fmt;

            if (ord.items.isNotEmpty) {
              // Import order items verbatim into the selected blank rows
              // (extra items get new rows, extra blank rows stay empty).
              var converted = 0;
              for (final it in ord.items) {
                _InvoiceRow r;
                if (converted < selectedBlankRows.length) {
                  r = selectedBlankRows[converted];
                } else {
                  r = _InvoiceRow();
                  rows.add(r);
                }
                converted++;
                r.assigned = true;
                r.selected = false;
                r.sourceType = 'طلب معمل';
                r.sourceId = ord.id;
                r.sourceLineItemId = it.sourceLineItemId;
                r.descCtrl.text = it.description;
                r.unitCategory = it.unitCategory;
                r.isGranite = it.isGranite;
                r.photoPath = it.photoPath;
                r.depositAmount = 0.0;
                r.flatNetCost = it.netCost;
                r.netCostPerUnit = 0.0;
                r.lenCtrl.text = it.lengthCm > 0 ? it.lengthCm.fmt : '';
                r.widCtrl.text = it.widthCm > 0 ? it.widthCm.fmt : '';
                r.heiCtrl.text = it.heightCm > 0 ? it.heightCm.fmt : '';
                r.qtyCtrl.text = (it.sourceType == 'بيع مواد خام من المعمل' &&
                        it.count > 0
                    ? it.count
                    : it.quantity)
                    .fmt;
                r.priceCtrl.text = it.unitPrice.fmt;
                r.services.addAll(it.services);
                if (r.services.isNotEmpty) r.hasService = true;
              }
              for (final r in selectedBlankRows) {
                r.selected = false;
              }
            } else {
              // Single order item bound to each selected blank row.
              var first = true;
              for (final r in selectedBlankRows) {
                r.assigned = true;
                r.selected = false;
                r.sourceType = 'طلب معمل';
                r.sourceId = ord.id;
                r.sourceLineItemId = '';
                r.descCtrl.text = ord.customDimensionsText.isNotEmpty
                    ? ord.customDimensionsText
                    : 'طلب معمل ${ord.orderNo}';
                r.unitCategory = 'مقطوعية';
                r.isGranite = false;
                r.photoPath = ord.photoPath;
                r.netCostPerUnit = 0.0;
                r.flatNetCost = -1;
                r.depositAmount = first ? ord.depositAmount : 0.0;
                first = false;
                r.lenCtrl.clear();
                r.widCtrl.clear();
                r.heiCtrl.clear();
                r.qtyCtrl.text = '1';
                r.priceCtrl.text = ord.agreedPrice.fmt;
              }
            }
            assignOrderId = null;
            assignOrderClient = null;
            batchError = null;
            setSt(() => recomputeInvoiceFinancials());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تعيين نوع «طلب معمل» واستيراد بنود الطلبية ${ord.orderNo} وقيد العربون (${ord.depositAmount.fmt}). عدّل القيم داخل الصفوف مباشرةً.',
                ),
                backgroundColor: AppColors.successGreen,
              ),
            );
            return;
          }

          if (assignRecordId == null) {
            setSt(
              () => batchError =
                  assignType == 'بيع مواد خام من المعمل'
                  ? 'يرجى اختيار المادة الخام من مواد المعمل.'
                  : 'يرجى اختيار السجل أو التفصيل المراد إضافته.',
            );
            return;
          }

          switch (assignType) {
            case 'بيع مواد خام من المعمل':
              final w = erp.workshopStock.firstWhere(
                (x) => x.id == assignRecordId,
              );
              for (final r in selectedBlankRows) {
                r.assigned = true;
                r.selected = false;
                r.sourceType = assignType;
                r.sourceId = w.id;
                r.sourceLineItemId = '';
                r.unitCategory = w.category;
                r.isGranite = w.isGranite;
                r.photoPath = '';
                r.netCostPerUnit = w.netCostPerUnit;
                r.flatNetCost = -1;
                r.depositAmount = 0.0;
                r.descCtrl.text =
                    '${w.typeName} ${w.grade} ${w.thicknessCm}سم';
                r.lenCtrl.clear();
                r.widCtrl.clear();
                if (w.category == 'متر مكعب') {
                  r.heiCtrl.text = w.thicknessCm.fmt;
                  r.priceCtrl.text =
                      workshopInvoiceCubicSellingPrice(erp, w).fmt;
                } else {
                  r.heiCtrl.clear();
                  r.priceCtrl.text = (w.recommendedSalePrice > 0
                          ? w.recommendedSalePrice
                          : w.netCostPerUnit * 1.3)
                      .fmt;
                }
                r.qtyCtrl.text = '1';
              }
            case 'بيع خياطة بسيطة':
              final t = erp.simpleTailorings.firstWhere(
                (x) => x.id == assignRecordId,
              );
              TailoringLineItem? li;
              if (assignLineItemId != null) {
                final m = t.lineItems.where((x) => x.id == assignLineItemId);
                if (m.isNotEmpty) li = m.first;
              }
              for (final r in selectedBlankRows) {
                r.assigned = true;
                r.selected = false;
                r.sourceType = assignType;
                r.sourceId = t.id;
                r.sourceLineItemId = li?.id ?? '';
                r.unitCategory = 'متر مربع';
                r.isGranite = t.isGranite;
                r.photoPath = t.photoPath;
                r.netCostPerUnit = t.quantity > 0
                    ? t.totalNetCost / t.quantity
                    : 0.0;
                r.flatNetCost = -1;
                r.depositAmount = 0.0;
                r.descCtrl.text = li != null
                    ? '${t.name} - ${li.description}'
                    : t.name;
                r.lenCtrl.text = li != null && li.lengthCm > 0
                    ? li.lengthCm.fmt
                    : '';
                r.widCtrl.text = li != null && li.widthCm > 0
                    ? li.widthCm.fmt
                    : '';
                r.heiCtrl.clear();
                r.qtyCtrl.text = '1';
                r.priceCtrl.text =
                    (li != null && li.sellingPricePerMeter > 0
                        ? li.sellingPricePerMeter
                        : t.sellingPrice)
                    .fmt;
              }
            case 'بيع خياطة معقدة':
              final t = erp.complexTailorings.firstWhere(
                (x) => x.id == assignRecordId,
              );
              for (final r in selectedBlankRows) {
                r.assigned = true;
                r.selected = false;
                r.sourceType = assignType;
                r.sourceId = t.id;
                r.sourceLineItemId = '';
                r.unitCategory = 'قطعة';
                r.isGranite = t.isGranite;
                r.photoPath = t.photoPath;
                r.netCostPerUnit = t.quantity > 0
                    ? t.totalNetCost / t.quantity
                    : 0.0;
                r.flatNetCost = -1;
                r.depositAmount = 0.0;
                r.descCtrl.text = t.name;
                r.lenCtrl.clear();
                r.widCtrl.clear();
                r.heiCtrl.clear();
                r.qtyCtrl.text = '1';
                r.priceCtrl.text = t.sellingPrice.fmt;
              }
            case 'بيع قطع إضافية':
              final s = erp.scrapItems.firstWhere(
                (x) => x.id == assignRecordId,
              );
              for (final r in selectedBlankRows) {
                r.assigned = true;
                r.selected = false;
                r.sourceType = assignType;
                r.sourceId = s.id;
                r.sourceLineItemId = '';
                r.unitCategory = 'قطعة';
                r.isGranite = false;
                r.photoPath = s.photoPath;
                r.netCostPerUnit = 0.0;
                r.flatNetCost = s.baseCost;
                r.depositAmount = 0.0;
                r.descCtrl.text = s.description;
                final m = RegExp(
                  r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)',
                ).firstMatch(s.description);
                r.lenCtrl.text =
                    m != null ? (double.tryParse(m.group(1)!) ?? 0).fmt : '';
                r.widCtrl.text =
                    m != null ? (double.tryParse(m.group(2)!) ?? 0).fmt : '';
                r.heiCtrl.clear();
                r.qtyCtrl.text = '1';
                r.priceCtrl.text = s.sellingPrice.fmt;
              }
          }
          assignRecordId = null;
          assignLineItemId = null;
          batchError = null;
          setSt(() => recomputeInvoiceFinancials());
        }

        void addBlankRow() {
          setSt(() => rows.add(_InvoiceRow()));
        }

        // ---------- Bulk service assignment logic ----------
        void applyServiceToSelectedRows() {
          if (batchServiceId == null) {
            setSt(() => batchSvcError = 'يرجى اختيار الخدمة المراد تطبيقها.');
            return;
          }
          if (selectedAssignedRows.isEmpty) {
            setSt(
              () => batchSvcError =
                  'يرجى تحديد بنود (☑) من يساراً قبل تطبيق الخدمة.',
            );
            return;
          }
          final srv = erp.services.firstWhere((s) => s.id == batchServiceId);
          final fixed =
              double.tryParse(batchSvcPriceCtrl.text.trim()) ?? 0.0;
          setSt(() {
            for (final r in selectedAssignedRows) {
              // Default: per-item rule (length × quantity × unit rate).
              // A fixed price, when given, is applied uniformly instead.
              final price = fixed > 0
                  ? fixed
                  : (double.tryParse(
                        workshopInvoiceServiceCost(
                          lengthCm: r.len,
                          quantity: r.qty,
                          unitRate: srv.unitRate,
                        ).fmt,
                      ) ??
                      0.0);
              r.hasService = true;
              r.services.add(
                ServiceAttachment(
                  serviceName: srv.name,
                  price: price,
                  notes: batchSvcNotesCtrl.text.trim(),
                ),
              );
            }
            batchServiceId = null;
            batchSvcPriceCtrl.clear();
            batchSvcNotesCtrl.clear();
            batchSvcError = null;
            recomputeInvoiceFinancials();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تطبيق خدمة «${srv.name}» على ${selectedAssignedRows.length} بند محدد.',
              ),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }

        Widget numField(
          _InvoiceRow r,
          TextEditingController c,
          String label, {
          double width = 140,
          bool enabled = true,
          String? helper,
        }) {
          return SizedBox(
            width: width,
            child: TextField(
              controller: c,
              enabled: enabled && r.assigned,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                helperText: enabled && r.assigned ? helper : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: const OutlineInputBorder(),
                disabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (_) => setSt(() {
                recomputeInvoiceFinancials();
                // Keep the pending service price in sync with the rule:
                // length × quantity × service unit price.
                if (r.pickedServiceId != null) {
                  final srv = erp.services.firstWhere(
                    (s) => s.id == r.pickedServiceId,
                  );
                  r.svcPriceCtrl.text = workshopInvoiceServiceCost(
                    lengthCm: r.len,
                    quantity: r.qty,
                    unitRate: srv.unitRate,
                  ).fmt;
                }
              }),
            ),
          );
        }

        Widget typeChip(_InvoiceRow r) {
          Color chipColor = AppColors.chipBgSky;
          Color textColor = AppColors.orderDepositBoxAccent;
          if (!r.assigned) {
            chipColor = const Color(0xFFFEF3C7);
            textColor = const Color(0xFF92400E);
          } else if (r.isRaw) {
            chipColor = const Color(0xFFD1FAE5);
            textColor = const Color(0xFF065F46);
          } else if (r.sourceType == 'بيع قطع إضافية' ||
              r.sourceType == 'قطع زائدة') {
            chipColor = const Color(0xFFFEF3C7);
            textColor = const Color(0xFF92400E);
          } else if (r.sourceType == 'طلب معمل' ||
              r.sourceType == 'طلبية معمل') {
            chipColor = const Color(0xFFEDE9FE);
            textColor = const Color(0xFF5B21B6);
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              r.assigned ? r.sourceType : 'بدون نوع',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          );
        }

        String qtyLabel(_InvoiceRow r) {
          if (!r.assigned) return 'الكمية';
          switch (r.sourceType) {
            case 'بيع مواد خام من المعمل':
              return 'العدد / القطع';
            case 'بيع خياطة بسيطة':
              return 'الكمية بالمتر (م²)';
            case 'بيع خياطة معقدة':
              return 'عدد القطع';
            case 'بيع قطع إضافية':
              return 'عدد القطع';
            case 'طلب معمل':
              return 'الكمية';
            default:
              return 'الكمية';
          }
        }

        String priceLabel(_InvoiceRow r) {
          if (!r.assigned) return 'السعر';
          switch (r.sourceType) {
            case 'بيع مواد خام من المعمل':
              return 'سعر بيع المتر (${r.isCube ? "م³" : "م²"} \$)';
            case 'بيع خياطة بسيطة':
              return 'سعر المتر الإفرادي (\$)';
            case 'بيع خياطة معقدة':
              return 'سعر القطعة الإفرادي (\$)';
            case 'بيع قطع إضافية':
              return 'السعر (\$)';
            case 'طلب معمل':
              return 'سعر الطلبية (\$)';
            default:
              return 'السعر (\$)';
          }
        }

        Widget serviceEditor(_InvoiceRow r) {
          final svcValue =
              servicesFiltered.any((s) => s.id == r.pickedServiceId)
              ? r.pickedServiceId
              : null;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.handyman_outlined,
                      size: 16,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'خدمات مخصصة لهذا الصنف:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      'إجمالي خدمات الصنف: ${r.servicesTotal.fmt}\$',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: svcValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'اختر الخدمة',
                          isDense: true,
                        ),
                        items: servicesFiltered
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.unitRate}\$)'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() {
                          r.pickedServiceId = v;
                          if (v != null) {
                            final srv = erp.services.firstWhere(
                              (s) => s.id == v,
                            );
                            // Automatic: length × quantity × unit rate.
                            r.svcPriceCtrl.text = workshopInvoiceServiceCost(
                              lengthCm: r.len,
                              quantity: r.qty,
                              unitRate: srv.unitRate,
                            ).fmt;
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: r.svcPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'سعر الخدمة (\$)',
                          isDense: true,
                          helperText: 'طول × كمية × سعر الوحدة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: r.svcNotesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الخدمة (اختياري)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        if (svcValue == null) return;
                        final price =
                            double.tryParse(r.svcPriceCtrl.text) ?? 0.0;
                        if (price <= 0) return;
                        final srv = erp.services.firstWhere(
                          (s) => s.id == svcValue,
                        );
                        setSt(() {
                          r.services.add(
                            ServiceAttachment(
                              serviceName: srv.name,
                              price: price,
                              notes: r.svcNotesCtrl.text.trim(),
                            ),
                          );
                          r.pickedServiceId = null;
                          r.svcPriceCtrl.clear();
                          r.svcNotesCtrl.clear();
                          recomputeInvoiceFinancials();
                        });
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('إرفاق', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                if (r.services.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: r.services.asMap().entries.map((e) {
                      return Chip(
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.white,
                        label: Text(
                          '${e.value.serviceName}: ${e.value.price}\$',
                          style: const TextStyle(fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setSt(() {
                          r.services.removeAt(e.key);
                          recomputeInvoiceFinancials();
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }

        Widget itemRow(_InvoiceRow r, int idx) {
          final rawMaterial =
              r.assigned && r.isRaw
                  ? erp.workshopStock
                        .where((w) => w.id == r.sourceId)
                        .toList()
                        .firstOrNull
                  : null;
          return Container(
            decoration: BoxDecoration(
              color: r.assigned ? Colors.white : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: r.selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE2E8F0),
                width: r.selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row meta line
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          value: r.selected,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) =>
                              setSt(() => r.selected = v ?? false),
                        ),
                      ),
                      if (r.assigned) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      typeChip(r),
                      const SizedBox(width: 8),
                      if (r.assigned)
                        Expanded(
                          child: TextField(
                            controller: r.descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'وصف البند',
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        )
                      else
                        const Expanded(
                          child: Text(
                            'صف فارغ — حدّده ثم عيّن له النوع من اللوحة اليمنى',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        'خدمة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: r.assigned
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      Switch(
                        value: r.hasService,
                        activeColor: AppColors.accentPrimary,
                        onChanged: r.assigned
                            ? (v) => setSt(() {
                                r.hasService = v;
                                if (!v) {
                                  r.services.clear();
                                  r.pickedServiceId = null;
                                  r.svcPriceCtrl.clear();
                                  r.svcNotesCtrl.clear();
                                }
                                recomputeInvoiceFinancials();
                              })
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.dangerWaste,
                        ),
                        tooltip: 'حذف هذا الصنف',
                        onPressed: () => setSt(() {
                          rows.removeAt(idx);
                          recomputeInvoiceFinancials();
                        }),
                      ),
                    ],
                  ),
                ),

                // Horizontal entry fields: Length | Width | Height | Quantity | Price
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 860),
                    child: Row(
                      children: [
                        numField(r, r.lenCtrl, 'الطول (سم)', width: 150),
                        const SizedBox(width: 10),
                        numField(r, r.widCtrl, 'العرض (سم)', width: 150),
                        const SizedBox(width: 10),
                        numField(
                          r,
                          r.heiCtrl,
                          'الارتفاع = السماكة (سم)',
                          width: 170,
                          enabled: r.isCube,
                          helper: rawMaterial != null && r.isCube
                              ? 'سماكة المادة: ${rawMaterial.thicknessCm.fmt} سم'
                              : null,
                        ),
                        const SizedBox(width: 10),
                        numField(
                          r,
                          r.qtyCtrl,
                          qtyLabel(r),
                          width: 170,
                        ),
                        const SizedBox(width: 10),
                        numField(
                          r,
                          r.priceCtrl,
                          priceLabel(r),
                          width: 190,
                          helper:
                              rawMaterial != null && r.isCube
                              ? 'سعر المتر المكعب: ${workshopInvoiceCubicSellingPrice(erp, rawMaterial).fmt} \$'
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: r.assigned
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: r.assigned
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي البند',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.brandSecondaryText,
                                ),
                              ),
                              Text(
                                '${(r.agreedPrice + r.servicesTotal).fmt} ${AppCurrency.symbol(invCurrency)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: r.assigned
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (r.assigned && r.hasService) serviceEditor(r),

                if (r.depositAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 8),
                    child: Text(
                      'العربون المرفق مع الطلبية: ${r.depositAmount.fmt}\$',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        // ============ RIGHT SECTION 1: Client & currency ============
        Widget clientCard() {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'بيانات الفاتورة والعميل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 140,
                      child: CurrencySelector(
                        value: invCurrency,
                        dense: true,
                        onChanged: (v) => setSt(() => invCurrency = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'بحث عن معتمد بالاسم أو الهاتف',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (value) =>
                      setSt(() => approvedClientSearch = value),
                ),
                const SizedBox(height: 10),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'اختر المعتمد',
                    helperText: clientCtrl.text.isEmpty
                        ? null
                        : 'المعتمد المحدد: ${clientCtrl.text}',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: approvedClientOptions().any(
                            (c) => c.name == clientCtrl.text,
                          )
                          ? clientCtrl.text
                          : null,
                      hint: Text(
                        approvedClientOptions().isEmpty
                            ? 'لا يوجد معتمدون مطابقون للبحث'
                            : 'اختر معتمداً من شاشة الأشخاص',
                      ),
                      items: approvedClientOptions()
                          .map(
                            (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (name) {
                        if (name != null)
                          setSt(() {
                            clientCtrl.text = name;
                            formError = null;
                          });
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ============ RIGHT SECTION 2: Batch / bulk assignment ============
        Widget batchCard() {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إضافة وتعيين أنواع البنود (دفعة واحدة)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (selectedBlankRows.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${selectedBlankRows.length} محدد',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'انقر "+ إضافة بند" لكل صف فارغ تريده، حدّد الصفوف من يساراً، ثم عيّن نوع البند والسجل المرتبط دفعة واحدة.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'نوع البند (Source Type):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: assignType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'طلب معمل',
                      child: Text('طلب معمل (Factory Order)'),
                    ),
                    DropdownMenuItem(
                      value: 'بيع خياطة بسيطة',
                      child: Text('بيع خياطة بسيطة (Sell Simple Tailoring)'),
                    ),
                    DropdownMenuItem(
                      value: 'بيع خياطة معقدة',
                      child: Text('بيع خياطة معقدة (Sell Complex Tailoring)'),
                    ),
                    DropdownMenuItem(
                      value: 'بيع قطع إضافية',
                      child: Text('بيع قطع إضافية (Sell Extra Pieces)'),
                    ),
                    DropdownMenuItem(
                      value: 'بيع مواد خام من المعمل',
                      child: Text(
                        'بيع مواد خام من المعمل (Sell Raw Materials)',
                      ),
                    ),
                  ],
                  onChanged: (v) => setSt(() {
                    assignType = v!;
                    resetBatchPickers();
                  }),
                ),
                const SizedBox(height: 10),

                if (assignType == 'طلب معمل') ...[
                  if (ordersByClient.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.brandSecondaryText,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'لا توجد طلبيات معمل قيد التنفيذ متاحة للتحويل حالياً.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.brandSecondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Text(
                      'الطلبيات مجمعة بحسب اسم الزبون:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: assignOrderClient,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'اختر الزبون صاحب الطلبية',
                        isDense: true,
                        prefixIcon: Icon(Icons.people_outline, size: 18),
                      ),
                      items: ordersByClient.keys.map((cName) {
                        final count = ordersByClient[cName]!.length;
                        return DropdownMenuItem(
                          value: cName,
                          child: Text('$cName ($count طلبيات قيد التنفيذ)'),
                        );
                      }).toList(),
                      onChanged: (cName) => setSt(() {
                        assignOrderClient = cName;
                        assignOrderId = null;
                      }),
                    ),
                    if (assignOrderClient != null) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: assignOrderId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'اختر طلبية هذا الزبون لإدراجها',
                          isDense: true,
                          prefixIcon: Icon(Icons.assignment_outlined, size: 18),
                        ),
                        items: ordersByClient[assignOrderClient]!
                            .map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: Text(
                                  '${o.orderNo} • عربون: ${o.depositAmount.fmt}\$ • إجمالي: ${o.agreedPrice.fmt}\$ (${o.items.isNotEmpty ? o.items.length : 1} بنود)',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (oid) => setSt(() => assignOrderId = oid),
                      ),
                      if (assignOrderId != null)
                        Builder(
                          builder: (_) {
                            final ord = erp.workshopOrders.firstWhere(
                              (x) => x.id == assignOrderId,
                            );
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الطلبية: ${ord.orderNo} • الزبون: ${ord.clientName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قيمة العربون: ${ord.depositAmount.fmt} ${AppCurrency.symbol(ord.currency)} (يُقيد كدفعة ويتحول للصندوق الرئيسي)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orderDepositBoxAccent,
                                    ),
                                  ),
                                  if (ord.items.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'البنود الجاهزة للنقل: ${ord.items.map((i) => i.description).join(" ، ")}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ] else if (assignType == 'بيع مواد خام من المعمل') ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث مادة خام...',
                      prefixIcon: Icon(Icons.search, size: 16),
                      isDense: true,
                    ),
                    onChanged: (v) => setSt(() => rawSearch = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: rawValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر المادة الخام من مواد المعمل',
                      isDense: true,
                    ),
                    items: rawFiltered
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              '${w.typeName} ${w.grade} — المتاح: ${getAvailableStockForRaw(w).fmt} ${w.category == "متر مكعب" ? "م³" : "م²"} (سعر المتر: ${w.recommendedSalePrice.fmt}\$)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => assignRecordId = v),
                  ),
                ] else if (assignType == 'بيع خياطة بسيطة') ...[
                  DropdownButtonFormField<String>(
                    value: assignRecordId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الخياطة البسيطة',
                      isDense: true,
                    ),
                    items: erp.simpleTailorings
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} (المتاح: ${getAvailableForTailoring(t).fmt} ${t.unitSymbol})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() {
                      assignRecordId = v;
                      assignLineItemId = null;
                      if (v != null) {
                        final t = erp.simpleTailorings.firstWhere(
                          (x) => x.id == v,
                        );
                        if (t.lineItems.isNotEmpty) {
                          assignLineItemId = t.lineItems.first.id;
                        }
                      }
                    }),
                  ),
                  if (assignRecordId != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final t = erp.simpleTailorings.firstWhere(
                          (x) => x.id == assignRecordId,
                        );
                        return DropdownButtonFormField<String>(
                          value: assignLineItemId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText:
                                'اختر البند المحدد من داخل هذه الخياطة للبيع (اختياري)',
                            isDense: true,
                          ),
                          items: t.lineItems
                              .map((li) {
                                final pieceMeters =
                                    (li.lengthCm > 0 && li.widthCm > 0)
                                    ? (li.lengthCm / 100.0) *
                                          (li.widthCm / 100.0)
                                    : 1.0;
                                final totalLiMeters = pieceMeters * li.quantity;
                                return DropdownMenuItem(
                                  value: li.id,
                                  child: Text(
                                    '${li.description} • الأبعاد: ${li.lengthCm}×${li.widthCm}سم • المتاح: ${totalLiMeters.fmt} م² (${li.quantity.fmt} قطع)',
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (lv) =>
                              setSt(() => assignLineItemId = lv),
                        );
                      },
                    ),
                  ],
                ] else if (assignType == 'بيع خياطة معقدة') ...[
                  DropdownButtonFormField<String>(
                    value: assignRecordId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الخياطة المعقدة',
                      isDense: true,
                    ),
                    items: erp.complexTailorings
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} • المتاح: ${getAvailableForTailoring(t).fmt} قطع (سعر القطعة: ${t.sellingPrice.fmt}\$)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => assignRecordId = v),
                  ),
                ] else if (assignType == 'بيع قطع إضافية') ...[
                  DropdownButtonFormField<String>(
                    value: assignRecordId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر القطعة الإضافية',
                      isDense: true,
                    ),
                    items: erp.scrapItems
                        .where((s) => !s.isSold)
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${s.description} (${s.sellingPrice.fmt}\$)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => assignRecordId = v),
                  ),
                ],

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: selectedBlankRows.isEmpty
                        ? null
                        : assignTypeToSelectedRows,
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                    label: Text(
                      'تعيين النوع للصفوف المحددة (${selectedBlankRows.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (batchError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    batchError!,
                    style: const TextStyle(
                      color: AppColors.dangerWaste,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // ============ RIGHT SECTION 2b: Bulk service assignment ============
        Widget serviceBatchCard() {
          final batchSvcValue =
              servicesFiltered.any((s) => s.id == batchServiceId)
              ? batchServiceId
              : null;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.handyman_rounded,
                      size: 18,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'تطبيق خدمة على البنود المحددة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (selectedAssignedRows.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${selectedAssignedRows.length} بند محدد',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115E59),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'حدّد البنود (☑) من يساراً ثم اختر الخدمة؛ يُحسب سعر كل بند تلقائياً (طول × كمية × سعر وحدة الخدمة). أدخل سعراً موحداً لتثبيته على الكل بدلاً من الحساب التلقائي.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: batchSvcValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اختر الخدمة',
                    isDense: true,
                  ),
                  items: servicesFiltered
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.unitRate}\$)'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() {
                    batchServiceId = v;
                    batchSvcError = null;
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: batchSvcPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'سعر موحّد (\$) اختياري',
                          helperText: 'فارغ = حساب تلقائي لكل بند',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: batchSvcNotesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الخدمة (اختياري)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: selectedAssignedRows.isEmpty
                        ? null
                        : applyServiceToSelectedRows,
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: Text(
                      'تطبيق الخدمة على البنود المحددة (${selectedAssignedRows.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (batchSvcError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    batchSvcError!,
                    style: const TextStyle(
                      color: AppColors.dangerWaste,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // ============ RIGHT SECTION 3: Additional fields ============
        Widget additionalCard() {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'الخصم والدفعات النقدية للفاتورة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: salesDiscountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'خصم المبيعات المسموح',
                          isDense: true,
                        ),
                        onChanged: (_) => setSt(
                          () => recomputeInvoiceFinancials(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        final itemsTotal = rows
                            .where((r) => r.assigned)
                            .fold<double>(0.0, (s, r) => s + r.agreedPrice);
                        final servicesTotal = rows
                            .where((r) => r.assigned)
                            .fold<double>(0.0, (s, r) => s + r.servicesTotal);
                        final disc =
                            double.tryParse(salesDiscountCtrl.text) ?? 0.0;
                        final currentNet = (itemsTotal + servicesTotal - disc)
                            .clamp(0.0, double.infinity);
                        final truncated = currentNet.truncateToDouble();
                        final diff = currentNet - truncated;
                        if (diff > 0.0001) {
                          salesDiscountCtrl.text = (disc + diff).fmt;
                          recomputeInvoiceFinancials();
                          setSt(() {});
                        }
                      },
                      icon: const Icon(Icons.content_cut_rounded, size: 14),
                      label: const Text(
                        'تجاهل القروش',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cashInvoice) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'فاتورة نقدية: تُسدد بالكامل نقداً فور الإصدار بعد خصم عربون الطلبيات إن وجد.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ] else ...[
                  Builder(
                    builder: (context) {
                      final curDep =
                          double.tryParse(depositCtrl.text) ?? 0.0;
                      final curCash = double.tryParse(cashCtrl.text) ?? 0.0;
                      final itemsTotal = rows
                          .where((r) => r.assigned)
                          .fold<double>(0.0, (s, r) => s + r.agreedPrice);
                      final servicesTotal = rows
                          .where((r) => r.assigned)
                          .fold<double>(0.0, (s, r) => s + r.servicesTotal);
                      final disc =
                          double.tryParse(salesDiscountCtrl.text) ?? 0.0;
                      final gt = (itemsTotal + servicesTotal - disc).clamp(
                        0.0,
                        double.infinity,
                      );
                      String? depError;
                      String? cashError;
                      if (depositCtrl.text.isNotEmpty) {
                        if (curDep < 0) {
                          depError = 'لا يمكن أن يكون سالباً';
                        } else if (curDep > gt + 0.01) {
                          depError = 'العربون يتجاوز إجمالي الفاتورة';
                        }
                      }
                      if (cashCtrl.text.isNotEmpty) {
                        if (curCash < 0) {
                          cashError = 'لا يمكن أن يكون سالباً';
                        } else if (curDep + curCash > gt + 0.01) {
                          cashError = 'المجموع يتجاوز الفاتورة (${gt.fmt})';
                        }
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: depositCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'العربون المخصوم (\$)',
                                isDense: true,
                                errorText: depError,
                                helperText: 'الحد الأقصى: ${gt.fmt}',
                              ),
                              onChanged: (_) => setSt(
                                () => recomputeInvoiceFinancials(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: cashCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'النقد المدفوع الآن (\$)',
                                isDense: true,
                                errorText: cashError,
                                helperText:
                                    'أقصى نقد إضافي: ${(gt - curDep).clamp(0.0, double.infinity).fmt}',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                AppImageAttachmentPicker(
                  initialPath: photoCtrl.text,
                  label: 'صورة الفاتورة / الوصل',
                  onImageChanged: (p) => setSt(() => photoCtrl.text = p),
                ),
              ],
            ),
          );
        }

        // ============ LEFT BOTTOM: Financial summary ============
        Widget summarySection() {
          final itemsTotal = rows
              .where((r) => r.assigned)
              .fold<double>(0.0, (s, r) => s + r.agreedPrice);
          final servicesTotal = rows
              .where((r) => r.assigned)
              .fold<double>(0.0, (s, r) => s + r.servicesTotal);
          final salesDiscount =
              double.tryParse(salesDiscountCtrl.text) ?? 0.0;
          final grandTotal = (itemsTotal + servicesTotal - salesDiscount)
              .clamp(0.0, double.infinity);
          final totalDeposits = double.tryParse(depositCtrl.text) ?? 0.0;
          final cashPaid = double.tryParse(cashCtrl.text) ?? 0.0;
          final remaining = grandTotal - totalDeposits - cashPaid;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مجموع الأصناف: ${itemsTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'مجموع الخدمات: ${servicesTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'الخصم: -${salesDiscount.fmt} ${AppCurrency.symbol(invCurrency)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الإجمالي النهائي للفاتورة:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.brandSecondaryText,
                          ),
                        ),
                        Text(
                          '${grandTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المدفوع: ${(cashPaid + totalDeposits).fmt} ${AppCurrency.symbol(invCurrency)}'
                          '${totalDeposits > 0 ? " (عربون ${totalDeposits.fmt})" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'المتبقي: ${remaining.fmt} ${AppCurrency.symbol(invCurrency)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: remaining <= 0.01
                                    ? AppColors.successGreen
                                    : AppColors.dangerWaste,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: remaining < -0.01
                                    ? const Color(0xFFFEE2E2)
                                    : (remaining <= 0.01
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E8)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                remaining < -0.01
                                    ? 'تجاوز (${(-remaining).fmt})!'
                                    : (remaining <= 0.01
                                          ? 'مسددة بالكامل'
                                          : 'متبقي ذمة'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: remaining < -0.01
                                      ? const Color(0xFFB91C1C)
                                      : (remaining <= 0.01
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB91C1C)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // ============ SAVE ============
        void saveInvoice() {
          if (rows.isEmpty) {
            setSt(
              () => formError = 'يجب إضافة صنف واحد على الأقل للفاتورة.',
            );
            return;
          }
          final unassignedCount = rows.where((r) => !r.assigned).length;
          if (unassignedCount > 0) {
            setSt(
              () => formError =
                  'لا يمكن الحفظ: يوجد $unassignedCount صف فارغ بدون نوع بند. عيّن النوع للصفوف المحددة من اللوحة اليمنى أو احذف الصفوف الفارغة.',
            );
            return;
          }

          // Per-row validation (same rules as the previous add-time checks)
          for (var i = 0; i < rows.length; i++) {
            final r = rows[i];
            final no = i + 1;
            if (r.isRaw) {
              if (r.rawArea <= 0) {
                setSt(
                  () => formError =
                      'بند $no (${r.effectiveDescription}): يرجى تحديد الأبعاد والكمية الصحيحة للبند.',
                );
                return;
              }
              final wMatches = erp.workshopStock
                  .where((w) => w.id == r.sourceId)
                  .toList();
              if (wMatches.isNotEmpty &&
                  r.rawArea > getAvailableStockForRaw(wMatches.first) + 0.0001) {
                setSt(
                  () => formError =
                      'بند $no (${r.effectiveDescription}): الكمية المطلوبة تتجاوز الرصيد المتاح.',
                );
                return;
              }
            } else if (r.isSimple) {
              final tMatches = erp.simpleTailorings
                  .where((t) => t.id == r.sourceId)
                  .toList();
              if (tMatches.isNotEmpty) {
                final avail = getAvailableForTailoring(tMatches.first);
                if (r.qty <= 0 || r.qty > avail + 0.0001) {
                  setSt(
                    () => formError =
                        'بند $no (${r.effectiveDescription}): الكمية المطلوبة غير صحيحة أو تتجاوز المتاح.',
                  );
                  return;
                }
              }
            } else if (r.sourceType == 'بيع خياطة معقدة') {
              final tMatches = erp.complexTailorings
                  .where((t) => t.id == r.sourceId)
                  .toList();
              if (tMatches.isNotEmpty) {
                final avail = getAvailableForTailoring(tMatches.first);
                if (r.qty <= 0 || r.qty > avail + 0.0001) {
                  setSt(
                    () => formError =
                        'بند $no (${r.effectiveDescription}): عدد القطع المطلوب غير صحيح أو يتجاوز المتاح.',
                  );
                  return;
                }
              }
            }
          }

          final draftItems = rows.map((r) => r.toItem()).toList();

          if (!erp.clients.any(
            (c) => c.clientType == 'معتمد مصنع' && c.name == clientCtrl.text,
          )) {
            setSt(() => formError = 'يرجى اختيار معتمد من قائمة الأشخاص.');
            return;
          }

          final itemsTotal = draftItems.fold<double>(
            0.0,
            (s, i) => s + i.agreedPrice,
          );
          final servicesTotal = draftItems.fold<double>(
            0.0,
            (s, i) => s + i.servicesTotal,
          );
          final salesDiscount =
              double.tryParse(salesDiscountCtrl.text) ?? 0.0;
          final grandTotal = (itemsTotal + servicesTotal - salesDiscount)
              .clamp(0.0, double.infinity);

          if (salesDiscount < 0 || salesDiscount > itemsTotal + servicesTotal) {
            setSt(() => formError = 'قيمة خصم المبيعات غير صحيحة.');
            return;
          }

          final enteredDeposit = double.tryParse(depositCtrl.text) ?? 0.0;
          final deposit = enteredDeposit;
          final cash = cashInvoice
              ? (grandTotal - deposit).clamp(0.0, double.infinity)
              : (double.tryParse(cashCtrl.text) ?? 0.0);

          if (deposit < 0) {
            setSt(
              () => formError = 'خطأ: قيمة العربون لا يمكن أن تكون سالبة.',
            );
            return;
          }
          if (cash < 0) {
            setSt(
              () => formError = 'خطأ: قيمة النقد المدفوع لا يمكن أن تكون سالبة.',
            );
            return;
          }
          if (deposit + cash > grandTotal + 0.01) {
            final maxCash = (grandTotal - deposit).clamp(0.0, double.infinity);
            setSt(
              () => formError =
                  'خطأ: إجمالي الدفعات (العربون ${deposit.fmt} + النقد ${cash.fmt}) يتجاوز إجمالي قيمة الفاتورة (${grandTotal.fmt}). الحد الأقصى للنقد الإضافي المسموح به: ${maxCash.fmt} ${AppCurrency.symbol(invCurrency)}.',
            );
            return;
          }

          // Determine overall sourceType
          final sourcesSet = draftItems.map((i) => i.sourceType).toSet();
          final String overallSourceType = sourcesSet.length == 1
              ? sourcesSet.first
              : (linkedOrderId != null
                    ? 'طلب معمل'
                    : 'مصادر متعددة (${sourcesSet.join(" + ")})');

          final invoice = WorkshopInvoiceModel(
            id: 'wi_${DateTime.now().millisecondsSinceEpoch}',
            invoiceNo: 'WRK-INV-${erp.workshopInvoices.length + 101}',
            date: DateTime.now(),
            clientName: clientCtrl.text.trim(),
            items: List.of(draftItems),
            sourceType: overallSourceType,
            sourceId: linkedOrderId ?? draftItems.first.sourceId,
            projectId: '',
            itemDescription: draftItems.map((i) => i.description).join(' + '),
            sourceQuantity: draftItems.fold<double>(
              0.0,
              (s, i) => s + i.quantity,
            ),
            sourceUnitCategory: draftItems.first.unitCategory,
            agreedPrice: itemsTotal,
            depositDeducted: deposit,
            cashPaidNow: cash,
            netCost: draftItems.fold<double>(
              0.0,
              (s, i) => s + i.netCost,
            ),
            salesDiscount: salesDiscount,
            services: draftItems.expand((i) => i.services).toList(),
            photoPath: photoCtrl.text.trim(),
            isGranite: draftItems.any((i) => i.isGranite),
            isCashInvoice: cashInvoice,
            currency: invCurrency,
          );

          final created = erp.createWorkshopInvoice(invoice);
          if (!created) {
            setSt(
              () => formError = cashInvoice
                  ? 'تعذر اعتماد الفاتورة النقدية؛ تحقق من المخزون أو تسوية المبلغ بالكامل.'
                  : 'المخزون غير كافٍ أو تعذر اعتماد الفاتورة.',
            );
            return;
          }

          // Ensure linked order is marked as completed and migrated
          if (linkedOrderId != null) {
            final ordMatches = erp.workshopOrders
                .where((o) => o.id == linkedOrderId)
                .toList();
            if (ordMatches.isNotEmpty) {
              ordMatches.first.status = 'مكتملة ومرحلة';
              erp.saveToDisk();
            }
          }

          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (cashInvoice
                    ? 'تم إصدار فاتورة البيع النقدية وتحصيلها بالكامل بنجاح.'
                    : 'تم إصدار وحفظ فاتورة المعمل بنجاح وترحيل العربون والذمة للزبون.'),
              ),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }

        // ---------- Body ----------
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cashInvoice
                            ? Icons.point_of_sale_rounded
                            : Icons.receipt_long_rounded,
                        color: AppColors.accentPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              cashInvoice
                                  ? 'فاتورة بيع نقدية (مسددة بالكامل)'
                                  : 'إنشاء فاتورة معمل',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (cashInvoice) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'مبيعات نقدية',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$assignedCount بنود مضافة',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            if (blankRows.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${blankRows.length} صف فارغ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // DUAL-PANE MAIN BODY:
                // Left side  = Item rows + financial summary
                // Right side = Client, batch assignment, additional fields, save
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ==========================================
                        // LEFT SECTION: ITEM ROWS + FINANCIAL SUMMARY
                        // (widest pane — items need clear visibility)
                        // ==========================================
                        Expanded(
                          flex: 3,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              color: const Color(0xFFF8FAFC),
                              child: Column(
                                children: [
                                  // Rows header + Add Item button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.view_list_rounded,
                                          size: 20,
                                          color: AppColors.accentPrimary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'بنود الفاتورة — حقول الأبعاد والكمية والسعر لكل بند',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (rows.isNotEmpty) ...[
                                          SizedBox(
                                            height: 32,
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              onPressed: () => setSt(() {
                                                final allSel = rows.every(
                                                  (r) => r.selected,
                                                );
                                                for (final r in rows) {
                                                  r.selected = !allSel;
                                                }
                                              }),
                                              icon: const Icon(
                                                Icons.select_all_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'تحديد الكل',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                          ),
                                          onPressed: addBlankRow,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text(
                                            '+ إضافة بند',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Item rows list
                                  Expanded(
                                    child: rows.isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long_outlined,
                                                    size: 64,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  const Text(
                                                    'لم يتم إضافة أي صنف للفاتورة بعد',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  const Text(
                                                    'انقر "+ إضافة بند" لتوليد صفوف فارغة، ثم حدّدها وعيّن نوع البند دفعة واحدة من اللوحة اليمنى.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .brandSecondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.all(12),
                                            itemCount: rows.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, idx) =>
                                                itemRow(rows[idx], idx),
                                          ),
                                  ),

                                  // Financial invoice summary (bottom-left)
                                  summarySection(),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0xFFCBD5E1),
                        ),

                        // ==========================================
                        // RIGHT SECTION: CLIENT • BATCH • ADDITIONAL • SAVE
                        // ==========================================
                        Expanded(
                          flex: 2,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          clientCard(),
                                          const SizedBox(height: 14),
                                          batchCard(),
                                          const SizedBox(height: 14),
                                          serviceBatchCard(),
                                          const SizedBox(height: 14),
                                          additionalCard(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Save invoice (bottom-right)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        if (formError != null) ...[
                                          Text(
                                            formError!,
                                            style: const TextStyle(
                                              color: AppColors.dangerWaste,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.accentPrimary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: saveInvoice,
                                            child: Text(
                                              (cashInvoice
                                                  ? 'إصدار فاتورة البيع النقدية وتحصيلها'
                                                  : 'إصدار وحفظ فاتورة المعمل'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
