import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
import '../widgets/backup_restore_modal.dart';

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
                      // BACKUP & RESTORE: EXPORT BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const BackupRestoreModal(initialTab: 0),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('تصدير نسخة احتياطية (فلاشة / خارجي)'),
                      ),
                      // BACKUP & RESTORE: RESTORE BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const BackupRestoreModal(initialTab: 1),
                          );
                        },
                        icon: const Icon(Icons.cloud_download_rounded),
                        label: const Text('استعادة نسخة احتياطية'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showCenterInfoDialog(context, erp),
                        icon: const Icon(Icons.business_rounded),
                        label: const Text('Add Center Information (بيانات المركز)'),
                      ),
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

            // SYSTEM BACKUP & RESTORE DATA PROTECTION CARD
            _buildBackupProtectionCard(context),
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

                // Metric 3: Special Granite Profit (Accountant Share)
                MetricCard(
                  title: 'أرباح الغرانيت (${erp.graniteAccountantPercentage.fmt}%)',
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
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
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
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
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

  // -------------------------------------------------------------
  // ADD / EDIT CENTER INFORMATION MODAL
  // -------------------------------------------------------------
  void _showCenterInfoDialog(BuildContext context, ERPProvider erp) {
    final current = erp.centerInfo;
    final nameCtrl = TextEditingController(text: current.centerName);
    final ownerCtrl = TextEditingController(text: current.ownerName);
    final phone1Ctrl = TextEditingController(text: current.phone1);
    final phone2Ctrl = TextEditingController(text: current.phone2);
    final regNoCtrl = TextEditingController(text: current.commercialRegNo);
    final taxIdCtrl = TextEditingController(text: current.taxId);
    final logoPathCtrl = TextEditingController(text: current.logoPath);
    final addressCtrl = TextEditingController(text: current.address);
    final sloganCtrl = TextEditingController(text: current.slogan);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة وتعديل بيانات المركز والمنشار',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'تظهر هذه البيانات رسميًا في ترويسة جميع الفواتير المطبوعة A4',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Center Name & Owner Name
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم المركز / المنشأة / المنشار (Center Name) *',
                              prefixIcon: Icon(Icons.domain_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: ownerCtrl,
                            decoration: const InputDecoration(
                              labelText: "اسم المالك / المدير (Owner's Name) *",
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Contact Numbers (First & Second)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phone1Ctrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف الأول (First Contact Number) *',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phone2Ctrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف الثاني (Second Contact Number)',
                              prefixIcon: Icon(Icons.phone_iphone_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Commercial Reg & Tax ID
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: regNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'رقم السجل التجاري (Commercial Reg Number)',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: taxIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الرقم الضريبي (Tax Identification Number)',
                              prefixIcon: Icon(Icons.receipt_long_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4. Address & Slogan
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'العنوان ومقر المركز (Address)',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: sloganCtrl,
                            decoration: const InputDecoration(
                              labelText: 'شعار لفظي / وصف النشاط (Slogan / Activity)',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 5. Center Logo Upload & Preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: Color(0xFF475569),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'شعار المركز / المنشار (Center Logo):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: logoPathCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'مسار ملف الشعار أو رابطه (Logo File Path / URL)',
                                    prefixIcon: Icon(Icons.link_rounded),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setSt(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    final file =
                                        await FilePicker.pickFile(
                                      type: FileType.image,
                                    );
                                    if (file != null &&
                                        file.path != null) {
                                      setSt(() {
                                        logoPathCtrl.text =
                                            file.path!;
                                      });
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر فتح منتقي الملفات: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: const Text('رفع الشعار'),
                              ),
                            ],
                          ),
                          if (logoPathCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: logoPathCtrl.text.startsWith('http')
                                        ? Image.network(
                                            logoPathCtrl.text,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Image.file(
                                            File(logoPathCtrl.text),
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'معاينة الشعار المعتمد',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.dangerWaste,
                                      ),
                                      onPressed: () =>
                                          setSt(() => logoPathCtrl.clear()),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      label: const Text('إلغاء الشعار الحالي'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  final newCenter = CenterInfoModel(
                    centerName: nameCtrl.text.trim().isNotEmpty
                        ? nameCtrl.text.trim()
                        : 'مركز ومنشار الأبرش للرخام والجرانيت',
                    ownerName: ownerCtrl.text.trim(),
                    phone1: phone1Ctrl.text.trim(),
                    phone2: phone2Ctrl.text.trim(),
                    commercialRegNo: regNoCtrl.text.trim(),
                    taxId: taxIdCtrl.text.trim(),
                    logoPath: logoPathCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    slogan: sloganCtrl.text.trim(),
                  );
                  erp.updateCenterInfo(newCenter);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم حفظ بيانات المركز والشعار بنجاح. ستظهر تلقائياً في ترويسة جميع الفواتير المطبوعة A4.',
                      ),
                      backgroundColor: AppColors.successGreen,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('حفظ بيانات المركز'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dedicated Data Protection & Full Backup/Restore card on the main screen.
  Widget _buildBackupProtectionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Dark slate
            Color(0xFF1E293B), // Slate 800
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFF14B8A6),
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'نظام تأمين وحفظ النسخ الاحتياطية وتوزيع البيانات الشامل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'تغطية شاملة 100%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'تأمين كافة سجلات النظام (الفواتير، الصناديق بالدولار والليرة، المخزون، العمال، والمشاريع) على فلاشة USB أو قرص خارجي، مع استعادة وتوزيع البيانات تلقائياً وفورياً على أماكنها الصحيحة في كافة واجهات وشاشات البرنامج.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const BackupRestoreModal(initialTab: 0),
                  );
                },
                icon: const Icon(Icons.usb_rounded, size: 20),
                label: const Text(
                  'تصدير نسخة (فلاشة USB)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const BackupRestoreModal(initialTab: 1),
                  );
                },
                icon: const Icon(Icons.restore_page_rounded, size: 20),
                label: const Text(
                  'استعادة وتوزيع البيانات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
