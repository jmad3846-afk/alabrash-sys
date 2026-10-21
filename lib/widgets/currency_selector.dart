import 'package:flutter/material.dart';
import '../core/models/models.dart';

/// Normalizes Arabic strings by removing diacritics and unifying Alef, Taa Marbuta, and Yaa.
String normalizeArabic(String text) {
  return text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // tashkeel
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}

/// Fuzzy match on Arabic text handling variations in spelling.
bool arabicFuzzyMatch(String source, String query) {
  if (query.trim().isEmpty) return true;
  return normalizeArabic(source).contains(normalizeArabic(query));
}

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

/// Modern segmented toggle pills for currency filtering:
/// 'ALL' (الكل), AppCurrency.usd (دولار $), AppCurrency.syp (ليرة سورية ل.س).
class CurrencyFilterPills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool compact;

  const CurrencyFilterPills({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            value: 'ALL',
            label: 'الكل',
            icon: Icons.all_inclusive_rounded,
            activeColor: const Color(0xFF0F172A),
          ),
          const SizedBox(width: 4),
          _buildItem(
            value: AppCurrency.usd,
            label: 'دولار (\$)',
            icon: Icons.attach_money_rounded,
            activeColor: const Color(0xFF047857),
          ),
          const SizedBox(width: 4),
          _buildItem(
            value: AppCurrency.syp,
            label: 'ل.س (SYP)',
            icon: Icons.receipt_long_rounded,
            activeColor: const Color(0xFF1D4ED8),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String value,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 13 : 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified, responsive search bar with integrated currency filter pills.
class SectionSearchAndFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedCurrency; // 'ALL', 'USD', 'SYP'
  final ValueChanged<String> onCurrencyChanged;
  final String hintText;
  final VoidCallback? onClear;
  final Widget? extraActions;

  const SectionSearchAndFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.hintText = 'بحث بالاسم، رقم الهاتف، أو رقم الفاتورة...',
    this.onClear,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final searchField = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                      onClear?.call();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        );

        final filterPills = CurrencyFilterPills(
          selected: selectedCurrency,
          onChanged: onCurrencyChanged,
          compact: isNarrow,
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: filterPills),
                  if (extraActions != null) ...[
                    const SizedBox(width: 8),
                    extraActions!,
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            filterPills,
            if (extraActions != null) ...[
              const SizedBox(width: 12),
              extraActions!,
            ],
          ],
        );
      },
    );
  }
}

