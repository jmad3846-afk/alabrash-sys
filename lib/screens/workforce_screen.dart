import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/workday_modal.dart';

class WorkforceScreen extends StatefulWidget {
  const WorkforceScreen({super.key});

  @override
  State<WorkforceScreen> createState() => _WorkforceScreenState();
}

class _WorkforceScreenState extends State<WorkforceScreen> with SingleTickerProviderStateMixin {
  late TabController _staffCategoryTabController;
  final TextEditingController searchWorkerCtrl = TextEditingController();
  final TextEditingController searchTechCtrl = TextEditingController();
  final TextEditingController searchAdminCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _staffCategoryTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _staffCategoryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: AppColors.panelSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة الكادر والعمالة والسُلف (Workforce & Payroll)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                    const SizedBox(height: 4),
                    const Text('إدارة مستحقات يوميات العمالة وصرف السُلف النقدية المباشرة من الصندوق الرئيسي', style: TextStyle(color: AppColors.brandSecondaryText)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                      onPressed: () {
                        showDialog(context: context, builder: (_) => const WorkdayModal());
                      },
                      icon: const Icon(Icons.date_range_rounded),
                      label: const Text('[أيام عمل]'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.partnersEquityAccent),
                      onPressed: () => _showAddStaffDialog(erp),
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('إضافة موظف/عامل جديد'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 3 Isolated Finance Tabs (مالية العمال / مالية المعلمين / مالية الإداريين)
          Container(
            color: const Color(0xFFF1F5F9),
            child: TabBar(
              controller: _staffCategoryTabController,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.brandSecondaryText,
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: '1. مالية العمال (Workers Payroll)'),
                Tab(text: '2. مالية المعلمين (Master Technicians)'),
                Tab(text: '3. مالية الإداريين (Admin Staff)'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _staffCategoryTabController,
              children: [
                _buildCategoryTab(erp, 'عمال', searchWorkerCtrl),
                _buildCategoryTab(erp, 'معلمين', searchTechCtrl),
                _buildCategoryTab(erp, 'إداريين', searchAdminCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(ERPProvider erp, String category, TextEditingController searchCtrl) {
    List<StaffModel> categoryList = erp.staffList.where((s) => s.category == category).toList();

    if (searchCtrl.text.isNotEmpty) {
      categoryList = categoryList.where((s) => s.name.contains(searchCtrl.text)).toList();
    }

    double totalCategoryEarned = categoryList.fold(0.0, (s, e) => s + e.totalEarned);
    double totalCategoryAdvances = categoryList.fold(0.0, (s, e) => s + e.cashAdvancesDisbursed);
    double totalCategoryRemaining = categoryList.fold(0.0, (s, e) => s + e.netRemainingBalance);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Isolated Search Bar per tab
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم في قسم ($category)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.chipBgBlue, borderRadius: BorderRadius.circular(8)),
                child: Text('المكتسب: ${totalCategoryEarned.fmt}\$ | السُلف: ${totalCategoryAdvances.fmt}\$ | المتبقي: ${totalCategoryRemaining.fmt}\$', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: categoryList.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final staff = categoryList[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.1),
                      child: Text(staff.name[0], style: const TextStyle(color: AppColors.accentPrimary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الهاتف: ${staff.phone} • المستحق الإجمالي: ${staff.totalEarned}\$ • السُلف المصروفة: ${staff.cashAdvancesDisbursed}\$'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('المتبقي الصافي:', style: TextStyle(fontSize: 10, color: AppColors.brandSecondaryText)),
                            Text(
                              '${staff.netRemainingBalance.fmt} \$',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dangerWaste),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          onPressed: () => _showDisburseAdvanceDialog(erp, staff),
                          icon: const Icon(Icons.payments_rounded, size: 16),
                          label: const Text('[صرف سلفة]'),
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

  void _showAddStaffDialog(ERPProvider erp) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String category = 'عمال';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة موظف/عامل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: const [
                DropdownMenuItem(value: 'عمال', child: Text('عمال (Workers)')),
                DropdownMenuItem(value: 'معلمين', child: Text('معلمين (Master Technicians)')),
                DropdownMenuItem(value: 'إداريين', child: Text('إداريين (Admin Staff)')),
              ],
              onChanged: (v) => category = v!,
              decoration: const InputDecoration(labelText: 'الفئة الوظيفية'),
            ),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                erp.addStaff(StaffModel(
                  id: 'stf_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  category: category,
                  phone: phoneCtrl.text,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ الموظف'),
          ),
        ],
      ),
    );
  }

  void _showDisburseAdvanceDialog(ERPProvider erp, StaffModel staff) {
    final amountCtrl = TextEditingController(text: '100');
    String advCurrency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('صرف سلفة نقدية لـ: ${staff.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CurrencySelector(
                value: advCurrency,
                dense: true,
                onChanged: (v) => setSt(() => advCurrency = v),
              ),
              const SizedBox(height: 8),
              Text(
                  'الرصيد المتاح: ${AppCurrency.single(erp.cashOf('main', advCurrency), advCurrency)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'مبلغ السلفة (${AppCurrency.symbol(advCurrency)}) - يقتطع فوراً من الصندوق الرئيسي'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary),
              onPressed: () {
                double amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount > 0) {
                  erp.disburseCashAdvance(staff, amount, advCurrency);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'تم صرف السلفة وتحديث رصيد الموظف وصندوق الرئيسي بنجاح!'),
                        backgroundColor: AppColors.successGreen),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('تأكيد وصرف السلفة'),
            ),
          ],
        ),
      ),
    );
  }
}


