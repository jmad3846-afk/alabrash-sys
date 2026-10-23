import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../core/models/models.dart';
import 'a4_statement_print_dialog.dart';

/// Step shown before the statement preview: lets the user pick which
/// invoices/rows are included in the account statement.
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
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items;
    final allSelected = _selected.length == items.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: SizedBox(
          width: 720,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختيار الفواتير المضمّنة في كشف الحساب',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.data.accountName,
                      style: const TextStyle(color: Color(0xFF64748B)),
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
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return CheckboxListTile(
                      dense: true,
                      value: _selected.contains(it.index),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(it.index);
                        } else {
                          _selected.remove(it.index);
                        }
                      }),
                      title: Text(
                        '${it.documentNo} • ${it.category} • ${intl.DateFormat('yyyy-MM-dd').format(it.date)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'الإجمالي: ${it.totalAmount.fmt} ${it.currencySymbol} • المتبقي: ${it.remainingAmount.fmt} ${it.currencySymbol} • ${it.details.length} بند',
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
                          : () => Navigator.of(context).pop(
                                items
                                    .where((e) => _selected.contains(e.index))
                                    .toList(),
                              ),
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
