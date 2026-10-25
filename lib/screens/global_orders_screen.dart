import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/a4_invoice_print_dialog.dart';
import '../widgets/factory_order_dialogs.dart';
import '../widgets/return_allowance_dialog.dart';

class GlobalOrdersScreen extends StatefulWidget {
  const GlobalOrdersScreen({super.key});

  @override
  State<GlobalOrdersScreen> createState() => _GlobalOrdersScreenState();
}

class _GlobalOrdersScreenState extends State<GlobalOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _ordersReturnsTabController;
  int _selectedOrdersScope = 0; // 0: Factory Orders, 1: Workshop Orders
  String _foFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _ordersReturnsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _ordersReturnsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.panelSurface,
            child: TabBar(
              controller: _ordersReturnsTabController,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.brandSecondaryText,
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  text:
                      '1. الشاشة الشاملة لإدارة الطلبيات (Global Orders Management)',
                ),
                Tab(text: '2. محرك فواتير المرتجع (Returns Engine)'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _ordersReturnsTabController,
              children: [
                _buildGlobalOrdersTab(erp),
                _buildReturnsEngineTab(erp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _foSearch = '';

  // -------------------------------------------------------------
  // TAB 1: GLOBAL ORDERS MANAGEMENT
  // -------------------------------------------------------------
  Widget _buildGlobalOrdersTab(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.orderDepositBoxAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'سجل الطلبيات الشامل وتتبع العربونات والصناديق المعزولة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'إدارة متكاملة لطلبيات المصنع والمعمل مع تتبع العربونات المعزولة وأوامر التشغيل للورشة',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brandSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.savings_rounded,
                      size: 20,
                      color: AppColors.orderDepositBoxAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'صندوق العربونات المعزول: ${erp.dualOrderCash}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.orderDepositBoxAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scope Switcher (Factory Orders vs Workshop Orders)
          Row(
            children: [
              _buildScopeTabButton(
                title: 'طلبيات المصنع (Factory Orders)',
                count: erp.factoryOrders.length,
                icon: Icons.precision_manufacturing_rounded,
                isSelected: _selectedOrdersScope == 0,
                onTap: () => setState(() => _selectedOrdersScope = 0),
              ),
              const SizedBox(width: 12),
              _buildScopeTabButton(
                title: 'طلبيات المعمل (Workshop Orders)',
                count: erp.workshopOrders.length,
                icon: Icons.handyman_rounded,
                isSelected: _selectedOrdersScope == 1,
                onTap: () => setState(() => _selectedOrdersScope = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scope Body
          Expanded(
            child: _selectedOrdersScope == 0
                ? _buildFactoryOrdersView(erp)
                : _buildWorkshopOrdersView(erp),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTabButton({
    required String title,
    required int count,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orderDepositBoxAccent
              : AppColors.panelSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.orderDepositBoxAccent
                : AppColors.panelBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.brandSecondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isSelected ? Colors.white : AppColors.brandPrimaryText,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.panelBorder,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.brandPrimaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // FACTORY ORDERS SUB-VIEW
  // -------------------------------------------------------------
  Widget _buildFactoryOrdersView(ERPProvider erp) {
    final allOrders = erp.factoryOrders;
    final inProgress = allOrders.where((o) => o.status == 'قيد التنفيذ').toList();
    final completed = allOrders.where((o) => o.status == 'مكتملة ومرحلة').toList();
    final cancelled = allOrders.where((o) => o.status.startsWith('ملغاة')).toList();

    List<FactoryOrderModel> filtered = allOrders;
    if (_foFilter == 'قيد التنفيذ') {
      filtered = inProgress;
    } else if (_foFilter == 'مكتملة ومرحلة') {
      filtered = completed;
    } else if (_foFilter == 'ملغاة') {
      filtered = cancelled;
    }

    if (_foSearch.isNotEmpty) {
      final q = _foSearch.toLowerCase();
      filtered = filtered.where((o) {
        return o.orderNo.toLowerCase().contains(q) ||
            o.clientName.toLowerCase().contains(q) ||
            o.clientPhone.contains(q) ||
            o.items.any((it) => it.description.toLowerCase().contains(q));
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Bar: Add Order Button + Search + Filters
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orderDepositBoxAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => showAddFactoryOrderDialog(context, erp),
              icon: const Icon(Icons.post_add_rounded),
              label: const Text(
                'إضافة طلبية مصنع جديدة +',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث برقم الطلبية أو اسم الزبون أو الهاتف أو الصنف...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.panelBorder),
                  ),
                ),
                onChanged: (v) => setState(() => _foSearch = v.trim()),
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 6,
              children: ['الكل', 'قيد التنفيذ', 'مكتملة ومرحلة', 'ملغاة']
                  .map((status) => ChoiceChip(
                        label: Text(status),
                        selected: _foFilter == status,
                        onSelected: (sel) {
                          if (sel) setState(() => _foFilter = status);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Statistics Metric Cards
        Row(
          children: [
            Expanded(
              child: _buildOrderStatCard(
                title: 'إجمالي طلبيات المصنع',
                value: '${allOrders.length}',
                icon: Icons.list_alt_rounded,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOrderStatCard(
                title: 'قيد التنفيذ (معلقة)',
                value: '${inProgress.length}',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOrderStatCard(
                title: 'مكتملة ومرحلة',
                value: '${completed.length}',
                icon: Icons.check_circle_rounded,
                color: AppColors.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOrderStatCard(
                title: 'ملغاة',
                value: '${cancelled.length}',
                icon: Icons.cancel_rounded,
                color: AppColors.dangerWaste,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Orders List
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.panelBorder),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'لا توجد طلبيات تطابق الفلتر الحالي.',
                          style: TextStyle(
                            color: AppColors.brandSecondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final ord = filtered[idx];
                      final isInProgress = ord.status == 'قيد التنفيذ';
                      final isOrdCompleted = ord.status == 'مكتملة ومرحلة';
                      final isCancelled = ord.status.startsWith('ملغاة');

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isInProgress
                                ? AppColors.orderDepositBoxAccent.withValues(alpha: 0.3)
                                : isOrdCompleted
                                    ? AppColors.successGreen.withValues(alpha: 0.3)
                                    : AppColors.dangerWaste.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Order Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: (isInProgress
                                        ? AppColors.orderDepositBoxAccent
                                        : isOrdCompleted
                                            ? AppColors.successGreen
                                            : AppColors.dangerWaste)
                                    .withValues(alpha: 0.06),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(9),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: (isInProgress
                                            ? AppColors.orderDepositBoxAccent
                                            : isOrdCompleted
                                                ? AppColors.successGreen
                                                : AppColors.dangerWaste)
                                        .withValues(alpha: 0.2),
                                    child: Icon(
                                      isInProgress
                                          ? Icons.hourglass_top_rounded
                                          : isOrdCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                      size: 16,
                                      color: isInProgress
                                          ? AppColors.orderDepositBoxAccent
                                          : isOrdCompleted
                                              ? AppColors.successGreen
                                              : AppColors.dangerWaste,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    ord.orderNo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'الزبون: ${ord.clientName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.brandPrimaryText,
                                    ),
                                  ),
                                  if (ord.clientPhone.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${ord.clientPhone})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isInProgress
                                          ? const Color(0xFFFEF3C7)
                                          : isOrdCompleted
                                              ? AppColors.chipBgGreen
                                              : AppColors.chipBgRed,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ord.status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: isInProgress
                                            ? const Color(0xFFB45309)
                                            : isOrdCompleted
                                                ? AppColors.successGreen
                                                : AppColors.dangerWaste,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Items Breakdown
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(ord.date)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'أصناف الطلبية (${ord.items.length}):',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Line Items Table
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.panelBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        ...ord.items.asMap().entries.map((entry) {
                                          final it = entry.value;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: entry.key.isEven
                                                  ? Colors.grey.shade50
                                                  : Colors.white,
                                              border: entry.key < ord.items.length - 1
                                                  ? const Border(
                                                      bottom: BorderSide(
                                                        color: AppColors.panelBorder,
                                                        width: 0.5,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 9,
                                                  backgroundColor: AppColors.accentPrimary
                                                      .withValues(alpha: 0.15),
                                                  child: Text(
                                                    '${entry.key + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.accentPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    it.description,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    (it.lengthCm > 0 && it.widthCm > 0)
                                                        ? '${it.lengthCm.fmt} × ${it.widthCm.fmt}${it.heightCm > 5 ? " × ${it.heightCm.fmt}" : ""} سم'
                                                        : '—',
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${it.calculatedArea.fmt} ${it.heightCm > 5 ? "م³" : "م²"} (${it.quantity.fmt} قطع)',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${it.unitPrice.fmt}\$ / م',
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                                ),
                                                Text(
                                                  '${it.subtotal.fmt}\$',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),

                                  // Services if any
                                  if (ord.services.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: ord.services.map((srv) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDE9FE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '🔧 ${srv.serviceName}: ${srv.price.fmt}\$',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6D28D9),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],

                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // Financial Totals Bar + Action Buttons
                                  Row(
                                    children: [
                                      // Meters
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFBBF7D0),
                                          ),
                                        ),
                                        child: Text(
                                          'إجمالي الأمتار: ${ord.totalArea.fmt} م²/م³',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Grand Total
                                      Text(
                                        'الإجمالي: ${ord.agreedPrice.fmt}\$',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Deposit Box Highlight
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.orderDepositBoxAccent
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.orderDepositBoxAccent
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.lock_clock_rounded,
                                              size: 15,
                                              color: AppColors.orderDepositBoxAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'العربون في الصندوق المعزول: ${ord.depositAmount.fmt}\$',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: AppColors.orderDepositBoxAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Remaining
                                      Text(
                                        'المتبقي: ${ord.remainingBalance.fmt}\$',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),

                                      // Assigned Invoice Info
                                      if (ord.assignedInvoiceNo != null) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.chipBgGreen,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'مرحلة لفاتورة: ${ord.assignedInvoiceNo}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: AppColors.successGreen,
                                            ),
                                          ),
                                        ),
                                      ],

                                      const Spacer(),

                                      // Print Button (معاينة للطباعة)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        onPressed: () {
                                          A4InvoicePrintDialog.show(
                                            context,
                                            invoiceData:
                                                A4InvoiceData.fromFactoryOrder(ord),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.print_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'معاينة للطباعة (أمر تشغيل)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),

                                      // Cancel Order Button (إلغاء الطلب)
                                      if (isInProgress) ...[
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.dangerWaste,
                                            side: const BorderSide(
                                              color: AppColors.dangerWaste,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          onPressed: () =>
                                              showCancelFactoryOrderDialog(
                                            context,
                                            erp,
                                            ord,
                                          ),
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'إلغاء الطلب',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // WORKSHOP ORDERS SUB-VIEW
  // -------------------------------------------------------------
  Widget _buildWorkshopOrdersView(ERPProvider erp) {
    if (erp.workshopOrders.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text(
                'لا توجد طلبيات معمل مسجلة حالياً.',
                style: TextStyle(
                  color: AppColors.brandSecondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.panelBorder),
      ),
      child: ListView.separated(
        itemCount: erp.workshopOrders.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final ord = erp.workshopOrders[idx];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppColors.orderDepositBoxAccent.withValues(alpha: 0.1),
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: AppColors.orderDepositBoxAccent,
              ),
            ),
            title: Text(
              '${ord.orderNo} • الزبون: ${ord.clientName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الطلب: ${ord.customDimensionsText} • الهاتف: ${ord.clientPhone} • التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(ord.date)}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'السعر: ${ord.agreedPrice}${ord.currencySymbol}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'العربون المعزول: ${ord.depositAmount}${ord.currencySymbol}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.orderDepositBoxAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: RETURNS ENGINE (3 SECTIONS)
  // -------------------------------------------------------------
  Widget _buildReturnsEngineTab(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل ومحرك فواتير المرتجع (Returns Engine)',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerWaste,
                ),
                onPressed: () => _showAddReturnInvoiceDialog(erp),
                icon: const Icon(Icons.assignment_return_rounded),
                label: const Text('إصدار فاتورة مرتجع جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: erp.returnInvoices.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final ret = erp.returnInvoices[idx];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.chipBgRed,
                      child: Icon(
                        Icons.replay_rounded,
                        color: AppColors.dangerWaste,
                      ),
                    ),
                    title: Text(
                      '${ret.returnNo} • ${ret.returnType}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الطرف: ${ret.partyName} • الصنف: ${ret.itemDescription} • المعالجة: ${ret.paymentAction}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المبلغ المسترد: ${ret.refundAmount}${AppCurrency.symbol(ret.currency)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.dangerWaste,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'معاينة طباعة A4 (Print Preview)',
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          onPressed: () {
                            A4InvoicePrintDialog.show(
                              context,
                              invoiceData:
                                  A4InvoiceData.fromReturnInvoice(ret),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddReturnInvoiceDialog(ERPProvider erp) async {
    var returnType = 'مرتجع مشتريات مورد';
    final savedType = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إصدار فاتورة مرتجع جديدة',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const Divider(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: returnType,
                  decoration: const InputDecoration(labelText: 'نوع المرتجع'),
                  items: const [
                    DropdownMenuItem(
                      value: 'مرتجع مشتريات مورد',
                      child: Text(
                        '1. مرتجع مشتريات مورد (Supplier Purchase Return)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'مرتجع مبيعات مصنع',
                      child: Text(
                        '2. مرتجع مبيعات مصنع (Factory Sales Return)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'مرتجع مبيعات معمل',
                      child: Text(
                        '3. مرتجع مبيعات معمل (Workshop Sales Return)',
                      ),
                    ),
                  ],
                  onChanged: (v) => setSt(() => returnType = v!),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerWaste,
                  ),
                  onPressed: () => Navigator.pop(ctx, returnType),
                  child: const Text('متابعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (savedType == null || !mounted) return;
    final (module, kind) = switch (savedType) {
      'مرتجع مبيعات معمل' => ('workshop', 'sales_return'),
      'مرتجع مبيعات مصنع' => ('factory', 'sales_return'),
      _ => ('factory', 'purchase_return'),
    };
    final result = await ReturnAllowanceDialog.show(
      context,
      erp: erp,
      module: module,
      kind: kind,
      title: savedType,
    );
    if (result == null || !mounted) return;
    if (!erp.addAdjustmentInvoice(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر حفظ المرتجع: تحقق من المبلغ والرصيد وطريقة التسوية.',
          ),
        ),
      );
    }
  }
}
