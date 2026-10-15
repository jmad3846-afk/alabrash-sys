import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import 'accounting_screens.dart';

class FinancialsScreen extends StatefulWidget {
  final bool showOnlyIncomeStatement;
  const FinancialsScreen({super.key, this.showOnlyIncomeStatement = false});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _financialsTabController;
  String _retailQuery = '';

  @override
  void initState() {
    super.initState();
    _financialsTabController = TabController(
      length: 9,
      vsync: this,
      initialIndex: widget.showOnlyIncomeStatement ? 7 : 0,
    );
  }

  @override
  void dispose() {
    _financialsTabController.dispose();
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
              controller: _financialsTabController,
              isScrollable: true,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.brandSecondaryText,
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: '1. أرباح محاسب الغرانيت (50%)'),
                Tab(text: '2. الصناديق المعزولة'),
                Tab(text: '3. مالية موردي المصنع'),
                Tab(text: '4. مالية معتمدي المصنع'),
                Tab(text: '5. مالية القوى العاملة'),
                Tab(text: '6. مالية المعمل'),
                Tab(text: '7. مالية الزيادات (Surplus Financials)'),
                Tab(text: '8. ملخص الدخل (P&L)'),
                Tab(text: '9. المالية القديمة • أرصدة القيد الافتتاحي'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _financialsTabController,
              children: [
                _buildGraniteAccountantTab(erp),
                _buildIsolatedCashBoxesTab(erp),
                _buildFactorySuppliersTab(erp),
                _buildFactoryClientsTab(erp),
                _buildWorkforceTab(erp),
                _buildWorkshopFinancesTab(erp),
                _buildSurplusTab(erp),
                _buildIncomeStatementTab(erp),
                const HistoricalFinancialsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SPECIAL ACCOUNTANT GRANITE PROFIT MODULE (50% SPLIT)
  // -------------------------------------------------------------
  Widget _buildGraniteAccountantTab(ERPProvider erp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قسم أرباح محاسب الغرانيت (Special 50% Granite Profit Module)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'القاعدة المحاسبية: يحصل المحاسب على 50% تماماً من صافي أرباح مبيعات أصناف الغرانيت بكافة مقاساته وسماكاته',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.chipBgBlue,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentPrimary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'مستحقات المحاسب المعتمدة (50% Share):',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${erp.accountantGraniteShare.fmt} \$',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Accounting Ledger Entry Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentPrimary,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'القيد المحاسبي المولد آلياً في دفتر الأستاذ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'من حـ/ 5321 (مصروف عمولات مبيعات الغرانيت)   :   ${erp.accountantGraniteShare.fmt} \$\nإلى حـ/ 2115 (مستحقات المحاسب الدائنة)       :   ${erp.accountantGraniteShare.fmt} \$',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Granite Financials Summary Cards
          Row(
            children: [
              _buildSummaryCard(
                'إجمالي إيرادات مبيعات الغرانيت',
                AppCurrency.dual(
                  erp.graniteTotalRevenue,
                  erp.graniteTotalRevenueSyp,
                ),
                AppColors.accentPrimary,
                AppColors.chipBgBlue,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'إجمالي تكلفة البضاعة المبيعة (Post-Cut COGS)',
                AppCurrency.dual(erp.graniteTotalCOGS, erp.graniteTotalCOGSSyp),
                AppColors.dangerWaste,
                AppColors.chipBgRed,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'صافي أرباح الغرانيت الكلية',
                AppCurrency.dual(erp.netGraniteProfit, erp.netGraniteProfitSyp),
                AppColors.successGreen,
                AppColors.chipBgGreen,
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'تفاصيل فواتير الغرانيت المساهمة في الأرباح:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),

          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: erp.factoryInvoices
                  .where((i) => i.containsGranite)
                  .length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final inv = erp.factoryInvoices
                    .where((i) => i.containsGranite)
                    .toList()[idx];
                return ListTile(
                  title: Text(
                    'فاتورة مصنع: ${inv.invoiceNo} • الطرف: ${inv.partyName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('أصناف الغرانيت المسجلة في الفاتورة'),
                  trailing: Text(
                    'ربح الغرانيت: ${inv.graniteProfit.fmt}\$',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                      fontSize: 15,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: ISOLATED CASH BOXES BALANCES OVERVIEW
  // -------------------------------------------------------------
  Widget _buildIsolatedCashBoxesTab(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على الصناديق المعزولة ورصيد السيولة النقدية',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          const Text(
            'يضمن النظام الفصل التام بين الصندوق الرئيسي وصندوق الزيادات وصندوق عربونات الطلبيات مع حماية ACID',
            style: TextStyle(color: AppColors.brandSecondaryText),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              // Box 1: Main Cash Register
              Expanded(
                child: _buildCashRegisterCard(
                  title: '1. الصندوق الرئيسي (Main Cash Box)',
                  description:
                      'يتلقى المبيعات الرئيسية المعتمدة، ويُصرف منه المشتريات وسُلف العمالة ومسحوبات الشركاء.',
                  balance: erp.mainCashBox,
                  balanceSyp: erp.mainCashBoxSyp,
                  accentColor: AppColors.accentPrimary,
                  bgColor: AppColors.chipBgBlue,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 16),

              // Box 2: Scrap Cash Register
              Expanded(
                child: _buildCashRegisterCard(
                  title: '2. صندوق الزيادات (Scrap Cash Box)',
                  description:
                      'يتلقى الإيرادات الناتجة حصراً وإلزامياً عن بيع القطع الزائدة والخردة وقصاصات المعمل.',
                  balance: erp.scrapCashBox,
                  balanceSyp: erp.scrapCashBoxSyp,
                  accentColor: AppColors.scrapBoxAccent,
                  bgColor: AppColors.chipBgGreen,
                  icon: Icons.inventory_2_rounded,
                ),
              ),
              const SizedBox(width: 16),

              // Box 3: Order Cash Register
              Expanded(
                child: _buildCashRegisterCard(
                  title: '3. صندوق الطلبيات (Order Deposit Box)',
                  description:
                      'يحتفظ بعربونات الطلبيات قيد التنفيذ بشكل معزول لحين ترحيلها للفاتورة أو إلغائها.',
                  balance: erp.orderCashBox,
                  balanceSyp: erp.orderCashBoxSyp,
                  accentColor: AppColors.orderDepositBoxAccent,
                  bgColor: AppColors.chipBgSky,
                  icon: Icons.assignment_turned_in_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Shared money movement dialog (pay / collect).
  // -------------------------------------------------------------
  void _showMoneyDialog({
    required String title,
    required String actionLabel,
    required double max,
    required bool Function(double amount) onConfirm,
    String currency = AppCurrency.usd,
  }) {
    final ctrl = TextEditingController(text: max > 0 ? max.fmt : '');
    final sym = AppCurrency.symbol(currency);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            const SizedBox(width: 8),
            CurrencyBadge(currency: currency),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الحد الأقصى: ${max.fmt} $sym'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'المبلغ ($sym)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text) ?? 0.0;
              if (onConfirm(amount)) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت العملية بنجاح.'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تعذر إتمام العملية (تحقق من المبلغ ورصيد الصندوق).',
                    ),
                    backgroundColor: AppColors.dangerWaste,
                  ),
                );
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// Collect/settle button that lets the user pick the fund currency
  /// when the account holds BOTH Dollar and Syrian balances.
  Widget _buildDualCollectButton(
    ERPProvider erp,
    String name,
    double usdDue,
    double sypDue,
    bool Function(String currency, double amount) onPay,
  ) {
    final hasUsd = usdDue > 0.01;
    final hasSyp = sypDue > 0.01;
    if (!hasUsd && !hasSyp) return const Chip(label: Text('خالص'));
    if (hasUsd && !hasSyp) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.successGreen,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: () => _showMoneyDialog(
          title: 'تحصيل دفعة من $name',
          actionLabel: 'تأكيد التحصيل',
          max: usdDue,
          currency: AppCurrency.usd,
          onConfirm: (a) => onPay(AppCurrency.usd, a),
        ),
        child: const Text('تحصيل'),
      );
    }
    // Both (or SYP only): open a currency picker first.
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: () {
        String picked = hasUsd ? AppCurrency.usd : AppCurrency.syp;
        showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => AlertDialog(
              title: Text('تحصيل دفعة من $name — اختر العملة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUsd)
                    RadioListTile<String>(
                      value: AppCurrency.usd,
                      groupValue: picked,
                      title: Text('دولار: ${usdDue.fmt} \$'),
                      onChanged: (v) => setSt(() => picked = v!),
                    ),
                  if (hasSyp)
                    RadioListTile<String>(
                      value: AppCurrency.syp,
                      groupValue: picked,
                      title: Text('ليرة: ${sypDue.fmt} ل.س'),
                      onChanged: (v) => setSt(() => picked = v!),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showMoneyDialog(
                      title: 'تحصيل دفعة من $name',
                      actionLabel: 'تأكيد التحصيل',
                      max: picked == AppCurrency.syp ? sypDue : usdDue,
                      currency: picked,
                      onConfirm: (a) => onPay(picked, a),
                    );
                  },
                  child: const Text('متابعة'),
                ),
              ],
            ),
          ),
        );
      },
      child: const Text('تحصيل'),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: FACTORY SUPPLIERS FINANCIALS (outstanding only)
  // Fully paid invoices live in the Paid section of Purchase Invoices.
  // -------------------------------------------------------------
  Widget _buildFactorySuppliersTab(ERPProvider erp) {
    final debtors = erp.suppliers
        .where((s) => s.debtBalance > 0.01 || s.debtBalanceSyp > 0.01)
        .toList();
    final totalDue = debtors.fold<double>(0.0, (s, x) => s + x.debtBalance);
    final totalDueSyp = debtors.fold<double>(
      0.0,
      (s, x) => s + x.debtBalanceSyp,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مالية موردي المصنع (Factory Suppliers)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'الموردون الذين علينا لهم مستحقات (الفواتير المدفوعة بالكامل في قسم المدفوعة)',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerWaste),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'إجمالي المستحق علينا:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.dangerWaste,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppCurrency.dual(totalDue, totalDueSyp),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dangerWaste,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (debtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'لا توجد مستحقات على الموردين. جميع الفواتير مدفوعة.',
                  ),
                ),
              ),
            ),
          ...debtors.map((s) {
            final invs = erp.factoryInvoices
                .where(
                  (i) =>
                      i.invoiceType == 'شراء_مورد' &&
                      (i.partyId == s.id || i.partyName == s.name),
                )
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.chipBgRed,
                  child: Text(
                    s.name.isEmpty ? '؟' : s.name[0],
                    style: const TextStyle(
                      color: AppColors.dangerWaste,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'المورد ${s.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'المتبقي علينا: ${s.dualDebt} • الفواتير: ${invs.length}',
                ),
                children: [
                  ...invs.map(
                    (inv) => ExpansionTile(
                      leading: CurrencyBadge(currency: inv.currency),
                      title: Text(
                        '${inv.invoiceNo} — ${inv.grandTotal.fmt}${inv.currencySymbol} (${inv.isDue ? "مستحق الدفع" : "مدفوعة"})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'التاريخ: ${inv.date.toString().substring(0, 10)} • واصلة: ${inv.isGoodsDelivered ? "نعم" : "لا (شحن ${inv.shippingFee}${inv.currencySymbol})"} • المدفوع: ${inv.advancePayment.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                      ),
                      trailing: inv.isDue
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.dangerWaste,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () => _showMoneyDialog(
                                title:
                                    'دفع دفعة للمورد ${s.name} — ${inv.invoiceNo}',
                                actionLabel: 'تأكيد الدفع',
                                max: inv.remainingBalance,
                                currency: inv.currency,
                                onConfirm: (a) =>
                                    erp.paySupplierInvoice(inv, a),
                              ),
                              child: const Text('دفع'),
                            )
                          : null,
                      children: [
                        ...inv.items.map(
                          (it) => ListTile(
                            dense: true,
                            title: Text(
                              '${it.typeName.isNotEmpty ? it.typeName : it.description} ${it.grade}',
                            ),
                            subtitle: Text(
                              '${it.quantity} طن × ${it.unitPrice}\$ = ${(it.quantity * it.unitPrice).fmt}\$',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: FACTORY APPROVED CLIENTS FINANCIALS (collect from them)
  // -------------------------------------------------------------
  Widget _buildFactoryClientsTab(ERPProvider erp) {
    final debtors = erp.clients
        .where(
          (c) =>
              c.clientType == 'معتمد مصنع' &&
              (c.debtBalance > 0.01 || c.debtBalanceSyp > 0.01),
        )
        .toList();
    final totalDue = debtors.fold<double>(0.0, (s, x) => s + x.debtBalance);
    final totalDueSyp = debtors.fold<double>(
      0.0,
      (s, x) => s + x.debtBalanceSyp,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مالية معتمدي المصنع (Approved Clients)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'المعتمدون الذين علينا تحصيل مستحقات منهم',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgGreen,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.successGreen),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'إجمالي المطلوب تحصيله:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppCurrency.dual(totalDue, totalDueSyp),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (debtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد مستحقات على المعتمدين.')),
              ),
            ),
          ...debtors.map((c) {
            final invs = erp.factoryInvoices
                .where(
                  (i) =>
                      i.invoiceType == 'بيع_معتمد' &&
                      (i.partyId == c.id || i.partyName == c.name),
                )
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.chipBgBlue,
                  child: Text(
                    c.name.isEmpty ? '؟' : c.name[0],
                    style: const TextStyle(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'المعتمد ${c.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'المتبقي عليه: ${c.dualDebt} • الفواتير: ${invs.length}',
                ),
                trailing: _buildDualCollectButton(
                  erp,
                  c.name,
                  c.debtBalance,
                  c.debtBalanceSyp,
                  (cur, amt) => erp.collectClientDebt(c, amt, cur),
                ),
                children: [
                  ...invs.map(
                    (inv) => ExpansionTile(
                      leading: CurrencyBadge(currency: inv.currency),
                      title: Text(
                        '${inv.invoiceNo} — ${inv.grandTotal.fmt}${inv.currencySymbol} (${inv.isDue ? "مستحق الدفع" : "مدفوعة"})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'التاريخ: ${inv.date.toString().substring(0, 10)} • المدفوع: ${inv.advancePayment.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                      ),
                      trailing: inv.isDue
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () => _showMoneyDialog(
                                title: 'تحصيل فاتورة ${inv.invoiceNo}',
                                actionLabel: 'تأكيد التحصيل',
                                max: inv.remainingBalance,
                                currency: inv.currency,
                                onConfirm: (a) =>
                                    erp.collectFactoryInvoice(inv, a),
                              ),
                              child: const Text('تحصيل'),
                            )
                          : null,
                      children: [
                        ...inv.items.map(
                          (it) => ListTile(
                            dense: true,
                            title: Text(it.description),
                            subtitle: Text(
                              'الكمية: ${it.calculatedArea.fmt} • الإجمالي: ${it.grandTotal.fmt}\$',
                            ),
                          ),
                        ),
                        ...inv.items.expand(
                          (it) => it.services.map(
                            (s) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.home_repair_service_rounded,
                                size: 18,
                                color: AppColors.accentPrimary,
                              ),
                              title: Text('خدمة: ${s.serviceName}'),
                              trailing: Text(
                                '${s.price}\$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 5: WORKFORCE FINANCIALS (Workers / Masters / Admin)
  // All dues are settled from here.
  // -------------------------------------------------------------
  Widget _buildWorkforceTab(ERPProvider erp) {
    Widget section(String category, String label) {
      final people = erp.staffList
          .where((s) => s.category == category)
          .toList();
      final totalDue = people.fold<double>(
        0.0,
        (s, x) => s + x.netRemainingBalance,
      );
      final totalDueSyp = people.fold<double>(
        0.0,
        (s, x) => s + x.netRemainingBalanceSyp,
      );
      if (people.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('لا يوجد $label مسجلون.')),
          ),
        );
      }
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.chipBgAmber,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.partnersEquityAccent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'إجمالي المستحق لـ$label:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppCurrency.dual(totalDue, totalDueSyp),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.partnersEquityAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...people.map((stf) {
            final days = erp.workdayEntries
                .where((d) => d.staffNames.contains(stf.name))
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.chipBgAmber,
                  child: Text(
                    stf.name.isEmpty ? '؟' : stf.name[0],
                    style: const TextStyle(
                      color: AppColors.partnersEquityAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  stf.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'المكتسب: ${AppCurrency.dual(stf.totalEarned, stf.totalEarnedSyp)} • المسلف: ${AppCurrency.dual(stf.cashAdvancesDisbursed, stf.cashAdvancesDisbursedSyp)} • الصافي: ${stf.dualNet}',
                ),
                trailing:
                    (stf.netRemainingBalance > 0.01 ||
                        stf.netRemainingBalanceSyp > 0.01)
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.partnersEquityAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          final hasUsd = stf.netRemainingBalance > 0.01;
                          final hasSyp = stf.netRemainingBalanceSyp > 0.01;
                          if (hasUsd && !hasSyp) {
                            _showMoneyDialog(
                              title: 'تسديد مستحقات ${stf.name}',
                              actionLabel: 'تأكيد التسديد',
                              max: stf.netRemainingBalance,
                              currency: AppCurrency.usd,
                              onConfirm: (_) => erp.settleStaffDue(stf),
                            );
                          } else {
                            String picked = hasUsd
                                ? AppCurrency.usd
                                : AppCurrency.syp;
                            showDialog(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (ctx, setSt) => AlertDialog(
                                  title: Text(
                                    'تسديد مستحقات ${stf.name} — اختر العملة',
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasUsd)
                                        RadioListTile<String>(
                                          value: AppCurrency.usd,
                                          groupValue: picked,
                                          title: Text(
                                            'دولار: ${stf.netRemainingBalance.fmt} \$',
                                          ),
                                          onChanged: (v) =>
                                              setSt(() => picked = v!),
                                        ),
                                      if (hasSyp)
                                        RadioListTile<String>(
                                          value: AppCurrency.syp,
                                          groupValue: picked,
                                          title: Text(
                                            'ليرة: ${stf.netRemainingBalanceSyp.fmt} ل.س',
                                          ),
                                          onChanged: (v) =>
                                              setSt(() => picked = v!),
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('إلغاء'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showMoneyDialog(
                                          title: 'تسديد مستحقات ${stf.name}',
                                          actionLabel: 'تأكيد التسديد',
                                          max: picked == AppCurrency.syp
                                              ? stf.netRemainingBalanceSyp
                                              : stf.netRemainingBalance,
                                          currency: picked,
                                          onConfirm: (_) =>
                                              erp.settleStaffDue(stf, picked),
                                        );
                                      },
                                      child: const Text('متابعة'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('تسديد'),
                      )
                    : const Chip(label: Text('خالص')),
                children: [
                  ...days.map(
                    (d) => ListTile(
                      dense: true,
                      leading: CurrencyBadge(currency: d.currency),
                      title: Text(d.workDescription),
                      subtitle: Text(
                        'التاريخ: ${d.date.toString().substring(0, 10)} • ${d.rateType}',
                      ),
                      trailing: Text(
                        AppCurrency.single(d.agreedAmountPerPerson, d.currency),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'لا توجد أيام عمل مسجلة لهذا الشخص.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return DefaultTabController(
      length: 3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مالية القوى العاملة (Workforce)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            const Text(
              'جميع المستحقات تُسوّى من هنا عبر الصندوق الرئيسي',
              style: TextStyle(color: AppColors.brandSecondaryText),
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'العمال (Workers)'),
                  Tab(text: 'المعلمون (Masters)'),
                  Tab(text: 'الإداريون (Admin)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 520,
              child: TabBarView(
                children: [
                  SingleChildScrollView(child: section('عمال', 'العمال')),
                  SingleChildScrollView(child: section('معلمين', 'المعلمين')),
                  SingleChildScrollView(child: section('إداريين', 'الإداريين')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 6: WORKSHOP FINANCIALS (Retail + Projects)
  // -------------------------------------------------------------
  Widget _buildWorkshopFinancesTab(ERPProvider erp) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.panelSurface,
            child: const TabBar(
              tabs: [
                Tab(text: 'زبائن الجزافي (Retail Clients)'),
                Tab(text: 'المشاريع (Projects)'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _buildRetailFinances(erp),
                _buildProjectsFinances(erp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetailStats(ERPProvider erp) {
    final invs = erp.workshopInvoices
        .where((i) => i.projectId.isEmpty)
        .toList();
    double sumWhere(String cur, double Function(WorkshopInvoiceModel) f) => invs
        .where((i) => i.currency == cur)
        .fold<double>(0.0, (s, i) => s + f(i));
    final totalInvoiced = sumWhere(AppCurrency.usd, (i) => i.grandTotal);
    final totalInvoicedSyp = sumWhere(AppCurrency.syp, (i) => i.grandTotal);
    final totalDue = sumWhere(AppCurrency.usd, (i) => i.remainingBalance);
    final totalDueSyp = sumWhere(AppCurrency.syp, (i) => i.remainingBalance);
    final retailDebt = erp.clients
        .where((c) => c.clientType == 'زبون معمل')
        .fold<double>(0.0, (s, c) => s + c.debtBalance);
    final retailDebtSyp = erp.clients
        .where((c) => c.clientType == 'زبون معمل')
        .fold<double>(0.0, (s, c) => s + c.debtBalanceSyp);
    Widget stat(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat('إجمالي الفواتير', '${invs.length}', AppColors.accentPrimary),
        const SizedBox(width: 8),
        stat(
          'إجمالي المبالغ',
          AppCurrency.dual(totalInvoiced, totalInvoicedSyp),
          AppColors.accentPrimary,
        ),
        const SizedBox(width: 8),
        stat(
          'المتبقي للتحصيل',
          AppCurrency.dual(totalDue, totalDueSyp),
          AppColors.dangerWaste,
        ),
        const SizedBox(width: 8),
        stat(
          'ديون الجزافي',
          AppCurrency.dual(retailDebt, retailDebtSyp),
          AppColors.partnersEquityAccent,
        ),
      ],
    );
  }

  Widget _buildRetailFinances(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search across all invoice fields.
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في كل حقول الفواتير...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _retailQuery = v.trim()),
          ),
          const SizedBox(height: 12),
          _buildRetailStats(erp),
          const SizedBox(height: 12),
          Expanded(
            child: Builder(
              builder: (_) {
                final q = _retailQuery;
                bool matches(WorkshopInvoiceModel i) {
                  if (q.isEmpty) return true;
                  final hay =
                      '${i.invoiceNo} ${i.clientName} ${i.itemDescription} ${i.sourceType} ${i.photoPath} ${i.services.map((s) => '${s.serviceName} ${s.notes}').join(' ')}';
                  return hay.contains(q);
                }

                final invs = erp.workshopInvoices
                    .where((i) => i.projectId.isEmpty && matches(i))
                    .toList();
                if (invs.isEmpty) {
                  return const Card(
                    child: Center(child: Text('لا توجد فواتير مطابقة.')),
                  );
                }
                return Card(
                  child: ListView.separated(
                    itemCount: invs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final inv = invs[idx];
                      return ExpansionTile(
                        leading: CurrencyBadge(currency: inv.currency),
                        title: Text(
                          '${inv.invoiceNo} • ${inv.clientName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${inv.itemDescription} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المتبقي للتحصيل: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                        ),
                        trailing: inv.remainingBalance > 0.01
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.successGreen,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                onPressed: () => _showMoneyDialog(
                                  title: 'تحصيل فاتورة ${inv.invoiceNo}',
                                  actionLabel: 'تأكيد التحصيل',
                                  max: inv.remainingBalance,
                                  currency: inv.currency,
                                  onConfirm: (a) =>
                                      erp.collectWorkshopInvoice(inv, a),
                                ),
                                child: const Text('تحصيل'),
                              )
                            : const Chip(label: Text('خالصة')),
                        children: [
                          ...inv.services.map(
                            (s) => ListTile(
                              dense: true,
                              title: Text('خدمة: ${s.serviceName}'),
                              trailing: Text(
                                '${s.price}\$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsFinances(ERPProvider erp) {
    final pending = erp.pendingProjects;
    final actionable = pending
        .where(
          (p) => erp.projectDue(p.id) > 0.01 || erp.projectDueSyp(p.id) > 0.01,
        )
        .toList();
    if (actionable.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: Center(child: Text('لا توجد مشاريع بانتظار التحصيل.')),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: actionable.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        final p = actionable[idx];
        final invs = erp.workshopInvoices
            .where((i) => i.projectId == p.id)
            .toList();
        final due = erp.projectDue(p.id);
        final dueSyp = erp.projectDueSyp(p.id);
        return Card(
          child: ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.chipBgSky,
              child: Icon(
                Icons.domain_rounded,
                color: AppColors.orderDepositBoxAccent,
              ),
            ),
            title: Text(
              'المشروع ${p.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الزبون: ${p.clientName} • الفواتير: ${invs.length} • المتبقي للتحصيل: ${AppCurrency.dual(due, dueSyp)}',
            ),
            children: [
              ...invs.map(
                (inv) => ListTile(
                  leading: CurrencyBadge(currency: inv.currency),
                  title: Text(
                    '${inv.invoiceNo} — ${inv.grandTotal.fmt}${inv.currencySymbol}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${inv.itemDescription} • المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                  ),
                  trailing: inv.remainingBalance > 0.01
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _showMoneyDialog(
                            title: 'تحصيل فاتورة ${inv.invoiceNo}',
                            actionLabel: 'تأكيد التحصيل',
                            max: inv.remainingBalance,
                            currency: inv.currency,
                            onConfirm: (a) =>
                                erp.collectWorkshopInvoice(inv, a),
                          ),
                          child: const Text('تحصيل'),
                        )
                      : const Chip(label: Text('خالصة')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 7: SURPLUS FINANCIALS (مالية الزيادات)
  // Dedicated ledger: how much did each surplus item cost?
  // Rule: initial price > 0 must be broken down into worker wages
  // and/or general expenses; all settled ONLY from the Surplus Fund.
  // Sales revenues go directly INTO the Surplus Fund.
  // -------------------------------------------------------------
  Widget _buildSurplusTab(ERPProvider erp) {
    final items = erp.scrapItems;
    final remaining = erp.totalSurplusCostRemaining;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مالية الزيادات (Surplus Financials)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'كم كلّفتني هذه القطعة الزائدة؟ المصاريف تُدفع من صندوق الزيادات (Surplus Fund)، وإيرادات البيع تدخل إليه. السعر الأولي 0 = هامش ربح 100%.',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgGreen,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.scrapBoxAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'رصيد صندوق الزيادات (Surplus Fund):',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.scrapBoxAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppCurrency.dual(
                        erp.surplusFundBalance,
                        erp.surplusFundBalanceSyp,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.scrapBoxAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryCard(
                'إيرادات الزيادات',
                AppCurrency.dual(
                  erp.totalSurplusRevenue,
                  erp.totalSurplusRevenueSyp,
                ),
                AppColors.accentPrimary,
                AppColors.chipBgBlue,
              ),
              _buildSummaryCard(
                'التكلفة الأولية الكلية',
                AppCurrency.dual(
                  erp.totalSurplusInitialCost,
                  erp.totalSurplusInitialCostSyp,
                ),
                AppColors.dangerWaste,
                AppColors.chipBgRed,
              ),
              _buildSummaryCard(
                'المدفوع من الصندوق',
                AppCurrency.dual(
                  erp.totalSurplusCostPaid,
                  erp.totalSurplusCostPaidSyp,
                ),
                AppColors.partnersEquityAccent,
                AppColors.chipBgAmber,
              ),
              _buildSummaryCard(
                'المتبقي (ذمم الزيادات)',
                AppCurrency.dual(remaining, erp.totalSurplusCostRemainingSyp),
                AppColors.dangerWaste,
                AppColors.chipBgRed,
              ),
              _buildSummaryCard(
                'صافي ربح الزيادات',
                AppCurrency.dual(erp.netSurplusProfit, erp.netSurplusProfitSyp),
                AppColors.successGreen,
                AppColors.chipBgGreen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.chipBgBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accentPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أجور العمال: ${AppCurrency.dual(erp.totalSurplusWorkerDue, erp.totalSurplusWorkerDueSyp)} • مصاريف (مواد/كهرباء/ماء...): ${AppCurrency.dual(erp.totalSurplusExpenseDue, erp.totalSurplusExpenseDueSyp)} • الدفع حصراً من صندوق الزيادات.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تفاصيل القطع الزائدة (التكلفة والإيراد والهامش):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.scrapBoxAccent,
                ),
                onPressed: () => _showAddSurplusCostDialog(erp),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة أجرة/مصروف لقطعة'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد قطع زائدة مسجلة بعد.')),
              ),
            ),
          ...items.map((sc) {
            final linked = erp.surplusCostsForItem(sc.id);
            final paid = erp.surplusItemPaid(sc.id);
            final due = erp.surplusItemRemaining(sc.id);
            final marginPct = (sc.profitMargin * 100).fmt;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: sc.isSold
                      ? AppColors.chipBgRed
                      : AppColors.chipBgGreen,
                  child: Text(
                    sc.description.isEmpty ? '؟' : sc.description[0],
                    style: TextStyle(
                      color: sc.isSold
                          ? AppColors.dangerWaste
                          : AppColors.scrapBoxAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sc.description,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    CurrencyBadge(currency: sc.currency),
                  ],
                ),
                subtitle: Text(
                  'أولي: ${sc.baseCost.fmt}${AppCurrency.symbol(sc.currency)} • بيع: ${sc.sellingPrice.fmt}${AppCurrency.symbol(sc.currency)} • هامش: $marginPct% ${sc.baseCost <= 0 ? "(100% ربح)" : ""} • ${sc.isSold ? "مُباعة" : "متاحة"} • مدفوع: ${paid.fmt}${AppCurrency.symbol(sc.currency)} • متبقٍ: ${due.fmt}${AppCurrency.symbol(sc.currency)}',
                ),
                children: [
                  if (linked.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        sc.baseCost > 0.01
                            ? 'تحذير: يوجد سعر أولي بلا تفصيل أشخاص/مصاريف. أضف التفصيل من زر أعلاه.'
                            : 'لا توجد تكاليف — هامش ربح 100%.',
                        style: TextStyle(
                          color: sc.baseCost > 0.01
                              ? AppColors.dangerWaste
                              : AppColors.brandSecondaryText,
                          fontWeight: sc.baseCost > 0.01
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ...linked.map(
                    (c) => ListTile(
                      dense: true,
                      leading: Icon(
                        c.kind == 'worker'
                            ? Icons.person_rounded
                            : Icons.receipt_long_rounded,
                        size: 18,
                        color: AppColors.partnersEquityAccent,
                      ),
                      title: Text(
                        '${c.kindLabel}: ${c.beneficiaryName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'مستحق: ${c.amountDue.fmt}${AppCurrency.symbol(c.currency)} • مدفوع: ${c.amountPaid.fmt}${AppCurrency.symbol(c.currency)} • متبقٍ: ${c.remaining.fmt}${AppCurrency.symbol(c.currency)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!c.isPaid)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.scrapBoxAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () => _showMoneyDialog(
                                title:
                                    'دفع ${c.kindLabel} ${c.beneficiaryName} من صندوق الزيادات',
                                actionLabel: 'تأكيد الدفع',
                                max: c.remaining,
                                currency: c.currency,
                                onConfirm: (a) => erp.paySurplusCost(c.id, a),
                              ),
                              child: const Text('دفع'),
                            ),
                          if (!c.isPaid) const SizedBox(width: 6),
                          if (c.isPaid) const Chip(label: Text('خالص')),
                          if (c.amountPaid <= 0.01)
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.dangerWaste,
                              ),
                              onPressed: () {
                                erp.deleteSurplusCost(c.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم حذف البند وتعديل السعر الأولي.',
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddSurplusCostDialog(ERPProvider erp) {
    if (erp.scrapItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجّل قطعة زائدة أولاً قبل إضافة أجرة/مصروف.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }
    String itemId = erp.scrapItems.first.id;
    String kind = 'worker';
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? staffId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة أجرة عامل / مصروف لقطعة زائدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'القطعة الزائدة',
                  ),
                  items: erp.scrapItems
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.description} (أولي: ${s.baseCost}${AppCurrency.symbol(s.currency)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => itemId = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(
                      value: 'worker',
                      child: Text('أجرة عامل/شخص'),
                    ),
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('مصروف (مواد/كهرباء/ماء...)'),
                    ),
                  ],
                  onChanged: (v) => setSt(() {
                    kind = v!;
                    staffId = null;
                  }),
                ),
                if (kind == 'worker' && erp.staffList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: staffId,
                    decoration: const InputDecoration(
                      labelText: 'ربط بعامل مسجل (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— شخص خارجي —'),
                      ),
                      ...erp.staffList.map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ),
                    ],
                    onChanged: (v) => setSt(() {
                      staffId = v;
                      if (v != null) {
                        final st = erp.staffList.firstWhere((e) => e.id == v);
                        if (nameCtrl.text.trim().isEmpty) {
                          nameCtrl.text = st.name;
                        }
                      }
                    }),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: kind == 'worker'
                        ? 'اسم الشخص'
                        : 'بيان المصروف (مثال: كهرباء، مواد...)',
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final sel = erp.scrapItems.firstWhere(
                      (s) => s.id == itemId,
                      orElse: () => erp.scrapItems.first,
                    );
                    return TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'المبلغ المستحق (${AppCurrency.symbol(sel.currency)})',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final sel = erp.scrapItems.firstWhere(
                      (s) => s.id == itemId,
                      orElse: () => erp.scrapItems.first,
                    );
                    return Text(
                      'عملة القطعة: ${AppCurrency.label(sel.currency)} — رصيد الصندوق: ${AppCurrency.single(erp.cashOf('scrap', sel.currency), sel.currency)} — الدفع يتم من هذا الصندوق حصراً.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brandSecondaryText,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.scrapBoxAccent,
              ),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (nameCtrl.text.trim().isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل الاسم والمبلغ الصحيح.'),
                      backgroundColor: AppColors.dangerWaste,
                    ),
                  );
                  return;
                }
                final item = erp.scrapItems.firstWhere((s) => s.id == itemId);
                erp.addSurplusCost(
                  SurplusCostModel(
                    id: 'sxc_${DateTime.now().millisecondsSinceEpoch}',
                    surplusItemId: itemId,
                    surplusDescription: item.description,
                    kind: kind,
                    beneficiaryName: nameCtrl.text.trim(),
                    staffId: staffId,
                    amountDue: amount,
                    notes: notesCtrl.text.trim(),
                    currency: item.currency,
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إضافة البند إلى مالية الزيادات.'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 8: INCOME STATEMENT (ملخص الدخل P&L)
  // -------------------------------------------------------------
  Widget _buildIncomeStatementTab(ERPProvider erp) {
    final expensesUsd =
        erp.totalCOGS +
        erp.totalOperationalExpenses +
        erp.totalUnnaturalWasteLosses +
        erp.totalSurplusInitialCost +
        erp.accountantGraniteShare +
        erp.expenseRecordsTotalOf(AppCurrency.usd) +
        erp.salesReturnsAndAllowancesOf(AppCurrency.usd) +
        erp.salesDiscountsOf(AppCurrency.usd);
    final expensesSyp =
        erp.totalCOGSSyp +
        erp.totalOperationalExpensesSyp +
        erp.totalUnnaturalWasteLossesSyp +
        erp.totalSurplusInitialCostSyp +
        erp.accountantGraniteShareSyp +
        erp.expenseRecordsTotalOf(AppCurrency.syp) +
        erp.salesReturnsAndAllowancesOf(AppCurrency.syp) +
        erp.salesDiscountsOf(AppCurrency.syp);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قائمة ملخص الدخل والأرباح والخسائر (P&L Income Statement)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'المعادلة المحاسبية المعيارية: صافي الأرباح التشغيلية = إجمالي الإيرادات - تكلفة المبيعات - المصاريف - خسائر الهدر - تكاليف الزيادات - حصة المحاسب',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgGreen,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.successGreen),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'صافي الأرباح التشغيلية القابلة التوزيع:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppCurrency.dual(
                        erp.netOperatingProfit,
                        erp.netOperatingProfitSyp,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // REVENUES SECTION
                  const Text(
                    'أولاً: إجمالي الإيرادات المباشرة (Total Revenues)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildPlLine(
                    'إجمالي مبيعات المصنع قبل الخصومات:',
                    erp.totalFactoryRevenue -
                        erp.factoryServiceRevenueOf(AppCurrency.usd) +
                        erp.factorySalesDiscountOf(AppCurrency.usd),
                    syp:
                        erp.totalFactoryRevenueSyp -
                        erp.factoryServiceRevenueOf(AppCurrency.syp) +
                        erp.factorySalesDiscountOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'خدمات المصنع:',
                    erp.factoryServiceRevenueOf(AppCurrency.usd),
                    syp: erp.factoryServiceRevenueOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'إجمالي مبيعات وتفصيل المعمل قبل الخصومات:',
                    erp.totalWorkshopRevenue -
                        erp.workshopServiceRevenueOf(AppCurrency.usd) +
                        erp.workshopSalesDiscountOf(AppCurrency.usd),
                    syp:
                        erp.totalWorkshopRevenueSyp -
                        erp.workshopServiceRevenueOf(AppCurrency.syp) +
                        erp.workshopSalesDiscountOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'خدمات المعمل:',
                    erp.workshopServiceRevenueOf(AppCurrency.usd),
                    syp: erp.workshopServiceRevenueOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'إيرادات مبيعات القطع الزائدة (صندوق الزيادات):',
                    erp.totalScrapRevenue,
                    syp: erp.totalScrapRevenueSyp,
                  ),
                  _buildPlLine(
                    'إيرادات العربونات المحتفظ بها (الطلبيات الملغاة):',
                    erp.totalKeptDepositsRevenue,
                    syp: erp.totalKeptDepositsRevenueSyp,
                  ),
                  _buildPlLine(
                    'مرتجعات ومسموحات المشتريات:',
                    erp.purchaseReturnsAndAllowances,
                    syp: erp.purchaseReturnsAndAllowancesSyp,
                  ),
                  _buildPlLine(
                    'الخصومات المكتسبة من الموردين:',
                    erp.supplierDiscountsOf(AppCurrency.usd),
                    syp: erp.supplierDiscountsOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'إيرادات بيع الأصول:',
                    erp.assetSaleRevenueOf(AppCurrency.usd),
                    syp: erp.assetSaleRevenueOf(AppCurrency.syp),
                  ),
                  const Divider(height: 16),
                  _buildPlLine(
                    'مجموع الإيرادات الكلية:',
                    erp.totalRevenues,
                    syp: erp.totalRevenuesSyp,
                    isTotal: true,
                    color: AppColors.accentPrimary,
                  ),

                  const SizedBox(height: 24),

                  // COGS & EXPENSES SECTION
                  const Text(
                    'ثانياً: تكلفة المبيعات والمصاريف التشغيلية (COGS & Operational Expenses)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.dangerWaste,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildPlLine(
                    'تكلفة مبيعات المصنع (Factory COGS):',
                    erp.totalFactoryCOGS,
                    syp: erp.totalFactoryCOGSSyp,
                  ),
                  _buildPlLine(
                    'تكلفة مبيعات المعمل (Workshop COGS):',
                    erp.totalWorkshopCOGS,
                    syp: erp.totalWorkshopCOGSSyp,
                  ),
                  _buildPlLine(
                    'مصاريف أجرة العمالة وإنجاز أيام العمل:',
                    erp.totalOperationalExpenses,
                    syp: erp.totalOperationalExpensesSyp,
                  ),
                  for (final type in erp.expenseTypes)
                    _buildPlLine(
                      'مصروفات ${type.name}:',
                      erp.expenseRecords
                          .where(
                            (expense) =>
                                expense.typeId == type.id &&
                                expense.currency == AppCurrency.usd,
                          )
                          .fold<double>(
                            0,
                            (sum, expense) => sum + expense.amount,
                          ),
                      syp: erp.expenseRecords
                          .where(
                            (expense) =>
                                expense.typeId == type.id &&
                                expense.currency == AppCurrency.syp,
                          )
                          .fold<double>(
                            0,
                            (sum, expense) => sum + expense.amount,
                          ),
                    ),
                  _buildPlLine(
                    'مرتجعات ومسموحات المبيعات:',
                    erp.salesReturnsAndAllowances,
                    syp: erp.salesReturnsAndAllowancesSyp,
                  ),
                  _buildPlLine(
                    'خصومات المبيعات الممنوحة:',
                    erp.salesDiscountsOf(AppCurrency.usd),
                    syp: erp.salesDiscountsOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'خسائر الهدر غير الطبيعي (سندات الإتلاف):',
                    erp.totalUnnaturalWasteLosses,
                    syp: erp.totalUnnaturalWasteLossesSyp,
                  ),
                  _buildPlLine(
                    'تكاليف الزيادات الأولية (Surplus Initial Cost):',
                    erp.totalSurplusInitialCost,
                    syp: erp.totalSurplusInitialCostSyp,
                  ),
                  _buildPlLine(
                    'مستحقات المحاسب عن مبيعات الغرانيت (50% Share):',
                    erp.accountantGraniteShare,
                    syp: erp.accountantGraniteShareSyp,
                  ),
                  const Divider(height: 16),
                  _buildPlLine(
                    'مجموع التكاليف والمصاريف الكلية:',
                    expensesUsd,
                    syp: expensesSyp,
                    isTotal: true,
                    color: AppColors.dangerWaste,
                  ),

                  const SizedBox(height: 24),

                  // NET OPERATING PROFIT & PARTNERS DISTRIBUTION
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.chipBgAmber,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.partnersEquityAccent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'صافي الربح التشغيلي النهائي:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              AppCurrency.dual(
                                erp.netOperatingProfit,
                                erp.netOperatingProfitSyp,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.partnersEquityAccent,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        const Text(
                          'توزيع صافي الربح على الشركاء حسب نسب حقوق الملكية الحالية:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: erp.partners.map((p) {
                            double share = erp.netOperatingProfit * p.ratio;
                            double shareSyp =
                                erp.netOperatingProfitSyp * p.ratio;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.panelBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'النسبة: ${(p.ratio * 100).fmt}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.brandSecondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppCurrency.dual(share, shareSyp),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.successGreen,
                                        fontSize: 12,
                                      ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String val, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              val,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashRegisterCard({
    required String title,
    required String description,
    required double balance,
    double balanceSyp = 0.0,
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.brandPrimaryText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'رصيد الصندوق الحالي:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${balance.fmt} \$',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    '${balanceSyp.fmt} ل.س',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlLine(
    String label,
    double val, {
    bool isTotal = false,
    Color? color,
    double? syp,
  }) {
    final text = syp == null ? '${val.fmt} \$' : AppCurrency.dual(val, syp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: FontWeight.bold,
              color:
                  color ??
                  (isTotal
                      ? AppColors.brandPrimaryText
                      : AppColors.brandPrimaryText),
            ),
          ),
        ],
      ),
    );
  }
}
