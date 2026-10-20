import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import 'partner_management_modal.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.panelSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.panelBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Thermal Printer Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: erp.isThermalPrinterConnected ? AppColors.chipBgGreen : AppColors.chipBgRed,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: erp.isThermalPrinterConnected ? AppColors.successGreen : AppColors.dangerWaste,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.print_rounded,
                  size: 16,
                  color: erp.isThermalPrinterConnected ? AppColors.successGreen : AppColors.dangerWaste,
                ),
                const SizedBox(width: 6),
                Text(
                  erp.isThermalPrinterConnected ? 'طابعة الفواتير الحرارية متصلة' : 'طابعة الفواتير غير متصلة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: erp.isThermalPrinterConnected ? AppColors.successGreen : AppColors.dangerWaste,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 3 ISOLATED CASH BOX BADGES — each shows Dollar + Syrian funds
          // 1. Main Cash Box
          _buildCashBadge(
            title: 'الصندوق الرئيسي',
            usd: erp.mainCashBox,
            syp: erp.mainCashBoxSyp,
            bgColor: AppColors.chipBgBlue,
            accentColor: AppColors.accentPrimary,
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(width: 12),

          // 2. Scrap Cash Box
          _buildCashBadge(
            title: 'صندوق الزيادات',
            usd: erp.scrapCashBox,
            syp: erp.scrapCashBoxSyp,
            bgColor: AppColors.chipBgGreen,
            accentColor: AppColors.scrapBoxAccent,
            icon: Icons.inventory_2_rounded,
          ),
          const SizedBox(width: 12),

          // 3. Order Cash Box
          _buildCashBadge(
            title: 'صندوق الطلبيات',
            usd: erp.orderCashBox,
            syp: erp.orderCashBoxSyp,
            bgColor: AppColors.chipBgSky,
            accentColor: AppColors.orderDepositBoxAccent,
            icon: Icons.assignment_turned_in_rounded,
          ),

          const Spacer(),

          // QUICK ACTION BUTTON: Partners Equity Management
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.partnersEquityAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const PartnerManagementModal(),
              );
            },
            icon: const Icon(Icons.group_rounded, size: 18),
            label: const Text('الشركاء'),
          ),
        ],
      ),
    );
  }

  Widget _buildCashBadge({
    required String title,
    required double usd,
    required double syp,
    required Color bgColor,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600),
              ),
              Text(
                '${usd.fmt}\$ • ${syp.fmt}ل.س',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

