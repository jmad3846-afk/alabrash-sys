import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import 'currency_selector.dart';

class WorkdayModal extends StatefulWidget {
  const WorkdayModal({super.key});

  @override
  State<WorkdayModal> createState() => _WorkdayModalState();
}

class _WorkdayModalState extends State<WorkdayModal> {
  DateTime selectedDate = DateTime.now();
  final List<String> selectedStaffNames = [];
  final TextEditingController descriptionController = TextEditingController(text: 'قص بلوكات وإنجاز درجات السلالم');
  String rateType = 'حساب يومية';
  final TextEditingController amountController = TextEditingController(text: '45');
  String workCurrency = AppCurrency.usd;

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Dialog(
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.chipBgBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.date_range_rounded, color: AppColors.accentPrimary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'تسجيل وإنجاز يوم عمل (أيام عمل)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 24),
            // Date Picker Row
            Row(
              children: [
                const Text('التاريخ المصرح:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.panelBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.brandSecondaryText),
                      const SizedBox(width: 8),
                      Text(
                        intl.DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('اختر العمالة المشاركة اليوم:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.panelBorder),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFFAF9F6),
              ),
              child: ListView.builder(
                itemCount: erp.staffList.length,
                itemBuilder: (context, idx) {
                  final staff = erp.staffList[idx];
                  final isSelected = selectedStaffNames.contains(staff.name);
                  return CheckboxListTile(
                    dense: true,
                    title: Text('${staff.name} (${staff.category})', style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedStaffNames.add(staff.name);
                        } else {
                          selectedStaffNames.remove(staff.name);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'وصف إنجاز وتفاصيل العمل اليومي',
              ),
            ),
            const SizedBox(height: 16),
            CurrencySelector(
              value: workCurrency,
              dense: true,
              onChanged: (v) => setState(() => workCurrency = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('طريقة أجر العمل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'حساب يومية', label: Text('حساب يومية')),
                          ButtonSegment(value: 'حساب مقطوع', label: Text('حساب مقطوع')),
                        ],
                        selected: {rateType},
                        onSelectionChanged: (val) {
                          setState(() {
                            rateType = val.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المتفق عليه للعدسة (\$)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                    onPressed: () {
                      if (selectedStaffNames.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى تحديد عامل واحد على الأقل!'), backgroundColor: AppColors.dangerWaste),
                        );
                        return;
                      }
                      double amount = double.tryParse(amountController.text) ?? 0.0;
                      erp.recordWorkdayExecution(WorkdayEntryModel(
                        id: 'wde_${DateTime.now().millisecondsSinceEpoch}',
                        date: selectedDate,
                        staffNames: selectedStaffNames,
                        workDescription: descriptionController.text,
                        rateType: rateType,
                        agreedAmountPerPerson: amount,
                        currency: workCurrency,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل مستحقات يوم العمل وترحيلها لحسابات العمال بنجاح!'), backgroundColor: AppColors.successGreen),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('اعتماد وتسجيل يوم العمل'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


