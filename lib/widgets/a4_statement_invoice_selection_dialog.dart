import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import 'a4_statement_print_dialog.dart';

/// Step shown before the statement preview: lets the user pick which
/// invoices/rows are included in the account statement.
/// Enforces accounting integrity: linked return invoices cannot be excluded
/// independently if their master parent invoice is included in the statement.
class A4StatementInvoiceSelectionDialog extends StatefulWidget {
  final A4StatementData data;
  const A4StatementInvoiceSelectionDialog({super.key, required this.data});

  @override
  State<A4StatementInvoiceSelectionDialog> createState() =>
      _A4StatementInvoiceSelectionDialogState();
}

class _A4StatementInvoiceSelectionDialogState
    extends State<A4StatementInvoiceSelectionDialog> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.data.items.map((e) => e.index).toSet();
    _bundleLinkedReturns();
  }

  /// Bundles any linked return invoices with their parent invoices.
  void _bundleLinkedReturns() {
    final items = widget.data.items;
    for (final it in items) {
      if (it.isReturn && it.parentInvoiceNo.isNotEmpty) {
        final isParentIn = items.any(
          (other) =>
              !other.isReturn &&
              other.documentNo == it.parentInvoiceNo &&
              _selected.contains(other.index),
        );
        if (isParentIn) {
          _selected.add(it.index);
        }
      }
    }
  }

  bool _isParentSelected(A4StatementLineItem it, List<A4StatementLineItem> allItems) {
    if (!it.isReturn || it.parentInvoiceNo.isEmpty) return false;
    return allItems.any(
      (other) =>
          !other.isReturn &&
          other.documentNo == it.parentInvoiceNo &&
          _selected.contains(other.index),
    );
  }

  List<A4StatementLineItem> _getLinkedReturns(
    A4StatementLineItem parent,
    List<A4StatementLineItem> allItems,
  ) {
    if (parent.isReturn) return const [];
    return allItems
        .where((it) => it.isReturn && it.parentInvoiceNo == parent.documentNo)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items;
    final allSelected = _selected.length == items.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 760,
          height: MediaQuery.of(context).size.height * 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.chipBgBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.accentPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اختيار الفواتير المضمّنة في كشف الحساب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'كشف حساب: ${widget.data.accountName}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.accentPrimary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'قاعدة النزاهة المحاسبية: فواتير المرتجعات مرتبطة إلزامياً بالفواتير الأصلية ولا يمكن استبعادها إذا كانت الفاتورة الأصلية محددة.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                dense: true,
                value: allSelected,
                title: Text(
                  'تحديد الكل (${_selected.length} من ${items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.addAll(items.map((e) => e.index));
                  } else {
                    _selected.clear();
                  }
                }),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    final isLockedReturn = _isParentSelected(it, items);
                    final linkedReturns = _getLinkedReturns(it, items);

                    return CheckboxListTile(
                      dense: true,
                      value: _selected.contains(it.index),
                      secondary: it.isReturn
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.chipBgRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.assignment_return_outlined,
                                color: AppColors.dangerWaste,
                                size: 18,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.chipBgBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.accentPrimary,
                                size: 18,
                              ),
                            ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(it.index);
                            // If this is a master invoice, auto-select its linked returns
                            for (final ret in linkedReturns) {
                              _selected.add(ret.index);
                            }
                          } else {
                            // If this is a return linked to an active parent, block deselection
                            if (isLockedReturn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.dangerWaste,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                    'لا يمكن استبعاد فاتورة المرتجع (${it.documentNo}) طالما أن الفاتورة الأصلية (${it.parentInvoiceNo}) محددة في الكشف لضمان النزاهة المحاسبية.',
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            _selected.remove(it.index);
                            // If this is a master invoice, also deselect linked returns
                            for (final ret in linkedReturns) {
                              _selected.remove(ret.index);
                            }
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it.documentNo} • ${it.category} • ${intl.DateFormat('yyyy-MM-dd').format(it.date)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: it.isReturn
                                    ? AppColors.dangerWaste
                                    : AppColors.brandPrimaryText,
                              ),
                            ),
                          ),
                          if (isLockedReturn) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 13,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'مرتبطة بالفاتورة #${it.parentInvoiceNo} (إلزامية)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (linkedReturns.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chipBgBlue,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.accentPrimary.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    size: 13,
                                    color: AppColors.accentPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'يوجد ${linkedReturns.length} مرتجع مرتبط',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'الإجمالي: ${it.totalAmount.fmt} ${it.currencySymbol} • المدفوع/المسوى: ${it.paidAmount.fmt} ${it.currencySymbol} • المتبقي: ${it.remainingAmount.fmt} ${it.currencySymbol} • ${it.details.length} بند',
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              _bundleLinkedReturns();
                              Navigator.of(context).pop(
                                items
                                    .where((e) => _selected.contains(e.index))
                                    .toList(),
                              );
                            },
                      icon: const Icon(Icons.print_rounded),
                      label: Text('معاينة الكشف (${_selected.length})'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
