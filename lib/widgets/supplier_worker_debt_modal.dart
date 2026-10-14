import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class SupplierWorkerDebtModal extends StatefulWidget {
  const SupplierWorkerDebtModal({super.key});

  @override
  State<SupplierWorkerDebtModal> createState() => _SupplierWorkerDebtModalState();
}

class _SupplierWorkerDebtModalState extends State<SupplierWorkerDebtModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Dialog(
      child: Container(
        width: 700,
        height: 560,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.outbox_rounded, color: AppColors.dangerWaste),
                    const SizedBox(width: 8),
                    Text(
                      'تفاصيل المستحقات والديون التي علينا (عمال وموردين)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                    text:
                        'ديون الموردين (${AppCurrency.dual(erp.suppliersTotalDebts, erp.suppliersTotalDebtsSyp)})'),
                Tab(
                    text:
                        'مستحقات العمالة (${AppCurrency.dual(erp.workersTotalDebts, erp.workersTotalDebtsSyp)})'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Supplier Debts
                  ListView.separated(
                    itemCount: erp.suppliers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final supplier = erp.suppliers[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.partnersEquityAccent.withValues(alpha: 0.1),
                          child: Text(supplier.name[0], style: const TextStyle(color: AppColors.partnersEquityAccent, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${supplier.phone} • ${supplier.location}'),
                        trailing: Text(
                          supplier.dualDebt,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dangerWaste),
                        ),
                      );
                    },
                  ),
                  // Tab 2: Worker Debts
                  ListView.separated(
                    itemCount: erp.staffList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final staff = erp.staffList[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.1),
                          child: Text(staff.name[0], style: const TextStyle(color: AppColors.accentPrimary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('الفئة: ${staff.category} • المكتسب: ${AppCurrency.dual(staff.totalEarned, staff.totalEarnedSyp)} • السُلف: ${AppCurrency.dual(staff.cashAdvancesDisbursed, staff.cashAdvancesDisbursedSyp)}'),
                        trailing: Text(
                          staff.dualNet,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dangerWaste),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimaryText),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
