import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';

class WorkforceScreen extends StatefulWidget {
  const WorkforceScreen({super.key});

  @override
  State<WorkforceScreen> createState() => _WorkforceScreenState();
}

class _WorkforceScreenState extends State<WorkforceScreen>
    with SingleTickerProviderStateMixin {
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
    searchWorkerCtrl.dispose();
    searchTechCtrl.dispose();
    searchAdminCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    final totalAdvancesUsd = erp.staffList.fold<double>(
      0.0,
      (sum, s) => sum + s.cashAdvancesDisbursed,
    );
    final totalAdvancesSyp = erp.staffList.fold<double>(
      0.0,
      (sum, s) => sum + s.cashAdvancesDisbursedSyp,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.groups_2_rounded,
                        color: AppColors.accentPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة الكادر والعمالة والسُلف (Workforce & Advances)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'إدارة سجلات العمال والمعلمين والإداريين • دفع الأجور • صرف وتحصيل السُلف النقدية',
                            style: TextStyle(
                              color: AppColors.brandSecondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () => _showAddStaffDialog(erp),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text(
                        'إضافة موظف/عامل جديد',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary Stat Cards
                Row(
                  children: [
                    _buildStatCard(
                      title: 'إجمالي الكادر',
                      value: '${erp.staffList.length} شخص',
                      subtitle:
                          'عمال: ${erp.staffList.where((s) => s.category == 'عمال').length} • معلمين: ${erp.staffList.where((s) => s.category == 'معلمين').length} • إداريين: ${erp.staffList.where((s) => s.category == 'إداريين').length}',
                      icon: Icons.people_outline_rounded,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      title: 'إجمالي السُلف القائمة (\$)',
                      value: '${totalAdvancesUsd.fmt} \$',
                      subtitle: 'مجموع سُلف الكادر بالدولار',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      title: 'إجمالي السُلف القائمة (ل.س)',
                      value: '${totalAdvancesSyp.fmt} ل.س',
                      subtitle: 'مجموع سُلف الكادر بالليرة',
                      icon: Icons.money_outlined,
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      title: 'الصندوق الرئيسي المتاح',
                      value:
                          '${erp.cashOf('main', AppCurrency.usd).fmt} \$ • ${erp.cashOf('main', AppCurrency.syp).fmt} ل.س',
                      subtitle: 'رصيد الصندوق المتاح للصرف والقبض',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 3 Category Tabs
          Container(
            color: const Color(0xFFF1F5F9),
            child: TabBar(
              controller: _staffCategoryTabController,
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
                      '1. العمال (Workers) [${erp.staffList.where((s) => s.category == 'عمال').length}]',
                ),
                Tab(
                  text:
                      '2. المعلمون (Masters) [${erp.staffList.where((s) => s.category == 'معلمين').length}]',
                ),
                Tab(
                  text:
                      '3. الإداريون (Administrators) [${erp.staffList.where((s) => s.category == 'إداريين').length}]',
                ),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(
    ERPProvider erp,
    String category,
    TextEditingController searchCtrl,
  ) {
    List<StaffModel> categoryList =
        erp.staffList.where((s) => s.category == category).toList();

    if (searchCtrl.text.trim().isNotEmpty) {
      final q = searchCtrl.text.trim().toLowerCase();
      categoryList = categoryList
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.phone.toLowerCase().contains(q) ||
                s.location.toLowerCase().contains(q),
          )
          .toList();
    }

    final double totalCategoryAdvancesUsd = categoryList.fold(
      0.0,
      (s, e) => s + e.cashAdvancesDisbursed,
    );
    final double totalCategoryAdvancesSyp = categoryList.fold(
      0.0,
      (s, e) => s + e.cashAdvancesDisbursedSyp,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search & Summary Header for tab
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم، الهاتف، أو الموقع في قسم ($category)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'سُلف هذا القسم: ${totalCategoryAdvancesUsd.fmt}\$ • ${totalCategoryAdvancesSyp.fmt} ل.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Worker List
          Expanded(
            child: categoryList.isEmpty
                ? Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا يوجد أشخاص مسجلون في قسم ($category)',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.brandSecondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showAddStaffDialog(erp, defaultCategory: category),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text('إضافة $category جديد'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: categoryList.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final staff = categoryList[idx];
                      return _buildWorkerCard(context, erp, staff);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(
    BuildContext context,
    ERPProvider erp,
    StaffModel staff,
  ) {
    final hasAdvances =
        staff.cashAdvancesDisbursed > 0.0001 ||
        staff.cashAdvancesDisbursedSyp > 0.0001;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _getCategoryColor(staff.category).withValues(alpha: 0.15),
              child: Text(
                staff.name.trim().isNotEmpty ? staff.name.trim()[0] : '؟',
                style: TextStyle(
                  color: _getCategoryColor(staff.category),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Worker Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        staff.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(staff.category)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getCategoryColor(staff.category)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          staff.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(staff.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staff.phone.isEmpty ? 'غير مسجل' : staff.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staff.location.isEmpty ? 'غير محدد' : staff.location,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Summary Statistic: Total Advances
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: hasAdvances
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasAdvances
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إجمالي رصيد السُلف:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasAdvances
                          ? const Color(0xFF92400E)
                          : AppColors.brandSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${staff.cashAdvancesDisbursed.fmt} \$ • ${staff.cashAdvancesDisbursedSyp.fmt} ل.س',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: hasAdvances
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // 1. Pay Wages Button (دفع اجور)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showPayWagesDialog(erp, staff),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('دفع أجور'),
                ),

                // 2. Pay Advance Button (دفع سلفة)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showPayAdvanceDialog(erp, staff),
                  icon: const Icon(Icons.arrow_circle_up_rounded, size: 16),
                  label: const Text('دفع سلفة'),
                ),

                // 3. Collect/Repay Advance Button (قبض/تحصيل سلفة)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showCollectAdvanceDialog(erp, staff),
                  icon: const Icon(Icons.arrow_circle_down_rounded, size: 16),
                  label: const Text('قبض/تحصيل سلفة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'معلمين':
        return const Color(0xFF7C3AED);
      case 'إداريين':
        return const Color(0xFF0284C7);
      case 'عمال':
      default:
        return AppColors.accentPrimary;
    }
  }

  // =========================================================================
  // 1. ADD NEW WORKER DIALOG
  // =========================================================================
  void _showAddStaffDialog(ERPProvider erp, {String defaultCategory = 'عمال'}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = defaultCategory;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.accentPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text('إضافة موظف / عامل جديد'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل *',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'الصفة / الفئة الوظيفية *',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'عمال',
                        child: Text('عامل (Worker)'),
                      ),
                      DropdownMenuItem(
                        value: 'معلمين',
                        child: Text('معلم / فني اختصاصي (Specialist / Master)'),
                      ),
                      DropdownMenuItem(
                        value: 'إداريين',
                        child: Text('إداري (Administrative)'),
                      ),
                    ],
                    onChanged: (v) => setSt(() => category = v ?? 'عمال'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الموقع / مكان السكن أو العمل',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال اسم الموظف/العامل.'),
                      backgroundColor: AppColors.dangerWaste,
                    ),
                  );
                  return;
                }
                erp.addStaff(
                  StaffModel(
                    id: 'stf_${DateTime.now().microsecondsSinceEpoch}',
                    name: name,
                    category: category,
                    phone: phoneCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت إضافة ($name) بنجاح تحت قسم ($category)!',
                    ),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              },
              child: const Text('حفظ الموظف'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. PAY WAGES DIALOG
  // =========================================================================
  void _showPayWagesDialog(ERPProvider erp, StaffModel staff) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String currency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final safeAvailable = erp.cashOf('main', currency);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: AppColors.accentPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('دفع أجور • ${staff.name}'),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يُخصم هذا الأجر مباشرة من الصندوق الرئيسي ويُسجل كقيد مصروف تحت بند (الرواتب والأجور).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اختر عملة الدفع:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    CurrencySelector(
                      value: currency,
                      dense: true,
                      onChanged: (v) => setSt(() => currency = v),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'الرصيد المتاح في الصندوق الرئيسي: ${AppCurrency.single(safeAvailable, currency)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: safeAvailable > 0
                              ? AppColors.successGreen
                              : AppColors.dangerWaste,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'مبلغ الأجر (${AppCurrency.symbol(currency)}) *',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات / وصف (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال مبلغ صحيح للأجر.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  if (amount > safeAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'الرصيد في الصندوق الرئيسي (${AppCurrency.single(safeAvailable, currency)}) غير كافٍ لدفع هذا المبلغ!',
                        ),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  final ok = erp.payStaffWages(
                    staff,
                    amount,
                    currency,
                    note: noteCtrl.text.trim(),
                  );
                  if (ok) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم دفع الأجر (${amount.fmt} ${AppCurrency.symbol(currency)}) لـ (${staff.name}) وخصمه من الصندوق وقيده في المصروفات بنجاح.',
                        ),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
                child: const Text('تأكيد ودفع الأجور'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3. PAY ADVANCE DIALOG
  // =========================================================================
  void _showPayAdvanceDialog(ERPProvider erp, StaffModel staff) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String currency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final safeAvailable = erp.cashOf('main', currency);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_circle_up_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('صرف سلفة نقدية • ${staff.name}'),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تُخصم السلفة من الصندوق الرئيسي وتُسجل كقيد مصروف تحت بند (السُلف)، وتُضاف فوراً إلى رصيد سُلف ${staff.name}.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'رصيد السُلف الحالي: ${staff.cashAdvancesDisbursed.fmt} \$ • ${staff.cashAdvancesDisbursedSyp.fmt} ل.س',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اختر عملة السلفة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    CurrencySelector(
                      value: currency,
                      dense: true,
                      onChanged: (v) => setSt(() => currency = v),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'الرصيد المتاح في الصندوق الرئيسي: ${AppCurrency.single(safeAvailable, currency)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: safeAvailable > 0
                              ? AppColors.successGreen
                              : AppColors.dangerWaste,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'مبلغ السلفة (${AppCurrency.symbol(currency)}) *',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات / وصف (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال مبلغ صحيح للسلفة.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  if (amount > safeAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'الرصيد في الصندوق الرئيسي (${AppCurrency.single(safeAvailable, currency)}) غير كافٍ لصرف السلفة!',
                        ),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  final ok = erp.payStaffAdvance(
                    staff,
                    amount,
                    currency,
                    note: noteCtrl.text.trim(),
                  );
                  if (ok) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم صرف السلفة (${amount.fmt} ${AppCurrency.symbol(currency)}) لـ (${staff.name}) وتحديث رصيد السُلف بنجاح.',
                        ),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
                child: const Text('تأكيد وصرف السلفة'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 4. COLLECT / REPAY ADVANCE DIALOG
  // =========================================================================
  void _showCollectAdvanceDialog(ERPProvider erp, StaffModel staff) {
    final hasUsdAdvance = staff.cashAdvancesDisbursed > 0.0001;
    final hasSypAdvance = staff.cashAdvancesDisbursedSyp > 0.0001;

    // If no advance owed at all
    if (!hasUsdAdvance && !hasSypAdvance) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('قبض / تحصيل سلفة • ${staff.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 54,
                color: AppColors.successGreen,
              ),
              const SizedBox(height: 12),
              Text(
                'لا توجد أي سُلف مسجلة أو مستحقة على (${staff.name}) حالياً.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    String origCurrency =
        hasSypAdvance && !hasUsdAdvance ? AppCurrency.syp : AppCurrency.usd;
    String collCurrency = origCurrency;
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '14000');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final origBalance = origCurrency == AppCurrency.syp
              ? staff.cashAdvancesDisbursedSyp
              : staff.cashAdvancesDisbursed;

          final isCrossCurrency = origCurrency != collCurrency;
          final amountVal = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final rateVal = double.tryParse(rateCtrl.text.trim()) ?? 0.0;

          double calculatedDeduction = 0.0;
          if (!isCrossCurrency) {
            calculatedDeduction = amountVal;
          } else {
            if (origCurrency == AppCurrency.syp) {
              // Sub-case 1: Original advance was paid in SYP, collection in USD:
              // Deduction from SYP = Field 1 (USD) * Field 2 (Daily Exchange Rate)
              calculatedDeduction = amountVal * rateVal;
            } else {
              // Sub-case 2: Original advance was paid in USD, collection in SYP:
              // Deduction from USD = Field 1 (SYP) / Field 2 (Daily Exchange Rate)
              calculatedDeduction = rateVal > 0 ? (amountVal / rateVal) : 0.0;
            }
          }

          final remainingAfter = (origBalance - calculatedDeduction);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_circle_down_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('قبض / تحصيل سلفة • ${staff.name}'),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Outstanding Advance Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إجمالي السُلف المستحقة حالياً على هذا الشخص:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• بالدولار: ${staff.cashAdvancesDisbursed.fmt} \$\n• بالليرة السورية: ${staff.cashAdvancesDisbursedSyp.fmt} ل.س',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Select Original Advance Currency
                    const Text(
                      'أصل عملة السلفة المراد تحصيلها وتخفيضها:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (hasUsdAdvance)
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: AppCurrency.usd,
                              groupValue: origCurrency,
                              title: Text(
                                'سلفة الدولار (${staff.cashAdvancesDisbursed.fmt} \$)',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              onChanged: (v) => setSt(() {
                                origCurrency = v!;
                                if (!isCrossCurrency) collCurrency = v;
                              }),
                            ),
                          ),
                        if (hasSypAdvance)
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: AppCurrency.syp,
                              groupValue: origCurrency,
                              title: Text(
                                'سلفة الليرة (${staff.cashAdvancesDisbursedSyp.fmt} ل.س)',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              onChanged: (v) => setSt(() {
                                origCurrency = v!;
                                if (!isCrossCurrency) collCurrency = v;
                              }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Select Collection Currency
                    const Text(
                      'عملة القبض المستلمة فعلياً في الصندوق الرئيسي:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    CurrencySelector(
                      value: collCurrency,
                      dense: true,
                      onChanged: (v) => setSt(() => collCurrency = v),
                    ),
                    const SizedBox(height: 14),

                    // Scenario A: Same Currency
                    if (!isCrossCurrency) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'الحالة: العملة المقبوضة متطابقة مع أصل السلفة (تخفيض مباشر)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSt(() {}),
                        decoration: InputDecoration(
                          labelText:
                              'المبلغ المقبوض (${AppCurrency.symbol(collCurrency)}) *',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ]
                    // Scenario B: Cross-Currency Collection
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          origCurrency == AppCurrency.syp
                              ? 'تحصيل سلفة ليرة سورية بعملة الدولار: المبلغ المقبوض بالدولار × سعر الصرف = المبلغ المخصوم من رصيد الليرة.'
                              : 'تحصيل سلفة دولار بعملة الليرة السورية: المبلغ المقبوض بالليرة ÷ سعر الصرف = المبلغ المخصوم من رصيد الدولار.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Field 1: Amount in counter-currency
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSt(() {}),
                        decoration: InputDecoration(
                          labelText:
                              'الحقل 1: المبلغ المقبوض (${AppCurrency.symbol(collCurrency)}) *',
                          prefixIcon: const Icon(Icons.currency_exchange_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Field 2: Daily exchange rate
                      TextField(
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSt(() {}),
                        decoration: const InputDecoration(
                          labelText: 'الحقل 2: سعر الصرف اليومي (ل.س / \$) *',
                          prefixIcon: Icon(Icons.trending_up_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Live calculation breakdown
                    if (amountVal > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: remainingAfter < -0.01
                                ? AppColors.dangerWaste
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• يدخل إلى الصندوق الرئيسي: ${amountVal.fmt} ${AppCurrency.symbol(collCurrency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '• يُخصم من رصيد سلفة (${AppCurrency.symbol(origCurrency)}): ${calculatedDeduction.fmt} ${AppCurrency.symbol(origCurrency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '• رصيد السلفة المتبقي بعد التحصيل: ${remainingAfter.clamp(0.0, double.infinity).fmt} ${AppCurrency.symbol(origCurrency)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: remainingAfter < -0.01
                                    ? AppColors.dangerWaste
                                    : const Color(0xFF334155),
                              ),
                            ),
                            if (remainingAfter < -0.01)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'تنبيه: المبلغ المراد خصمه أكبر من رصيد السلفة المستحقة!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.dangerWaste,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات التحصيل (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (amountVal <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال مبلغ صحيح للتحصيل.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  if (isCrossCurrency && rateVal <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال سعر صرف يومي صحيح.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  if (calculatedDeduction <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('قيمة الخصم المحسوبة غير صالحة.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  if (calculatedDeduction > origBalance + 0.001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'المبلغ المراد خصمه (${calculatedDeduction.fmt}) أكبر من رصيد السلفة (${origBalance.fmt})!',
                        ),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }

                  final ok = erp.collectStaffAdvance(
                    staff: staff,
                    originalCurrency: origCurrency,
                    collectedCurrency: collCurrency,
                    collectedAmount: amountVal,
                    deductedAmount: calculatedDeduction,
                    exchangeRate: isCrossCurrency ? rateVal : 1.0,
                    note: noteCtrl.text.trim(),
                  );

                  if (ok) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم تحصيل السلفة (${amountVal.fmt} ${AppCurrency.symbol(collCurrency)}) وإيداعها في الصندوق الرئيسي وتسجيلها في الإيرادات وتخفيض رصيد السلفة بنجاح.',
                        ),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
                child: const Text('تأكيد وقبض السلفة'),
              ),
            ],
          );
        },
      ),
    );
  }
}
