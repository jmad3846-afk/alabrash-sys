import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

/// Clean visual badge indicating the customer account's inherited currency classification:
/// "USD Customer" or "SYP Customer".
class CustomerClassificationBadge extends StatelessWidget {
  final ClientModel client;
  final bool compact;

  const CustomerClassificationBadge({
    super.key,
    required this.client,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSyp = client.isSypCustomer;
    final color = isSyp ? const Color(0xFF1D4ED8) : const Color(0xFF047857);
    final bgColor = isSyp ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final borderColor = isSyp ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);
    final icon = isSyp ? Icons.account_balance_wallet_outlined : Icons.monetization_on_outlined;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            client.currencyClassificationLabel,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              isSyp ? '(زبون ليرة)' : '(زبون دولار)',
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Multi-currency customer collection modal supporting direct payment (same currency)
/// and cross-currency payment with real-time conversion rates.
class CustomerCollectionDialog extends StatefulWidget {
  final ClientModel client;
  final ERPProvider erp;

  const CustomerCollectionDialog({
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
      builder: (_) => CustomerCollectionDialog(client: client, erp: erp),
    );
  }

  @override
  State<CustomerCollectionDialog> createState() => _CustomerCollectionDialogState();
}

class _CustomerCollectionDialogState extends State<CustomerCollectionDialog> {
  late String _selectedPaymentCurrency;
  late final TextEditingController _paymentAmountCtrl;
  late final TextEditingController _exchangeRateCtrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default payment currency matches the customer's account currency classification
    _selectedPaymentCurrency = widget.client.currencyClassification;

    final initialDue = widget.client.debtOf(_selectedPaymentCurrency);
    _paymentAmountCtrl = TextEditingController(
      text: initialDue > 0 ? initialDue.fmt : '',
    );
    _exchangeRateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _paymentAmountCtrl.dispose();
    _exchangeRateCtrl.dispose();
    super.dispose();
  }

  void _onPaymentCurrencyChanged(String? newCurrency) {
    if (newCurrency == null || newCurrency == _selectedPaymentCurrency) return;
    setState(() {
      _selectedPaymentCurrency = newCurrency;
      _errorMessage = null;

      final isSame = _selectedPaymentCurrency == widget.client.currencyClassification;
      if (isSame) {
        final due = widget.client.debtOf(_selectedPaymentCurrency);
        _paymentAmountCtrl.text = due > 0 ? due.fmt : '';
      } else {
        _paymentAmountCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final erp = widget.erp;
    final accountCurrency = client.currencyClassification;
    final isSameCurrency = _selectedPaymentCurrency == accountCurrency;

    final double enteredAmount = double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0;
    final double exchangeRate = double.tryParse(_exchangeRateCtrl.text.trim()) ?? 0.0;

    // Calculation variables
    double convertedAmount = 0.0;
    if (!isSameCurrency && exchangeRate > 0 && enteredAmount > 0) {
      if (accountCurrency == AppCurrency.usd && _selectedPaymentCurrency == AppCurrency.syp) {
        // Scenario 1: USD Customer Paying in SYP
        // Converted USD Amount = amount_syp / exchange_rate
        convertedAmount = enteredAmount / exchangeRate;
      } else if (accountCurrency == AppCurrency.syp && _selectedPaymentCurrency == AppCurrency.usd) {
        // Scenario 2: SYP Customer Paying in USD
        // Converted SYP Amount = amount_usd * exchange_rate
        convertedAmount = enteredAmount * exchangeRate;
      }
    } else if (isSameCurrency) {
      convertedAmount = enteredAmount;
    }

    final double dueInAccountCurrency = client.debtOf(accountCurrency);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(bottom: BorderSide(color: AppColors.panelBorder)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.successGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'تحصيل دفعة: ${client.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomerClassificationBadge(client: client, compact: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'القسم: ${client.clientType} • الرصيد المدين الحالي: ${dueInAccountCurrency.fmt} ${AppCurrency.symbol(accountCurrency)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brandSecondaryText,
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
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Account Currency Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: client.isSypCustomer
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: client.isSypCustomer
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          client.isSypCustomer
                              ? Icons.account_balance_wallet_outlined
                              : Icons.monetization_on_outlined,
                          size: 20,
                          color: client.isSypCustomer
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF047857),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تصنيف حساب العميل في المالية:',
                              style: TextStyle(
                                fontSize: 11,
                                color: client.isSypCustomer
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF047857),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${client.currencyClassificationLabel} (${client.currencyClassificationLabelAr})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: client.isSypCustomer
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFF064E3B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'الذمة المستحقة:',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.brandSecondaryText,
                          ),
                        ),
                        Text(
                          '${dueInAccountCurrency.fmt} ${AppCurrency.symbol(accountCurrency)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: dueInAccountCurrency > 0
                                ? AppColors.dangerWaste
                                : AppColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Payment Currency Selection Options
              const Text(
                'عملة الدفع الفعلية (Payment Currency):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _onPaymentCurrencyChanged(AppCurrency.usd),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentCurrency == AppCurrency.usd
                              ? const Color(0xFFECFDF5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPaymentCurrency == AppCurrency.usd
                                ? const Color(0xFF059669)
                                : AppColors.panelBorder,
                            width: _selectedPaymentCurrency == AppCurrency.usd ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: AppCurrency.usd,
                              groupValue: _selectedPaymentCurrency,
                              activeColor: const Color(0xFF059669),
                              onChanged: _onPaymentCurrencyChanged,
                            ),
                            Expanded(
                              child: Text(
                                'دولار أمريكي (USD \$)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onPaymentCurrencyChanged(AppCurrency.syp),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentCurrency == AppCurrency.syp
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPaymentCurrency == AppCurrency.syp
                                ? const Color(0xFF2563EB)
                                : AppColors.panelBorder,
                            width: _selectedPaymentCurrency == AppCurrency.syp ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: AppCurrency.syp,
                              groupValue: _selectedPaymentCurrency,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: _onPaymentCurrencyChanged,
                            ),
                            Expanded(
                              child: Text(
                                'ليرة سورية (SYP ل.س)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Dynamic Conditional Inputs
              if (isSameCurrency) ...[
                // Case A: Direct Payment (Same Currency)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        'دفع مباشر بنفس عملة الحساب (${AppCurrency.label(accountCurrency)})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _paymentAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الدفعة المسدد (${AppCurrency.symbol(_selectedPaymentCurrency)})',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    helperText: 'الحد الأقصى للمستحق: ${dueInAccountCurrency.fmt} ${AppCurrency.symbol(accountCurrency)}',
                    suffixIcon: dueInAccountCurrency > 0
                        ? TextButton(
                            onPressed: () {
                              setState(() {
                                _paymentAmountCtrl.text = dueInAccountCurrency.fmt;
                                _errorMessage = null;
                              });
                            },
                            child: const Text('كامل المستحق', style: TextStyle(fontSize: 12)),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
              ] else ...[
                // Case B: Cross-Currency Payment (Different Currency)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange_rounded, size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          accountCurrency == AppCurrency.usd
                              ? 'حالة خاصة: زبون دولار يسدد بالليرة السورية (USD Customer Paying in SYP)'
                              : 'حالة خاصة: زبون ليرة يسدد بالدولار الأمريكي (SYP Customer Paying in USD)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Field 1: payment_amount
                TextField(
                  controller: _paymentAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedPaymentCurrency == AppCurrency.syp
                        ? 'المبلغ الفعلي المدفوع بالليرة السورية (amount_syp)'
                        : 'المبلغ الفعلي المدفوع بالدولار الأمريكي (amount_usd)',
                    prefixIcon: const Icon(Icons.price_check_rounded),
                    helperText: 'المبلغ المستلم فعلياً من العميل لتوريده بالصندوق',
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 12),

                // Field 2: daily_exchange_rate
                TextField(
                  controller: _exchangeRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر الصرف المعتمد اليوم (daily_exchange_rate)',
                    prefixIcon: Icon(Icons.currency_exchange_rounded),
                    helperText: 'سعر صرف 1 دولار = ... ليرة سورية (مثال: 15000)',
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
              ],

              const SizedBox(height: 16),

              // 4. Live Real-Time Conversion & Double-Entry Accounting Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_balance_outlined, size: 16, color: AppColors.accentPrimary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'الأثر المحاسبي وفق القيد المزدوج (Double-Entry Impact):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    if (!isSameCurrency) ...[
                      // Conversion Formula Details
                      if (exchangeRate > 0 && enteredAmount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accountCurrency == AppCurrency.usd
                                    ? 'معادلة التحويل: Converted USD = amount_syp / exchange_rate'
                                    : 'معادلة التحويل: Converted SYP = amount_usd * exchange_rate',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                accountCurrency == AppCurrency.usd
                                    ? '${enteredAmount.fmt} ل.س ÷ ${exchangeRate.fmt} = ${convertedAmount.fmt} \$'
                                    : '${enteredAmount.fmt} \$ × ${exchangeRate.fmt} = ${convertedAmount.fmt} ل.س',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Leg 1: Customer Account (Credit / Deduct)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle_outline, color: AppColors.dangerWaste, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'حساب الزبون (${client.currencyClassificationLabel}):',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'خصم / دائن ${convertedAmount.fmt} ${AppCurrency.symbol(accountCurrency)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dangerWaste),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Leg 2: Main Safe Vault (Debit / Deposit)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, color: AppColors.successGreen, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'الصندوق الرئيسي (خزينة ${AppCurrency.label(_selectedPaymentCurrency)}):',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'إيداع / مدين ${enteredAmount.fmt} ${AppCurrency.symbol(_selectedPaymentCurrency)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.successGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.dangerWaste, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
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
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('تأكيد التحصيل (Confirm)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            if (enteredAmount <= 0) {
              setState(() => _errorMessage = 'يرجى إدخال مبلغ تحصيل صحيح أكبر من الصفر.');
              return;
            }
            if (isSameCurrency) {
              if (enteredAmount > dueInAccountCurrency + 0.001) {
                setState(() => _errorMessage =
                    'لا يمكن تحصيل مبلغ أكبر من المستحق المطلوب (${dueInAccountCurrency.fmt} ${AppCurrency.symbol(accountCurrency)})!');
                return;
              }
            } else {
              if (convertedAmount > dueInAccountCurrency + 0.001) {
                setState(() => _errorMessage =
                    'المبلغ المعادل (${convertedAmount.fmt} ${AppCurrency.symbol(accountCurrency)}) أكبر من المستحق المطلوب (${dueInAccountCurrency.fmt} ${AppCurrency.symbol(accountCurrency)})! لا يمكن تحصيل أكثر من المستحق.');
                return;
              }
            }

            final success = erp.collectCustomerPayment(
              client: client,
              paymentCurrency: _selectedPaymentCurrency,
              paymentAmount: enteredAmount,
              exchangeRate: !isSameCurrency ? exchangeRate : null,
            );

            if (!success) {
              setState(() => _errorMessage = 'تعذر تنفيذ عملية التحصيل. تحقق من صحة المدخلات.');
              return;
            }

            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.successGreen,
                content: Text(
                  isSameCurrency
                      ? 'تم تحصيل ${enteredAmount.fmt} ${AppCurrency.symbol(_selectedPaymentCurrency)} من حساب ${client.name} وإيداعها في خزينة ${AppCurrency.label(_selectedPaymentCurrency)} بالصندوق الرئيسي بنجاح.'
                      : 'تم تحصيل ${enteredAmount.fmt} ${AppCurrency.symbol(_selectedPaymentCurrency)} بسعر صرف ${exchangeRate.fmt}، وتم خصم المعادل (${convertedAmount.fmt} ${AppCurrency.symbol(accountCurrency)}) من حساب ${client.name} وإيداع المبلغ بالكامل في خزينة ${AppCurrency.label(_selectedPaymentCurrency)} بالصندوق الرئيسي بنجاح.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
