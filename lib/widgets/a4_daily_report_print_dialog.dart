import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Modal dialog for previewing and printing A4 Daily Reports.
class A4DailyReportPrintDialog extends StatefulWidget {
  final DailyReportModel report;

  const A4DailyReportPrintDialog({
    super.key,
    required this.report,
  });

  /// Static helper to display the dialog easily from any screen
  static Future<void> show(
    BuildContext context, {
    required DailyReportModel report,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => A4DailyReportPrintDialog(report: report),
    );
  }

  @override
  State<A4DailyReportPrintDialog> createState() =>
      _A4DailyReportPrintDialogState();
}

class _A4DailyReportPrintDialogState extends State<A4DailyReportPrintDialog> {
  final List<GlobalKey> _pageKeys = [];
  bool _isPrinting = false;
  bool _isBlackAndWhite = false;
  int _totalPages = 2;

  static const ColorFilter _blackAndWhiteFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  Widget _wrapWithPrintMode(Widget child) {
    if (!_isBlackAndWhite) return child;
    return ColorFiltered(
      colorFilter: _blackAndWhiteFilter,
      child: child,
    );
  }

  // Paginated chunks
  late final List<DailyReportInvoiceSummary> _salesPage1;
  late final List<DailyReportInvoiceSummary> _salesPageExtra;
  late final List<DailyReportInvoiceSummary> _purchaseList;
  late final List<DailyReportInvoiceSummary> _returnList;
  late final List<DailyReportExpenseSummary> _expensesList;
  late final List<DailyReportCashMovementSummary> _cashMovementsList;
  bool _needsPage3 = false;

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

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  void _prepareData() {
    final report = widget.report;

    // Sales invoices split
    if (report.salesInvoices.length > 7) {
      _salesPage1 = report.salesInvoices.sublist(0, 7);
      _salesPageExtra = report.salesInvoices.sublist(7);
    } else {
      _salesPage1 = report.salesInvoices;
      _salesPageExtra = [];
    }

    _purchaseList = report.purchaseInvoices;
    _returnList = report.returnInvoices;
    _expensesList = report.expenses;
    _cashMovementsList = report.cashMovements;

    // Check if Page 2 would be overcrowded
    final page2RowCount = _salesPageExtra.length +
        _purchaseList.length +
        _returnList.length +
        _expensesList.length +
        _cashMovementsList.length;

    if (page2RowCount > 14) {
      _needsPage3 = true;
      _totalPages = 3;
    } else {
      _needsPage3 = false;
      _totalPages = 2;
    }

    _pageKeys.clear();
    for (int i = 0; i < _totalPages; i++) {
      _pageKeys.add(GlobalKey());
    }
  }

  Future<void> _handleDirectPrint() async {
    setState(() => _isPrinting = true);
    try {
      final pdfDoc = pw.Document();

      for (int i = 0; i < _pageKeys.length; i++) {
        final key = _pageKeys[i];
        final boundary = key.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) continue;

        final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final pdfImage = pw.MemoryImage(pngBytes);

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            ),
          ),
        );
      }

      final dateStr = intl.DateFormat('yyyy-MM-dd').format(widget.report.reportDate);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name: 'تقرير_اليومية_الشامل_${widget.report.reportNo}_$dateStr${_isBlackAndWhite ? "_BW" : ""}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال أمر الطباعة: $e'),
            backgroundColor: AppColors.dangerWaste,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final centerInfo = erp.centerInfo;
    final report = widget.report;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1000,
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معاينة التقرير اليومي الشامل (A4 Daily Report Preview)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'رقم التقرير: ${report.reportNo} • تاريخ اليومية: ${intl.DateFormat('yyyy/MM/dd').format(report.reportDate)} • صفحات التقرير: $_totalPages',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Color / B&W Version Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _isBlackAndWhite = false),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !_isBlackAndWhite ? const Color(0xFF1E293B) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: !_isBlackAndWhite
                                      ? Border.all(color: const Color(0x8038BDF8))
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.palette_rounded,
                                      size: 14,
                                      color: !_isBlackAndWhite ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ملونة (الأصل)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: !_isBlackAndWhite ? FontWeight.w900 : FontWeight.w600,
                                        color: !_isBlackAndWhite ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _isBlackAndWhite = true),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isBlackAndWhite ? const Color(0xFF1E293B) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: _isBlackAndWhite
                                      ? Border.all(color: const Color(0x80E2E8F0))
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_b_and_w_rounded,
                                      size: 14,
                                      color: _isBlackAndWhite ? Colors.white : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'أبيض وأسود',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _isBlackAndWhite ? FontWeight.w900 : FontWeight.w600,
                                        color: _isBlackAndWhite ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBlackAndWhite ? const Color(0xFF334155) : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isPrinting ? null : _handleDirectPrint,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isBlackAndWhite ? Icons.print_outlined : Icons.print_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isPrinting
                              ? 'جاري التجهيز...'
                              : _isBlackAndWhite
                                  ? 'طباعة أبيض وأسود (A4)'
                                  : 'طباعة ملونة (A4)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'إغلاق المعاينة',
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Preview Canvas
            Expanded(
              child: Container(
                color: const Color(0xFF0B132B),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        // Page 1
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: RepaintBoundary(
                            key: _pageKeys[0],
                            child: _wrapWithPrintMode(
                              _buildPage1(context, centerInfo, report),
                            ),
                          ),
                        ),

                        // Page 2
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: RepaintBoundary(
                            key: _pageKeys[1],
                            child: _wrapWithPrintMode(
                              _buildPage2(context, centerInfo, report),
                            ),
                          ),
                        ),

                        // Page 3 (if needed)
                        if (_needsPage3 && _pageKeys.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: RepaintBoundary(
                              key: _pageKeys[2],
                              child: _wrapWithPrintMode(
                                _buildPage3(context, centerInfo, report),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PAGE 1: HEADER + FINANCIAL KPIS + CASH BALANCES + SALES INVOICES
  // =========================================================================
  Widget _buildPage1(
    BuildContext context,
    CenterInfoModel centerInfo,
    DailyReportModel report,
  ) {
    return _buildA4Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Official Header
          _buildOfficialHeader(centerInfo),
          const SizedBox(height: 10),

          // 2. Report Title & Meta Banner
          _buildReportTitleBanner(report, pageNumber: 1),
          const SizedBox(height: 12),

          // 3. Executive Financial Summary Cards (6 KPIs)
          _buildFinancialKpiGrid(report),
          const SizedBox(height: 12),

          // 4. Cash Box Balances Table
          _buildCashBalancesTable(report),
          const SizedBox(height: 12),

          // 5. Operations & Attendance Summary Strip
          _buildOperationsAttendanceStrip(report),
          const SizedBox(height: 12),

          // 6. Today's Sales Invoices Table
          _buildSectionHeader(
            title: 'فواتير المبيعات الصادرة اليوم (المصنع والمعمل)',
            count: report.salesInvoices.length,
            icon: Icons.point_of_sale_rounded,
          ),
          const SizedBox(height: 6),
          _buildInvoicesTable(
            invoices: _salesPage1,
            isSales: true,
            emptyMessage: 'لا توجد فواتير مبيعات مسجلة في هذا اليوم.',
          ),

          const SizedBox(height: 24),

          // Page 1 Footer
          _buildA4Footer(pageNumber: 1, totalPages: _totalPages, report: report),
        ],
      ),
    );
  }

  // =========================================================================
  // PAGE 2: PURCHASES + RETURNS + EXPENSES + CASH MOVEMENTS
  // =========================================================================
  Widget _buildPage2(
    BuildContext context,
    CenterInfoModel centerInfo,
    DailyReportModel report,
  ) {
    return _buildA4Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Header
          _buildCompactHeader(centerInfo, report, pageNumber: 2),
          const SizedBox(height: 10),

          // Extra Sales (if any overflowed from Page 1)
          if (_salesPageExtra.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'تتمة فواتير المبيعات الصادرة اليوم',
              count: _salesPageExtra.length,
              icon: Icons.point_of_sale_rounded,
            ),
            const SizedBox(height: 6),
            _buildInvoicesTable(
              invoices: _salesPageExtra,
              isSales: true,
              emptyMessage: '',
            ),
            const SizedBox(height: 12),
          ],

          // Purchase Invoices
          _buildSectionHeader(
            title: 'فواتير المشتريات والتوريد المنفذة اليوم',
            count: _purchaseList.length,
            icon: Icons.local_shipping_rounded,
          ),
          const SizedBox(height: 6),
          _buildInvoicesTable(
            invoices: _purchaseList,
            isSales: false,
            emptyMessage: 'لا توجد فواتير توريد ومشتريات مسجلة في هذا اليوم.',
          ),
          const SizedBox(height: 12),

          // Return Invoices (if any)
          if (_returnList.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'فواتير المرتجعات اليومية',
              count: _returnList.length,
              icon: Icons.assignment_return_rounded,
            ),
            const SizedBox(height: 6),
            _buildReturnsTable(_returnList),
            const SizedBox(height: 12),
          ],

          // Daily Expenses
          _buildSectionHeader(
            title: 'المصاريف والنفقات التشغيلية لليوم',
            count: _expensesList.length,
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 6),
          _buildExpensesTable(_expensesList),
          const SizedBox(height: 12),

          // If NO Page 3: Include Cash Movements & Signatures here
          if (!_needsPage3) ...[
            _buildSectionHeader(
              title: 'حركة السيولة وسحوبات الأرباح بالصناديق',
              count: _cashMovementsList.length,
              icon: Icons.currency_exchange_rounded,
            ),
            const SizedBox(height: 6),
            _buildCashMovementsTable(_cashMovementsList),
            const SizedBox(height: 12),
            _buildNotesAndSignatures(report),
          ],

          const SizedBox(height: 24),

          // Page 2 Footer
          _buildA4Footer(pageNumber: 2, totalPages: _totalPages, report: report),
        ],
      ),
    );
  }

  // =========================================================================
  // PAGE 3: CASH MOVEMENTS & SIGNATURES (WHEN DATA OVERFLOWS)
  // =========================================================================
  Widget _buildPage3(
    BuildContext context,
    CenterInfoModel centerInfo,
    DailyReportModel report,
  ) {
    return _buildA4Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Header
          _buildCompactHeader(centerInfo, report, pageNumber: 3),
          const SizedBox(height: 10),

          // Cash Movements Table
          _buildSectionHeader(
            title: 'حركة السيولة وسحوبات الأرباح بالصناديق لليوم',
            count: _cashMovementsList.length,
            icon: Icons.currency_exchange_rounded,
          ),
          const SizedBox(height: 6),
          _buildCashMovementsTable(_cashMovementsList),
          const SizedBox(height: 16),

          // Notes & Signatures
          _buildNotesAndSignatures(report),

          const SizedBox(height: 24),

          // Page 3 Footer
          _buildA4Footer(pageNumber: 3, totalPages: _totalPages, report: report),
        ],
      ),
    );
  }

  // =========================================================================
  // REUSABLE A4 PAGE CONTAINER
  // =========================================================================
  Widget _buildA4Container({required Widget child}) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  // =========================================================================
  // OFFICIAL HEADER
  // =========================================================================
  Widget _buildOfficialHeader(CenterInfoModel centerInfo) {
    final hasLogo =
        centerInfo.logoPath.isNotEmpty && File(centerInfo.logoPath).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasLogo)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(centerInfo.logoPath),
              width: 58,
              height: 58,
              fit: BoxFit.contain,
            ),
          )
        else
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                centerInfo.centerName.isNotEmpty
                    ? centerInfo.centerName
                    : 'شركة الأبرش للرخام والجرانيت',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerInfo.slogan.isNotEmpty
                    ? centerInfo.slogan
                    : 'إدارة متكاملة للمصنع والمعمل • توريد وتصنيع كافة أنواع الحجر والرخام',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF475569),
                ),
              ),
              if (centerInfo.phone1.isNotEmpty || centerInfo.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (centerInfo.phone1.isNotEmpty) 'هاتف: ${centerInfo.phone1}',
                      if (centerInfo.address.isNotEmpty) 'العنوان: ${centerInfo.address}',
                    ].join('  |  '),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'نظام أبعاد (Abaad ERP)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'تقرير اليومية المالي والتشغيلي',
                style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // COMPACT HEADER (FOR SUBSEQUENT PAGES)
  // =========================================================================
  Widget _buildCompactHeader(
    CenterInfoModel centerInfo,
    DailyReportModel report, {
    required int pageNumber,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 16, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                centerInfo.centerName.isNotEmpty
                    ? centerInfo.centerName
                    : 'شركة الأبرش للرخام والجرانيت',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Text(
                ' • التقرير اليومي الشامل',
                style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ],
          ),
          Text(
            'رقم: ${report.reportNo}  |  تاريخ: ${intl.DateFormat('yyyy/MM/dd').format(report.reportDate)}  |  صفحة $pageNumber من $_totalPages',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // REPORT TITLE & METADATA BANNER
  // =========================================================================
  Widget _buildReportTitleBanner(DailyReportModel report, {required int pageNumber}) {
    final arabicDate = formatArabicDate(report.reportDate);
    final compiledTime = formatArabicDateTime(report.generatedAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description_rounded,
                      size: 16, color: Color(0xFF0284C7)),
                  SizedBox(width: 6),
                  Text(
                    'التقرير المالي والتشغيلي لليوم (Comprehensive Daily Report)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'يوم العمل: $arabicDate',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0369A1),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'رقم المستند: ${report.reportNo}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'توقيت التصدير: $compiledTime',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EXECUTIVE FINANCIAL SUMMARY CARDS (6 KPIS)
  // =========================================================================
  Widget _buildFinancialKpiGrid(DailyReportModel report) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'إجمالي مبيعات اليوم',
                usd: report.totalSalesUsd,
                syp: report.totalSalesSyp,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                icon: Icons.point_of_sale_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'إجمالي مشتريات وتوريد اليوم',
                usd: report.totalPurchasesUsd,
                syp: report.totalPurchasesSyp,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                icon: Icons.local_shipping_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'إجمالي مصاريف اليوم',
                usd: report.totalExpensesUsd,
                syp: report.totalExpensesSyp,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFECACA),
                icon: Icons.payments_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'المقبوضات النقدية الداخلة',
                usd: report.totalCashInUsd,
                syp: report.totalCashInSyp,
                color: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFF99F6E4),
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'المدفوعات النقدية الخارجة',
                usd: report.totalCashOutUsd,
                syp: report.totalCashOutSyp,
                color: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                icon: Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'صافي التدفق النقدي اليومي',
                usd: report.netCashFlowUsd,
                syp: report.netCashFlowSyp,
                color: report.netCashFlowUsd >= 0
                    ? const Color(0xFF047857)
                    : const Color(0xFFB91C1C),
                bgColor: report.netCashFlowUsd >= 0
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderColor: report.netCashFlowUsd >= 0
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFECACA),
                icon: Icons.account_balance_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required double usd,
    required double syp,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            AppCurrency.single(usd, 'USD'),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            AppCurrency.single(syp, 'SYP'),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CASH BOX BALANCES TABLE
  // =========================================================================
  Widget _buildCashBalancesTable(DailyReportModel report) {
    final totalUsd = report.mainCashUsd + report.scrapCashUsd + report.orderCashUsd;
    final totalSyp = report.mainCashSyp + report.scrapCashSyp + report.orderCashSyp;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 13, color: Color(0xFF0F172A)),
                SizedBox(width: 6),
                Text(
                  'أرصدة الصناديق والسيولة النقدية الحالية بالمنشأة (Cash Box Balances)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Table(
            border: TableBorder.symmetric(
              inside: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(2.2),
              3: FlexColumnWidth(2.8),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  _buildTableCell('الصندوق الرئيسي (المصنع والمعمل)', isHeader: true),
                  _buildTableCell('صندوق الفائض (Scrap Fund)', isHeader: true),
                  _buildTableCell('صندوق الطلبيات والمشاريع', isHeader: true),
                  _buildTableCell('إجمالي السيولة النقدية الفعلية', isHeader: true),
                ],
              ),
              TableRow(
                children: [
                  _buildBalanceCell(report.mainCashUsd, report.mainCashSyp),
                  _buildBalanceCell(report.scrapCashUsd, report.scrapCashSyp),
                  _buildBalanceCell(report.orderCashUsd, report.orderCashSyp),
                  _buildBalanceCell(totalUsd, totalSyp, isHighlight: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCell(double usd, double syp, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppCurrency.single(usd, 'USD'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? const Color(0xFF047857)
                  : const Color(0xFF0F172A),
            ),
          ),
          Text(
            AppCurrency.single(syp, 'SYP'),
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // OPERATIONS & ATTENDANCE SUMMARY STRIP
  // =========================================================================
  Widget _buildOperationsAttendanceStrip(DailyReportModel report) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_rounded,
                  size: 13, color: Color(0xFF4338CA)),
              const SizedBox(width: 6),
              const Text(
                'عمليات القص المنفذة بالمصنع:',
                style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 4),
              Text(
                '${report.cuttingOperationsCount} عملية',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4338CA),
                ),
              ),
            ],
          ),
          Container(width: 1, height: 16, color: const Color(0xFFCBD5E1)),
          Row(
            children: [
              const Icon(Icons.badge_rounded,
                  size: 13, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              const Text(
                'سجل حضور الكادر والعاملين:',
                style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 4),
              Text(
                '${report.attendanceCount} موظف حاضر',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION HEADER
  // =========================================================================
  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF0F172A)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count سجل',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // INVOICES TABLE (SALES / PURCHASES)
  // =========================================================================
  Widget _buildInvoicesTable({
    required List<DailyReportInvoiceSummary> invoices,
    required bool isSales,
    required String emptyMessage,
  }) {
    if (invoices.isEmpty) {
      if (emptyMessage.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        columnWidths: const {
          0: FixedColumnWidth(60), // رقم
          1: FixedColumnWidth(55), // قسم
          2: FlexColumnWidth(2.0), // الطرف
          3: FlexColumnWidth(3.2), // الأصناف
          4: FixedColumnWidth(68), // الإجمالي
          5: FixedColumnWidth(62), // المسدد/المقبوض
          6: FixedColumnWidth(62), // المتبقي
          7: FixedColumnWidth(48), // التوقيت
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: [
              _buildTableCell('الرقم', isHeader: true),
              _buildTableCell('القسم', isHeader: true),
              _buildTableCell(isSales ? 'العميل / المعتمد' : 'المورد', isHeader: true),
              _buildTableCell('الأصناف والكميات', isHeader: true),
              _buildTableCell('الإجمالي', isHeader: true),
              _buildTableCell(isSales ? 'المقبوض' : 'المسدد', isHeader: true),
              _buildTableCell('المتبقي', isHeader: true),
              _buildTableCell('الوقت', isHeader: true),
            ],
          ),
          ...invoices.map((inv) {
            final timeStr = formatArabicTime(inv.time);

            return TableRow(
              children: [
                _buildTableCell('#${inv.invoiceNo}', isBold: true),
                _buildTableCell(inv.module),
                _buildTableCell(inv.partyName),
                _buildTableCell(
                  inv.itemsSummary.isNotEmpty ? inv.itemsSummary : '—',
                  align: TextAlign.start,
                ),
                _buildTableCell(
                  AppCurrency.single(inv.totalAmount, inv.currency),
                  isBold: true,
                ),
                _buildTableCell(
                  AppCurrency.single(inv.paidAmount, inv.currency),
                  textColor: const Color(0xFF059669),
                ),
                _buildTableCell(
                  inv.remainingAmount > 0
                      ? AppCurrency.single(inv.remainingAmount, inv.currency)
                      : 'خالص',
                  textColor: inv.remainingAmount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                ),
                _buildTableCell(timeStr),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // RETURNS TABLE
  // =========================================================================
  Widget _buildReturnsTable(List<DailyReportInvoiceSummary> returns) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        columnWidths: const {
          0: FixedColumnWidth(65),
          1: FlexColumnWidth(2.0),
          2: FlexColumnWidth(3.5),
          3: FixedColumnWidth(80),
          4: FixedColumnWidth(80),
          5: FixedColumnWidth(50),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: [
              _buildTableCell('رقم المرتجع', isHeader: true),
              _buildTableCell('العميل', isHeader: true),
              _buildTableCell('المواد المرتجعة', isHeader: true),
              _buildTableCell('إجمالي المرتجع', isHeader: true),
              _buildTableCell('المبلغ المسترد', isHeader: true),
              _buildTableCell('الوقت', isHeader: true),
            ],
          ),
          ...returns.map((ret) {
            final timeStr = formatArabicTime(ret.time);
            return TableRow(
              children: [
                _buildTableCell('#${ret.invoiceNo}', isBold: true),
                _buildTableCell(ret.partyName),
                _buildTableCell(ret.itemsSummary, align: TextAlign.start),
                _buildTableCell(AppCurrency.single(ret.totalAmount, ret.currency)),
                _buildTableCell(
                  AppCurrency.single(ret.paidAmount, ret.currency),
                  textColor: const Color(0xFFDC2626),
                  isBold: true,
                ),
                _buildTableCell(timeStr),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // EXPENSES TABLE
  // =========================================================================
  Widget _buildExpensesTable(List<DailyReportExpenseSummary> expenses) {
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'لا توجد مصاريف أو نفقات تشغيلية مسجلة في هذا اليوم.',
          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        columnWidths: const {
          0: FixedColumnWidth(100), // التصنيف
          1: FlexColumnWidth(3.0), // البيان والوصف
          2: FlexColumnWidth(1.8), // المستفيد
          3: FixedColumnWidth(70), // الصندوق
          4: FixedColumnWidth(80), // المبلغ
          5: FixedColumnWidth(50), // الوقت
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: [
              _buildTableCell('التصنيف', isHeader: true),
              _buildTableCell('البيان والوصف', isHeader: true),
              _buildTableCell('المستفيد', isHeader: true),
              _buildTableCell('الصندوق', isHeader: true),
              _buildTableCell('المبلغ', isHeader: true),
              _buildTableCell('الوقت', isHeader: true),
            ],
          ),
          ...expenses.map((exp) {
            final timeStr = formatArabicTime(exp.time);
            final boxName = exp.cashBox == 'scrap'
                ? 'الفائض'
                : (exp.cashBox == 'order' ? 'الطلبيات' : 'الرئيسي');

            return TableRow(
              children: [
                _buildTableCell(exp.category, isBold: true),
                _buildTableCell(exp.description, align: TextAlign.start),
                _buildTableCell(exp.beneficiary.isNotEmpty ? exp.beneficiary : '—'),
                _buildTableCell(boxName),
                _buildTableCell(
                  AppCurrency.single(exp.amount, exp.currency),
                  textColor: const Color(0xFFDC2626),
                  isBold: true,
                ),
                _buildTableCell(timeStr),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // CASH MOVEMENTS TABLE
  // =========================================================================
  Widget _buildCashMovementsTable(List<DailyReportCashMovementSummary> movements) {
    if (movements.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'لا توجد حركات سيولة مسجلة في هذا اليوم.',
          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        columnWidths: const {
          0: FixedColumnWidth(110), // نوع الحركة
          1: FlexColumnWidth(3.0), // البيان
          2: FixedColumnWidth(75), // الصندوق
          3: FixedColumnWidth(85), // المبلغ
          4: FixedColumnWidth(50), // الوقت
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: [
              _buildTableCell('نوع الحركة', isHeader: true),
              _buildTableCell('البيان والجهة', isHeader: true),
              _buildTableCell('الصندوق', isHeader: true),
              _buildTableCell('المبلغ المسجل', isHeader: true),
              _buildTableCell('الوقت', isHeader: true),
            ],
          ),
          ...movements.map((mov) {
            final timeStr = formatArabicTime(mov.time);
            final isInflow = mov.type.contains('قبض') || mov.type.contains('وارد');
            final boxName = mov.cashBox == 'scrap'
                ? 'الفائض'
                : (mov.cashBox == 'order' ? 'الطلبيات' : 'الرئيسي');

            return TableRow(
              children: [
                _buildTableCell(
                  mov.type,
                  isBold: true,
                  textColor: isInflow
                      ? const Color(0xFF047857)
                      : const Color(0xFFB91C1C),
                ),
                _buildTableCell(mov.description, align: TextAlign.start),
                _buildTableCell(boxName),
                _buildTableCell(
                  '${isInflow ? '+' : '-'} ${AppCurrency.single(mov.amount, mov.currency)}',
                  textColor: isInflow
                      ? const Color(0xFF047857)
                      : const Color(0xFFB91C1C),
                  isBold: true,
                ),
                _buildTableCell(timeStr),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // NOTES & SIGNATURES AREA
  // =========================================================================
  Widget _buildNotesAndSignatures(DailyReportModel report) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.notes.isNotEmpty) ...[
            const Text(
              'ملاحظات اليومية وتوجيهات الإدارة:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              report.notes,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF1E293B)),
            ),
            const Divider(height: 12),
          ],
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'المحاسب المالي المسؤول',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '....................................',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'المدير العام / الاعتماد',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '....................................',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TABLE CELL BUILDER
  // =========================================================================
  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    Color? textColor,
    TextAlign align = TextAlign.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 9.5 : 9,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? const Color(0xFF0F172A)
              : (textColor ?? const Color(0xFF1E293B)),
        ),
      ),
    );
  }

  // =========================================================================
  // STANDARDIZED BRAND A4 FOOTER
  // =========================================================================
  Widget _buildA4Footer({
    required int pageNumber,
    required int totalPages,
    required DailyReportModel report,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'برنامج Sh Ab\'ad • هاتف: 0931691900 • مستند معتمد',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            'صفحة $pageNumber من $totalPages • تاريخ التقرير: ${intl.DateFormat('yyyy/MM/dd').format(report.reportDate)}',
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
