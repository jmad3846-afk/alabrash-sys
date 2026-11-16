import 'package:flutter/material.dart';

/// Editable transaction date used by supplier and distributor/agent
/// Pay/Collect forms. The selected value is passed to the account ledger and
/// therefore controls the chronological statement row.
class TransactionDateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  const TransactionDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'تاريخ العملية',
  });

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: 'اختر تاريخ العملية',
          cancelText: 'إلغاء',
          confirmText: 'تأكيد',
        );
        if (picked != null) {
          onChanged(DateTime(
            picked.year,
            picked.month,
            picked.day,
            value.hour,
            value.minute,
            value.second,
          ));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18),
          suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 18),
        ),
        child: Text(
          _dateText(value),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
