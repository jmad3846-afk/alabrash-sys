import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/database/form_draft_store.dart';
import '../core/models/models.dart';
import 'currency_selector.dart';
import 'app_image_attachment.dart';
import 'a4_invoice_print_dialog.dart';

/// Per-row field controllers and Tab focus nodes for the factory order
/// item rows. Kept index-aligned with the draftItems list so keyboard
/// Tab cycles only through [Length, Width, Height, Quantity, Price].
class _OrderRowEdit {
  final lenCtrl = TextEditingController();
  final widCtrl = TextEditingController();
  final heiCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final lenFocus = FocusNode(debugLabel: 'order-row-len');
  final widFocus = FocusNode(debugLabel: 'order-row-wid');
  final heiFocus = FocusNode(debugLabel: 'order-row-hei');
  final qtyFocus = FocusNode(debugLabel: 'order-row-qty');
  final priceFocus = FocusNode(debugLabel: 'order-row-price');
}

/// Shows dialog to create a new Factory Order with identical structure
/// to Factory Accredited Agents Sales Invoice, but including a Deposit / Down Payment.
void showAddFactoryOrderDialog(
  BuildContext context,
  ERPProvider erp, {
  FactoryOrderModel? existingOrder,
  void Function(FactoryOrderModel)? onOrderCreated,
  void Function(FactoryInvoiceItem item, void Function(FactoryInvoiceItem) onSave)?
  onEditItem,
}) {
  final approvedClients = erp.clients
      .where((c) => c.clientType == 'معتمد مصنع')
      .toList();

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

  // ---- Auto-saved session draft: reopening this dialog restores the
  // unsaved form state; a successful save or "تجاهل المسودة" clears it.
  final draftKey = FormDraftStore.keyFor(
    FormDraftStore.factoryOrderKey,
    existingOrder == null ? 'new' : 'edit:${existingOrder.id}',
  );
  final draft = FormDraftStore.load(draftKey);

  String? selectedClientId =
      draft?['selectedClientId'] as String? ?? existingOrder?.partyId;
  String clientSearch = draft?['clientSearch'] as String? ?? '';
  String? selectedWhId = draft?['selectedWhId'] as String?;
  String goodsSearch = draft?['goodsSearch'] as String? ?? '';
  final depositCtrl = TextEditingController(
    text:
        draft?['deposit'] as String? ?? existingOrder?.depositAmount.fmt ?? '',
  );
  final salesDiscountCtrl = TextEditingController(
    text:
        draft?['salesDiscount'] as String? ??
        existingOrder?.discountAmount.fmt ??
        '0',
  );
  final shippingCtrl = TextEditingController(
    text: draft?['shipping'] as String? ?? existingOrder?.shippingFee.fmt ?? '',
  );
  final photoCtrl = TextEditingController(
    text: draft?['photo'] as String? ?? existingOrder?.photoPath ?? '',
  );
  bool? deliverByUs = draft != null
      ? draft['deliverByUs'] as bool?
      : existingOrder?.isGoodsDelivered;
  String? formError;
  bool showAdditionalInformation = draft?['showAdditional'] as bool? ?? false;
  String orderCurrency =
      draft?['currency'] as String? ??
      existingOrder?.currency ??
      AppCurrency.usd;

  final List<FactoryInvoiceItem> draftItems = draft != null
      ? (draft['items'] as List)
            .map(
              (m) => FactoryInvoiceItem.fromJson(
                Map<String, dynamic>.from(m as Map),
              ).copyWith(),
            )
            .toList()
      : existingOrder?.items.map((item) => item.copyWith()).toList() ?? [];

  // Bulk row selection (first selection: assign material/type; second
  // selection on bound rows: apply services).
  final Set<int> selectedDraftRows = <int>{
    ...((draft?['selectedRows'] as List?)?.map(
          (e) => (e as num).toInt(),
        ) ??
        const <int>[]),
  };

  // Per-row controllers + Tab focus nodes, index-aligned with draftItems.
  final rowEdits = <_OrderRowEdit>[];
  void syncRowEdit(int idx, FactoryInvoiceItem it) {
    final edit = rowEdits[idx];
    void push(TextEditingController c, double v) {
      final text = v > 0 ? v.fmt : '';
      if (c.text != text) c.text = text;
    }
    push(edit.lenCtrl, it.lengthCm);
    push(edit.widCtrl, it.widthCm);
    push(edit.heiCtrl, it.heightCm);
    push(edit.qtyCtrl, it.quantity);
    push(edit.priceCtrl, it.unitPrice);
  }

  void rebuildRowEdits() {
    rowEdits.clear();
    for (var i = 0; i < draftItems.length; i++) {
      rowEdits.add(_OrderRowEdit());
    }
    for (var i = 0; i < draftItems.length; i++) {
      syncRowEdit(i, draftItems[i]);
    }
  }

  rebuildRowEdits();

  // Bulk service application state.
  String? bulkServiceId = draft?['bulkServiceId'] as String?;
  final bulkSvcPriceCtrl = TextEditingController(
    text: draft?['bulkSvcPrice'] as String? ?? '',
  );
  final bulkSvcNotesCtrl = TextEditingController(
    text: draft?['bulkSvcNotes'] as String? ?? '',
  );
  String? bulkSvcError;

  // Snapshot of the entire live form state; called on every rebuild so any
  // typed value, selection, row edit, or toggle survives an accidental
  // close until the order is saved or the draft is discarded.
  void persistDraft() => FormDraftStore.save(draftKey, () => {
    'selectedClientId': selectedClientId,
    'clientSearch': clientSearch,
    'selectedWhId': selectedWhId,
    'goodsSearch': goodsSearch,
    'deposit': depositCtrl.text,
    'salesDiscount': salesDiscountCtrl.text,
    'shipping': shippingCtrl.text,
    'photo': photoCtrl.text,
    'deliverByUs': deliverByUs,
    'showAdditional': showAdditionalInformation,
    'currency': orderCurrency,
    'bulkServiceId': bulkServiceId,
    'bulkSvcPrice': bulkSvcPriceCtrl.text,
    'bulkSvcNotes': bulkSvcNotesCtrl.text,
    'selectedRows': selectedDraftRows.toList(),
    'items': draftItems.map((it) => it.toJson()).toList(),
  });

  double getFactoryCubicSellingPrice(FactoryWarehouseModel item) {
    if (item.category == 'متر مكعب' && item.recommendedSalePrice > 0) {
      return item.recommendedSalePrice;
    }
    final matches = erp.factoryWarehouse
        .where(
          (w) =>
              w.typeName.trim() == item.typeName.trim() &&
              w.category == 'متر مكعب' &&
              w.recommendedSalePrice > 0,
        )
        .toList();
    if (matches.isNotEmpty) {
      return matches.first.recommendedSalePrice;
    }
    return item.recommendedSalePrice;
  }

  // ---- Tab navigation restricted to the item value fields ----
  // Tab / Shift+Tab cycle only through [Length, Width, Height, Quantity,
  // Price] of the bound rows (Height participates only on m³ rows), and
  // never move focus to any other field inside this dialog.
  List<FocusNode> orderTabNodes() {
    final nodes = <FocusNode>[];
    for (var i = 0; i < draftItems.length; i++) {
      final it = draftItems[i];
      if (it.itemId.isEmpty) continue;
      final edit = rowEdits[i];
      nodes.add(edit.lenFocus);
      nodes.add(edit.widFocus);
      if (it.meterUnit == 'متر مكعب' || it.heightCm > 0) {
        nodes.add(edit.heiFocus);
      }
      nodes.add(edit.qtyFocus);
      nodes.add(edit.priceFocus);
    }
    return nodes;
  }

  void moveOrderTabFocus({required bool forward}) {
    final nodes = orderTabNodes();
    if (nodes.isEmpty) return;
    final current = FocusManager.instance.primaryFocus;
    final idx = current == null ? -1 : nodes.indexOf(current);
    if (idx == -1) {
      nodes.first.requestFocus();
      return;
    }
    final next = forward
        ? (idx + 1) % nodes.length
        : (idx - 1 + nodes.length) % nodes.length;
    nodes[next].requestFocus();
  }

  if (draft != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت استعادة مسودة الطلبية غير المحفوظة تلقائياً.'),
          backgroundColor: AppColors.orderDepositBoxAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        persistDraft();
        final clientsFiltered = approvedClients
            .where(
              (c) => arabicFuzzyMatch(
                '${c.name} ${c.phone} ${c.location}',
                clientSearch,
              ),
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
        final matches = erp.factoryWarehouse
            .where((w) => w.id == selectedWhId)
            .toList();
        final FactoryWarehouseModel? wh = matches.isEmpty
            ? null
            : matches.first;

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
            (itemsTotal + itemsServicesTotal + shipping - salesDiscount).clamp(
              0.0,
              double.infinity,
            );
        final double deposit = double.tryParse(depositCtrl.text) ?? 0.0;
        final double remaining = (grandTotal - deposit).clamp(
          0.0,
          double.infinity,
        );

          // ---- Bulk service application on the selected rows ----
          // First selection assigns the material/type to the rows; this
          // second selection (rows already bound) applies a service to all
          // of them at once.
          final bulkSvcTargets = selectedDraftRows
              .where(
                (i) =>
                    i < draftItems.length && draftItems[i].itemId.isNotEmpty,
              )
              .toList();

          void applyBulkService() {
            if (bulkServiceId == null) {
              setSt(() => bulkSvcError = 'يرجى اختيار الخدمة المراد تطبيقها.');
              return;
            }
            if (bulkSvcTargets.isEmpty) {
              setSt(
                () => bulkSvcError =
                    'يرجى تحديد بنود مرتبطة بمادة (☑) قبل تطبيق الخدمة.',
              );
              return;
            }
            final srv = erp.services.firstWhere((s) => s.id == bulkServiceId);
            final fixed = double.tryParse(bulkSvcPriceCtrl.text.trim()) ?? 0.0;
            setSt(() {
              for (final i in bulkSvcTargets) {
                final it = draftItems[i];
                // Automatic per-item rule: length(m) × quantity × unit
                // rate; a fixed price, when given, overrides it uniformly.
                final rawPrice = fixed > 0
                    ? fixed
                    : (it.lengthCm > 0 && it.quantity > 0
                          ? (it.lengthCm / 100.0) * it.quantity * srv.unitRate
                          : it.quantity > 0
                          ? it.quantity * srv.unitRate
                          : srv.unitRate);
                final price = double.tryParse(rawPrice.fmt) ?? rawPrice;
                draftItems[i] = it.copyWith(
                  services: [
                    ...it.services,
                    ServiceAttachment(
                      serviceName: srv.name,
                      price: price,
                      notes: bulkSvcNotesCtrl.text.trim(),
                    ),
                  ],
                );
              }
              bulkServiceId = null;
              bulkSvcPriceCtrl.clear();
              bulkSvcNotesCtrl.clear();
              bulkSvcError = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تطبيق خدمة «${srv.name}» على ${bulkSvcTargets.length} بند محدد.',
                ),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }

          Widget bulkServicePanel() {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5EEAD4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          ),
                        ),
                      ),
                      if (bulkSvcTargets.isNotEmpty)
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
                            '${bulkSvcTargets.length} بند محدد',
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
                    'يُحسب سعر الخدمة لكل بند تلقائياً (الطول بالمتر × العدد × سعر وحدة الخدمة)؛ أدخل سعراً موحداً لتثبيته على الكل. يبقى تعيين الخدمات الفردية لكل بند كما هو.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: bulkServiceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الخدمة',
                      isDense: true,
                    ),
                    items: erp.services
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.unitRate.fmt}\$)'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() {
                      bulkServiceId = v;
                      bulkSvcError = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bulkSvcPriceCtrl,
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
                          controller: bulkSvcNotesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الخدمة (اختياري)',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed:
                        bulkSvcTargets.isEmpty ? null : applyBulkService,
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: Text(
                      'تطبيق الخدمة على البنود المحددة (${bulkSvcTargets.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (bulkSvcError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      bulkSvcError!,
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

          // ---------- Body ----------
          // Tab / Shift+Tab are captured for the whole dialog and redirected
          // ONLY through the item value fields (Length, Width, Height,
          // Quantity, Price) of the bound rows.
          return Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
              SingleActivator(LogicalKeyboardKey.tab, shift: true):
                  PreviousFocusIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                NextFocusIntent: CallbackAction<NextFocusIntent>(
                  onInvoke: (_) {
                    moveOrderTabFocus(forward: true);
                    return null;
                  },
                ),
                PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
                  onInvoke: (_) {
                    moveOrderTabFocus(forward: false);
                    return null;
                  },
                ),
              },
              child: Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Container(
            width: MediaQuery.of(ctx).size.width - 32,
            height: MediaQuery.of(ctx).size.height - 32,
            padding: const EdgeInsets.all(16),
            child: Column(
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
                                children: [
                                  Text(
                                    existingOrder == null
                                        ? 'إضافة طلبية مصنع جديدة (Factory Order)'
                                        : 'تعديل طلبية المصنع (${existingOrder.orderNo})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const Text(
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
                      OutlinedButton.icon(
                        onPressed: () {
                          FormDraftStore.discard(draftKey);
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerWaste,
                          side: const BorderSide(color: AppColors.dangerWaste),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('تجاهل المسودة'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'إغلاق (تبقى المسودة محفوظة)',
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              color: Colors.white,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                  const Text(
                    'بيانات العميل وإضافة البنود',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: clientValue,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'اختر المعتمد',
                          ),
                          items: clientsFiltered
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.location.isEmpty
                                        ? c.name
                                        : '${c.name} • ${c.location}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setSt(() => selectedClientId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: CurrencySelector(
                          value: orderCurrency,
                          dense: true,
                          onChanged: (v) => setSt(() => orderCurrency = v),
                        ),
                      ),
                    ],
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
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // تعيين المادة دفعة واحدة للصفوف المحددة (التحديد الأول).
                  if (selectedDraftRows.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: wh == null
                            ? null
                            : () => setSt(() {
                                  final isCubeWh = wh.category == 'متر مكعب';
                                  for (final rowIndex in selectedDraftRows) {
                                    final row = draftItems[rowIndex];
                                    final cp = getFactoryCubicSellingPrice(wh);
                                    draftItems[rowIndex] = row.copyWith(
                                      itemId: wh.id,
                                      description:
                                          '${wh.typeName} ${wh.grade} ${wh.thicknessCm}سم',
                                      typeName: wh.typeName,
                                      grade: wh.grade,
                                      unitPrice: isCubeWh && cp > 0
                                          ? cp
                                          : (wh.recommendedSalePrice > 0
                                                ? wh.recommendedSalePrice
                                                : row.unitPrice),
                                      unitCost: wh.netCostPerUnit,
                                      isGranite: wh.isGranite,
                                      thicknessCm: wh.thicknessCm,
                                      // سماكة > 5سم => المتر المكعب يُفعّل
                                      // حقل الارتفاع تلقائياً.
                                      heightCm: isCubeWh
                                          ? wh.thicknessCm
                                          : row.heightCm,
                                      meterUnit: isCubeWh
                                          ? 'متر مكعب'
                                          : 'متر مربع',
                                      itemCategory: isCubeWh
                                          ? 'متر مكعب'
                                          : 'meter',
                                    );
                                    syncRowEdit(rowIndex, draftItems[rowIndex]);
                                  }
                                  selectedDraftRows.clear();
                                  formError = null;
                                }),
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text(
                          'تعيين المادة للصفوف المحددة (${selectedDraftRows.length})',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // البديل الجديد لإضافة البنود: صفوف فارغة من القسم الأيمن،
                  // تُحدَّد (☑) ثم تُعيَّن لها المادة دفعة واحدة من هنا.
                  if (bulkSvcTargets.isNotEmpty) bulkServicePanel(),
                  if (wh != null && selectedDraftRows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'المادة المحددة: ${wh.typeName} ${wh.grade} ${wh.thicknessCm}سم — حدّد صفوف البنود (☑) من قسم «بنود الطلبية والملخص» ثم اضغط «تعيين المادة للصفوف المحددة»، وعدّل الأبعاد والكمية والسعر داخل كل صف مباشرة.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.w600,
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
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          flex: 6,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              color: const Color(0xFFF8FAFC),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'بنود الطلبية والملخص',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => setSt(() {
                            draftItems.add(
                              FactoryInvoiceItem(
                                itemId: '',
                                description: 'صف جديد — اختر المادة',
                                quantity: 0,
                                unitPrice: 0,
                                unitCost: 0,
                                itemCategory: 'meter',
                              ),
                            );
                            rowEdits.add(_OrderRowEdit());
                          }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة صف'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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

                    // Draft items table — كل بند صف أفقي قابل للتعديل
                    if (draftItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'لم تتم إضافة بنود للطلبية بعد. أضف صفوفاً من الزر أعلاه، حدّدها ثم عيّن المادة من لوحة الإدخال.',
                          style: TextStyle(color: AppColors.brandSecondaryText),
                        ),
                      ),
                    ...draftItems.asMap().entries.map((e) {
                      final it = e.value;
                      final rowEdit = rowEdits[e.key];
                      final rowCube =
                          it.meterUnit == 'متر مكعب' || it.heightCm > 0;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          leading: Tooltip(
                            message:
                                'تحديد: أولاً للتعيين الجماعي للمادة، ثم للخدمات',
                            child: Checkbox(
                              value: selectedDraftRows.contains(e.key),
                              onChanged: (_) => setSt(() {
                                if (!selectedDraftRows.add(e.key)) {
                                  selectedDraftRows.remove(e.key);
                                }
                              }),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  it.description,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: rowEdit.lenCtrl,
                                  focusNode: rowEdit.lenFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الطول',
                                    isDense: true,
                                  ),
                                  onChanged: (value) => setSt(() {
                                    draftItems[e.key] = it.copyWith(
                                      lengthCm:
                                          double.tryParse(value) ?? 0,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: rowEdit.widCtrl,
                                  focusNode: rowEdit.widFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'العرض',
                                    isDense: true,
                                  ),
                                  onChanged: (value) => setSt(() {
                                    draftItems[e.key] = it.copyWith(
                                      widthCm:
                                          double.tryParse(value) ?? 0,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 95,
                                child: TextFormField(
                                  controller: rowEdit.heiCtrl,
                                  focusNode: rowEdit.heiFocus,
                                  enabled: rowCube,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الارتفاع',
                                    isDense: true,
                                  ),
                                  onChanged: (value) => setSt(() {
                                    draftItems[e.key] = it.copyWith(
                                      heightCm:
                                          double.tryParse(value) ?? 0,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: rowEdit.qtyCtrl,
                                  focusNode: rowEdit.qtyFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'العدد',
                                    isDense: true,
                                  ),
                                  onChanged: (value) => setSt(() {
                                    draftItems[e.key] = it.copyWith(
                                      quantity:
                                          double.tryParse(value) ?? 0,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 95,
                                child: TextFormField(
                                  controller: rowEdit.priceCtrl,
                                  focusNode: rowEdit.priceFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'السعر',
                                    isDense: true,
                                  ),
                                  onChanged: (value) => setSt(() {
                                    draftItems[e.key] = it.copyWith(
                                      unitPrice:
                                          double.tryParse(value) ?? 0,
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${it.calculatedArea.fmt} ${rowCube ? "م³" : "م²"} × ${it.unitPrice.fmt}\$ + خدمات ${it.servicesTotal.fmt}\$ = ${it.grandTotal.fmt}\$',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEditItem != null)
                                IconButton(
                                  tooltip: 'تعديل البند',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => onEditItem(it, (updated) {
                                    setSt(() {
                                      draftItems[e.key] = updated;
                                      syncRowEdit(e.key, updated);
                                    });
                                  }),
                                ),
                              IconButton(
                                tooltip: 'حذف البند',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerWaste,
                                ),
                                onPressed: () => setSt(() {
                                  draftItems.removeAt(e.key);
                                  rowEdits.removeAt(e.key);
                                  selectedDraftRows.clear();
                                }),
                              ),
                            ],
                          ),
                          children: [
                            if (it.itemId.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'صف فارغ — حدّده ثم عيّن له المادة من لوحة الإدخال (يساراً).',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (it.services.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'لا توجد خدمات مرفقة بهذا البند',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.brandSecondaryText,
                                  ),
                                ),
                              )
                            else
                              ...it.services.map(
                                (s) => ListTile(
                                  dense: true,
                                  title: Text(
                                    s.serviceName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    s.notes.isEmpty ? '—' : s.notes,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  trailing: Text(
                                    '${s.price.fmt}\$',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),


                    const SizedBox(height: 16),
                  // Order pricing summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('ملخص الطلبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الأصناف'), Text('${itemsTotal.fmt} ${AppCurrency.symbol(orderCurrency)}')]),
                        if (itemsServicesTotal > 0) ...[
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الخدمات'), Text('${itemsServicesTotal.fmt} ${AppCurrency.symbol(orderCurrency)}')]),
                        ],
                        if (shipping > 0) ...[
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('التوصيل والشحن'), Text('${shipping.fmt} ${AppCurrency.symbol(orderCurrency)}')]),
                        ],
                        if (salesDiscount > 0) ...[
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('خصم المبيعات', style: TextStyle(color: AppColors.dangerWaste)), Text('-${salesDiscount.fmt} ${AppCurrency.symbol(orderCurrency)}', style: const TextStyle(color: AppColors.dangerWaste))]),
                        ],
                        const Divider(height: 18),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي قيمة الطلبية', style: TextStyle(fontWeight: FontWeight.bold)), Text('${grandTotal.fmt} ${AppCurrency.symbol(orderCurrency)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accentPrimary))]),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('العربون / الدفعة المقدمة'), Text('${deposit.fmt} ${AppCurrency.symbol(orderCurrency)}')]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المتبقي عند الاستلام', style: TextStyle(fontWeight: FontWeight.bold)), Text('${remaining.fmt} ${AppCurrency.symbol(orderCurrency)}', style: TextStyle(fontWeight: FontWeight.bold, color: remaining > 0 ? AppColors.dangerWaste : AppColors.successGreen))]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setSt(() => showAdditionalInformation = !showAdditionalInformation),
                      icon: Icon(showAdditionalInformation ? Icons.expand_less_rounded : Icons.tune_rounded),
                      label: Text(showAdditionalInformation ? 'إخفاء المعلومات الإضافية' : 'Additional Information / معلومات إضافية'),
                    ),
                  ),
                  if (showAdditionalInformation) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.panelBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('حقول إضافية', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(controller: salesDiscountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'خصم المبيعات', isDense: true), onChanged: (_) => setSt(() {})),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.3))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              const Text('العربون / الدفعة المقدمة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orderDepositBoxAccent)),
                              const SizedBox(height: 6),
                              TextField(controller: depositCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'قيمة العربون (${AppCurrency.symbol(orderCurrency)})', isDense: true), onChanged: (_) => setSt(() {})),
                              const SizedBox(height: 6),
                              Text('يُودع في صندوق الطلبيات المعزول. المتبقي: ${remaining.fmt} ${AppCurrency.symbol(orderCurrency)}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          const Text('خيار التوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(children: [
                            Expanded(child: RadioListTile<bool>(contentPadding: EdgeInsets.zero, dense: true, title: const Text('الزبون يستلم', style: TextStyle(fontSize: 12)), value: false, groupValue: deliverByUs, onChanged: (v) => setSt(() => deliverByUs = v))),
                            Expanded(child: RadioListTile<bool>(contentPadding: EdgeInsets.zero, dense: true, title: const Text('نوصّل نحن', style: TextStyle(fontSize: 12)), value: true, groupValue: deliverByUs, onChanged: (v) => setSt(() => deliverByUs = v))),
                          ]),
                          if (deliverByUs == true) TextField(controller: shippingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تكلفة التوصيل / الشحن', isDense: true), onChanged: (_) => setSt(() {})),
                          const SizedBox(height: 10),
                          AppImageAttachmentPicker(initialPath: photoCtrl.text, label: 'صورة الطلبية / المخطط الفني', onImageChanged: (p) => setSt(() => photoCtrl.text = p)),
                        ],
                      ),
                    ),
                  ],
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
                          () =>
                              formError = 'أضف صنفاً واحداً على الأقل للطلبية.',
                        );
                        return;
                      }
                      if (draftItems.any(
                        (item) =>
                            item.itemId.isEmpty || item.calculatedArea <= 0,
                      )) {
                        setSt(
                          () => formError =
                              'أكمل اختيار المادة والأبعاد والكمية لكل صف قبل حفظ الطلبية.',
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
                        id: existingOrder?.id ??
                            'fo_${DateTime.now().millisecondsSinceEpoch}',
                        orderNo: existingOrder?.orderNo ??
                            'FORD-${erp.factoryOrders.length + 101}',
                        date: existingOrder?.date ?? DateTime.now(),
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
                        status: existingOrder?.status ?? 'قيد التنفيذ',
                      );

                      final bool saved;
                      if (existingOrder == null) {
                        erp.createFactoryOrder(order);
                        saved = true;
                      } else {
                        saved = erp.updateFactoryOrder(existingOrder.id, order);
                      }
                      if (!saved) {
                        setSt(() => formError =
                            'تعذر حفظ التعديل. تحقق من توفر المخزون والعربون.');
                        return;
                      }
                      FormDraftStore.discard(draftKey);
                      Navigator.pop(ctx);

                      if (onOrderCreated != null) {
                        onOrderCreated(order);
                      }

                      // Show immediate confirmation & workshop print preview dialog
                      if (existingOrder == null) {
                        showFactoryOrderSuccessDialog(context, order);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ تعديلات الطلبية بنجاح.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      existingOrder == null
                          ? 'حفظ وتأكيد طلبية المصنع وإيداع العربون'
                          : 'حفظ تعديلات الطلبية',
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.successGreen,
            size: 28,
          ),
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
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
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
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.dangerWaste,
              size: 26,
            ),
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
