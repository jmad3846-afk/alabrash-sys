import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/a4_invoice_print_dialog.dart';
import '../widgets/a4_statement_print_dialog.dart';
import '../widgets/app_image_attachment.dart';
import '../widgets/customer_collection_dialog.dart';
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
  int _retailSubView = 0;
  String _projectQuery = '';
  int _projectSubView = 0;
  String _supplierQuery = '';
  int _supplierFilter = 0;
  String _agentQuery = '';
  int _agentFilter = 0;
  int _graniteSubView = 0;

  // Currency Filters for each Financials Section
  String _graniteCurrency = 'ALL';
  String _cashBoxesCurrency = 'ALL';
  String _supplierCurrency = 'ALL';
  String _agentCurrency = 'ALL';
  String _retailCurrency = 'ALL';
  String _projectCurrency = 'ALL';
  String _surplusCurrency = 'ALL';
  String _pnlCurrency = 'ALL';

  final TextEditingController _supplierSearchCtrl = TextEditingController();
  final TextEditingController _agentSearchCtrl = TextEditingController();
  final TextEditingController _retailSearchCtrl = TextEditingController();
  final TextEditingController _projectSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _financialsTabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.showOnlyIncomeStatement ? 6 : 0,
    );
  }

  @override
  void dispose() {
    _supplierSearchCtrl.dispose();
    _agentSearchCtrl.dispose();
    _retailSearchCtrl.dispose();
    _projectSearchCtrl.dispose();
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
              tabs: [
                Tab(
                  text:
                      '1. أرباح محاسب الغرانيت (${erp.graniteAccountantPercentage.fmt}%)',
                ),
                Tab(text: '2. الصناديق المعزولة'),
                Tab(text: '3. مالية موردي المصنع'),
                Tab(text: '4. مالية معتمدي المصنع'),
                Tab(text: '5. مالية المعمل'),
                Tab(text: '6. مالية الزيادات (Surplus Financials)'),
                Tab(text: '7. ملخص الدخل (P&L)'),
                Tab(text: '8. المالية القديمة • أرصدة القيد الافتتاحي'),
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
  // -------------------------------------------------------------
  // TAB 1: SPECIAL ACCOUNTANT GRANITE PROFIT MODULE
  // -------------------------------------------------------------
  Widget _buildGraniteAccountantTab(ERPProvider erp) {
    final availableUsd = erp.accountantAvailableBalanceUsd;
    final availableSyp = erp.accountantAvailableBalanceSyp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Title, Badge, and Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'قسم أرباح محاسب الغرانيت (${erp.graniteAccountantPercentage.fmt}%)',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 20),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.accentPrimary.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            'نسبة الشراكة: ${erp.graniteAccountantPercentage.fmt}%',
                            style: const TextStyle(
                              color: AppColors.accentPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'القاعدة المحاسبية: يحصل المحاسب على ${erp.graniteAccountantPercentage.fmt}% من صافي أرباح مبيعات أصناف الغرانيت بكافة مقاساته وسماكاته (المصنع والمعمل)',
                      style: const TextStyle(
                        color: AppColors.brandSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Action Buttons
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                      side: const BorderSide(
                        color: AppColors.accentPrimary,
                        width: 1.3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showEditProfitPercentageDialog(context, erp),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(
                      'تعديل نسبة الأرباح (${erp.graniteAccountantPercentage.fmt}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showWithdrawAccountantProfitDialog(context, erp),
                    icon: const Icon(Icons.payments_rounded, size: 19),
                    label: const Text(
                      'سحب أرباح المحاسب',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Financial Summary KPI Cards with Currency Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المؤشرات المالية لأرباح الغرانيت:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              CurrencyFilterPills(
                selected: _graniteCurrency,
                onChanged: (c) => setState(() => _graniteCurrency = c),
              ),
            ],
          ),
          const SizedBox(height: 12),
          () {
            String fmtGranite(double usd, double syp) {
              if (_graniteCurrency == AppCurrency.usd) {
                return '${usd.fmt} \$';
              } else if (_graniteCurrency == AppCurrency.syp) {
                return '${syp.fmt} ل.س';
              } else {
                return AppCurrency.dual(usd, syp);
              }
            }

            return Row(
              children: [
                _buildSummaryCard(
                  'صافي أرباح الغرانيت الكلية (100%)',
                  fmtGranite(
                    erp.netGraniteProfit,
                    erp.netGraniteProfitSyp,
                  ),
                  AppColors.accentPrimary,
                  AppColors.chipBgBlue,
                ),
                const SizedBox(width: 14),
                _buildSummaryCard(
                  'مستحقات المحاسب (${erp.graniteAccountantPercentage.fmt}%)',
                  fmtGranite(
                    erp.accountantGraniteShare,
                    erp.accountantGraniteShareSyp,
                  ),
                  const Color(0xFF0284C7),
                  const Color(0xFFF0F9FF),
                ),
                const SizedBox(width: 14),
                _buildSummaryCard(
                  'إجمالي المسحوبات المصروفة',
                  fmtGranite(
                    erp.accountantTotalWithdrawnUsd,
                    erp.accountantTotalWithdrawnSyp,
                  ),
                  AppColors.dangerWaste,
                  AppColors.chipBgRed,
                ),
                const SizedBox(width: 14),
                _buildSummaryCard(
                  'الرصيد المتبقي المتاح للسحب',
                  fmtGranite(
                    availableUsd,
                    availableSyp,
                  ),
                  availableUsd > 0.01 || availableSyp > 0.01
                      ? AppColors.successGreen
                      : const Color(0xFF64748B),
                  availableUsd > 0.01 || availableSyp > 0.01
                      ? AppColors.chipBgGreen
                      : const Color(0xFFF1F5F9),
                ),
              ],
            );
          }(),
          const SizedBox(height: 20),

          // 3. Double-Entry Accounting Ledger Info Box
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'الأثر المحاسبي المولد آلياً في دفتر الأستاذ العام:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. قيد استحقاق الأرباح الدائنة (${erp.graniteAccountantPercentage.fmt}%):\n'
                        '   من حـ/ 5321 (مصروف أرباح مبيعات الغرانيت)   :   ${AppCurrency.dual(erp.accountantGraniteShare, erp.accountantGraniteShareSyp)}\n'
                        '   إلى حـ/ 2115 (مستحقات المحاسب الدائنة)       :   ${AppCurrency.dual(erp.accountantGraniteShare, erp.accountantGraniteShareSyp)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimaryText,
                          fontSize: 12,
                        ),
                      ),
                      if (erp.accountantWithdrawals.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '2. قيد صرف المسحوبات المسددة:\n'
                          '   من حـ/ 2115 (مستحقات المحاسب الدائنة)       :   ${AppCurrency.dual(erp.accountantTotalWithdrawnUsd, erp.accountantTotalWithdrawnSyp)}\n'
                          '   إلى حـ/ 1111 (النقدية في الصناديق المعزولة)  :   ${AppCurrency.dual(erp.accountantTotalWithdrawnUsd, erp.accountantTotalWithdrawnSyp)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Sub-Navigation Filter Chips (Withdrawals vs Invoices)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.history_edu_rounded, size: 16),
                    label: Text(
                      'سجل مسحوبات المحاسب (${erp.accountantWithdrawals.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    selected: _graniteSubView == 0,
                    onSelected: (sel) {
                      if (sel) setState(() => _graniteSubView = 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(
                      'فواتير الغرانيت المساهمة (${erp.factoryInvoices.where((i) => i.containsGranite).length + erp.workshopInvoices.where((i) => i.isGranite).length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    selected: _graniteSubView == 1,
                    onSelected: (sel) {
                      if (sel) setState(() => _graniteSubView = 1);
                    },
                  ),
                ],
              ),
              if (_graniteSubView == 0 && erp.accountantWithdrawals.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showWithdrawAccountantProfitDialog(context, erp),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('تسجيل سحب جديد'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Active Sub-View Body
          if (_graniteSubView == 0)
            _buildAccountantWithdrawalsTable(erp)
          else
            _buildGraniteInvoicesTable(erp),
        ],
      ),
    );
  }

  Widget _buildAccountantWithdrawalsTable(ERPProvider erp) {
    final withdrawals = erp.accountantWithdrawals.where((w) {
      if (_graniteCurrency == AppCurrency.usd) return AppCurrency.isUsd(w.currency);
      if (_graniteCurrency == AppCurrency.syp) return AppCurrency.isSyp(w.currency);
      return true;
    }).toList();

    if (withdrawals.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد مسحوبات مسجلة للمحاسب مطابقة للتصفية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'كامل رصيد أرباح المحاسب متاح في الذمة ويمكن سحبه نقداً في أي وقت.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showWithdrawAccountantProfitDialog(context, erp),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('سحب دفعة الآن'),
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
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: withdrawals.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final w = withdrawals[idx];
          String boxLabel = 'الصندوق الرئيسي';
          if (w.cashBox == 'order') boxLabel = 'صندوق الطلبيات';
          if (w.cashBox == 'scrap') boxLabel = 'صندوق الزيادات والسكراب';
          if (w.cashBox == 'direct') boxLabel = 'تسوية مباشرة (سحب خارجي)';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.chipBgRed,
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: AppColors.dangerWaste,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(
                  'سحب دفعة: ${w.amount.fmt} ${AppCurrency.symbol(w.currency)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppCurrency.isSyp(w.currency)
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    w.currency,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppCurrency.isSyp(w.currency)
                          ? const Color(0xFFB45309)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• الصندوق: $boxLabel',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            subtitle: Text(
              'التاريخ: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(w.date)} • المستلم: ${w.recipient}'
              '${w.notes.isNotEmpty ? " • البيان: ${w.notes}" : ""}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerWaste),
              tooltip: 'حذف وإلغاء السحب (إعادة المبلغ للصندوق)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تأكيد حذف حركة السحب'),
                    content: Text(
                      'هل أنت متأكد من حذف حركة السحب بقيمة ${w.amount.fmt} ${AppCurrency.symbol(w.currency)}؟'
                      '${w.cashBox != "direct" ? "\nسيتم استرجاع المبلغ فوراً إلى $boxLabel." : ""}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dangerWaste,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          erp.deleteAccountantWithdrawal(w.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف حركة السحب واسترجاع المبلغ بنجاح.'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        },
                        child: const Text('حذف واسترجاع'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGraniteInvoicesTable(ERPProvider erp) {
    final graniteFactoryInvoices = erp.factoryInvoices.where((i) {
      if (!i.containsGranite) return false;
      if (_graniteCurrency == AppCurrency.usd) return AppCurrency.isUsd(i.currency);
      if (_graniteCurrency == AppCurrency.syp) return AppCurrency.isSyp(i.currency);
      return true;
    }).toList();
    final graniteWorkshopInvoices = erp.workshopInvoices.where((i) {
      if (!i.isGranite) return false;
      if (_graniteCurrency == AppCurrency.usd) return AppCurrency.isUsd(i.currency);
      if (_graniteCurrency == AppCurrency.syp) return AppCurrency.isSyp(i.currency);
      return true;
    }).toList();

    if (graniteFactoryInvoices.isEmpty && graniteWorkshopInvoices.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            children: const [
              Icon(Icons.receipt_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'لا توجد فواتير مبيعات تحتوي أصناف غرانيت بعد',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      child: Column(
        children: [
          ...graniteFactoryInvoices.map((inv) {
            double graniteRev = 0.0;
            double graniteCogs = 0.0;
            for (var item in inv.items) {
              if (item.isGranite) {
                graniteRev += item.totalPrice;
                graniteCogs += item.totalCost;
              }
            }
            final profit = (graniteRev - graniteCogs).clamp(0.0, double.infinity);
            final accShare = profit * (erp.graniteAccountantPercentage / 100.0);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.chipBgBlue,
                child: const Icon(
                  Icons.factory_rounded,
                  color: AppColors.accentPrimary,
                  size: 20,
                ),
              ),
              title: Text(
                'فاتورة مصنع: ${inv.invoiceNo} • الطرف: ${inv.partyName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(inv.date)} • مبيعات الغرانيت: ${graniteRev.fmt} ${AppCurrency.symbol(inv.currency)} • التكلفة: ${graniteCogs.fmt} ${AppCurrency.symbol(inv.currency)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ربح الفاتورة: ${profit.fmt} ${AppCurrency.symbol(inv.currency)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'حصة المحاسب: ${accShare.fmt} ${AppCurrency.symbol(inv.currency)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...graniteWorkshopInvoices.map((inv) {
            final profit = (inv.agreedPrice - inv.netCost).clamp(0.0, double.infinity);
            final accShare = profit * (erp.graniteAccountantPercentage / 100.0);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.chipBgSky,
                child: const Icon(
                  Icons.construction_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              title: Text(
                'فاتورة معمل: ${inv.invoiceNo} • العميل: ${inv.clientName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(inv.date)} • القيمة: ${inv.agreedPrice.fmt} ${AppCurrency.symbol(inv.currency)} • التكلفة: ${inv.netCost.fmt} ${AppCurrency.symbol(inv.currency)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ربح المعمل: ${profit.fmt} ${AppCurrency.symbol(inv.currency)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'حصة المحاسب: ${accShare.fmt} ${AppCurrency.symbol(inv.currency)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                      fontSize: 11,
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

  void _showEditProfitPercentageDialog(BuildContext context, ERPProvider erp) {
    final ctrl = TextEditingController(text: erp.graniteAccountantPercentage.fmt);
    double currentPct = erp.graniteAccountantPercentage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final parsed = double.tryParse(ctrl.text.trim()) ?? currentPct;
          final valid = parsed >= 0.0 && parsed <= 100.0;
          final previewShareUsd = erp.netGraniteProfit * (parsed / 100.0);
          final previewShareSyp = erp.netGraniteProfitSyp * (parsed / 100.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: const [
                Icon(Icons.tune_rounded, color: AppColors.accentPrimary),
                SizedBox(width: 8),
                Text('تعديل نسبة أرباح محاسب الغرانيت'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حدد النسبة المئوية التي يستحقها المحاسب من صافي أرباح مبيعات أصناف الغرانيت. يتم تطبيق النسبة وإعادة احتساب الأرباح والقيود المحاسبية فورياً.',
                    style: TextStyle(fontSize: 12, color: AppColors.brandSecondaryText),
                  ),
                  const SizedBox(height: 14),

                  // Quick presets
                  const Text(
                    'نسب سريعة مقترحة:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [25.0, 30.0, 33.3, 40.0, 50.0, 60.0, 75.0].map((preset) {
                      final isSelected = (parsed - preset).abs() < 0.05;
                      return ChoiceChip(
                        label: Text('${preset.fmt}%'),
                        selected: isSelected,
                        onSelected: (_) {
                          setDialogState(() {
                            ctrl.text = preset.fmt;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'النسبة المئوية (%)',
                      hintText: 'مثال: 50 أو 35.5',
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      errorText: valid ? null : 'النسبة يجب أن تكون بين 0 و 100',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Live Calculation Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'معاينة الأرباح بالاعتماد على النسبة الجديدة:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              '${valid ? parsed.fmt : "—"}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'مستحقات المحاسب الجديدة: ${AppCurrency.dual(previewShareUsd, previewShareSyp)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إجمالي صافي أرباح الغرانيت: ${AppCurrency.dual(erp.netGraniteProfit, erp.netGraniteProfitSyp)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
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
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: valid
                    ? () {
                        erp.setGraniteAccountantPercentage(parsed);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تعديل نسبة أرباح المحاسب بنجاح إلى ${parsed.fmt}%',
                            ),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    : null,
                child: const Text('حفظ واعتماد النسبة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWithdrawAccountantProfitDialog(
    BuildContext context,
    ERPProvider erp,
  ) {
    String selectedCurrency = AppCurrency.usd;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final recipientCtrl = TextEditingController(text: 'محاسب الغرانيت');
    String selectedCashBox = 'main';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final availableBalance = erp.accountantAvailableBalanceOf(selectedCurrency);
          final double enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final boxBalance = selectedCashBox == 'direct'
              ? double.infinity
              : erp.cashOf(selectedCashBox, selectedCurrency);
          final bool exceedsProfit = enteredAmount > availableBalance + 0.0001;
          final bool exceedsCash =
              selectedCashBox != 'direct' && enteredAmount > boxBalance + 0.0001;
          final bool isValid = enteredAmount > 0 && !exceedsProfit && !exceedsCash;

          String? warningText;
          if (enteredAmount > 0) {
            if (exceedsProfit) {
              warningText =
                  'المبلغ يتجاوز رصيد الأرباح المتاح للسحب (${availableBalance.fmt} ${AppCurrency.symbol(selectedCurrency)})!';
            } else if (exceedsCash) {
              warningText =
                  'رصيد الصندوق المحدد (${boxBalance.fmt} ${AppCurrency.symbol(selectedCurrency)}) لا يكفي للصرف!';
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: const [
                Icon(Icons.payments_rounded, color: AppColors.successGreen),
                SizedBox(width: 8),
                Text('سحب دفعة من أرباح محاسب الغرانيت'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance indicator card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الرصيد المتبقي المتاح للسحب:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${availableBalance.fmt} ${AppCurrency.symbol(selectedCurrency)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                          // Currency toggle
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('دولار \$'),
                                selected: selectedCurrency == AppCurrency.usd,
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      selectedCurrency = AppCurrency.usd;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('ليرة سورية'),
                                selected: selectedCurrency == AppCurrency.syp,
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      selectedCurrency = AppCurrency.syp;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount input with quick buttons
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            'مبلغ السحب (${AppCurrency.symbol(selectedCurrency)})',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (availableBalance > 0)
                          ActionChip(
                            avatar: const Icon(Icons.all_inclusive_rounded, size: 14),
                            label: Text('كامل الرصيد (${availableBalance.fmt})'),
                            onPressed: () {
                              setDialogState(() {
                                amountCtrl.text = availableBalance.fmt;
                              });
                            },
                          ),
                        if (availableBalance > 0)
                          ActionChip(
                            avatar: const Icon(Icons.pie_chart_outline_rounded, size: 14),
                            label: Text('نصف الرصيد (${(availableBalance / 2).fmt})'),
                            onPressed: () {
                              setDialogState(() {
                                amountCtrl.text = (availableBalance / 2).fmt;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Source Cash Box
                    DropdownButtonFormField<String>(
                      value: selectedCashBox,
                      decoration: InputDecoration(
                        labelText: 'الصندوق المخصوم منه',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'main',
                          child: Text(
                            'الصندوق الرئيسي (المتاح: ${erp.cashOf("main", selectedCurrency).fmt} ${AppCurrency.symbol(selectedCurrency)})',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'order',
                          child: Text(
                            'صندوق الطلبيات (المتاح: ${erp.cashOf("order", selectedCurrency).fmt} ${AppCurrency.symbol(selectedCurrency)})',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'scrap',
                          child: Text(
                            'صندوق الزيادات والسكراب (المتاح: ${erp.cashOf("scrap", selectedCurrency).fmt} ${AppCurrency.symbol(selectedCurrency)})',
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'direct',
                          child: Text('تسوية دفترية مباشرة (سحب خارجي بدون خصم من صندوق)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCashBox = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Recipient
                    TextField(
                      controller: recipientCtrl,
                      decoration: InputDecoration(
                        labelText: 'المستلم / صاحب المسحوبات',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'بيان / ملاحظات السحب (اختياري)',
                        hintText: 'مثال: سحب دفعة نقدية من عمولة مبيعات الغرانيت',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    if (warningText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.dangerWaste,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warningText,
                                style: const TextStyle(
                                  color: AppColors.dangerWaste,
                                  fontSize: 11,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: isValid
                    ? () {
                        final warning = MutableWrapper<String?>(null);
                        final success = erp.withdrawAccountantProfit(
                          amount: enteredAmount,
                          currency: selectedCurrency,
                          cashBox: selectedCashBox,
                          notes: notesCtrl.text.trim(),
                          recipient: recipientCtrl.text.trim().isNotEmpty
                              ? recipientCtrl.text.trim()
                              : 'محاسب الغرانيت',
                          outWarning: warning,
                        );
                        if (success) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم صرف دفعة ${enteredAmount.fmt} ${AppCurrency.symbol(selectedCurrency)} من أرباح المحاسب بنجاح.',
                              ),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        } else {
                          setDialogState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                warning.value ?? 'تعذر صرف الدفعة.',
                              ),
                              backgroundColor: AppColors.dangerWaste,
                            ),
                          );
                        }
                      }
                    : null,
                child: const Text('تأكيد وصرف السحب'),
              ),
            ],
          );
        },
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                      'يضمن النظام الفصل التام بين الصناديق الستة (الرئيسي، الزيادات، الطلبيات) بالدولار والليرة مع حماية ACID',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: () => _showCashBoxTransferDialog(erp),
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text(
                  'التحويل بين الصناديق (6 صناديق)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تصفية عملة الصناديق:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              CurrencyFilterPills(
                selected: _cashBoxesCurrency,
                onChanged: (c) => setState(() => _cashBoxesCurrency = c),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                  boxKey: 'main',
                  erp: erp,
                  currencyFilter: _cashBoxesCurrency,
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
                  boxKey: 'scrap',
                  erp: erp,
                  currencyFilter: _cashBoxesCurrency,
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
                  boxKey: 'order',
                  erp: erp,
                  currencyFilter: _cashBoxesCurrency,
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
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال مبلغ صحيح أكبر من الصفر.'),
                    backgroundColor: AppColors.dangerWaste,
                  ),
                );
                return;
              }
              if (amount > max + 0.001) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'لا يمكن دفع/قبض مبلغ أكبر من المستحق المطلوب (${max.fmt} $sym)!',
                    ),
                    backgroundColor: AppColors.dangerWaste,
                  ),
                );
                return;
              }
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

  /// Pay button dedicated to Supplier Accounts in Factory Suppliers Financials.
  Widget _buildSupplierPayButton(ERPProvider erp, SupplierModel supplier) {
    final hasDebt =
        supplier.debtBalance > 0.01 || supplier.debtBalanceSyp > 0.01;
    if (!hasDebt) return const Chip(label: Text('خالص'));
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dangerWaste,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.payment_rounded, size: 16),
      label: const Text('دفع للمورد',
          style: TextStyle(fontWeight: FontWeight.bold)),
      onPressed: () => _showSupplierPaymentDialog(erp, supplier),
    );
  }

  void _showSupplierPaymentDialog(ERPProvider erp, SupplierModel supplier) {
    final hasUsd = supplier.debtBalance > 0.01;
    final hasSyp = supplier.debtBalanceSyp > 0.01;
    String selectedCurrency = hasUsd ? AppCurrency.usd : AppCurrency.syp;
    double currentDue = supplier.debtOf(selectedCurrency);
    final ctrl =
        TextEditingController(text: currentDue > 0 ? currentDue.fmt : '');
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final sym = AppCurrency.symbol(selectedCurrency);
          final boxCash = erp.cashOf('main', selectedCurrency);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerWaste.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.outbox_rounded,
                    color: AppColors.dangerWaste,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دفع للمورد: ${supplier.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المستحق الكلي: ${supplier.dualDebt}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brandSecondaryText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasUsd && hasSyp) ...[
                      const Text(
                        'اختر عملة الدفع:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: AppCurrency.usd,
                              groupValue: selectedCurrency,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'دولار (${supplier.debtBalance.fmt}\$)'),
                              onChanged: (v) {
                                if (v != null) {
                                  setSt(() {
                                    selectedCurrency = v;
                                    currentDue = supplier.debtOf(v);
                                    ctrl.text = currentDue > 0
                                        ? currentDue.fmt
                                        : '';
                                    errorMsg = null;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: AppCurrency.syp,
                              groupValue: selectedCurrency,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'ليرة (${supplier.debtBalanceSyp.fmt} ل.س)'),
                              onChanged: (v) {
                                if (v != null) {
                                  setSt(() {
                                    selectedCurrency = v;
                                    currentDue = supplier.debtOf(v);
                                    ctrl.text = currentDue > 0
                                        ? currentDue.fmt
                                        : '';
                                    errorMsg = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
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
                              const Text('المستحق في هذه العملة:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                '${currentDue.fmt} $sym',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الرصيد المتوفر بالصندوق الرئيسي:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                '${boxCash.fmt} $sym',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: boxCash >= currentDue
                                      ? AppColors.successGreen
                                      : AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'مبلغ الدفع ($sym)',
                        prefixIcon: const Icon(Icons.money_off_rounded),
                        helperText: 'الحد الأقصى المسموح: ${currentDue.fmt} $sym',
                        suffixIcon: currentDue > 0
                            ? TextButton(
                                onPressed: () {
                                  setSt(() {
                                    ctrl.text = currentDue.fmt;
                                    errorMsg = null;
                                  });
                                },
                                child: const Text('كامل المستحق',
                                    style: TextStyle(fontSize: 12)),
                              )
                            : null,
                      ),
                      onChanged: (_) => setSt(() => errorMsg = null),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                  backgroundColor: AppColors.dangerWaste,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('تأكيد الدفع',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final amount = double.tryParse(ctrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    setSt(
                        () => errorMsg = 'يرجى إدخال مبلغ صحيح أكبر من الصفر.');
                    return;
                  }
                  if (amount > currentDue + 0.001) {
                    setSt(() => errorMsg =
                        'لا يمكن دفع مبلغ أكبر من المستحق المطلوب للمورد (${currentDue.fmt} $sym)!');
                    return;
                  }
                  if (amount > boxCash + 0.001) {
                    setSt(() => errorMsg =
                        'رصيد الصندوق الرئيسي غير كافٍ لإتمام الدفع (المتوفر: ${boxCash.fmt} $sym).');
                    return;
                  }

                  final ok = erp.paySupplierDebt(
                    supplier: supplier,
                    amount: amount,
                    currency: selectedCurrency,
                  );

                  if (ok) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.successGreen,
                        content: Text(
                            'تم دفع ${amount.fmt} $sym للمورد ${supplier.name} بنجاح.'),
                      ),
                    );
                  } else {
                    setSt(() => errorMsg =
                        'تعذر تنفيذ عملية الدفع. تحقق من المدخلات.');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Collect button dedicated to Workshop Projects in Project Financials.
  Widget _buildProjectCollectButton(
      ERPProvider erp, WorkshopProjectModel project) {
    final dueUsd = erp.projectDue(project.id);
    final dueSyp = erp.projectDueSyp(project.id);
    final hasDue = dueUsd > 0.01 || dueSyp > 0.01;
    if (!hasDue) return const Chip(label: Text('خالص'));
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.payments_rounded, size: 16),
      label: const Text('قبض من المشروع',
          style: TextStyle(fontWeight: FontWeight.bold)),
      onPressed: () => _showProjectCollectionDialog(erp, project),
    );
  }

  void _showProjectCollectionDialog(
      ERPProvider erp, WorkshopProjectModel project) {
    final dueUsd = erp.projectDue(project.id);
    final dueSyp = erp.projectDueSyp(project.id);
    final hasUsd = dueUsd > 0.01;
    final hasSyp = dueSyp > 0.01;
    String selectedCurrency = hasUsd ? AppCurrency.usd : AppCurrency.syp;
    double currentDue = erp.projectDueOf(project.id, selectedCurrency);
    final ctrl =
        TextEditingController(text: currentDue > 0 ? currentDue.fmt : '');
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final sym = AppCurrency.symbol(selectedCurrency);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
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
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحصيل لمشروع: ${project.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الزبون: ${project.clientName} • المتبقي: ${AppCurrency.dual(dueUsd, dueSyp)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brandSecondaryText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasUsd && hasSyp) ...[
                      const Text(
                        'اختر عملة التحصيل:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: AppCurrency.usd,
                              groupValue: selectedCurrency,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('دولار (${dueUsd.fmt}\$)'),
                              onChanged: (v) {
                                if (v != null) {
                                  setSt(() {
                                    selectedCurrency = v;
                                    currentDue =
                                        erp.projectDueOf(project.id, v);
                                    ctrl.text = currentDue > 0
                                        ? currentDue.fmt
                                        : '';
                                    errorMsg = null;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: AppCurrency.syp,
                              groupValue: selectedCurrency,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('ليرة (${dueSyp.fmt} ل.س)'),
                              onChanged: (v) {
                                if (v != null) {
                                  setSt(() {
                                    selectedCurrency = v;
                                    currentDue =
                                        erp.projectDueOf(project.id, v);
                                    ctrl.text = currentDue > 0
                                        ? currentDue.fmt
                                        : '';
                                    errorMsg = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المستحق المطلوب في هذه العملة:',
                                  style: TextStyle(fontSize: 12)),
                          Text(
                            '${currentDue.fmt} $sym',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.dangerWaste,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'مبلغ التحصيل ($sym)',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        helperText:
                            'الحد الأقصى المسموح: ${currentDue.fmt} $sym',
                        suffixIcon: currentDue > 0
                            ? TextButton(
                                onPressed: () {
                                  setSt(() {
                                    ctrl.text = currentDue.fmt;
                                    errorMsg = null;
                                  });
                                },
                                child: const Text('كامل المستحق',
                                    style: TextStyle(fontSize: 12)),
                              )
                            : null,
                      ),
                      onChanged: (_) => setSt(() => errorMsg = null),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('تأكيد التحصيل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final amount = double.tryParse(ctrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    setSt(() =>
                        errorMsg = 'يرجى إدخال مبلغ تحصيل صحيح أكبر من الصفر.');
                    return;
                  }
                  if (amount > currentDue + 0.001) {
                    setSt(() => errorMsg =
                        'لا يمكن تحصيل مبلغ أكبر من المستحق المطلوب للمشروع (${currentDue.fmt} $sym)!');
                    return;
                  }

                  final ok = erp.collectProjectPayment(
                    projectId: project.id,
                    amount: amount,
                    currency: selectedCurrency,
                  );

                  if (ok) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.successGreen,
                        content: Text(
                            'تم تحصيل ${amount.fmt} $sym لمشروع ${project.name} بنجاح.'),
                      ),
                    );
                  } else {
                    setSt(() => errorMsg =
                        'تعذر تنفيذ عملية التحصيل. تحقق من المدخلات.');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Collect button dedicated to Customer Accounts.
  /// Launches the Multi-Currency Customer Collection Dialog with automatic
  /// currency classification display, direct payment, and real-time cross-currency conversion.
  Widget _buildCustomerCollectButton(ERPProvider erp, ClientModel client) {
    final hasDebt = client.debtBalance > 0.01 || client.debtBalanceSyp > 0.01;
    if (!hasDebt) return const Chip(label: Text('خالص'));
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: () => CustomerCollectionDialog.show(
        context,
        client: client,
        erp: erp,
      ),
      child: const Text('تحصيل', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final q = _supplierQuery.trim();
    final allSuppliers = erp.suppliers;
    final filteredSuppliers = allSuppliers.where((s) {
      if (_supplierCurrency != 'ALL') {
        if (_supplierCurrency == AppCurrency.usd && s.debtBalance <= 0.01 && s.debtBalanceSyp > 0.01) {
          return false;
        }
        if (_supplierCurrency == AppCurrency.syp && s.debtBalanceSyp <= 0.01 && s.debtBalance > 0.01) {
          return false;
        }
      }
      if (_supplierFilter == 0) {
        final hasDebt = _supplierCurrency == AppCurrency.usd
            ? s.debtBalance > 0.01
            : _supplierCurrency == AppCurrency.syp
                ? s.debtBalanceSyp > 0.01
                : (s.debtBalance > 0.01 || s.debtBalanceSyp > 0.01);
        if (!hasDebt) return false;
      }
      if (q.isEmpty) return true;
      final text = '${s.name} ${s.phone} ${s.location}';
      return arabicFuzzyMatch(text, q);
    }).toList();

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
                      'متابعة حسابات وفواتير وكشوفات حساب موردي مستلزمات ومواد المصنع',
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
                      _supplierCurrency == AppCurrency.usd
                          ? '${totalDue.fmt} \$'
                          : _supplierCurrency == AppCurrency.syp
                              ? '${totalDueSyp.fmt} ل.س'
                              : AppCurrency.dual(totalDue, totalDueSyp),
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
          const SizedBox(height: 16),

          // Search & Filter Bar
          SectionSearchAndFilterBar(
            searchController: _supplierSearchCtrl,
            searchQuery: _supplierQuery,
            onSearchChanged: (v) => setState(() => _supplierQuery = v),
            selectedCurrency: _supplierCurrency,
            onCurrencyChanged: (c) => setState(() => _supplierCurrency = c),
            hintText: 'بحث في الموردين بالاسم أو الهاتف أو الموقع...',
            onClear: () => setState(() => _supplierQuery = ''),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                selected: _supplierFilter == 0,
                onSelected: (_) => setState(() => _supplierFilter = 0),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_actions_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'موردون بذمتهم مستحقات (${debtors.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _supplierFilter == 1,
                onSelected: (_) => setState(() => _supplierFilter = 1),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'كافة الموردين (${allSuppliers.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (filteredSuppliers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'لا يوجد موردون مطابقون للبحث أو الفلتر المحدد.',
                  ),
                ),
              ),
            ),
          ...filteredSuppliers.map((s) {
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
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المورد: ${s.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 16,
                      ),
                      label: const Text(
                        'معاينة كشف الحساب قبل الطباعة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        A4StatementPrintDialog.show(
                          context,
                          statementData: A4StatementData.fromSupplier(
                            supplier: s,
                            erp: erp,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                subtitle: Text(
                  'المتبقي علينا: ${s.dualDebt} • الفواتير: ${invs.length}',
                ),
                trailing: _buildSupplierPayButton(erp, s),
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
                        'التاريخ: ${inv.date.toString().substring(0, 10)} • واصلة: ${inv.isGoodsDelivered ? "نعم" : "لا (شحن مرسمل ${inv.shippingFee}${inv.currencySymbol})"} • المدفوع: ${inv.advancePayment.fmt}${inv.currencySymbol} • المتبقي للمورد: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                      ),
                      trailing: inv.isDue
                          ? const Chip(
                              label: Text(
                                'مستحق الدفع',
                                style: TextStyle(
                                  color: AppColors.dangerWaste,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Chip(
                              label: Text(
                                'مدفوعة',
                                style: TextStyle(
                                  color: AppColors.successGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      children: [
                        if (inv.photoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: AppImagePreviewCard(
                              imagePath: inv.photoUrl,
                              title: 'صورة الفاتورة المرفقة (${inv.invoiceNo})',
                            ),
                          ),
                        ...inv.items.map(
                          (it) => ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: it.isMeterItem
                                    ? AppColors.chipBgBlue
                                    : AppColors.chipBgAmber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                it.isMeterItem ? 'أمتار' : 'بلوك',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: it.isMeterItem
                                      ? AppColors.accentPrimary
                                      : AppColors.partnersEquityAccent,
                                ),
                              ),
                            ),
                            title: Text(
                              '${it.typeName.isNotEmpty ? it.typeName : it.description} ${it.grade}${it.isMeterItem && it.thicknessCm > 0 ? " (${it.thicknessCm.fmt} سم)" : ""}',
                            ),
                            subtitle: Text(
                              it.isMeterItem
                                  ? '${it.quantity.fmt} ${it.meterUnit.isNotEmpty ? it.meterUnit : "متر"} × ${it.unitPrice.fmt}${inv.currencySymbol} = ${(it.quantity * it.unitPrice).fmt}${inv.currencySymbol}'
                                  : '${it.quantity.fmt} طن × ${it.unitPrice.fmt}${inv.currencySymbol} = ${(it.quantity * it.unitPrice).fmt}${inv.currencySymbol}',
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

    final q = _agentQuery.trim();
    final allAgents = erp.clients
        .where((c) => c.clientType == 'معتمد مصنع')
        .toList();
    final filteredAgents = allAgents.where((c) {
      if (_agentCurrency != 'ALL') {
        if (_agentCurrency == AppCurrency.usd && c.isSypCustomer && c.debtBalance <= 0.01) {
          return false;
        }
        if (_agentCurrency == AppCurrency.syp && c.isUsdCustomer && c.debtBalanceSyp <= 0.01) {
          return false;
        }
      }
      if (_agentFilter == 0) {
        final hasDebt = _agentCurrency == AppCurrency.usd
            ? c.debtBalance > 0.01
            : _agentCurrency == AppCurrency.syp
                ? c.debtBalanceSyp > 0.01
                : (c.debtBalance > 0.01 || c.debtBalanceSyp > 0.01);
        if (!hasDebt) return false;
      }
      if (q.isEmpty) return true;
      final text = '${c.name} ${c.phone} ${c.location}';
      return arabicFuzzyMatch(text, q);
    }).toList();

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
                      'متابعة حسابات وفواتير وتحصيلات وكشوفات حساب وكلاء التوزيع المعتمدين',
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
                      _agentCurrency == AppCurrency.usd
                          ? '${totalDue.fmt} \$'
                          : _agentCurrency == AppCurrency.syp
                              ? '${totalDueSyp.fmt} ل.س'
                              : AppCurrency.dual(totalDue, totalDueSyp),
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
          const SizedBox(height: 16),

          // Search & Filter Bar
          SectionSearchAndFilterBar(
            searchController: _agentSearchCtrl,
            searchQuery: _agentQuery,
            onSearchChanged: (v) => setState(() => _agentQuery = v),
            selectedCurrency: _agentCurrency,
            onCurrencyChanged: (c) => setState(() => _agentCurrency = c),
            hintText: 'بحث في معتمدي المصنع بالاسم أو الهاتف أو الموقع...',
            onClear: () => setState(() => _agentQuery = ''),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                selected: _agentFilter == 0,
                onSelected: (_) => setState(() => _agentFilter = 0),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_actions_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'معتمدون عليهم مستحقات (${debtors.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _agentFilter == 1,
                onSelected: (_) => setState(() => _agentFilter = 1),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'كافة المعتمدين (${allAgents.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (filteredAgents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا يوجد معتمدون مطابقون للبحث أو الفلتر المحدد.'),
                ),
              ),
            ),
          ...filteredAgents.map((c) {
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
                title: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'المعتمد: ${c.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomerClassificationBadge(client: c),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 16,
                      ),
                      label: const Text(
                        'معاينة كشف الحساب قبل الطباعة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        A4StatementPrintDialog.show(
                          context,
                          statementData: A4StatementData.fromAccreditedAgent(
                            client: c,
                            erp: erp,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                subtitle: Text(
                  'المتبقي عليه: ${c.dualDebt} • الفواتير: ${invs.length}',
                ),
                trailing: _buildCustomerCollectButton(erp, c),
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
                          ? const Chip(
                              label: Text(
                                'مستحق الدفع',
                                style: TextStyle(
                                  color: AppColors.dangerWaste,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Chip(
                              label: Text(
                                'مدفوعة',
                                style: TextStyle(
                                  color: AppColors.successGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      children: [
                        if (inv.photoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: AppImagePreviewCard(
                              imagePath: inv.photoUrl,
                              title: 'صورة الفاتورة المرفقة (${inv.invoiceNo})',
                            ),
                          ),
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
  // TAB 5: WORKSHOP FINANCIALS (Retail + Projects)
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
                Tab(text: 'زبائن المعمل (الطلبيات والجزافي)'),
                Tab(text: 'مالية المشاريع (Project Financials)'),
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

    String fmtRetail(double usd, double syp) {
      if (_retailCurrency == AppCurrency.usd) {
        return '${usd.fmt} \$';
      } else if (_retailCurrency == AppCurrency.syp) {
        return '${syp.fmt} ل.س';
      } else {
        return AppCurrency.dual(usd, syp);
      }
    }

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
          fmtRetail(totalInvoiced, totalInvoicedSyp),
          AppColors.accentPrimary,
        ),
        const SizedBox(width: 8),
        stat(
          'المتبقي للتحصيل',
          fmtRetail(totalDue, totalDueSyp),
          AppColors.dangerWaste,
        ),
        const SizedBox(width: 8),
        stat(
          'ديون الجزافي',
          fmtRetail(retailDebt, retailDebtSyp),
          AppColors.partnersEquityAccent,
        ),
      ],
    );
  }

  Widget _buildRetailFinances(ERPProvider erp) {
    final q = _retailQuery.trim();
    final clients = erp.clients.where((c) {
      final isWorkshopClient = c.clientType == 'زبون معمل' ||
          erp.workshopInvoices.any((i) => i.clientName.trim() == c.name.trim());
      if (!isWorkshopClient) return false;
      if (_retailCurrency != 'ALL') {
        if (_retailCurrency == AppCurrency.usd && c.isSypCustomer && c.debtBalance <= 0.01) {
          return false;
        }
        if (_retailCurrency == AppCurrency.syp && c.isUsdCustomer && c.debtBalanceSyp <= 0.01) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      final text = '${c.name} ${c.phone}';
      return arabicFuzzyMatch(text, q);
    }).toList();

    bool matchesInv(WorkshopInvoiceModel i) {
      if (_retailCurrency != 'ALL') {
        final isInvSyp = AppCurrency.isSyp(i.currency);
        final isInvUsd = AppCurrency.isUsd(i.currency);
        final client = erp.clients
            .where((c) => c.name.trim() == i.clientName.trim())
            .firstOrNull;
        final isSypHolder = client != null && client.isSypCustomer;
        final isUsdHolder = client != null && client.isUsdCustomer;

        if (_retailCurrency == AppCurrency.syp) {
          if (isInvSyp) {
            // matches
          } else if (isSypHolder && !isInvUsd) {
            // matches
          } else {
            return false;
          }
        } else {
          if (isInvUsd) {
            // matches
          } else if (isUsdHolder && !isInvSyp) {
            // matches
          } else {
            return false;
          }
        }
      }
      if (q.isEmpty) return true;
      final hay =
          '${i.invoiceNo} ${i.clientName} ${i.itemDescription} ${i.sourceType} ${i.photoPath} ${i.services.map((s) => '${s.serviceName} ${s.notes}').join(' ')}';
      return arabicFuzzyMatch(hay, q);
    }

    final invs = erp.workshopInvoices
        .where((i) => i.projectId.isEmpty && matchesInv(i))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search across clients and invoice fields.
          SectionSearchAndFilterBar(
            searchController: _retailSearchCtrl,
            searchQuery: _retailQuery,
            onSearchChanged: (v) => setState(() => _retailQuery = v),
            selectedCurrency: _retailCurrency,
            onCurrencyChanged: (c) => setState(() => _retailCurrency = c),
            hintText: 'بحث في الزبائن، الفواتير، الخدمات بالاسم أو الرقم...',
            onClear: () => setState(() => _retailQuery = ''),
          ),
          const SizedBox(height: 12),
          _buildRetailStats(erp),
          const SizedBox(height: 12),

          // Sub-view switch: Customer Accounts vs Invoice Ledger
          Row(
            children: [
              ChoiceChip(
                selected: _retailSubView == 0,
                onSelected: (_) => setState(() => _retailSubView = 0),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'حسابات زبائن المعمل (${clients.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _retailSubView == 1,
                onSelected: (_) => setState(() => _retailSubView = 1),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'سجل فواتير المعمل (${invs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _retailSubView == 0
                ? (clients.isEmpty
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد حسابات زبائن معمل مطابقة.'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: clients.length,
                        itemBuilder: (_, idx) {
                          final c = clients[idx];
                          final clientInvs = erp.workshopInvoices
                              .where((i) => i.clientName.trim() == c.name.trim())
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
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'الزبون: ${c.name}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CustomerClassificationBadge(client: c),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'معاينة كشف الحساب قبل الطباعة',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      A4StatementPrintDialog.show(
                                        context,
                                        statementData:
                                            A4StatementData.fromCustomer(
                                          client: c,
                                          erp: erp,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'الرصيد المتبقي عليه: ${c.dualDebt} • الفواتير: ${clientInvs.length}${c.phone.isNotEmpty ? " • الهاتف: ${c.phone}" : ""}',
                              ),
                              trailing: _buildCustomerCollectButton(erp, c),
                              children: [
                                if (clientInvs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('لا توجد فواتير مسجلة لهذا الزبون.'),
                                  )
                                else
                                  ...clientInvs.map(
                                    (inv) => ExpansionTile(
                                      leading: CurrencyBadge(currency: inv.currency),
                                      title: Text(
                                        '${inv.invoiceNo} — الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'التاريخ: ${inv.date.toString().substring(0, 10)}${inv.depositDeducted > 0 ? " • عربون مخصوم: ${inv.depositDeducted.fmt}${inv.currencySymbol}" : ""} • مدفوع نقداً: ${inv.cashPaidNow.fmt}${inv.currencySymbol}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'معاينة طباعة A4',
                                            icon: const Icon(
                                              Icons.picture_as_pdf_rounded,
                                              color: Color(0xFF2563EB),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              A4InvoicePrintDialog.show(
                                                context,
                                                invoiceData:
                                                    A4InvoiceData.fromWorkshopInvoice(inv),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          inv.remainingBalance > 0.01
                                              ? const Chip(
                                                  label: Text(
                                                    'متبقي',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.dangerWaste,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              : const Chip(
                                                  label: Text(
                                                    'خالصة',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.successGreen,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                      children: [
                                        if (inv.items.isNotEmpty)
                                          ...inv.items.map(
                                            (it) => ListTile(
                                              dense: true,
                                              title: Text(it.description),
                                              subtitle: Text(
                                                'الكمية: ${it.quantity.fmt} ${it.unitCategory} • سعر الوحدة: ${it.unitPrice.fmt}${inv.currencySymbol} • الإجمالي: ${it.agreedPrice.fmt}${inv.currencySymbol}',
                                              ),
                                            ),
                                          ),
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
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ))
                : (invs.isEmpty
                    ? const Card(
                        child: Center(child: Text('لا توجد فواتير مطابقة.')),
                      )
                    : Card(
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                            A4InvoiceData.fromWorkshopInvoice(inv),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  inv.remainingBalance > 0.01
                                      ? const Chip(
                                          label: Text(
                                            'متبقي',
                                            style: TextStyle(
                                              color: AppColors.dangerWaste,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : const Chip(
                                          label: Text(
                                            'خالصة',
                                            style: TextStyle(
                                              color: AppColors.successGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                              children: [
                                if (inv.photoPath.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: AppImagePreviewCard(
                                      imagePath: inv.photoPath,
                                      title:
                                          'صورة الفاتورة المرفقة (${inv.invoiceNo})',
                                    ),
                                  ),
                                if (inv.items.isNotEmpty)
                                  ...inv.items.map(
                                    (it) => ListTile(
                                      dense: true,
                                      title: Text(it.description),
                                      subtitle: Text(
                                        'الكمية: ${it.quantity.fmt} ${it.unitCategory} • سعر الوحدة: ${it.unitPrice.fmt}${inv.currencySymbol} • الإجمالي: ${it.agreedPrice.fmt}${inv.currencySymbol}',
                                      ),
                                    ),
                                  ),
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
                      )),
          ),
        ],
      ),
    );
  }


  Widget _buildProjectsStats(ERPProvider erp) {
    final invs = erp.workshopInvoices
        .where((i) => i.projectId.isNotEmpty)
        .toList();
    double sumWhere(String cur, double Function(WorkshopInvoiceModel) f) => invs
        .where((i) => i.currency == cur)
        .fold<double>(0.0, (s, i) => s + f(i));

    final totalInvoicedUsd = sumWhere(AppCurrency.usd, (i) => i.grandTotal);
    final totalInvoicedSyp = sumWhere(AppCurrency.syp, (i) => i.grandTotal);
    final totalCollectedUsd = sumWhere(
      AppCurrency.usd,
      (i) => i.cashPaidNow + i.depositDeducted,
    );
    final totalCollectedSyp = sumWhere(
      AppCurrency.syp,
      (i) => i.cashPaidNow + i.depositDeducted,
    );
    final totalDueUsd = sumWhere(AppCurrency.usd, (i) => i.remainingBalance);
    final totalDueSyp = sumWhere(AppCurrency.syp, (i) => i.remainingBalance);

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
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    String fmtProj(double usd, double syp) {
      if (_projectCurrency == AppCurrency.usd) {
        return '${usd.fmt} \$';
      } else if (_projectCurrency == AppCurrency.syp) {
        return '${syp.fmt} ل.س';
      } else {
        return AppCurrency.dual(usd, syp);
      }
    }

    return Row(
      children: [
        stat(
          'إجمالي المشاريع',
          '${erp.workshopProjects.length} مشروع (${invs.length} فاتورة)',
          AppColors.accentPrimary,
        ),
        const SizedBox(width: 8),
        stat(
          'إجمالي مبالغ الفواتير',
          fmtProj(totalInvoicedUsd, totalInvoicedSyp),
          const Color(0xFF2563EB),
        ),
        const SizedBox(width: 8),
        stat(
          'المحصل الفعلي',
          fmtProj(totalCollectedUsd, totalCollectedSyp),
          AppColors.successGreen,
        ),
        const SizedBox(width: 8),
        stat(
          'المتبقي للتحصيل',
          fmtProj(totalDueUsd, totalDueSyp),
          AppColors.dangerWaste,
        ),
      ],
    );
  }

  Widget _buildProjectsFinances(ERPProvider erp) {
    final q = _projectQuery.trim();
    final allProjects = erp.workshopProjects;
    final pendingProjects = erp.pendingProjects;
    final completedProjects = erp.completedProjects;
    final allProjectInvoices = erp.workshopInvoices
        .where((i) => i.projectId.isNotEmpty)
        .toList();

    bool matchesProject(WorkshopProjectModel p) {
      final invs = erp.workshopInvoices
          .where((i) => i.projectId == p.id)
          .toList();
      if (_projectCurrency != 'ALL') {
        final hasSypInvoice = invs.any((i) => AppCurrency.isSyp(i.currency));
        final hasUsdInvoice = invs.any((i) => AppCurrency.isUsd(i.currency));
        final client = erp.clients
            .where((c) => c.name.trim() == p.clientName.trim())
            .firstOrNull;
        final isSypHolder = client != null && client.isSypCustomer;
        final isUsdHolder = client != null && client.isUsdCustomer;

        if (_projectCurrency == AppCurrency.syp) {
          if (hasSypInvoice) {
            // matches
          } else if (isSypHolder && !hasUsdInvoice) {
            // matches
          } else if (invs.isEmpty && isSypHolder) {
            // matches
          } else {
            return false;
          }
        } else {
          if (hasUsdInvoice) {
            // matches
          } else if (isUsdHolder && !hasSypInvoice) {
            // matches
          } else if (invs.isEmpty && isUsdHolder) {
            // matches
          } else {
            return false;
          }
        }
      }
      if (q.isEmpty) return true;
      final hay =
          '${p.name} ${p.clientName} ${p.phone} ${p.description} ${invs.map((i) => '${i.invoiceNo} ${i.itemDescription}').join(' ')}';
      return arabicFuzzyMatch(hay, q);
    }

    bool matchesInv(WorkshopInvoiceModel i) {
      if (_projectCurrency != 'ALL') {
        final isInvSyp = AppCurrency.isSyp(i.currency);
        final isInvUsd = AppCurrency.isUsd(i.currency);
        final client = erp.clients
            .where((c) => c.name.trim() == i.clientName.trim())
            .firstOrNull;
        final isSypHolder = client != null && client.isSypCustomer;
        final isUsdHolder = client != null && client.isUsdCustomer;

        if (_projectCurrency == AppCurrency.syp) {
          if (isInvSyp) {
            // matches
          } else if (isSypHolder && !isInvUsd) {
            // matches
          } else {
            return false;
          }
        } else {
          if (isInvUsd) {
            // matches
          } else if (isUsdHolder && !isInvSyp) {
            // matches
          } else {
            return false;
          }
        }
      }
      if (q.isEmpty) return true;
      final proj = erp.workshopProjects
          .cast<WorkshopProjectModel?>()
          .firstWhere((p) => p?.id == i.projectId, orElse: () => null);
      final hay =
          '${i.invoiceNo} ${i.clientName} ${proj?.name ?? ""} ${i.itemDescription} ${i.sourceType} ${i.services.map((s) => s.serviceName).join(' ')}';
      return arabicFuzzyMatch(hay, q);
    }

    final filteredProjects = (switch (_projectSubView) {
      1 => pendingProjects,
      2 => completedProjects,
      _ => allProjects,
    }).where(matchesProject).toList();

    final filteredInvoices =
        allProjectInvoices.where(matchesInv).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionSearchAndFilterBar(
            searchController: _projectSearchCtrl,
            searchQuery: _projectQuery,
            onSearchChanged: (v) => setState(() => _projectQuery = v),
            selectedCurrency: _projectCurrency,
            onCurrencyChanged: (c) => setState(() => _projectCurrency = c),
            hintText: 'بحث في المشاريع، الزبائن، المواقع أو الفواتير...',
            onClear: () => setState(() => _projectQuery = ''),
          ),
          const SizedBox(height: 12),
          _buildProjectsStats(erp),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                selected: _projectSubView == 0,
                onSelected: (_) => setState(() => _projectSubView = 0),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.domain_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'كافة المشاريع (${allProjects.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _projectSubView == 1,
                onSelected: (_) => setState(() => _projectSubView = 1),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_actions_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'بانتظار التحصيل (${pendingProjects.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _projectSubView == 2,
                onSelected: (_) => setState(() => _projectSubView = 2),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'مسددة بالكامل (${completedProjects.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _projectSubView == 3,
                onSelected: (_) => setState(() => _projectSubView = 3),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'سجل فواتير المشاريع (${allProjectInvoices.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _projectSubView == 3
                ? (filteredInvoices.isEmpty
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد فواتير مشاريع مطابقة.'),
                          ),
                        ),
                      )
                    : Card(
                        child: ListView.separated(
                          itemCount: filteredInvoices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final inv = filteredInvoices[idx];
                            final proj = erp.workshopProjects
                                .cast<WorkshopProjectModel?>()
                                .firstWhere(
                                  (p) => p?.id == inv.projectId,
                                  orElse: () => null,
                                );
                            return ExpansionTile(
                              leading: CurrencyBadge(currency: inv.currency),
                              title: Text(
                                '${inv.invoiceNo} • ${inv.clientName}${proj != null ? " (مشروع: ${proj.name})" : ""}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${inv.itemDescription} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'معاينة طباعة A4',
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Color(0xFF2563EB),
                                    ),
                                    onPressed: () {
                                      A4InvoicePrintDialog.show(
                                        context,
                                        invoiceData:
                                            A4InvoiceData.fromWorkshopInvoice(
                                          inv,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  inv.remainingBalance > 0.01
                                      ? const Chip(
                                          label: Text(
                                            'متبقي',
                                            style: TextStyle(
                                              color: AppColors.dangerWaste,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : const Chip(
                                          label: Text(
                                            'خالصة',
                                            style: TextStyle(
                                              color: AppColors.successGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                              children: [
                                if (inv.photoPath.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: AppImagePreviewCard(
                                      imagePath: inv.photoPath,
                                      title:
                                          'صورة الفاتورة المرفقة (${inv.invoiceNo})',
                                    ),
                                  ),
                                if (inv.items.isNotEmpty)
                                  ...inv.items.map(
                                    (it) => ListTile(
                                      dense: true,
                                      title: Text(it.description),
                                      subtitle: Text(
                                        'الكمية: ${it.quantity.fmt} ${it.unitCategory} • سعر الوحدة: ${it.unitPrice.fmt}${inv.currencySymbol} • الإجمالي: ${it.agreedPrice.fmt}${inv.currencySymbol}',
                                      ),
                                    ),
                                  ),
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
                      ))
                : (filteredProjects.isEmpty
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد مشاريع مطابقة.'),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredProjects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final p = filteredProjects[idx];
                          final invs = erp.workshopInvoices
                              .where((i) => i.projectId == p.id)
                              .toList();
                          final due = erp.projectDue(p.id);
                          final dueSyp = erp.projectDueSyp(p.id);
                          final hasDue = due > 0.01 || dueSyp > 0.01;
                          final isPaidInFull = !hasDue && invs.isNotEmpty;

                          final totalUsd = invs
                              .where((i) => i.currency == AppCurrency.usd)
                              .fold<double>(0.0, (s, i) => s + i.grandTotal);
                          final totalSyp = invs
                              .where((i) => i.currency == AppCurrency.syp)
                              .fold<double>(0.0, (s, i) => s + i.grandTotal);
                          final paidUsd = invs
                              .where((i) => i.currency == AppCurrency.usd)
                              .fold<double>(
                                0.0,
                                (s, i) =>
                                    s + (i.cashPaidNow + i.depositDeducted),
                              );
                          final paidSyp = invs
                              .where((i) => i.currency == AppCurrency.syp)
                              .fold<double>(
                                0.0,
                                (s, i) =>
                                    s + (i.cashPaidNow + i.depositDeducted),
                              );

                          return Card(
                            elevation: 1,
                            margin: EdgeInsets.zero,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: isPaidInFull
                                    ? const Color(0xFFDCFCE7)
                                    : (hasDue
                                        ? const Color(0xFFFEE2E2)
                                        : AppColors.chipBgSky),
                                child: Icon(
                                  Icons.domain_rounded,
                                  color: isPaidInFull
                                      ? const Color(0xFF166534)
                                      : (hasDue
                                          ? AppColors.dangerWaste
                                          : AppColors.orderDepositBoxAccent),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'المشروع: ${p.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'معاينة كشف الحساب قبل الطباعة',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      A4StatementPrintDialog.show(
                                        context,
                                        statementData:
                                            A4StatementData.fromProject(
                                          project: p,
                                          erp: erp,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  if (isPaidInFull)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF86EFAC),
                                        ),
                                      ),
                                      child: const Text(
                                        'مسدد بالكامل',
                                        style: TextStyle(
                                          color: Color(0xFF166534),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (hasDue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                        ),
                                      ),
                                      child: Text(
                                        'متبقي: ${AppCurrency.dual(due, dueSyp)}',
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'قيد التنفيذ',
                                        style: TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                'الزبون: ${p.clientName}${p.phone.isNotEmpty ? " • الهاتف: ${p.phone}" : ""} • الفواتير: ${invs.length}',
                              ),
                              trailing: _buildProjectCollectButton(erp, p),
                              children: [
                                // Financial summary bar for the project
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'إجمالي قيمة الفواتير:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                            Text(
                                              AppCurrency.dual(
                                                totalUsd,
                                                totalSyp,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'إجمالي المدفوع:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                            Text(
                                              AppCurrency.dual(
                                                paidUsd,
                                                paidSyp,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.successGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'المتبقي للتحصيل:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                            Text(
                                              AppCurrency.dual(due, dueSyp),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: hasDue
                                                    ? AppColors.dangerWaste
                                                    : AppColors.successGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (p.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'ملاحظات المشروع: ${p.description}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.brandSecondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (invs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'لا توجد فواتير مسجلة لهذا المشروع حتى الآن.',
                                    ),
                                  )
                                else
                                  ...invs.map(
                                    (inv) => ListTile(
                                      leading: CurrencyBadge(
                                        currency: inv.currency,
                                      ),
                                      title: Text(
                                        '${inv.invoiceNo} — ${inv.grandTotal.fmt}${inv.currencySymbol}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${inv.itemDescription} • التاريخ: ${inv.date.toString().substring(0, 10)} • المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'معاينة طباعة A4',
                                            icon: const Icon(
                                              Icons.picture_as_pdf_rounded,
                                              color: Color(0xFF2563EB),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              A4InvoicePrintDialog.show(
                                                context,
                                                invoiceData:
                                                    A4InvoiceData
                                                        .fromWorkshopInvoice(
                                                  inv,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          inv.remainingBalance > 0.01
                                              ? const Chip(
                                                  label: Text(
                                                    'متبقي',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .dangerWaste,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              : const Chip(
                                                  label: Text(
                                                    'خالصة',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .successGreen,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
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
                      () {
                        if (_surplusCurrency == AppCurrency.usd) {
                          return '${erp.surplusFundBalance.fmt} \$';
                        } else if (_surplusCurrency == AppCurrency.syp) {
                          return '${erp.surplusFundBalanceSyp.fmt} ل.س';
                        } else {
                          return AppCurrency.dual(
                            erp.surplusFundBalance,
                            erp.surplusFundBalanceSyp,
                          );
                        }
                      }(),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تصفية عملة الزيادات:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              CurrencyFilterPills(
                selected: _surplusCurrency,
                onChanged: (c) => setState(() => _surplusCurrency = c),
              ),
            ],
          ),
          const SizedBox(height: 16),
          () {
            String fmtSurplus(double usd, double syp) {
              if (_surplusCurrency == AppCurrency.usd) {
                return '${usd.fmt} \$';
              } else if (_surplusCurrency == AppCurrency.syp) {
                return '${syp.fmt} ل.س';
              } else {
                return AppCurrency.dual(usd, syp);
              }
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSummaryCard(
                  'إيرادات الزيادات',
                  fmtSurplus(
                    erp.totalSurplusRevenue,
                    erp.totalSurplusRevenueSyp,
                  ),
                  AppColors.accentPrimary,
                  AppColors.chipBgBlue,
                ),
                _buildSummaryCard(
                  'التكلفة الأولية الكلية',
                  fmtSurplus(
                    erp.totalSurplusInitialCost,
                    erp.totalSurplusInitialCostSyp,
                  ),
                  AppColors.dangerWaste,
                  AppColors.chipBgRed,
                ),
                _buildSummaryCard(
                  'المدفوع من الصندوق',
                  fmtSurplus(
                    erp.totalSurplusCostPaid,
                    erp.totalSurplusCostPaidSyp,
                  ),
                  AppColors.partnersEquityAccent,
                  AppColors.chipBgAmber,
                ),
                _buildSummaryCard(
                  'المتبقي (ذمم الزيادات)',
                  fmtSurplus(remaining, erp.totalSurplusCostRemainingSyp),
                  AppColors.dangerWaste,
                  AppColors.chipBgRed,
                ),
                _buildSummaryCard(
                  'صافي ربح الزيادات',
                  fmtSurplus(erp.netSurplusProfit, erp.netSurplusProfitSyp),
                  AppColors.successGreen,
                  AppColors.chipBgGreen,
                ),
              ],
            );
          }(),
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
        erp.salesDiscountsOf(AppCurrency.usd) +
        erp.assetSaleLossesOf(AppCurrency.usd);
    final expensesSyp =
        erp.totalCOGSSyp +
        erp.totalOperationalExpensesSyp +
        erp.totalUnnaturalWasteLossesSyp +
        erp.totalSurplusInitialCostSyp +
        erp.accountantGraniteShareSyp +
        erp.expenseRecordsTotalOf(AppCurrency.syp) +
        erp.salesReturnsAndAllowancesOf(AppCurrency.syp) +
        erp.salesDiscountsOf(AppCurrency.syp) +
        erp.assetSaleLossesOf(AppCurrency.syp);
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
                      () {
                        if (_pnlCurrency == AppCurrency.usd) {
                          return '${erp.netOperatingProfit.fmt} \$';
                        } else if (_pnlCurrency == AppCurrency.syp) {
                          return '${erp.netOperatingProfitSyp.fmt} ل.س';
                        } else {
                          return AppCurrency.dual(
                            erp.netOperatingProfit,
                            erp.netOperatingProfitSyp,
                          );
                        }
                      }(),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تصفية عملة قائمة الدخل:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              CurrencyFilterPills(
                selected: _pnlCurrency,
                onChanged: (c) => setState(() => _pnlCurrency = c),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                    'أرباح بيع الأصول الثابتة (فائض سعر البيع):',
                    erp.assetSaleGainsOf(AppCurrency.usd),
                    syp: erp.assetSaleGainsOf(AppCurrency.syp),
                  ),
                  _buildPlLine(
                    'إيرادات تحصيل واسترداد سُلف العمالة:',
                    erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd),
                    syp: erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.syp),
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
                    'مستحقات المحاسب عن مبيعات الغرانيت (${erp.graniteAccountantPercentage.fmt}% Share):',
                    erp.accountantGraniteShare,
                    syp: erp.accountantGraniteShareSyp,
                  ),
                  _buildPlLine(
                    'خسائر بيع الأصول الثابتة (عجز سعر البيع):',
                    erp.assetSaleLossesOf(AppCurrency.usd),
                    syp: erp.assetSaleLossesOf(AppCurrency.syp),
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
    String? boxKey,
    ERPProvider? erp,
    String currencyFilter = 'ALL',
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
                  if (currencyFilter != AppCurrency.syp)
                    Text(
                      '${balance.fmt} \$',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  if (currencyFilter != AppCurrency.usd)
                    Text(
                      '${balanceSyp.fmt} ل.س',
                      style: TextStyle(
                        fontSize: currencyFilter == AppCurrency.syp ? 20 : 15,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (boxKey != null && erp != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (currencyFilter != AppCurrency.syp)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showCashBoxTransferDialog(
                        erp,
                        presetBoxKey: boxKey,
                        presetCurrency: AppCurrency.usd,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text(
                        'تحويل (\$)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (currencyFilter == 'ALL') const SizedBox(width: 8),
                if (currencyFilter != AppCurrency.usd)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showCashBoxTransferDialog(
                        erp,
                        presetBoxKey: boxKey,
                        presetCurrency: AppCurrency.syp,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text(
                        'تحويل (ل.س)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showCashBoxTransferDialog(
    ERPProvider erp, {
    String? presetBoxKey,
    String? presetCurrency,
  }) {
    final boxes = [
      {
        'id': 'main_usd',
        'box': 'main',
        'currency': AppCurrency.usd,
        'name': 'الصندوق الرئيسي',
        'symbol': '\$',
        'label': '1. الصندوق الرئيسي — بالدولار (\$)',
      },
      {
        'id': 'main_syp',
        'box': 'main',
        'currency': AppCurrency.syp,
        'name': 'الصندوق الرئيسي',
        'symbol': 'ل.س',
        'label': '2. الصندوق الرئيسي — بالليرة السورية (ل.س)',
      },
      {
        'id': 'scrap_usd',
        'box': 'scrap',
        'currency': AppCurrency.usd,
        'name': 'صندوق الزيادات',
        'symbol': '\$',
        'label': '3. صندوق الزيادات — بالدولار (\$)',
      },
      {
        'id': 'scrap_syp',
        'box': 'scrap',
        'currency': AppCurrency.syp,
        'name': 'صندوق الزيادات',
        'symbol': 'ل.س',
        'label': '4. صندوق الزيادات — بالليرة السورية (ل.س)',
      },
      {
        'id': 'order_usd',
        'box': 'order',
        'currency': AppCurrency.usd,
        'name': 'صندوق الطلبيات',
        'symbol': '\$',
        'label': '5. صندوق الطلبيات — بالدولار (\$)',
      },
      {
        'id': 'order_syp',
        'box': 'order',
        'currency': AppCurrency.syp,
        'name': 'صندوق الطلبيات',
        'symbol': 'ل.س',
        'label': '6. صندوق الطلبيات — بالليرة السورية (ل.س)',
      },
    ];

    double getBoxBalance(Map<String, dynamic> b) {
      return erp.cashOf(b['box'] as String, b['currency'] as String);
    }

    String initialFromId = presetBoxKey != null && presetCurrency != null
        ? '${presetBoxKey}_${presetCurrency.toLowerCase()}'
        : 'main_usd';
    if (!boxes.any((b) => b['id'] == initialFromId)) {
      initialFromId = 'main_usd';
    }

    String fromId = initialFromId;
    String toId = fromId == 'scrap_usd' ? 'main_usd' : 'scrap_usd';
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    String? formError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final fromBox = boxes.firstWhere((b) => b['id'] == fromId);
          final toBox = boxes.firstWhere((b) => b['id'] == toId);

          final fromBalance = getBoxBalance(fromBox);
          final toBalance = getBoxBalance(toBox);

          final fromCurrency = fromBox['currency'] as String;
          final toCurrency = toBox['currency'] as String;
          final sameCurrency = fromCurrency == toCurrency;

          final amount = double.tryParse(amountCtrl.text) ?? 0.0;
          final rate = double.tryParse(rateCtrl.text) ?? 0.0;

          double convertedAmount = amount;
          if (!sameCurrency) {
            if (fromCurrency == AppCurrency.usd) {
              convertedAmount = amount * rate;
            } else {
              convertedAmount = rate > 0 ? (amount / rate) : 0.0;
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.accentPrimary,
                  size: 26,
                ),
                SizedBox(width: 10),
                Text(
                  'التحويل بين الصناديق المعزولة (الستة صناديق)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تحويل الأموال بين الصناديق الستة (الرئيسي، الزيادات، الطلبيات) بالدولار والليرة السورية:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.brandSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Source Box Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: fromId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'من الصندوق المصدر',
                        helperText:
                            'الرصيد المتاح: ${fromBalance.fmt} ${fromBox['symbol']}',
                        helperStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      items: boxes.map((b) {
                        final bal = getBoxBalance(b);
                        return DropdownMenuItem<String>(
                          value: b['id'] as String,
                          child: Text(
                            '${b['label']} (الرصيد: ${bal.fmt} ${b['symbol']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setSt(() {
                        fromId = v!;
                        if (fromId == toId) {
                          toId = boxes.firstWhere(
                            (b) => b['id'] != fromId,
                          )['id'] as String;
                        }
                        formError = null;
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Target Box Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: toId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'إلى الصندوق المستلم',
                        helperText:
                            'الرصيد الحالي: ${toBalance.fmt} ${toBox['symbol']}',
                        helperStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      items: boxes.map((b) {
                        final bal = getBoxBalance(b);
                        return DropdownMenuItem<String>(
                          value: b['id'] as String,
                          child: Text(
                            '${b['label']} (الرصيد: ${bal.fmt} ${b['symbol']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setSt(() {
                        toId = v!;
                        formError = null;
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Amount TextField with Quick Max Button
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
                                      'المبلغ المراد تحويله (${fromBox['symbol']})',
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
                                    amountCtrl.text = fromBalance.fmt;
                                    setSt(() => formError = null);
                                  },
                                  child: const Text('كامل الرصيد المتاح'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!sameCurrency) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: rateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'سعر الصرف (1\$ = ... ل.س)',
                                prefixIcon: Icon(Icons.price_change_outlined),
                              ),
                              onChanged: (_) =>
                                  setSt(() => formError = null),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Live Transfer Summary Card
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
                          const Text(
                            'ملخص العملية وأرصدة الصناديق المتوقعة:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المبلغ المخصوم: ${amount.fmt} ${fromBox['symbol']}',
                              ),
                              Text(
                                'الرصيد بعد التحويل: ${(fromBalance - amount).fmt} ${fromBox['symbol']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (fromBalance - amount) < 0
                                      ? AppColors.dangerWaste
                                      : AppColors.brandPrimaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المبلغ المودع: ${convertedAmount.fmt} ${toBox['symbol']}',
                              ),
                              Text(
                                'الرصيد بعد التحويل: ${(toBalance + convertedAmount).fmt} ${toBox['symbol']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                          if (!sameCurrency && rate > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              fromCurrency == AppCurrency.usd
                                  ? 'حسبة التصريف: ${amount.fmt} \$ × ${rate.fmt} = ${convertedAmount.fmt} ل.س'
                                  : 'حسبة التصريف: ${amount.fmt} ل.س ÷ ${rate.fmt} = ${convertedAmount.fmt} \$',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.brandSecondaryText,
                              ),
                            ),
                          ],
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
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  if (fromId == toId) {
                    setSt(() => formError = 'لا يمكن التحويل لنفس الصندوق.');
                    return;
                  }
                  if (amount <= 0) {
                    setSt(() => formError = 'أدخل مبلغاً صحيحاً أكبر من الصفر.');
                    return;
                  }
                  if (amount > fromBalance + 0.0001) {
                    setSt(
                      () =>
                          formError =
                              'المبلغ يتجاوز رصيد الصندوق المصدر.',
                    );
                    return;
                  }
                  if (!sameCurrency && rate <= 0) {
                    setSt(
                      () =>
                          formError =
                              'أدخل سعر صرف صحيح لاختلاف العملتين.',
                    );
                    return;
                  }

                  bool success = false;
                  if (sameCurrency) {
                    success = erp.transferCash(
                      fromBox: fromBox['box'] as String,
                      toBox: toBox['box'] as String,
                      currency: fromCurrency,
                      amount: amount,
                    );
                  } else {
                    success = erp.convertCurrency(
                      fromBox: fromBox['box'] as String,
                      toBox: toBox['box'] as String,
                      fromCurrency: fromCurrency,
                      amount: amount,
                      exchangeRate: rate,
                    );
                  }

                  if (!success) {
                    setSt(
                      () => formError = 'تعذر تنفيذ عملية التحويل.',
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحويل ${amount.fmt} ${fromBox['symbol']} من (${fromBox['name']}) إلى (${toBox['name']}) بنجاح.',
                      ),
                      backgroundColor: AppColors.successGreen,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('تأكيد التحويل بين الصناديق'),
              ),
            ],
          );
        },
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
    final text = syp == null
        ? '${val.fmt} \$'
        : _pnlCurrency == AppCurrency.usd
            ? '${val.fmt} \$'
            : _pnlCurrency == AppCurrency.syp
                ? '${syp.fmt} ل.س'
                : AppCurrency.dual(val, syp);
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
