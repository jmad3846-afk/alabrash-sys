import 'package:flutter/material.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Cash collection voucher dialog when a supplier's account balance has flipped
/// to Debtor (مدين - لنا عنده رصيد دائن / فائض ناتج عن مرتجع مشتريات ودفعات سابقة).
class SupplierCreditCollectionDialog extends StatefulWidget {
  final SupplierModel supplier;
  final ERPProvider erp;

  const SupplierCreditCollectionDialog({
    super.key,
    required this.supplier,
    required this.erp,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SupplierModel supplier,
    required ERPProvider erp,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SupplierCreditCollectionDialog(
        supplier: supplier,
        erp: erp,
      ),
    );
  }

  @override
  State<SupplierCreditCollectionDialog> createState() =>
      _SupplierCreditCollectionDialogState();
}

class _SupplierCreditCollectionDialogState
    extends State<SupplierCreditCollectionDialog> {
  late String _selectedCurrency;
  late final TextEditingController _amountCtrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final hasUsdCredit = widget.supplier.debtBalance < -0.01;
    final hasSypCredit = widget.supplier.debtBalanceSyp < -0.01;
    _selectedCurrency = hasUsdCredit
        ? AppCurrency.usd
        : (hasSypCredit ? AppCurrency.syp : AppCurrency.usd);

    final initialCredit = widget.supplier.creditOf(_selectedCurrency);
    _amountCtrl = TextEditingController(
      text: initialCredit > 0 ? initialCredit.fmt : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onCurrencyChanged(String? newCurrency) {
    if (newCurrency == null || newCurrency == _selectedCurrency) return;
    setState(() {
      _selectedCurrency = newCurrency;
      _errorMessage = null;
      final credit = widget.supplier.creditOf(_selectedCurrency);
      _amountCtrl.text = credit > 0 ? credit.fmt : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplier = widget.supplier;
    final erp = widget.erp;
    final hasUsdCredit = supplier.debtBalance < -0.01;
    final hasSypCredit = supplier.debtBalanceSyp < -0.01;
    final currentCredit = supplier.creditOf(_selectedCurrency);
    final sym = AppCurrency.symbol(_selectedCurrency);
    final boxCash = erp.cashOf('main', _selectedCurrency);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.move_to_inbox_rounded,
              color: AppColors.successGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحصيل واسترداد نقدي من المورد: ${supplier.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'الرصيد الدائن المستحق لنا (فائض): ${supplier.dualCredit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasUsdCredit && hasSypCredit) ...[
                const Text(
                  'اختر عملة التحصيل:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: AppCurrency.usd,
                        groupValue: _selectedCurrency,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'دولار (${supplier.creditOf(AppCurrency.usd).fmt}\$)',
                        ),
                        onChanged: _onCurrencyChanged,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: AppCurrency.syp,
                        groupValue: _selectedCurrency,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'ليرة (${supplier.creditOf(AppCurrency.syp).fmt} ل.س)',
                        ),
                        onChanged: _onCurrencyChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الرصيد الدائن المسترد لنا في هذه العملة:',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${currentCredit.fmt} $sym',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'جهة التوريد والإيداع:',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'الصندوق الرئيسي ($sym)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'رصيد الصندوق قبل التوريد:',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${boxCash.fmt} $sym',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'مبلغ التحصيل / الاسترداد ($sym)',
                  prefixIcon: const Icon(Icons.download_rounded),
                  helperText: 'الحد الأقصى المسموح: ${currentCredit.fmt} $sym',
                  suffixIcon: currentCredit > 0
                      ? TextButton(
                          onPressed: () {
                            setState(() {
                              _amountCtrl.text = currentCredit.fmt;
                              _errorMessage = null;
                            });
                          },
                          child: const Text('كامل المستحق', style: TextStyle(fontSize: 12)),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text(
            'تأكيد التحصيل والتوريد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
            if (amount <= 0) {
              setState(() => _errorMessage = 'يرجى إدخال مبلغ صحيح أكبر من الصفر.');
              return;
            }
            if (amount > currentCredit + 0.001) {
              setState(() => _errorMessage =
                  'لا يمكن تحصيل مبلغ أكبر من الرصيد الدائن المستحق لنا (${currentCredit.fmt} $sym)!');
              return;
            }

            final ok = erp.collectFromSupplierCredit(
              supplier: supplier,
              amount: amount,
              currency: _selectedCurrency,
            );

            if (ok) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.successGreen,
                  content: Text(
                    'تم تحصيل واسترداد ${amount.fmt} $sym من المورد ${supplier.name} وتوريدها للصندوق الرئيسي بنجاح.',
                  ),
                ),
              );
            } else {
              setState(() => _errorMessage = 'تعذر تنفيذ عملية التحصيل. تحقق من المدخلات.');
            }
          },
        ),
      ],
    );
  }
}
