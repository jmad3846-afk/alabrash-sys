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
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                        onPressed: () {
                          showDialog(context: context, builder: (_) => const WorkdayModal());
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
                  value: '${erp.totalCurrentEquity.fmt} \$',
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
}

