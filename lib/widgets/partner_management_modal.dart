import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Comprehensive Partners & Equity Management View
/// Clarified with rich details: Total Capital KPI, Visual Equity Ownership Bar,
/// Individual Partner Cards with single-partner Capital Injection and Profit Withdrawal,
/// Live Mathematical Dilution Preview Modal, and Capital Injections Log Table.
class PartnerManagementModal extends StatefulWidget {
  const PartnerManagementModal({super.key});

  @override
  State<PartnerManagementModal> createState() => _PartnerManagementModalState();
}

class _PartnerManagementModalState extends State<PartnerManagementModal> {
  int _activeViewTab = 0; // 0: Overview & Partners Cards, 1: History Log, 2: Equity Breakdown Table

  // Distinct palette for partner ownership visualization
  static const List<Color> _partnerColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFFD97706), // Amber
    Color(0xFF059669), // Emerald Green
    Color(0xFF7C3AED), // Violet
    Color(0xFFDC2626), // Rose
    Color(0xFF0D9488), // Teal
  ];

  Color _getPartnerColor(int index) =>
      _partnerColors[index % _partnerColors.length];

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    // Calculate aggregated company metrics
    final totalCapitalUsd = erp.totalCapitalUsd;
    final totalCapitalSyp = erp.totalCapitalSyp;

    final totalNetProfitUsd = erp.netOperatingProfit;
    final totalNetProfitSyp = erp.netOperatingProfitSyp;

    final totalWithdrawnUsd = erp.partners.fold<double>(
      0.0,
      (sum, p) => sum + p.totalWithdrawn,
    );
    final totalWithdrawnSyp = erp.partners.fold<double>(
      0.0,
      (sum, p) => sum + p.totalWithdrawnSyp,
    );

    final netAvailableUsd = totalNetProfitUsd - totalWithdrawnUsd;
    final netAvailableSyp = totalNetProfitSyp - totalWithdrawnSyp;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenSize.width * 0.92,
        constraints: BoxConstraints(
          maxWidth: 1080,
          maxHeight: screenSize.height * 0.90,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Section
            _buildHeader(context, erp),
            const SizedBox(height: 14),

            // 2. High-Level Summary KPI Cards (4 metrics)
            _buildKpiMetricsRow(
              totalCapitalUsd: totalCapitalUsd,
              totalCapitalSyp: totalCapitalSyp,
              netProfitUsd: totalNetProfitUsd,
              netProfitSyp: totalNetProfitSyp,
              totalWithdrawnUsd: totalWithdrawnUsd,
              totalWithdrawnSyp: totalWithdrawnSyp,
              netAvailableUsd: netAvailableUsd,
              netAvailableSyp: netAvailableSyp,
            ),
            const SizedBox(height: 14),

            // 3. Visual Ownership & Equity Distribution Bar
            _buildEquityDistributionBar(erp),
            const SizedBox(height: 14),

            // 4. Sub-Navigation Tabs
            _buildNavigationTabs(erp),
            const SizedBox(height: 12),

            // 5. Scrollable Active View Area
            Expanded(
              child: SingleChildScrollView(
                child: _activeViewTab == 0
                    ? _buildPartnersCardsGrid(context, erp)
                    : _activeViewTab == 1
                        ? _buildInjectionsHistoryTable(erp)
                        : _buildEquityComparisonTable(erp),
              ),
            ),
            const SizedBox(height: 12),

            // 6. Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.brandSecondaryText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'نظام الحصص التلقائي: يتم تحديث النسب والتخفيف (Dilution) فور كل حقن جديد مع الحفاظ على التوازن المالي 100%.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimaryText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('إغلاق النافذة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------
  Widget _buildHeader(BuildContext context, ERPProvider erp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.chipBgAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.partnersEquityAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إدارة الشركاء وحقوق الملكية وتوزيع الأرباح',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'متابعة الحصص المالية، حقن رأس المال الفردي، تخفيف النسب (Dilution)، ومسحوبات الأرباح الصافية',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 15, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'عدد الشركاء: ${erp.partners.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'إغلاق',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // KPI METRICS ROW
  // -------------------------------------------------------------
  Widget _buildKpiMetricsRow({
    required double totalCapitalUsd,
    required double totalCapitalSyp,
    required double netProfitUsd,
    required double netProfitSyp,
    required double totalWithdrawnUsd,
    required double totalWithdrawnSyp,
    required double netAvailableUsd,
    required double netAvailableSyp,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildKpiCard(
            title: 'إجمالي رأس مال الشركة',
            valueUsd: totalCapitalUsd,
            valueSyp: totalCapitalSyp,
            subtitle: 'مجموع الحصص المكتتبة والمحقونة',
            icon: Icons.account_balance_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: 'الأرباح التشغيلية القابلة للتوزيع',
            valueUsd: netProfitUsd,
            valueSyp: netProfitSyp,
            subtitle: 'صافي أرباح العمليات من ملخص الدخل',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: 'إجمالي مسحوبات الشركاء',
            valueUsd: totalWithdrawnUsd,
            valueSyp: totalWithdrawnSyp,
            subtitle: 'المبالغ المسحوبة فعلياً من الحصص',
            icon: Icons.outbox_rounded,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: 'صافي الأرباح المتبقية المتاحة',
            valueUsd: netAvailableUsd,
            valueSyp: netAvailableSyp,
            subtitle: 'الرصيد الفعلي الجاهز للسحب حالياً',
            icon: Icons.savings_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required double valueUsd,
    required double valueSyp,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${valueUsd.fmt} \$',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (valueSyp > 0)
            Text(
              '${valueSyp.fmt} ل.س',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // VISUAL EQUITY DISTRIBUTION BAR
  // -------------------------------------------------------------
  Widget _buildEquityDistributionBar(ERPProvider erp) {
    if (erp.partners.isEmpty) return const SizedBox.shrink();

    final totalPercentage = erp.partners.fold<double>(
      0.0,
      (sum, p) => sum + (p.ratio * 100),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 15, color: AppColors.brandPrimaryText),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'توزيع نسب الملكية بين الشركاء (Equity Ownership Distribution):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'المجموع الكلي: ${totalPercentage.toStringAsFixed(2)}% ✓',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-segmented colored bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: List.generate(erp.partners.length, (index) {
                  final p = erp.partners[index];
                  final flex = ((p.ratio * 1000).round()).clamp(1, 100000);
                  final color = _getPartnerColor(index);
                  return Expanded(
                    flex: flex,
                    child: Tooltip(
                      message:
                          '${p.name}: ${(p.ratio * 100).toStringAsFixed(2)}% (${p.injectedCapital.fmt} \$)',
                      child: Container(
                        color: color,
                        alignment: Alignment.center,
                        child: Text(
                          '${(p.ratio * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Partner Badges Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: List.generate(erp.partners.length, (index) {
              final p = erp.partners[index];
              final color = _getPartnerColor(index);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${(p.ratio * 100).toStringAsFixed(2)}% • ${p.injectedCapital.fmt} \$)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // NAVIGATION TABS
  // -------------------------------------------------------------
  Widget _buildNavigationTabs(ERPProvider erp) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildNavTabButton(
            title: 'بطاقات الشركاء والعمليات الفردية',
            icon: Icons.badge_outlined,
            index: 0,
            badgeCount: erp.partners.length,
          ),
          const SizedBox(width: 8),
          _buildNavTabButton(
            title: 'سجل عمليات حقن رأس المال',
            icon: Icons.history_edu_rounded,
            index: 1,
            badgeCount: erp.capitalInjections.length,
          ),
          const SizedBox(width: 8),
          _buildNavTabButton(
            title: 'جدول مقارنة الشركاء وحقوق الملكية',
            icon: Icons.table_chart_outlined,
            index: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTabButton({
    required String title,
    required IconData icon,
    required int index,
    int? badgeCount,
  }) {
    final isSelected = _activeViewTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _activeViewTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.partnersEquityAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.partnersEquityAccent
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.partnersEquityAccent
                  : AppColors.brandSecondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.partnersEquityAccent
                    : AppColors.brandPrimaryText,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.partnersEquityAccent
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 0: DETAILED PARTNER CARDS WITH ACTION BUTTONS
  // -------------------------------------------------------------
  Widget _buildPartnersCardsGrid(BuildContext context, ERPProvider erp) {
    if (erp.partners.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('لا يوجد شركاء مسجلين في النظام.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'بيانات الشركاء وحصصهم مع إمكانية حقن رأس المال وسحب الأرباح لكل شريك:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              'انقر على "حقن رأس مال" لإضافة مبلغ للشريك مع المعاينة التلقائية للتخفيف',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(erp.partners.length, (index) {
            final partner = erp.partners[index];
            final partnerColor = _getPartnerColor(index);

            // Calculations per partner
            final netProfitShareUsd = erp.netOperatingProfit * partner.ratio;
            final netProfitShareSyp = erp.netOperatingProfitSyp * partner.ratio;

            final netAvailableUsd = netProfitShareUsd - partner.totalWithdrawn;
            final netAvailableSyp = netProfitShareSyp - partner.totalWithdrawnSyp;

            final withdrawalPercent = netProfitShareUsd > 0
                ? ((partner.totalWithdrawn / netProfitShareUsd) * 100).clamp(0.0, 100.0)
                : 0.0;

            return SizedBox(
              width: 320,
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: partnerColor.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner Header with Avatar & Ratio Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: partnerColor.withValues(alpha: 0.15),
                                child: Text(
                                  partner.name.isNotEmpty
                                      ? partner.name.characters.last
                                      : 'P',
                                  style: TextStyle(
                                    color: partnerColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partner.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'معرف: ${partner.id}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: partnerColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: partnerColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${(partner.ratio * 100).toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: partnerColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),

                      // Metric 1: Injected Capital Share
                      _buildPartnerDataRow(
                        label: 'حصة رأس المال:',
                        value: AppCurrency.dual(
                          partner.injectedCapital,
                          partner.injectedCapitalSyp,
                        ),
                        valueColor: AppColors.brandPrimaryText,
                        isBold: true,
                      ),
                      const SizedBox(height: 5),

                      // Metric 2: Net Profit Share
                      _buildPartnerDataRow(
                        label: 'حصة الأرباح الصافية:',
                        value: AppCurrency.dual(
                          netProfitShareUsd,
                          netProfitShareSyp,
                        ),
                        valueColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 5),

                      // Metric 3: Total Withdrawn
                      _buildPartnerDataRow(
                        label: 'إجمالي المسحوبات:',
                        value: AppCurrency.dual(
                          partner.totalWithdrawn,
                          partner.totalWithdrawnSyp,
                        ),
                        valueColor: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 5),

                      // Metric 4: Net Available Profit
                      _buildPartnerDataRow(
                        label: 'الصافي المتاح للسحب:',
                        value: AppCurrency.dual(
                          netAvailableUsd,
                          netAvailableSyp,
                        ),
                        valueColor: const Color(0xFF2563EB),
                        isBold: true,
                      ),
                      const SizedBox(height: 8),

                      // Withdrawal Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'نسبة استنفاذ الأرباح المسحوبة:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${withdrawalPercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: withdrawalPercent > 90
                                      ? Colors.red
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: withdrawalPercent / 100.0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              withdrawalPercent > 90
                                  ? Colors.red
                                  : withdrawalPercent > 50
                                      ? Colors.amber
                                      : Colors.green,
                            ),
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ACTION BUTTONS FOR EACH INDIVIDUAL PARTNER
                      Row(
                        children: [
                          // 1. INJECT CAPITAL BUTTON (Primary Action)
                          Expanded(
                            flex: 3,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.partnersEquityAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showInjectCapitalDialog(
                                context,
                                erp,
                                partner,
                              ),
                              icon: const Icon(Icons.add_circle_outline, size: 15),
                              label: const Text(
                                'حقن رأس مال',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. WITHDRAW PROFIT BUTTON (Secondary Action)
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dangerWaste,
                                side: const BorderSide(
                                  color: AppColors.dangerWaste,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showWithdrawProfitDialog(
                                context,
                                erp,
                                partner,
                              ),
                              icon: const Icon(Icons.outbox_rounded, size: 14),
                              label: const Text(
                                'سحب أرباح',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPartnerDataRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: CAPITAL INJECTIONS HISTORY TABLE
  // -------------------------------------------------------------
  Widget _buildInjectionsHistoryTable(ERPProvider erp) {
    if (erp.capitalInjections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا توجد عمليات حقن رأس مال مسجلة حتى الآن.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'عند حقن رأس مال إضافي من قِبل أي شريك، ستظهر تفاصيل العملية والتخفيف الحاصل هنا آلياً.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final dateFmt = intl.DateFormat('yyyy/MM/dd HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 18, color: AppColors.partnersEquityAccent),
                    SizedBox(width: 8),
                    Text(
                      'سجل عمليات حقن رأس المال والقيود المحاسبية:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  'إجمالي العمليات: ${erp.capitalInjections.length}',
                  style: const TextStyle(fontSize: 12, color: AppColors.brandSecondaryText),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('التاريخ والوقت', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('قيد المعاملة (Transaction Title)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الشريك المحقون', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المبلغ المحقون (A)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الصندوق المستلم', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('رأس مال الشركة (قبل -> بعد)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('حصة الشريك (قبل -> بعد)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('نسبة الملكية (قبل -> بعد)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('البيان / ملاحظات', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: erp.capitalInjections.reversed.map((inj) {
                final safeName = inj.destinationSafe == 'scrap'
                    ? 'صندوق الزيادات'
                    : inj.destinationSafe == 'order'
                        ? 'صندوق الطلبيات'
                        : 'الصندوق الرئيسي';
                return DataRow(
                  cells: [
                    DataCell(Text(dateFmt.format(inj.date), style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          inj.logEntryTitle,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(Text(inj.partnerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(
                      Text(
                        '${inj.amount.fmt} ${AppCurrency.symbol(inj.currency)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.successGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(Text(safeName, style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Text(
                        '${inj.oldTotalCapital.fmt} -> ${inj.newTotalCapital.fmt} ${AppCurrency.symbol(inj.currency)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${inj.oldPartnerShare.fmt} -> ${inj.newPartnerShare.fmt} ${AppCurrency.symbol(inj.currency)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(inj.oldRatio * 100).toStringAsFixed(2)}% -> ${(inj.newRatio * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.partnersEquityAccent,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        inj.notes.isNotEmpty ? inj.notes : '-',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: DETAILED EQUITY COMPARISON TABLE (Non-Overflowing Layout)
  // -------------------------------------------------------------
  Widget _buildEquityComparisonTable(ERPProvider erp) {
    final totalCapital = erp.totalCapitalUsd;
    final totalProfit = erp.netOperatingProfit;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: const Text(
              'جدول المقارنة التفصيلي لحقوق الملكية والمطابقات المالية بين جميع الشركاء:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const Divider(height: 1),
          // Horizontal scroll wrapper to eliminate any horizontal overflow
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 22,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    columns: const [
                      DataColumn(label: Text('الشريك', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('نسبة الملكية', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('رأس المال المكتتب (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('حصة الأرباح (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('المسحوبات (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الصافي المتاح (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('حالة الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: erp.partners.map((p) {
                      final profitShare = totalProfit * p.ratio;
                      final netAvail = profitShare - p.totalWithdrawn;
                      final isWithdrawnClean = netAvail >= 0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: AppColors.partnersEquityAccent),
                                const SizedBox(width: 6),
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              '${(p.ratio * 100).toStringAsFixed(2)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.partnersEquityAccent),
                            ),
                          ),
                          DataCell(Text('${p.injectedCapital.fmt} \$')),
                          DataCell(Text('${profitShare.fmt} \$', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          DataCell(Text('${p.totalWithdrawn.fmt} \$', style: const TextStyle(color: Colors.red))),
                          DataCell(
                            Text(
                              '${netAvail.fmt} \$',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isWithdrawnClean ? Colors.blue.shade700 : Colors.red,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isWithdrawnClean ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isWithdrawnClean ? 'متاح للسحب' : 'تجاوز الحصة',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isWithdrawnClean ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('المجموع الإجمالي للشركة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Text(
                    '100.00% • رأس المال: ${totalCapital.fmt} \$ • الأرباح: ${totalProfit.fmt} \$',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimaryText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // DEDICATED SINGLE-PARTNER CAPITAL INJECTION MODAL DIALOG
  // -------------------------------------------------------------
  void _showInjectCapitalDialog(
    BuildContext context,
    ERPProvider erp,
    PartnerModel partner,
  ) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCurrency = AppCurrency.usd;
    String selectedSafe = 'main';
    DateTime selectedDate = DateTime.now();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double injectedAmount =
                double.tryParse(amountController.text) ?? 0.0;

            final isSyp = AppCurrency.isSyp(selectedCurrency);
            final double currentCompanyCapital = erp.totalCapitalOf(selectedCurrency);
            final double currentPartnerShare =
                isSyp ? partner.injectedCapitalSyp : partner.injectedCapital;
            final double currentRatio = partner.ratio;

            // Live Mathematical Preview Calculations:
            final double newCompanyCapital = currentCompanyCapital + injectedAmount;
            final double newPartnerShare = currentPartnerShare + injectedAmount;
            final double newPartnerRatio = newCompanyCapital > 0
                ? (newPartnerShare / newCompanyCapital)
                : currentRatio;

            // Safe balance preview
            final double currentSafeBalance = erp.cashOf(selectedSafe, selectedCurrency);
            final double newSafeBalance = currentSafeBalance + injectedAmount;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 620,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Modal Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBgAmber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.partnersEquityAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'حقن رأس مال لشريك منفرد',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandPrimaryText,
                                    ),
                                  ),
                                  Text(
                                    'إيداع حصة إضافية وإعادة حساب نسب الملكية والتخفيف آلياً',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // 1. Partner Name: Read-Only / Pre-selected Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.partnersEquityAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'اسم الشريك: ${partner.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.brandPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'الحصة الحالية: ${(currentRatio * 100).toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.partnersEquityAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Injected Amount ($A$) and Currency Selection
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              autofocus: true,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: 'مبلغ رأس المال المحقون (A) *',
                                hintText: 'مثال: 50000',
                                prefixIcon: const Icon(Icons.attach_money_rounded),
                                suffixText: AppCurrency.symbol(selectedCurrency),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: 'العملة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: AppCurrency.usd,
                                  child: Text('USD - دولار (\$)'),
                                ),
                                DropdownMenuItem(
                                  value: AppCurrency.syp,
                                  child: Text('SYP - ليرة (ل.س)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedCurrency = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick Amount Increment Chips
                      Wrap(
                        spacing: 8,
                        children: [1000.0, 5000.0, 10000.0, 50000.0].map((amt) {
                          return ActionChip(
                            label: Text('+${amt.fmt} ${AppCurrency.symbol(selectedCurrency)}'),
                            onPressed: () {
                              final curr = double.tryParse(amountController.text) ?? 0.0;
                              amountController.text = (curr + amt).fmt;
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 3. Destination Safe / Account Selector
                      DropdownButtonFormField<String>(
                        initialValue: selectedSafe,
                        decoration: InputDecoration(
                          labelText: 'الصندوق / الحساب المستلم *',
                          helperText: 'الرصيد الحالي: ${currentSafeBalance.fmt} ${AppCurrency.symbol(selectedCurrency)} -> يصبح: ${newSafeBalance.fmt} ${AppCurrency.symbol(selectedCurrency)}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'main',
                            child: Text('الصندوق الرئيسي (Main Safe) - الافتراضي'),
                          ),
                          DropdownMenuItem(
                            value: 'scrap',
                            child: Text('صندوق الزيادات (Surplus Safe)'),
                          ),
                          DropdownMenuItem(
                            value: 'order',
                            child: Text('صندوق الطلبيات (Orders Safe)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedSafe = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. Date & Reference / Notes
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ العملية',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  intl.DateFormat('yyyy/MM/dd').format(selectedDate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: notesController,
                              decoration: InputDecoration(
                                labelText: 'البيان / مرجع العملية (اختياري)',
                                hintText: 'مثال: توسعة المصنع',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 5. LIVE REAL-TIME MATHEMATICAL PREVIEW BOX
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.calculate_outlined,
                                  color: Color(0xFFB45309),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'المعاينة الرياضية المباشرة لإعادة توزيع رأس المال والتخفيف (Dilution Preview):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Color(0xFFFCD34D)),

                            // Total Company Capital Before & After
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('رأس مال الشركة الإجمالي (C):', style: TextStyle(fontSize: 11)),
                                Text(
                                  '${currentCompanyCapital.fmt} -> ${newCompanyCapital.fmt} ${AppCurrency.symbol(selectedCurrency)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Contributing Partner Share Before & After
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('حصة الشريك (${partner.name}):', style: const TextStyle(fontSize: 11)),
                                Text(
                                  '${currentPartnerShare.fmt} -> ${newPartnerShare.fmt} ${AppCurrency.symbol(selectedCurrency)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Contributing Partner Ownership % Before & After
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('نسبة ملكية الشريك (${partner.name}):', style: const TextStyle(fontSize: 11)),
                                Text(
                                  '${(currentRatio * 100).toStringAsFixed(2)}% -> ${(newPartnerRatio * 100).toStringAsFixed(2)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.partnersEquityAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Dilution breakdown for non-contributing partners
                            if (erp.partners.length > 1 && injectedAmount > 0) ...[
                              const Text(
                                'تخفيف نسب الشركاء غير المساهمين (Dilution):',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Column(
                                children: erp.partners
                                    .where((p) => p.id != partner.id)
                                    .map((other) {
                                  final otherVal = isSyp
                                      ? other.injectedCapitalSyp
                                      : other.injectedCapital;
                                  final dilutedRatio = newCompanyCapital > 0
                                      ? (otherVal / newCompanyCapital)
                                      : other.ratio;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('• ${other.name}:', style: const TextStyle(fontSize: 10)),
                                        Text(
                                          '${(other.ratio * 100).toStringAsFixed(2)}% -> ${(dilutedRatio * 100).toStringAsFixed(2)}% (تخفيف)',
                                          style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Confirmation & Cancel Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('إلغاء'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.partnersEquityAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: injectedAmount <= 0
                                ? null
                                : () {
                                    final success = erp.injectPartnerCapital(
                                      partnerId: partner.id,
                                      amount: injectedAmount,
                                      currency: selectedCurrency,
                                      destinationSafe: selectedSafe,
                                      date: selectedDate,
                                      notes: notesController.text.trim(),
                                    );

                                    if (success) {
                                      Navigator.of(dialogCtx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'تم حقن رأس المال بنجاح! الشريك: ${partner.name} - المبلغ: ${injectedAmount.fmt} ${AppCurrency.symbol(selectedCurrency)} - الحصة الجديدة: ${(partner.ratio * 100).toStringAsFixed(2)}%',
                                          ),
                                          backgroundColor: AppColors.successGreen,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('تأكيد وإيداع رأس المال'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // QUICK PROFIT WITHDRAWAL MODAL DIALOG
  // -------------------------------------------------------------
  void _showWithdrawProfitDialog(
    BuildContext context,
    ERPProvider erp,
    PartnerModel partner,
  ) {
    final amountController = TextEditingController();
    String selectedCurrency = AppCurrency.usd;
    String warningMessage = '';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final netProfitShare = erp.netOperatingProfitOf(selectedCurrency) * partner.ratio;
            final alreadyWithdrawn = AppCurrency.isSyp(selectedCurrency)
                ? partner.totalWithdrawnSyp
                : partner.totalWithdrawn;
            final netAvailable = netProfitShare - alreadyWithdrawn;
            final safeBalance = erp.cashOf('main', selectedCurrency);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 520,
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
                                color: AppColors.chipBgRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.outbox_rounded,
                                color: AppColors.dangerWaste,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سحب أرباح: ${partner.name}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'فحص حدود الأمان وتوفر السيولة في الصندوق الرئيسي',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Limits display box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('حصة الشريك من الأرباح:', style: TextStyle(fontSize: 11)),
                              Text('${netProfitShare.fmt} ${AppCurrency.symbol(selectedCurrency)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المسحوبات السابقة:', style: TextStyle(fontSize: 11)),
                              Text('${alreadyWithdrawn.fmt} ${AppCurrency.symbol(selectedCurrency)}', style: const TextStyle(color: Colors.red, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الحد الأقصى المتاح للسحب:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('${netAvailable.fmt} ${AppCurrency.symbol(selectedCurrency)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('رصيد الصندوق الرئيسي المتوفر:', style: TextStyle(fontSize: 11)),
                              Text('${safeBalance.fmt} ${AppCurrency.symbol(selectedCurrency)}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'المبلغ المطلوب سحبه *',
                              suffixText: AppCurrency.symbol(selectedCurrency),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCurrency,
                            decoration: InputDecoration(
                              labelText: 'العملة',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: AppCurrency.usd, child: Text('USD (\$)')),
                              DropdownMenuItem(value: AppCurrency.syp, child: Text('SYP (ل.س)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedCurrency = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (warningMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          warningMessage,
                          style: const TextStyle(
                            color: AppColors.dangerWaste,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.dangerWaste,
                          ),
                          onPressed: () {
                            final amt = double.tryParse(amountController.text) ?? 0.0;
                            if (amt <= 0) return;

                            final outWarn = MutableWrapper('');
                            final ok = erp.withdrawPartnerProfit(
                              partner.id,
                              amt,
                              outWarn,
                              selectedCurrency,
                            );

                            if (!ok) {
                              setModalState(() => warningMessage = outWarn.value);
                            } else {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم سحب الأرباح للشريك ${partner.name} بمبلغ ${amt.fmt} ${AppCurrency.symbol(selectedCurrency)} بنجاح!',
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.outbox_rounded),
                          label: const Text('تأكيد السحب'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
