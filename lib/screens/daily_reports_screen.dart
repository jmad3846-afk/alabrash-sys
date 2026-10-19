import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/a4_daily_report_print_dialog.dart';

/// Screen for managing, compiling, and previewing Daily Reports.
class DailyReportsScreen extends StatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  State<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends State<DailyReportsScreen> {
  String _searchQuery = '';
  DateTime? _selectedFilterDate;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatArabicDate(DateTime date) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const months = [
      'كانون الثاني / يناير',
      'شباط / فبراير',
      'آذار / مارس',
      'نيسان / أبريل',
      'أيار / مايو',
      'حزيران / يونيو',
      'تموز / يوليو',
      'آب / أغسطس',
      'أيلول / سبتمبر',
      'تشرين الأول / أكتوبر',
      'تشرين الثاني / نوفمبر',
      'كانون الأول / ديسمبر',
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName، ${date.day} $monthName ${date.year}';
  }

  static String formatArabicTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'م' : 'ص';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  static String formatArabicDateTime(DateTime dt) {
    final ymd =
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    return '$ymd - ${formatArabicTime(dt)}';
  }

  void _generateAndExportToday(BuildContext context, ERPProvider erp) {
    final report = erp.compileDailyReportForDate(DateTime.now());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم تصدير وتحديث تقرير اليوم (${report.reportNo}) بنجاح متضمناً كافة العمليات.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    // Open A4 print preview immediately
    A4DailyReportPrintDialog.show(context, report: report);
  }

  Future<void> _pickDateAndGenerate(
      BuildContext context, ERPProvider erp) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ اليومية المراد توليد تقريرها',
      confirmText: 'توليد وتصدير',
      cancelText: 'إلغاء',
    );

    if (picked != null) {
      final report = erp.compileDailyReportForDate(picked);

      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            'تم توليد تقرير يوم ${intl.DateFormat('yyyy/MM/dd').format(picked)} بنجاح.',
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );

      A4DailyReportPrintDialog.show(this.context, report: report);
    }
  }

  void _confirmDeleteReport(
      BuildContext context, ERPProvider erp, DailyReportModel report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('حذف التقرير اليومي من الأرشيف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف التقرير رقم (${report.reportNo}) لتاريخ ${intl.DateFormat('yyyy/MM/dd').format(report.reportDate)}؟\nملاحظة: حذف التقرير لا يحذف الفواتير أو الحركات المالية المسجلة بالبرنامج.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              erp.deleteDailyReport(report.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف التقرير من الأرشيف.'),
                  backgroundColor: Color(0xFF475569),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final allReports = erp.dailyReports;

    final todayReport = allReports.cast<DailyReportModel?>().firstWhere(
          (r) => r != null && _isSameDay(r.reportDate, DateTime.now()),
          orElse: () => null,
        );

    // Filter reports
    final filteredReports = allReports.where((r) {
      if (_selectedFilterDate != null &&
          !_isSameDay(r.reportDate, _selectedFilterDate!)) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchNo = r.reportNo.toLowerCase().contains(q);
        final matchNotes = r.notes.toLowerCase().contains(q);
        final dateStr = intl.DateFormat('yyyy/MM/dd').format(r.reportDate);
        final matchDate = dateStr.contains(q);
        if (!matchNo && !matchNotes && !matchDate) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER BAR
            _buildTopAppBar(context, erp),

            // MAIN CONTENT SCROLLABLE
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. TODAY'S STATUS BANNER
                    _buildTodayStatusBanner(context, erp, todayReport),
                    const SizedBox(height: 16),

                    // 2. STATS OVERVIEW CARDS
                    _buildStatsOverview(allReports),
                    const SizedBox(height: 16),

                    // 3. SEARCH & FILTER BAR
                    _buildFilterBar(),
                    const SizedBox(height: 16),

                    // 4. ARCHIVED REPORTS LIST
                    _buildArchivedReportsList(
                        context, erp, filteredReports, allReports.length),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TOP APP BAR
  // =========================================================================
  Widget _buildTopAppBar(BuildContext context, ERPProvider erp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title & Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'العودة للشاشة الرئيسية',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF38BDF8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التقارير اليومية وحركة الصناديق (Daily Reports)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'توليد وتصدير تقرير شامل لكافة العمليات اليومية وحركة الصناديق للطباعة المعتمدة A4',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Primary Actions
          Row(
            children: [
              // Export / Generate Today's Report (Primary Action)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
                onPressed: () => _generateAndExportToday(context, erp),
                icon: const Icon(Icons.post_add_rounded, size: 20),
                label: const Text(
                  'تصدير وتحديث تقرير اليوم',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Generate for Specific Date
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _pickDateAndGenerate(context, erp),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text(
                  'تقرير لتاريخ مخصص',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TODAY'S LIVE STATUS BANNER
  // =========================================================================
  Widget _buildTodayStatusBanner(
    BuildContext context,
    ERPProvider erp,
    DailyReportModel? todayReport,
  ) {
    final now = DateTime.now();
    final arabicDate = formatArabicDate(now);

    final hasReport = todayReport != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasReport ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasReport ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasReport
                  ? const Color(0xFF059669)
                  : const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasReport
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'يوم العمل الحالي: $arabicDate',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: hasReport
                            ? const Color(0xFF14532D)
                            : const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasReport
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasReport ? 'تم إصدار التقرير' : 'لم يتم التصدير بعد',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasReport
                              ? const Color(0xFF15803D)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasReport
                      ? 'تم تصدير نسخة تقرير اليوم (${todayReport.reportNo}) في تمام الساعة ${formatArabicTime(todayReport.generatedAt)}. يمكنك معاينة التقرير للطباعة أو إعادة تصديره في أي وقت لتحديث أحدث العمليات.'
                      : 'التقارير اليومية لا تُنشأ تلقائياً عند نهاية اليوم بل يتم توليدها بناءً على طلبك. انقر على زر "تصدير وتحديث تقرير اليوم" لتوليد وتحديث نسخة شاملة بكافة العمليات.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasReport
                        ? const Color(0xFF166534)
                        : const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (hasReport)
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () =>
                      A4DailyReportPrintDialog.show(context, report: todayReport),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'معاينة وطباعة A4',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _generateAndExportToday(context, erp),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text(
                    'تحديث فوري',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _generateAndExportToday(context, erp),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text(
                'تصدير تقرير اليوم الآن',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // STATS OVERVIEW CARDS
  // =========================================================================
  Widget _buildStatsOverview(List<DailyReportModel> reports) {
    double totalSalesUsd = 0;
    double totalSalesSyp = 0;
    double totalExpensesUsd = 0;
    double totalExpensesSyp = 0;
    double totalNetUsd = 0;
    double totalNetSyp = 0;

    for (final r in reports) {
      totalSalesUsd += r.totalSalesUsd;
      totalSalesSyp += r.totalSalesSyp;
      totalExpensesUsd += r.totalExpensesUsd;
      totalExpensesSyp += r.totalExpensesSyp;
      totalNetUsd += r.netCashFlowUsd;
      totalNetSyp += r.netCashFlowSyp;
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'إجمالي التقارير المؤرشفة',
            value: '${reports.length} تقرير يومي',
            subtitle: 'محفوظ في قاعدة البيانات والنسخ الاحتياطي',
            color: const Color(0xFF4338CA),
            bgColor: const Color(0xFFEEF2FF),
            borderColor: const Color(0xFFC7D2FE),
            icon: Icons.inventory_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'إجمالي المبيعات المؤرشفة',
            value: AppCurrency.dual(totalSalesUsd, totalSalesSyp),
            subtitle: 'مبيعات المصنع والمعمل عبر التقارير',
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'إجمالي المصاريف المؤرشفة',
            value: AppCurrency.dual(totalExpensesUsd, totalExpensesSyp),
            subtitle: 'النفقات ومصاريف التشغيل المسجلة',
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            icon: Icons.payments_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'صافي التدفق المالي المسجل',
            value: AppCurrency.dual(totalNetUsd, totalNetSyp),
            subtitle: 'المقبوضات النقدية ناقص المدفوعات',
            color: const Color(0xFF0D9488),
            bgColor: const Color(0xFFF0FDFA),
            borderColor: const Color(0xFF99F6E4),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SEARCH & FILTER BAR
  // =========================================================================
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث برقم التقرير (DREP-...) أو الملاحظات أو التاريخ...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 14),

          // Date Filter Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              side: BorderSide(
                color: _selectedFilterDate != null
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFCBD5E1),
              ),
              backgroundColor: _selectedFilterDate != null
                  ? const Color(0xFFF0F9FF)
                  : Colors.white,
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedFilterDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedFilterDate = picked);
              }
            },
            icon: Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: _selectedFilterDate != null
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF64748B),
            ),
            label: Text(
              _selectedFilterDate != null
                  ? intl.DateFormat('yyyy/MM/dd').format(_selectedFilterDate!)
                  : 'تصفية حسب التاريخ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _selectedFilterDate != null
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF334155),
              ),
            ),
          ),

          if (_selectedFilterDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
              tooltip: 'إلغاء تصفية التاريخ',
              onPressed: () => setState(() => _selectedFilterDate = null),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // ARCHIVED REPORTS LIST
  // =========================================================================
  Widget _buildArchivedReportsList(
    BuildContext context,
    ERPProvider erp,
    List<DailyReportModel> reports,
    int totalCount,
  ) {
    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 54, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 14),
            Text(
              totalCount == 0
                  ? 'لا توجد تقارير يومية مؤرشفة حتى الآن.'
                  : 'لا توجد نتائج تطابق معايير البحث أو التصفية الحالية.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'يمكنك تصدير تقرير اليوم بالنقر على زر "تصدير وتحديث تقرير اليوم" بأعلى الصفحة.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: reports.map((report) {
        return _buildReportCard(context, erp, report);
      }).toList(),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ERPProvider erp,
    DailyReportModel report,
  ) {
    final arabicDate = formatArabicDate(report.reportDate);
    final compiledTime = formatArabicDateTime(report.generatedAt);

    final totalInvoices =
        report.salesInvoices.length + report.purchaseInvoices.length + report.returnInvoices.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF0F172A),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Text(
              report.reportNo,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                arabicDate,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'تصدير: $compiledTime',
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMiniStat('مبيعات', AppCurrency.dual(report.totalSalesUsd, report.totalSalesSyp)),
              _buildMiniStat('مشتريات', AppCurrency.dual(report.totalPurchasesUsd, report.totalPurchasesSyp)),
              _buildMiniStat('مصاريف', AppCurrency.dual(report.totalExpensesUsd, report.totalExpensesSyp)),
              _buildMiniStat('صافي التدفق', AppCurrency.dual(report.netCashFlowUsd, report.netCashFlowSyp),
                  color: report.netCashFlowUsd >= 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$totalInvoices فاتورة • ${report.expenses.length} مصاريف • ${report.cashMovements.length} حركة سيولة',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Financial summary breakdown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailBox(
                        title: 'حركة المقبوضات والمدفوعات',
                        lines: [
                          'المقبوضات الداخلة: ${AppCurrency.dual(report.totalCashInUsd, report.totalCashInSyp)}',
                          'المدفوعات الخارجة: ${AppCurrency.dual(report.totalCashOutUsd, report.totalCashOutSyp)}',
                          'صافي السيولة اليومي: ${AppCurrency.dual(report.netCashFlowUsd, report.netCashFlowSyp)}',
                        ],
                        icon: Icons.currency_exchange_rounded,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailBox(
                        title: 'أرصدة الصناديق وقت التقرير',
                        lines: [
                          'الصندوق الرئيسي: ${AppCurrency.dual(report.mainCashUsd, report.mainCashSyp)}',
                          'صندوق الفائض: ${AppCurrency.dual(report.scrapCashUsd, report.scrapCashSyp)}',
                          'صندوق الطلبيات: ${AppCurrency.dual(report.orderCashUsd, report.orderCashSyp)}',
                        ],
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailBox(
                        title: 'العمليات وكادر العمل',
                        lines: [
                          'عمليات القص المنفذة: ${report.cuttingOperationsCount} عملية',
                          'حضور كادر العمل: ${report.attendanceCount} موظف',
                          'فواتير مرتجعة: ${report.returnInvoices.length} مرتجع',
                        ],
                        icon: Icons.handyman_rounded,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Delete Report
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: () =>
                          _confirmDeleteReport(context, erp, report),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('حذف من الأرشيف'),
                    ),
                    const SizedBox(width: 12),

                    // Refresh / Recompile Report
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final updated =
                            erp.compileDailyReportForDate(report.reportDate);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'تم تحديث تقرير ${report.reportNo} ببيانات اللحظة.'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                        A4DailyReportPrintDialog.show(context, report: updated);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('تحديث بيانات التقرير'),
                    ),
                    const SizedBox(width: 12),

                    // Full On-Screen Details
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () =>
                          _showReportDetailsModal(context, erp, report),
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text('عرض التفاصيل الشاملة'),
                    ),
                    const SizedBox(width: 12),

                    // Print Preview (Primary)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () =>
                          A4DailyReportPrintDialog.show(context, report: report),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('معاينة وطباعة A4'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBox({
    required String title,
    required List<String> lines,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                l,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ON-SCREEN FULL DETAILS MODAL
  // =========================================================================
  void _showReportDetailsModal(
    BuildContext context,
    ERPProvider erp,
    DailyReportModel report,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل التقرير اليومي: ${report.reportNo}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'تاريخ اليومية: ${intl.DateFormat('yyyy/MM/dd').format(report.reportDate)} • تم التصدير: ${formatArabicDateTime(report.generatedAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          A4DailyReportPrintDialog.show(context, report: report);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('طباعة كشف A4'),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Scrollable content
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorColor: const Color(0xFF059669),
                        indicatorWeight: 3,
                        tabs: [
                          Tab(
                            text:
                                'فواتير المبيعات (${report.salesInvoices.length})',
                          ),
                          Tab(
                            text:
                                'فواتير المشتريات (${report.purchaseInvoices.length})',
                          ),
                          Tab(
                            text: 'المصاريف (${report.expenses.length})',
                          ),
                          Tab(
                            text:
                                'حركة السيولة (${report.cashMovements.length})',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 1. Sales Invoices
                            _buildScrollableInvoiceTable(report.salesInvoices, isSales: true),
                            // 2. Purchase Invoices
                            _buildScrollableInvoiceTable(report.purchaseInvoices, isSales: false),
                            // 3. Expenses
                            _buildScrollableExpenseTable(report.expenses),
                            // 4. Cash movements
                            _buildScrollableMovementsTable(report.cashMovements),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableInvoiceTable(
    List<DailyReportInvoiceSummary> items, {
    required bool isSales,
  }) {
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد فواتير مسجلة في هذا القسم.'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, idx) {
        final inv = items[idx];
        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('#${inv.invoiceNo}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          title: Row(
            children: [
              Text(
                inv.partyName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(inv.module, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
          subtitle: Text(
            inv.itemsSummary.isNotEmpty ? inv.itemsSummary : '—',
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppCurrency.single(inv.totalAmount, inv.currency),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                'المدفوع: ${AppCurrency.single(inv.paidAmount, inv.currency)}',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF059669)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollableExpenseTable(List<DailyReportExpenseSummary> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد مصاريف مسجلة.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, idx) {
        final exp = items[idx];
        return ListTile(
          dense: true,
          title: Text(exp.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          subtitle: Text(
            'التصنيف: ${exp.category}  |  المستفيد: ${exp.beneficiary.isNotEmpty ? exp.beneficiary : "—"}  |  الصندوق: ${exp.cashBox}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
          ),
          trailing: Text(
            AppCurrency.single(exp.amount, exp.currency),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: Color(0xFFDC2626),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollableMovementsTable(
      List<DailyReportCashMovementSummary> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد حركات نقدية مسجلة.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, idx) {
        final mov = items[idx];
        final isInflow =
            mov.type.contains('قبض') || mov.type.contains('وارد');

        return ListTile(
          dense: true,
          title: Text(mov.type,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isInflow
                    ? const Color(0xFF047857)
                    : const Color(0xFFB91C1C),
              )),
          subtitle: Text(
            '${mov.description} • الصندوق: ${mov.cashBox}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
          ),
          trailing: Text(
            '${isInflow ? "+" : "-"} ${AppCurrency.single(mov.amount, mov.currency)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: isInflow
                  ? const Color(0xFF047857)
                  : const Color(0xFFB91C1C),
            ),
          ),
        );
      },
    );
  }
}
