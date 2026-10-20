import 'package:flutter/material.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import 'a4_invoice_print_dialog.dart';

/// Shows the Print Preview fulfillment document specifically formatted for workshop execution.
void showWorkshopOrderPreview(BuildContext context, WorkshopOrderModel order) {
  A4InvoicePrintDialog.show(
    context,
    invoiceData: A4InvoiceData.fromWorkshopOrder(order),
  );
}

/// Internal helper state holder for each raw material conversion during order cancellation.
class _RawConversionState {
  final WorkshopInvoiceItem item;
  bool isSimple; // true = simple tailoring, false = complex tailoring
  bool isCreateNew; // true = new on the fly, false = existing
  String? selectedExistingId;
  final TextEditingController nameCtrl;
  final TextEditingController sellingPriceCtrl;

  _RawConversionState({
    required this.item,
    this.isSimple = true,
    this.isCreateNew = true,
    String? defaultName,
    double defaultPrice = 0.0,
  })  : nameCtrl = TextEditingController(text: defaultName ?? ''),
        sellingPriceCtrl = TextEditingController(
          text: defaultPrice > 0 ? defaultPrice.fmt : '',
        );

  void dispose() {
    nameCtrl.dispose();
    sellingPriceCtrl.dispose();
  }
}

/// Cancellation confirmation and inventory/financial rollback dialog for Workshop Orders.
/// Prompts the user: "Is the order completed?" (هل الطلبية مكتملة؟)
/// - Option A (Not Completed): Refunds deposit and returns all items to original stock.
/// - Option B (Completed): Keeps deposit as profit, restores standard items, and converts
///   raw materials into tailored stock (Simple or Complex Tailoring, existing or created on the fly).
void showCancelWorkshopOrderDialog(
  BuildContext context,
  ERPProvider erp,
  WorkshopOrderModel order,
) {
  // Identify raw material items in the order
  final rawItems = order.items
      .where(
        (it) =>
            it.sourceType == 'بيع مواد خام من المعمل' ||
            it.sourceType == 'مواد خام',
      )
      .toList();

  final List<_RawConversionState> conversionStates = rawItems.map((it) {
    return _RawConversionState(
      item: it,
      isSimple: true,
      isCreateNew: true,
      defaultName: 'تفصيل من طلبية ${order.orderNo} (${it.description})',
      defaultPrice: it.agreedPrice > 0 ? it.agreedPrice : it.unitPrice,
    );
  }).toList();

  bool isCompleted = false;
  String? errorMessage;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogWidth = screenWidth.clamp(480.0, 720.0);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerWaste.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.dangerWaste,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إلغاء طلبية المعمل (${order.orderNo})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الزبون: ${order.clientName} • السعر: ${order.agreedPrice.fmt} ${order.currencySymbol}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.brandSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Financial Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              size: 18,
                              color: AppColors.orderDepositBoxAccent,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'العربون المحجوز:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${order.depositAmount.fmt} ${order.currencySymbol}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orderDepositBoxAccent,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${order.items.length} بنود مدرجة',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // The Main Question
                  const Text(
                    'هل تم إنجاز / قص وتجهيز الطلبية في ورشة المعمل؟',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option A: Not Completed (لا - غير مكتملة)
                  InkWell(
                    onTap: () => setSt(() {
                      isCompleted = false;
                      errorMessage = null;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isCompleted
                            ? AppColors.accentPrimary.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !isCompleted
                              ? AppColors.accentPrimary
                              : const Color(0xFFE2E8F0),
                          width: !isCompleted ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: isCompleted,
                            activeColor: AppColors.accentPrimary,
                            onChanged: (v) => setSt(() {
                              isCompleted = v!;
                              errorMessage = null;
                            }),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'لا، الطلبية غير مكتملة (لم يتم إنجازها في الورشة)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• رد العربون (${order.depositAmount.fmt} ${order.currencySymbol}) كاملاً للزبون من صندوق الطلبيات.\n'
                                  '• إرجاع جميع المواد الخام والتفصيلات والقطع المستهلكة تلقائياً إلى مخزونها الأصلي بالمعمل.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF475569),
                                    height: 1.4,
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

                  // Option B: Completed (نعم - مكتملة)
                  InkWell(
                    onTap: () => setSt(() {
                      isCompleted = true;
                      errorMessage = null;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.orderDepositBoxAccent.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.orderDepositBoxAccent
                              : const Color(0xFFE2E8F0),
                          width: isCompleted ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: isCompleted,
                            activeColor: AppColors.orderDepositBoxAccent,
                            onChanged: (v) => setSt(() {
                              isCompleted = v!;
                              errorMessage = null;
                            }),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'نعم، الطلبية مكتملة (تم إنجازها وتفصيلها)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• لا يتم رد العربون (${order.depositAmount.fmt} ${order.currencySymbol})، ويبقى في صندوق الطلبيات ويُسجل كربح.\n'
                                  '• بنود الخياطة والقطع الإضافية تعود مباشرة لمخزونها في المعمل.\n'
                                  '• بنود المواد الخام (${rawItems.length} صنف): تُحول إلى مخزون تفصيلات (بسيط أو معقد) لأنها فُصلت بالفعل.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF475569),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Interactive Raw Material Conversion Section (Shown when isCompleted = true and rawItems exist)
                  if (isCompleted && conversionStates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.transform_rounded,
                                color: Color(0xFFB45309),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'تخصيص المواد الخام المفصلة إلى مخزون التفصيلات:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'بما أن الطلبية منجزة، تم قص المواد الخام. يرجى اختيار نوع التفصيل (بسيط أو معقد) وتسمية الصنف ليُقيد في مخزون التفصيلات.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                          ),
                          const Divider(height: 16, color: Color(0xFFFCD34D)),

                          // List each raw item with conversion configuration
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: conversionStates.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final conv = conversionStates[idx];
                              final item = conv.item;

                              final existingList = conv.isSimple
                                  ? erp.simpleTailorings
                                  : erp.complexTailorings;

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item description and quantity
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 10,
                                          backgroundColor: const Color(0xFFFEF3C7),
                                          child: Text(
                                            '${idx + 1}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item.description} • الكمية: ${item.quantity.fmt} ${item.unitCategory}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Tailoring Category: Simple vs Complex
                                    Row(
                                      children: [
                                        const Text(
                                          'نوع التفصيل:',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('تفصيل بسيط (Simple)'),
                                          selected: conv.isSimple,
                                          visualDensity: VisualDensity.compact,
                                          onSelected: (v) => setSt(() {
                                            conv.isSimple = true;
                                            conv.selectedExistingId = null;
                                          }),
                                        ),
                                        const SizedBox(width: 6),
                                        ChoiceChip(
                                          label: const Text('تفصيل معقد (Complex)'),
                                          selected: !conv.isSimple,
                                          visualDensity: VisualDensity.compact,
                                          onSelected: (v) => setSt(() {
                                            conv.isSimple = false;
                                            conv.selectedExistingId = null;
                                          }),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Mode: New on the fly vs Existing record
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => setSt(() => conv.isCreateNew = true),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Radio<bool>(
                                                value: true,
                                                groupValue: conv.isCreateNew,
                                                visualDensity: VisualDensity.compact,
                                                onChanged: (v) => setSt(() => conv.isCreateNew = v!),
                                              ),
                                              const Text(
                                                'تعريف صنف تفصيل جديد فوري',
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () => setSt(() => conv.isCreateNew = false),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Radio<bool>(
                                                value: false,
                                                groupValue: conv.isCreateNew,
                                                visualDensity: VisualDensity.compact,
                                                onChanged: (v) => setSt(() => conv.isCreateNew = v!),
                                              ),
                                              const Text(
                                                'إضافة لصنف تفصيل موجود مسبقاً',
                                                style: TextStyle(fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    if (conv.isCreateNew) ...[
                                      // Dynamic name creation on the fly
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              controller: conv.nameCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'اسم صنف التفصيل الجديد (إلزامي)',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: conv.sellingPriceCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                labelText: 'سعر البيع المقترح (${order.currencySymbol})',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // Existing dropdown selection
                                      if (existingList.isEmpty)
                                        Text(
                                          'لا توجد أصناف مسجلة حالياً في قسم ${conv.isSimple ? "الخياطة البسيطة" : "الخياطة المعقدة"}. يرجى اختيار تعريف صنف جديد.',
                                          style: const TextStyle(fontSize: 11, color: AppColors.dangerWaste),
                                        )
                                      else
                                        DropdownButtonFormField<String>(
                                          value: existingList.any((t) => t.id == conv.selectedExistingId)
                                              ? conv.selectedExistingId
                                              : null,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'اختر صنف التفصيل لإضافة الكمية إليه (${item.quantity.fmt} ${item.unitCategory})',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          items: existingList.map((t) {
                                            return DropdownMenuItem(
                                              value: t.id,
                                              child: Text('${t.name} (المتاح حالياً: ${t.quantity.fmt} ${t.unitSymbol})'),
                                            );
                                          }).toList(),
                                          onChanged: (v) => setSt(() => conv.selectedExistingId = v),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerWaste.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.dangerWaste),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.dangerWaste,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final c in conversionStates) {
                  c.dispose();
                }
                Navigator.pop(ctx);
              },
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerWaste,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                // Validation if isCompleted
                if (isCompleted) {
                  for (int i = 0; i < conversionStates.length; i++) {
                    final c = conversionStates[i];
                    if (c.isCreateNew && c.nameCtrl.text.trim().isEmpty) {
                      setSt(() => errorMessage = 'يرجى إدخال اسم صنف التفصيل للبند رقم ${i + 1}.');
                      return;
                    }
                    if (!c.isCreateNew && c.selectedExistingId == null) {
                      setSt(() => errorMessage = 'يرجى اختيار صنف التفصيل المطلوب للبند رقم ${i + 1}.');
                      return;
                    }
                  }
                }

                // Prepare assignments
                final List<RawMaterialTailoringAssignment> assignments = [];
                if (isCompleted) {
                  for (final c in conversionStates) {
                    assignments.add(
                      RawMaterialTailoringAssignment(
                        itemId: c.item.id,
                        rawMaterialName: c.item.description,
                        quantity: c.item.quantity,
                        unitCategory: c.item.unitCategory,
                        isSimpleTailoring: c.isSimple,
                        existingTailoringId: !c.isCreateNew ? c.selectedExistingId : null,
                        newTailoringName: c.isCreateNew ? c.nameCtrl.text.trim() : null,
                        sellingPrice: double.tryParse(c.sellingPriceCtrl.text) ?? 0.0,
                      ),
                    );
                  }
                }

                erp.cancelWorkshopOrderWorkflow(
                  order: order,
                  isCompleted: isCompleted,
                  rawMaterialAssignments: assignments,
                );

                for (final c in conversionStates) {
                  c.dispose();
                }

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isCompleted
                          ? 'تم إلغاء الطلبية كمكتملة: تم الاحتفاظ بالعربون كربح وتحويل المواد المفصلة إلى مخزون التفصيلات بنجاح.'
                          : 'تم إلغاء الطلبية واسترجاع العربون (${order.depositAmount.fmt} ${order.currencySymbol}) للزبون وإرجاع كافة المواد لمخزونها الأصلي.',
                    ),
                    backgroundColor: isCompleted ? AppColors.orderDepositBoxAccent : AppColors.successGreen,
                  ),
                );
              },
              child: const Text('تأكيد إلغاء الطلبية'),
            ),
          ],
        );
      },
    ),
  );
}
