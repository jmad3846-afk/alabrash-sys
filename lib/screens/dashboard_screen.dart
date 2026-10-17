import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/metric_card.dart';
import '../widgets/client_debt_modal.dart';
import '../widgets/supplier_worker_debt_modal.dart';
import '../widgets/partner_management_modal.dart';
import '../widgets/workday_modal.dart';
import '../widgets/system_reset_modal.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int index)? onNavigateToIndex;

  const DashboardScreen({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Title & Quick Actions Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الشاشة الرئيسية (لوحة القيادة والمؤشرات)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'متابعة التحليلات المباشرة للمصنع والمعمل والسيولة وصناديق الأرباح',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _showCurrencyConversionDialog(context, erp),
                        icon: const Icon(Icons.currency_exchange_rounded),
                        label: const Text('تصريف وتحويل العملات (USD ⇄ SYP)'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const WorkdayModal(),
                          );
                        },
                        icon: const Icon(Icons.date_range),
                        label: const Text('أيام عمل'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.partnersEquityAccent),
                        onPressed: () {
                          showDialog(context: context, builder: (_) => const PartnerManagementModal());
                        },
                        icon: const Icon(Icons.group),
                        label: const Text('الشركاء وحقوق الملكية'),
                      ),
                      // HIGH PRIORITY DANGER ACTION: System Factory Reset & Data Wipe
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerWaste,
                          side: const BorderSide(color: AppColors.dangerWaste, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const SystemResetModal(),
                          );
                          if (confirmed == true) {
                            onNavigateToIndex?.call(8); // Opening Entry screen
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم تصفير البرنامج بنجاح. يمكنك الآن البدء بإدخال بياناتك الحقيقية عبر واجهة القيد الافتتاحي.',
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text('تصفير البرنامج ومسح البيانات'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SECTION 1: FACTORY & WORKSHOP ANALYTICS CARDS
            const Text(
              '1. تحليلات وذمم المصنع والمعمل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandPrimaryText),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                // Card 1: المصنع - لنا من معتمدين
                MetricCard(
                  title: 'تحليلات المصنع • لنا من معتمدين',
                  value: AppCurrency.dual(
                      erp.clientsApprovedDebtsOf(AppCurrency.usd),
                      erp.clientsApprovedDebtsOf(AppCurrency.syp)),
                  subtitle: 'انقر لفتح القائمة التفصيلية للمعتمدين',
                  icon: Icons.factory_rounded,
                  iconColor: AppColors.accentPrimary,
                  bgColor: AppColors.chipBgBlue,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ClientDebtModal(titleFilter: 'معتمد مصنع'),
                    );
                  },
                ),

                // Card 2: علينا عمال وموردين
                MetricCard(
                  title: 'المستحقات • علينا عمال وموردين',
                  value: AppCurrency.dual(
                      erp.suppliersTotalDebts + erp.workersTotalDebts,
                      erp.suppliersTotalDebtsSyp + erp.workersTotalDebtsSyp),
                  subtitle: 'انقر لفتح تبويبات الموردين والعمالة',
                  icon: Icons.outbox_rounded,
                  iconColor: AppColors.dangerWaste,
                  bgColor: AppColors.chipBgRed,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SupplierWorkerDebtModal(),
                    );
                  },
                ),

                // Card 3: المعمل - لنا زبائن
                MetricCard(
                  title: 'تحليلات المعمل • لنا زبائن',
                  value: AppCurrency.dual(
                      erp.clientsRetailDebts, erp.clientsRetailDebtsSyp),
                  subtitle: 'انقر لعرض ديون الزبائن الجزافية',
                  icon: Icons.storefront_rounded,
                  iconColor: AppColors.orderDepositBoxAccent,
                  bgColor: AppColors.chipBgSky,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ClientDebtModal(titleFilter: 'زبون معمل'),
                    );
                  },
                ),

                // Card 4: المعمل - لنا مشاريع
                MetricCard(
                  title: 'تحليلات المعمل • لنا مشاريع',
                  value: AppCurrency.dual(
                      erp.clientsProjectDebts, erp.clientsProjectDebtsSyp),
                  subtitle: 'انقر لعرض مستحقات المشاريع المتعهد بها',
                  icon: Icons.domain_rounded,
                  iconColor: AppColors.partnersEquityAccent,
                  bgColor: AppColors.chipBgAmber,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ClientDebtModal(titleFilter: 'مشروع معمل'),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            // SECTION 2: BOTTOM KEY FINANCIAL METRICS CARDS
            const Text(
              '2. المؤشرات المالية ورأس المال والأرباح الصافية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandPrimaryText),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.1,
              children: [
                // Metric 1: Current Equity Capital
                MetricCard(
                  title: 'رأس المال الحالي',
                  value: AppCurrency.dual(
                    erp.totalCurrentEquity,
                    erp.totalCurrentEquitySyp,
                  ),
                  icon: Icons.account_balance_rounded,
                  iconColor: AppColors.partnersEquityAccent,
                  bgColor: AppColors.chipBgAmber,
                ),

                // Metric 2: Net Operating Profit
                MetricCard(
                  title: 'قيمة الأرباح الصافية',
                  value: AppCurrency.dual(erp.netOperatingProfit,
                      erp.netOperatingProfitSyp),
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.successGreen,
                  bgColor: AppColors.chipBgGreen,
                ),

                // Metric 3: Special 50% Granite Profit (Accountant Share)
                MetricCard(
                  title: 'أرباح الغرانيت (50%)',
                  value: AppCurrency.dual(erp.accountantGraniteShare,
                      erp.accountantGraniteShareSyp),
                  subtitle: 'مستحقات المحاسب المعتمدة',
                  icon: Icons.pie_chart_rounded,
                  iconColor: AppColors.accentPrimary,
                  bgColor: AppColors.chipBgBlue,
                ),

                // Metric 4: Main Cash Box
                MetricCard(
                  title: 'الصندوق الرئيسي',
                  value: erp.dualMainCash,
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.accentPrimary,
                  bgColor: AppColors.chipBgBlue,
                ),

                // Metric 5: Scrap Cash Box
                MetricCard(
                  title: 'صندوق الزيادات',
                  value: erp.dualScrapCash,
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.scrapBoxAccent,
                  bgColor: AppColors.chipBgGreen,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Quick Status Table & Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'توزيع الأرباح الصافية الحالي حسب نسب الشركاء الحالية:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إجمالي صافي الأرباح القابلة للتوزيع: ${AppCurrency.dual(erp.netOperatingProfit, erp.netOperatingProfitSyp)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.successGreen),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: erp.partners.map((partner) {
                        final partnerProfit =
                            erp.netOperatingProfit * partner.ratio;
                        final partnerProfitSyp =
                            erp.netOperatingProfitSyp * partner.ratio;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.panelBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('النسبة: ${(partner.ratio * 100).fmt}%', style: const TextStyle(fontSize: 12, color: AppColors.brandSecondaryText)),
                                const SizedBox(height: 6),
                                Text(
                                  'رأس المال: ${AppCurrency.dual(partner.injectedCapital, partner.injectedCapitalSyp)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'المستحق الصافي: ${AppCurrency.dual(partnerProfit, partnerProfitSyp)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.partnersEquityAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyConversionDialog(BuildContext context, ERPProvider erp) {
    String convertCurrencyChoice =
        AppCurrency.usd; // Currency to convert (SYP or USD)
    String fromBox = 'main';
    String targetBox = 'main';
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    String? formError;

    String boxName(String b) {
      switch (b) {
        case 'scrap':
          return 'صندوق الزيادات';
        case 'order':
          return 'صندوق الطلبيات';
        default:
          return 'الصندوق الرئيسي';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isUsd = convertCurrencyChoice == AppCurrency.usd;
          final fromSymbol = isUsd ? '\$' : 'ل.س';
          final toSymbol = isUsd ? 'ل.س' : '\$';
          final sourceBalance = erp.cashOf(fromBox, convertCurrencyChoice);
          final targetBalance = erp.cashOf(
            targetBox,
            isUsd ? AppCurrency.syp : AppCurrency.usd,
          );

          final amount = double.tryParse(amountCtrl.text) ?? 0.0;
          final rate = double.tryParse(rateCtrl.text) ?? 0.0;
          final double convertedAmount = isUsd
              ? (amount * rate)
              : (rate > 0 ? (amount / rate) : 0.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.currency_exchange_rounded,
                  color: Color(0xFF0D9488),
                  size: 26,
                ),
                SizedBox(width: 10),
                Text(
                  'تصريف العملات والتحويل بين الصناديق',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'اختر اتجاه تصريف العملة، وحدد الصناديق والمبلغ وسعر الصرف اليوم:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.brandSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Currency Direction Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setSt(
                                () => convertCurrencyChoice = AppCurrency.usd,
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      isUsd ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isUsd
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'تحويل من دولار (\$) إلى ليرة (ل.س)',
                                    style: TextStyle(
                                      fontWeight: isUsd
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isUsd
                                          ? const Color(0xFF0D9488)
                                          : AppColors.brandPrimaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setSt(
                                () => convertCurrencyChoice = AppCurrency.syp,
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isUsd
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !isUsd
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'تحويل من ليرة (ل.س) إلى دولار (\$)',
                                    style: TextStyle(
                                      fontWeight: !isUsd
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: !isUsd
                                          ? const Color(0xFF0D9488)
                                          : AppColors.brandPrimaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Source Box & Target Box
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: fromBox,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'الصندوق المصدر ($fromSymbol)',
                              helperText:
                                  'الرصيد: ${sourceBalance.fmt} $fromSymbol',
                              helperStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'main',
                                child: Text(
                                  'الصندوق الرئيسي (${erp.cashOf('main', convertCurrencyChoice).fmt} $fromSymbol)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'scrap',
                                child: Text(
                                  'صندوق الزيادات (${erp.cashOf('scrap', convertCurrencyChoice).fmt} $fromSymbol)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'order',
                                child: Text(
                                  'صندوق الطلبيات (${erp.cashOf('order', convertCurrencyChoice).fmt} $fromSymbol)',
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setSt(() => fromBox = v ?? 'main'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: targetBox,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'صندوق الاستلام المستهدف ($toSymbol)',
                              helperText:
                                  'الرصيد: ${targetBalance.fmt} $toSymbol',
                              helperStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'main',
                                child: Text(
                                  'الصندوق الرئيسي (${erp.cashOf('main', isUsd ? AppCurrency.syp : AppCurrency.usd).fmt} $toSymbol)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'scrap',
                                child: Text(
                                  'صندوق الزيادات (${erp.cashOf('scrap', isUsd ? AppCurrency.syp : AppCurrency.usd).fmt} $toSymbol)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'order',
                                child: Text(
                                  'صندوق الطلبيات (${erp.cashOf('order', isUsd ? AppCurrency.syp : AppCurrency.usd).fmt} $toSymbol)',
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setSt(() => targetBox = v ?? 'main'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Amount & Rate
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      'المبلغ المراد تصريفه ($fromSymbol)',
                                  prefixIcon:
                                      const Icon(Icons.payments_outlined),
                                ),
                                onChanged: (_) =>
                                    setSt(() => formError = null),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    amountCtrl.text = sourceBalance.fmt;
                                    setSt(() => formError = null);
                                  },
                                  child: const Text('كامل الرصيد المتاح'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            decoration: const InputDecoration(
                              labelText: 'سعر الصرف اليوم (1\$ = ... ل.س)',
                              prefixIcon: Icon(Icons.price_change_outlined),
                            ),
                            onChanged: (_) =>
                                setSt(() => formError = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 4. Live Converted Amount Preview Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF99F6E4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'المبلغ المحوّل الناتج (Live Converted Amount):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  toSymbol,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${convertedAmount.fmt} $toSymbol',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF134E4A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isUsd
                                ? 'الحسبة: ${amount.fmt} \$ × ${rate.fmt} ل.س/دولار = ${convertedAmount.fmt} ل.س'
                                : 'الحسبة: ${amount.fmt} ل.س ÷ ${rate.fmt} = ${convertedAmount.fmt} \$',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const Divider(
                            height: 16,
                            color: Color(0xFF99F6E4),
                          ),
                          Text(
                            '• سيتم خصم: ${amount.fmt} $fromSymbol من (${boxName(fromBox)})\n'
                            '• سيتم إيداع: ${convertedAmount.fmt} $toSymbol في (${boxName(targetBox)})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF115E59),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.dangerWaste,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  if (amount <= 0) {
                    setSt(() => formError = 'أدخل مبلغاً صحيحاً أكبر من الصفر.');
                    return;
                  }
                  if (rate <= 0) {
                    setSt(
                      () =>
                          formError =
                              'أدخل سعر صرف صحيح اليوم أكبر من الصفر.',
                    );
                    return;
                  }
                  if (amount > sourceBalance + 0.0001) {
                    setSt(
                      () => formError =
                          'المبلغ يتجاوز رصيد ${boxName(fromBox)} المتوفر (${sourceBalance.fmt} $fromSymbol).',
                    );
                    return;
                  }
                  final ok = erp.convertCurrency(
                    fromBox: fromBox,
                    toBox: targetBox,
                    fromCurrency: convertCurrencyChoice,
                    amount: amount,
                    exchangeRate: rate,
                  );
                  if (!ok) {
                    setSt(
                      () => formError = 'تعذر تنفيذ عملية التحويل والتصريف.',
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحويل وتصريف ${amount.fmt} $fromSymbol بسعر ${rate.fmt} ل.س بنجاح، وإيداع ${convertedAmount.fmt} $toSymbol في (${boxName(targetBox)}).',
                      ),
                      backgroundColor: AppColors.successGreen,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('تأكيد التحويل (Confirm Transfer)'),
              ),
            ],
          );
        },
      ),
    );
  }
}
