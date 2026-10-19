import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<Map<String, dynamic>> _navItems = [
    {'title': 'الشاشة الرئيسية', 'icon': Icons.dashboard_rounded},
    {'title': 'المصنع', 'icon': Icons.factory_rounded},
    {'title': 'المعمل', 'icon': Icons.precision_manufacturing_rounded},
    {'title': 'الخدمات', 'icon': Icons.home_repair_service_rounded},
    {'title': 'المالية', 'icon': Icons.account_balance_rounded},
    {'title': 'ملخص الدخل', 'icon': Icons.assessment_rounded},
    {'title': 'العاملين', 'icon': Icons.badge_rounded},
    {'title': 'الطلبيات', 'icon': Icons.shopping_bag_rounded},
    {'title': 'معلومات القيد الافتتاحي', 'icon': Icons.account_tree_rounded},
    {
      'title': 'مرتجعات ومسموحات الفواتير',
      'icon': Icons.assignment_return_rounded,
    },
    {'title': 'دليل الحسابات', 'icon': Icons.menu_book_rounded},
    {'title': 'إدارة الأصول الثابتة', 'icon': Icons.apartment_rounded},
    {'title': 'المصروفات', 'icon': Icons.request_quote_rounded},
    {'title': 'الميزانية العمومية', 'icon': Icons.table_chart_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.panelSurface,
        border: Border(
          left: BorderSide(color: AppColors.panelBorder, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Branding Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.panelBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.panelBorder),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/abaad_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أبعاد • ABAAD',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                      ),
                      const Text(
                        'لبرنامج إدارة الرخام والحجر',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.brandSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sidebar Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _navItems.length,
              itemBuilder: (context, idx) {
                final item = _navItems[idx];
                final isSelected = idx == selectedIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onDestinationSelected(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentPrimary.withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 20,
                              color: isSelected
                                  ? AppColors.accentPrimary
                                  : AppColors.brandSecondaryText,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.brandPrimaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer version badge
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.scrapBoxAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'نسخة الأوفلاين • v1.0.0 ACID',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
