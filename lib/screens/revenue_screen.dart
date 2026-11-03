import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class RevenueScreen extends StatelessWidget {
  const RevenueScreen({super.key});

  Future<void> _add(BuildContext context, ERPProvider erp) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    var currency = AppCurrency.usd;
    var date = DateUtils.dateOnly(DateTime.now());
    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('إضافة إيراد'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'يضاف المبلغ إلى الصندوق الرئيسي وإلى ملخص الدخل.',
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'وصف الإيراد',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل الوصف' : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? 'أدخل مبلغاً أكبر من صفر'
                            : null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      items: const [
                        DropdownMenuItem(
                          value: AppCurrency.usd,
                          child: Text('USD'),
                        ),
                        DropdownMenuItem(
                          value: AppCurrency.syp,
                          child: Text('SYP'),
                        ),
                      ],
                      onChanged: (v) => update(() => currency = v!),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(DateFormat('yyyy-MM-dd').format(date)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && context.mounted)
                          update(() => date = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                erp.addRevenueRecord(
                  RevenueRecordModel(
                    id: 'revenue_${DateTime.now().microsecondsSinceEpoch}',
                    description: description.text.trim(),
                    amount: double.parse(amount.text.trim()),
                    currency: currency,
                    date: date,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    description.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final entries = [...erp.revenueRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'الإيرادات',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _add(context, erp),
                icon: const Icon(Icons.add),
                label: const Text('إضافة إيراد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'إجمالي الإيرادات: ${AppCurrency.dual(erp.revenuePageEarningsOf(AppCurrency.usd), erp.revenuePageEarningsOf(AppCurrency.syp))}',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('لا توجد إيرادات مسجلة'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(entry.description),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(entry.date),
                          ),
                          trailing: Text(
                            '${entry.amount.fmt} ${AppCurrency.symbol(entry.currency)}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
