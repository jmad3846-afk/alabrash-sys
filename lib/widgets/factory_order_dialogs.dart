import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import 'currency_selector.dart';
import 'app_image_attachment.dart';
import 'a4_invoice_print_dialog.dart';

/// Shows dialog to create a new Factory Order with identical structure
/// to Factory Accredited Agents Sales Invoice, but including a Deposit / Down Payment.
void showAddFactoryOrderDialog(
  BuildContext context,
  ERPProvider erp, {
  void Function(FactoryOrderModel)? onOrderCreated,
}) {
  final approvedClients =
      erp.clients.where((c) => c.clientType == 'معتمد مصنع').toList();

  if (approvedClients.isEmpty || erp.factoryWarehouse.isEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.dangerWaste),
            SizedBox(width: 8),
            Expanded(child: Text('لا يمكن إضافة طلبية مصنع')),
          ],
        ),
        content: Text(
          'يجب توفر بيانات أساسية أولاً:\n'
          '${approvedClients.isEmpty ? "• معتمد مصنع واحد على الأقل في قسم الأشخاص\n" : ""}'
          '${erp.factoryWarehouse.isEmpty ? "• بضاعة متوفرة في مستودع المصنع\n" : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    return;
  }

  String? selectedClientId;
  String clientSearch = '';
  String? selectedWhId;
  String goodsSearch = '';
  final lengthCtrl = TextEditingController();
  final widthCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final unitPriceCtrl = TextEditingController();
  final depositCtrl = TextEditingController();
  final salesDiscountCtrl = TextEditingController(text: '0');
  final shippingCtrl = TextEditingController();
  final photoCtrl = TextEditingController();
  bool? deliverByUs;
  String? formError;
  String orderCurrency = AppCurrency.usd;

  final List<FactoryInvoiceItem> draftItems = [];

  // Services attached to the item currently being built
  String? selectedServiceId;
  String serviceSearch = '';
  final servicePriceCtrl = TextEditingController();
  final serviceNotesCtrl = TextEditingController();
  final List<ServiceAttachment> draftServices = [];
  String selectedItemMeterUnit = 'متر مربع';

  double getFactoryCubicSellingPrice(FactoryWarehouseModel item) {
    if (item.category == 'متر مكعب' && item.recommendedSalePrice > 0) {
      return item.recommendedSalePrice;
    }
    final matches = erp.factoryWarehouse.where(
      (w) => w.typeName.trim() == item.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0,
    ).toList();
    if (matches.isNotEmpty) {
      return matches.first.recommendedSalePrice;
    }
    return item.recommendedSalePrice;
  }

  double draftArea(
    FactoryWarehouseModel? wh,
    double l,
    double w,
    double h,
    double q,
    bool isCube,
  ) {
    if (wh == null || l <= 0 || w <= 0 || q <= 0) return 0.0;
    if (isCube) {
      if (h <= 0) return 0.0;
      return (l / 100.0) * (w / 100.0) * (h / 100.0) * q;
    }
    return (l / 100.0) * (w / 100.0) * q;
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final clientsFiltered = approvedClients
            .where(
              (c) => clientSearch.isEmpty || c.name.contains(clientSearch),
            )
            .toList();
        final clientValue = clientsFiltered.any((c) => c.id == selectedClientId)
            ? selectedClientId
            : null;

        final goodsFiltered = erp.factoryWarehouse
            .where(
              (w) =>
                  goodsSearch.isEmpty ||
                  '${w.typeName} ${w.grade} ${w.thicknessCm}'.contains(
                    goodsSearch,
                  ),
            )
            .toList();
        final goodsValue = goodsFiltered.any((w) => w.id == selectedWhId)
            ? selectedWhId
            : null;
        final matches =
            erp.factoryWarehouse.where((w) => w.id == selectedWhId).toList();
        final FactoryWarehouseModel? wh =
            matches.isEmpty ? null : matches.first;
        final bool isCube = selectedItemMeterUnit == 'متر مكعب' || wh?.category == 'متر مكعب';

        if (wh != null) {
          if (isCube) {
            if (heightCtrl.text.isEmpty && wh.thicknessCm > 0) {
              heightCtrl.text = wh.thicknessCm.fmt;
            }
            if (unitPriceCtrl.text.isEmpty) {
              final cp = getFactoryCubicSellingPrice(wh);
              if (cp > 0) unitPriceCtrl.text = cp.fmt;
            }
          } else {
            if (unitPriceCtrl.text.isEmpty && wh.recommendedSalePrice > 0) {
              unitPriceCtrl.text = wh.recommendedSalePrice.fmt;
            }
          }
        }

        final double l = double.tryParse(lengthCtrl.text) ?? 0.0;
        final double w = double.tryParse(widthCtrl.text) ?? 0.0;
        final double h = double.tryParse(heightCtrl.text) ?? 0.0;
        final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
        final double price = double.tryParse(unitPriceCtrl.text) ?? 0.0;
        final double area = draftArea(wh, l, w, h, q, isCube);
        final double draftTotal = area * price;

        void autoCalcServicePrice() {
          if (selectedServiceId == null) return;
          final srvMatches =
              erp.services.where((s) => s.id == selectedServiceId).toList();
          if (srvMatches.isEmpty) return;
          final srv = srvMatches.first;

          final rawL = double.tryParse(lengthCtrl.text) ?? 0.0;
          final double curLenM = rawL > 0 ? (rawL / 100.0) : 0.0;
          final double curQty = double.tryParse(qtyCtrl.text) ?? 0.0;

          if (curLenM > 0 && curQty > 0) {
            final double calc = curLenM * curQty * srv.unitRate;
            servicePriceCtrl.text = calc.toStringAsFixed(2);
            serviceNotesCtrl.text =
                'طول ${curLenM.fmt}م × ${curQty.fmt} قطع × ${srv.unitRate.fmt}\$';
          } else if (curQty > 0) {
            final double calc = curQty * srv.unitRate;
            servicePriceCtrl.text = calc.toStringAsFixed(2);
            serviceNotesCtrl.text =
                '${curQty.fmt} قطع × ${srv.unitRate.fmt}\$';
          } else {
            servicePriceCtrl.text = srv.unitRate.toStringAsFixed(2);
            serviceNotesCtrl.text = 'سعر الوحدة: ${srv.unitRate.fmt}\$';
          }
        }

        final double itemsTotal = draftItems.fold(
          0.0,
          (s, it) => s + it.totalPrice,
        );
        final double itemsServicesTotal = draftItems.fold(
          0.0,
          (s, it) => s + it.servicesTotal,
        );
        final double shipping = (deliverByUs == true)
            ? (double.tryParse(shippingCtrl.text) ?? 0.0)
            : 0.0;
        final double salesDiscount =
            double.tryParse(salesDiscountCtrl.text) ?? 0.0;
        final double grandTotal =
            (itemsTotal + itemsServicesTotal + shipping - salesDiscount)
                .clamp(0.0, double.infinity);
        final double deposit = double.tryParse(depositCtrl.text) ?? 0.0;
        final double remaining =
            (grandTotal - deposit).clamp(0.0, double.infinity);

        final servicesFiltered = erp.services
            .where(
              (s) => serviceSearch.isEmpty || s.name.contains(serviceSearch),
            )
            .toList();
        final serviceValue =
            servicesFiltered.any((s) => s.id == selectedServiceId)
                ? selectedServiceId
                : null;

        double draftedFor(String whId) => draftItems
            .where((it) => it.itemId == whId)
            .fold(0.0, (s, it) => s + it.calculatedArea);

        return Dialog(
          child: Container(
            width: 780,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.orderDepositBoxAccent
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.post_add_rounded,
                                color: AppColors.orderDepositBoxAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'إضافة طلبية مصنع جديدة (Factory Order)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    'تخضع لبنية فاتورة مبيعات المعتمدين وتتضمن عربوناً يودع في صندوق الطلبيات المعزول',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.brandSecondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // 1. Approved client searchable dropdown
                  const Text(
                    '1. المعتمد / الزبون (Approved Client):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'بحث عن معتمد...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setSt(() => clientSearch = v.trim()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: clientValue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'اختر المعتمد'),
                    items: clientsFiltered
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.location})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => selectedClientId = v),
                  ),
                  const SizedBox(height: 16),

                  // 2. Factory Warehouse Goods (Multi-item line builder)
                  const Text(
                    '2. أصناف بضاعة مستودع المصنع (Line Items):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث صنف المستودع (النوع والدرجة)...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setSt(() => goodsSearch = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: goodsValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع البضاعة حسب مستودع المصنع',
                    ),
                    items: goodsFiltered
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              '${g.typeName} ${g.grade} ${g.thicknessCm}سم (${g.category}) — المتاح: ${g.availableQty} — سعر المتر: ${g.recommendedSalePrice.fmt} \$',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setSt(() {
                        selectedWhId = v;
                        if (v != null) {
                          final mList = erp.factoryWarehouse
                              .where((g) => g.id == v)
                              .toList();
                          if (mList.isNotEmpty) {
                            final selWh = mList.first;
                            selectedItemMeterUnit = selWh.category == 'متر مكعب' ? 'متر مكعب' : 'متر مربع';
                            if (selectedItemMeterUnit == 'متر مكعب') {
                              heightCtrl.text = selWh.thicknessCm.fmt;
                              final cp = getFactoryCubicSellingPrice(selWh);
                              unitPriceCtrl.text = cp > 0 ? cp.fmt : (selWh.recommendedSalePrice > 0 ? selWh.recommendedSalePrice.fmt : '');
                            } else {
                              heightCtrl.clear();
                              if (selWh.recommendedSalePrice > 0) {
                                unitPriceCtrl.text =
                                    selWh.recommendedSalePrice.fmt;
                              }
                            }
                          }
                        }
                        autoCalcServicePrice();
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  if (wh != null) ...[
                    Row(
                      children: [
                        const Text(
                          'وحدة القياس / البيع:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('متر مربع (م²)'),
                          selected: !isCube,
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                selectedItemMeterUnit = 'متر مربع';
                                heightCtrl.clear();
                                if (wh.recommendedSalePrice > 0) {
                                  unitPriceCtrl.text = wh.recommendedSalePrice.fmt;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('متر مكعب (م³)'),
                          selected: isCube,
                          selectedColor: const Color(0xFFDCFCE7),
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                selectedItemMeterUnit = 'متر مكعب';
                                heightCtrl.text = wh.thicknessCm.fmt;
                                final cp = getFactoryCubicSellingPrice(wh);
                                if (cp > 0) unitPriceCtrl.text = cp.fmt;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lengthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'الطول (سم)',
                            ),
                            onChanged: (_) {
                              autoCalcServicePrice();
                              setSt(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: widthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'العرض (سم)',
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        if (isCube) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'الارتفاع = السماكة (سم)',
                                helperText: 'سماكة المادة: ${wh.thicknessCm.fmt} سم',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'الكمية (العدد)',
                            ),
                            onChanged: (_) {
                              autoCalcServicePrice();
                              setSt(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unitPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'سعر المتر (${isCube ? "م³" : "م²"} \$)',
                              helperText: isCube
                                  ? 'سعر المتر المكعب للمادة: ${getFactoryCubicSellingPrice(wh).fmt} \$'
                                  : (wh.recommendedSalePrice > 0
                                      ? 'سعر المستودع: ${wh.recommendedSalePrice.fmt} \$'
                                      : null),
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chipBgBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'إجمالي قيمة البند:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${draftTotal.fmt} \$',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Prominent calculated meters display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF86EFAC),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.straighten_rounded,
                              color: Color(0xFF15803D),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'إجمالي عدد الأمتار المحسوبة للبند:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                    Text(
                                      '${area.fmt} ${isCube ? "متر مكعب (م³)" : "متر مربع (م²)"}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (l > 0 && w > 0 && q > 0)
                                      ? 'طريقة الحساب: (الطول ${(l / 100.0).fmt}م × العرض ${(w / 100.0).fmt}م ${isCube ? "× الارتفاع ${(h / 100.0).fmt}م " : ""}× العدد ${q.fmt} قطع) = ${area.fmt} ${isCube ? "م³" : "م²"}'
                                      : 'أدخل الطول والعرض والعدد لاحتساب إجمالي الأمتار تلقائياً قبل إضافة الصنف',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: (l > 0 && w > 0 && q > 0)
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Services attachment section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.miscellaneous_services_rounded,
                                size: 18,
                                color: AppColors.accentPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'إلحاق خدمات مصنعية بالبند (اختياري):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
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
                                  initialValue: serviceValue,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'اختر الخدمة',
                                    isDense: true,
                                  ),
                                  items: servicesFiltered
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(
                                            '${s.name} (${s.unitRate}\$)',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setSt(() {
                                      selectedServiceId = v;
                                      autoCalcServicePrice();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: servicePriceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'التكلفة (\$)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: serviceNotesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'ملاحظات الخدمة',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  if (selectedServiceId == null) return;
                                  final srv = erp.services.firstWhere(
                                    (s) => s.id == selectedServiceId,
                                  );
                                  final p =
                                      double.tryParse(servicePriceCtrl.text) ??
                                          srv.unitRate;
                                  setSt(() {
                                    draftServices.add(
                                      ServiceAttachment(
                                        serviceName: srv.name,
                                        price: p,
                                        notes: serviceNotesCtrl.text.trim(),
                                      ),
                                    );
                                    selectedServiceId = null;
                                    servicePriceCtrl.clear();
                                    serviceNotesCtrl.clear();
                                  });
                                },
                                child: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                          if (draftServices.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: draftServices.asMap().entries.map((e) {
                                return Chip(
                                  label: Text(
                                    '${e.value.serviceName}: ${e.value.price.fmt}\$ ${e.value.notes.isNotEmpty ? "(${e.value.notes})" : ""}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => setSt(
                                    () => draftServices.removeAt(e.key),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          if (selectedClientId == null) {
                            setSt(() => formError = 'اختر المعتمد أولاً.');
                            return;
                          }
                          if (area <= 0) {
                            setSt(
                              () => formError = 'أدخل أبعاداً وكمية صحيحة.',
                            );
                            return;
                          }
                          if (price < 0) {
                            setSt(() => formError = 'أدخل سعر وحدة صحيح.');
                            return;
                          }
                          final available =
                              wh.availableQty - draftedFor(wh.id);
                          if (area > available + 0.0001) {
                            setSt(
                              () => formError =
                                  'الكمية تتجاوز المتاح في المستودع (${available.fmt}).',
                            );
                            return;
                          }
                          setSt(() {
                            formError = null;
                            draftItems.add(
                              FactoryInvoiceItem(
                                itemId: wh.id,
                                description:
                                    '${wh.typeName} ${wh.grade} ${wh.thicknessCm}سم',
                                typeName: wh.typeName,
                                grade: wh.grade,
                                lengthCm: l,
                                widthCm: w,
                                heightCm: isCube ? h : 0.0,
                                quantity: q,
                                unitPrice: price,
                                unitCost: wh.netCostPerUnit,
                                isGranite: wh.isGranite,
                                services: List.of(draftServices),
                                thicknessCm: wh.thicknessCm,
                                meterUnit: isCube ? 'متر مكعب' : 'متر مربع',
                                itemCategory: isCube ? 'متر مكعب' : 'meter',
                              ),
                            );
                            draftServices.clear();
                            lengthCtrl.clear();
                            widthCtrl.clear();
                            heightCtrl.clear();
                            qtyCtrl.clear();
                            unitPriceCtrl.clear();
                            selectedWhId = null;
                          });
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('إضافة البند إلى بنود الطلبية +'),
                      ),
                    ),
                  ],

                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.chipBgRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.dangerWaste,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Draft items table
                  if (draftItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'لم تتم إضافة بنود للطلبية بعد. اختر صنفاً وأدخله بالزر أعلاه.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ),
                  ...draftItems.asMap().entries.map(
                    (e) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.chipBgBlue,
                          child: Text('${e.key + 1}'),
                        ),
                        title: Text(
                          e.value.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${e.value.calculatedArea.fmt} ${e.value.heightCm > 5 ? "م³" : "م²"} × ${e.value.unitPrice}\$ + خدمات ${e.value.servicesTotal.fmt}\$ = ${e.value.grandTotal.fmt}\$',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.dangerWaste,
                          ),
                          onPressed: () =>
                              setSt(() => draftItems.removeAt(e.key)),
                        ),
                        children: [
                          ...e.value.services.map(
                            (s) => ListTile(
                              dense: true,
                              title: Text(s.serviceName),
                              subtitle: Text(s.notes.isEmpty ? '—' : s.notes),
                              trailing: Text(
                                '${s.price}\$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Totals, Currency, Deposit & Delivery
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CurrencySelector(
                                value: orderCurrency,
                                dense: true,
                                onChanged: (v) =>
                                    setSt(() => orderCurrency = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: salesDiscountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'خصم مبيعات مسموح (اختياري)',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي قيمة الطلبية (بضاعة + خدمات):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${grandTotal.fmt} ${AppCurrency.symbol(orderCurrency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // CRITICAL MANDATORY FIELD: Deposit / Down payment
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.orderDepositBoxAccent
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.orderDepositBoxAccent
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.savings_rounded,
                                    color: AppColors.orderDepositBoxAccent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'العربون / الدفعة المقدمة (Deposit / Down Payment):',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.orderDepositBoxAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'يتم إيداع العربون حصرياً في "صندوق الطلبيات المعزول"، ويتم خصم الأمتار المستهلكة من مستودع المصنع.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: depositCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      'قيمة العربون (${AppCurrency.symbol(orderCurrency)}) *',
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.attach_money_rounded,
                                    color: AppColors.orderDepositBoxAccent,
                                  ),
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المتبقي على الزبون عند الاستلام:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: remaining > 0
                                          ? AppColors.dangerWaste
                                          : AppColors.successGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${remaining.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: remaining > 0
                                          ? AppColors.dangerWaste
                                          : AppColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delivery options
                        const Text(
                          'خيارات التوصيل والشحن:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setSt(() => deliverByUs = false),
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: false,
                                      groupValue: deliverByUs,
                                      onChanged: (v) =>
                                          setSt(() => deliverByUs = v),
                                    ),
                                    const Text('الزبون يستلم النقل'),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setSt(() => deliverByUs = true),
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      groupValue: deliverByUs,
                                      onChanged: (v) =>
                                          setSt(() => deliverByUs = v),
                                    ),
                                    const Text('نوصّل نحن'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (deliverByUs == true)
                          TextField(
                            controller: shippingCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تكلفة التوصيل / الشحن (\$)',
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        const SizedBox(height: 12),
                        AppImageAttachmentPicker(
                          initialPath: photoCtrl.text,
                          label: 'صورة الطلبية / المخطط الفني',
                          onImageChanged: (p) =>
                              setSt(() => photoCtrl.text = p),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orderDepositBoxAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (selectedClientId == null) {
                        setSt(() => formError = 'يرجى اختيار المعتمد.');
                        return;
                      }
                      if (draftItems.isEmpty) {
                        setSt(
                          () => formError = 'أضف صنفاً واحداً على الأقل للطلبية.',
                        );
                        return;
                      }
                      if (deposit < 0) {
                        setSt(() => formError = 'أدخل عربوناً صحيحاً.');
                        return;
                      }
                      if (deposit > grandTotal) {
                        setSt(
                          () => formError =
                              'العربون لا يمكن أن يتجاوز إجمالي الطلبية.',
                        );
                        return;
                      }

                      final client = erp.clients.firstWhere(
                        (c) => c.id == selectedClientId,
                      );

                      final order = FactoryOrderModel(
                        id: 'fo_${DateTime.now().millisecondsSinceEpoch}',
                        orderNo:
                            'FORD-${erp.factoryOrders.length + 101}',
                        date: DateTime.now(),
                        partyId: client.id,
                        clientName: client.name,
                        clientPhone: client.phone,
                        items: List.of(draftItems),
                        shippingFee: shipping,
                        isGoodsDelivered: deliverByUs == true,
                        discountAmount: salesDiscount,
                        depositAmount: deposit,
                        photoPath: photoCtrl.text.trim(),
                        currency: orderCurrency,
                      );

                      erp.createFactoryOrder(order);
                      Navigator.pop(ctx);

                      if (onOrderCreated != null) {
                        onOrderCreated(order);
                      }

                      // Show immediate confirmation & workshop print preview dialog
                      showFactoryOrderSuccessDialog(context, order);
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'حفظ وتأكيد طلبية المصنع وإيداع العربون',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Success dialog offering one-click "Preview for Printing" for the workshop.
void showFactoryOrderSuccessDialog(
  BuildContext context,
  FactoryOrderModel order,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 28),
          SizedBox(width: 10),
          Expanded(child: Text('تم حفظ طلبية المصنع بنجاح')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رقم الطلبية: ${order.orderNo}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('الزبون / المعتمد: ${order.clientName}'),
          const SizedBox(height: 4),
          Text(
            'إجمالي الأمتار المحسوبة: ${order.totalArea.fmt} م • عدد البنود: ${order.items.length}',
          ),
          const SizedBox(height: 4),
          Text(
            'إجمالي القيمة: ${order.grandTotal.fmt} ${order.currencySymbol}',
          ),
          const SizedBox(height: 4),
          Text(
            'العربون المحجوز في صندوق الطلبيات: ${order.depositAmount.fmt} ${order.currencySymbol}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.orderDepositBoxAccent,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم خصم الأمتار المستهلكة من مستودع المصنع، وتم عزل العربون في صندوق الطلبيات.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            A4InvoicePrintDialog.show(
              context,
              invoiceData: A4InvoiceData.fromFactoryOrder(order),
            );
          },
          icon: const Icon(Icons.print_rounded),
          label: const Text('معاينة للطباعة (أمر تشغيل للورشة)'),
        ),
      ],
    ),
  );
}

/// Cancellation dialog implementing the exact logic:
/// - Asks whether order is completed or not completed.
/// - If completed: deposit is NOT refunded and remains in Orders Safe,
///   while exact meters consumed in line items return to Factory Warehouse.
/// - If not completed: option to refund deposit to customer (or keep it),
///   and exact meters consumed return to Factory Warehouse.
void showCancelFactoryOrderDialog(
  BuildContext context,
  ERPProvider erp,
  FactoryOrderModel order,
) {
  bool isCompleted = false;
  bool refundDeposit = true;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.dangerWaste, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text('إلغاء طلبية المصنع (${order.orderNo})')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الزبون: ${order.clientName} • العربون في صندوق الطلبيات: ${order.depositAmount.fmt} ${order.currencySymbol}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'إجمالي الأمتار المستهلكة في بنود الطلبية: ${order.totalArea.fmt} م',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const Divider(height: 20),

              const Text(
                'هل تم إنجاز / قص وتجهيز الطلبية في ورشة المصنع؟',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 10),

              // Option 1: Completed
              InkWell(
                onTap: () => setSt(() => isCompleted = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.accentPrimary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.accentPrimary
                          : AppColors.panelBorder,
                      width: isCompleted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: isCompleted,
                        onChanged: (v) => setSt(() => isCompleted = v!),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'نعم، الطلبية مكتملة (تم إنجازها في الورشة)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '• لا يتم استرجاع العربون (${order.depositAmount.fmt} ${order.currencySymbol}) ويبقى في صندوق الطلبيات.\n'
                              '• يتم إرجاع الأمتار المستهلكة (${order.totalArea.fmt} م) إلى مستودع المصنع.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: Not Completed
              InkWell(
                onTap: () => setSt(() => isCompleted = false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !isCompleted
                        ? AppColors.accentPrimary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !isCompleted
                          ? AppColors.accentPrimary
                          : AppColors.panelBorder,
                      width: !isCompleted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: false,
                        groupValue: isCompleted,
                        onChanged: (v) => setSt(() => isCompleted = v!),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'لا، الطلبية غير مكتملة (لم يتم إنجازها)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '• يتوفر خيار استرجاع العربون للزبون أو إبقائه.\n'
                              '• يتم إرجاع الأمتار المستهلكة (${order.totalArea.fmt} م) إلى مستودع المصنع.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // If NOT completed: Option to refund deposit
              if (!isCompleted && order.depositAmount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خيار استرجاع العربون للزبون:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'استرجاع العربون للزبون (${order.depositAmount.fmt} ${order.currencySymbol})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          refundDeposit
                              ? 'سيتم رد العربون نقداً للزبون وخصمه من صندوق الطلبيات.'
                              : 'لن يتم رد العربون وسيبقى في صندوق الطلبيات.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: refundDeposit,
                        activeColor: AppColors.dangerWaste,
                        onChanged: (v) => setSt(() => refundDeposit = v),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerWaste,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              erp.cancelFactoryOrder(
                order: order,
                isCompleted: isCompleted,
                refundDeposit: !isCompleted && refundDeposit,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isCompleted
                        ? 'تم إلغاء الطلبية كمكتملة: بقي العربون في الصندوق وأعيدت الأمتار لمستودع المصنع.'
                        : refundDeposit
                            ? 'تم إلغاء الطلبية واسترجاع العربون للزبون وأعيدت الأمتار لمستودع المصنع.'
                            : 'تم إلغاء الطلبية مع إبقاء العربون وأعيدت الأمتار لمستودع المصنع.',
                  ),
                  backgroundColor: AppColors.dangerWaste,
                ),
              );
            },
            child: const Text('تأكيد إلغاء الطلبية'),
          ),
        ],
      ),
    ),
  );
}
