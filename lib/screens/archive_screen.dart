import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/archive_and_close_period_modal.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedArchiveId;

  // Search controllers for each section to provide independent, clutter-free search
  final TextEditingController _invoiceSearchCtrl = TextEditingController();
  final TextEditingController _expenseSearchCtrl = TextEditingController();
  final TextEditingController _workforceSearchCtrl = TextEditingController();
  final TextEditingController _ordersReportsSearchCtrl = TextEditingController();
  final TextEditingController _openingEntrySearchCtrl = TextEditingController();

  // Category filter state for tab sub-sections
  String _invoiceFilter = 'all'; // 'all', 'factory', 'workshop', 'returns'
  String _expenseFilter = 'all'; // 'all', 'operating', 'surplus', 'asset_sales'
  String _workforceFilter = 'all'; // 'all', 'workdays', 'attendance', 'advances'
  String _ordersFilter = 'all'; // 'all', 'factory', 'workshop', 'reports'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceSearchCtrl.dispose();
    _expenseSearchCtrl.dispose();
    _workforceSearchCtrl.dispose();
    _ordersReportsSearchCtrl.dispose();
    _openingEntrySearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final archives = erp.periodArchives;

    // Pick latest archive if none selected or selected was removed
    PeriodArchiveModel? currentArchive;
    if (archives.isNotEmpty) {
      if (_selectedArchiveId != null) {
        currentArchive = archives.firstWhere(
          (a) => a.id == _selectedArchiveId,
          orElse: () => archives.last,
        );
      } else {
        currentArchive = archives.last;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: archives.isEmpty
            ? _buildEmptyArchiveView(context, erp)
            : _buildArchiveContentView(context, erp, archives, currentArchive!),
      ),
    );
  }

  // -------------------------------------------------------------
  // EMPTY STATE (عندما لا يوجد أي أرشيف مرحل بعد)
  // -------------------------------------------------------------
  Widget _buildEmptyArchiveView(BuildContext context, ERPProvider erp) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(36),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 40,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا يوجد أرشيف فترات سابقة حتى الآن',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'عند إتمام عملية "ترحيل وجرد" من الشاشة الرئيسية، يقوم المحرك المحاسبي بأرشفة الفواتير والمصروفات والتقارير المكتملة بصيغة قراءة فقط، وتصفير الحسابات المؤقتة، وتدوير الأرباح وتوليد القيد الافتتاحي للفترة الجديدة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () => _openArchiveModal(context, erp),
              icon: const Icon(Icons.archive_rounded, size: 20),
              label: const Text(
                'بدء ترحيل وجرد الفترة الحالية الآن',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ACTIVE ARCHIVE CONTENT VIEW
  // -------------------------------------------------------------
  Widget _buildArchiveContentView(
    BuildContext context,
    ERPProvider erp,
    List<PeriodArchiveModel> archives,
    PeriodArchiveModel archive,
  ) {
    return Column(
      children: [
        // Top Archive Navigation & Summary Header
        _buildArchiveHeader(context, erp, archives, archive),

        // Tabs Header with Counts
        _buildTabsHeader(archive),

        // Tab Content Views with Dedicated Search
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInvoicesTab(archive),
              _buildExpensesTab(archive),
              _buildRevenuesProfitTab(archive),
              _buildWorkforceTab(archive),
              _buildOrdersReportsTab(archive),
              _buildRolledOpeningEntryTab(archive),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TOP ARCHIVE HEADER & SELECTOR
  // -------------------------------------------------------------
  Widget _buildArchiveHeader(
    BuildContext context,
    ERPProvider erp,
    List<PeriodArchiveModel> archives,
    PeriodArchiveModel archive,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 24,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'أرشيف الفترات المحاسبية',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB45309)),
                              SizedBox(width: 4),
                              Text(
                                'قراءة فقط ومحمي',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'استعراض تاريخي مفصل للفترات المغلقة دون التأثير على سرعة قاعدة البيانات النشطة',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Archive Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: archive.id,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                    items: archives.map((a) {
                      return DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(
                          '${a.archiveName} (${_formatDate(a.archivedAt)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        setState(() {
                          _selectedArchiveId = newId;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Trigger Another Archive
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                onPressed: () => _openArchiveModal(context, erp),
                icon: const Icon(Icons.archive_rounded, size: 18),
                label: const Text(
                  'ترحيل وجرد جديد',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Archive Snapshot KPI Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildKpiItem(
                  title: 'إيرادات الفترة',
                  value: AppCurrency.dual(archive.totalRevenuesUsd, archive.totalRevenuesSyp),
                  color: const Color(0xFF0D9488),
                  icon: Icons.trending_up_rounded,
                ),
                _buildVerticalDivider(),
                _buildKpiItem(
                  title: 'مصروفات الفترة',
                  value: AppCurrency.dual(archive.totalExpensesUsd, archive.totalExpensesSyp),
                  color: const Color(0xFFDC2626),
                  icon: Icons.receipt_long_rounded,
                ),
                _buildVerticalDivider(),
                _buildKpiItem(
                  title: 'صافي الربح المرحل',
                  value: AppCurrency.dual(archive.netProfitUsd, archive.netProfitSyp),
                  color: const Color(0xFF16A34A),
                  icon: Icons.monetization_on_rounded,
                ),
                _buildVerticalDivider(),
                _buildKpiItem(
                  title: 'رأس المال والمدور',
                  value: '${archive.totalEquityUsd.fmt} \$',
                  color: const Color(0xFF4338CA),
                  icon: Icons.account_balance_rounded,
                ),
                _buildVerticalDivider(),
                _buildKpiItem(
                  title: 'الصناديق المرحلة',
                  value: '${archive.mainCashUsd.fmt} \$ | ${archive.mainCashSyp.fmt} ل.س',
                  color: const Color(0xFF475569),
                  icon: Icons.point_of_sale_rounded,
                ),
              ],
            ),
          ),
          if (archive.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظات الأرشفة: ${archive.notes}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFCBD5E1),
    );
  }

  Widget _buildKpiItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TABS HEADER WITH BADGES
  // -------------------------------------------------------------
  Widget _buildTabsHeader(PeriodArchiveModel archive) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFFD97706),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFFD97706),
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              children: [
                const Icon(Icons.receipt_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('الفواتير والمردودات'),
                const SizedBox(width: 6),
                _buildTabBadge(archive.totalInvoicesCount + archive.totalAdjustmentsCount),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.request_quote_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('المصروفات والتكاليف'),
                const SizedBox(width: 6),
                _buildTabBadge(archive.totalExpensesCount + archive.assetSaleRecords.length),
              ],
            ),
          ),
          const Tab(
            child: Row(
              children: [
                Icon(Icons.assessment_rounded, size: 16),
                SizedBox(width: 6),
                Text('ملخص الإيرادات والأرباح'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('شؤون العمال والدوام'),
                const SizedBox(width: 6),
                _buildTabBadge(
                  archive.workdayEntries.length +
                      archive.staffAttendance.length +
                      archive.advanceRepayments.length,
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.assignment_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('الطلبيات والتقارير اليومية'),
                const SizedBox(width: 6),
                _buildTabBadge(archive.totalOrdersCount + archive.dailyReports.length),
              ],
            ),
          ),
          const Tab(
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 16),
                SizedBox(width: 6),
                Text('القيد الافتتاحي الناتج'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: INVOICES & RETURNS TAB (الفواتير والمردودات)
  // -------------------------------------------------------------
  Widget _buildInvoicesTab(PeriodArchiveModel archive) {
    final query = _invoiceSearchCtrl.text.trim().toLowerCase();

    // Group items for display
    final factoryInvoices = archive.factoryInvoices.where((i) {
      if (_invoiceFilter != 'all' && _invoiceFilter != 'factory') return false;
      if (query.isEmpty) return true;
      return i.invoiceNo.toLowerCase().contains(query) ||
          i.partyName.toLowerCase().contains(query) ||
          i.invoiceType.toLowerCase().contains(query);
    }).toList();

    final workshopInvoices = archive.workshopInvoices.where((i) {
      if (_invoiceFilter != 'all' && _invoiceFilter != 'workshop') return false;
      if (query.isEmpty) return true;
      return i.invoiceNo.toLowerCase().contains(query) ||
          i.clientName.toLowerCase().contains(query);
    }).toList();

    final returnInvoices = archive.returnInvoices.where((r) {
      if (_invoiceFilter != 'all' && _invoiceFilter != 'returns') return false;
      if (query.isEmpty) return true;
      return r.returnNo.toLowerCase().contains(query) ||
          r.parentInvoiceNo.toLowerCase().contains(query) ||
          r.partyName.toLowerCase().contains(query);
    }).toList();

    final totalCount = factoryInvoices.length + workshopInvoices.length + returnInvoices.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sub-bar: Search & Filter Chips
          _buildSearchAndFiltersRow(
            controller: _invoiceSearchCtrl,
            hint: 'بحث برقم الفاتورة، اسم العميل، المورد، أو نوع المعاملة...',
            onChanged: () => setState(() {}),
            filters: [
              _buildFilterChip('الكل', 'all', _invoiceFilter, (v) => setState(() => _invoiceFilter = v)),
              _buildFilterChip('فواتير المصنع', 'factory', _invoiceFilter, (v) => setState(() => _invoiceFilter = v)),
              _buildFilterChip('فواتير المعمل', 'workshop', _invoiceFilter, (v) => setState(() => _invoiceFilter = v)),
              _buildFilterChip('المردودات', 'returns', _invoiceFilter, (v) => setState(() => _invoiceFilter = v)),
            ],
            resultCount: totalCount,
          ),
          const SizedBox(height: 16),

          // List View
          Expanded(
            child: totalCount == 0
                ? _buildNoResultsPlaceholder()
                : ListView(
                    children: [
                      if (factoryInvoices.isNotEmpty) ...[
                        _buildSectionHeader('فواتير المصنع المؤرشفة (${factoryInvoices.length})', Icons.factory_rounded),
                        ...factoryInvoices.map((inv) => _buildFactoryInvoiceCard(inv)),
                        const SizedBox(height: 16),
                      ],
                      if (workshopInvoices.isNotEmpty) ...[
                        _buildSectionHeader('فواتير المعمل المؤرشفة (${workshopInvoices.length})', Icons.storefront_rounded),
                        ...workshopInvoices.map((inv) => _buildWorkshopInvoiceCard(inv)),
                        const SizedBox(height: 16),
                      ],
                      if (returnInvoices.isNotEmpty) ...[
                        _buildSectionHeader('مرتجع ومسوحات الفواتير (${returnInvoices.length})', Icons.assignment_return_rounded),
                        ...returnInvoices.map((ret) => _buildReturnInvoiceCard(ret)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryInvoiceCard(FactoryInvoiceModel inv) {
    return _buildArchiveItemContainer(
      leadingIcon: Icons.receipt_long_rounded,
      leadingColor: const Color(0xFF0284C7),
      title: 'فاتورة مصنع رقم #${inv.invoiceNo} • ${inv.partyName}',
      subtitle: 'النوع: ${inv.invoiceType} | التاريخ: ${_formatDate(inv.date)} | الأصناف: ${inv.items.length}',
      trailingAmount: '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
      trailingLabel: inv.paymentStatus,
      trailingColor: inv.paymentStatus == 'مدفوعة' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
      onTap: () => _showFactoryInvoiceDetails(inv),
    );
  }

  Widget _buildWorkshopInvoiceCard(WorkshopInvoiceModel inv) {
    return _buildArchiveItemContainer(
      leadingIcon: Icons.point_of_sale_rounded,
      leadingColor: const Color(0xFF0D9488),
      title: 'فاتورة معمل رقم #${inv.invoiceNo} • ${inv.clientName}',
      subtitle: 'التاريخ: ${_formatDate(inv.date)} | بنود الفاتورة: ${inv.items.length}',
      trailingAmount: '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
      trailingLabel: inv.isDue ? 'متبقي: ${inv.remainingBalance.fmt}' : 'مسددة بالكامل',
      trailingColor: inv.isDue ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      onTap: () => _showWorkshopInvoiceDetails(inv),
    );
  }

  Widget _buildReturnInvoiceCard(ReturnInvoiceModel ret) {
    return _buildArchiveItemContainer(
      leadingIcon: Icons.assignment_return_rounded,
      leadingColor: const Color(0xFFDC2626),
      title: 'سند إرجاع #${ret.returnNo} للفاتورة الأصلية #${ret.parentInvoiceNo}',
      subtitle: 'الطرف: ${ret.partyName} | النوع: ${ret.returnType} | التاريخ: ${_formatDate(ret.date)}',
      trailingAmount: '-${ret.refundAmount.fmt} ${AppCurrency.symbol(ret.currency)}',
      trailingLabel: ret.paymentAction,
      trailingColor: const Color(0xFF64748B),
      onTap: () => _showReturnDetails(ret),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: EXPENSES & COSTS TAB (المصروفات والتكاليف)
  // -------------------------------------------------------------
  Widget _buildExpensesTab(PeriodArchiveModel archive) {
    final query = _expenseSearchCtrl.text.trim().toLowerCase();

    final expenses = archive.expenseRecords.where((e) {
      if (_expenseFilter != 'all' && _expenseFilter != 'operating') return false;
      if (query.isEmpty) return true;
      return e.description.toLowerCase().contains(query) ||
          e.personName.toLowerCase().contains(query) ||
          e.typeId.toLowerCase().contains(query);
    }).toList();

    final surplus = archive.surplusCosts.where((s) {
      if (_expenseFilter != 'all' && _expenseFilter != 'surplus') return false;
      if (query.isEmpty) return true;
      return s.surplusDescription.toLowerCase().contains(query) ||
          s.beneficiaryName.toLowerCase().contains(query);
    }).toList();

    final assetSales = archive.assetSaleRecords.where((a) {
      if (_expenseFilter != 'all' && _expenseFilter != 'asset_sales') return false;
      if (query.isEmpty) return true;
      return a.assetName.toLowerCase().contains(query) ||
          a.description.toLowerCase().contains(query);
    }).toList();

    final totalCount = expenses.length + surplus.length + assetSales.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSearchAndFiltersRow(
            controller: _expenseSearchCtrl,
            hint: 'بحث باسم المصروف، البند، المستلم، أو التكلفة...',
            onChanged: () => setState(() {}),
            filters: [
              _buildFilterChip('الكل', 'all', _expenseFilter, (v) => setState(() => _expenseFilter = v)),
              _buildFilterChip('مصاريف تشغيلية', 'operating', _expenseFilter, (v) => setState(() => _expenseFilter = v)),
              _buildFilterChip('تكاليف زيادات', 'surplus', _expenseFilter, (v) => setState(() => _expenseFilter = v)),
              _buildFilterChip('مبيعات أصول', 'asset_sales', _expenseFilter, (v) => setState(() => _expenseFilter = v)),
            ],
            resultCount: totalCount,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: totalCount == 0
                ? _buildNoResultsPlaceholder()
                : ListView(
                    children: [
                      if (expenses.isNotEmpty) ...[
                        _buildSectionHeader('المصروفات التشغيلية المؤرشفة (${expenses.length})', Icons.request_quote_rounded),
                        ...expenses.map((exp) => _buildArchiveItemContainer(
                              leadingIcon: Icons.receipt_rounded,
                              leadingColor: const Color(0xFFEF4444),
                              title: exp.description.isNotEmpty ? exp.description : 'سجل مصروف تشغيلي',
                              subtitle: 'الطرف: ${exp.personName.isNotEmpty ? exp.personName : "-"} | الصندوق: ${exp.cashBox} | التاريخ: ${_formatDate(exp.date)}',
                              trailingAmount: '${exp.amount.fmt} ${AppCurrency.symbol(exp.currency)}',
                              trailingLabel: 'سداد نقدي',
                              trailingColor: const Color(0xFF64748B),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (surplus.isNotEmpty) ...[
                        _buildSectionHeader('تكاليف صندوق الزيادات (${surplus.length})', Icons.inventory_2_rounded),
                        ...surplus.map((s) => _buildArchiveItemContainer(
                              leadingIcon: Icons.add_circle_outline_rounded,
                              leadingColor: const Color(0xFFF59E0B),
                              title: s.surplusDescription,
                              subtitle: 'المستفيد: ${s.beneficiaryName} | التاريخ: ${_formatDate(s.date)}',
                              trailingAmount: '${s.amountDue.fmt} ${AppCurrency.symbol(s.currency)}',
                              trailingLabel: s.isPaid ? 'مسددة' : 'متبقية',
                              trailingColor: s.isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (assetSales.isNotEmpty) ...[
                        _buildSectionHeader('سجلات مبيعات الأصول (${assetSales.length})', Icons.sell_rounded),
                        ...assetSales.map((a) => _buildArchiveItemContainer(
                              leadingIcon: Icons.apartment_rounded,
                              leadingColor: const Color(0xFF10B981),
                              title: 'بيع أصل: ${a.assetName}',
                              subtitle: 'التصنيف: ${a.category} | التاريخ: ${_formatDate(a.saleDate)}',
                              trailingAmount: '${a.salePrice.fmt} ${AppCurrency.symbol(a.currency)}',
                              trailingLabel: a.isGain ? 'ربح بيع أصل (+${a.gain.fmt})' : 'بيع أصل',
                              trailingColor: a.isGain ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: REVENUES & PROFITS SUMMARY (ملخص الإيرادات والأرباح)
  // -------------------------------------------------------------
  Widget _buildRevenuesProfitTab(PeriodArchiveModel archive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('ملخص الأداء المالي والأرباح للفترة المؤرشفة', Icons.assessment_rounded),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenues Card
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'إجمالي الإيرادات المؤرشفة',
                  usdAmount: archive.totalRevenuesUsd,
                  sypAmount: archive.totalRevenuesSyp,
                  accentColor: const Color(0xFF0D9488),
                  icon: Icons.trending_up_rounded,
                  breakdownRows: [
                    'فواتير المصنع: ${archive.factoryInvoices.length} فاتورة',
                    'فواتير المعمل: ${archive.workshopInvoices.length} فاتورة',
                    'مرتجع ومسوحات: ${archive.returnInvoices.length} معاملة',
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Expenses Card
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'إجمالي المصروفات والتكاليف',
                  usdAmount: archive.totalExpensesUsd,
                  sypAmount: archive.totalExpensesSyp,
                  accentColor: const Color(0xFFDC2626),
                  icon: Icons.receipt_long_rounded,
                  breakdownRows: [
                    'مصاريف تشغيلية: ${archive.expenseRecords.length} سجل',
                    'تكاليف زيادات: ${archive.surplusCosts.length} بند',
                    'أجور العمال: ${archive.workdayEntries.length} يومية عمل',
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Net Profit Card
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'صافي الربح المرحل (الأرباح المدورة)',
                  usdAmount: archive.netProfitUsd,
                  sypAmount: archive.netProfitSyp,
                  accentColor: const Color(0xFF16A34A),
                  icon: Icons.monetization_on_rounded,
                  breakdownRows: [
                    'رأس المال والمدور: ${archive.totalEquityUsd.fmt} \$',
                    'الصندوق الرئيسي: ${archive.mainCashUsd.fmt} \$ | ${archive.mainCashSyp.fmt} ل.س',
                    'صندوق الزيادات: ${archive.scrapCashUsd.fmt} \$ | ${archive.scrapCashSyp.fmt} ل.س',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Partner Equity Distribution Snapshot in Archive
          _buildSectionHeader('توزيع حقوق الشركاء والأرباح المدورة عند الأرشفة', Icons.groups_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('اسم الشريك', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('نسبة الملكية %', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الحصة من رأس المال والمدور (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                _buildPartnerDataRow('حسن', archive.rolledOpeningEntry.hassanRatio, archive.rolledOpeningEntry.hassanCapital),
                _buildPartnerDataRow('عدنان', archive.rolledOpeningEntry.adnanRatio, archive.rolledOpeningEntry.adnanCapital),
                _buildPartnerDataRow('عبد المعين', archive.rolledOpeningEntry.abdelMoeenRatio, archive.rolledOpeningEntry.abdelMoeenCapital),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildPartnerDataRow(String name, double ratio, double capital) {
    return DataRow(cells: [
      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text('${(ratio * 100).toStringAsFixed(1)}%')),
      DataCell(Text('${capital.fmt} \$', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488)))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('مرحل للقيد الافتتاحي', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
      )),
    ]);
  }

  Widget _buildFinancialSummaryCard({
    required String title,
    required double usdAmount,
    required double sypAmount,
    required Color accentColor,
    required IconData icon,
    required List<String> breakdownRows,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${usdAmount.fmt} \$',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor),
          ),
          Text(
            '${sypAmount.fmt} ل.س',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const Divider(height: 24),
          ...breakdownRows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        row,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: WORKFORCE TAB (شؤون العمال والدوام)
  // -------------------------------------------------------------
  Widget _buildWorkforceTab(PeriodArchiveModel archive) {
    final query = _workforceSearchCtrl.text.trim().toLowerCase();

    final workdays = archive.workdayEntries.where((w) {
      if (_workforceFilter != 'all' && _workforceFilter != 'workdays') return false;
      if (query.isEmpty) return true;
      return w.staffNames.any((n) => n.toLowerCase().contains(query)) ||
          w.workDescription.toLowerCase().contains(query);
    }).toList();

    final attendance = archive.staffAttendance.where((a) {
      if (_workforceFilter != 'all' && _workforceFilter != 'attendance') return false;
      if (query.isEmpty) return true;
      return a.staffId.toLowerCase().contains(query);
    }).toList();

    final advances = archive.advanceRepayments.where((r) {
      if (_workforceFilter != 'all' && _workforceFilter != 'advances') return false;
      if (query.isEmpty) return true;
      return r.staffName.toLowerCase().contains(query);
    }).toList();

    final totalCount = workdays.length + attendance.length + advances.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSearchAndFiltersRow(
            controller: _workforceSearchCtrl,
            hint: 'بحث باسم العامل أو الموظف في الأرشيف...',
            onChanged: () => setState(() {}),
            filters: [
              _buildFilterChip('الكل', 'all', _workforceFilter, (v) => setState(() => _workforceFilter = v)),
              _buildFilterChip('يوميات العمل', 'workdays', _workforceFilter, (v) => setState(() => _workforceFilter = v)),
              _buildFilterChip('حضور الموظفين', 'attendance', _workforceFilter, (v) => setState(() => _workforceFilter = v)),
              _buildFilterChip('سدادات السلف', 'advances', _workforceFilter, (v) => setState(() => _workforceFilter = v)),
            ],
            resultCount: totalCount,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: totalCount == 0
                ? _buildNoResultsPlaceholder()
                : ListView(
                    children: [
                      if (workdays.isNotEmpty) ...[
                        _buildSectionHeader('يوميات أجور العمال المؤرشفة (${workdays.length})', Icons.badge_rounded),
                        ...workdays.map((w) => _buildArchiveItemContainer(
                              leadingIcon: Icons.person_rounded,
                              leadingColor: const Color(0xFF6366F1),
                              title: 'يومية: ${w.staffNames.join("، ")}',
                              subtitle: 'التاريخ: ${_formatDate(w.date)} | الوصف: ${w.workDescription} | النوع: ${w.rateType}',
                              trailingAmount: '${w.grandTotal.fmt} ${AppCurrency.symbol(w.currency)}',
                              trailingLabel: 'أجور مستحقة/مسددة',
                              trailingColor: const Color(0xFF16A34A),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (attendance.isNotEmpty) ...[
                        _buildSectionHeader('سجلات حضور الكادر (${attendance.length})', Icons.event_available_rounded),
                        ...attendance.map((att) => _buildArchiveItemContainer(
                              leadingIcon: Icons.how_to_reg_rounded,
                              leadingColor: const Color(0xFF0D9488),
                              title: 'تسجيل حضور عامل / موظف: ${att.staffId}',
                              subtitle: 'التاريخ: ${_formatDate(att.date)} | اليومية المعتمدة: ${att.dailyRate.fmt} ${AppCurrency.symbol(att.currency)}',
                              trailingAmount: '${att.dailyRate.fmt} ${AppCurrency.symbol(att.currency)}',
                              trailingLabel: 'حضور مسجل',
                              trailingColor: const Color(0xFF16A34A),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (advances.isNotEmpty) ...[
                        _buildSectionHeader('سجلات سداد السلف (${advances.length})', Icons.price_check_rounded),
                        ...advances.map((adv) => _buildArchiveItemContainer(
                              leadingIcon: Icons.account_balance_wallet_rounded,
                              leadingColor: const Color(0xFF0284C7),
                              title: 'سداد سلفة: ${adv.staffName}',
                              subtitle: 'التاريخ: ${_formatDate(adv.date)} | الملاحظات: ${adv.note.isNotEmpty ? adv.note : "-"}',
                              trailingAmount: '${adv.collectedAmount.fmt} ${AppCurrency.symbol(adv.collectedCurrency)}',
                              trailingLabel: 'سداد سلفة',
                              trailingColor: const Color(0xFF64748B),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 5: ORDERS & DAILY REPORTS (الطلبيات والتقارير اليومية)
  // -------------------------------------------------------------
  Widget _buildOrdersReportsTab(PeriodArchiveModel archive) {
    final query = _ordersReportsSearchCtrl.text.trim().toLowerCase();

    final factoryOrders = archive.factoryOrders.where((o) {
      if (_ordersFilter != 'all' && _ordersFilter != 'factory') return false;
      if (query.isEmpty) return true;
      return o.orderNo.toLowerCase().contains(query) ||
          o.clientName.toLowerCase().contains(query);
    }).toList();

    final workshopOrders = archive.workshopOrders.where((o) {
      if (_ordersFilter != 'all' && _ordersFilter != 'workshop') return false;
      if (query.isEmpty) return true;
      return o.orderNo.toLowerCase().contains(query) ||
          o.clientName.toLowerCase().contains(query);
    }).toList();

    final reports = archive.dailyReports.where((r) {
      if (_ordersFilter != 'all' && _ordersFilter != 'reports') return false;
      if (query.isEmpty) return true;
      return r.reportNo.toLowerCase().contains(query) ||
          r.notes.toLowerCase().contains(query);
    }).toList();

    final totalCount = factoryOrders.length + workshopOrders.length + reports.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSearchAndFiltersRow(
            controller: _ordersReportsSearchCtrl,
            hint: 'بحث برقم الطلبية، اسم العميل، المشرف، أو ملاحظات التقرير...',
            onChanged: () => setState(() {}),
            filters: [
              _buildFilterChip('الكل', 'all', _ordersFilter, (v) => setState(() => _ordersFilter = v)),
              _buildFilterChip('طلبيات المصنع', 'factory', _ordersFilter, (v) => setState(() => _ordersFilter = v)),
              _buildFilterChip('طلبيات المعمل', 'workshop', _ordersFilter, (v) => setState(() => _ordersFilter = v)),
              _buildFilterChip('التقارير اليومية', 'reports', _ordersFilter, (v) => setState(() => _ordersFilter = v)),
            ],
            resultCount: totalCount,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: totalCount == 0
                ? _buildNoResultsPlaceholder()
                : ListView(
                    children: [
                      if (factoryOrders.isNotEmpty) ...[
                        _buildSectionHeader('طلبيات المصنع المؤرشفة (${factoryOrders.length})', Icons.factory_rounded),
                        ...factoryOrders.map((o) => _buildArchiveItemContainer(
                              leadingIcon: Icons.assignment_turned_in_rounded,
                              leadingColor: const Color(0xFF0284C7),
                              title: 'طلبية مصنع #${o.orderNo} • ${o.clientName}',
                              subtitle: 'التاريخ: ${_formatDate(o.date)} | العربون: ${o.depositAmount.fmt} ${AppCurrency.symbol(o.currency)}',
                              trailingAmount: '${o.agreedPrice.fmt} ${AppCurrency.symbol(o.currency)}',
                              trailingLabel: o.status,
                              trailingColor: const Color(0xFF16A34A),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (workshopOrders.isNotEmpty) ...[
                        _buildSectionHeader('طلبيات المعمل المؤرشفة (${workshopOrders.length})', Icons.storefront_rounded),
                        ...workshopOrders.map((o) => _buildArchiveItemContainer(
                              leadingIcon: Icons.shopping_bag_rounded,
                              leadingColor: const Color(0xFF0D9488),
                              title: 'طلبية معمل #${o.orderNo} • ${o.clientName}',
                              subtitle: 'التاريخ: ${_formatDate(o.date)} | الهاتف: ${o.clientPhone}',
                              trailingAmount: '${o.agreedPrice.fmt} ${AppCurrency.symbol(o.currency)}',
                              trailingLabel: o.status,
                              trailingColor: const Color(0xFF16A34A),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (reports.isNotEmpty) ...[
                        _buildSectionHeader('التقارير اليومية المؤرشفة (${reports.length})', Icons.analytics_rounded),
                        ...reports.map((r) => _buildArchiveItemContainer(
                              leadingIcon: Icons.menu_book_rounded,
                              leadingColor: const Color(0xFF7C3AED),
                              title: 'تقرير يومي #${r.reportNo}',
                              subtitle: 'التاريخ: ${_formatDate(r.reportDate)} | المصاريف: ${r.totalExpensesUsd.fmt} \$ | الملاحظات: ${r.notes}',
                              trailingAmount: '${r.totalSalesUsd.fmt} \$',
                              trailingLabel: 'مبيعات اليوم',
                              trailingColor: const Color(0xFF0D9488),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 6: ROLLED OPENING ENTRY TAB (القيد الافتتاحي الناتج)
  // -------------------------------------------------------------
  Widget _buildRolledOpeningEntryTab(PeriodArchiveModel archive) {
    final entry = archive.rolledOpeningEntry;
    final assetsTotal = entry.totalAssets;
    final liabilitiesTotal = entry.totalLiabilities;
    final equityTotal = entry.totalEquity;
    final isBalanced = (assetsTotal - (liabilitiesTotal + equityTotal)).abs() < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader('القيد الافتتاحي الناتج للفترة الجديدة (ميزان مراجعة متزن)', Icons.account_tree_rounded),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isBalanced ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isBalanced ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBalanced ? Icons.verified_rounded : Icons.warning_rounded,
                      size: 16,
                      color: isBalanced ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBalanced ? 'الميزان متزن محاسبياً 100%' : 'تنبيه: عدم توازن في الميزان',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isBalanced ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Side-by-side: Assets vs Liabilities & Equity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DEBIT SIDE (ASSETS)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488), size: 20),
                          const SizedBox(width: 8),
                          const Text('الجانب المدين (الأصول والموجودات والذمم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${assetsTotal.fmt} \$', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488), fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildBalanceRow('الصندوق الرئيسي المرحل', '${entry.mainCashValue.fmt} \$'),
                      _buildBalanceRow('صندوق الزيادات المرحل', '${entry.scrapCashValue.fmt} \$'),
                      _buildBalanceRow('صندوق الطلبيات المرحل', '${entry.orderCashValue.fmt} \$'),
                      _buildBalanceRow('الأصول الثابتة النشطة (${entry.fixedAssets.length} أصل)', '${entry.totalFixedAssets.fmt} \$'),
                      _buildBalanceRow('بضاعة أول المدة (المخزون المرحل)', '${entry.inventoryValue.fmt} \$'),
                      _buildBalanceRow('ذمم الزبائن والعملاء المدورة', '${entry.customerDebtsValue.fmt} \$'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // CREDIT SIDE (LIABILITIES & EQUITY)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.outbox_rounded, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 8),
                          const Text('الجانب الدائن (الخصوم وحقوق الملكية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${(liabilitiesTotal + equityTotal).fmt} \$', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildBalanceRow('مستحقات الموردين المدورة', '${entry.supplierPayablesValue.fmt} \$'),
                      _buildBalanceRow('مستحقات أجور العمال المدورة', '${entry.workerSalariesValue.fmt} \$'),
                      _buildBalanceRow('إجمالي الخصوم والالتزامات', '${liabilitiesTotal.fmt} \$', isBold: true),
                      const SizedBox(height: 8),
                      _buildBalanceRow('صافي حقوق الملكية ورأس المال المدور', '${equityTotal.fmt} \$', isBold: true, highlightColor: const Color(0xFF16A34A)),
                      const SizedBox(height: 6),
                      Text(
                        'تم توزيع حقوق الملكية على الشركاء بنسبهم المحددة بنجاح.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Historical Rolled Debts Breakdown (الذمم والمستحقات المدورة)
          _buildSectionHeader('الذمم والمستحقات المدورة كأرصدة افتتاحية (${entry.legacyFinancials.length})', Icons.history_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: entry.legacyFinancials.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('لا توجد ذمم أو مستحقات مدورة في هذا القيد الافتتاحي.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  )
                : DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('اسم الطرف', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('التصنيف', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('المبلغ المدور', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('العملة', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ملاحظات القيد', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: entry.legacyFinancials.map((rec) {
                      final isClient = rec.category == 'clients';
                      return DataRow(cells: [
                        DataCell(Text(rec.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isClient ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isClient ? 'مدين (لنا / زبون)' : (rec.category == 'suppliers' ? 'دائن (علينا / مورد)' : 'دائن (علينا / عامل)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isClient ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                            ),
                          ),
                        )),
                        DataCell(Text('${rec.amount.fmt} ${AppCurrency.symbol(rec.currency)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(rec.currency)),
                        DataCell(Text(rec.description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                      ]);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HELPER WIDGETS & MODALS
  // -------------------------------------------------------------
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFiltersRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onChanged,
    required List<Widget> filters,
    required int resultCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD97706)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Filter Chips
          Wrap(
            spacing: 8,
            children: filters,
          ),
          const SizedBox(width: 14),

          // Result Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$resultCount نتيجة',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedValue == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFD97706),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
        color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _buildArchiveItemContainer({
    required IconData leadingIcon,
    required Color leadingColor,
    required String title,
    required String subtitle,
    required String trailingAmount,
    required String trailingLabel,
    required Color trailingColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: leadingColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(leadingIcon, size: 20, color: leadingColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailingAmount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trailingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: trailingColor,
                      ),
                    ),
                  ],
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF94A3B8)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لم يتم العثور على أي نتائج مطابقة للبحث أو الفلتر في هذا الأرشيف',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // READ-ONLY ITEM DETAILS MODALS
  // -------------------------------------------------------------
  void _showFactoryInvoiceDetails(FactoryInvoiceModel inv) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('تفاصيل فاتورة مصنع #${inv.invoiceNo} (أرشيف قراءة فقط)'),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModalRow('الطرف / العميل:', inv.partyName),
                  _buildModalRow('نوع الفاتورة:', inv.invoiceType),
                  _buildModalRow('التاريخ:', _formatDate(inv.date)),
                  _buildModalRow('إجمالي الفاتورة:', '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  _buildModalRow('المدفوع سلفاً:', '${inv.advancePayment.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  _buildModalRow('حالة السداد:', inv.paymentStatus),
                  const Divider(height: 24),
                  const Text('الأصناف والبنود المدرجة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...inv.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${it.description} (${it.quantity.fmt} ${it.meterUnit})'),
                            Text('${it.totalPrice.fmt} ${AppCurrency.symbol(inv.currency)}'),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkshopInvoiceDetails(WorkshopInvoiceModel inv) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('تفاصيل فاتورة معمل #${inv.invoiceNo} (أرشيف قراءة فقط)'),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModalRow('اسم الزبون:', inv.clientName),
                  _buildModalRow('التاريخ:', _formatDate(inv.date)),
                  _buildModalRow('الإجمالي النهائي:', '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  _buildModalRow('العربون المخصوم:', '${inv.depositDeducted.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  _buildModalRow('المدفوع نقداً:', '${inv.cashPaidNow.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  _buildModalRow('المتبقي:', '${inv.remainingBalance.fmt} ${AppCurrency.symbol(inv.currency)}'),
                  const Divider(height: 24),
                  const Text('بنود الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...inv.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${it.description} (${it.quantity.fmt} ${it.unitCategory})'),
                            Text('${it.agreedPrice.fmt} ${AppCurrency.symbol(inv.currency)}'),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnDetails(ReturnInvoiceModel ret) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('سند إرجاع #${ret.returnNo} (أرشيف قراءة فقط)'),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalRow('الفاتورة الأصلية:', '#${ret.parentInvoiceNo}'),
                _buildModalRow('الطرف:', ret.partyName),
                _buildModalRow('النوع:', ret.returnType),
                _buildModalRow('التاريخ:', _formatDate(ret.date)),
                _buildModalRow('قيمة المردود:', '${ret.refundAmount.fmt} ${AppCurrency.symbol(ret.currency)}'),
                if (ret.cashAmount != null)
                  _buildModalRow('المبلغ المسترد نقداً:', '${ret.cashAmount!.fmt} ${AppCurrency.symbol(ret.currency)}'),
                _buildModalRow('إجراء السداد:', ret.paymentAction),
                if (ret.itemDescription.isNotEmpty) _buildModalRow('الوصف:', ret.itemDescription),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  void _openArchiveModal(BuildContext context, ERPProvider erp) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ArchiveAndClosePeriodModal(),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
