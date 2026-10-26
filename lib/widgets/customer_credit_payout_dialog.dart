import 'package:flutter/material.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Cash payout voucher dialog when a customer / dealer's account balance has flipped
/// to Creditor (دائن - له رصيد دائن / أمانة بذمة الشركة ناتجة عن مرتجع مبيعات ودفعات سابقة).
class CustomerCreditPayoutDialog extends StatefulWidget {
  final ClientModel client;
  final ERPProvider erp;

  const CustomerCreditPayoutDialog({
    super.key,
    required this.client,
    required this.erp,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ClientModel client,
    required ERPProvider erp,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerCreditPayoutDialog(
        client: client,
        erp: erp,
      ),
    );
  }

  @override
  State<CustomerCreditPayoutDialog> createState() =>
      _CustomerCreditPayoutDialogState();
}

class _CustomerCreditPayoutDialogState
    extends State<CustomerCreditPayoutDialog> {
  late String _selectedCurrency;
  late final TextEditingController _amountCtrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final hasUsdCredit = widget.client.debtBalance < -0.01;
    final hasSypCredit = widget.client.debtBalanceSyp < -0.01;
    _selectedCurrency = hasUsdCredit
        ? AppCurrency.usd
        : (hasSypCredit ? AppCurrency.syp : AppCurrency.usd);

    final initialCredit = widget.client.creditOf(_selectedCurrency);
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
      final credit = widget.client.creditOf(_selectedCurrency);
      _amountCtrl.text = credit > 0 ? credit.fmt : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final erp = widget.erp;
    final isAgent = client.clientType == 'معتمد مصنع';
    final roleLabel = isAgent ? 'المعتمد' : 'العميل';
    final hasUsdCredit = client.debtBalance < -0.01;
    final hasSypCredit = client.debtBalanceSyp < -0.01;
    final currentCredit = client.creditOf(_selectedCurrency);
    final sym = AppCurrency.symbol(_selectedCurrency);
    final boxCash = erp.cashOf('main', _selectedCurrency);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.dangerWaste.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.outbox_rounded,
              color: AppColors.dangerWaste,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دفع وصرف نقدي لـ$roleLabel: ${client.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'الرصيد الدائن المستحق له (أمانة بذمتنا): ${client.dualCredit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.dangerWaste,
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
                  'اختر عملة الصرف:',
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
                          'دولار (${client.creditOf(AppCurrency.usd).fmt}\$)',
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
                          'ليرة (${client.creditOf(AppCurrency.syp).fmt} ل.س)',
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
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الرصيد المستحق لـ$roleLabel في هذه العملة:',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${currentCredit.fmt} $sym',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.dangerWaste,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'خزينة الصرف:',
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
                          'رصيد الصندوق المتوفر:',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${boxCash.fmt} $sym',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: boxCash >= currentCredit
                                ? AppColors.successGreen
                                : AppColors.dangerWaste,
                          ),
                        ),
                      ],
                    ),
                    if (boxCash < currentCredit) ...[
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'حالة السحب:',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.brandSecondaryText,
                            ),
                          ),
                          Text(
                            'مسموح بالسالب (سحب على المكشوف)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.dangerWaste,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'مبلغ الصرف / الدفع ($sym)',
                  prefixIcon: const Icon(Icons.outbox_rounded),
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
            backgroundColor: AppColors.dangerWaste,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text(
            'تأكيد الصرف والدفع',
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
                  'لا يمكن صرف مبلغ أكبر من الرصيد الدائن المستحق (${currentCredit.fmt} $sym)!');
              return;
            }

            final ok = erp.payCustomerCredit(
              client: client,
              amount: amount,
              currency: _selectedCurrency,
            );

            if (ok) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.successGreen,
                  content: Text(
                    'تم صرف وتسديد ${amount.fmt} $sym لـ$roleLabel ${client.name} من الصندوق الرئيسي بنجاح.',
                  ),
                ),
              );
            } else {
              setState(() => _errorMessage = 'تعذر تنفيذ عملية الصرف. تحقق من المدخلات.');
            }
          },
        ),
      ],
    );
  }
}
