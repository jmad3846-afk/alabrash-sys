import 'package:flutter/material.dart';
import '../core/models/models.dart';

/// Small dropdown to pick the invoice/order fund currency:
/// US Dollars ($) or Syrian Pounds (SYP ل.س).
class CurrencySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool dense;

  const CurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: AppCurrency.normalize(value),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'العملة (Currency)',
        isDense: dense,
        prefixIcon: const Icon(Icons.currency_exchange_rounded),
      ),
      items: const [
        DropdownMenuItem(
          value: AppCurrency.usd,
          child: Text('دولار (\$) — USD'),
        ),
        DropdownMenuItem(
          value: AppCurrency.syp,
          child: Text('ليرة سورية (ل.س) — SYP'),
        ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Inline currency badge shown next to money amounts.
class CurrencyBadge extends StatelessWidget {
  final String currency;

  const CurrencyBadge({super.key, required this.currency});

  @override
  Widget build(BuildContext context) {
    final syp = AppCurrency.isSyp(currency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: syp ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: syp ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
        ),
      ),
      child: Text(
        syp ? 'ل.س SYP' : '\$ USD',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: syp ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
        ),
      ),
    );
  }
}
